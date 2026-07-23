#!/usr/bin/env bash
set -euo pipefail

FIXTURE_PATH="${SOCIAL_STRATEGY_ANALYTICS_TRENDS_FIXTURE:-examples/social-strategy-analytics-trends-ingestion.fake.yaml}"
DOC_PATH="docs/operations/social-strategy-analytics-trends-ingestion.md"
PROJECT_SLUG="egdev"
CONTENT_LEDGER_NAMESPACE="discord-project-manager/project/egdev/content-ledger"
STRATEGY_NAMESPACE="discord-project-manager/project/egdev/strategy"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

command -v grep >/dev/null 2>&1 || fail "required command not found: grep"
command -v python3 >/dev/null 2>&1 || fail "required command not found: python3"

SKILL_PATHS=(
  "skills/strategy-planner/SKILL.md"
  "skills/linkedin-weekly-planner/SKILL.md"
  "skills/x-queue-planner/SKILL.md"
)

for path in "$FIXTURE_PATH" "$DOC_PATH" "${SKILL_PATHS[@]}"; do
  [[ -f "$path" ]] || fail "required file not found: $path"
done

python3 - "$FIXTURE_PATH" "$DOC_PATH" "$PROJECT_SLUG" "$CONTENT_LEDGER_NAMESPACE" "$STRATEGY_NAMESPACE" "${SKILL_PATHS[@]}" <<'PY'
import re
import sys
from datetime import date, datetime
from pathlib import Path

SIGNAL_SUMMARY_MAX_CHARS = 280

fixture_path = Path(sys.argv[1])
doc_path = Path(sys.argv[2])
project_slug = sys.argv[3]
content_ledger_namespace = sys.argv[4]
strategy_namespace = sys.argv[5]
skill_paths = [Path(value) for value in sys.argv[6:]]

try:
    import yaml
except ImportError as exc:
    raise SystemExit("ERROR: PyYAML is required for structural validation; install PyYAML and retry.") from exc

class Loader(yaml.SafeLoader):
    pass

def mapping(loader, node, deep=False):
    out = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in out:
            raise ValueError(f"duplicate YAML key: {key}")
        out[key] = loader.construct_object(value_node, deep=deep)
    return out

Loader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, mapping)

def req(ok, msg):
    if not ok:
        raise ValueError(msg)


def req_keys(mapping_value, allowed, area):
    req(isinstance(mapping_value, dict), f"{area} must be a mapping")
    extra = set(mapping_value) - set(allowed)
    missing = set(allowed) - set(mapping_value)
    req(not extra, f"{area} contains unsupported keys: {', '.join(sorted(extra))}")
    req(not missing, f"{area} is missing keys: {', '.join(sorted(missing))}")

def parse_ts(value, field):
    req(
        isinstance(value, str)
        and re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", value),
        f"{field} must be an RFC3339 UTC timestamp string ending in Z",
    )
    return datetime.fromisoformat(value.replace("Z", "+00:00"))

def parse_date(value, field):
    if isinstance(value, date) and not isinstance(value, datetime):
        return value
    req(isinstance(value, str) and re.fullmatch(r"\d{4}-\d{2}-\d{2}", value), f"{field} must be YYYY-MM-DD")
    return date.fromisoformat(value)

COUNT_METRICS_BY_NETWORK = {
    "linkedin": {"impressions", "reactions", "comments", "shares", "clicks"},
    "x": {"impressions", "likes", "replies", "reposts", "quote_posts", "clicks"},
}
RATE_METRICS = {"engagement_rate"}
REQUIRED_METRICS_BY_NETWORK = {
    network: count_metrics | RATE_METRICS
    for network, count_metrics in COUNT_METRICS_BY_NETWORK.items()
}


def validate_metric_value(network, key, value):
    if value == "unknown":
        return
    req(not isinstance(value, bool), f"metric {key} must not be boolean")
    if key in COUNT_METRICS_BY_NETWORK[network]:
        req(isinstance(value, int), f"metric {key} must be a non-negative integer or unknown")
        req(value >= 0, f"metric {key} must be a non-negative integer or unknown")
        return
    if key in RATE_METRICS:
        req(isinstance(value, (int, float)), f"metric {key} must be numeric between 0 and 1 or unknown")
        req(0 <= value <= 1, f"metric {key} must be numeric between 0 and 1 or unknown")
        return
    raise ValueError(f"unsupported metric key for {network}: {key}")


def req_rejects_metric(network, key, value):
    try:
        validate_metric_value(network, key, value)
    except ValueError:
        return
    raise ValueError(f"validator self-check accepted invalid metric {network}.{key}: {value!r}")


for invalid_metric in [
    ("linkedin", "impressions", True),
    ("linkedin", "impressions", 1.5),
    ("x", "likes", -1),
    ("x", "engagement_rate", False),
    ("x", "engagement_rate", 2.5),
]:
    req_rejects_metric(*invalid_metric)

text = fixture_path.read_text()
doc = doc_path.read_text()
data = yaml.load(text, Loader=Loader)
req_keys(data, {
    "schema_version",
    "contract",
    "project",
    "fake",
    "safe_for_repo",
    "live_scraping_enabled",
    "live_api_ingestion_enabled",
    "browser_automation_enabled",
    "raw_provider_payloads_included",
    "screenshots_included",
    "account_data_included",
    "private_metrics_included",
    "credential_material_included",
    "source_options",
    "normalized_snapshots",
    "trend_signals",
    "metadata",
}, "fixture")
req(data.get("schema_version") == 1, "schema_version must be 1")
req(data.get("contract") == "social-strategy-analytics-trends-ingestion", "wrong contract")
req(data.get("project") == project_slug, "project slug mismatch")
for flag in ["fake", "safe_for_repo"]:
    req(data.get(flag) is True, f"{flag} must be true")
for flag in [
    "live_scraping_enabled",
    "live_api_ingestion_enabled",
    "browser_automation_enabled",
    "raw_provider_payloads_included",
    "screenshots_included",
    "account_data_included",
    "private_metrics_included",
    "credential_material_included",
]:
    req(data.get(flag) is False, f"{flag} must be false")

expected_options = {
    "manual-sanitized-entry",
    "native-platform-export",
    "approved-provider-api",
    "rss-web-search-trend-provider",
    "browser-scraping-automation",
}
expected_source_approval_status = {
    "manual-sanitized-entry": "approved-for-fake-fixtures",
    "native-platform-export": "requires-separate-approval",
    "approved-provider-api": "pending-provider-approval",
    "rss-web-search-trend-provider": "approved-for-fake-fixtures",
    "browser-scraping-automation": "not-approved",
}
source_options = data.get("source_options") or []
req(isinstance(source_options, list) and source_options, "source_options are required")
seen_options = set()
for option in source_options:
    req_keys(option, {"option", "reliability", "privacy", "tos_risk", "implementation_effort", "approval_status"}, "source option")
    name = option.get("option")
    req(name in expected_options, f"unexpected source option: {name}")
    req(name not in seen_options, f"duplicate source option: {name}")
    seen_options.add(name)
    req(option.get("reliability") in {"low", "medium", "medium-high", "high"}, f"{name} invalid reliability")
    req(option.get("privacy") in {"low", "medium", "high"}, f"{name} invalid privacy")
    req(option.get("tos_risk") in {"low", "medium", "high"}, f"{name} invalid ToS risk")
    req(option.get("implementation_effort") in {"low", "medium", "high"}, f"{name} invalid effort")
    req(option.get("approval_status") == expected_source_approval_status[name], f"{name} approval status must be {expected_source_approval_status[name]}")
req(seen_options == expected_options, "source option matrix incomplete")

snapshots = data.get("normalized_snapshots") or []
req(isinstance(snapshots, list) and len(snapshots) >= 2, "at least LinkedIn and X snapshots are required")
networks = set()
ledger_ids = set()
for snapshot in snapshots:
    req_keys(snapshot, {"snapshot_id", "project", "network", "strategy_namespace_key", "content_ledger_namespace_key", "network_namespace_key", "source_type", "source_approval_status", "captured_at", "snapshot_window", "metrics"}, "normalized snapshot")
    network = snapshot.get("network")
    networks.add(network)
    req(snapshot.get("project") == project_slug, "snapshot project mismatch")
    req(snapshot.get("strategy_namespace_key") == strategy_namespace, "snapshot strategy namespace mismatch")
    req(snapshot.get("content_ledger_namespace_key") == content_ledger_namespace, "snapshot content-ledger namespace mismatch")
    req(snapshot.get("network_namespace_key") == f"discord-project-manager/project/{project_slug}/network/{network}", "snapshot network namespace mismatch")
    req(snapshot.get("source_type") == "manual-sanitized-entry", "repository fake analytics snapshots must use manual sanitized entry")
    req(snapshot.get("source_approval_status") == "approved-for-fake-fixtures", "repository fake snapshots must not use pending or separately approved sources")
    captured_at = parse_ts(snapshot.get("captured_at"), "captured_at")
    window = snapshot.get("snapshot_window") or {}
    req_keys(window, {"start", "end"}, "snapshot_window")
    window_start = parse_date(window.get("start"), "snapshot_window.start")
    window_end = parse_date(window.get("end"), "snapshot_window.end")
    req(window_start <= window_end, "snapshot_window.start must be on or before snapshot_window.end")
    req(captured_at.date() >= window_end, "captured_at date must be on or after snapshot_window.end")
    metrics = snapshot.get("metrics") or []
    req(metrics, "snapshot metrics are required")
    for metric in metrics:
        req_keys(metric, {"content_ledger_entry_id", "planning_reference_id", "published_at", "values"}, "metric")
        ledger_id = metric.get("content_ledger_entry_id")
        req(isinstance(ledger_id, str) and ledger_id.endswith("-demo"), "metrics must join through safe demo content_ledger_entry_id")
        ledger_ids.add(ledger_id)
        req(metric.get("planning_reference_id"), "planning_reference_id required")
        published_at = parse_ts(metric.get("published_at"), "metric.published_at")
        req(published_at <= captured_at, "metric.published_at must be on or before captured_at")
        req(window_start <= published_at.date() <= window_end, "metric.published_at date must be within snapshot_window")
        values = metric.get("values") or {}
        required_metric_keys = REQUIRED_METRICS_BY_NETWORK.get(network)
        req(required_metric_keys, f"unsupported normalized snapshot network: {network}")
        actual_metric_keys = set(values)
        req(actual_metric_keys == required_metric_keys, f"{network} metrics must be exactly: {', '.join(sorted(required_metric_keys))}")
        for key, value in values.items():
            validate_metric_value(network, key, value)
req({"linkedin", "x"}.issubset(networks), "normalized snapshots must include LinkedIn and X")
req({"linkedin-post-001-demo", "x-post-001-demo"}.issubset(ledger_ids), "expected ledger demo joins missing")

trend_signals = data.get("trend_signals") or []
req(isinstance(trend_signals, list) and trend_signals, "trend_signals are required")
for trend in trend_signals:
    req_keys(trend, {"trend_id", "project", "strategy_namespace_key", "network_scope", "source_type", "provenance", "observed_at", "confidence", "signal_summary"}, "trend signal")
    req(trend.get("project") == project_slug, "trend project mismatch")
    req(trend.get("strategy_namespace_key") == strategy_namespace, "trend strategy namespace mismatch")
    req(trend.get("source_type") in {"rss", "web", "search", "trend-provider", "manual-sanitized-entry"}, "invalid trend source_type")
    parse_ts(trend.get("observed_at"), "trend.observed_at")
    confidence = trend.get("confidence")
    req(not isinstance(confidence, bool) and isinstance(confidence, (int, float)) and 0 <= confidence <= 1, "trend confidence must be numeric between 0 and 1")
    req(trend.get("network_scope") and set(trend.get("network_scope")).issubset({"linkedin", "x"}), "trend network_scope invalid")
    req(trend.get("signal_summary") and len(trend.get("signal_summary")) <= SIGNAL_SUMMARY_MAX_CHARS, "trend signal_summary must be bounded")
    prov = trend.get("provenance") or {}
    req_keys(prov, {"source_kind", "retrieved_by", "retrieval_mode", "canonical_url", "source_title"}, "trend provenance")
    for field in ["source_kind", "retrieved_by", "retrieval_mode", "canonical_url", "source_title"]:
        req(prov.get(field), f"trend provenance missing {field}")
    req(prov.get("source_kind") in {"rss-feed", "webpage", "search-result", "trend-report", "manual-note"}, "invalid provenance source_kind")
    req(prov.get("retrieval_mode") == "fake-fixture-no-network", "trend retrieval must be fake/no-network")
    req(str(prov.get("canonical_url", "")).startswith("https://example.invalid/"), "trend canonical_url must be example.invalid")

metadata = data.get("metadata") or {}
req_keys(metadata, {"fixture_type", "safe_for_repo", "note"}, "metadata")
req(metadata.get("fixture_type") == "fake-demo", "metadata.fixture_type must be fake-demo")
req(metadata.get("safe_for_repo") is True, "metadata.safe_for_repo must be true")

unsafe_patterns = [
    r"\b[0-9]{17,20}\b",
    r"BUFFER_[A-Z0-9_]+",
    r"DISCORD_[A-Z0-9_]+",
    r"OPENAI_[A-Z0-9_]+",
    r"ANTHROPIC_[A-Z0-9_]+",
    r"GITHUB_TOKEN",
    r"ENGRAM_[A-Z0-9_]+",
    r"sk-[A-Za-z0-9_]+",
    r"gh[pousr]_[A-Za-z0-9_]+",
    r"xox[baprs]-[A-Za-z0-9_-]+",
    r"https?://(localhost|127\.0\.0\.1|discord\.com|notion\.so|api\.|www\.)",
    r"/home/|/Users/",
    r"production-ready|live fetching passed|live scraping passed|live API validated|browser automation validated|uses production credentials",
    r"live scraping is enabled|live api ingestion is enabled|browser automation is enabled|uses live scraping|uses live api ingestion|uses browser automation",
]
unsafe_pattern_self_checks = [
    (r"\b[0-9]{17,20}\b", "123456789" + "012345678"),
    (r"BUFFER_[A-Z0-9_]+", "BUFFER_TOKEN"),
    (r"https?://(localhost|127\.0\.0\.1|discord\.com|notion\.so|api\.|www\.)", "https://discord" + ".com/channels/123"),
    (r"production-ready|live fetching passed|live scraping passed|live API validated|browser automation validated|uses production credentials", "live scraping passed"),
    (r"live scraping is enabled|live api ingestion is enabled|browser automation is enabled|uses live scraping|uses live api ingestion|uses browser automation", "live scraping is enabled"),
]
for pattern, sample in unsafe_pattern_self_checks:
    req(re.search(pattern, sample, re.IGNORECASE), f"unsafe pattern self-check failed: {pattern}")
for pattern in unsafe_patterns:
    req(not re.search(pattern, text, re.IGNORECASE), f"unsafe fixture marker matched: {pattern}")
for url in re.findall(r"https?://[^\s<>\'\")\]}]+", text):
    req(url.startswith("https://example.invalid/"), f"non-demo fixture URL found: {url}")

for marker in [
    "Source option matrix",
    "Normalized snapshot schema",
    "Strategy skills consume",
    "not implement live scraping",
    "not approved",
    "content_ledger_entry_id",
    "provenance",
    "confidence",
]:
    req(marker in doc, f"doc missing marker: {marker}")

for skill_path in skill_paths:
    skill = skill_path.read_text()
    for marker in [
        "normalized_snapshots",
        "trend_signals",
        "content_ledger_entry_id",
        "unknown",
        "provenance",
        "confidence",
        "Do not consume raw scraped pages",
        "Do not claim live browser/API scraping",
    ]:
        req(marker in skill, f"{skill_path} missing skill contract marker: {marker}")

print("PyYAML schema validation passed.")
PY

for required in \
  "contract: social-strategy-analytics-trends-ingestion" \
  "fake: true" \
  "safe_for_repo: true" \
  "live_scraping_enabled: false" \
  "browser_automation_enabled: false" \
  "network: linkedin" \
  "network: x" \
  "content_ledger_entry_id: linkedin-post-001-demo" \
  "content_ledger_entry_id: x-post-001-demo" \
  "source_type: web" \
  "source_type: rss" \
  "retrieval_mode: fake-fixture-no-network"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "fixture missing marker: $required"
done

echo "Validated fake social strategy analytics/trends ingestion contract."
echo "Fixture: $FIXTURE_PATH"
echo "Doc: $DOC_PATH"
echo "Project: $PROJECT_SLUG"
