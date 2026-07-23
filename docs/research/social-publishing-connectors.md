# Social publishing connector research

This research slice evaluates connector options for social publishing without implementing live publishing, scheduling, OAuth, browser automation, or provider API calls. It is a fake-first contract for docs, fixtures, and validation only.

## Options matrix

| Option | Reliability | Privacy exposure | ToS/compliance risk | Implementation effort | Credential model | Approval status | Scheduling support | Ledger update behavior |
|---|---|---|---|---|---|---|---|---|
| Buffer GraphQL publishing | high if Buffer account, profiles, and API access are approved | medium; Buffer OAuth credentials can act on connected social profiles | medium; depends on Buffer terms and approved OAuth use | medium | Buffer OAuth access/refresh tokens or API key in private runtime only; scopes such as posts:read, posts:write, offline_access when approved | candidate-provider; no live activity approved in this slice | documented Buffer scheduling concepts exist through createPost/scheduled posts surfaces, but not validated live here | Update content ledger to `queued` only after a fake successful schedule result, or `published` only after a fake successful publish result; failures leave ledger unchanged. |
| Direct LinkedIn API | medium; official Posts API exists but access is gated | medium-high; organization/member tokens and author URNs are sensitive | medium-high; Community Management API access can require app review/tier approval | high | LinkedIn OAuth/user or organization tokens in private runtime only | pending-provider-approval; not approved for live publishing here | no official scheduling endpoint confirmed in captured research | Update ledger only after a fake successful LinkedIn publish result; schedule remains unsupported unless a separately approved provider contract exists. |
| Direct X API | medium; official post creation APIs exist but access is paid/approved | medium-high; developer app credentials and user tokens are sensitive | medium-high; developer policy, paid tier, and automation constraints apply | high | X developer app OAuth/user tokens in private runtime only | pending-provider-approval; not approved for live publishing here | no official scheduling endpoint confirmed in captured research | Update ledger only after a fake successful X publish result; schedule remains unsupported unless a separately approved provider contract exists. |
| Browser-assisted manual publishing | medium; human operator can verify final UI state | high; browser sessions may expose private accounts, DMs, notifications, and analytics | high in the canonical fixture because it is the automation-safe conservative rating; lower risk applies only to operator-only manual website use with no software assistance | high in the canonical fixture for safe audit tooling; a simple operator-only runbook may be lower effort outside the machine contract | Human session state stays outside the repo in a private browser/profile; no stored automation credentials | manual-only; automation not approved | platform-native scheduler may be used manually only when separately approved by the operator | Ledger update requires a fake/manual success receipt entered after the human action; do not mark published or queued from a draft alone. |
| Community plugin (`openclaw-plugin-social` / `zooclaw-social`) | low-medium; community maintenance and behavior are unverified | high; plugin may touch browser/session state or connector credentials | high; browser automation style publishing can conflict with platform terms | medium | Plugin connector credentials/session state in private runtime only | not-approved for automation; research-only | unknown/unverified | No ledger update unless wrapped by a future approved fake-first result contract; current failures or unapproved actions leave ledger unchanged. |
| Custom OpenClaw plugin | medium-high after review, test coverage, and provider approval | medium-high; connector boundary must isolate tokens and account IDs | medium; depends on using approved provider APIs and avoiding UI automation | high | Provider-specific OAuth tokens or API keys stored in private runtime/secret manager; public fixtures use placeholders only | design-candidate; requires separate implementation approval | provider-specific; Buffer schedule may be candidate, LinkedIn/X schedule unconfirmed | Plugin returns a normalized fake/provider result; ledger updates only after successful schedule/publish result and explicit action approval. |

## Browser-assisted publishing modes

The machine-readable fixture uses a single conservative browser-assisted rating: `tos_risk: high` and `implementation_effort: high`. That rating represents any software-assisted, audit-tooling, extension, or automation-adjacent workflow and keeps browser/community automation high-risk and not approved. A separate operator-only manual runbook may have lower effort and lower ToS risk when the human uses the website directly, but that mode is documentation-only and is not encoded as an approved automation connector.

## Proposal-first publication flow

Publishing must remain separate from planning and drafting:

1. **Draft proposal**: a planner may produce draft copy, target network, assets checklist, and a proposed timing window. This is not permission to schedule or publish.
2. **Schedule approval**: an operator may separately approve a scheduling action for a specific target, time, account/profile placeholder, and ledger entry. Schedule approval does not authorize immediate publish.
3. **Publish approval**: an operator must explicitly approve publishing for a specific target, account/profile placeholder, and ledger entry. Draft approval or schedule approval must not be reused as publish approval.
4. **Provider action result**: only a fake/sanitized success result in this slice can advance ledger state. Failed, blocked, unapproved, or unknown provider results leave the durable ledger state unchanged.

The approval gate must block publish intent before explicit publish approval, even if draft approval or schedule approval exists; draft approval or schedule approval must not be reused as publish approval.

## Credential storage and rotation requirements

- Store Buffer, LinkedIn, X, community plugin, and custom plugin credentials only in `.env`, a secret manager, or provider-specific private runtime state. Do not commit tokens, refresh tokens, client secrets, account IDs, profile IDs, browser session state, screenshots, or raw provider payloads.
- Buffer credentials may include OAuth access/refresh tokens or API keys. Rotate by revoking the Buffer app/token, issuing a new credential, rebinding approved profiles in private runtime, and re-running a fake-first validation before live use.
- LinkedIn and X credentials may include OAuth/user tokens, developer app secrets, organization/member references, or paid-tier access metadata. Rotate by revoking the provider app/session, regenerating tokens, rebinding accounts privately, and invalidating old runtime state.
- Browser-assisted manual publishing must not store browser session state in the repo. Rotate by signing out, revoking sessions, clearing private browser profiles when needed, and reauthorizing accounts privately.
- Community/custom plugin credentials inherit the strictest provider requirement. A leak requires revoke, rotate, rebind, audit review, and a private incident record before any future live use.

## Content ledger result contract

A connector result may propose one durable content-ledger transition only after an approved action completes successfully:

- Successful fake publish result: set ledger status to `published`, record a sanitized `published_at`, and attach a fake provider receipt reference such as `fake-provider://publish/...`.
- Successful fake schedule result: set ledger status to `queued`, record sanitized `scheduled_for`, and attach a fake provider receipt reference such as `fake-provider://schedule/...`.
- Failed, blocked, unapproved, or unknown result: keep the existing ledger status and do not set `published_at`, `scheduled_for`, or provider receipt fields.

Real provider IDs, account data, payloads, screenshots, and tokens are never valid ledger evidence in public repo artifacts.

## Non-goals

This slice does not implement live Buffer, LinkedIn, X, browser, community plugin, or custom plugin publishing. It does not perform OAuth, provider writes, browser automation, real scheduling, screenshot capture, account discovery, token handling, or API payload storage. Public docs and fixtures must remain fake, sanitized, and safe for repo review.
