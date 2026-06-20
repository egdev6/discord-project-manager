---
name: release-roadmap-hygiene
description: "Trigger: release hygiene, post-release issues, Kanban status, project column, merged to main. Keep GitHub issues and Project status aligned after merges and releases."
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
---

## Activation Contract

Use this skill when closing shipped issues, moving GitHub Project/Kanban items, finishing a PR merge, promoting a release branch to `main`, or cleaning up a milestone after release.

Do not use it for issue creation, PR authoring, or implementation planning unless project status must also be changed.

## Hard Rules

- Preserve release truth: project status must reflect where the work actually landed.
- PR merged to `develop` means `Merged to develop`, not `Done`.
- Release promoted to `main` means the release issue and every included shipped issue move to `Merged to main`.
- `Done` is only for non-merge administrative closure or work that intentionally has no branch/main promotion semantics.
- Deferred issues remain open, keep their blocker/status labels, and move to the next milestone instead of being marked merged.
- Never claim live/private Discord, Engram, production, or public readiness unless the issue evidence explicitly proves it.

## Decision Gates

| Situation | Action |
| --- | --- |
| PR merged into `develop` | Close linked issue if appropriate and set Project status to `Merged to develop`. |
| Release PR/promote to `main` completed | Set the release issue and included shipped issues to `Merged to main`. |
| Issue shipped only partially | Close only the shipped scope with an explicit no-overclaim comment, or keep open if acceptance remains central. |
| Issue deferred to next release | Move milestone, keep open/blocked, and comment the deferred gate. |
| Milestone still has open issues | Move/close each issue explicitly before closing the milestone. |

## Execution Steps

1. List milestone issues and Project statuses before making changes.
2. Identify shipped, deferred, and administrative issues separately.
3. Update Project status using exact columns: `Merged to develop`, `Merged to main`, or `Done` only when justified.
4. Add a concise comment when closing or deferring an issue, naming any no-overclaim boundary.
5. Close the milestone only after open issues are zero or explicitly moved out.
6. Verify the final issue list and Project status after edits.

## Output Contract

Return:

- Issues moved by number and final Project status.
- Issues closed, deferred, or left open.
- Milestone state after cleanup.
- Any no-overclaim caveats or remaining release risks.

## References

- `.atl/skill-registry.md` — generated skill index used by delegators.
