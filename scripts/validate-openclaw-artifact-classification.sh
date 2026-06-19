#!/usr/bin/env bash
set -euo pipefail

FIXTURE_PATH="${OPENCLAW_ARTIFACT_CLASSIFICATION_FIXTURE:-examples/openclaw-artifact-classification.fake.yaml}"
DOC_PATH="docs/architecture/openclaw-artifact-classification.md"
DATA_DOC="docs/security/data-handling.md"

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
[[ -f "$DATA_DOC" ]] || fail "data handling doc not found: $DATA_DOC"

for required in \
  "schema_version: 1" \
  "fixture_type: fake-demo" \
  "safe_for_repo: true" \
  "privacy_reviewed: true" \
  "contract: openclaw-artifact-classification" \
  "live_discord_connection: false" \
  "live_engram_calls: false" \
  "live_prompt_execution: false" \
  "uses_real_discord_ids: false" \
  "private_profile_content_included: false" \
  "secrets_included: false" \
  "workspace_file_writes_allowed: false" \
  "publishing_enabled: false" \
  "scheduling_enabled: false" \
  "buffer_activity_enabled: false" \
  "artifact_type: workflow_skill" \
  "artifact_type: private_context" \
  "artifact_type: runtime_capability" \
  "artifact_type: publication_flow" \
  "artifact_type: sdd_dev_work" \
  "artifact_type: ephemeral_draft" \
  "persistence_target: private-runtime" \
  "persistence_target: external-service" \
  "persistence_target: repo" \
  "persistence_target: ephemeral" \
  "approval_gate_required: true" \
  "idempotency_required: true" \
  "reconciliation_required: true" \
  "gentle_is_backend_only: true"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "fixture missing marker: $required"
done

for required in \
  "OpenClaw artifact classification and persistence" \
  "persistence_target" \
  "private_context" \
  "runtime_capability" \
  "publication_flow" \
  "sdd_dev_work" \
  "ephemeral_draft" \
  "runner_backend" \
  "External connector resilience" \
  "Current recovery path"; do
  grep -F "$required" "$DOC_PATH" "$DATA_DOC" >/dev/null || fail "docs missing marker: $required"
done

python3 - "$FIXTURE_PATH" <<'PY'
import sys
from pathlib import Path

lines = Path(sys.argv[1]).read_text().splitlines()
scenarios = []
current = None
in_classification = False
for raw in lines:
    if raw.startswith("  - name:"):
        if current:
            scenarios.append(current)
        current = {"name": raw.split(":", 1)[1].strip(), "classification": {}, "pairs": []}
        in_classification = False
        continue
    if not current:
        continue
    if raw.startswith("    classification:"):
        in_classification = True
        continue
    if raw.startswith("    safety:") or raw.startswith("    request_shape:"):
        in_classification = False
    if raw.startswith("      ") and ":" in raw:
        key, value = raw.strip().split(":", 1)
        current["pairs"].append((key, value.strip()))
        if in_classification:
            current["classification"][key] = value.strip()
if current:
    scenarios.append(current)

required_fields = {"artifact_type", "subtype", "operation", "persistence_target", "approval_required", "backup_required", "deployment_required", "runner_backend", "writeback_policy"}
for scenario in scenarios:
    missing = required_fields - scenario["classification"].keys()
    if missing:
        raise SystemExit(f"scenario {scenario['name']} missing classification fields: {sorted(missing)}")
    c = scenario["classification"]
    write_like_ops = {"create", "update", "bind", "reference", "unbind", "clone", "execute", "handoff"}
    if c["writeback_policy"] == "confirmation-required" and c["approval_required"] != "true":
        raise SystemExit(f"scenario {scenario['name']} confirmation-required must require approval")
    if c["operation"] in write_like_ops and c["approval_required"] != "true":
        raise SystemExit(f"scenario {scenario['name']} write-like operation must require approval")
    if c["artifact_type"] == "workflow_skill":
        if c["persistence_target"] != "repo" or c["approval_required"] != "true" or c["deployment_required"] != "true":
            raise SystemExit(f"scenario {scenario['name']} workflow_skill must target repo, require approval, and require deployment/review path")
        if c["runner_backend"] != "gentle-sdd" or c["writeback_policy"] != "draft":
            raise SystemExit(f"scenario {scenario['name']} workflow_skill must stay a gentle-sdd draft proposal before repo write")
        if not any(k == "repo_review_required" and v == "true" for k, v in scenario["pairs"]):
            raise SystemExit(f"scenario {scenario['name']} workflow_skill must require repo review in safety metadata")
    if c["artifact_type"] == "private_context" and (c["persistence_target"] != "private-runtime" or c["backup_required"] != "true"):
        raise SystemExit(f"scenario {scenario['name']} private context must target private-runtime and require backup")
    if c["artifact_type"] == "ephemeral_draft" and (c["persistence_target"] != "ephemeral" or c["approval_required"] != "false"):
        raise SystemExit(f"scenario {scenario['name']} ephemeral draft must not require durable persistence")

required_types = {"workflow_skill", "private_context", "runtime_capability", "publication_flow", "sdd_dev_work", "ephemeral_draft"}
seen = {s["classification"].get("artifact_type") for s in scenarios}
missing_types = required_types - seen
if missing_types:
    raise SystemExit(f"missing artifact type scenarios: {sorted(missing_types)}")
PY

review_paths=("$FIXTURE_PATH" "$DOC_PATH" "$DATA_DOC")

# Discord snowflakes are currently 17-20 digit decimal identifiers; public fixtures/docs must use placeholders instead.
if grep -E '\b[0-9]{17,20}\b' "${review_paths[@]}" >/dev/null; then
  fail "artifacts must not expose raw Discord snowflake-like IDs"
fi

if grep -E 'BUFFER_[A-Z0-9_]+|DISCORD_[A-Z0-9_]+|OPENAI_[A-Z0-9_]+|ANTHROPIC_[A-Z0-9_]+|GITHUB_TOKEN|ENGRAM_[A-Z0-9_]+' "$FIXTURE_PATH" "$DOC_PATH" >/dev/null; then
  fail "classification fixture/doc must not contain credential variable names"
fi

if grep -E 'live_discord_connection: true|live_engram_calls: true|live_prompt_execution: true|uses_real_discord_ids: true|private_profile_content_included: true|secrets_included: true|workspace_file_writes_allowed: true|publishing_enabled: true|scheduling_enabled: true|buffer_activity_enabled: true|production-ready|live Discord validation passed|production credentials enabled' "${review_paths[@]}" >/dev/null; then
  fail "artifacts must not claim live, production, persistence, publishing, scheduling, or private-data behavior"
fi

echo "Validated fake OpenClaw artifact classification contract."
echo "Fixture: $FIXTURE_PATH"
echo "Doc: $DOC_PATH"
