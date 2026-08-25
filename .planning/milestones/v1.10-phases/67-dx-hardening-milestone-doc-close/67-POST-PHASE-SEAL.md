# Phase 67 Post-Phase-Seal Orchestration

This planning-time artifact is consumed by the root auto-advance orchestrator after `$gsd-execute-phase 67 --auto --no-transition` returns `PHASE COMPLETE`. It is not an execute-plan task and is not an input to the Phase 67 verifier.

## Strict precondition

Stop unless `.planning/phases/67-dx-hardening-milestone-doc-close/67-VERIFICATION.md` exists, is non-empty, identifies Phase 67, and has frontmatter `status: passed`. The normal milestone audit treats a missing or non-passing phase verification as a blocker, so no interim or `gaps_found` audit is useful or permitted for D-17.

Verify the precondition from `/Users/jon/projects/lattice_stripe`:

`test -s .planning/phases/67-dx-hardening-milestone-doc-close/67-VERIFICATION.md && rg -q '^phase: 67(-dx-hardening-milestone-doc-close)?$' .planning/phases/67-dx-hardening-milestone-doc-close/67-VERIFICATION.md && rg -q '^status: passed$' .planning/phases/67-dx-hardening-milestone-doc-close/67-VERIFICATION.md`

## D-17 supported orchestration

1. In the primary repository, verify the historical audit before any workspace operation:
   `printf '%s  %s\n' '96d0ee3584c074566aaf3f3c516d005bb227e4916268b00cecf0073ba09d2726' '.planning/v1.10-MILESTONE-AUDIT.md' | shasum -a 256 -c -`
2. Capture `git rev-parse HEAD` as the post-Phase-67 SHA. Require the passing `67-VERIFICATION.md` to exist at that committed SHA with `git cat-file -e <post-phase-67-sha>:.planning/phases/67-dx-hardening-milestone-doc-close/67-VERIFICATION.md` and require its committed frontmatter to contain `status: passed`.
3. Invoke the supported creator from the primary repository exactly as `$gsd-workspace --new --name lattice-stripe-phase67-audit --repos /Users/jon/projects/lattice_stripe --path /Users/jon/gsd-workspaces/lattice-stripe-phase67-audit --strategy worktree --branch workspace/lattice-stripe-phase67-audit --auto`.
4. Enter `/Users/jon/gsd-workspaces/lattice-stripe-phase67-audit/lattice_stripe`, run `git switch --detach <post-phase-67-sha>`, require `git rev-parse HEAD` to equal the captured SHA, and require `git symbolic-ref -q HEAD` to fail. Require `.planning/v1.10-MILESTONE-AUDIT.md` to be absent before the audit; the primary historical untracked artifact must not be copied into the worktree.
5. From that detached member-repository working directory, invoke the normal supported `$gsd-audit-milestone v1.10`. Do not supply an output override. It must write its standard `.planning/v1.10-MILESTONE-AUDIT.md` path.
6. Require the isolated report to be non-empty with milestone `v1.10`, `audited` UTC date equal to the current UTC date, `status: passed` or `status: tech_debt`, and a Phase 67 evidence marker (`Phase 67`, `67-dx-hardening`, `DX-02`, `DX-03`, or `DOC-02`). A `gaps_found` result blocks the chain and is not transferred as D-17 closure evidence.
7. Transfer that exact isolated report to the distinct primary path `/Users/jon/projects/lattice_stripe/.planning/v1.10-POST-PHASE-67-MILESTONE-AUDIT.md`. Require source and destination SHA-256 values to match, require the destination to contain the same freshness/status/Phase-67 evidence, and require the destination path to differ from `.planning/v1.10-MILESTONE-AUDIT.md`.
8. Re-run the fixed historical SHA-256 check in the primary repository. This is the D-17 proof that historical pre-Phase-67 evidence was not rewritten.
9. In the isolated member repository, require `git status --porcelain=v1 --untracked-files=all` to contain exactly `?? .planning/v1.10-MILESTONE-AUDIT.md`. If any other path is dirty, stop and preserve the workspace for diagnosis.
10. Remove only `/Users/jon/gsd-workspaces/lattice-stripe-phase67-audit/lattice_stripe/.planning/v1.10-MILESTONE-AUDIT.md`, then require the isolated member repository to be clean.
11. Return to `/Users/jon/projects/lattice_stripe`, invoke `$gsd-workspace --remove lattice-stripe-phase67-audit`, and provide the exact workspace name at its required confirmation. Do not use manual recursive deletion. Require `/Users/jon/gsd-workspaces/lattice-stripe-phase67-audit` to be absent after the supported removal reports success.

## Blocking success criteria

D-17 is complete only when all of these machine-verifiable facts hold after the Phase 67 seal:

- `.planning/phases/67-dx-hardening-milestone-doc-close/67-VERIFICATION.md` exists at the audited commit with `status: passed`.
- `.planning/v1.10-POST-PHASE-67-MILESTONE-AUDIT.md` is non-empty, current-date, identifies v1.10 and Phase 67 evidence, and has status `passed` or `tech_debt`.
- The transferred report SHA-256 equals the isolated standard report SHA-256.
- `.planning/v1.10-MILESTONE-AUDIT.md` still has SHA-256 `96d0ee3584c074566aaf3f3c516d005bb227e4916268b00cecf0073ba09d2726`.
- The isolated repository was clean after removal of exactly its generated standard report, and the supported workspace removal removed the named workspace.

If any criterion fails, stop auto-advance and report the exact failed check. Do not reinterpret the failure as phase verification success and do not run an interim audit.
