#!/usr/bin/env bash
set -euo pipefail

ENV_PATH="${ENV_PATH:-.env}"

if [[ "${1:-}" == "--self-test" ]]; then
  python3 - <<'PYTEST'

def clamp_float(raw, default, minimum=0.0, maximum=1.0):
    try:
        value = float(raw)
    except (TypeError, ValueError):
        return default
    return min(max(value, minimum), maximum)

def normalize_thresholds(reportable, watchlist):
    reportable = clamp_float(reportable, 0.55)
    watchlist = clamp_float(watchlist, 0.32)
    if reportable < watchlist:
        reportable, watchlist = 0.55, 0.32
    return reportable, watchlist

def decide(score, reportable, watchlist):
    return "reportable" if score >= reportable else "watchlist" if score >= watchlist else "discard"

assert clamp_float("-0.2", 0.06) == 0.0
assert clamp_float("1.4", 0.06) == 1.0
assert normalize_thresholds("0.2", "0.8") == (0.55, 0.32)
assert decide(0.60, 0.55, 0.32) == "reportable"
assert decide(0.40, 0.55, 0.32) == "watchlist"
assert decide(0.10, 0.55, 0.32) == "discard"
print("Dynamic scoring profile self-test: PASS")
PYTEST
  exit 0
fi
SCORING_PROFILE_OVERRIDE="${SCORING_PROFILE:-}"
NOTION_SOURCE_MAX_RESULTS_OVERRIDE="${NOTION_SOURCE_MAX_RESULTS:-}"
RSS_REPORTABILITY_ALLOWED_HOSTS_OVERRIDE="${RSS_REPORTABILITY_ALLOWED_HOSTS:-}"
[[ -f "$ENV_PATH" ]] || { echo "ERROR: env file not found: $ENV_PATH" >&2; exit 1; }

set -a
# shellcheck disable=SC1090
. "$ENV_PATH"
set +a
if [[ -n "$SCORING_PROFILE_OVERRIDE" ]]; then
  SCORING_PROFILE="$SCORING_PROFILE_OVERRIDE"
fi
if [[ -n "$NOTION_SOURCE_MAX_RESULTS_OVERRIDE" ]]; then
  NOTION_SOURCE_MAX_RESULTS="$NOTION_SOURCE_MAX_RESULTS_OVERRIDE"
fi
if [[ -n "$RSS_REPORTABILITY_ALLOWED_HOSTS_OVERRIDE" ]]; then
  RSS_REPORTABILITY_ALLOWED_HOSTS="$RSS_REPORTABILITY_ALLOWED_HOSTS_OVERRIDE"
fi

: "${NOTION_API_KEY:?NOTION_API_KEY is required in $ENV_PATH}"
: "${NOTION_SOURCE_DATA_SOURCE_ID:?NOTION_SOURCE_DATA_SOURCE_ID is required in $ENV_PATH}"
: "${NOTION_SCORING_PROFILES_DATA_SOURCE_ID:?NOTION_SCORING_PROFILES_DATA_SOURCE_ID is required in $ENV_PATH}"
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
SCORING_PROFILES_DATA_SOURCE_ID = os.environ["NOTION_SCORING_PROFILES_DATA_SOURCE_ID"]
SCORING_PROFILE_NAME = os.environ.get("SCORING_PROFILE", "ai-news")
DISCORD_BOT_TOKEN = os.environ["DISCORD_BOT_TOKEN"]
DISCORD_TEST_CHANNEL_ID = os.environ["DISCORD_TEST_CHANNEL_ID"]
NOTION_VERSION = os.environ.get("NOTION_VERSION", "2025-09-03")
ENDPOINT_MODE = os.environ.get("NOTION_SOURCE_QUERY_ENDPOINT", "auto")
MAX_SOURCES = min(max(int(os.environ.get("NOTION_SOURCE_MAX_RESULTS", "3")), 1), 10)
MAX_ITEMS_PER_SOURCE = min(max(int(os.environ.get("RSS_REPORTABILITY_MAX_ITEMS_PER_SOURCE", "5")), 1), 10)
MAX_REPORT_LINES = min(max(int(os.environ.get("RSS_REPORTABILITY_MAX_REPORT_LINES", "8")), 1), 20)
ALLOWED_FEED_HOSTS = {
    host.strip().lower()
    for host in os.environ.get("RSS_REPORTABILITY_ALLOWED_HOSTS", "www.reddit.com,old.reddit.com,cassidoo.co,overreacted.io,kentcdodds.com,www.joshwcomeau.com,pnpm.io,ollama.com,code.visualstudio.com").split(",")
    if host.strip()
}

DEFAULT_ACTIONABLE = {"how to", "guide", "checklist", "steps", "tutorial", "example", "case study", "playbook"}


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
    if typ == "number":
        value = prop.get("number")
        return "" if value is None else str(value)
    return ""


def parse_csv(value: str) -> list[str]:
    return [part.strip().lower() for part in (value or "").split(",") if part.strip()]


def parse_float(value: str, default: float, minimum: float | None = None, maximum: float | None = None) -> float:
    try:
        parsed = float(value)
    except (TypeError, ValueError):
        parsed = default
    if minimum is not None:
        parsed = max(parsed, minimum)
    if maximum is not None:
        parsed = min(parsed, maximum)
    return parsed


def parse_boosts(value: str) -> dict[str, float]:
    boosts: dict[str, float] = {}
    for part in (value or "").split(","):
        if ":" not in part:
            continue
        key, raw_score = part.split(":", 1)
        key = key.strip().lower()
        if not key:
            continue
        boosts[key] = parse_float(raw_score.strip(), 0.0)
    return boosts


def query_scoring_profiles() -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    start_cursor: str | None = None
    while True:
        payload: dict[str, Any] = {"page_size": 25}
        if start_cursor:
            payload["start_cursor"] = start_cursor
        data = request_json(
            f"https://api.notion.com/v1/data_sources/{SCORING_PROFILES_DATA_SOURCE_ID}/query",
            method="POST",
            headers={
                "Authorization": f"Bearer {NOTION_API_KEY}",
                "Content-Type": "application/json",
                "Notion-Version": NOTION_VERSION,
            },
            body=json.dumps(payload).encode("utf-8"),
        )
        rows.extend(data.get("results") or [])
        if not data.get("has_more"):
            return rows
        start_cursor = data.get("next_cursor")
        if not start_cursor:
            return rows


def default_scoring_profile(reason: str) -> dict[str, Any]:
    return {
        "name": f"default-safe ({reason})",
        "target_topics": {"ai", "llm", "agents", "automation", "content", "workflow"},
        "high_keywords": {"ai", "llm", "agents", "automation"},
        "medium_keywords": {"content", "workflow", "tooling", "benchmark"},
        "negative_keywords": {"sponsored", "discount", "giveaway", "meme"},
        "tag_boosts": {"ai": 0.08, "llm": 0.08, "agents": 0.06, "content": 0.05},
        "preferred_categories": {"official", "company", "expert"},
        "preferred_networks": set(),
        "reportable_threshold": 0.65,
        "watchlist_threshold": 0.40,
        "freshness_window_days": 7.0,
        "actionability_boost": 0.05,
        "noise_penalty": 0.08,
    }


def normalize_thresholds(reportable: float, watchlist: float) -> tuple[float, float]:
    if reportable < watchlist:
        return 0.55, 0.32
    return reportable, watchlist


def load_scoring_profile() -> dict[str, Any]:
    profile_name = SCORING_PROFILE_NAME.strip().lower()
    try:
        rows = query_scoring_profiles()
    except Exception:
        return default_scoring_profile("profile-query-failed")
    active_profiles = []
    for page in rows:
        props = page.get("properties") or {}
        name = (prop_value(props, "Name") or "").strip().lower()
        status = (prop_value(props, "Status") or "active").strip().lower()
        if status == "active":
            active_profiles.append(name)
        if name != profile_name or status != "active":
            continue
        high = set(parse_csv(prop_value(props, "High Keywords")))
        medium = set(parse_csv(prop_value(props, "Medium Keywords")))
        target_topics = set(parse_csv(prop_value(props, "Target Topics")))
        negative = set(parse_csv(prop_value(props, "Negative Keywords")))
        tag_boosts = parse_boosts(prop_value(props, "Source Tag Boosts"))
        return {
            "name": name,
            "target_topics": target_topics,
            "high_keywords": high,
            "medium_keywords": medium,
            "negative_keywords": negative,
            "tag_boosts": tag_boosts,
            "preferred_categories": set(parse_csv(prop_value(props, "Preferred Source Categories"))),
            "preferred_networks": set(parse_csv(prop_value(props, "Preferred Networks"))),
            "reportable_threshold": parse_float(prop_value(props, "Reportable Threshold"), 0.55, 0.0, 1.0),
            "watchlist_threshold": parse_float(prop_value(props, "Watchlist Threshold"), 0.32, 0.0, 1.0),
            "freshness_window_days": parse_float(prop_value(props, "Freshness Window Days"), 7.0, 0.0, 365.0),
            "actionability_boost": parse_float(prop_value(props, "Actionability Boost"), 0.07, 0.0, 1.0),
            "noise_penalty": parse_float(prop_value(props, "Noise Penalty"), 0.06, 0.0, 1.0),
        }
        profile["reportable_threshold"], profile["watchlist_threshold"] = normalize_thresholds(
            profile["reportable_threshold"], profile["watchlist_threshold"]
        )
        return profile
    return default_scoring_profile(f"profile-not-found:{profile_name}")


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


def freshness_score(published: datetime | None, freshness_window_days: float) -> tuple[float, str]:
    if not published:
        return 0.05, "fecha-desconocida"
    age_days = max((datetime.now(timezone.utc) - published).total_seconds() / 86400, 0)
    if age_days <= 2:
        return 0.14, "fresh-update"
    if age_days <= freshness_window_days:
        return 0.11, "fresh-window"
    if age_days <= 30:
        return 0.07, "recent-month"
    return 0.03, "stale"


def keyword_present(keyword: str, text: str) -> bool:
    if " " in keyword:
        return keyword in text
    return re.search(rf"\b{re.escape(keyword)}\b", text) is not None


def score_item(item: dict[str, Any], source: dict[str, Any], profile: dict[str, Any]) -> dict[str, Any]:
    text = f"{item['title']} {item['summary']} {' '.join(source['tags'])}".lower()
    source_tags = set(source.get("tags", []))
    priority = source.get("priority", "medium").lower()
    source_category = source.get("category", "")
    priority_score = {"high": 0.25, "medium": 0.12, "low": 0.03}.get(priority, 0.12)
    trust_score = {
        "official": 0.25, "company": 0.18, "expert": 0.16, "curator": 0.08,
        "aggregator": 0.05, "community": 0.03, "weak": -0.05,
    }.get(source_category, 0.05 if source.get("type") == "rss" else 0.0)
    if source_category in profile["preferred_categories"]:
        trust_score += 0.04
    high_hits = sorted({kw for kw in profile["high_keywords"] if keyword_present(kw, text)})
    medium_hits = sorted({kw for kw in profile["medium_keywords"] if keyword_present(kw, text)})
    topic_hits = sorted(source_tags & profile["target_topics"])
    tag_boost_score = sum(profile["tag_boosts"].get(tag, 0.0) for tag in source_tags)
    topic_score = min(len(high_hits) * 0.14 + len(medium_hits) * 0.07 + len(topic_hits) * 0.05 + tag_boost_score, 0.42)
    fresh, fresh_reason = freshness_score(item.get("publishedAt"), profile["freshness_window_days"])
    actionable_hits = sorted({kw for kw in DEFAULT_ACTIONABLE if kw in text})
    actionability = profile["actionability_boost"] if actionable_hits else 0.0
    negative_hits = sorted({kw for kw in profile["negative_keywords"] if keyword_present(kw, text)})
    noise_penalty = -profile["noise_penalty"] if negative_hits else 0.0
    if len(item["title"] + item["summary"]) < 80:
        noise_penalty -= 0.08
    score = max(0.0, min(1.0, priority_score + trust_score + topic_score + fresh + actionability + noise_penalty))
    reasons = []
    if priority == "high": reasons.append("high-priority-source")
    if high_hits: reasons.append("high-keyword-match")
    if medium_hits: reasons.append("medium-keyword-match")
    if topic_hits: reasons.append("source-tag-match")
    if fresh_reason in {"fresh-update", "fresh-window"}: reasons.append(fresh_reason)
    if actionability: reasons.append("actionable")
    if source_category in {"official", "company", "expert"}: reasons.append("trusted-source")
    if source_category in {"community", "aggregator", "weak"}: reasons.append("weak-source-needs-original")
    if negative_hits: reasons.append("negative-keyword-penalty")
    decision = "reportable" if score >= profile["reportable_threshold"] else "watchlist" if score >= profile["watchlist_threshold"] else "discard"
    return {
        "score": round(score, 2),
        "decision": decision,
        "reasons": reasons or ["low-signal"],
        "profile": profile["name"],
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
    profile = load_scoring_profile()
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
                scored = score_item(item, source, profile)
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
        f"Perfil de scoring: `{profile['name']}`",
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
    print(f"scoring_profile: {profile['name']}")
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
