---
status: complete
quick_id: 260528-rgw
date: 2026-05-28
---

# Quick 260528-rgw: release gate CI wait

## Done

- `release.yml` `gate-ci-green` polls up to ~30 min for `ci.yml` + `ci-gate` success on the release SHA.
- `docs/maintainer-release.md` notes automatic wait before Hex publish.

## Verification

YAML valid; logic ported from rindle `release.yml` Wait for CI step, narrowed to `ci-gate` job conclusion.
