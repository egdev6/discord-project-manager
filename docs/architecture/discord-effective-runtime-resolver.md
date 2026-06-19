# Discord effective runtime resolver

This contract defines the reviewable output that OpenClaw should resolve for each Discord-originated turn before workflow execution: `effective_context`, `effective_skills`, and `effective_capabilities`.

The resolver exists to prevent routing drift. Skills, private profiles, context packs, and capability permissions must not be resolved independently by each workflow.

This is a fake-first contract only. It does not prove live Discord routing, live Engram reads/writes, prompt execution, filesystem access, browser automation, connector calls, publishing, scheduling, or production credentials.

## Quick path

1. Start with the resolved Discord origin and artifact classification.
2. Resolve allowed context by scope and route.
3. Resolve skills using the scoped skills registry.
4. Resolve capabilities separately from capability permission/config.
5. Emit provenance and exclusion reasons for every included or excluded item.
6. Require `discord-approval-gate` for write-like flows before any durable write.

## Resolver inputs

| Input | Purpose |
| --- | --- |
| `runtime_namespace` | `discord-project-manager/runtime/discord/<guild-id>/<channel-id>`. |
| `routing_status` and `resolved_route` | Matched project/network route or `none`. |
| `artifact_classification` | Artifact type, operation, persistence target, approval, backup, deployment, runner backend, and writeback policy. |
| `scope_layers` | Global/category/channel/thread layers available for this turn. |
| `private_profile_refs` | Approved private profile definitions referenced by bindings. |
| `capability_registry` | Capability availability, permission, and private config status. |

## Output schema

```yaml
effective_context:
  included:
    - ref: profile:writing.demo-linkedin-b2b
      scope: category:linkedin
      kind: private_profile_ref
      provenance: private-runtime/profile-binding
      reason: matched-route-category-binding
      content_policy: reference-only-no-private-content
  excluded:
    - ref: profile:writing.demo-linkedin-b2b
      scope: category:linkedin
      kind: private_profile_ref
      provenance: private-runtime/category-binding
      reason: overridden-by-channel-binding
      content_policy: reference-only-no-private-content

effective_skills:
  included:
    - skill_name: discord-approval-gate
      class: runtime-core
      provenance: mandatory-runtime-core
      reason: write-like-flow
  excluded:
    - skill_name: x-queue-planner
      class: scoped-workflow
      provenance: channel-disabled
      reason: explicit-channel-disable

effective_capabilities:
  included:
    - capability: engram
      available: true
      permitted: true
      config_state: configured-private
      provenance: capability-registry
      reason: private-runtime-write-target-after-approval
  excluded:
    - capability: filesystem
      available: true
      permitted: false
      config_state: private-config-required
      approval_required: true
      provenance: capability-registry
      reason: capability-present-but-not-enabled-for-scope
```

## Resolution order

Resolve in this order:

1. Runtime core safety requirements.
2. Global defaults.
3. Category bindings and category-local skills.
4. Channel bindings, preferences, disables, and overrides.
5. Thread/session summaries when explicitly modeled.
6. Private profile references and disabled profile bindings.
7. Capability availability and scoped permission/config.
8. Write-like safety additions such as `discord-approval-gate`.

Later layers may override earlier layers only when the override is explicit and reviewable. Disabled items stay excluded unless a reviewed override says otherwise.

## Context resolution

| Context source | Include when | Output rule |
| --- | --- | --- |
| Public repo docs/contracts | Relevant to the resolved route or runner boundary. | Include path/provenance, not copied large content. |
| Private profile definition | A binding references it for global/category/channel scope. | Include `ref` and summary metadata only; do not expose real profile content in repo fixtures. |
| Private profile binding | Binding applies to the current route/scope. | Include scope and reason. |
| Thread/session summary | Explicitly modeled and bounded. | Include summary ref, never raw chat logs. |
| Unmapped channel context | Route is not matched. | Exclude durable context; ask for clarification. |

## Skill resolution

Reuse `docs/architecture/discord-scoped-skills-registry.md` and `skills/scoped-skill-resolver/SKILL.md`.

Every skill item must include:

- skill name;
- class: `runtime-core`, `scoped-workflow`, or `preserved-protocol`;
- included/excluded state;
- source scope or registry layer;
- inclusion or exclusion reason;
- provenance.

For write-like flows, `discord-approval-gate` is mandatory even if a draft registry omits it.

## Capability resolution

Capability availability and permission are different decisions.

| Field | Meaning |
| --- | --- |
| `capability` | Capability family such as `filesystem`, `browser`, `buffer`, `engram`, `github`, `image_generation`, or `gentle_sdd`. |
| `available` | Runtime/plugin/integration exists in the environment or inventory. |
| `permitted` | Current scope may use it. |
| `config_state` | `not-required`, `private-config-required`, `configured-private`, or `missing-private-config`. |
| `approval_required` | Whether using or changing the capability requires exact approval. |
| `reason` | Why it is included, excluded, or blocked. |

External-service and local filesystem capabilities must never expose credentials, local sensitive paths, raw browser session state, or private connector config in repo fixtures.

## Example outcomes

| Scenario | Expected resolver outcome |
| --- | --- |
| Shared profile referenced by LinkedIn and X categories | Same `ref` appears for both scopes; no clone unless operation is `clone`. |
| Channel-specific profile override | Category profile remains visible as overridden/excluded; channel profile is included with override provenance. |
| Disabled skill | Skill appears under `excluded` with explicit disabled reason. |
| Capability present but not permitted | Capability appears as `available: true`, `permitted: false` with permission/config reason. |
| Write-like private context update | `discord-approval-gate` appears in effective skills and approval remains required. |

## Related docs

- `docs/architecture/openclaw-artifact-classification.md`
- `docs/architecture/discord-runtime-orchestrator.md`
- `docs/architecture/discord-scoped-skills-registry.md`
- `docs/architecture/discord-context-skill-packs.md`
- `docs/architecture/discord-memory-gateway.md`
- `docs/operations/private-runtime-backup-restore.md`
- `docs/security/data-handling.md`

## Validation checklist

- [ ] Fixture uses fake/demo markers only.
- [ ] Effective context includes provenance and reasons for included/excluded private profile refs.
- [ ] Effective skills include provenance and exclusion reasons.
- [ ] Effective capabilities distinguish availability from scoped permission/config.
- [ ] Shared profile references remain shared unless `operation: clone` is explicit.
- [ ] Write-like flows include `discord-approval-gate`.
- [ ] No raw Discord IDs, private profile content, local sensitive paths, tokens, raw logs, screenshots, or production claims are introduced.
