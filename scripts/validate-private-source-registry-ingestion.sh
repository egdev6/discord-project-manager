#!/usr/bin/env bash
set -euo pipefail

FIXTURE_PATH="${PRIVATE_SOURCE_REGISTRY_INGESTION_FIXTURE:-examples/private-source-registry-ingestion.fake.yaml}"
DOC_PATH="docs/operations/content-ideation-source-ingestion-flow.md"
RUNTIME_NAMESPACE_CONTRACT="discord-project-manager/runtime/source-registry/<operator-private-scope>"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found on PATH: $1"
}

require_cmd grep
require_cmd python3

[[ -f "$FIXTURE_PATH" ]] || fail "fixture not found: $FIXTURE_PATH"
[[ -f "$DOC_PATH" ]] || fail "doc not found: $DOC_PATH"

python3 - "$FIXTURE_PATH" "$DOC_PATH" "$RUNTIME_NAMESPACE_CONTRACT" <<'PY'
import sys
from pathlib import Path

fixture_path = Path(sys.argv[1])
doc_path = Path(sys.argv[2])
runtime_ns = sys.argv[3]

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
data = yaml.load(fixture_path.read_text(), Loader=Loader)
doc = doc_path.read_text()

def req(ok, msg):
    if not ok:
        raise ValueError(msg)

req(isinstance(data, dict), "fixture root must be a mapping")
req(data.get("schema_version") == 1, "schema_version must be 1")
req(data.get("fixture_type") == "fake-demo", "fixture_type must be fake-demo")
req(data.get("safe_for_repo") is True, "safe_for_repo must be true")
req(data.get("privacy_reviewed") is True, "privacy_reviewed must be true")
req(data.get("contract") == "private-source-registry-ingestion", "wrong contract")
req(data.get("issue") == 299, "issue must be 299")
req(data.get("project") == "egdev", "project must be egdev")
req(data.get("registry_first") is True, "registry_first must be true")
req(data.get("runtime_namespace_contract") == runtime_ns, "runtime namespace contract mismatch")

false_flags = [
    "live_source_fetching",
    "live_discord_connection",
    "live_openclaw_execution",
    "live_engram_calls",
    "notion_dependency",
    "plugin_install_enabled",
    "plugin_enable_enabled",
    "publishing_enabled",
    "scheduling_enabled",
    "queue_execution_enabled",
    "durable_memory_writes_allowed",
    "workspace_file_writes_allowed",
    "uses_real_discord_ids",
    "credential_material_included",
    "raw_source_dumps_included",
    "private_source_urls_in_repo",
]
for flag in false_flags:
    req(data.get(flag) is False, f"{flag} must be false")

limits = data.get("limits") or {}
expected_limits = {
    "max_items_per_source": 2,
    "max_summary_chars": 280,
    "max_signals_per_item": 3,
    "max_fetch_timeout_ms": 5000,
    "max_response_bytes": 1048576,
    "max_extracted_chars": 12000,
}
for key, expected in expected_limits.items():
    req(limits.get(key) == expected, f"limit mismatch for {key}")

registry = data.get("source_registry") or {}
req(registry.get("storage_policy") == "repo-safe-demo-only", "storage_policy must be repo-safe-demo-only")
private_policy = registry.get("private_runtime_policy") or ""
for marker in ["private source URLs", "credentials", "cookies", "headers", "outside git"]:
    req(marker in private_policy, f"private runtime policy missing {marker}")

baseline_kinds = set(registry.get("accepted_baseline_source_kinds") or [])
deferred_kinds = set(registry.get("deferred_private_source_kinds") or [])
req(baseline_kinds == {"manual-sanitized-entry", "rss-feed", "webpage"}, "baseline source kinds mismatch")
req(deferred_kinds == {"notion-page", "notion-database"}, "deferred source kinds mismatch")

sources = registry.get("sources") or []
req(len(sources) >= 4, "fixture must include baseline sources plus deferred Notion example")
keys = set()
source_by_key = {}
for source in sources:
    key = source.get("source_key")
    kind = source.get("source_kind")
    req(key and key not in keys, "source_key must be present and unique")
    keys.add(key)
    source_by_key[key] = source
    req(kind in baseline_kinds | deferred_kinds, f"invalid source_kind: {kind}")
    req(source.get("sensitivity") in {"public-demo", "public", "private-runtime"}, "invalid sensitivity")
    req(source.get("untrusted_content_policy") in {None, "wrap-as-source-material-not-instructions"}, "invalid untrusted content policy")
    if kind in baseline_kinds:
        req(source.get("url_policy") == "fake-demo-url-only", "baseline repo URL policy must be fake-demo-url-only")
        req(str(source.get("url", "")).startswith("https://example.invalid/"), "baseline URLs must use example.invalid")
        req(source.get("retrieval_adapter") in {"fake-manual-entry-fixture-adapter", "fake-rss-fixture-adapter", "web-readability"}, "baseline retrieval adapter must be allowed")
    if kind == "manual-sanitized-entry":
        req(source.get("adapter_preference") == "manual-sanitized-entry", "manual source adapter mismatch")
        req(source.get("retrieval_adapter") == "fake-manual-entry-fixture-adapter", "manual retrieval adapter mismatch")
    if kind == "rss-feed":
        req(source.get("adapter_preference") == "read-only-rss-feed-adapter", "RSS adapter mismatch")
        req(source.get("retrieval_adapter") == "fake-rss-fixture-adapter", "RSS retrieval adapter mismatch")
    if kind == "webpage":
        req(source.get("adapter_preference") == "web-readability", "webpage adapter mismatch")
        req(source.get("retrieval_adapter") == "web-readability", "webpage retrieval adapter mismatch")
    if kind in deferred_kinds:
        req(source.get("url") is None, "deferred private source must not include a repo URL")
        req(source.get("url_policy") == "private-runtime-config-only", "deferred source URL policy mismatch")
        req(source.get("retrieval_adapter") == "none-in-repo-fixture", "deferred source must not have an in-repo adapter")
        req(source.get("enabled_in_fixture") is False, "deferred source must be disabled in fixture")
        req("credentials" in (source.get("reason_deferred") or ""), "deferred source reason must mention credentials")

present_baseline = {s.get("source_kind") for s in sources if s.get("source_kind") in baseline_kinds}
req(present_baseline == baseline_kinds, "all baseline source kinds are required")
req("notion-page" in {s.get("source_kind") for s in sources}, "deferred notion-page source marker required")
req("notion-database" in deferred_kinds, "deferred notion-database marker required")

retrieval = data.get("retrieval_plan") or {}
req(retrieval.get("retrieval_mode") == "fake-fixture-no-network", "retrieval_mode must be fake-fixture-no-network")
allowed = set(retrieval.get("allowed_capabilities") or [])
excluded = set(retrieval.get("excluded_capabilities") or [])
req(allowed == {"fake-manual-entry-fixture-adapter", "fake-rss-fixture-adapter", "web-readability"}, "allowed capabilities mismatch")
req(excluded == {"live-fetch", "plugin-install", "plugin-enable", "notion-api", "browser-automation"}, "excluded capabilities mismatch")
req(allowed.isdisjoint(excluded), "allowed and excluded capabilities must not overlap")
url_safety = retrieval.get("url_safety") or {}
req(url_safety.get("ssrf_protection_required") is True, "SSRF protection marker required")
req(url_safety.get("allowed_fixture_hosts") == ["example.invalid"], "allowed fixture host must be example.invalid")
req(url_safety.get("reject_private_network_targets") is True, "private network targets must be rejected")
req(url_safety.get("reject_prompt_supplied_urls") is True, "prompt-supplied URLs must be rejected")
req(url_safety.get("max_redirects") == 0, "redirects must be disabled in fixture")
runtime_bounds = retrieval.get("runtime_bounds") or {}
for key in ["timeout_ms", "max_response_bytes", "max_extracted_chars"]:
    expected_key = "max_fetch_timeout_ms" if key == "timeout_ms" else key
    req(runtime_bounds.get(key) == expected_limits[expected_key], f"runtime bound mismatch for {key}")

statuses = data.get("source_statuses") or []
status_refs = set()
counts = {}
for item in data.get("normalized_items") or []:
    counts[item.get("source_ref")] = counts.get(item.get("source_ref"), 0) + 1
for status in statuses:
    ref = status.get("source_ref")
    req(ref in source_by_key and ref not in status_refs, "source status must refer to each registered baseline source once")
    status_refs.add(ref)
    source = source_by_key[ref]
    req(source.get("source_kind") in baseline_kinds, "deferred source must not have a retrieval status")
    req(status.get("source_kind") == source.get("source_kind"), "status source_kind mismatch")
    req(status.get("retrieved_by") == source.get("retrieval_adapter"), "status retrieval adapter mismatch")
    req(status.get("retrieval_mode") == "fake-fixture-no-network", "status retrieval must be fake")
    req(status.get("status") in {"succeeded", "partial", "failed"}, "invalid status value")
    req(status.get("items_emitted") == counts.get(ref, 0), "items_emitted must match normalized items")
    req(status.get("durable_write_executed") is False, "status durable write must be false")
    req(status.get("publish_or_schedule_executed") is False, "status publish/schedule must be false")
req(status_refs == {key for key, source in source_by_key.items() if source.get("source_kind") in baseline_kinds}, "every baseline source needs a status envelope")
req(all(status.get("status") == "succeeded" for status in statuses), "baseline fixture statuses must be succeeded")

items = data.get("normalized_items") or []
req(len(items) == 3, "fixture must include one normalized item for each baseline source")
item_ids = set()
for item in items:
    item_id = item.get("item_id")
    ref = item.get("source_ref")
    req(item_id and item_id not in item_ids, "item_id must be present and unique")
    item_ids.add(item_id)
    req(ref in source_by_key, "item source_ref must be registered")
    source = source_by_key[ref]
    req(source.get("source_kind") in baseline_kinds, "normalized item must use baseline source")
    summary = item.get("summary") or ""
    signals = item.get("ideation_signals") or []
    req(0 < len(summary) <= limits["max_summary_chars"], "summary must be bounded")
    req(0 < len(signals) <= limits["max_signals_per_item"], "signals must be bounded")
    prov = item.get("provenance") or {}
    for field in ["source_kind", "retrieved_by", "retrieval_mode", "canonical_url", "source_title"]:
        req(prov.get(field), f"provenance missing {field}")
    req(prov.get("source_kind") == source.get("source_kind"), "provenance source_kind mismatch")
    req(prov.get("retrieved_by") == source.get("retrieval_adapter"), "provenance retrieval adapter mismatch")
    req(prov.get("retrieval_mode") == "fake-fixture-no-network", "provenance retrieval must be fake")
    req(str(prov.get("canonical_url", "")).startswith("https://example.invalid/"), "canonical URL must use example.invalid")
    boundary = item.get("untrusted_content_boundary") or {}
    req(boundary.get("source_text_is_untrusted") is True, "source text must be marked untrusted")
    req(boundary.get("may_inform_summary_only") is True, "source text must be summary-only")
    req(boundary.get("may_not_instruct_tools") is True, "source text must not instruct tools")
    for flag in ["raw_dump_included", "private_payload_included", "durable_write_executed", "publish_or_schedule_executed"]:
        req(boundary.get(flag) is False, f"unsafe boundary flag must be false: {flag}")
req(all(count <= limits["max_items_per_source"] for count in counts.values()), "items per source exceed max_items_per_source")

route = data.get("proposal_route") or {}
req({"strategy-planner", "on-demand-brief-planner"}.issubset(route.get("effective_skills") or []), "proposal route planning skills missing")
req("discord-approval-gate" in (route.get("mandatory_skills") or []), "proposal route approval gate missing")
req(route.get("write_mode") == "planned-only-until-approved", "proposal route must be planned-only")
for flag in ["write_executed", "publishing_enabled", "scheduling_enabled", "queue_execution_enabled"]:
    req(route.get(flag) is False, f"proposal route flag must be false: {flag}")

non_goals = set(data.get("non_goals") or [])
for marker in [
    "live source fetching",
    "Notion API calls or dependency",
    "validator implementation",
    "plugin installation or enablement",
    "durable storage",
    "publishing",
    "scheduling",
    "production credentials",
]:
    req(marker in non_goals, f"non-goal missing: {marker}")

for marker in [
    "Issue #299",
    "registry-first private read-only baseline",
    "manual-sanitized-entry",
    "rss-feed",
    "webpage",
    "notion-page",
    "notion-database",
    "fake/demo URLs",
    "fake-fixture-no-network",
    "SSRF-safe",
    "planned-only-until-approved",
    "discord-approval-gate",
    "approve write",
    "No private source URLs",
]:
    req(marker in doc, f"doc missing #299 marker: {marker}")

print("PyYAML private source registry validation passed.")
PY

for required in \
  "schema_version: 1" \
  "fixture_type: fake-demo" \
  "contract: private-source-registry-ingestion" \
  "issue: 299" \
  "registry_first: true" \
  "live_source_fetching: false" \
  "live_discord_connection: false" \
  "live_openclaw_execution: false" \
  "live_engram_calls: false" \
  "notion_dependency: false" \
  "plugin_install_enabled: false" \
  "plugin_enable_enabled: false" \
  "publishing_enabled: false" \
  "scheduling_enabled: false" \
  "queue_execution_enabled: false" \
  "durable_memory_writes_allowed: false" \
  "workspace_file_writes_allowed: false" \
  "uses_real_discord_ids: false" \
  "credential_material_included: false" \
  "raw_source_dumps_included: false" \
  "private_source_urls_in_repo: false" \
  "runtime_namespace_contract: $RUNTIME_NAMESPACE_CONTRACT" \
  "source_kind: manual-sanitized-entry" \
  "source_kind: rss-feed" \
  "source_kind: webpage" \
  "source_kind: notion-page" \
  "retrieval_mode: fake-fixture-no-network" \
  "ssrf_protection_required: true" \
  "reject_private_network_targets: true" \
  "reject_prompt_supplied_urls: true" \
  "source_text_is_untrusted: true" \
  "may_not_instruct_tools: true" \
  "write_mode: planned-only-until-approved"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "fixture missing required marker: $required"
done

for required in \
  "Issue #299" \
  "registry-first private read-only baseline" \
  "manual-sanitized-entry" \
  "rss-feed" \
  "webpage" \
  "notion-page" \
  "notion-database" \
  "discord-approval-gate"; do
  grep -F "$required" "$DOC_PATH" >/dev/null || fail "doc missing #299 marker: $required"
done

review_paths=("$FIXTURE_PATH" "$DOC_PATH")

# Repo-safe fixtures/docs for this issue must not expose Discord snowflakes, obvious
# credential/token material, private/local URLs, raw dumps, or live/prod behavior claims.
if grep -E '\b[0-9]{17,20}\b|BUFFER_[A-Z0-9_]+|DISCORD_[A-Z0-9_]+|OPENAI_[A-Z0-9_]+|ANTHROPIC_[A-Z0-9_]+|GITHUB_TOKEN|ENGRAM_[A-Z0-9_]+|NOTION_[A-Z0-9_]+|sk-[A-Za-z0-9_]+|gh[pousr]_[A-Za-z0-9_]+|xox[baprs]-[A-Za-z0-9_-]+' "${review_paths[@]}" >/dev/null; then
  fail "credential, token, or Discord ID marker found"
fi

if grep -E 'https?://(localhost|127\.0\.0\.1|0\.0\.0\.0|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.|discord\.com|notion\.so|api\.|www\.)|/home/|/Users/|production-ready|live fetching passed|live Discord validated|live OpenClaw validated|live Engram validated|durable write executed|publishing completed|scheduling completed|queue execution completed|uses production credentials|raw source dump:' "${review_paths[@]}" >/dev/null; then
  fail "private URL/path, raw dump, or live/prod claim found"
fi

python3 - "${review_paths[@]}" <<'PY'
import re
import sys
from pathlib import Path

url_pattern = re.compile(r"https?://[^\s<>'\")\]}]+")
for raw_path in sys.argv[1:]:
    path = Path(raw_path)
    for line_no, line in enumerate(path.read_text().splitlines(), 1):
        for url in url_pattern.findall(line):
            if not url.startswith("https://example.invalid/"):
                raise SystemExit(f"ERROR: non-demo URL found: {path}:{line_no}: {url}")
PY

private_script_paths=(
  "scripts/private-test-notion-source-registry.sh"
  "scripts/private-test-notion-to-discord-response.sh"
  "scripts/private-test-notion-rss-reportability-to-discord.sh"
)

for script_path in "${private_script_paths[@]}"; do
  [[ -f "$script_path" ]] || fail "private rehearsal script missing: $script_path"
  [[ -x "$script_path" ]] || fail "private rehearsal script is not executable: $script_path"
done

for required in \
  "NOTION_API_KEY" \
  "NOTION_SOURCE_DATA_SOURCE_ID" \
  "raw Notion payload" \
  "no writes performed"; do
  grep -F "$required" scripts/private-test-notion-source-registry.sh >/dev/null || fail "Notion registry rehearsal missing marker: $required"
done

for required in \
  "DISCORD_BOT_TOKEN" \
  "DISCORD_TEST_CHANNEL_ID" \
  "sin escritura en memoria" \
  "sin ledger" \
  "sin publicar" \
  "sin agendar" \
  "payload crudo de Notion" \
  "allowed_mentions"; do
  grep -F "$required" scripts/private-test-notion-to-discord-response.sh >/dev/null || fail "Notion-to-Discord rehearsal missing marker: $required"
done

for required in \
  "SCORING_PROFILES_DATA_SOURCE_ID" \
  "SCORING_PROFILE_NAME" \
  "query_scoring_profiles" \
  "default_scoring_profile" \
  "normalize_thresholds" \
  "load_scoring_profile" \
  "score_item" \
  "reportable" \
  "watchlist" \
  "discard" \
  "ALLOWED_FEED_HOSTS" \
  "host_is_public" \
  "NoRedirectHandler" \
  "allowed_mentions" \
  "sin escritura en memoria" \
  "sin ledger" \
  "sin publicar" \
  "sin agendar" \
  "cuerpos RSS completos"; do
  grep -F "$required" scripts/private-test-notion-rss-reportability-to-discord.sh >/dev/null || fail "RSS reportability rehearsal missing marker: $required"
done

bash scripts/private-test-notion-rss-reportability-to-discord.sh --self-test >/dev/null || fail "dynamic scoring self-test failed"

if grep -E 'Bearer [A-Za-z0-9._~+/-]{20,}|secret_[A-Za-z0-9_/-]{12,}|ntn_[A-Za-z0-9_/-]{12,}|mka_[A-Za-z0-9_/-]{12,}|sk-[A-Za-z0-9_/-]{20,}|gh[pousr]_[A-Za-z0-9_/-]{20,}|xox[baprs]-[A-Za-z0-9_-]{20,}' "${private_script_paths[@]}" >/dev/null; then
  fail "private rehearsal scripts must not contain literal credential values"
fi

echo "Validated fake private source registry ingestion contract."
echo "Fixture: $FIXTURE_PATH"
echo "Doc: $DOC_PATH"
echo "Runtime namespace contract: $RUNTIME_NAMESPACE_CONTRACT"
