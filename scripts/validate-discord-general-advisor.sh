#!/usr/bin/env bash
set -euo pipefail

FIXTURE_PATH="${DISCORD_GENERAL_ADVISOR_FIXTURE:-examples/discord-general-advisor.fake.yaml}"
DOC_PATH="docs/architecture/discord-general-advisor.md"
SKILL_PATH="skills/discord-general-advisor/SKILL.md"
MANAGED_ROUTING_DOC_PATH="docs/architecture/discord-managed-channel-routing.md"
GUIDE_DOC_PATH="docs/architecture/discord-semantic-channel-guides.md"
SCOPED_SKILLS_DOC_PATH="docs/architecture/discord-scoped-skills-registry.md"
ORCH_DOC_PATH="docs/architecture/discord-runtime-orchestrator.md"
MEMORY_GATEWAY_DOC_PATH="docs/architecture/discord-memory-gateway.md"
ROUTING_DOC_PATH="docs/operations/discord-routing.md"
CONFIG_README_PATH="openclaw/config/README.md"
RUNTIME_NAMESPACE_CONTRACT="discord-project-manager/runtime/discord/<guild-id>/<channel-id>"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for path in "$FIXTURE_PATH" "$DOC_PATH" "$SKILL_PATH" "$MANAGED_ROUTING_DOC_PATH" "$GUIDE_DOC_PATH" "$SCOPED_SKILLS_DOC_PATH" "$ORCH_DOC_PATH" "$MEMORY_GATEWAY_DOC_PATH" "$ROUTING_DOC_PATH" "$CONFIG_README_PATH"; do
  [[ -f "$path" ]] || fail "required file not found: $path"
done

for required in \
  "schema_version: 1" \
  "fixture_type: fake-demo" \
  "safe_for_repo: true" \
  "privacy_reviewed: true" \
  "contract: discord-general-advisor" \
  "live_discord_connection: false" \
  "live_openclaw_execution: false" \
  "live_engram_calls: false" \
  "live_prompt_execution: false" \
  "github_mutations_enabled: false" \
  "uses_real_discord_ids: false" \
  "raw_discord_chat_logs_included: false" \
  "production_credentials: false" \
  "publishing_enabled: false" \
  "scheduling_enabled: false" \
  "buffer_activity_enabled: false" \
  "runtime_namespace_contract: $RUNTIME_NAMESPACE_CONTRACT" \
  "advisor_scenarios:" \
  "name: linkedin-project-request" \
  "name: project-overview-request" \
  "name: category-selection-question" \
  "name: channel-selection-question" \
  "name: context-question" \
  "name: skill-governance-question" \
  "name: private-writing-preference" \
  "name: new-capability-request" \
  "name: social-bootstrap-request" \
  "name: publishing-request" \
  "name: ambiguous-route-question" \
  "name: command-family-help" \
  "name: prompt-feedback-request" \
  "name: workflow-handoff-request" \
  "name: process-release-question" \
  "name: spanish-strategy-question" \
  "name: mixed-language-profile-approval" \
  "user_message_language: es" \
  "prose_reply_language: es" \
  "technical_tokens_language: en" \
  "language_policy: prose-matches-current-message; technical-tokens-stay-english"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "fixture missing required marker: $required"
done

for required in \
  "skills/discord-general-advisor/SKILL.md" \
  "docs/architecture/discord-managed-channel-routing.md" \
  "docs/architecture/discord-semantic-channel-guides.md" \
  "docs/architecture/discord-scoped-skills-registry.md" \
  "docs/architecture/discord-runtime-orchestrator.md" \
  "docs/architecture/discord-memory-gateway.md" \
  "skills/discord-approval-gate/SKILL.md"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "fixture missing dependency marker: $required"
  grep -F "$required" "$DOC_PATH" >/dev/null || fail "doc missing dependency marker: $required"
done

for required in \
  "Activation Contract" \
  "Hard Rules" \
  "Decision Gates" \
  "write_executed: false" \
  "discord-approval-gate" \
  "recommended_route" \
  "handoff_message" \
  "command_families" \
  "prompt_pattern" \
  "safer_prompt" \
  "response-only usage coach" \
  "user_message_language" \
  "prose_reply_language" \
  "technical_tokens_language: en" \
  "language_policy: prose-matches-current-message; technical-tokens-stay-english"; do
  grep -F "$required" "$SKILL_PATH" >/dev/null || fail "skill missing advisor marker: $required"
done

for required in \
  "Advisor input schema" \
  "Advisor response schema" \
  "Topic routing guide" \
  "Command family guide" \
  "Prompt review guide" \
  "Information placement guide" \
  "Workflow handoff template" \
  "project:egdev:strategy" \
  "category" \
  "channel" \
  "context" \
  "private-runtime:profile-binding" \
  "publishing-connector-readiness" \
  "write_executed: false" \
  "clarifying question" \
  "Response-language rule" \
  "user_message_language" \
  "prose_reply_language" \
  "technical_tokens_language" \
  "prose-matches-current-message; technical-tokens-stay-english"; do
  grep -F "$required" "$DOC_PATH" >/dev/null || fail "doc missing advisor marker: $required"
done

grep -F "docs/architecture/discord-general-advisor.md" "$ROUTING_DOC_PATH" >/dev/null || fail "routing doc missing general advisor reference"
grep -F "examples/discord-general-advisor.fake.yaml" "$ROUTING_DOC_PATH" >/dev/null || fail "routing doc missing general advisor fixture"
grep -F "scripts/validate-discord-general-advisor.sh" "$ROUTING_DOC_PATH" >/dev/null || fail "routing doc missing general advisor validator"
grep -F "docs/architecture/discord-general-advisor.md" "$CONFIG_README_PATH" >/dev/null || fail "config README missing general advisor reference"
grep -F "skills/discord-general-advisor/SKILL.md" "$CONFIG_README_PATH" >/dev/null || fail "config README missing advisor skill reference"

python3 - "$FIXTURE_PATH" "$RUNTIME_NAMESPACE_CONTRACT" <<'PY'
import sys
from pathlib import Path

import yaml

fixture_path = Path(sys.argv[1])
runtime_contract = sys.argv[2]

try:
    fixture = yaml.safe_load(fixture_path.read_text())
except yaml.YAMLError as exc:
    raise SystemExit(f"fixture is not valid YAML: {exc}") from exc

if not isinstance(fixture, dict):
    raise SystemExit("fixture root must be a mapping")

raw_scenarios = fixture.get("advisor_scenarios")
if not isinstance(raw_scenarios, list):
    raise SystemExit("fixture must contain advisor_scenarios list")

def scalar_to_contract_string(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)

scenarios = []
for raw in raw_scenarios:
    if not isinstance(raw, dict):
        raise SystemExit("each advisor scenario must be a mapping")
    name = raw.get("name")
    inp = raw.get("input")
    res = raw.get("response")
    if not isinstance(name, str):
        raise SystemExit("each advisor scenario must have a string name")
    if not isinstance(inp, dict):
        raise SystemExit(f"{name} input must be a mapping")
    if not isinstance(res, dict):
        raise SystemExit(f"{name} response must be a mapping")
    scenarios.append({
        "name": name,
        "input": {key: scalar_to_contract_string(value) for key, value in inp.items()},
        "response": {key: scalar_to_contract_string(value) for key, value in res.items() if key != "required_contracts"},
        "contracts": res.get("required_contracts") or [],
    })

expected = {
    "linkedin-project-request",
    "project-overview-request",
    "category-selection-question",
    "channel-selection-question",
    "context-question",
    "skill-governance-question",
    "private-writing-preference",
    "new-capability-request",
    "social-bootstrap-request",
    "publishing-request",
    "ambiguous-route-question",
    "command-family-help",
    "prompt-feedback-request",
    "workflow-handoff-request",
    "process-release-question",
    "spanish-strategy-question",
    "mixed-language-profile-approval",
    "unknown-language-clarification",
}
seen = {s["name"] for s in scenarios}
missing = expected - seen
if missing:
    raise SystemExit(f"missing advisor scenarios: {sorted(missing)}")

required_topics = {"project", "category", "channel", "context", "skill", "profile", "capability", "strategy", "task", "analytics", "publishing", "process_release"}
seen_topics = {s["input"].get("requested_topic") for s in scenarios}
missing_topics = required_topics - seen_topics
if missing_topics:
    raise SystemExit(f"missing advisor topic coverage: {sorted(missing_topics)}")

for sc in scenarios:
    name = sc["name"]
    inp = sc["input"]
    res = sc["response"]
    if inp.get("runtime_namespace") != runtime_contract:
        raise SystemExit(f"{name} has wrong runtime namespace")
    for key in ["question_type", "requested_topic", "known_scope", "known_project_ref", "write_like", "user_message_language"]:
        if key not in inp:
            raise SystemExit(f"{name} missing input field {key}")
    for key in ["advisor_state", "recommended_route", "reason", "approval_required", "write_executed", "prose_reply_language", "technical_tokens_language", "language_policy"]:
        if key not in res:
            raise SystemExit(f"{name} missing response field {key}")
    if res.get("write_executed") != "false":
        raise SystemExit(f"{name} must keep write_executed: false")
    if res.get("prose_reply_language") != inp.get("user_message_language"):
        raise SystemExit(f"{name} prose reply language must match current user message language")
    if res.get("technical_tokens_language") != "en":
        raise SystemExit(f"{name} technical tokens language must stay English")
    if res.get("language_policy") != "prose-matches-current-message; technical-tokens-stay-english":
        raise SystemExit(f"{name} has wrong language policy marker")
    if name == "spanish-strategy-question":
        if inp.get("user_message_language") != "es" or res.get("prose_reply_language") != "es":
            raise SystemExit("spanish-strategy-question must keep Spanish prose metadata")
        for token in ["project:egdev:strategy", "project-demo-egdev"]:
            if token not in res.get("reason", "") and token not in res.get("handoff_message", "") and token not in res.get("recommended_route", ""):
                raise SystemExit(f"spanish-strategy-question must preserve English technical token: {token}")
    if name == "mixed-language-profile-approval":
        if inp.get("user_message_language") != "es" or res.get("prose_reply_language") != "es":
            raise SystemExit("mixed-language-profile-approval must keep Spanish prose metadata")
        for token in ["private-runtime:profile-binding", "discord-approval-gate", "approve write", "project:egdev:context"]:
            if token not in res.get("reason", "") and token not in res.get("handoff_message", "") and token not in res.get("recommended_route", "") and token not in res.get("target_channel_ref", ""):
                raise SystemExit(f"mixed-language-profile-approval must preserve English technical token: {token}")
    if name == "unknown-language-clarification":
        if inp.get("user_message_language") != "und" or res.get("prose_reply_language") != "und":
            raise SystemExit("unknown-language-clarification must use und language-neutral metadata")
        if res.get("advisor_state") != "clarification-needed":
            raise SystemExit("unknown-language-clarification must ask before choosing a language or route")
        if res.get("recommended_route") != "none" or res.get("target_channel_ref") != "none" or "handoff_message" in res:
            raise SystemExit("unknown-language-clarification must not emit a concrete route, target channel, or handoff")
        if "🌐" not in res.get("clarifying_question", "") or "idioma" not in res.get("clarifying_question", ""):
            raise SystemExit("unknown-language-clarification must avoid silently defaulting to English prose")
    if not sc["contracts"]:
        raise SystemExit(f"{name} missing required contracts")
    write_like = inp.get("write_like") == "true"
    approval = res.get("approval_required") == "true"
    if write_like:
        if not approval or res.get("advisor_state") != "blocked-write-like":
            raise SystemExit(f"{name} write-like advice must be blocked and approval-required")
        if res.get("approval_skill") != "discord-approval-gate" or res.get("exact_approval_phrase") != "approve write":
            raise SystemExit(f"{name} write-like advice must name exact approval gate")
    if name == "command-family-help":
        for key in ["command_families", "prompt_pattern", "handoff_message"]:
            if key not in res:
                raise SystemExit(f"{name} missing {key}")
        for token in ["context", "profile", "skill", "capability", "strategy", "task", "analytics", "publishing", "process/release"]:
            if token not in res.get("command_families", "") and token not in res.get("reason", ""):
                raise SystemExit(f"{name} must explain command family {token}")
    if name == "prompt-feedback-request":
        if inp.get("question_type") != "prompt_feedback" or "safer_prompt" not in res:
            raise SystemExit("prompt-feedback-request must review and improve a prompt before execution")
        if res.get("write_executed") != "false":
            raise SystemExit("prompt-feedback-request must remain response-only")
    if name == "workflow-handoff-request":
        if inp.get("question_type") != "handoff_copy" or "handoff_message" not in res:
            raise SystemExit("workflow-handoff-request must produce copyable handoff")
    if name == "process-release-question":
        if inp.get("requested_topic") != "process_release" or "process/release" not in res.get("reason", ""):
            raise SystemExit("process-release-question must cover process/release placement")
    if res.get("advisor_state") == "clarification-needed":
        if "clarifying_question" not in res:
            raise SystemExit(f"{name} clarification-needed response must ask a clarifying question")
    elif "handoff_message" not in res:
        raise SystemExit(f"{name} must include copyable handoff message")
PY

review_paths=("$FIXTURE_PATH" "$DOC_PATH" "$SKILL_PATH")

if grep -E '\b[0-9]{17,20}\b' "${review_paths[@]}" >/dev/null; then
  fail "advisor artifacts must not expose raw Discord snowflake-like IDs"
fi

if grep -E 'BUFFER_[A-Z0-9_]+|DISCORD_[A-Z0-9_]+|OPENAI_[A-Z0-9_]+|ANTHROPIC_[A-Z0-9_]+|GITHUB_TOKEN|ENGRAM_[A-Z0-9_]+' "${review_paths[@]}" >/dev/null; then
  fail "advisor artifacts must not contain credential variable names"
fi

if grep -E 'live_discord_connection: true|live_openclaw_execution: true|live_engram_calls: true|live_prompt_execution: true|github_mutations_enabled: true|uses_real_discord_ids: true|raw_discord_chat_logs_included: true|production_credentials: true|publishing_enabled: true|scheduling_enabled: true|buffer_activity_enabled: true|production-ready|live Discord validation passed|prompt execution proven|GitHub mutation executed|publish executed|scheduled successfully' "${review_paths[@]}" >/dev/null; then
  fail "advisor artifacts must not claim live, production, mutation, publishing, scheduling, or execution behavior"
fi

echo "Validated fake Discord general advisor contract."
echo "Fixture: $FIXTURE_PATH"
echo "Doc: $DOC_PATH"
echo "Skill: $SKILL_PATH"
echo "Runtime namespace contract: $RUNTIME_NAMESPACE_CONTRACT"
