# Phase 58 — Pattern Map

**Mapped:** 2026-05-27  
**Phase:** Milestone Closure & Planning Truth  
**Requirements:** ROUTE-03, PLAN-01, PLAN-02, PROOF-01, SC #5

---

## Summary

Phase 58 is a **planning-truth and hygiene close** — no new API breadth, no Hex 1.8.0 bump, no stop-signal rewrite. Execution follows the **v1.7 close template** (Phase 55 / RETROSPECTIVE v1.7): append-only milestone history, audit before archive, immutable `*-MILESTONE-AUDIT.md` snapshots, surgical v1.N−1 audit footnotes when later milestones resolve tech debt.

**Ordered waves (D-30):**

| Wave | Plan | Primary deliverables |
|------|------|---------------------|
| 1 | 58-01 | `.planning/JTBD-MAP.md` full refresh |
| 2 | 58-02 | `.planning/MILESTONES.md`, `.planning/RETROSPECTIVE.md` |
| 3 | 58-03 | Tax proof files + CI step (atomic commit) |
| 4 | 58-04 | `milestones/v1.8-MILESTONE-AUDIT.md`, `58-VERIFICATION.md` |
| 5 | 58-05 | Archive + PROJECT/STATE/ROADMAP posture flip |

---

## Plan 58-01 — JTBD-MAP Refresh (ROUTE-03)

| File | Role | Closest Analog | Pattern to Replicate |
|------|------|----------------|----------------------|
| `.planning/JTBD-MAP.md` | Internal capability map / priority queue | Self (post-v1.7 state) + Phase 56/57 shipped evidence | Full Gap 1 collapse → Resolved gaps; matrix row upgrades; maintenance-first priority order |

### Analog: Coverage matrix row (stale → target)

**Current (stale — L87, L105–107):**

```markdown
| One-time payments | Core | Strong | Partial | Shipped; **payments.md has API example bugs** (status atoms, search arity) — fix in v1.8 |
| Charge audit and reconciliation | Important for support/ops | Strong | Partial | Shipped (v1.7); list/search/update/capture in code; payments guide routing gap |
| Production operator guides | Foundational for prod readiness | Strong | Good | Shipped (v1.7): production-checklist + event-debugging; Charge update/capture not in operator route |
| Public package/docs/version truth | Foundational | Strong | Partial | Hex 1.7.0 + lockstep `~> 1.7` on seven install surfaces; getting-started prose drift (lines 20–21) |
```

**Target (post-v1.8):**

```markdown
| One-time payments | Core | Strong | Strong | Shipped; payments.md examples fixed (Phase 57) + docs_truth locked |
| Charge audit and reconciliation | Important for support/ops | Strong | Good/Strong | Shipped; `#charge-reconciliation` in payments.md + operator cross-links (Phase 57) |
| Production operator guides | Foundational for prod readiness | Strong | Good/Strong | Shipped; update/capture routed in production-checklist + event-debugging (Phase 57) |
| Public package/docs/version truth | Foundational | Strong | Strong | Hex 1.7.0 + lockstep `~> 1.7`; getting-started prose SSOT locked (Phase 56) |
```

### Analog: Resolved gaps block (v1.7 pattern — L141–149)

**Extend with v1.8 items:**

```markdown
### Resolved gaps (do not re-prioritize)

- ~~End-to-end flagship recipes~~ — four guides shipped (v1.4)
- ~~Thin-event webhook support~~ — shipped (v1.5)
- ~~Tax resource family~~ — shipped (v1.6)
- ~~Charge list/search/update/capture~~ — shipped (v1.7)
- ~~Production operator guides~~ — production-checklist + event-debugging shipped (v1.7)
- ~~Public release truth / Hex publish~~ — 1.7.0 on Hex, lockstep `~> 1.7` install contract (v1.7)
- ~~v1.x stop signal~~ — README, scope.md, planning artifacts (v1.7)
- ~~getting-started release-status prose drift~~ — fixed Phase 56 (TRUTH-01/02)
- ~~payments.md API example bugs~~ — atom statuses, search/3 fixed Phase 57 (GUIDE-01..03)
- ~~Charge reconciliation discovery gap~~ — `payments.md#charge-reconciliation` Phase 57 (ROUTE-01)
- ~~operator guide update/capture routing~~ — Phase 57 (ROUTE-02)
- ~~cosmetic planning drift~~ — MILESTONES/RETROSPECTIVE/JTBD refresh Phase 58 (PLAN-01/02, ROUTE-03)
```

### Analog: Gap 1 collapse (D-04)

**Replace entire Gap 1 block (L126–135) with:**

```markdown
Doc-routing polish closed in v1.8 (Phases 56–58).
```

### Analog: Recommended Priority Order (D-05)

**Replace v1.8-as-#1 with maintenance-first:**

```markdown
## Recommended Priority Order

Post-v1.8 close (2026-05-27):

1. **Maintenance mode** — Stripe API drift, adopter-pull narrow adds (TAX-01/02), bugfixes
2. **Gap 2: Narrative docs still thin** — Product/Price, BillingPortal, disputes/files, mandate diagnostics (adopter pull only)
3. **Specialist breadth families** — Identity, Financial Connections, Terminal, Issuing, Treasury only if real adopter pull appears
4. **Deferred Tax narrow reqs** — TAX-01 (tax_codes), TAX-02 (transaction list) — adopter pull only
5. **Long-tail narrative docs** — opportunistic, not milestone-grade
```

### Analog: Maintenance Notes bullet (D-06)

**Append to L204–212 section:**

```markdown
- Refresh this file at **milestone close** (not only milestone start); verify against `CHANGELOG.md`, `docs_truth_test.exs`, and shipped guides.
```

### Cross-check SSOT (must align with shipped code)

Adopter truth lives in `docs_truth_test.exs` — planning must not contradict:

```elixir
describe "guides/getting-started.md" do
  test "release-status prose matches current Hex surface" do
    getting_started = File.read!("guides/getting-started.md")
    release_line = current_release_line()
    assert getting_started =~ release_line
    for claim <- @stale_release_status_claims do
      refute getting_started =~ claim
    end
  end
end

describe "guides/payments.md" do
  test "routes Charge reconciliation after PaymentIntent flows" do
    payments = File.read!("guides/payments.md")
    assert payments =~ "## Charge reconciliation"
    assert payments =~ "LatticeStripe.Charge.list"
    # ...
  end
end
```

**ROUTE-03 grep gates:**

```bash
rg -n "payments\.md has API example bugs|getting-started prose drift|routing gap|Gap 1: Doc-routing" .planning/JTBD-MAP.md
# → no matches

rg -n "maintenance mode|Doc-routing polish closed in v1.8" .planning/JTBD-MAP.md
# → matches
```

---

## Plan 58-02 — Planning Cosmetics (PLAN-01, PLAN-02)

| File | Role | Closest Analog | Pattern to Replicate |
|------|------|----------------|----------------------|
| `.planning/MILESTONES.md` | Shipped milestone history (append-only) | v1.7 section (L3–23) + v1.6 forward-resolution footnote (L43) | Append v1.8 at top; surgical v1.7 audit line only |
| `.planning/RETROSPECTIVE.md` | Process lessons feed-forward | v1.7 section (L5–43) | Append v1.8 above v1.7; preserve v1.7 "partial close" bullet verbatim |

### Analog: v1.7 MILESTONES section shape (mirror for v1.8)

```markdown
## v1.7 Polish & Operator (Shipped: 2026-05-27)

**Phases completed:** 4 phases (52–55), 17 plans

**Stop signal:** As of **1.7.0** on Hex.pm, LatticeStripe is **feature-complete for its intended v1.x scope** ...

**Key accomplishments:**
- Expanded `LatticeStripe.Charge` from retrieve-only to list/search/update/capture parity ...
- Shipped operator playbooks ...
- Reconciled release truth ...
- Published `lattice_stripe` **1.7.0** to Hex.pm ...
- Retired Phase `41.1` as `accepted-external-verification` ...

**Audit:** PASSED — ...
**Known deferred items at close:** 1 (260402-wte ...)
**Git range:** `5baf5c6` → `ff8dd13`
```

### Target: v1.8 section (insert above v1.7 — D-08, D-13)

```markdown
## v1.8 Adopter Truth & Doc Routing Polish (Shipped: 2026-05-27)

**Phases completed:** 3 phases (56–58), TBD plans

**Key accomplishments:**
- getting-started release-status prose + docs_truth prose SSOT locks (TRUTH-01/02, Phase 56)
- payments.md atom status, stream filter, search/3 fixes + VERIFY-04 locks (GUIDE-01..03, Phase 57)
- PI-first Charge reconciliation section in payments.md (ROUTE-01, Phase 57)
- operator guide update/capture routing spines (ROUTE-02, Phase 57)
- planning truth close — JTBD-MAP refresh, MILESTONES/RETROSPECTIVE, tax proof commit (ROUTE-03, PLAN-01/02, PROOF-01, Phase 58)

**Audit:** PASSED — see [v1.8-MILESTONE-AUDIT.md](milestones/v1.8-MILESTONE-AUDIT.md)
**Known deferred at close:** CI-01 paths-ignore (guide-only PRs skip docs_truth)

**Git range:** `ff8dd13` → `{close_sha}` (fill at close)
**Timeline:** 2026-05-27 (single-day milestone)
```

### Analog: v1.6 forward-resolution footnote (L43)

```markdown
**Outstanding follow-through (resolved at v1.7 close):** Phase 41.1 retired as `accepted-external-verification` in Phase 55. Hex publish at `1.7.0` shipped in v1.7 (REL-04).
```

**Apply to v1.7 audit line (surgical edit only — D-09):**

```markdown
**Audit:** PASSED — 13/13 requirements, 0 critical gaps, 4/5 E2E flows. **Tech debt at close:** missing `54-VERIFICATION.md`; doc-routing gaps (getting-started prose, payments/operator Charge routing). **Resolved in v1.8** (Phases 56–57). See [v1.7-MILESTONE-AUDIT.md](milestones/v1.7-MILESTONE-AUDIT.md).
```

**Do not edit** `milestones/v1.7-MILESTONE-AUDIT.md` (D-10) — immutable snapshot.

### Analog: RETROSPECTIVE v1.7 structure (mirror for v1.8 — D-11)

```markdown
## Milestone: v1.7 — Polish & Operator

**Shipped:** 2026-05-27
**Phases:** 4 (52–55) | **Plans:** 17

### What Was Built
...

### What Worked
- **Four-phase vertical slice with honest stop signal.** ...
- **Hex publish as stop-milestone capstone.** ...
- **Phase 55 gap-closure plans.** ...

### What Was Inefficient
- **Partial close artifacts before REL-04 landed.** ...  ← PRESERVE verbatim (D-12)
- **Phase 54 missing VERIFICATION.md.** ...

### Key Lessons
3. **Audit before complete-milestone.** Running `/gsd-audit-milestone` first surfaced doc-routing tech debt without blocking close.
```

**Target v1.8 append (insert above v1.7):**

```markdown
## Milestone: v1.8 — Adopter Truth & Doc Routing Polish

**Shipped:** 2026-05-27
**Phases:** 3 (56–58) | **Plans:** TBD

### What Was Built
- getting-started 1.7.x release-status blockquote + docs_truth SSOT prose locks (Phase 56)
- payments.md copy-paste fixes + Charge reconciliation section + operator routing (Phase 57)
- JTBD-MAP full post-v1.8 refresh; MILESTONES/RETROSPECTIVE cosmetics; tax proof commit (Phase 58)

### What Worked
- **describe-per-guide docs_truth pattern** — Phase 56 getting-started describe → Phase 57 payments + operator describes
- **JTBD refresh at milestone close** — prevents v1.7-style stale map driving redundant milestones
- **Post-stop milestone = doc polish only** — no new modules; highest leverage after v1.x stop signal

### What Was Inefficient
- **Untracked proof files discovered at assessment** — adoption_contract + tax_id_integration existed locally while CI referenced adoption gate
- **JTBD-MAP lagged two phases** — Gap 1 block contradicted shipped guides through Phase 57

### Key Lessons
1. Planning maps must refresh at **close**, not only milestone start
2. CI steps must reference **tracked** files — adoption contract on fresh clone breaks without PROOF-01
3. Doc-only post-stop milestones still need audit-before-archive (v1.7 pattern)
```

**Also:** add v1.8 row to Cross-Milestone Trends table (RETROSPECTIVE L196+).

**Two-pass MILESTONES edit (D-30):** draft v1.8 + v1.7 footnote in wave 2; finalize audit verdict + git range after audit in wave 5.

---

## Plan 58-03 — Tax Proof Commit (PROOF-01)

| File | Role | Closest Analog | Pattern to Replicate |
|------|------|----------------|----------------------|
| `test/integration/tax_id_integration_test.exs` | stripe-mock integration proof | `test/integration/charge_integration_test.exs` | `@moduletag :integration` + TCP probe + CRUD smokes |
| `test/lattice_stripe/tax/adoption_contract_test.exs` | UAT checklist gate (CI 1.19/OTP 28) | `test/lattice_stripe/docs_truth_test.exs` Tax blocks + v1.6 audit claims | describe-per-UAT grep + fixture round-trip |
| `.github/workflows/ci.yml` | CI honesty gate | Existing test job steps | Matrix-scoped adoption contract step |

### Analog: charge_integration_test.exs (integration pyramid)

```elixir
defmodule LatticeStripe.ChargeIntegrationTest do
  use ExUnit.Case, async: false
  @moduletag :integration

  setup_all do
    case :gen_tcp.connect(~c"localhost", 12_111, [], 1000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        start_supervised!({Finch, name: LatticeStripe.IntegrationFinch})
        :ok
      {:error, _} ->
        raise "stripe-mock not running on localhost:12111 — start with: docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest"
    end
  end

  setup do
    {:ok, client: test_integration_client()}
  end
  # retrieve/list/search/update/capture smokes ...
end
```

**tax_id_integration_test.exs follows exactly** — dual URL families (top-level + customer-nested CRUD round-trip):

```elixir
defmodule LatticeStripe.Integration.TaxIdTest do
  use ExUnit.Case, async: false
  @moduletag :integration

  describe "top-level TaxId CRUD round-trip" do
    test "create → retrieve → list → delete on /v1/tax_ids", %{client: client} do
      # ...
    end
  end

  describe "customer-nested TaxId CRUD round-trip" do
    test "create → retrieve → list → delete on /v1/customers/:id/tax_ids", %{client: client} do
      # ...
    end
  end
end
```

Picked up by integration job: `mix test --include integration` (38 files with `@moduletag :integration`).

### Analog: adoption contract (UAT-mapped describes)

```elixir
defmodule LatticeStripe.Tax.AdoptionContractTest do
  @moduledoc """
  Phase 51 adoption contract — automated replacement for manual UAT.
  ...
  CI gate:
    mix test test/lattice_stripe/tax/adoption_contract_test.exs --warnings-as-errors
  """
  use ExUnit.Case, async: true

  describe "UAT-4: Testing fixtures produce typed structs" do
    test "guides/testing.md documents Tax fixture workflow" do
      testing = File.read!("guides/testing.md")
      assert testing =~ "## Tax"
      assert testing =~ "tax_calculation_json"
    end
  end

  describe "UAT-6: Tax moduledoc guide links" do
    test "all five Tax modules link guides/tax.md with no Phase 51 placeholders" do
      for path <- @tax_sources do
        source = File.read!(path)
        refute source =~ "Phase 51", "placeholder still present in #{path}"
      end
    end
  end
end
```

**Follow-up in same commit (D-19):** update `@moduledoc` L5 — reference `milestones/v1.6-MILESTONE-AUDIT.md` instead of missing `.planning/phases/51-taxid-testing-adoption-surface/51-UAT.md`.

### Analog: CI adoption step (already in working tree)

```yaml
      - name: Tax adoption contract (Phase 51 UAT gate)
        if: matrix.elixir == '1.19' && matrix.otp == '28'
        run: mix test test/lattice_stripe/tax/adoption_contract_test.exs --warnings-as-errors
```

**Atomic commit (D-15–D-21):** all three paths in one commit:

```bash
git add test/lattice_stripe/tax/adoption_contract_test.exs \
        test/integration/tax_id_integration_test.exs \
        .github/workflows/ci.yml
# message: test(tax): commit Phase 51 proof tests wired by CI and milestone audit
```

**Authority:** v1.6-MILESTONE-AUDIT.md claims adoption contract + stripe-mock TaxId proof.

---

## Plan 58-04 — Milestone Audit (SC #5)

| File | Role | Closest Analog | Pattern to Replicate |
|------|------|----------------|----------------------|
| `.planning/milestones/v1.8-MILESTONE-AUDIT.md` | Immutable close-time verdict | `milestones/v1.7-MILESTONE-AUDIT.md` | YAML frontmatter + requirements table + tech_debt list |
| `.planning/phases/58-*/58-VERIFICATION.md` | Phase evidence artifact | `56-VERIFICATION.md`, `57-VERIFICATION.md` | Frontmatter score + grep/test commands |

### Analog: v1.7-MILESTONE-AUDIT.md frontmatter

```yaml
---
milestone: v1.7
milestone_name: Polish & Operator
audited: 2026-05-27T21:30:00Z
status: passed
scores:
  requirements: 13/13
  phases: 3/4
  integration: 16/18
  flows: 4/5
gaps: []
tech_debt:
  - phase: 54-release-truth-capstone
    items:
      - "Missing 54-VERIFICATION.md ..."
      - "guides/getting-started.md lines 20–21 still claim 1.3.x ..."
nyquist:
  compliant_phases: ["53-operator-guides", "54-release-truth-capstone"]
  partial_phases: ["52-charge-surface-expansion", "55-milestone-closure-v1-x-stop-signal"]
  overall: partial
---
```

**v1.8 expected:** 12/12 requirements, 3/3 phases, passed-with-tech-debt (CI-01 paths-ignore, checkout.md deferred, 54-VERIFICATION still missing).

### Analog: Phase VERIFICATION frontmatter (56/57)

```yaml
---
phase: 56-release-truth-getting-started
status: passed
verified: 2026-05-27
score: 8/8
requirements:
  TRUTH-01: satisfied
  TRUTH-02: satisfied
---
```

**58-VERIFICATION.md must exist before audit** — Phase 58 cannot be "unverified phase" in milestone aggregation.

**Audit command:** `/gsd-audit-milestone v1.8` (mandatory step 1 before archive — v1.7 lesson RETROSPECTIVE L37).

---

## Plan 58-05 — Archive & Posture Flip (SC #5)

| File | Role | Closest Analog | Pattern to Replicate |
|------|------|----------------|----------------------|
| `.planning/ROADMAP.md` | Active phase tracker | Post-v1.7 close state (L12–13) | v1.8 ✅; no active milestone; maintenance only |
| `.planning/REQUIREMENTS.md` | Active req tracker | Archive to `milestones/v1.7-REQUIREMENTS.md` | Flip ROUTE-03/PLAN-01/02/PROOF-01 → `[x]`; archive |
| `.planning/PROJECT.md` | Project SSOT | v1.7 maintenance posture (L49–53) | Latest shipped = v1.8; replace "Current Milestone: v1.8" with maintenance mode |
| `.planning/STATE.md` | GSD execution state | Pre-v1.8 maintenance (if any) | `status: maintenance`; `completed_phases: 3/3`; clear stale todos |
| `.planning/milestones/v1.8-ROADMAP.md` | Archived roadmap | `milestones/v1.7-ROADMAP.md` | Move current ROADMAP at close |
| `.planning/milestones/v1.8-REQUIREMENTS.md` | Archived requirements | `milestones/v1.7-REQUIREMENTS.md` | Archive header + all 12 `[x]` |
| `.planning/milestones/v1.8-phases/` (optional) | Phase artifact archive | `milestones/v1.5-phases/` (36 files) | Move phases 56–58 if low friction |

### Analog: ROADMAP milestone list entry (target flip)

**Current:**

```markdown
- 🚧 **v1.8 — Adopter Truth & Doc Routing Polish** — Phases 56-58 (in progress)
```

**Target:**

```markdown
- ✅ **v1.8 — Adopter Truth & Doc Routing Polish** — Phases 56-58 (shipped 2026-05-27) — [archive](milestones/v1.8-ROADMAP.md)
```

No active milestone line; next work = maintenance / adopter-pull only.

### Analog: REQUIREMENTS archive header (v1.7)

```markdown
# Requirements Archive: v1.7 Polish & Operator

**Archived:** 2026-05-27
**Status:** SHIPPED

For current requirements, see `.planning/REQUIREMENTS.md`.
```

**At close:** flip pending rows then archive:

```markdown
- [ ] **ROUTE-03**: `.planning/JTBD-MAP.md` charge-reconciliation route reflects post-v1.8 doc routing
- [ ] **PLAN-01**: `.planning/MILESTONES.md` v1.7 section prose reflects published 1.7.0 state
- [ ] **PLAN-02**: `.planning/RETROSPECTIVE.md` historical bullets accurate post-1.7.0 Hex publish
- [ ] **PROOF-01**: Untracked tax proof files committed or dropped with rationale
```

### Analog: PROJECT.md maintenance posture (D-27)

**Replace "Current Milestone: v1.8" section with:**

```markdown
## Maintenance Mode (post–v1.8)

**Latest shipped milestone:** v1.8 Adopter Truth & Doc Routing Polish (archived 2026-05-27)

**Forward posture:** Maintenance mode — Stripe API drift, adopter-driven narrow additions, bugfixes. No planned new resource-family breadth absent fresh adopter pull.

**Do not rewrite:** v1.x stop signal (already at Hex 1.7.0); no Hex 1.8.0 bump (doc-only milestone).
```

Move Active v1.8 reqs → Validated with phase references.

### Analog: STATE.md posture flip (D-28)

**Current (stale):**

```yaml
milestone: v1.8
status: executing
progress:
  completed_phases: 2
```

**Target:**

```yaml
milestone: v1.8
status: maintenance
progress:
  total_phases: 3
  completed_phases: 3
  percent: 100
```

Clear stale todos (`/gsd-plan-phase 56`, executing v1.8 drift).

### Analog: v1.5-phases archive (optional D-25)

```
.planning/milestones/v1.5-phases/
  47-thin-event-sdk-surface-webhook-reconciliation/
  48-thin-event-adoption-surface-guide-integration-verification/
```

Move `.planning/phases/56-*`, `57-*`, `58-*` → `milestones/v1.8-phases/` if low friction.

**Archive command:** `/gsd-complete-milestone v1.8`

---

## Cross-Cutting Patterns

### Append-only milestone history

- **MILESTONES:** new section at top; never rewrite prior accomplishments
- **RETROSPECTIVE:** append new milestone; preserve process archaeology (v1.7 "partial close" bullet)
- **\*-MILESTONE-AUDIT.md:** immutable; forward-resolution via MILESTONES audit footnote only

### Audit-before-close sequence (v1.7 → v1.8)

```
1. Ship doc/planning work (58-01..03)
2. /gsd-audit-milestone v1.8 → write v1.8-MILESTONE-AUDIT.md
3. Finalize MILESTONES audit line + git range
4. /gsd-complete-milestone v1.8 → archive + posture flip
```

### Mox + stripe-mock test pyramid (PROOF-01)

| Layer | TaxId analog | File |
|-------|-------------|------|
| Mox unit | `tax_id_test.exs` | wire-path CRUDL |
| Adoption contract | `adoption_contract_test.exs` | UAT-1..8 checklist + guide/fixture greps |
| stripe-mock integration | `tax_id_integration_test.exs` | dual URL family CRUD |
| docs_truth | `docs_truth_test.exs` | Tax guide/moduledoc locks (overlap OK — adoption contract adds UAT-4/6 + explicit gate) |

### Explicitly skip (D-29)

- Hex 1.8.0 bump
- README / `guides/scope.md` stop-signal rewrite
- New milestone kickoff
- Editing `milestones/v1.7-MILESTONE-AUDIT.md`

---

## Verification Command Summary

| REQ / SC | Command | Pass condition |
|----------|---------|----------------|
| ROUTE-03 | `rg` stale gap patterns in JTBD-MAP | no matches |
| ROUTE-03 | `rg "maintenance mode\|Doc-routing polish closed in v1.8" JTBD-MAP` | matches |
| PLAN-01 | `rg "Resolved in v1.8" MILESTONES.md` | match |
| PLAN-01 | `rg "## v1.8 Adopter Truth" MILESTONES.md` | match |
| PLAN-02 | `rg "## Milestone: v1.8" RETROSPECTIVE.md` | match |
| PLAN-02 | `rg "Partial close artifacts before REL-04" RETROSPECTIVE.md` | v1.7 preserved |
| PROOF-01 | `git ls-files` three paths | all tracked |
| PROOF-01 | `mix test .../adoption_contract_test.exs --warnings-as-errors` | 8/0 |
| PROOF-01 | `mix test .../tax_id_integration_test.exs --include integration` | 2/0 |
| SC #5 | `test -f milestones/v1.8-MILESTONE-AUDIT.md` | exists |
| SC #5 | `rg "status: maintenance" STATE.md` | match |
| SC #5 | archive files exist | v1.8-ROADMAP + v1.8-REQUIREMENTS |
| Adopter SSOT | `mix test docs_truth_test.exs --warnings-as-errors` | 24/0 |

---

## PATTERN MAPPING COMPLETE
