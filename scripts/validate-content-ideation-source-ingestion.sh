#!/usr/bin/env bash
set -euo pipefail

FIXTURE_PATH="${CONTENT_IDEATION_SOURCE_INGESTION_FIXTURE:-examples/content-ideation-source-ingestion.fake.yaml}"
DOC_PATH="docs/operations/content-ideation-source-ingestion-flow.md"
INVENTORY_PATH="docs/research/openclaw-runtime-capability-inventory.md"
RUNTIME_NAMESPACE="discord-project-manager/runtime/discord/<guild-id>/<channel-id>"

fail() { echo "ERROR: $*" >&2; exit 1; }
command -v grep >/dev/null 2>&1 || fail "required command not found: grep"
command -v python3 >/dev/null 2>&1 || fail "required command not found: python3"
for path in "$FIXTURE_PATH" "$DOC_PATH" "$INVENTORY_PATH"; do [[ -f "$path" ]] || fail "required file not found: $path"; done

python3 - "$FIXTURE_PATH" "$DOC_PATH" "$INVENTORY_PATH" "$RUNTIME_NAMESPACE" <<'PY'
import sys
from pathlib import Path
fixture_path, doc_path, inventory_path = map(Path, sys.argv[1:4])
runtime_ns = sys.argv[4]
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
inv = inventory_path.read_text()
def req(ok, msg):
    if not ok:
        raise ValueError(msg)
req(data.get("schema_version") == 1, "schema_version must be 1")
req(data.get("contract") == "content-ideation-source-ingestion", "wrong contract")
false_flags = ["live_source_fetching", "live_discord_connection", "live_openclaw_execution", "live_engram_calls", "notion_dependency", "plugin_install_enabled", "plugin_enable_enabled", "publishing_enabled", "scheduling_enabled", "queue_execution_enabled", "durable_memory_writes_allowed", "workspace_file_writes_allowed", "uses_real_discord_ids", "credential_material_included", "raw_source_dumps_included", "private_source_urls_in_repo"]
for flag in false_flags:
    req(data.get(flag) is False, f"{flag} must be false")
limits = data.get("limits") or {}
max_items, max_chars, max_signals = limits.get("max_items_per_source"), limits.get("max_summary_chars"), limits.get("max_signals_per_item")
req(all(isinstance(v, int) and v > 0 for v in [max_items, max_chars, max_signals]), "limits must be positive integers")
sources = ((data.get("source_registry") or {}).get("sources") or [])
keys, kinds, counts, source_by_key = set(), set(), {}, {}
for source in sources:
    key, kind = source.get("source_key"), source.get("source_kind")
    req(key and key not in keys, "source_key must be unique")
    keys.add(key); kinds.add(kind); source_by_key[key] = source
    req(kind in {"rss-feed", "webpage"}, "invalid source_kind")
    req(source.get("sensitivity") in {"public-demo", "public", "private-runtime"}, "invalid sensitivity")
    req(source.get("url_policy") == "fake-demo-url-only", "repo URLs must be demo-only")
    req(str(source.get("url", "")).startswith("https://example.invalid/"), "fixture URL must use example.invalid")
    if kind == "rss-feed":
        req(source.get("adapter_preference") == "pending-rss-plugin-spike", "RSS adapter choice must remain pending")
        req(source.get("retrieval_adapter") == "fake-rss-fixture-adapter", "RSS fixture retrieval adapter must be explicit")
        for candidate in source.get("rss_plugin_candidates") or []:
            req(candidate in inv, f"inventory missing RSS candidate: {candidate}")
    if kind == "webpage":
        req(source.get("adapter_preference") == "web-readability", "webpage adapter must prefer web-readability")
        req(source.get("retrieval_adapter") == "web-readability", "webpage retrieval adapter must be web-readability")
req({"rss-feed", "webpage"}.issubset(kinds), "RSS and webpage sources required")
retrieval_plan = data.get("retrieval_plan") or {}
req(retrieval_plan.get("retrieval_mode") == "fake-fixture-no-network", "retrieval_plan must be fake/no-network")
allowed_capabilities = set(retrieval_plan.get("allowed_capabilities") or [])
excluded_capabilities = set(retrieval_plan.get("excluded_capabilities") or [])
req(allowed_capabilities == {"web-readability", "fake-rss-fixture-adapter"}, "retrieval_plan allowed_capabilities must be closed and read-only")
req(excluded_capabilities == {"live-fetch", "plugin-install", "plugin-enable", "notion-api"}, "retrieval_plan excluded_capabilities must be exact")
req(allowed_capabilities.isdisjoint(excluded_capabilities), "retrieval_plan cannot allow excluded capabilities")
item_ids = set()
for item in data.get("normalized_items") or []:
    item_id = item.get("item_id")
    req(item_id and item_id not in item_ids, "item_id must be present and unique")
    item_ids.add(item_id)
    ref = item.get("source_ref"); counts[ref] = counts.get(ref, 0) + 1
    req(ref in keys, "item source_ref not registered")
    source = source_by_key[ref]
    req(0 < len(item.get("summary", "")) <= max_chars, "summary not bounded")
    req(0 < len(item.get("ideation_signals") or []) <= max_signals, "signals not bounded")
    prov = item.get("provenance") or {}; bounds = item.get("content_boundaries") or {}
    for field in ["source_kind", "retrieved_by", "retrieval_mode", "canonical_url", "source_title"]:
        req(prov.get(field), f"provenance missing {field}")
    req(prov.get("source_kind") == source.get("source_kind"), "provenance source_kind must match registered source")
    req(prov.get("retrieved_by") == source.get("retrieval_adapter"), "provenance retrieved_by must match source retrieval_adapter")
    req(prov.get("retrieval_mode") == "fake-fixture-no-network", "retrieval must be fake")
    req(str(prov.get("canonical_url", "")).startswith("https://example.invalid/"), "canonical_url must be demo")
    req(all(bounds.get(k) is False for k in ["raw_dump_included", "private_payload_included", "durable_write_executed"]), "unsafe boundary flag")
req(counts and all(v <= max_items for v in counts.values()), "items per source exceed limit")
statuses = data.get("source_statuses") or []
status_refs = set()
for status in statuses:
    ref = status.get("source_ref")
    req(ref in keys and ref not in status_refs, "source_status source_ref must be unique and registered")
    status_refs.add(ref)
    source = source_by_key[ref]
    req(status.get("source_kind") == source.get("source_kind"), "source_status source_kind must match registered source")
    req(status.get("retrieved_by") == source.get("retrieval_adapter"), "source_status retrieved_by must match source retrieval_adapter")
    req(status.get("retrieval_mode") == "fake-fixture-no-network", "source_status retrieval must be fake")
    state = status.get("status")
    emitted = status.get("items_emitted")
    req(state in {"succeeded", "partial", "failed"}, "invalid source_status status")
    req(isinstance(emitted, int) and 0 <= emitted <= max_items, "source_status items_emitted out of bounds")
    req(emitted == counts.get(ref, 0), "source_status items_emitted must match normalized item count")
    req(status.get("durable_write_executed") is False, "source_status durable writes must be false")
    if state == "failed":
        req(emitted == 0, "failed source must emit zero items")
    if state in {"partial", "failed"}:
        req(status.get("failure_reason") and status.get("isolated") is True, "partial or failed source must include isolated failure_reason")
req(status_refs == keys, "every source must have a source_status envelope")
req(any(s.get("status") == "partial" for s in statuses), "partial source status scenario required")
req(any(s.get("status") == "failed" for s in statuses), "failed source status scenario required")
route, approval = data.get("proposal_route") or {}, data.get("approval_request") or {}
targets = route.get("proposed_targets") or {}
networks = targets.get("network_namespace_keys") or {}
req(targets.get("strategy_namespace_key") == "discord-project-manager/project/egdev/strategy", "strategy target namespace mismatch")
req(targets.get("content_ledger_namespace_key") == "discord-project-manager/project/egdev/content-ledger", "content ledger target namespace mismatch")
expected_networks = {
    "youtube": "discord-project-manager/project/egdev/network/youtube",
    "twitch": "discord-project-manager/project/egdev/network/twitch",
    "stack-and-flow": "discord-project-manager/project/egdev/network/stack-and-flow",
}
req(networks == expected_networks, "network target namespaces must match expected project routes")
req({"strategy-planner", "on-demand-brief-planner"}.issubset(route.get("effective_skills") or []), "planning skills required")
req("discord-approval-gate" in (route.get("mandatory_skills") or []), "approval gate required")
req(route.get("write_mode") == "planned-only-until-approved", "write mode must be gated")
req(approval.get("state") == "approval-requested", "approval state must be approval-requested")
req(approval.get("runtime_context") == runtime_ns, "approval runtime_context mismatch")
req(approval.get("approval_phrase") == "approve write" and approval.get("write_executed") is False, "approval contract invalid")
req({"approve write", "reject"}.issubset(set(approval.get("reply_options") or [])), "approval reply_options must include approve write and reject")
risk_boundary = "\n".join(approval.get("risk_boundary") or [])
for marker in ["no durable memory writes", "no workspace file writes", "no publishing", "no live fetching"]:
    req(marker in risk_boundary, f"approval risk boundary missing {marker}")
for marker in ["RSS/feed URLs and webpage sources", "web-readability", "pending spike", "strategy-planner", "on-demand-brief-planner", "discord-approval-gate", "approve write", "No live fetching", "future optional adapter"]:
    req(marker in doc, f"doc missing marker: {marker}")
req(str(runtime_ns) in str(approval.get("runtime_audit_namespace")), "runtime namespace mismatch")
print("PyYAML schema validation passed.")
PY

for required in \
  "contract: content-ideation-source-ingestion" \
  "source_kind: rss-feed" \
  "source_kind: webpage" \
  "adapter_preference: pending-rss-plugin-spike" \
  "adapter_preference: web-readability" \
  "retrieval_mode: fake-fixture-no-network" \
  "approval_phrase: approve write" \
  "runtime_audit_namespace: $RUNTIME_NAMESPACE"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "fixture missing marker: $required"
done

review_paths=("$FIXTURE_PATH" "$DOC_PATH")
# Discord snowflake-like IDs are 17-20 digit decimal identifiers; repo fixtures must not contain them.
if grep -E '\b[0-9]{17,20}\b|BUFFER_[A-Z0-9_]+|DISCORD_[A-Z0-9_]+|OPENAI_[A-Z0-9_]+|ANTHROPIC_[A-Z0-9_]+|GITHUB_TOKEN|ENGRAM_[A-Z0-9_]+|sk-[A-Za-z0-9_]+|gh[pousr]_[A-Za-z0-9_]+|xox[baprs]-[A-Za-z0-9_-]+' "${review_paths[@]}" >/dev/null; then fail "credential or Discord ID marker found"; fi
if grep -E 'https?://(localhost|127\.0\.0\.1|discord\.com|notion\.so|api\.|www\.)|/home/|/Users/|production-ready|live fetching passed|live Discord validated|durable write executed|publishing completed|scheduling completed|uses production credentials' "${review_paths[@]}" >/dev/null; then fail "private path or live/prod claim found"; fi
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

echo "Validated fake content ideation source-ingestion contract."
echo "Fixture: $FIXTURE_PATH"
echo "Doc: $DOC_PATH"
echo "Runtime namespace contract: $RUNTIME_NAMESPACE"
