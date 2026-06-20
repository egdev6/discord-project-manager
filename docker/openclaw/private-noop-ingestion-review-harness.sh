#!/usr/bin/env sh
set -eu

RUNTIME_NAMESPACE="discord-project-manager/runtime/discord/<guild-id>/<channel-id>"
TARGET_NAMESPACE="discord-project-manager/project/<project-key>/private-context"
SCENARIO="${PRIVATE_NOOP_INGESTION_REVIEW_SCENARIO:-not-run}"

usage() {
  cat <<'USAGE'
Usage: discord-project-manager-private-noop-ingestion-review-harness [--scenario NAME]

Repo-safe private no-op ingestion review harness.
It emits deterministic sanitized review summaries only. It does not connect to
Discord, execute prompts, write to Engram, perform readback, or prove #211 ready.

Scenarios:
  not-run
  pass-summary
  missing-approval-binding
  missing-operator-attestation
  raw-private-evidence
  unsupported-success-claim
  write-readback-attempt
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --scenario)
      shift
      SCENARIO="${1:-}"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift || true
done

case "$SCENARIO" in
  not-run)
    review_state="blocked"
    acceptance_allowed="false"
    operator_attestation_present="false"
    approval_binding_present="false"
    sanitized_summary_present="false"
    raw_private_evidence_present="false"
    unsupported_success_claim="false"
    write_or_readback_attempted="false"
    reason="private no-op ingestion has not been run or reviewed"
    ;;
  pass-summary)
    review_state="pass-summary"
    acceptance_allowed="false"
    operator_attestation_present="true"
    approval_binding_present="true"
    sanitized_summary_present="true"
    raw_private_evidence_present="false"
    unsupported_success_claim="false"
    write_or_readback_attempted="false"
    reason="sanitized no-op ingestion summary is reviewable but cannot be accepted as write/readback readiness proof"
    ;;
  missing-approval-binding)
    review_state="blocked"
    acceptance_allowed="false"
    operator_attestation_present="true"
    approval_binding_present="false"
    sanitized_summary_present="true"
    raw_private_evidence_present="false"
    unsupported_success_claim="false"
    write_or_readback_attempted="false"
    reason="approval binding reference is missing"
    ;;
  missing-operator-attestation)
    review_state="blocked"
    acceptance_allowed="false"
    operator_attestation_present="false"
    approval_binding_present="true"
    sanitized_summary_present="true"
    raw_private_evidence_present="false"
    unsupported_success_claim="false"
    write_or_readback_attempted="false"
    reason="operator attestation is missing"
    ;;
  raw-private-evidence)
    review_state="blocked"
    acceptance_allowed="false"
    operator_attestation_present="true"
    approval_binding_present="true"
    sanitized_summary_present="true"
    raw_private_evidence_present="true"
    unsupported_success_claim="false"
    write_or_readback_attempted="false"
    reason="raw private evidence is forbidden"
    ;;
  unsupported-success-claim)
    review_state="blocked"
    acceptance_allowed="false"
    operator_attestation_present="true"
    approval_binding_present="true"
    sanitized_summary_present="true"
    raw_private_evidence_present="false"
    unsupported_success_claim="true"
    write_or_readback_attempted="false"
    reason="no-op ingestion review cannot claim write/readback readiness"
    ;;
  write-readback-attempt)
    review_state="blocked"
    acceptance_allowed="false"
    operator_attestation_present="true"
    approval_binding_present="true"
    sanitized_summary_present="true"
    raw_private_evidence_present="false"
    unsupported_success_claim="false"
    write_or_readback_attempted="true"
    reason="write/readback attempts are outside this harness"
    ;;
  *)
    echo "unknown scenario: $SCENARIO" >&2
    usage >&2
    exit 2
    ;;
esac

cat <<EOF
private_noop_ingestion_review_harness_result:
  evidence_mode: repo-safe-sanitized-review-harness
  scenario: $SCENARIO
  review_state: $review_state
  acceptance_allowed: $acceptance_allowed
  runtime_namespace: $RUNTIME_NAMESPACE
  target_namespace: $TARGET_NAMESPACE
  live_discord_connection: false
  live_engram_calls: false
  live_openclaw_prompt_execution: false
  live_discord_message_received: false
  live_discord_message_sent: false
  live_engram_write_attempted: false
  live_readback_attempted: false
  uses_real_discord_ids: false
  raw_private_evidence_present: $raw_private_evidence_present
  operator_attestation_present: $operator_attestation_present
  approval_binding_present: $approval_binding_present
  sanitized_summary_present: $sanitized_summary_present
  unsupported_success_claim: $unsupported_success_claim
  write_or_readback_attempted: $write_or_readback_attempted
  readiness_available_and_proven: false
  issue_211_status: blocked
  reason: $reason
EOF
