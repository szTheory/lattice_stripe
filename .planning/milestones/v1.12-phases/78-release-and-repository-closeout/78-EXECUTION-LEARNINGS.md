# Phase 78 Execution Learnings

## What caused the worktree detour

- GSD worktree dispatch was enabled and correct. A diagnostic without `--cwd-target` returned `exec: null`; supplying the target path resolved the expected `codex exec --cd ...` command. Check the dispatch command with the target before treating this as a configuration failure.
- The actual worktree creation and nested Codex startup hit sandbox restrictions around Git metadata and app-server initialization. Keep worktree mode enabled and use the narrow, approved execution path for those operations instead of changing repository workflow settings.
- GSD executor worktrees must be cleaned through their recorded manifests after merges. Confirm the final `git worktree list` contains only intended worktrees.

## Repository and release practices

- Do not accumulate a multi-phase milestone directly on local `main`. Start a named review branch from the agreed base, execute there, and open a review PR before considering release actions.
- Refresh `origin/main` and inspect ahead/behind counts before closeout. A large local-only commit range is a review and integration gate, even when local CI passes.
- Release publication requires the exact Release Please candidate PR and a passing current-head preflight. If that candidate is absent, record the blocker, keep the release unpublished, and resume when automation creates it.
- Preserve pre-existing dirty files. Record their paths and verify the review branch is based on committed `HEAD`; do not sweep unrelated edits into cleanup or a PR.
- Keep operational facts synchronized across phase state, roadmap, closeout evidence, and the candidate checker. Distinguish user edits from generated GSD run-state in dirty-worktree reports.
- Post external PR dispositions only after explicit user authorization, preserve the exact approved wording, and verify the resulting comment URL and PR state.

## Follow-up pattern

For future phases: inspect repository and worktree state first; establish an isolated review branch; validate executor dispatch with its target; execute and merge worktrees through GSD; run the planned verification; reconcile planning state; review the committed diff; push a review PR; then use the exact release candidate as the publication gate. Retain this checklist in phase closeout artifacts when the workflow changes or finds a new failure mode.
