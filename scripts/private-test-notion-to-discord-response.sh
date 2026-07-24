#!/usr/bin/env bash
set -euo pipefail

ENV_PATH="${ENV_PATH:-.env}"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found on PATH: $1"
}

require_cmd curl
require_cmd python3

[[ -f "$ENV_PATH" ]] || fail "env file not found: $ENV_PATH"

set -a
# shellcheck disable=SC1090
. "$ENV_PATH"
set +a

: "${NOTION_API_KEY:?NOTION_API_KEY is required in $ENV_PATH}"
: "${NOTION_SOURCE_DATA_SOURCE_ID:?NOTION_SOURCE_DATA_SOURCE_ID is required in $ENV_PATH}"
: "${DISCORD_BOT_TOKEN:?DISCORD_BOT_TOKEN is required in $ENV_PATH}"
: "${DISCORD_TEST_CHANNEL_ID:?DISCORD_TEST_CHANNEL_ID is required in $ENV_PATH}"

NOTION_VERSION="${NOTION_VERSION:-2025-09-03}"
NOTION_SOURCE_QUERY_ENDPOINT="${NOTION_SOURCE_QUERY_ENDPOINT:-auto}"
NOTION_SOURCE_MAX_RESULTS="${NOTION_SOURCE_MAX_RESULTS:-3}"

case "$NOTION_SOURCE_QUERY_ENDPOINT" in
  auto|data_sources|databases) ;;
  *) fail "NOTION_SOURCE_QUERY_ENDPOINT must be auto, data_sources, or databases" ;;
esac

case "$NOTION_SOURCE_MAX_RESULTS" in
  ''|*[!0-9]*) fail "NOTION_SOURCE_MAX_RESULTS must be a positive integer" ;;
  *) ;;
esac

if [[ "$NOTION_SOURCE_MAX_RESULTS" -lt 1 || "$NOTION_SOURCE_MAX_RESULTS" -gt 10 ]]; then
  fail "NOTION_SOURCE_MAX_RESULTS must be between 1 and 10 for safe rehearsal"
fi

case "$DISCORD_TEST_CHANNEL_ID" in
  ''|*[!0-9]*) fail "DISCORD_TEST_CHANNEL_ID must be a numeric Discord channel id in private .env" ;;
  *) ;;
esac

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

query_endpoint() {
  local kind="$1"
  local url
  case "$kind" in
    data_sources) url="https://api.notion.com/v1/data_sources/${NOTION_SOURCE_DATA_SOURCE_ID}/query" ;;
    databases) url="https://api.notion.com/v1/databases/${NOTION_SOURCE_DATA_SOURCE_ID}/query" ;;
    *) fail "invalid endpoint kind: $kind" ;;
  esac

  curl --silent --show-error --fail-with-body \
    --request POST "$url" \
    --connect-timeout 10 \
    --max-time 30 \
    --header "Authorization: Bearer ${NOTION_API_KEY}" \
    --header "Content-Type: application/json" \
    --header "Notion-Version: ${NOTION_VERSION}" \
    --data "{\"page_size\":${NOTION_SOURCE_MAX_RESULTS}}"
}

response_path="$tmp_dir/notion-response.json"
endpoint_used=""

if [[ "$NOTION_SOURCE_QUERY_ENDPOINT" == "auto" ]]; then
  if query_endpoint data_sources >"$response_path" 2>"$tmp_dir/data_sources.err"; then
    endpoint_used="data_sources"
  elif query_endpoint databases >"$response_path" 2>"$tmp_dir/databases.err"; then
    endpoint_used="databases"
  else
    echo "Data sources endpoint failed:" >&2
    sed 's/Bearer [^[:space:]]*/Bearer <redacted>/g' "$tmp_dir/data_sources.err" >&2 || true
    echo "Databases endpoint failed:" >&2
    sed 's/Bearer [^[:space:]]*/Bearer <redacted>/g' "$tmp_dir/databases.err" >&2 || true
    fail "Notion query failed for both data_sources and databases endpoints"
  fi
else
  query_endpoint "$NOTION_SOURCE_QUERY_ENDPOINT" >"$response_path"
  endpoint_used="$NOTION_SOURCE_QUERY_ENDPOINT"
fi

message_path="$tmp_dir/discord-message.json"
summary_path="$tmp_dir/sanitized-summary.txt"

python3 - "$response_path" "$endpoint_used" "$summary_path" "$message_path" <<'PY'
import json
import sys
from urllib.parse import urlparse

response_path, endpoint, summary_path, message_path = sys.argv[1:5]
with open(response_path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

results = data.get("results") or []

def prop_value(props, name):
    prop = props.get(name) or {}
    typ = prop.get("type")
    if typ == "title":
        return "".join(part.get("plain_text", "") for part in prop.get("title", []))
    if typ == "rich_text":
        return "".join(part.get("plain_text", "") for part in prop.get("rich_text", []))
    if typ == "select":
        sel = prop.get("select") or {}
        return sel.get("name") or ""
    if typ == "status":
        status = prop.get("status") or {}
        return status.get("name") or ""
    if typ == "multi_select":
        return ", ".join(item.get("name", "") for item in prop.get("multi_select", []))
    if typ == "url":
        return prop.get("url") or ""
    return ""

lines = [
    "🧪 Prueba read-only del registro de fuentes (#299)",
    "",
    f"Endpoint de Notion: `{endpoint}`",
    f"Filas leídas: `{len(results)}`",
    "Modo: solo respuesta — sin escritura en memoria, sin ledger, sin publicar y sin agendar.",
    "",
    "Fuentes sanitizadas:",
]

for idx, page in enumerate(results, start=1):
    props = page.get("properties") or {}
    name = (prop_value(props, "Name") or "Untitled source")[:80]
    status = prop_value(props, "Status") or "active(default)"
    source_type = prop_value(props, "Source Type") or "unspecified"
    priority = prop_value(props, "Priority") or "medium(default)"
    cadence = prop_value(props, "Cadence") or "unspecified"
    tags = prop_value(props, "Topic Tags") or "none"
    url = prop_value(props, "URL")
    domain = urlparse(url).netloc if url.startswith(("http://", "https://")) else "none"
    lines.extend([
        f"{idx}. **{name}**",
        f"   estado=`{status}` tipo=`{source_type}` prioridad=`{priority}` cadencia=`{cadence}`",
        f"   tags=`{tags[:120]}` dominio=`{domain}`",
    ])

lines.append("")
lines.append("Seguridad: no se imprimieron ni enviaron tokens ni payload crudo de Notion.")
content = "\n".join(lines)
if len(content) > 1900:
    content = content[:1800] + "\n…truncated for Discord safety."

discord_content = content.replace("@", "@\u200b")
with open(summary_path, "w", encoding="utf-8") as fh:
    fh.write(content + "\n")
with open(message_path, "w", encoding="utf-8") as fh:
    json.dump({"content": discord_content, "allowed_mentions": {"parse": []}}, fh)
PY

curl --silent --show-error --fail-with-body \
  --request POST "https://discord.com/api/v10/channels/${DISCORD_TEST_CHANNEL_ID}/messages" \
  --connect-timeout 10 \
  --max-time 30 \
  --header "Authorization: Bot ${DISCORD_BOT_TOKEN}" \
  --header "Content-Type: application/json" \
  --data-binary "@${message_path}" \
  >"$tmp_dir/discord-response.json"

python3 - "$tmp_dir/discord-response.json" "$summary_path" <<'PY'
import json
import sys

response_path, summary_path = sys.argv[1:3]
with open(response_path, "r", encoding="utf-8") as fh:
    response = json.load(fh)
message_id = response.get("id", "unknown")
channel_id = response.get("channel_id", "unknown")
with open(summary_path, "r", encoding="utf-8") as fh:
    summary = fh.read()
print("Prueba Discord solo-respuesta: PASS")
print(f"channel_id: {channel_id}")
print(f"message_id: {message_id}")
print("vista_previa_mensaje_sanitizado:")
print(summary)
PY
