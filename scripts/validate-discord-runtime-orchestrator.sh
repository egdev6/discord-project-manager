#!/usr/bin/env bash
set -euo pipefail

FIXTURE_PATH="${DISCORD_RUNTIME_ORCHESTRATOR_FIXTURE:-examples/discord-runtime-orchestrator.fake.yaml}"
DOC_PATH="docs/architecture/discord-runtime-orchestrator.md"
ARTIFACT_DOC_PATH="docs/architecture/openclaw-artifact-classification.md"
PARENT_DOC_PATH="docs/architecture/discord-dynamic-context-namespaces.md"
ROUTING_DOC_PATH="docs/operations/discord-routing.md"
CONFIG_README_PATH="openclaw/config/README.md"
RUNTIME_NAMESPACE_CONTRACT="discord-project-manager/runtime/discord/<guild-id>/<channel-id>"

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
[[ -f "$ARTIFACT_DOC_PATH" ]] || fail "artifact classification doc not found: $ARTIFACT_DOC_PATH"
[[ -f "$PARENT_DOC_PATH" ]] || fail "parent doc not found: $PARENT_DOC_PATH"
[[ -f "$ROUTING_DOC_PATH" ]] || fail "routing doc not found: $ROUTING_DOC_PATH"
[[ -f "$CONFIG_README_PATH" ]] || fail "config readme not found: $CONFIG_README_PATH"

for required in \
  "schema_version: 1" \
  "fixture_type: fake-demo" \
  "safe_for_repo: true" \
  "privacy_reviewed: true" \
  "contract: discord-runtime-orchestrator" \
  "live_discord_connection: false" \
  "live_engram_calls: false" \
  "live_prompt_execution: false" \
  "runtime_enforcement_proven: false" \
  "uses_real_discord_ids: false" \
  "workspace_file_writes_allowed: false" \
  "github_mutations_enabled: false" \
  "publishing_enabled: false" \
  "scheduling_enabled: false" \
  "buffer_activity_enabled: false" \
  "runtime_namespace_contract: $RUNTIME_NAMESPACE_CONTRACT" \
  "name: planning-content-flow" \
  "name: private-profile-create" \
  "name: private-profile-bind-shared" \
  "name: private-profile-channel-override" \
  "name: private-profile-clone" \
  "name: runtime-capability-filesystem" \
  "name: publication-flow-buffer" \
  "name: workflow-skill-proposal" \
  "name: sdd-dev-work-flow" \
  "name: clarification-fallback" \
  "family: planning_content" \
  "family: sdd_dev_work" \
  "family: clarification_needed" \
  "prompt_execution: none"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "fixture missing required marker: $required"
done

for required in \
  "artifact_type: workflow_skill" \
  "artifact_type: private_context" \
  "artifact_type: runtime_capability" \
  "artifact_type: publication_flow" \
  "artifact_type: sdd_dev_work" \
  "artifact_type: ephemeral_draft" \
  "persistence_target: repo" \
  "persistence_target: private-runtime" \
  "persistence_target: external-service" \
  "persistence_target: ephemeral" \
  "operation: create" \
  "operation: bind" \
  "operation: reference" \
  "operation: clone" \
  "writeback_policy: confirmation-required" \
  "exact_approval_phrase: approve write"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "fixture missing classification marker: $required"
done

for required in \
  "docs/architecture/channel-context-namespace-mapping.md" \
  "docs/architecture/openclaw-artifact-classification.md" \
  "docs/architecture/discord-memory-gateway.md" \
  "docs/architecture/discord-context-skill-packs.md" \
  "docs/architecture/discord-scoped-skills-registry.md" \
  "docs/adr/0001-runtime-boundary.md" \
  "skills/discord-approval-gate/SKILL.md"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "fixture missing dependency marker: $required"
done

for required in \
  "Orchestrator pipeline" \
  "Event envelope schema" \
  "Artifact classification" \
  "Intent families" \
  "Runner selection" \
  "Permission and confirmation gates" \
  "Execution metadata" \
  "docs/architecture/channel-context-namespace-mapping.md" \
  "docs/architecture/openclaw-artifact-classification.md" \
  "docs/architecture/discord-memory-gateway.md" \
  "docs/architecture/discord-context-skill-packs.md" \
  "docs/architecture/discord-scoped-skills-registry.md" \
  "skills/discord-approval-gate/SKILL.md" \
  "docs/adr/0001-runtime-boundary.md" \
  "Gentle SDD is one runner/backend for \`sdd_dev_work\`" \
  "GitHub mutations"; do
  grep -F "$required" "$DOC_PATH" >/dev/null || fail "doc missing required orchestrator marker: $required"
done

for required in \
  "OpenClaw artifact classification and persistence" \
  "artifact_type" \
  "persistence_target" \
  "private_context" \
  "runtime_capability" \
  "publication_flow" \
  "sdd_dev_work" \
  "ephemeral_draft"; do
  grep -F "$required" "$ARTIFACT_DOC_PATH" >/dev/null || fail "artifact classification doc missing marker: $required"
done

for required in \
  "#73 | OpenClaw Discord Runtime Orchestrator; see \`docs/architecture/discord-runtime-orchestrator.md\`. |" \
  "context pack -> skill pack -> intent -> runner"; do
  grep -F "$required" "$PARENT_DOC_PATH" >/dev/null || fail "parent doc missing orchestrator reference: $required"
done

grep -F "bash scripts/validate-discord-runtime-orchestrator.sh" "$ROUTING_DOC_PATH" >/dev/null || fail "routing doc missing orchestrator validator"
grep -F "examples/discord-runtime-orchestrator.fake.yaml" "$ROUTING_DOC_PATH" >/dev/null || fail "routing doc missing orchestrator fixture"
grep -F "docs/architecture/discord-runtime-orchestrator.md" "$CONFIG_README_PATH" >/dev/null || fail "config README missing orchestrator reference"

python3 - "$FIXTURE_PATH" "$RUNTIME_NAMESPACE_CONTRACT" <<'PY'
import sys
from pathlib import Path

fixture_path = Path(sys.argv[1])
runtime_contract = sys.argv[2]
lines = fixture_path.read_text().splitlines()
scenarios = []
current = None
section = None

for raw in lines:
    if raw.startswith("  - name:"):
        if current:
            scenarios.append(current)
        current = {"name": raw.split(":", 1)[1].strip(), "sections": {}, "lists": {}}
        section = None
        continue
    if not current:
        continue
    if raw.startswith("    ") and not raw.startswith("      ") and raw.rstrip().endswith(":"):
        section = raw.strip()[:-1]
        current["sections"].setdefault(section, {})
        continue
    if section and raw.startswith("      ") and ":" in raw:
        key, value = raw.strip().split(":", 1)
        current["sections"].setdefault(section, {})[key] = value.strip()
        continue
if current:
    scenarios.append(current)

if not scenarios:
    raise SystemExit("no scenarios found")

required_sections = {
    "event_envelope",
    "pack_refs",
    "artifact_classification",
    "intent_classification",
    "runner_selection",
    "permission_gate",
    "execution_metadata",
    "writeback_policy",
}
required_artifact_fields = {
    "artifact_type",
    "subtype",
    "operation",
    "persistence_target",
    "approval_required",
    "backup_required",
    "deployment_required",
    "runner_backend",
    "writeback_policy",
}

seen_artifact_types = set()
seen_persistence_targets = set()
seen_profile_ops = set()

for sc in scenarios:
    name = sc["name"]
    sections = sc["sections"]
    missing = required_sections - sections.keys()
    if missing:
        raise SystemExit(f"scenario {name} missing sections: {sorted(missing)}")

    event = sections["event_envelope"]
    artifact = sections["artifact_classification"]
    intent = sections["intent_classification"]
    runner = sections["runner_selection"]
    gate = sections["permission_gate"]
    exec_meta = sections["execution_metadata"]
    writeback = sections["writeback_policy"]

    if event.get("runtime_namespace") != runtime_contract:
        raise SystemExit(f"scenario {name} has wrong runtime namespace")
    if "routing_status" not in event or "network_slug" not in event:
        raise SystemExit(f"scenario {name} missing route status or network slug")
    if exec_meta.get("prompt_execution") != "none":
        raise SystemExit(f"scenario {name} must keep prompt_execution: none")

    missing_artifact = required_artifact_fields - artifact.keys()
    if missing_artifact:
        raise SystemExit(f"scenario {name} missing artifact classification fields: {sorted(missing_artifact)}")

    seen_artifact_types.add(artifact["artifact_type"])
    seen_persistence_targets.add(artifact["persistence_target"])
    if artifact.get("artifact_type") == "private_context":
        seen_profile_ops.add(artifact.get("operation"))
        if artifact.get("persistence_target") != "private-runtime":
            raise SystemExit(f"private context scenario {name} must target private-runtime")
        if artifact.get("approval_required") != "true" or artifact.get("backup_required") != "true":
            raise SystemExit(f"private context scenario {name} must require approval and backup")

    write_like_ops = {"create", "update", "bind", "reference", "unbind", "clone", "execute", "handoff"}
    is_write_like = intent.get("write_like") == "true" or artifact.get("operation") in write_like_ops or artifact.get("approval_required") == "true"
    if is_write_like:
        if gate.get("state") != "approval-requested" or gate.get("approval_needed") != "true":
            raise SystemExit(f"write-like scenario {name} must request approval")
        if gate.get("required_skill") != "discord-approval-gate":
            raise SystemExit(f"write-like scenario {name} must require discord-approval-gate")
        if gate.get("exact_approval_phrase") != "approve write":
            raise SystemExit(f"write-like scenario {name} must require exact approve write phrase")
        if artifact.get("approval_required") != "true":
            raise SystemExit(f"write-like scenario {name} must set approval_required: true")
        if artifact.get("persistence_target") in {"private-runtime", "external-service"} and writeback.get("classification") != "confirmation-required":
            raise SystemExit(f"write-like private/external scenario {name} must use confirmation-required writeback")
    if artifact.get("deployment_required") == "true":
        if "deployment_step" not in exec_meta or "validated_runtime_version_ref" not in exec_meta:
            raise SystemExit(f"deployment-required scenario {name} must include deployment step and runtime version refs")

    if artifact.get("runner_backend") != runner.get("backend"):
        raise SystemExit(f"scenario {name} artifact runner_backend must match runner backend")

    if name == "planning-content-flow":
        if intent.get("family") != "planning_content" or runner.get("backend") != "openclaw-skill-surface" or runner.get("runner_kind") != "content-planner" or gate.get("state") != "summary-only" or gate.get("approval_needed") != "false" or writeback.get("classification") != "draft":
            raise SystemExit("planning-content-flow contract markers are inconsistent")
    if name == "sdd-dev-work-flow":
        if intent.get("family") != "sdd_dev_work" or runner.get("backend") != "gentle-sdd" or runner.get("runner_kind") != "development-orchestrator" or runner.get("backend_mode") != "delegated-contract-only" or gate.get("state") != "approval-requested" or writeback.get("classification") != "draft":
            raise SystemExit("sdd-dev-work-flow must be routed to gentle-sdd as delegated contract-only with approval before repo/deployment work")
    if name == "clarification-fallback":
        if intent.get("family") != "clarification_needed" or runner.get("backend") != "response-only" or runner.get("runner_kind") != "clarification" or gate.get("state") != "needs-route" or writeback.get("classification") != "reject":
            raise SystemExit("clarification-fallback must stay response-only with needs-route and reject writeback")

required_types = {"workflow_skill", "private_context", "runtime_capability", "publication_flow", "sdd_dev_work", "ephemeral_draft"}
missing_types = required_types - seen_artifact_types
if missing_types:
    raise SystemExit(f"fixture missing artifact types: {sorted(missing_types)}")

required_targets = {"repo", "private-runtime", "external-service", "ephemeral"}
missing_targets = required_targets - seen_persistence_targets
if missing_targets:
    raise SystemExit(f"fixture missing persistence targets: {sorted(missing_targets)}")

required_profile_ops = {"create", "bind", "reference", "clone"}
missing_profile_ops = required_profile_ops - seen_profile_ops
if missing_profile_ops:
    raise SystemExit(f"fixture missing private profile operations: {sorted(missing_profile_ops)}")
PY

review_paths=("$FIXTURE_PATH" "$DOC_PATH" "$ARTIFACT_DOC_PATH" "$PARENT_DOC_PATH" "$ROUTING_DOC_PATH" "$CONFIG_README_PATH")

if grep -E '\b[0-9]{17,20}\b' "${review_paths[@]}" >/dev/null; then
  fail "artifacts must not expose raw Discord snowflake-like IDs"
fi

if grep -E 'BUFFER_[A-Z0-9_]+|DISCORD_[A-Z0-9_]+|OPENAI_[A-Z0-9_]+|ANTHROPIC_[A-Z0-9_]+|GITHUB_TOKEN|ENGRAM_[A-Z0-9_]+' "${review_paths[@]}" >/dev/null; then
  fail "artifacts must not contain credential variable names"
fi

if grep -E 'live_discord_connection: true|live_engram_calls: true|live_prompt_execution: true|runtime_enforcement_proven: true|uses_real_discord_ids: true|workspace_file_writes_allowed: true|github_mutations_enabled: true|publishing_enabled: true|scheduling_enabled: true|buffer_activity_enabled: true|production-ready|public Discord validation passed|live Discord validation passed|live Engram calls enabled|prompt execution proven|sdd execution proven|GitHub mutation executed|uses production credentials|production credentials enabled' "${review_paths[@]}" >/dev/null; then
  fail "artifacts must not claim live, production, mutation, persistence, publishing, scheduling, or prompt execution behavior"
fi

echo "Validated fake Discord runtime orchestrator contract."
echo "Fixture: $FIXTURE_PATH"
echo "Doc: $DOC_PATH"
echo "Artifact classification doc: $ARTIFACT_DOC_PATH"
echo "Parent doc: $PARENT_DOC_PATH"
echo "Routing doc: $ROUTING_DOC_PATH"
echo "Config README: $CONFIG_README_PATH"
echo "Runtime namespace contract: $RUNTIME_NAMESPACE_CONTRACT"
