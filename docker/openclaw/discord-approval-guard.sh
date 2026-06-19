#!/usr/bin/env sh
set -eu

APPROVAL_PHRASE="approve write"
STATE_SUMMARY_ONLY="summary-only"
STATE_APPROVAL_REQUESTED="approval-requested"
STATE_NEEDS_ROUTE="needs-route"
STATE_APPROVAL_VERIFICATION_REQUIRED="approval-verification-required"
WRITE_LIKE_TERMS="save write update remember store queue ledger publish schedule"

usage() {
  cat <<'USAGE'
Usage: discord-project-manager-approval-guard \
  --route-status <matched-route|unmapped-channel> \
  --request <text> \
  [--approval <text>] \
  [--prior-proposal <id>] \
  [--runtime-namespace <placeholder>] \
  [--target-namespace <namespace>]

Deterministic pre-write approval guard for repo-safe/private no-op validation.
It never authorizes writes by itself and never writes files, memory, queues,
ledgers, publishing targets, or workspace state.
USAGE
}

reject_unsafe_scalar() {
  name="$1"
  value="$2"
  case "$value" in
    *'
'*|*''*|*'	'*)
      echo "unsafe $name: control characters are not allowed" >&2
      exit 2
      ;;
  esac
}

route_status=""
request_text=""
approval_text=""
prior_proposal=""
runtime_namespace="discord-project-manager/runtime/discord/<guild-id>/<channel-id>"
target_namespace="none"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --route-status) shift; route_status="${1:-}" ;;
    --request) shift; request_text="${1:-}" ;;
    --approval) shift; approval_text="${1:-}" ;;
    --prior-proposal) shift; prior_proposal="${1:-}" ;;
    --runtime-namespace) shift; runtime_namespace="${1:-}" ;;
    --target-namespace) shift; target_namespace="${1:-}" ;;
    --help|-h) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

[ -n "$route_status" ] || { echo "missing --route-status" >&2; exit 2; }
[ -n "$request_text" ] || { echo "missing --request" >&2; exit 2; }

for pair in \
  "route_status:$route_status" \
  "request:$request_text" \
  "approval:$approval_text" \
  "prior_proposal:$prior_proposal" \
  "runtime_namespace:$runtime_namespace" \
  "target_namespace:$target_namespace"; do
  reject_unsafe_scalar "${pair%%:*}" "${pair#*:}"
done

case "$route_status" in
  matched-route|unmapped-channel) ;;
  *) echo "unsupported route status: $route_status" >&2; exit 2 ;;
esac

lower_request=$(printf '%s' "$request_text" | tr '[:upper:]' '[:lower:]')
write_like=false
for term in $WRITE_LIKE_TERMS; do
  case " $lower_request " in
    *" $term "*|*" $term:"*|*" $term,"*|*" $term."*|*" $term"*)
      write_like=true
      break
      ;;
  esac
done

response_state="$STATE_SUMMARY_ONLY"
persistent_writes_allowed=false
workspace_file_writes_allowed=false
memory_writes_allowed=false
engram_writes_allowed=false
publishing_allowed=false
scheduling_allowed=false
durable_reads_allowed=true
writes_attempted=false
prompt_execution="none"
allowed_write_scope="none"
audit_required=false
guard_event_type="guard-summary"
operator_signal_required=false
reason="read-only request"

if [ "$route_status" = "unmapped-channel" ]; then
  response_state="$STATE_NEEDS_ROUTE"
  durable_reads_allowed=false
  guard_event_type="guard-needs-route"
  reason="unmapped route cannot read or write durable project memory"
elif [ "$write_like" = "true" ]; then
  if [ "$approval_text" = "$APPROVAL_PHRASE" ]; then
    response_state="$STATE_APPROVAL_VERIFICATION_REQUIRED"
    guard_event_type="guard-approval-verification-required"
    operator_signal_required=true
    audit_required=true
    reason="exact approval phrase received; server-side proposal binding verification required before writes"
  elif [ -n "$approval_text" ]; then
    response_state="$STATE_APPROVAL_REQUESTED"
    guard_event_type="guard-invalid-approval"
    operator_signal_required=true
    reason="invalid approval input; exact approve write is required"
  else
    response_state="$STATE_APPROVAL_REQUESTED"
    guard_event_type="guard-denial"
    reason="write-like request requires exact approve write before persistence"
  fi
fi

cat <<EOF
approval_guard_result:
  route_status: $route_status
  write_like: $write_like
  response_state: $response_state
  runtime_namespace: $runtime_namespace
  target_namespace: $target_namespace
  prior_proposal_ref: ${prior_proposal:-none}
  exact_approval_received: $([ "$approval_text" = "$APPROVAL_PHRASE" ] && echo true || echo false)
  persistent_writes_allowed: $persistent_writes_allowed
  workspace_file_writes_allowed: $workspace_file_writes_allowed
  memory_writes_allowed: $memory_writes_allowed
  engram_writes_allowed: $engram_writes_allowed
  publishing_allowed: $publishing_allowed
  scheduling_allowed: $scheduling_allowed
  durable_reads_allowed: $durable_reads_allowed
  writes_attempted: $writes_attempted
  prompt_execution: $prompt_execution
  allowed_write_scope: $allowed_write_scope
  audit_required: $audit_required
  guard_event_type: $guard_event_type
  operator_signal_required: $operator_signal_required
  reason: $reason
EOF
