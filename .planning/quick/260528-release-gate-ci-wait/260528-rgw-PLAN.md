# Quick: release gate waits for ci-gate

**Objective:** Fix race where `gate-ci-green` failed before `ci.yml` started on the release merge SHA (required manual Hex recovery for 1.7.2).

**Approach:** Poll `ci.yml` for the tagged SHA (60 × 30s, rindle pattern); require `ci-gate` success before `publish-hex`.
