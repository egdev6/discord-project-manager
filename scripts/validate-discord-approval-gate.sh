#!/usr/bin/env bash
set -euo pipefail

FIXTURE_PATH="${DISCORD_APPROVAL_GATE_FIXTURE:-examples/discord-approval-gate.fake.yaml}"
SKILL_PATH="skills/discord-approval-gate/SKILL.md"
DOC_PATH="docs/operations/discord-approval-responses.md"
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
[[ -f "$SKILL_PATH" ]] || fail "skill not found: $SKILL_PATH"
[[ -f "$DOC_PATH" ]] || fail "approval response doc not found: $DOC_PATH"

for required in \
  "schema_version: 1" \
  "fixture_type: fake-demo" \
  "safe_for_repo: true" \
  "privacy_reviewed: true" \
  "contract: discord-approval-gate" \
  "live_discord_connection: false" \
  "live_engram_calls: false" \
  "live_openclaw_prompt_execution: false" \
  "runtime_enforcement_proven: false" \
  "uses_real_discord_ids: false" \
  "runtime_namespace_contract: $RUNTIME_NAMESPACE_CONTRACT" \
  "approval_phrase: approve write" \
  "state: approval-requested" \
  "persistent_writes_allowed: false" \
  "durable_project_writes_allowed: false" \
  "workspace_file_writes_allowed: false" \
  "memory_writes_allowed: false" \
  "ledger_writes_allowed: false" \
  "queue_writes_allowed: false" \
  "audit_trail_mode: response-local-until-decision" \
  "name: matched-route-save-request" \
  "name: matched-route-approve-write" \
  "name: invalid-approval-short" \
  "name: invalid-approval-case" \
  "name: invalid-approval-extra-text" \
  "name: invalid-approval-emoji" \
  "name: invalid-approval-silence" \
  "name: matched-route-revise" \
  "name: matched-route-reject" \
  "name: unmapped-route-write-request"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "fixture missing approval gate marker: $required"
done

for required in \
  "save" \
  "write" \
  "update" \
  "remember" \
  "store" \
  "queue" \
  "ledger" \
  "publish" \
  "schedule"; do
  grep -F "  - $required" "$FIXTURE_PATH" >/dev/null || fail "fixture missing write-like term: $required"
done

for required in \
  "Before explicit approval, do not call file, memory, ledger, queue, publishing, scheduling, or workspace persistence tools." \
  "Accept only the exact phrase \`approve write\` as approval." \
  "Keep the pre-approval audit trail in the response" \
  "$RUNTIME_NAMESPACE_CONTRACT"; do
  grep -F "$required" "$SKILL_PATH" >/dev/null || fail "skill missing enforcement rule: $required"
done

for required in \
  "## Runtime enforcement skill" \
  "skills/discord-approval-gate/SKILL.md" \
  "Before approval, the safe default is response-only" \
  "Reply with exactly one option:" \
  "Lifecycle validation fixture"; do
  grep -F "$required" "$DOC_PATH" >/dev/null || fail "approval doc missing enforcement marker: $required"
done

python3 - "$FIXTURE_PATH" "$RUNTIME_NAMESPACE_CONTRACT" <<'PY'
import sys
from pathlib import Path
import yaml

fixture = Path(sys.argv[1])
runtime = sys.argv[2]
data = yaml.safe_load(fixture.read_text())

false_flags = [
    "live_discord_connection",
    "live_engram_calls",
    "live_openclaw_prompt_execution",
    "runtime_enforcement_proven",
    "uses_real_discord_ids",
    "raw_discord_chat_logs_included",
    "raw_private_payload_included",
    "screenshots_included",
    "secrets_included",
]
for key in false_flags:
    if data.get(key) is not False:
        raise SystemExit(f"fixture must keep {key}: false")

if data.get("safe_for_repo") is not True or data.get("fixture_type") != "fake-demo":
    raise SystemExit("fixture must remain fake-demo and safe_for_repo")
if data.get("runtime_namespace_contract") != runtime:
    raise SystemExit("runtime namespace contract mismatch")
if data.get("approval_phrase") != "approve write":
    raise SystemExit("approval phrase must be exact")

required_terms = {"save", "write", "update", "remember", "store", "queue", "ledger", "publish", "schedule"}
if set(data.get("write_like_terms", [])) != required_terms:
    raise SystemExit("write-like terms drifted")

pre = data.get("pre_approval", {})
for key in [
    "persistent_writes_allowed",
    "durable_project_writes_allowed",
    "workspace_file_writes_allowed",
    "memory_writes_allowed",
    "ledger_writes_allowed",
    "queue_writes_allowed",
    "publishing_allowed",
    "scheduling_allowed",
]:
    if pre.get(key) is not False:
        raise SystemExit(f"pre-approval must keep {key}: false")
if pre.get("state") != "approval-requested" or pre.get("allowed_output") != "discord-response-only":
    raise SystemExit("pre-approval state/output mismatch")

scenarios = {item.get("name"): item for item in data.get("scenarios", [])}
required_scenarios = {
    "matched-route-save-request",
    "matched-route-approve-write",
    "invalid-approval-short",
    "invalid-approval-case",
    "invalid-approval-extra-text",
    "invalid-approval-emoji",
    "invalid-approval-silence",
    "matched-route-revise",
    "matched-route-reject",
    "unmapped-route-write-request",
}
if set(scenarios) != required_scenarios:
    raise SystemExit("approval lifecycle scenario coverage drifted")

save = scenarios["matched-route-save-request"]
if save.get("phase") != "pre-approval" or save.get("expected_state") != "approval-requested":
    raise SystemExit("save request must stop at approval-requested")
for key in ["writes_before_approval", "workspace_file_writes_before_approval", "memory_writes_before_approval"]:
    if save.get(key) is not False:
        raise SystemExit(f"save request must keep {key}: false")
if save.get("mandatory_skill") != "discord-approval-gate" or save.get("exact_approval_phrase_required") != "approve write":
    raise SystemExit("save request must require approval gate and exact phrase")
if save.get("runtime_audit_namespace") != runtime:
    raise SystemExit("save request runtime audit namespace mismatch")

approve = scenarios["matched-route-approve-write"]
if approve.get("phase") != "approved-write" or approve.get("expected_state") != "approved-for-write":
    raise SystemExit("approve scenario state mismatch")
if approve.get("prior_proposal_ref") != "matched-route-save-request":
    raise SystemExit("approve scenario must reference prior proposal")
if approve.get("approval_phrase_received") != "approve write":
    raise SystemExit("approve scenario must use exact approval phrase")
if approve.get("persistent_writes_allowed") is not True:
    raise SystemExit("approve scenario should allow the approved persistent write")
if approve.get("allowed_write_scope") != "displayed-target-only":
    raise SystemExit("approve scenario must limit write scope")
for key in ["workspace_file_writes_allowed", "publishing_allowed", "scheduling_allowed"]:
    if approve.get(key) is not False:
        raise SystemExit(f"approve scenario must keep {key}: false")
if approve.get("audit_record_required") is not True:
    raise SystemExit("approve scenario must require audit record")
for key in ["rollback_restore_hint_required", "backup_ref", "pre_change_snapshot_ref", "restore_command_ref", "verification_step", "owner_ref", "fix_forward_path"]:
    if key not in approve:
        raise SystemExit(f"approve scenario missing recovery field: {key}")
if approve.get("rollback_restore_hint_required") is not True:
    raise SystemExit("approve scenario must require rollback/restore hint")
if not str(approve.get("backup_ref", "")).startswith("private-backup://demo/"):
    raise SystemExit("approve scenario must include private backup ref")
if not str(approve.get("pre_change_snapshot_ref", "")).startswith("snapshot:"):
    raise SystemExit("approve scenario must include snapshot pre-change ref")
if approve.get("restore_command_ref") != "docs/security/data-handling.md#current-recovery-path":
    raise SystemExit("approve scenario must reference recovery path")
if not str(approve.get("verification_step", "")).strip() or "readback" not in str(approve.get("verification_step", "")):
    raise SystemExit("approve scenario must include concrete readback verification step")
if not str(approve.get("owner_ref", "")).startswith("operator-"):
    raise SystemExit("approve scenario must include sanitized operator owner ref")
if not str(approve.get("fix_forward_path", "")).strip() or "approval gate validation" not in str(approve.get("fix_forward_path", "")):
    raise SystemExit("approve scenario must include concrete fix-forward validation path")

for name in ["invalid-approval-short", "invalid-approval-case", "invalid-approval-extra-text", "invalid-approval-emoji", "invalid-approval-silence"]:
    invalid = scenarios[name]
    if invalid.get("phase") != "invalid-approval" or invalid.get("expected_state") != "approval-requested":
        raise SystemExit(f"invalid approval scenario must stay approval-requested: {name}")
    if invalid.get("valid_approval_phrase") is not False:
        raise SystemExit(f"invalid approval phrase must be marked invalid: {name}")
    if invalid.get("persistent_writes_allowed") is not False or invalid.get("writes_after_invalid_approval") is not False:
        raise SystemExit(f"invalid approval must not write: {name}")
    if invalid.get("approval_phrase_received") == "approve write":
        raise SystemExit(f"invalid scenario must not use exact approval phrase: {name}")

revise = scenarios["matched-route-revise"]
if revise.get("phase") != "revision" or revise.get("expected_state") != "approval-requested":
    raise SystemExit("revise scenario must return to approval-requested")
if revise.get("writes_after_revision") is not False or revise.get("revised_proposal_required") is not True:
    raise SystemExit("revise scenario must forbid writes and require revised proposal")

reject = scenarios["matched-route-reject"]
if reject.get("phase") != "rejection" or reject.get("expected_state") != "rejected":
    raise SystemExit("reject scenario mismatch")
if reject.get("writes_after_reject") is not False or reject.get("persistent_writes_allowed") is not False:
    raise SystemExit("reject scenario must forbid persistence")

unmapped = scenarios["unmapped-route-write-request"]
if unmapped.get("phase") != "needs-route" or unmapped.get("expected_state") != "needs-route":
    raise SystemExit("unmapped scenario mismatch")
if unmapped.get("target_namespace") != "none" or unmapped.get("durable_reads_allowed") is not False:
    raise SystemExit("unmapped scenario must not target or read durable memory")
if unmapped.get("writes_before_approval") is not False or unmapped.get("persistent_writes_allowed") is not False:
    raise SystemExit("unmapped scenario must forbid writes")
PY

if grep -E '\b[0-9]{17,20}\b' "$FIXTURE_PATH" "$SKILL_PATH" >/dev/null; then
  fail "approval gate artifacts must not expose raw Discord snowflake-like IDs"
fi

if grep -E 'BUFFER_[A-Z0-9_]+|DISCORD_[A-Z0-9_]+|OPENAI_[A-Z0-9_]+|ANTHROPIC_[A-Z0-9_]+|GITHUB_TOKEN|ENGRAM_[A-Z0-9_]+' "$FIXTURE_PATH" "$SKILL_PATH" >/dev/null; then
  fail "approval gate artifacts must not contain credential variable names"
fi

if grep -E 'live_discord_connection: true|live_engram_calls: true|live_openclaw_prompt_execution: true|runtime_enforcement_proven: true|uses_real_discord_ids: true|raw_discord_chat_logs_included: true|raw_private_payload_included: true|screenshots_included: true|secrets_included: true|workspace_file_writes_allowed: true|workspace_file_writes_before_approval: true|memory_writes_before_approval: true|writes_before_approval: true|publishing_allowed: true|scheduling_allowed: true|live approval enforcement passed|production-ready' "$FIXTURE_PATH" "$DOC_PATH" >/dev/null; then
  fail "approval gate artifacts must not claim live enforcement, production readiness, or pre-approval writes"
fi

echo "Validated fake Discord approval gate contract."
echo "Fixture: $FIXTURE_PATH"
echo "Skill: $SKILL_PATH"
echo "Contract doc: $DOC_PATH"
echo "Runtime namespace contract: $RUNTIME_NAMESPACE_CONTRACT"
