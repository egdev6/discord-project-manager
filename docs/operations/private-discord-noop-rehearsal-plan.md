# Private Discord no-op rehearsal plan

Status: preparation only. This plan does not grant execution approval and does not prove live Discord gateway delivery.

## Purpose

Prepare a summary-minimum evidence path for a future private, non-production, redacted no-op observation rehearsal for #211.

The rehearsal may only observe a no-op event after a separate explicit approval. It must not send a write-like live Discord message, write to Engram, execute prompts, mutate workspace files, publish, schedule, mutate GitHub, or expose private payloads.

## Required gates before execution

All gates must be checked before any private event is observed:

- private non-production guild and channel prepared outside git;
- credentials present outside git and never printed;
- `bash scripts/validate-discord-approval-guard-cli.sh` passes;
- `bash scripts/validate-discord-noop-observation-cli.sh` passes;
- `bash scripts/validate-discord-runtime-boundary-harness.sh` passes;
- `bash scripts/validate-private-discord-engram-rehearsal-readiness.sh` still reports blocked until explicit approval;
- `bash scripts/validate-repo-safe-evidence.sh` passes;
- explicit execution approval is granted in a later step for no-op observation only.

## Allowed public evidence

Public evidence is summary-minimum only:

- pass/blocked/not-run status summary;
- placeholder namespace refs such as `<guild-id>` and `<channel-id>`;
- command names and pass/fail summaries;
- sanitized no-op state table;
- explicit operator decision summary without identifiers.

## Forbidden public evidence

Do not commit or paste:

- real Discord guild, channel, user, role, or message IDs;
- credentials, tokens, `.env` values, or secret-like strings;
- screenshots;
- raw logs;
- transcripts;
- private payloads;
- raw Engram exports;
- SQL dumps;
- backup archives or volume dumps.

## Stop rules

Abort before observing any event if:

- the environment points at a public guild/channel;
- credentials or identifiers would need to be printed;
- the runtime requires prompt execution to observe the event;
- the runtime requires workspace, filesystem, memory, Engram, publishing, scheduling, GitHub, or external side-effect writes;
- evidence would require raw logs, screenshots, transcripts, private payloads, or secrets;
- exact scope or approval is ambiguous.

## Planned sanitized result states

- `not-run`: preparation exists but no explicit execution approval was granted;
- `blocked`: a gate failed or required unsafe evidence;
- `pass-summary`: a separately approved private no-op observation completed with sanitized summary only;
- `aborted`: execution stopped before private data or side effects were exposed.

## Current result

Current result: `not-run`.

No live Discord message was sent. No private event was observed. No Engram write/readback was attempted. #211 remains blocked.
