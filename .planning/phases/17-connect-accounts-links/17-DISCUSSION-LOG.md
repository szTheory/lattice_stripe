# Phase 17: Connect Accounts & Account Links - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `17-CONTEXT.md` — this log preserves the alternatives considered and the research rationale.

**Date:** 2026-04-12
**Phase:** 17-connect-accounts-links
**Mode:** Research-synthesis (4 parallel `gsd-advisor-researcher` agents, one per gray area)
**Areas discussed:** A — Nested struct budget, B — Capabilities shape, C — Phase 17/18 scope boundary, D — Atom guards & helpers

---

## Process note

This phase was entered via `/gsd-discuss-phase 17` but Phase 17 had no entry in `ROADMAP.md` when discussion began. The discussion started by (1) surfacing the missing roadmap entry, (2) confirming `STATE.md` was stale (PR #4 had merged with all Billing phases 14+15+16 but state still said "awaiting merge"), (3) refreshing STATE.md and adding Phase 17/18/19 entries to ROADMAP.md, then (4) running the 4-agent research synthesis against the newly-defined Phase 17 scope.

User explicitly requested a one-shot synthesized recommendation rather than area-by-area interactive Q&A. All 4 research agents ran in parallel with full project context (Phases 14/15/16 locked decisions, F-001 pattern, "no fake ergonomics" principle, flat namespace rule, budget rule).

---

## Area A — Nested typed struct budget on `%Account{}`

### Gray area framing
Stripe's `%Account{}` has 8 candidate fields for promotion to typed nested structs: `business_profile`, `capabilities`, `requirements`, `future_requirements`, `settings`, `tos_acceptance`, `company`, `individual`. Phase 16 D1 locked a 5-field budget. Need to decide which win the budget, whether `requirements`/`future_requirements` reuse one struct, whether `company`/`individual` unify, and how deep to go on `settings`.

### Options considered

| Option | Summary | Verdict |
|--------|---------|---------|
| A. Strict 5-budget: business_profile, requirements, tos_acceptance, company, individual | Honors D1 literally; drops settings and future_requirements. | Not recommended — loses real use sites (settings.payouts, future_requirements consistency) |
| B. Amend to 6 with outer-only Settings | Adds Settings as outer struct, sub-objects stay as plain maps via `:extra`. | **✓ Selected** |
| C. Full nest all 8 + cascade Settings sub-objects (~12 modules) | Maximum type fidelity, mirrors stripe-node. | Rejected — blows budget 2.4x, contradicts D1 philosophy, maintenance drag |
| D. Conservative 4: drop tos_acceptance and settings | Smallest surface. | Rejected — under-shoots budget with no upside |

### Sub-decisions

| Question | Resolution | Reason |
|----------|------------|--------|
| Reuse one struct for `requirements` + `future_requirements`? | **Yes** | Stripe API docs confirm identical shape; Phase 15 D4 "reuse over duplicate" + Phase 16 Phase↔default_settings precedent |
| Unify `company` + `individual` into `Account.Party`? | **No** | Mutual exclusion is load-bearing; divergent fields (dob/ssn_last_4 vs structure/directors_provided) are identity, not incidental; stripity_stripe also keeps them separate |
| Promote `settings` fully or outer-only? | **Outer-only** | Cascading adds 5 more modules and blows budget; `:extra` map handles forward-compat cleanly |
| Amend the 5-field budget rule? | **Yes — count distinct modules, not parent fields** | Ratifies what Phase 16 already did (Phase struct reused); cleaner rule going forward |

### Final promoted field set (locked in D-01)

1. `business_profile` → `Account.BusinessProfile`
2. `requirements` + `future_requirements` → `Account.Requirements` (reused at two sites)
3. `tos_acceptance` → `Account.TosAcceptance` (PII-safe Inspect)
4. `company` → `Account.Company` (PII-safe Inspect)
5. `individual` → `Account.Individual` (PII-safe Inspect)
6. `settings` → `Account.Settings` (outer-only)

**Research sources:** Stripe Account API Reference, stripe-node, stripity_stripe source, stripe-node CHANGELOG (business_profile evolution), Stripe Docs Connect onboarding guide.

---

## Area B — `capabilities` shape modeling

### Gray area framing
`Account.capabilities` is an unusual shape: a map of capability_name (string) → capability_object (map). Stripe has ~30+ capability names and adds ~3-5 per year. The inner object has a stable 5-field shape. Need to decide whether to type the inner, the outer, both, or neither.

### Options considered

| Option | Summary | Verdict |
|--------|---------|---------|
| 1. Typed inner, untyped outer | `%{String.t() => %Account.Capability{}}` — typed inner struct, open string keys | **✓ Selected** |
| 2. Plain map of maps (stripity_stripe approach) | Zero ceremony, zero typing. | Rejected — leaves ergonomic value on the floor given stable inner shape |
| 3. Atom-keyed mega-struct (stripe-go/java/rust approach) | All 30+ capabilities as named struct fields with atom-cast status enum. | Rejected — goes stale every Stripe release for a hand-maintained SDK; nil-bloat |
| 4. Hybrid — atom-cast `status` only, rest raw | Half-typed. | Rejected — `String.to_atom/1` footgun on unknown Stripe values; awkward to document |

### Key insight
Cross-language data points diverge based on how the SDK is **maintained**:
- stripe-go, stripe-java, async-stripe (Rust) all use Option 3 — but they're **OpenAPI-generated and re-ship on every Stripe release**, so staleness has zero cost
- stripity_stripe uses Option 2 — also generated, but punts on open-keyed maps because OpenAPI-to-Elixir-typespec for open keys is messy
- **LatticeStripe is hand-maintained** → cost curve inverts → Option 1 is the unique sweet spot

### Locked shape (D-02)

`LatticeStripe.Account.Capability` module with:
- `@known_fields` = `~w(status requested requested_at requirements disabled_reason)a`
- `:extra` map absorbs forward-compat per F-001
- `status_atom/1` helper — uses `String.to_existing_atom/1` inside guard clause over pre-declared `@known_statuses`, falls through to `:unknown` for forward-compat, **never** calls `String.to_atom/1` on user input (atom-table DOS safe)

Outer map stays a plain `map(String.t(), Account.Capability.t())` on `%Account{}` — does NOT consume a D-01 budget slot because it's an open-keyed forwarding map, not a fixed-shape promoted field.

**Research sources:** stripity-stripe source (capabilities as `term`), stripe-go (`AccountCapabilityStatus` enum), stripe-java `Account.Capabilities`, async-stripe Rust, Stripe API Capabilities reference, Stripe Docs Account Capabilities.

---

## Area C — Phase 17/18 scope boundary

### Gray area framing
Two Stripe API surfaces straddle the Phase 17 (onboarding) / Phase 18 (money movement) line:
1. **External Accounts** — `/v1/accounts/:id/external_accounts` (bank accounts + debit cards as payout destinations)
2. **Login Links** — `/v1/accounts/:id/login_links` (single-use Express dashboard return URL)

### Surface 1: External Accounts

| Option | Summary | Verdict |
|--------|---------|---------|
| a. Phase 17 — full CRUD in onboarding | Completes "account setup" mental model. | Rejected — bloats 17, semantically about payouts |
| b. Phase 18 — full CRUD with payouts | Lives next to Payouts (their consumers); matches every SDK's placement. | **✓ Selected** |
| c. Split — convenience in 17, full module in 18 | Two code paths to same endpoint. | Rejected — drift, duplicated docs |

**Decisive factor:** stripity_stripe has top-level `Stripe.ExternalAccount`. stripe-node/python/go/java all group External Accounts under the Connect payouts namespace. Stripe's own API reference places External Accounts next to Payouts, not under Account onboarding. Developer mental model check: `grep -r external_account` asks "how do I pay out" → Phase 18.

### Surface 2: Login Links

| Option | Summary | Verdict |
|--------|---------|---------|
| a. `Account.create_login_link/4` function on Account module | Tiny, no new module. | Rejected — inconsistent with AccountLink (its own module in same phase) |
| b. Standalone `LatticeStripe.LoginLink` in Phase 17 | Mirrors AccountLink exactly; matches stripity_stripe; completes Express onboarding story. | **✓ Selected** |
| c. Defer to Phase 18 or 19 | Smaller 17. | Rejected — splits Express story across phases |
| d. Defer entirely | Zero work. | Rejected — Express devs need dashboard return path |

### Resulting scopes (D-03)

**Phase 17:** `Account` + `AccountLink` + `LoginLink` (3 modules, ~9 endpoints, ~600-800 src + ~900 test LOC)
**Phase 18:** `ExternalAccount` + `Transfer` + `TransferReversal` + `Payout` + `Balance` + `BalanceTransaction` + destination charges + platform fees (5+ modules, ~20 endpoints, ~900-1100 src + ~1200 test LOC)

Size/effort roughly balanced. Phase 17 complexity is concentrated per-endpoint (Account is Stripe's fattest single resource); Phase 18 has more endpoints, each simpler.

**Research sources:** stripity_stripe Stripe.ExternalAccount HexDocs, Stripe API External Accounts reference, Stripe API Reference index, stripe-node.

---

## Area D — Atom guards and helpers

### Gray area framing
Three candidate ergonomic calls where the Phase 15 D5 `pause_collection` atom-guard pattern could apply:
1. `Account.reject/4` — reason enum
2. `Account.request_capability/4` — wrapper helper
3. `AccountLink.create/3` — type enum on a multi-field create

### D-04a — `Account.reject/4` reason guard

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| Atom-guarded `when reason in [:fraud, :terms_of_service, :other]` | Direct D5 analog; compile-time typo protection; atom-table DOS safe (compile-time literals); 3-value enum stable since ~2016 (decade-stable) | If Stripe adds a value, users wait for SDK release (~minor version cadence) | **✓ Selected** |
| String pass-through | Trivially forward-compat | Drifts from D5 pattern; no typo protection | Rejected |
| Both (guard clause + string fallback) | Best of both | API surface bloat, two clauses to document | Rejected |

### D-04b — `Account.request_capability/4` helper

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| Include | Hides one level of nested-map construction | Pure spelling sugar — no guard, no validation, no atom typing; capability list is ~30+ open strings that grow every quarter (any whitelist rots) | Rejected |
| **Omit** | Zero API surface; honors D5 "no fake ergonomics"; document `update/4 + capabilities: %{...}` pattern in moduledoc instead | Users construct a 3-deep nested map (mitigated by moduledoc example) | **✓ Selected** |
| Include with atom-guarded capability list | Compile-time typo protection | Goes stale every quarter — exact failure mode D5 exists to avoid | Rejected |

### D-04c — `AccountLink.create/3` type guard

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **Map-only `create(client, params, opts)`** | Mirrors every other create endpoint in LatticeStripe; consistency wins; `refresh_url`/`return_url`/`collect` already live in the same params map | Typo on `type` is a runtime Stripe 400 | **✓ Selected** |
| `create(client, account_id, type, opts)` with guard | Compile-time typo protection on 2-value enum | Breaks SDK-wide `create/3` shape for marginal benefit; awkward arity (account_id is just one of ~5 required params — why elevate it?) | Rejected |

### Unifying principle

Function-head atom guards earn their place when **(1)** the endpoint is a dedicated single-purpose verb, **(2)** the meaningful argument is a small closed enum, **(3)** the enum is stable enough that SDK churn won't strand users. `Account.reject` hits all three cleanly. Helpers without a guard or validation are "fake ergonomics" (Phase 15 D5) and are omitted. Consistency with the SDK-wide `create(client, params, opts)` shape outranks marginal typo protection on multi-field creates.

**Research sources:** Stripe API Reject Account, Stripe API Create Account Link, Stripe Connect Account Capabilities, stripity_stripe Stripe.AccountLink, Elixir Patterns and Guards docs, stripe-node forward-compat enum discussion.

---

## Cross-area coherence check

All four decisions were reviewed for internal consistency:

- **D-01** (6 promoted fields) + **D-02** (Capability as separate module not counted against budget) — coherent; the reframing to "count distinct modules not parent fields" explicitly handles this case
- **D-01** + **D-04** — no conflict; reject is an action on Account, struct budget is about the shape of `%Account{}`
- **D-02** (inner struct with `:extra`) + **F-001** — `Capability.cast/1` uses the same `Map.split` pattern as every other F-001 struct
- **D-03** (LoginLink in Phase 17) + **D-04c** (AccountLink create shape) — `LoginLink.create/3` follows the same map-based shape as `AccountLink.create/3`
- **D-03** (ExternalAccount → Phase 18) vs original Phase 18 ROADMAP entry — requires ROADMAP.md Phase 18 entry update (done as part of this commit)

No conflicts found. All decisions compose cleanly.

---

## Deferred Ideas

Captured in `17-CONTEXT.md` `<deferred>` section:
- `Account.Persons` sub-resource (defer until user demand)
- `AccountLink.create_onboarding/3` / `create_update/3` thin wrappers (post-ship, user demand)
- Standard/Express/Custom type convenience constructors (rejected as fake ergonomics)
- Unified `Account.Party` struct (rejected — mutual exclusion is load-bearing)
- Cascading `Account.Settings` sub-objects into typed structs (revisit as standalone phase addition)

---

*End of discussion log. Canonical decisions live in `17-CONTEXT.md`.*
