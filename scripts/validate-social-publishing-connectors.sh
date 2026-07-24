#!/usr/bin/env bash
set -euo pipefail

FIXTURE_PATH="${SOCIAL_PUBLISHING_CONNECTORS_FIXTURE:-examples/social-publishing-connectors.fake.yaml}"
DOC_PATH="docs/research/social-publishing-connectors.md"
SECURITY_DOC_PATH="docs/security/data-handling.md"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

command -v python3 >/dev/null 2>&1 || fail "required command not found: python3"

for path in "$FIXTURE_PATH" "$DOC_PATH" "$SECURITY_DOC_PATH"; do
  [[ -f "$path" ]] || fail "required file not found: $path"
done

python3 - "$FIXTURE_PATH" "$DOC_PATH" "$SECURITY_DOC_PATH" <<'PY'
import re
import sys
from pathlib import Path

fixture_path = Path(sys.argv[1])
doc_path = Path(sys.argv[2])
security_doc_path = Path(sys.argv[3])

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

def req_keys(value, allowed, area):
    req(isinstance(value, dict), f"{area} must be a mapping")
    extra = set(value) - set(allowed)
    missing = set(allowed) - set(value)
    req(not extra, f"{area} contains unsupported keys: {', '.join(sorted(extra))}")
    req(not missing, f"{area} is missing keys: {', '.join(sorted(missing))}")

def req_ts(value, field):
    req(isinstance(value, str), f"{field} must be a quoted RFC3339 UTC string or unknown")
    if value == "unknown":
        return
    req(re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", value), f"{field} must be RFC3339 UTC ending in Z")

def req_receipt(value, expected_prefix, field):
    req(isinstance(value, str), f"{field} must be a string")
    if value == "none":
        return
    req(value.startswith(expected_prefix), f"{field} must use {expected_prefix}")
    req(value.endswith("-demo"), f"{field} must end with -demo")


def req_any_fake_receipt(value, allowed_prefixes, field):
    req(isinstance(value, str), f"{field} must be a string")
    if value == "none":
        return
    req(any(value.startswith(prefix) for prefix in allowed_prefixes), f"{field} must use a fake provider receipt prefix")
    req(value.endswith("-demo"), f"{field} must end with -demo")

text = fixture_path.read_text()
doc = doc_path.read_text()
security_doc = security_doc_path.read_text()
data = yaml.load(text, Loader=Loader)

req_keys(data, {
    "schema_version",
    "contract",
    "project",
    "fixture_type",
    "fake",
    "safe_for_repo",
    "privacy_reviewed",
    "real_tokens_included",
    "real_payloads_included",
    "screenshots_included",
    "social_account_data_included",
    "live_publish_attempted",
    "live_schedule_attempted",
    "browser_automation_attempted",
    "raw_provider_payloads_included",
    "credential_material_included",
    "approval_phrase",
    "connector_options",
    "approval_contract",
    "ledger_contract",
    "credential_requirements",
    "scenarios",
    "metadata",
}, "fixture")

req(data["schema_version"] == 1, "schema_version must be 1")
req(data["contract"] == "social-publishing-connectors", "wrong contract")
req(data["project"] == "egdev", "project slug mismatch")
req(data["fixture_type"] == "fake-demo", "fixture_type must be fake-demo")
for flag in ["fake", "safe_for_repo", "privacy_reviewed"]:
    req(data[flag] is True, f"{flag} must be true")
for flag in [
    "real_tokens_included",
    "real_payloads_included",
    "screenshots_included",
    "social_account_data_included",
    "live_publish_attempted",
    "live_schedule_attempted",
    "browser_automation_attempted",
    "raw_provider_payloads_included",
    "credential_material_included",
]:
    req(data[flag] is False, f"{flag} must be false")

expected_options = {
    "buffer-graphql-publishing": {
        "approval_status": "candidate-provider-not-live-approved",
        "scheduling_support": "supported-by-provider-unvalidated-here",
        "tos_risk": "medium",
    },
    "direct-linkedin-api": {
        "approval_status": "pending-provider-approval",
        "scheduling_support": "not-confirmed",
        "tos_risk": "medium-high",
    },
    "direct-x-api": {
        "approval_status": "pending-provider-approval",
        "scheduling_support": "not-confirmed",
        "tos_risk": "medium-high",
    },
    "browser-assisted-manual-publishing": {
        "approval_status": "manual-only-automation-not-approved",
        "scheduling_support": "platform-native-manual-only",
        "tos_risk": "high",
        "implementation_effort": "high",
    },
    "community-plugin-openclaw-social": {
        "approval_status": "not-approved-for-automation",
        "scheduling_support": "unknown-unverified",
        "tos_risk": "high",
    },
    "custom-openclaw-plugin": {
        "approval_status": "design-candidate-separate-implementation-approval-required",
        "scheduling_support": "provider-specific",
        "tos_risk": "medium",
    },
}
options = data["connector_options"]
req(isinstance(options, list), "connector_options must be a list")
seen = set()
for option in options:
    req_keys(option, {
        "option",
        "label",
        "reliability",
        "privacy_exposure",
        "tos_risk",
        "implementation_effort",
        "credential_model",
        "credential_storage",
        "rotation_action",
        "approval_status",
        "scheduling_support",
        "ledger_update_behavior",
    }, "connector option")
    name = option["option"]
    req(name in expected_options, f"unexpected connector option: {name}")
    req(name not in seen, f"duplicate connector option: {name}")
    seen.add(name)
    req(option["credential_storage"] == "private-runtime-only", f"{name} credential storage must be private-runtime-only")
    req(option["privacy_exposure"] in {"medium", "medium-high", "high"}, f"{name} invalid privacy exposure")
    req(option["reliability"] in {"low-medium", "medium", "medium-high", "high"}, f"{name} invalid reliability")
    req(option["implementation_effort"] in {"low", "medium", "high"}, f"{name} invalid effort")
    expected = expected_options[name]
    for key, value in expected.items():
        req(option[key] == value, f"{name} {key} must be {value}")
    req("rotate" in option["rotation_action"] or "revoke" in option["rotation_action"], f"{name} missing revoke/rotate action")
    req("placeholder" in option["credential_model"], f"{name} credential model must be placeholder-only")
req(seen == set(expected_options), "connector option matrix incomplete")

approval = data["approval_contract"]
req_keys(approval, {
    "draft_approval_phrase",
    "schedule_approval_phrase",
    "publish_approval_phrase",
    "draft_approval_allows_publish",
    "schedule_approval_allows_publish",
    "publish_requires_explicit_separate_approval",
    "publish_before_approval_blocked",
    "schedule_before_approval_blocked",
    "ledger_updates_before_provider_success",
}, "approval_contract")
req(approval["draft_approval_phrase"] != approval["publish_approval_phrase"], "draft approval must differ from publish approval")
req(approval["schedule_approval_phrase"] != approval["publish_approval_phrase"], "schedule approval must differ from publish approval")
req(approval["draft_approval_allows_publish"] is False, "draft approval must not allow publish")
req(approval["schedule_approval_allows_publish"] is False, "schedule approval must not allow publish")
req(approval["publish_requires_explicit_separate_approval"] is True, "publish must require separate approval")
req(approval["publish_before_approval_blocked"] is True, "publish before approval must be blocked")
req(approval["schedule_before_approval_blocked"] is True, "schedule before approval must be blocked")
req(approval["ledger_updates_before_provider_success"] is False, "ledger must not update before provider success")
req(data["approval_phrase"] == approval["publish_approval_phrase"], "top-level approval phrase must be publish approval")

ledger = data["ledger_contract"]
req_keys(ledger, {
    "allowed_initial_states",
    "publish_success_state",
    "schedule_success_state",
    "failed_result_preserves_previous_state",
    "blocked_result_preserves_previous_state",
    "provider_receipts_are_fake_only",
    "publish_receipt_prefix",
    "schedule_receipt_prefix",
}, "ledger_contract")
req(set(ledger["allowed_initial_states"]) == {"draft", "queued"}, "initial states must be draft and queued")
req(ledger["publish_success_state"] == "published", "publish success state must be published")
req(ledger["schedule_success_state"] == "queued", "schedule success state must be queued")
for key in ["failed_result_preserves_previous_state", "blocked_result_preserves_previous_state", "provider_receipts_are_fake_only"]:
    req(ledger[key] is True, f"{key} must be true")
req(ledger["publish_receipt_prefix"] == "fake-provider://publish/", "publish receipt prefix mismatch")
req(ledger["schedule_receipt_prefix"] == "fake-provider://schedule/", "schedule receipt prefix mismatch")

creds = data["credential_requirements"]
req_keys(creds, {"storage_classification", "placeholders_only", "public_repo_allowed_values", "required_rotation_actions"}, "credential_requirements")
req(creds["storage_classification"] == "private-runtime-only", "credential requirements must be private-runtime-only")
req(creds["placeholders_only"] is True, "credentials must be placeholders only")
req(set(creds["required_rotation_actions"]) == {"revoke-provider-token", "rotate-secret", "rebind-private-runtime-account", "invalidate-old-session-state", "rerun-fake-first-validator"}, "rotation action coverage drifted")

expected_scenarios = {
    "blocked-publish-before-approval",
    "draft-approved-but-publish-blocked",
    "schedule-approved-but-publish-blocked",
    "publish-approved-updates-ledger-after-success",
    "schedule-approved-updates-ledger-after-success",
    "failed-provider-result-does-not-mark-published",
}
scenarios = {item.get("name"): item for item in data["scenarios"]}
req(set(scenarios) == expected_scenarios, "scenario coverage drifted")

scenario_allowed_keys = {
    "name", "intent", "draft_approved", "schedule_approved", "publish_approved", "action_allowed", "expected_result",
    "provider_call_attempted", "live_activity_attempted", "ledger_before", "provider_result", "ledger_after",
}
ledger_keys = {"entry_id", "status", "published_at", "scheduled_for", "provider_receipt_ref"}
provider_keys = {"status", "receipt_ref", "completed_at", "scheduled_for", "error_ref"}
for name, scenario in scenarios.items():
    req_keys(scenario, scenario_allowed_keys, f"scenario {name}")
    req(scenario["intent"] in {"publish", "schedule"}, f"{name} invalid intent")
    req(scenario["provider_call_attempted"] is False, f"{name} must not attempt provider calls")
    req(scenario["live_activity_attempted"] is False, f"{name} must not attempt live activity")
    req_keys(scenario["ledger_before"], ledger_keys, f"{name}.ledger_before")
    req_keys(scenario["ledger_after"], ledger_keys, f"{name}.ledger_after")
    req_keys(scenario["provider_result"], provider_keys, f"{name}.provider_result")
    req(scenario["ledger_before"]["entry_id"] == scenario["ledger_after"]["entry_id"], f"{name} ledger entry id changed")
    req(scenario["ledger_before"]["entry_id"].endswith("-demo"), f"{name} entry id must be demo")
    for field in ["published_at", "scheduled_for"]:
        req_ts(scenario["ledger_before"][field], f"{name}.ledger_before.{field}")
        req_ts(scenario["ledger_after"][field], f"{name}.ledger_after.{field}")
    result = scenario["provider_result"]
    req(result["status"] in {"not-attempted", "fake-success", "fake-failure"}, f"{name} invalid provider status")
    if result["completed_at"] is not None:
        req_ts(result["completed_at"], f"{name}.provider_result.completed_at")
    if result["scheduled_for"] is not None:
        req_ts(result["scheduled_for"], f"{name}.provider_result.scheduled_for")
    if result["error_ref"] is not None:
        req(str(result["error_ref"]).startswith("fake-error://"), f"{name} error ref must be fake")
    receipt_prefix = ledger["publish_receipt_prefix"] if scenario["intent"] == "publish" else ledger["schedule_receipt_prefix"]
    req_receipt(result["receipt_ref"], receipt_prefix, f"{name}.provider_result.receipt_ref")

    before = scenario["ledger_before"]
    after = scenario["ledger_after"]
    allowed_receipt_prefixes = {ledger["publish_receipt_prefix"], ledger["schedule_receipt_prefix"]}
    req_any_fake_receipt(before["provider_receipt_ref"], allowed_receipt_prefixes, f"{name}.ledger_before.provider_receipt_ref")
    req_any_fake_receipt(after["provider_receipt_ref"], allowed_receipt_prefixes, f"{name}.ledger_after.provider_receipt_ref")
    blocked = scenario["action_allowed"] is False
    failed = result["status"] == "fake-failure"
    success = result["status"] == "fake-success"
    if blocked or failed:
        req(before == after, f"{name} must leave ledger unchanged when blocked or failed")
        req(result["receipt_ref"] == "none", f"{name} must not include receipt when blocked or failed")
    if scenario["intent"] == "publish":
        if scenario["publish_approved"] is False:
            req(scenario["action_allowed"] is False, f"{name} publish without approval must be blocked")
        if success:
            req(scenario["publish_approved"] is True, f"{name} publish success requires publish approval")
            req(after["status"] == "published", f"{name} publish success must mark published")
            req(after["published_at"] == result["completed_at"], f"{name} published_at must come from fake success")
            req(after["provider_receipt_ref"] == result["receipt_ref"], f"{name} receipt must come from fake success")
    if scenario["intent"] == "schedule":
        if scenario["schedule_approved"] is False:
            req(scenario["action_allowed"] is False, f"{name} schedule without approval must be blocked")
        if success:
            req(scenario["schedule_approved"] is True, f"{name} schedule success requires schedule approval")
            req(scenario["publish_approved"] is False, f"{name} schedule approval must not imply publish approval")
            req(after["status"] == "queued", f"{name} schedule success must mark queued")
            req(after["scheduled_for"] == result["scheduled_for"], f"{name} scheduled_for must come from fake success")
            req(after["provider_receipt_ref"] == result["receipt_ref"], f"{name} receipt must come from fake success")

unsafe_fixture_patterns = [
    r"live_publish_attempted:\s*true",
    r"live_schedule_attempted:\s*true",
    r"browser_automation_attempted:\s*true",
    r"real_tokens_included:\s*true",
    r"real_payloads_included:\s*true",
    r"screenshots_included:\s*true",
    r"social_account_data_included:\s*true",
    r"credential_material_included:\s*true",
    r"[A-Za-z0-9_]*(TOKEN|SECRET|PASSWORD|API_KEY)\s*[:=]\s*['\"]?[A-Za-z0-9_\-.]{12,}",
    r"https://(api\.buffer\.com|auth\.buffer\.com|api\.linkedin\.com|api\.x\.com|api\.twitter\.com)/[^\s]+",
]
for pattern in unsafe_fixture_patterns:
    req(not re.search(pattern, text), f"fixture contains unsafe pattern: {pattern}")

required_doc_markers = [
    "Buffer GraphQL publishing",
    "Direct LinkedIn API",
    "Direct X API",
    "Browser-assisted manual publishing",
    "The machine-readable fixture uses a single conservative browser-assisted rating: `tos_risk: high` and `implementation_effort: high`.",
    "Community plugin (`openclaw-plugin-social` / `zooclaw-social`)",
    "Custom OpenClaw plugin",
    "Publish approval",
    "draft approval or schedule approval must not be reused as publish approval",
    "Store Buffer, LinkedIn, X, community plugin, and custom plugin credentials only in `.env`, a secret manager, or provider-specific private runtime state",
    "Successful fake publish result",
    "Successful fake schedule result",
    "Failed, blocked, unapproved, or unknown result",
    "This slice does not implement live Buffer, LinkedIn, X, browser, community plugin, or custom plugin publishing",
]
for marker in required_doc_markers:
    req(marker in doc, f"research doc missing marker: {marker}")

for option in expected_options:
    req(option in text, f"fixture missing option marker: {option}")

for marker in [
    "Social publishing connector credentials and browser/session state",
    "Revoke, rotate, rebind private runtime config, invalidate old sessions, and rerun fake-first validation after suspected exposure.",
    "Do not commit social provider payloads, screenshots, account IDs, profile IDs, OAuth refresh tokens, or browser session state.",
]:
    req(marker in security_doc, f"security doc missing marker: {marker}")

print("Validated fake social publishing connector research contract.")
print(f"Fixture: {fixture_path}")
print(f"Doc: {doc_path}")
print(f"Security doc: {security_doc_path}")
print("Approval gate: publish intent remains blocked until explicit publish approval.")
PY
