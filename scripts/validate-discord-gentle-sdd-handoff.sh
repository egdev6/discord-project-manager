#!/usr/bin/env bash
set -euo pipefail

FIXTURE_PATH="${DISCORD_GENTLE_SDD_HANDOFF_FIXTURE:-examples/discord-gentle-sdd-handoff.fake.yaml}"
DOC_PATH="docs/architecture/discord-gentle-sdd-handoff.md"
ORCHESTRATOR_DOC_PATH="docs/architecture/discord-runtime-orchestrator.md"
PARENT_DOC_PATH="docs/architecture/discord-dynamic-context-namespaces.md"
ROUTING_DOC_PATH="docs/operations/discord-routing.md"
CONFIG_README_PATH="openclaw/config/README.md"
RUNTIME_NAMESPACE_CONTRACT="discord-project-manager/runtime/discord/<guild-id>/<channel-id>"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for path in "$FIXTURE_PATH" "$DOC_PATH" "$ORCHESTRATOR_DOC_PATH" "$PARENT_DOC_PATH" "$ROUTING_DOC_PATH" "$CONFIG_README_PATH"; do
  [[ -f "$path" ]] || fail "required file not found: $path"
done

for required in \
  "schema_version: 1" \
  "fixture_type: fake-demo" \
  "safe_for_repo: true" \
  "privacy_reviewed: true" \
  "contract: discord-gentle-sdd-handoff" \
  "live_discord_connection: false" \
  "live_engram_calls: false" \
  "live_prompt_execution: false" \
  "live_sdd_execution: false" \
  "github_mutations_enabled: false" \
  "uses_real_discord_ids: false" \
  "production_credentials: false" \
  "publishing_enabled: false" \
  "scheduling_enabled: false" \
  "buffer_activity_enabled: false" \
  "runtime_namespace_contract: $RUNTIME_NAMESPACE_CONTRACT" \
  "name: matched-route-sdd-handoff" \
  "name: global-governance-approval-proposal" \
  "name: repo-artifact-claim-proposal" \
  "development_intent: openclaw_skill_development" \
  "target_path: skills/demo-openclaw-workflow/SKILL.md" \
  "validation_evidence:" \
  "runtime_sync_requirements:"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "fixture missing required marker: $required"
done

for required in \
  "docs/architecture/discord-runtime-orchestrator.md" \
  "docs/architecture/discord-context-skill-packs.md" \
  "docs/architecture/discord-memory-gateway.md" \
  "docs/adr/0001-runtime-boundary.md" \
  "docs/process/shared-artifact-serialization.md" \
  "docs/adr/0002-engram-namespace-contract.md" \
  "skills/discord-approval-gate/SKILL.md"; do
  grep -F "$required" "$DOC_PATH" >/dev/null || fail "doc missing dependency marker: $required"
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "fixture missing dependency marker: $required"
done

for required in \
  "Input handoff envelope" \
  "Return envelope" \
  "Writeback target scopes" \
  "Shared-artifact claims" \
  "development_intent" \
  "validation_evidence" \
  "runtime_sync_requirements" \
  "skills/{name}/SKILL.md" \
  "must not query Discord directly" \
  "approve write" \
  "single_writer: true" \
  "GitHub mutation"; do
  grep -F "$required" "$DOC_PATH" >/dev/null || fail "doc missing required handoff marker: $required"
done

grep -F "docs/architecture/discord-gentle-sdd-handoff.md" "$ORCHESTRATOR_DOC_PATH" >/dev/null || fail "orchestrator doc missing handoff reference"
grep -F "#74 | OpenClaw to Gentle SDD handoff; see \`docs/architecture/discord-gentle-sdd-handoff.md\`. |" "$PARENT_DOC_PATH" >/dev/null || fail "parent doc missing handoff reference"
grep -F "bash scripts/validate-discord-gentle-sdd-handoff.sh" "$ROUTING_DOC_PATH" >/dev/null || fail "routing doc missing handoff validator"
grep -F "examples/discord-gentle-sdd-handoff.fake.yaml" "$ROUTING_DOC_PATH" >/dev/null || fail "routing doc missing handoff fixture"
grep -F "docs/architecture/discord-gentle-sdd-handoff.md" "$CONFIG_README_PATH" >/dev/null || fail "config README missing handoff reference"

awk -v runtime="$RUNTIME_NAMESPACE_CONTRACT" '
  function finish_scenario() {
    if (scenario == "") {
      return
    }
    if (has_runtime != 2 || has_routing_status != 1 || has_resolved_route != 1 || has_project_slug != 1 || has_network_slug != 1 || has_route != 2 || has_intent != 1 || has_context_ref != 1 || has_skill_ref != 1 || has_gate != 1 || has_mode != 1 || has_exec != 1 || has_prompt != 1 || has_summary != 1 || has_artifact_marker != 1 || has_writeback_marker != 1) {
      printf("scenario %s is missing required handoff markers\n", scenario) > "/dev/stderr"
      exit 1
    }
    if (scenario == "matched-route-sdd-handoff") {
      if (approval_policy != "proposal-only" || execution_state != "contract-only" || artifact_mode != "none" || writeback_mode != "none") {
        print "matched-route-sdd-handoff must stay contract-only with no artifact or writeback execution" > "/dev/stderr"
        exit 1
      }
    }
    if (scenario == "global-governance-approval-proposal") {
      if (proposal_scope != "global" || target_namespace != "discord-project-manager/project/egdev/brand" || topic_key != "discord/writeback/global-governance" || approval_state != "approval-requested" || approval_phrase != "approve write" || write_executed != "false") {
        print "global governance proposal must stay approval-requested with exact approve write" > "/dev/stderr"
        exit 1
      }
    }
    if (scenario == "repo-artifact-claim-proposal") {
      if (development_intent != "openclaw_skill_development" || artifact_kind != "repo-skill" || target_path != "skills/demo-openclaw-workflow/SKILL.md" || artifact_write_executed != "false" || serialization_ref != "docs/process/shared-artifact-serialization.md" || claim_target_path != "skills/demo-openclaw-workflow/SKILL.md" || claim_required != "true" || release_required != "true" || single_writer != "true" || claim_write_executed != "false" || has_validation_evidence != 1 || has_runtime_sync_requirements != 1) {
        print "repo skill proposal must include openclaw skill intent, target path, serialization claim metadata, validation evidence, runtime sync requirements, and no write execution" > "/dev/stderr"
        exit 1
      }
    }
  }

  /^  - name:/ {
    finish_scenario()
    scenario = $3
    has_runtime = has_routing_status = has_resolved_route = has_project_slug = has_network_slug = has_route = has_intent = has_context_ref = has_skill_ref = has_gate = has_mode = has_exec = has_prompt = has_summary = has_artifact_marker = has_writeback_marker = 0
    approval_policy = execution_state = artifact_mode = writeback_mode = proposal_scope = target_namespace = topic_key = approval_state = approval_phrase = write_executed = artifact_kind = target_path = artifact_write_executed = serialization_ref = claim_target_path = claim_required = release_required = single_writer = claim_write_executed = route_status = development_intent = ""
    has_validation_evidence = has_runtime_sync_requirements = 0
    section = "scenario"
    next
  }
  scenario != "" && /^    handoff_envelope:/ { section = "handoff"; next }
  scenario != "" && /^    return_envelope:/ { section = "return"; next }
  section == "handoff" && index($0, "runtime_namespace: " runtime) { has_runtime = 2; next }
  section == "handoff" && /routing_status:/ { route_status = $NF; if (route_status == "matched-route") { has_routing_status = 1 } next }
  section == "handoff" && /^      resolved_route:/ { has_resolved_route = 1; next }
  section == "handoff" && /^        project_slug:/ && has_resolved_route { has_project_slug = 1; if (has_network_slug) { has_route = 2 } next }
  section == "handoff" && /^        network_slug:/ && has_resolved_route { has_network_slug = 1; if (has_project_slug) { has_route = 2 } next }
  section == "handoff" && /intent_family:/ && $NF == "sdd_dev_work" { has_intent = 1; next }
  section == "handoff" && /context_pack_ref:/ && /stack-and-flow-github.context_pack/ { has_context_ref = 1; next }
  section == "handoff" && /skill_pack_ref:/ && /stack-and-flow-github.skill_pack/ { has_skill_ref = 1; next }
  section == "handoff" && /- discord-approval-gate/ { has_gate = 1; next }
  section == "handoff" && /execution_mode:/ && $NF == "delegated-contract-only" { has_mode = 1; next }
  section == "handoff" && /development_intent:/ { development_intent = $NF; next }
  section == "handoff" && /approval_policy:/ { approval_policy = $NF; next }
  section == "return" && /execution_state:/ { execution_state = $NF; has_exec = 1; next }
  section == "return" && /prompt_execution:/ && $NF == "none" { has_prompt = 1; next }
  section == "return" && /turn_summary:/ { has_summary = 1; next }
  section == "return" && /artifact_proposals:/ { has_artifact_marker = 1; artifact_mode = $NF; next }
  section == "return" && /writeback_proposals:/ { has_writeback_marker = 1; writeback_mode = $NF; next }
  section == "return" && /proposal_scope:/ { proposal_scope = $NF; next }
  section == "return" && /target_namespace:/ { target_namespace = $NF; next }
  section == "return" && /topic_key:/ { topic_key = $NF; next }
  section == "return" && /approval_state:/ { approval_state = $NF; next }
  section == "return" && /approval_phrase:/ { approval_phrase = $(NF-1) " " $NF; next }
  section == "return" && /write_executed:/ && artifact_kind == "" && serialization_ref == "" { write_executed = $NF; next }
  section == "return" && /artifact_kind:/ { artifact_kind = $NF; next }
  section == "return" && /target_path:/ && artifact_kind != "" && serialization_ref == "" { target_path = $NF; next }
  section == "return" && /write_executed:/ && artifact_kind != "" && serialization_ref == "" { artifact_write_executed = $NF; next }
  section == "return" && /serialization_contract_ref:/ { serialization_ref = $NF; next }
  section == "return" && /target_path:/ && serialization_ref != "" { claim_target_path = $NF; next }
  section == "return" && /claim_required:/ { claim_required = $NF; next }
  section == "return" && /release_required:/ { release_required = $NF; next }
  section == "return" && /single_writer:/ { single_writer = $NF; next }
  section == "return" && /write_executed:/ && serialization_ref != "" { claim_write_executed = $NF; next }
  section == "return" && /^      validation_evidence:/ { has_validation_evidence = 1; next }
  section == "return" && /^      runtime_sync_requirements:/ { has_runtime_sync_requirements = 1; next }
  END { finish_scenario() }
' "$FIXTURE_PATH" || fail "fixture handoff scenarios are inconsistent"

review_paths=("$FIXTURE_PATH" "$DOC_PATH" "$ORCHESTRATOR_DOC_PATH" "$PARENT_DOC_PATH" "$ROUTING_DOC_PATH" "$CONFIG_README_PATH")

if grep -E '\b[0-9]{17,20}\b' "${review_paths[@]}" >/dev/null; then
  fail "artifacts must not expose raw Discord snowflake-like IDs"
fi

if grep -E 'BUFFER_[A-Z0-9_]+|DISCORD_[A-Z0-9_]+|OPENAI_[A-Z0-9_]+|ANTHROPIC_[A-Z0-9_]+|GITHUB_TOKEN|ENGRAM_[A-Z0-9_]+' "${review_paths[@]}" >/dev/null; then
  fail "artifacts must not contain credential variable names"
fi

if grep -E 'live_discord_connection: true|live_engram_calls: true|live_prompt_execution: true|live_sdd_execution: true|github_mutations_enabled: true|uses_real_discord_ids: true|production_credentials: true|publishing_enabled: true|scheduling_enabled: true|buffer_activity_enabled: true|production-ready|public Discord validation passed|live Discord validation passed|live OpenClaw handoff proven|live Engram calls enabled|prompt execution proven|sdd execution proven|GitHub mutation executed|uses production credentials|production credentials enabled' "${review_paths[@]}" >/dev/null; then
  fail "artifacts must not claim live, production, mutation, publishing, scheduling, or execution behavior"
fi

echo "Validated fake Discord Gentle SDD handoff contract."
echo "Fixture: $FIXTURE_PATH"
echo "Doc: $DOC_PATH"
echo "Orchestrator doc: $ORCHESTRATOR_DOC_PATH"
echo "Parent doc: $PARENT_DOC_PATH"
echo "Routing doc: $ROUTING_DOC_PATH"
echo "Config README: $CONFIG_README_PATH"
echo "Runtime namespace contract: $RUNTIME_NAMESPACE_CONTRACT"
