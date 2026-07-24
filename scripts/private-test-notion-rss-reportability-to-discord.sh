#!/usr/bin/env bash
set -euo pipefail

ENV_PATH="${ENV_PATH:-.env}"
[[ -f "$ENV_PATH" ]] || { echo "ERROR: env file not found: $ENV_PATH" >&2; exit 1; }

set -a
# shellcheck disable=SC1090
. "$ENV_PATH"
set +a

: "${NOTION_API_KEY:?NOTION_API_KEY is required in $ENV_PATH}"
: "${NOTION_SOURCE_DATA_SOURCE_ID:?NOTION_SOURCE_DATA_SOURCE_ID is required in $ENV_PATH}"
: "${DISCORD_BOT_TOKEN:?DISCORD_BOT_TOKEN is required in $ENV_PATH}"
: "${DISCORD_TEST_CHANNEL_ID:?DISCORD_TEST_CHANNEL_ID is required in $ENV_PATH}"

python3 - <<'PY'
from __future__ import annotations

import email.utils
import html
import json
import ipaddress
import os
import re
import socket
import sys
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from typing import Any

NOTION_API_KEY = os.environ["NOTION_API_KEY"]
DATA_SOURCE_ID = os.environ["NOTION_SOURCE_DATA_SOURCE_ID"]
DISCORD_BOT_TOKEN = os.environ["DISCORD_BOT_TOKEN"]
DISCORD_TEST_CHANNEL_ID = os.environ["DISCORD_TEST_CHANNEL_ID"]
NOTION_VERSION = os.environ.get("NOTION_VERSION", "2025-09-03")
ENDPOINT_MODE = os.environ.get("NOTION_SOURCE_QUERY_ENDPOINT", "auto")
MAX_SOURCES = min(max(int(os.environ.get("NOTION_SOURCE_MAX_RESULTS", "3")), 1), 10)
MAX_ITEMS_PER_SOURCE = min(max(int(os.environ.get("RSS_REPORTABILITY_MAX_ITEMS_PER_SOURCE", "5")), 1), 10)
MAX_REPORT_LINES = min(max(int(os.environ.get("RSS_REPORTABILITY_MAX_REPORT_LINES", "8")), 1), 20)
ALLOWED_FEED_HOSTS = {
    host.strip().lower()
    for host in os.environ.get("RSS_REPORTABILITY_ALLOWED_HOSTS", "www.reddit.com,old.reddit.com").split(",")
    if host.strip()
}

DPM_KEYWORDS = {
    "discord", "notion", "workflow", "workflows", "automation", "bot", "bots",
    "project", "management", "triage", "rss", "source", "registry", "publishing",
    "content", "operations", "agent", "agents", "llm", "ai", "openclaw",
    "approval", "review", "planner", "planning",
}
ACTIONABLE = {"how to", "guide", "checklist", "steps", "tutorial", "example", "case study", "playbook"}
NOISE = {"subscribe", "sponsored", "buy now", "discount", "deal", "promo"}


def request_json(url: str, *, method: str = "GET", headers: dict[str, str] | None = None, body: bytes | None = None) -> dict[str, Any]:
    req = urllib.request.Request(url, data=body, method=method, headers=headers or {})
    with urllib.request.urlopen(req, timeout=30) as resp:
        raw = resp.read(1_000_000)
    return json.loads(raw.decode("utf-8"))


def notion_query(kind: str) -> dict[str, Any]:
    if kind == "data_sources":
        url = f"https://api.notion.com/v1/data_sources/{DATA_SOURCE_ID}/query"
    elif kind == "databases":
        url = f"https://api.notion.com/v1/databases/{DATA_SOURCE_ID}/query"
    else:
        raise ValueError(kind)
    return request_json(
        url,
        method="POST",
        headers={
            "Authorization": f"Bearer {NOTION_API_KEY}",
            "Content-Type": "application/json",
            "Notion-Version": NOTION_VERSION,
        },
        body=json.dumps({"page_size": MAX_SOURCES}).encode("utf-8"),
    )


def query_notion() -> tuple[str, dict[str, Any]]:
    if ENDPOINT_MODE in {"data_sources", "databases"}:
        return ENDPOINT_MODE, notion_query(ENDPOINT_MODE)
    errors = []
    for kind in ("data_sources", "databases"):
        try:
            return kind, notion_query(kind)
        except Exception as exc:  # do not include secrets in exception text in final message
            errors.append(f"{kind}: {type(exc).__name__}")
    raise RuntimeError("Notion query failed for both endpoints: " + ", ".join(errors))


def prop_value(props: dict[str, Any], name: str) -> str:
    prop = props.get(name) or {}
    typ = prop.get("type")
    if typ == "title":
        return "".join(part.get("plain_text", "") for part in prop.get("title", []))
    if typ == "rich_text":
        return "".join(part.get("plain_text", "") for part in prop.get("rich_text", []))
    if typ == "select":
        return (prop.get("select") or {}).get("name") or ""
    if typ == "status":
        return (prop.get("status") or {}).get("name") or ""
    if typ == "multi_select":
        return ",".join(item.get("name", "") for item in prop.get("multi_select", []))
    if typ == "url":
        return prop.get("url") or ""
    return ""


def clean_text(value: str) -> str:
    value = re.sub(r"<[^>]+>", " ", value or "")
    value = html.unescape(value)
    value = re.sub(r"\s+", " ", value).strip()
    return value


def parse_date(value: str) -> datetime | None:
    value = (value or "").strip()
    if not value:
        return None
    try:
        parsed = email.utils.parsedate_to_datetime(value)
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        return parsed.astimezone(timezone.utc)
    except Exception:
        pass
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(timezone.utc)
    except Exception:
        return None


class NoRedirectHandler(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise urllib.error.HTTPError(req.full_url, code, "redirect blocked", headers, fp)


NO_REDIRECT_OPENER = urllib.request.build_opener(NoRedirectHandler)


def host_is_public(host: str) -> bool:
    try:
        infos = socket.getaddrinfo(host, None, proto=socket.IPPROTO_TCP)
    except socket.gaierror:
        return False
    addresses = {info[4][0] for info in infos}
    if not addresses:
        return False
    for address in addresses:
        ip = ipaddress.ip_address(address)
        if ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_multicast or ip.is_reserved:
            return False
    return True


def validate_feed_url(url: str) -> urllib.parse.ParseResult | None:
    parsed = urllib.parse.urlparse(url)
    host = (parsed.hostname or "").lower()
    if parsed.scheme not in {"http", "https"} or not host:
        return None
    if host not in ALLOWED_FEED_HOSTS:
        return None
    if not host_is_public(host):
        return None
    return parsed


def safe_feed_candidates(url: str) -> list[str]:
    parsed = validate_feed_url(url)
    if not parsed:
        return []
    candidates = [urllib.parse.urlunparse(parsed)]
    host = (parsed.hostname or "").lower()
    if host in {"www.reddit.com", "old.reddit.com"} and not parsed.path.endswith(".rss"):
        path = parsed.path.rstrip("/")
        candidates.append(urllib.parse.urlunparse((parsed.scheme, parsed.netloc, path + ".rss", "", "", "")))
    return list(dict.fromkeys(candidates))


def fetch_feed(url: str) -> tuple[str, bytes]:
    last_error = None
    for candidate in safe_feed_candidates(url):
        req = urllib.request.Request(candidate, headers={"User-Agent": "discord-project-manager-private-rehearsal/0.1"})
        try:
            with NO_REDIRECT_OPENER.open(req, timeout=20) as resp:
                raw = resp.read(1_000_000)
            return candidate, raw
        except Exception as exc:
            last_error = exc
    if isinstance(last_error, urllib.error.HTTPError):
        raise RuntimeError(f"HTTP_{last_error.code}")
    raise RuntimeError(type(last_error).__name__ if last_error else "invalid_feed_url")


def tag_name(elem: ET.Element) -> str:
    return elem.tag.rsplit("}", 1)[-1].lower()


def child_text(elem: ET.Element, names: set[str]) -> str:
    for child in list(elem):
        if tag_name(child) in names:
            return "".join(child.itertext()).strip()
    return ""


def child_link(elem: ET.Element) -> str:
    for child in list(elem):
        if tag_name(child) == "link":
            href = child.attrib.get("href")
            if href:
                return href.strip()
            text = "".join(child.itertext()).strip()
            if text:
                return text
    return ""


def parse_feed(raw: bytes, source_url: str) -> list[dict[str, Any]]:
    root = ET.fromstring(raw)
    entries: list[ET.Element] = []
    for elem in root.iter():
        name = tag_name(elem)
        if name in {"item", "entry"}:
            entries.append(elem)
    items = []
    for entry in entries[:MAX_ITEMS_PER_SOURCE]:
        title = clean_text(child_text(entry, {"title"})) or "Untitled item"
        link = child_link(entry) or source_url
        summary = clean_text(child_text(entry, {"description", "summary", "content", "encoded"})) or title
        date_raw = child_text(entry, {"pubdate", "published", "updated", "date"})
        published = parse_date(date_raw)
        items.append({
            "title": title[:160],
            "summary": summary[:500],
            "sourceUrl": link,
            "sourceDomain": urllib.parse.urlparse(link).netloc or urllib.parse.urlparse(source_url).netloc,
            "discoveredAt": (published or datetime.now(timezone.utc)).isoformat(),
            "publishedAt": published,
        })
    return items


def freshness_score(published: datetime | None) -> tuple[float, str]:
    if not published:
        return 0.05, "fecha-desconocida"
    age_days = max((datetime.now(timezone.utc) - published).total_seconds() / 86400, 0)
    if age_days <= 2:
        return 0.14, "fresh-update"
    if age_days <= 7:
        return 0.11, "fresh-week"
    if age_days <= 30:
        return 0.07, "recent-month"
    return 0.03, "stale"


def score_item(item: dict[str, Any], source: dict[str, Any]) -> dict[str, Any]:
    text = f"{item['title']} {item['summary']} {' '.join(source['tags'])}".lower()
    priority = source.get("priority", "medium").lower()
    source_category = source.get("category", "")
    priority_score = {"high": 0.25, "medium": 0.12, "low": 0.03}.get(priority, 0.12)
    trust_score = {
        "official": 0.25, "company": 0.18, "expert": 0.16, "curator": 0.08,
        "aggregator": 0.05, "community": 0.03, "weak": -0.05,
    }.get(source_category, 0.05 if source.get("type") == "rss" else 0.0)
    keyword_hits = sorted({kw for kw in DPM_KEYWORDS if re.search(rf"\b{re.escape(kw)}\b", text)})
    tag_hits = sorted(set(source.get("tags", [])) & DPM_KEYWORDS)
    topic_score = min(len(keyword_hits) * 0.10 + len(tag_hits) * 0.05, 0.38)
    fresh, fresh_reason = freshness_score(item.get("publishedAt"))
    actionable_hits = sorted({kw for kw in ACTIONABLE if kw in text})
    actionability = 0.07 if actionable_hits else 0.0
    noise_hits = sorted({kw for kw in NOISE if kw in text})
    noise_penalty = -0.06 if noise_hits else 0.0
    if len(item["title"] + item["summary"]) < 80:
        noise_penalty -= 0.08
    score = max(0.0, min(1.0, priority_score + trust_score + topic_score + fresh + actionability + noise_penalty))
    reasons = []
    if priority == "high": reasons.append("high-priority-source")
    if keyword_hits or tag_hits: reasons.append("topic-match")
    if fresh_reason in {"fresh-update", "fresh-week"}: reasons.append(fresh_reason)
    if actionability: reasons.append("actionable")
    if source_category in {"official", "company", "expert"}: reasons.append("trusted-source")
    if source_category in {"community", "aggregator", "weak"}: reasons.append("weak-source-needs-original")
    if noise_hits: reasons.append("noise-penalty")
    decision = "reportable" if score >= 0.55 else "watchlist" if score >= 0.32 else "discard"
    return {
        "score": round(score, 2),
        "decision": decision,
        "reasons": reasons or ["low-signal"],
        "breakdown": {
            "priority": round(priority_score, 2),
            "trust": round(trust_score, 2),
            "topic": round(topic_score, 2),
            "freshness": round(fresh, 2),
            "actionability": round(actionability, 2),
            "noisePenalty": round(noise_penalty, 2),
        },
    }


def discord_safe(value: str) -> str:
    return value.replace("@", "@\u200b")


def post_discord(content: str) -> dict[str, Any]:
    payload = json.dumps({"content": discord_safe(content), "allowed_mentions": {"parse": []}}).encode("utf-8")
    req = urllib.request.Request(
        f"https://discord.com/api/v10/channels/{DISCORD_TEST_CHANNEL_ID}/messages",
        data=payload,
        method="POST",
        headers={
            "Authorization": f"Bot {DISCORD_BOT_TOKEN}",
            "Content-Type": "application/json",
            "User-Agent": "DiscordBot (https://github.com/egdev6/discord-project-manager, private-rehearsal)",
        },
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))


def main() -> None:
    endpoint, notion = query_notion()
    sources = []
    for page in notion.get("results") or []:
        props = page.get("properties") or {}
        status = (prop_value(props, "Status") or "active").lower()
        source_type = (prop_value(props, "Source Type") or "").lower()
        url = prop_value(props, "URL")
        if status != "active" or source_type not in {"rss", "feed", "atom"} or not url:
            continue
        sources.append({
            "id": page.get("id"),
            "name": prop_value(props, "Name") or "Untitled source",
            "type": "rss",
            "url": url,
            "priority": prop_value(props, "Priority") or "medium",
            "tags": [t.strip().lower() for t in (prop_value(props, "Topic Tags") or "").split(",") if t.strip()],
            "category": (prop_value(props, "Source Category") or "aggregator").lower(),
            "cadence": prop_value(props, "Cadence") or "unspecified",
        })

    evaluated = []
    failures = []
    for source in sources[:MAX_SOURCES]:
        try:
            fetched_url, raw = fetch_feed(source["url"])
            items = parse_feed(raw, fetched_url)
            for item in items:
                scored = score_item(item, source)
                evaluated.append({"source": source, "item": item, "score": scored})
        except Exception as exc:
            failures.append({"source": source["name"], "error": str(exc)[:80] or type(exc).__name__})

    evaluated.sort(key=lambda row: row["score"]["score"], reverse=True)
    reportable = [r for r in evaluated if r["score"]["decision"] == "reportable"]
    watchlist = [r for r in evaluated if r["score"]["decision"] == "watchlist"]
    discard = [r for r in evaluated if r["score"]["decision"] == "discard"]

    lines = [
        "🧪 Prueba Notion → RSS → reportabilidad (#299)",
        "",
        f"Endpoint de Notion: `{endpoint}`",
        f"Fuentes RSS activas leídas: `{len(sources)}`",
        f"Items evaluados: `{len(evaluated)}` · reportables `{len(reportable)}` · watchlist `{len(watchlist)}` · descartados `{len(discard)}`",
        "Modo: solo respuesta — sin escritura en memoria, sin ledger, sin publicar y sin agendar.",
        "",
        "Top items sanitizados:",
    ]
    for idx, row in enumerate(evaluated[:MAX_REPORT_LINES], start=1):
        src, item, score = row["source"], row["item"], row["score"]
        domain = item.get("sourceDomain") or "none"
        title = clean_text(item["title"])[:120]
        reasons = ", ".join(score["reasons"][:4])
        lines.extend([
            f"{idx}. **{title}**",
            f"   fuente=`{src['name'][:60]}` dominio=`{domain}`",
            f"   score=`{score['score']}` decisión=`{score['decision']}` razones=`{reasons}`",
        ])
    if failures:
        lines.append("")
        lines.append(f"Fuentes con fallo aislado: `{len(failures)}`")
        for failure in failures[:5]:
            lines.append(f"- `{failure['source'][:60]}`: `{failure['error']}`")
    lines.append("")
    lines.append("Seguridad: no se enviaron tokens, payload crudo de Notion ni cuerpos RSS completos.")
    content = "\n".join(lines)
    if len(content) > 1900:
        content = content[:1800] + "\n…truncado para seguridad de Discord."

    response = post_discord(content)
    print("Prueba Notion RSS reportability → Discord: PASS")
    print(f"message_id: {response.get('id', 'unknown')}")
    print(f"sources: {len(sources)}")
    print(f"items_evaluated: {len(evaluated)}")
    print(f"reportable: {len(reportable)}")
    print(f"watchlist: {len(watchlist)}")
    print(f"discard: {len(discard)}")
    print("vista_previa_mensaje_sanitizado:")
    print(content)


if __name__ == "__main__":
    try:
        main()
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", "replace")[:300]
        print(f"ERROR: HTTP {exc.code}: {body}", file=sys.stderr)
        sys.exit(1)
PY
