#!/usr/bin/env sh
set -eu

usage() {
  cat <<'USAGE'
Usage: discord-project-manager-noop-observation \
  --route-status <matched-route|unmapped-channel> \
  --content-summary <sanitized-text> \
  [--runtime-namespace <placeholder>] \
  [--target-namespace <namespace>]

Repo-safe synthetic no-op observation for Discord-originated requests.
It performs no network calls, prompt execution, filesystem writes, workspace writes,
Engram writes, publishing, scheduling, or GitHub mutations.
USAGE
}

reject_unsafe_scalar() {
  name="$1"
  value="$2"
  without_basic_control=$(printf '%s' "$value" | tr -d '\n\r\t')
  if [ "$without_basic_control" != "$value" ]; then
    echo "unsafe $name: control characters are not allowed" >&2
    exit 2
  fi
  case "$value" in
    *'{'*|*'}'*|*'['*|*']'*|*':'*|*'&'*|*'*'*|*'#'*|*'|'*)
      echo "unsafe $name: YAML metacharacters are not allowed in sanitized no-op output" >&2
      exit 2
      ;;
  esac
  if printf '%s' "$value" | grep -E '[0-9]{17,20}|(TOKEN|SECRET|PASSWORD|API_KEY|DISCORD|ENGRAM|OPENCLAW|GITHUB|GH)_[A-Z0-9_]*=|gh[pousr]_[A-Za-z0-9_]{20,}|[A-Za-z0-9_-]{24,}\.[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{20,}' >/dev/null 2>&1; then
    echo "unsafe $name: possible private identifier or secret-like value" >&2
    exit 2
  fi
}

find_guard() {
  script_dir=$(unset CDPATH; cd -- "$(dirname -- "$0")" && pwd)

  if [ -x "$script_dir/discord-project-manager-approval-guard" ]; then
    printf '%s\n' "$script_dir/discord-project-manager-approval-guard"
    return 0
  fi

  if [ -x "$script_dir/discord-approval-guard.sh" ]; then
    printf '%s\n' "$script_dir/discord-approval-guard.sh"
    return 0
  fi

  if [ -f "docker/openclaw/discord-approval-guard.sh" ]; then
    printf '%s\n' "docker/openclaw/discord-approval-guard.sh"
    return 0
  fi

  echo "approval guard not found" >&2
  exit 2
}

require_guard_field() {
  field="$1"
  value=$(printf '%s\n' "$guard_output" | awk -F': ' -v key="  $field" '$1 == key { print $2; exit }')
  if [ -z "$value" ]; then
    echo "approval guard output missing required field: $field" >&2
    exit 2
  fi
  printf '%s\n' "$value"
}

route_status=""
content_summary=""
runtime_namespace="discord-project-manager/runtime/discord/<guild-id>/<channel-id>"
target_namespace="discord-project-manager/project/demo-project/private-context"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --route-status) shift; route_status="${1:-}" ;;
    --content-summary) shift; content_summary="${1:-}" ;;
    --runtime-namespace) shift; runtime_namespace="${1:-}" ;;
    --target-namespace) shift; target_namespace="${1:-}" ;;
    --help|-h) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

[ -n "$route_status" ] || { echo "missing --route-status" >&2; exit 2; }
[ -n "$content_summary" ] || { echo "missing --content-summary" >&2; exit 2; }

for pair in \
  "route_status:$route_status" \
  "content_summary:$content_summary" \
  "runtime_namespace:$runtime_namespace" \
  "target_namespace:$target_namespace"; do
  reject_unsafe_scalar "${pair%%:*}" "${pair#*:}"
done

case "$route_status" in
  matched-route|unmapped-channel) ;;
  *) echo "unsupported route status: $route_status" >&2; exit 2 ;;
esac

guard_path=$(find_guard)
guard_output=$(sh "$guard_path" \
  --route-status "$route_status" \
  --request "$content_summary" \
  --runtime-namespace "$runtime_namespace" \
  --target-namespace "$target_namespace")

response_state=$(require_guard_field response_state)
write_like=$(require_guard_field write_like)
persistent_writes_allowed=$(require_guard_field persistent_writes_allowed)
workspace_file_writes_allowed=$(require_guard_field workspace_file_writes_allowed)
engram_writes_allowed=$(require_guard_field engram_writes_allowed)
durable_reads_allowed=$(require_guard_field durable_reads_allowed)
writes_attempted=$(require_guard_field writes_attempted)
prompt_execution=$(require_guard_field prompt_execution)
guard_event_type=$(require_guard_field guard_event_type)

cat <<EOF
noop_observation_result:
  event_source: synthetic-discord-envelope
  live_discord_connection: false
  live_engram_calls: false
  live_openclaw_prompt_execution: false
  runtime_namespace: $runtime_namespace
  target_namespace: $target_namespace
  route_status: $route_status
  content_summary: $content_summary
  write_like: $write_like
  response_state: $response_state
  persistent_writes_allowed: $persistent_writes_allowed
  workspace_file_writes_allowed: $workspace_file_writes_allowed
  engram_writes_allowed: $engram_writes_allowed
  durable_reads_allowed: $durable_reads_allowed
  writes_attempted: $writes_attempted
  prompt_execution: $prompt_execution
  guard_event_type: $guard_event_type
  network_calls_attempted: false
  filesystem_writes_attempted: false
  publishing_attempted: false
  scheduling_attempted: false
  github_mutations_attempted: false
  evidence_policy: sanitized-summary-only
EOF
