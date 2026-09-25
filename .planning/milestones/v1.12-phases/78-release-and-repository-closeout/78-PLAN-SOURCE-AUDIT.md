# Phase 78 plan source audit

| Source | ID | Required outcome or constraint | Plan | Status |
|---|---|---|---|---|
| GOAL | — | Installable verified release; healthy main CI; triaged PRs; clean workspace | 01–06 | COVERED |
| REQ | REL-01 | SemVer and API-version contract proven, release cut | 02, 05, 06 | COVERED |
| REQ | REL-02 | Hex install plus matching GitHub Release and HexDocs | 01, 06 | COVERED |
| REQ | CLOSE-01 | Required CI green on the main release SHA | 01, 02, 06 | COVERED |
| REQ | CLOSE-02 | All open PRs reviewed with disposition | 03, 06 | COVERED |
| REQ | CLOSE-03 | Primary and linked worktrees clean | 04, 06 | COVERED |
| CONTEXT | D-01 | Expected 2.3.0, final additive diff, Release Please authority, unchanged default | 02, 06 | COVERED |
| CONTEXT | D-02 | One release SHA across CI/tag/release/Hex/checksum/docs/Hex-sourced adopter | 01, 06 | COVERED |
| CONTEXT | D-03 | Routine protected automation; recovery remains exact-SHA, versioned, idempotent | 01, 02, 06 | COVERED |
| CONTEXT | D-04 | No privileged merge bypass; least-privilege credentials | 02 | COVERED |
| CONTEXT | D-05 | Contributor-visible PR disposition plus dated ledger, green accepted changes | 03, 06 | COVERED |
| CONTEXT | D-06 | Read-only all-worktree inventory, ownership, release main synchronization | 04, 06 | COVERED |
| RESEARCH | R-01 | Existing Release Please and manual recovery reused | 01, 02, 06 | COVERED |
| RESEARCH | R-02 | Hex checksum representation proven against known version before assertion | 01 | COVERED |
| RESEARCH | R-03 | Isolated published-Hex mode in existing Phoenix host, no live credentials | 01 | COVERED |
| RESEARCH | R-04 | Normal protected merge with actionable blocker | 02 | COVERED |
| RESEARCH | R-05 | Complete PR inventory and linked ledger | 03 | COVERED |
| RESEARCH | R-06 | Porcelain worktree inventory including untracked and unknown-state blocker | 04 | COVERED |
| RESEARCH | R-07 | Current local main divergence and unrelated dirty changes are rechecked, preserved | 04, 05, 06 | COVERED |
| RESEARCH | R-08 | Release-only smoke avoids redundant recurring CI lane | 01 | COVERED |

## Specless edge-probe disposition

The fallback probe produced generic runtime-input labels for repository closeout. Each row below is retained and mapped to a concrete observable acceptance criterion where the label applies; the remaining semantic judgment is named explicitly.

| Candidate | Disposition |
|---|---|
| REL-01 / concurrency | 02 and 06: compare current Release Please PR head and required check again before protected merge; stale parallel updates block. |
| REL-02 / unclassified | 01: unknown registry/checksum/docs response blocks with named diagnostic; 03: genuinely ambiguous contribution fit remains a narrow human decision. |
| CLOSE-01 / adjacency | 01: distinguish a check on the immediately adjacent commit from the exact release SHA; only exact SHA passes. |
| CLOSE-01 / empty | 01: absent ci-gate, tag, release, or main relation blocks. |
| CLOSE-01 / ordering | 01 and 06: completed successful ci-gate on release SHA must precede package publication; latest run on the same SHA controls. |
| CLOSE-02 / adjacency | 03: adjacent PR numbers do not imply coverage; join ledger to exact PR number/URL. |
| CLOSE-02 / empty | 03: empty open-PR inventory is valid only after successful API enumeration; zero records is not a proxy for API failure. |
| CLOSE-02 / ordering | 03 and 06: re-inventory after dispositions and before final close; stale comments/checks do not pass. |
| CLOSE-02 / concurrency | 03: current head/check state is re-read before merge; newly opened PRs are included in final inventory. |
| CLOSE-03 / adjacency | 04: all linked worktree records are parsed, including adjacent records and whitespace-bearing paths. |
| CLOSE-03 / empty | 04: zero linked worktrees is valid if primary exists and is clean; empty/unparseable inventory blocks. |
| CLOSE-03 / ordering | 06: final cleanliness probe follows all closeout commits and origin/main refresh. |

The generic adjacent/equal-value prompts do not define runtime product behavior for this headless release phase. Their applicable failure modes are identity matching (SHA, PR number, path) and fresh ordering of checks, covered above. No generic input behavior is invented.

## Exclusions

- A GitHub App token migration is deferred by CONTEXT.md; no plan implements it.
- No schema, browser UI, Ecto data, live Stripe credentials, or extra package install is in scope.
- The API coverage detector returned `detected:false` on the ROADMAP Phase 78 section. The phase verifies GitHub/Hex release services through existing workflows and does not integrate a new external product API, so no API capability matrix is required.
