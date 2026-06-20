#!/usr/bin/env bash
set -euo pipefail

FIXTURE_PATH="${PRIVATE_RUNTIME_BACKUP_RESTORE_FIXTURE:-examples/private-runtime-backup-restore.fake.yaml}"
DOC_PATH="docs/operations/private-runtime-backup-restore.md"
DATA_DOC="docs/security/data-handling.md"
RESOLVER_DOC="docs/architecture/discord-effective-runtime-resolver.md"
AUDIT_DOC="docs/architecture/discord-durable-change-audit.md"
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

for path in "$FIXTURE_PATH" "$DOC_PATH" "$DATA_DOC" "$RESOLVER_DOC" "$AUDIT_DOC"; do
  [[ -f "$path" ]] || fail "required path not found: $path"
done

for required in \
  "schema_version: 1" \
  "fixture_type: fake-demo" \
  "safe_for_repo: true" \
  "privacy_reviewed: true" \
  "contract: private-runtime-backup-restore" \
  "live_discord_connection: false" \
  "live_engram_calls: false" \
  "live_postgres_dump: false" \
  "live_docker_restore: false" \
  "runtime_enforcement_proven: false" \
  "uses_real_discord_ids: false" \
  "raw_private_backup_included: false" \
  "raw_discord_chat_logs_included: false" \
  "private_profile_content_included: false" \
  "secrets_included: false" \
  "workspace_file_writes_allowed: false" \
  "publishing_enabled: false" \
  "scheduling_enabled: false" \
  "buffer_activity_enabled: false" \
  "runtime_namespace_contract: $RUNTIME_NAMESPACE_CONTRACT" \
  "artifact_type: private_context" \
  "persistence_target: private-runtime" \
  "approval_required: true" \
  "backup_required: true" \
  "profile_definitions: true" \
  "scope_bindings: true" \
  "overrides: true" \
  "disabled_bindings: true" \
  "capability_permissions: true" \
  "durable_audit_records: true" \
  "shared_profile_refs_preserved: true" \
  "capability_permissions_preserved: true" \
  "duplicate_profile_defs_created: false" \
  "writes_enabled_after_restore: false"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "fixture missing marker: $required"
done

for required in \
  "Private runtime backup and restore" \
  "Backup manifest shape" \
  "Restore validation shape" \
  "Restore invariants" \
  "capability_permissions_preserved" \
  "shared profile references" \
  "private-backup://demo"; do
  grep -F "$required" "$DOC_PATH" >/dev/null || fail "doc missing marker: $required"
done

for required in \
  "Current recovery path" \
  "REHEARSAL_PROJECT" \
  "pg_dump" \
  "psql" \
  "tar xzf" \
  "sanitized readback check"; do
  grep -F "$required" "$DATA_DOC" >/dev/null || fail "data handling doc missing recovery marker: $required"
done

python3 - "$FIXTURE_PATH" "$RUNTIME_NAMESPACE_CONTRACT" <<'PY'
import sys
from pathlib import Path
import yaml

data = yaml.safe_load(Path(sys.argv[1]).read_text())
runtime = sys.argv[2]

manifest = data.get("backup_manifest", {})
if manifest.get("source_runtime_namespace") != runtime:
    raise SystemExit("backup manifest missing runtime namespace")
if manifest.get("public_repo_storage_allowed") is not False:
    raise SystemExit("backup manifest must forbid public repo storage")
if manifest.get("integrity", {}).get("raw_export_committed") is not False:
    raise SystemExit("backup manifest must state raw export is not committed")

classification = data.get("artifact_classification", {})
for key in ["artifact_type", "subtype", "operation", "persistence_target", "approval_required", "backup_required", "deployment_required", "runner_backend", "writeback_policy"]:
    if key not in classification:
        raise SystemExit(f"backup/restore fixture missing artifact classification field {key}")
if classification.get("persistence_target") != "private-runtime" or classification.get("backup_required") is not True:
    raise SystemExit("backup/restore classification must target private-runtime and require backup")

restore = data.get("restore_rehearsal", {})
if restore.get("target_environment") != "private-rehearsal":
    raise SystemExit("restore rehearsal must target private-rehearsal")
if restore.get("writes_enabled_during_restore") is not False:
    raise SystemExit("restore rehearsal must keep writes disabled")
if restore.get("restore_command_ref") != "docs/security/data-handling.md#current-recovery-path":
    raise SystemExit("restore rehearsal missing restore command ref")

pre = data.get("pre_restore_effective_resolution", {})
post = data.get("post_restore_effective_resolution", {})
for key in ["included_context", "excluded_context", "capability_permissions", "audit_refs"]:
    if sorted(pre.get(key, []), key=repr) != sorted(post.get(key, []), key=repr):
        raise SystemExit(f"pre/post restore {key} differs")

included = pre.get("included_context", [])
if sum(1 for item in included if item.get("ref") == "profile:writing.demo-linkedin-b2b") < 2:
    raise SystemExit("shared profile ref must appear before and after restore across scopes")
excluded_reasons = {item.get("reason") for item in pre.get("excluded_context", [])}
for reason in ["overridden-by-channel-binding", "disabled-binding-preserved"]:
    if reason not in excluded_reasons:
        raise SystemExit(f"missing restore invariant reason: {reason}")
capabilities = {item.get("capability"): item for item in pre.get("capability_permissions", [])}
if capabilities.get("filesystem", {}).get("permitted") is not False:
    raise SystemExit("filesystem capability permission must remain blocked in restore fixture")
if capabilities.get("engram", {}).get("permitted") is not True:
    raise SystemExit("engram capability permission must remain permitted in restore fixture")

assertions = data.get("restore_assertions", {})
for key in ["shared_profile_refs_preserved", "profile_bindings_preserved", "overrides_preserved", "disabled_bindings_preserved", "audit_metadata_preserved", "capability_permissions_preserved"]:
    if assertions.get(key) is not True:
        raise SystemExit(f"restore assertion must be true: {key}")
if assertions.get("duplicate_profile_defs_created") is not False or assertions.get("writes_enabled_after_restore") is not False:
    raise SystemExit("restore assertions must forbid duplicate profiles and post-restore writes")
PY

review_paths=("$FIXTURE_PATH" "$DOC_PATH" "$DATA_DOC" "$RESOLVER_DOC" "$AUDIT_DOC")

if grep -E '\b[0-9]{17,20}\b' "${review_paths[@]}" >/dev/null; then
  fail "backup/restore artifacts must not expose raw Discord snowflake-like IDs"
fi

if grep -E 'BUFFER_[A-Z0-9_]+|DISCORD_[A-Z0-9_]+|OPENAI_[A-Z0-9_]+|ANTHROPIC_[A-Z0-9_]+|GITHUB_TOKEN|ENGRAM_[A-Z0-9_]+' "$FIXTURE_PATH" "$DOC_PATH" "$RESOLVER_DOC" "$AUDIT_DOC" >/dev/null; then
  fail "backup/restore contract artifacts must not contain credential variable names"
fi

if grep -E 'live_discord_connection: true|live_engram_calls: true|live_postgres_dump: true|live_docker_restore: true|runtime_enforcement_proven: true|uses_real_discord_ids: true|raw_private_backup_included: true|raw_discord_chat_logs_included: true|private_profile_content_included: true|secrets_included: true|workspace_file_writes_allowed: true|publishing_enabled: true|scheduling_enabled: true|buffer_activity_enabled: true|production-ready|live Discord validation passed|production credentials enabled' "${review_paths[@]}" >/dev/null; then
  fail "backup/restore artifacts must not claim live, production, persistence, publishing, scheduling, or private-data behavior"
fi

echo "Validated fake private runtime backup/restore contract."
echo "Fixture: $FIXTURE_PATH"
echo "Doc: $DOC_PATH"
echo "Runtime namespace contract: $RUNTIME_NAMESPACE_CONTRACT"
