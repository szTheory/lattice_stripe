# Phase 41: Quote Lifecycle E2E Verification - Research

**Researched:** 2026-05-25
**Domain:** Quote verification closure for lifecycle, PDF download, and bounded quote-to-downstream follow-through under `stripe-mock` [VERIFIED: phase context + codebase grep]
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

Verbatim copy from `.planning/phases/41-quote-lifecycle-e2e-verification/41-CONTEXT.md` [VERIFIED: `41-CONTEXT.md`].

### Locked Decisions

### Lifecycle proof depth

- **D-01:** Use a **hybrid verification posture**. Integration tests must prove the Quote lifecycle edges that `stripe-mock` can truthfully cover, while unit tests remain the source of truth for parser depth, empty-param contracts, expanded-object decoding, and nuanced lifecycle semantics.
- **D-02:** Phase 41 integration evidence must explicitly exercise:
  - `Quote.pdf/3`
  - `Quote.accept/3`
  - `Quote.cancel/3`
  - one narrow quote-to-downstream follow-through hop after acceptance
- **D-03:** Do **not** treat `stripe-mock` as a real Quote state-machine oracle. Verifier wording must say that the integration evidence proves request routing, request encoding, binary transport, and typed decode sanity under `stripe-mock`, not full real-Stripe lifecycle semantics.
- **D-04:** Do **not** close Phase 41 with unit-only proof. The audit explicitly calls out missing integration evidence for Quote lifecycle closure, and the verifier should require fresh targeted Quote integration runs.

### Quote-to-invoice follow-through

- **D-05:** The correct follow-through depth is: `Quote.create/3 -> Quote.finalize/4 -> Quote.accept/3 -> inspect returned downstream reference -> retrieve exactly one linked downstream Stripe resource -> stop`.
- **D-06:** Prefer downstream follow-through in this order when present in the accepted quote response:
  - `invoice`
  - otherwise `subscription`
  - otherwise `subscription_schedule`
- **D-07:** Follow-through retrieval should assert **typed top-level decode only**. Do not assert invoice payment behavior, subscription activation timing, webhook ordering, or any broader multi-resource business workflow semantics.
- **D-08:** This is the least-surprise proof for a low-level Stripe SDK: it demonstrates the handoff users actually care about after `accept/3` without drifting into Accrue-owned orchestration or fake end-to-end billing-theater.

### PDF proof strictness

- **D-09:** `Quote.pdf/3` should be treated as an **expected integration-proof requirement** for Phase 41 because the audit explicitly flags missing Quote PDF integration coverage and PDF download is exactly the kind of wire-contract check `stripe-mock` is good at.
- **D-10:** The default success path is a real integration call that proves `Quote.pdf/3` returns raw binary over HTTP and does not leak a decoded struct or `%Response{}` wrapper.
- **D-11:** A fallback to unit/transport-only proof is allowed **only** if a concrete `stripe-mock` limitation is reproduced and documented in the verifier with the failure shape, date, and explicit note that live Stripe/test-environment proof remains outstanding.
- **D-12:** Even when integration passes, the verifier must not claim PDF rendering fidelity or business-semantic quote correctness. The proof is transport and binary-response handling only.

### Allowed repair scope

- **D-13:** Allow **narrow evidence repairs only**:
  - Quote integration-test additions or tightening for `pdf/3`, `accept/3`, `cancel/3`, and one downstream follow-through hop
  - small fixture or helper adjustments required to make those proofs executable and truthful
  - tiny support-code or wiring fixes only when they are strictly evidence-enabling for already-shipped Quote behavior
  - `36-VERIFICATION.md` creation plus QUOT-only traceability updates
- **D-14:** Do **not** reopen Quote API design, add new helper verbs, expand parser trees beyond the shipped Phase 36 contract, or perform opportunistic cleanup in unrelated resources, guides, or planning families.
- **D-15:** Do **not** absorb broad roadmap/requirements truth reconciliation in Phase 41. Keep planning-document edits tightly scoped to `36-VERIFICATION.md` and `QUOT-01` through `QUOT-05`. Broader planning-truth cleanup remains Phase 42 work.
- **D-16:** If verification reveals a substantive shipped Quote behavior defect rather than a proof gap, record it and route it to follow-up work instead of stretching Phase 41 into a hidden repair phase.

### Decision posture for downstream agents

- **D-17:** Shift ordinary planning and verification choices left to the agent for this phase. Downstream agents should prefer cohesive recommendations and agent discretion for routine tradeoffs instead of asking the user to adjudicate low-impact details repeatedly.
- **D-18:** Escalate only if a decision would materially affect:
  - shipped Quote behavior
  - public API surface
  - milestone acceptance standards
  - phase scope boundary
  - dependency footprint
  - verifier credibility
- **D-19:** Treat this as the standing workflow preference for Phase 41 planning and execution. If useful later, a broader GSD/process-level shift can be captured separately, but it should not broaden this phase’s implementation scope.

### the agent's Discretion

- Exact test naming and module structure for the new Quote integration coverage, as long as it stays aligned with current `test/integration/` conventions.
- Exact verifier table layout, wording, and score format, as long as the report is closed, audit-friendly, and explicit about `stripe-mock` limits.
- Whether the lifecycle proof uses `create -> cancel` or `finalize -> cancel`, as long as the chosen route is truthful and closes the explicit cancel-evidence gap.
- Whether the follow-through hop retrieves `Invoice`, `Subscription`, or `SubscriptionSchedule`, based on what the accepted Quote response actually exposes under `stripe-mock`.

### Deferred Ideas (OUT OF SCOPE)

- Any broader roadmap/requirements truth reconciliation beyond Quote rows remains deferred to Phase 42.
- Any real Quote behavior defect discovered during Phase 41 verification should become follow-up work instead of hidden expansion inside this closure phase.
- Any future desire to validate richer quote lifecycle semantics against real Stripe sandboxes or test mode should be separate from this `stripe-mock`-based closure phase.
- Any project-wide GSD/process change to make “shift-left agent discretion” the default across workflows should be captured separately from Phase 41 implementation work.
</user_constraints>

## Project Constraints (from CLAUDE.md)

- Use Elixir `1.15+` and OTP `26+`; the local environment is newer (`Mix 1.19.5`, OTP `28`) and remains compatible with that floor [VERIFIED: CLAUDE.md + `mix --version`].
- Keep dependencies minimal; this phase should add no new Hex packages unless a blocker proves otherwise [VERIFIED: CLAUDE.md + `mix.exs`].
- Do not introduce Dialyzer work; typespecs remain documentation-only in this project [VERIFIED: CLAUDE.md].
- Keep HTTP proof on the existing transport boundary with Finch as the default adapter and `test_integration_client/1` as the integration harness [VERIFIED: CLAUDE.md + `test/support/test_helpers.ex`].
- Preserve the explicit Stripe-shaped SDK boundary; do not add Accrue-style orchestration helpers to make the quote flow look more “end-to-end” than the library intends [VERIFIED: CLAUDE.md + `lib/lattice_stripe/quote.ex`].
- Stay inside GSD workflow artifacts; this research phase may write planning docs but should not do opportunistic product edits outside the scoped closure work [VERIFIED: CLAUDE.md].

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| QUOT-01 | Developer can create, retrieve, update, list quotes with auto-pagination via `stream!/3` | Existing unit coverage is present; integration harness repair is needed because `test/integration/quote_integration_test.exs` currently fails quote creation against current `stripe-mock` validation [VERIFIED: `test/lattice_stripe/quote_test.exs` + `mix test test/integration/quote_integration_test.exs --include integration`]. |
| QUOT-02 | Developer can finalize, accept, and cancel quotes via explicit verbs | Unit tests already prove request shape and typed semantic fixtures; Phase 41 should add route/decode integration calls for `finalize/4`, `accept/3`, and `cancel/3` without asserting real state progression under `stripe-mock` [VERIFIED: `test/lattice_stripe/quote_test.exs` + SDK probe + stripe-mock README]. |
| QUOT-03 | Developer can list and stream quote line items via `Quote.list_line_items/4` and `stream_line_items!/4` | Current unit coverage exists and line-item integration remains the right downstream sanity check once quote creation is repaired [VERIFIED: `test/lattice_stripe/quote_test.exs` + `test/integration/quote_integration_test.exs`]. |
| QUOT-04 | Developer can download quote PDF as raw binary via `Quote.pdf/3` | `Quote.pdf/3` is untested in integration today, but the SDK probe returned a 22-byte binary from `Quote.pdf/3`, which makes this the cleanest missing integration proof to add [VERIFIED: `test/lattice_stripe/quote_test.exs` + SDK probe + Stripe quote PDF docs]. |
| QUOT-05 | Quote line items deserialize into typed `Quote.LineItem` struct | Typed parsing is already proven in unit tests and should remain unit-owned, with integration limited to top-level typed `%Response{data: %List{}}` sanity on line-item routes [VERIFIED: `test/lattice_stripe/quote_test.exs` + `lib/lattice_stripe/quote.ex`]. |
</phase_requirements>

## Summary

Phase 41 should be planned as a narrow two-plan closure phase: first repair and extend the quote integration harness, then create `36-VERIFICATION.md` and close QUOT traceability with fresh evidence only [VERIFIED: phase context + `.planning/REQUIREMENTS.md` + `.planning/phases/39-credit-note-verification-closure/39-VERIFICATION.md`]. The current Quote integration file exists, but `mix test test/integration/quote_integration_test.exs --include integration` fails `4/5` tests because the fixture creates quotes with `price_data.product_data.name` while the running `stripe-mock:latest` image now rejects that shape and requires `price_data.product` [VERIFIED: `test/integration/quote_integration_test.exs` + `test/support/fixtures/quote.ex` + integration test run + curl probe].

After bypassing that stale fixture shape, the existing SDK can already prove three useful things under the current environment: `Quote.create/3` succeeds with a Product-backed price payload, `Quote.pdf/3` returns raw binary, and both quote line-item endpoints respond with typed list-shaped data [VERIFIED: SDK probe + curl probe]. The same probes also show why the verifier must stay bounded: `Quote.finalize/4`, `Quote.accept/3`, and `Quote.cancel/3` all return a typed `%Quote{}` but keep `status` at `:draft`, and `invoice` / `subscription` / `subscription_schedule` are `nil` after accept under the current `stripe-mock` image [VERIFIED: SDK probe; CITED: https://github.com/stripe/stripe-mock].

**Primary recommendation:** Plan Phase 41 so Plan 01 begins with a feasibility gate inside `test/integration/quote_integration_test.exs`: repair quote creation, add PDF + lifecycle route/decode assertions, attempt the one-hop downstream retrieve exactly once, and if no downstream reference is exposed under current `stripe-mock`, record that reproduced limitation explicitly in the verifier instead of inventing semantic assertions [VERIFIED: phase context + SDK probe + stripe-mock README].

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Quote route and binary PDF proof | API / Backend | — | `LatticeStripe.Quote` and `LatticeStripe.Client.download/3` own request construction, HTTP transport, and response decoding for `pdf/3` [VERIFIED: `lib/lattice_stripe/quote.ex` + `lib/lattice_stripe/client.ex`]. |
| Lifecycle verb wire proof (`finalize/4`, `accept/3`, `cancel/3`) | API / Backend | — | These are explicit Quote resource verbs already implemented in the SDK; the phase only needs evidence that the routes and empty-param POSTs stay correct [VERIFIED: `lib/lattice_stripe/quote.ex` + `test/lattice_stripe/quote_test.exs`]. |
| One-hop downstream follow-through | API / Backend | — | The only valid downstream owners are `Invoice`, `Subscription`, or `SubscriptionSchedule`, all of which already expose retrieve functions for typed top-level decode [VERIFIED: codebase grep on `lib/lattice_stripe/{invoice,subscription,subscription_schedule}.ex`]. |
| Verification artifact and QUOT traceability closure | Static / Docs | API / Backend | `36-VERIFICATION.md` and `.planning/REQUIREMENTS.md` consume the fresh test outputs; they should not invent facts beyond what the executable proof can support [VERIFIED: `.planning/REQUIREMENTS.md` + neighboring closure verifiers]. |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ExUnit | `1.19.5` runtime / stdlib | Targeted unit and integration commands for closure evidence [VERIFIED: `mix --version`] | This repo already uses ExUnit in `test/test_helper.exs`, and neighboring closure phases cite `mix test` as the primary proof loop [VERIFIED: `test/test_helper.exs` + neighboring verification docs]. |
| `stripe-mock` | Docker image `stripe/stripe-mock:latest` [CITED: https://github.com/stripe/stripe-mock] | Route, parameter, and decode sanity against Stripe-shaped responses [VERIFIED: `docker ps` + `test/integration/quote_integration_test.exs`] | Stripe documents `stripe-mock` as a basic sanity-check server used by Stripe SDK suites, which matches this phase’s bounded integration goal [CITED: https://github.com/stripe/stripe-mock; CITED: https://github.com/stripe/stripe-ruby]. |
| Finch transport via `test_integration_client/1` | Repo-pinned `{:finch, "~> 0.21"}` [VERIFIED: `mix.exs`] | Real HTTP transport path used by integration tests [VERIFIED: `test/support/test_helpers.ex`] | The phase is about evidence on the shipped SDK path, so tests should keep using the existing Finch-backed integration client rather than mocks or ad-hoc HTTP code [VERIFIED: `test/support/test_helpers.ex` + `lib/lattice_stripe/client.ex`]. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Mox | Repo-pinned `{:mox, "~> 1.2"}` [VERIFIED: `mix.exs`] | Deterministic unit proof for parser depth, empty-param contracts, and semantic fixtures [VERIFIED: `test/lattice_stripe/quote_test.exs`] | Keep lifecycle-status semantics in unit tests when `stripe-mock` hardcodes unrealistic Quote responses [VERIFIED: unit tests + SDK probe]. |
| `LatticeStripe.Invoice` / `Subscription` / `SubscriptionSchedule` | Shipped repo modules [VERIFIED: codebase grep] | Exactly one downstream retrieve after `accept/3` when a reference exists [VERIFIED: phase context D-05/D-06] | Use only one retrieve and stop; do not build multi-resource orchestration or payment-state assertions [VERIFIED: phase context + `lib/lattice_stripe/quote.ex`]. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `stripe-mock` closure proof | Live Stripe sandbox proof | A sandbox would model real lifecycle semantics better, but it is broader, slower, and outside the locked closure posture for this phase unless `stripe-mock` makes a required proof impossible [CITED: https://docs.stripe.com/testing-use-cases; CITED: https://github.com/stripe/stripe-mock]. |
| Integration assertions on `status == :open/:accepted/:canceled` | Unit semantic fixtures only | The current mock returns `:draft` for finalize/accept/cancel, so semantic status checks are misleading in integration and should stay unit-owned [VERIFIED: SDK probe + `test/lattice_stripe/quote_test.exs`]. |

**Installation:**
```bash
docker run --rm -it -p 12111-12112:12111-12112 stripe/stripe-mock:latest
mix test test/integration/quote_integration_test.exs --include integration
```

**Version verification:** No new Hex package versions need to be introduced for Phase 41; the relevant execution stack is already present as `Mix 1.19.5`, `Docker 29.4.1`, and a running `stripe/stripe-mock:latest` container named `stripe-mock-phase39` [VERIFIED: `mix --version` + `docker --version` + `docker ps`].

## Architecture Patterns

### System Architecture Diagram

```text
Quote integration test
  -> test_integration_client/1
  -> POST /v1/quotes
  -> typed %Quote{}
     -> GET /v1/quotes/:id/pdf
     -> raw binary assertion
     -> POST /v1/quotes/:id/finalize
     -> POST /v1/quotes/:id/accept
     -> inspect invoice/subscription/subscription_schedule
        -> if reference present: retrieve exactly one downstream resource
        -> else: record reproduced stripe-mock limitation in verifier
     -> POST /v1/quotes/:id/cancel
  -> fresh targeted command output
  -> 36-VERIFICATION.md
  -> QUOT-01..05 rows in REQUIREMENTS.md
```

The diagram reflects the bounded evidence flow the planner should enforce: executable proof first, documentation closure second [VERIFIED: phase context + neighboring closure phases].

### Recommended Project Structure

```text
test/
├── integration/quote_integration_test.exs      # repair fixture inputs; add pdf/lifecycle/downstream probes [VERIFIED: current file + phase context]
├── lattice_stripe/quote_test.exs               # keep parser and semantic lifecycle truth in unit tests [VERIFIED: current file]
└── support/fixtures/quote.ex                   # create Product-backed quote fixture helpers for current stripe-mock [VERIFIED: current file + test run]

.planning/
├── phases/36-quote/36-VERIFICATION.md          # new closed verifier artifact [VERIFIED: missing file + milestone audit]
└── REQUIREMENTS.md                             # close QUOT-01..05 only [VERIFIED: `.planning/REQUIREMENTS.md`]
```

### Pattern 1: Shape-First Lifecycle Integration

**What:** Exercise `create -> finalize -> accept -> inspect downstream ref -> cancel` through the real HTTP client, but assert only route success, top-level typing, and binary behavior that `stripe-mock` can support [VERIFIED: phase context D-01..D-04 + stripe-mock README].  
**When to use:** For closure evidence where the API surface already exists and the risk is stale or missing runtime proof, not missing product logic [VERIFIED: phase context].  
**Example:**
```elixir
# Source: test/integration/mandate_integration_test.exs pattern + quote SDK probe [VERIFIED: codebase grep]
setup do
  {:ok, client: test_integration_client()}
end

test "accept/3 returns a typed quote even when stripe-mock is not stateful", %{client: client} do
  quote_id = "qt_example_after_create"
  assert {:ok, %LatticeStripe.Quote{id: ^quote_id}} = LatticeStripe.Quote.accept(client, quote_id)
end
```

### Pattern 2: Semantic Truth Stays in Unit Tests

**What:** Keep assertions about Quote status transitions, expanded downstream objects, and parser depth in `test/lattice_stripe/quote_test.exs` where fixtures are deterministic [VERIFIED: `test/lattice_stripe/quote_test.exs`].  
**When to use:** Any time `stripe-mock` returns unrealistic lifecycle bodies or omits downstream references [VERIFIED: SDK probe].  
**Example:**
```elixir
# Source: test/lattice_stripe/quote_test.exs [VERIFIED: codebase grep]
assert {:ok, %Quote{status: :accepted}} = Quote.accept(client, "qt_test1234567890abc")
assert %Invoice{} = Quote.from_map(expanded_quote_json()).invoice
```

### Anti-Patterns to Avoid

- **Re-asserting lifecycle semantics in integration:** Current `stripe-mock` returns `:draft` for finalize/accept/cancel in the SDK probe, so asserting `:open` / `:accepted` / `:canceled` there would manufacture false failures or fake confidence [VERIFIED: SDK probe].
- **Inventing a custom quote-to-invoice helper for the test:** The phase boundary explicitly forbids broadening into orchestration; retrieve one existing downstream resource only if the accepted quote exposes a reference [VERIFIED: phase context D-05..D-08, D-13..D-16].
- **Closing QUOT rows without a fresh quote integration rerun:** The audit and locked decisions both require fresh targeted integration evidence, not paperwork-only closure [VERIFIED: phase context D-04 + `.planning/v1.3-v1.3-MILESTONE-AUDIT.md` grep].

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| PDF transport proof | A custom PDF downloader or manual HTTP wrapper | `Quote.pdf/3` over `Client.download/3` | The binary transport path is already shipped and unit-tested; the missing work is only integration evidence [VERIFIED: `lib/lattice_stripe/quote.ex` + `test/lattice_stripe/client_test.exs`]. |
| Quote semantic state machine in integration | Fake persistence or bespoke lifecycle fixtures inside `stripe-mock` tests | Existing unit fixtures in `test/support/fixtures/quote.ex` and `test/lattice_stripe/quote_test.exs` | `stripe-mock` is stateless and hardcoded; trying to simulate real lifecycle semantics in integration fights the tool and weakens verifier honesty [CITED: https://github.com/stripe/stripe-mock; VERIFIED: SDK probe]. |
| Downstream workflow orchestration | Multi-step invoice/subscription business assertions | One typed top-level retrieve of `Invoice`, `Subscription`, or `SubscriptionSchedule` if present | The phase is closure proof for a low-level SDK, not billing-engine workflow validation [VERIFIED: phase context + `lib/lattice_stripe/quote.ex`]. |

**Key insight:** The only missing value here is truthful evidence on the shipped SDK surface; every custom abstraction beyond that increases scope and lowers verifier credibility [VERIFIED: phase context + milestone audit].

## Common Pitfalls

### Pitfall 1: Stale Quote Creation Payload

**What goes wrong:** Quote integration setup fails before any lifecycle/PDF assertions run [VERIFIED: integration test run].  
**Why it happens:** `test/support/fixtures/quote.ex` creates quote line items with `price_data.product_data.name`, but the current `stripe-mock` validator rejects that path and requires `price_data.product` [VERIFIED: `test/support/fixtures/quote.ex` + integration test run + curl probe].  
**How to avoid:** Create a Product first in the integration fixture path and feed `price_data.product` into quote creation [VERIFIED: curl probe + SDK probe].  
**Warning signs:** `Request validation error ... price_data ... 'product' is required` from `mix test test/integration/quote_integration_test.exs --include integration` [VERIFIED: integration test run].

### Pitfall 2: Overclaiming `stripe-mock` Lifecycle Semantics

**What goes wrong:** The verifier claims real quote-state progression or downstream-object creation that the mock did not actually prove [VERIFIED: SDK probe].  
**Why it happens:** `stripe-mock` is explicitly hardcoded and stateless, and the current probe returns `%Quote{status: :draft}` plus nil downstream refs even after `finalize/4` and `accept/3` [CITED: https://github.com/stripe/stripe-mock; VERIFIED: SDK probe].  
**How to avoid:** Assert route/decode sanity in integration, keep status semantics in unit tests, and record reproduced mock limits verbatim in `36-VERIFICATION.md` [VERIFIED: phase context + neighboring closure verifiers].  
**Warning signs:** `accepted.invoice == nil`, `accepted.subscription == nil`, `accepted.subscription_schedule == nil`, or lifecycle statuses staying `:draft` in probe output [VERIFIED: SDK probe].

### Pitfall 3: Missing PDF Integration Evidence

**What goes wrong:** QUOT-04 remains audit-open even if unit tests pass [VERIFIED: milestone audit grep].  
**Why it happens:** Phase 36 only shipped unit proof for `Quote.pdf/3`; the integration file currently has no PDF test [VERIFIED: `test/lattice_stripe/quote_test.exs` + `test/integration/quote_integration_test.exs`].  
**How to avoid:** Add a dedicated integration assertion that `Quote.pdf/3` returns raw binary and not a `%Response{}` wrapper [VERIFIED: phase context D-09..D-12 + SDK probe].  
**Warning signs:** `36-VERIFICATION.md` cannot cite a targeted PDF integration command [VERIFIED: missing file + phase context].

### Pitfall 4: Documentation Closure Without Fresh QUOT Commands

**What goes wrong:** `36-VERIFICATION.md` or QUOT rows read as current, but the executable evidence is stale or absent [VERIFIED: `.planning/REQUIREMENTS.md` + missing `36-VERIFICATION.md`].  
**Why it happens:** The repo already has Phase 36 summaries, which makes it tempting to “close” the phase from historical artifacts alone [VERIFIED: `.planning/phases/36-quote/36-01-SUMMARY.md` + `36-02-SUMMARY.md`].  
**How to avoid:** Require fresh Quote-scoped unit and integration reruns in the verifier, mirroring Phases 39 and 40 [VERIFIED: neighboring verifier artifacts].  
**Warning signs:** QUOT rows updated without a same-day `mix test test/integration/quote_integration_test.exs --include integration` citation [VERIFIED: closure pattern docs].

## Code Examples

Verified patterns from current repo and official docs:

### Integration Guard Pattern

```elixir
# Source: test/integration/quote_integration_test.exs [VERIFIED: codebase grep]
setup_all do
  case :gen_tcp.connect(~c"localhost", 12_111, [], 1000) do
    {:ok, socket} ->
      :gen_tcp.close(socket)
      start_supervised!({Finch, name: LatticeStripe.IntegrationFinch})
      :ok

    {:error, _} ->
      raise "stripe-mock not running on localhost:12111"
  end
end
```

### Quote PDF Contract

```elixir
# Source: lib/lattice_stripe/quote.ex + docs.stripe.com/api/quotes/pdf [VERIFIED: codebase grep; CITED: https://docs.stripe.com/api/quotes/pdf]
@doc """
`pdf/3` returns raw PDF binary, not a `%Quote{}`.
"""
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Phase 36 expected route-sanity integration plus at least one line-item route [VERIFIED: `36-VALIDATION.md`] | Closure phases 38-40 now require a closed verifier artifact backed by fresh scoped reruns before requirements move to `Verified` [VERIFIED: `38-RESEARCH.md` + `39-VERIFICATION.md` + `35-VERIFICATION.md`] | 2026-05-25 closure-wave planning [VERIFIED: file dates/content] | Phase 41 should separate executable proof work from verifier/traceability closure instead of treating them as one generic task [VERIFIED: neighboring closure patterns]. |
| Treating `stripe-mock` as if it roughly models lifecycle progression | Treat `stripe-mock` as URL/param/type sanity only, and use Stripe sandbox/live testing for richer semantics [CITED: https://github.com/stripe/stripe-mock; CITED: https://docs.stripe.com/testing-use-cases] | Current Stripe docs and README as of 2026-05-25 [CITED: official sources] | Integration assertions must be bounded, and any missing downstream ref after accept must be reported honestly rather than patched over [VERIFIED: SDK probe]. |

**Deprecated/outdated:**
- `price_data.product_data.name` as the integration fixture input for Quote creation is outdated against the current running `stripe-mock` validator; use a real Product ID in `price_data.product` for integration setup instead [VERIFIED: integration test run + curl probe + SDK probe].

## Assumptions Log

All material findings in this research were verified in the current repo or cited from official docs. No `[ASSUMED]` claims remain.

## Open Questions (RESOLVED)

1. **Can Phase 41 satisfy D-05 under the current `stripe-mock` image without broadening scope?**
   - **Resolved answer:** No, not under the current local `stripe-mock` behavior. A fresh repo-local probe using a repaired Product-backed Quote create flow reached `Quote.create/3`, `Quote.update/4`, `Quote.stream!/3`, `Quote.list_line_items/4`, `Quote.stream_line_items!/4`, `Quote.finalize/4`, `Quote.accept/3`, `Quote.cancel/3`, and `Quote.pdf/3`, but `accept/3` still returned `invoice == nil`, `subscription == nil`, and `subscription_schedule == nil` [VERIFIED: 2026-05-25 `mix run -e` probe against local `stripe-mock`].
   - **Implication:** The current environment can support fresh bounded evidence for QUOT-01 through QUOT-05 except the locked D-05 requirement to retrieve exactly one downstream resource after accept. That downstream hop cannot be completed truthfully under the present `stripe-mock` image because no downstream reference is exposed to retrieve [VERIFIED: probe].
   - **Planning consequence:** The planner must not silently reduce the acceptance standard. It should either:
     1. produce a phase-split / escalation recommendation because the roadmap's strict quote-to-invoice follow-through criterion cannot currently be met under `stripe-mock`, or
     2. introduce an explicit checkpoint that blocks closure until a reproducible environment capable of returning one downstream reference is available.
   - **Evidence captured:** The same probe also confirmed that `Quote.update/4`, `Quote.stream!/3`, `Quote.stream_line_items!/4`, and `Quote.pdf/3` all work with the repaired setup, so the remaining requirement-coverage gap is planning completeness, not implementation uncertainty [VERIFIED: probe].

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir / Mix | All targeted test commands | ✓ [VERIFIED: `mix --version`] | `Mix 1.19.5` on OTP `28` [VERIFIED: `mix --version`] | — |
| Docker | Running `stripe-mock` for integration proof | ✓ [VERIFIED: `docker --version`] | `29.4.1` [VERIFIED: `docker --version`] | Existing Homebrew `stripe-mock` service would also work, but Docker is already available and active [CITED: https://github.com/stripe/stripe-mock]. |
| `stripe-mock` service | `Quote` integration tests and SDK probes | ✓ [VERIFIED: `docker ps`] | `stripe/stripe-mock:latest` container `stripe-mock-phase39` [VERIFIED: `docker ps`] | `docker run --rm -it -p 12111-12112:12111-12112 stripe/stripe-mock:latest` [CITED: https://github.com/stripe/stripe-mock]. |

**Missing dependencies with no fallback:**
- None [VERIFIED: environment audit].

**Missing dependencies with fallback:**
- None in the current environment [VERIFIED: environment audit].

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit with Mox unit tests and `stripe-mock` integration tests [VERIFIED: `test/test_helper.exs` + `mix.exs` + `36-VALIDATION.md`] |
| Config file | `test/test_helper.exs` [VERIFIED: codebase grep] |
| Quick run command | `mix test test/lattice_stripe/quote_test.exs --warnings-as-errors` [VERIFIED: `36-VALIDATION.md`] |
| Full suite command | `mix ci` [VERIFIED: `mix.exs` alias + `36-VALIDATION.md`] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| QUOT-01 | Create/retrieve/list/stream Quote routes still work with typed top-level decode | unit + integration | `mix test test/lattice_stripe/quote_test.exs test/integration/quote_integration_test.exs --include integration` [VERIFIED: existing files + current failure output] | ✅ but red [VERIFIED: test run] |
| QUOT-02 | `finalize/4`, `accept/3`, and `cancel/3` keep correct request routing and explicit public verbs | unit + integration | `mix test test/lattice_stripe/quote_test.exs test/integration/quote_integration_test.exs --include integration` [VERIFIED: existing files] | ✅ but missing `accept/cancel` integration coverage today [VERIFIED: `test/integration/quote_integration_test.exs`] |
| QUOT-03 | Quote line-item list/stream routes return typed list wrappers | unit + integration | `mix test test/lattice_stripe/quote_test.exs test/integration/quote_integration_test.exs --include integration` [VERIFIED: existing files] | ✅ but integration currently blocked by stale create fixture [VERIFIED: test run] |
| QUOT-04 | `Quote.pdf/3` returns raw binary over HTTP | unit + integration | `mix test test/lattice_stripe/quote_test.exs test/integration/quote_integration_test.exs --include integration` [VERIFIED: unit file + required new integration assertion] | ✅ unit / ❌ integration [VERIFIED: current files] |
| QUOT-05 | Quote line items deserialize into `%Quote.LineItem{}` | unit primary | `mix test test/lattice_stripe/quote_test.exs test/lattice_stripe/object_types_test.exs --warnings-as-errors` [VERIFIED: existing files + `36-VALIDATION.md`] | ✅ [VERIFIED: existing files] |

### Sampling Rate

- **Per task commit:** `mix test test/lattice_stripe/quote_test.exs --warnings-as-errors` after unit-affecting changes, and `mix test test/integration/quote_integration_test.exs --include integration` after integration-affecting changes [VERIFIED: current test layout + closure-phase pattern].
- **Per wave merge:** `mix test test/lattice_stripe/object_types_test.exs test/lattice_stripe/quote_test.exs test/integration/quote_integration_test.exs --include integration` [VERIFIED: file layout + `36-VALIDATION.md` adapted to current closure scope].
- **Phase gate:** Fresh Quote-scoped unit and integration commands must be green or explicitly bounded by reproduced `stripe-mock` limitations before creating `36-VERIFICATION.md` [VERIFIED: phase context D-03/D-04 + neighboring closure verifiers].

### Wave 0 Gaps

- [ ] `test/support/fixtures/quote.ex` — integration quote builder must create a Product-backed `price_data.product` payload for current `stripe-mock` [VERIFIED: test run + probes].
- [ ] `test/integration/quote_integration_test.exs` — add `pdf/3`, `accept/3`, `cancel/3`, and one bounded downstream follow-through attempt; keep lifecycle semantics shape-first [VERIFIED: current file + phase context].
- [ ] `.planning/phases/36-quote/36-VERIFICATION.md` — create the missing closed verifier artifact cited by the audit [VERIFIED: missing file + milestone audit].

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no [VERIFIED: phase scope] | Existing API-key auth path is unchanged; this phase adds only verification evidence [VERIFIED: `lib/lattice_stripe/client.ex`]. |
| V3 Session Management | no [VERIFIED: phase scope] | No session state exists in this SDK verification phase [VERIFIED: project architecture]. |
| V4 Access Control | no [VERIFIED: phase scope] | No new authorization surface is introduced [VERIFIED: phase scope]. |
| V5 Input Validation | yes [VERIFIED: current failures] | Keep Stripe-form param assertions in unit tests and `stripe-mock` schema validation in integration so request-shape drift is caught immediately [CITED: https://github.com/stripe/stripe-mock; VERIFIED: integration failure output]. |
| V6 Cryptography | no [VERIFIED: phase scope] | No crypto behavior is added or changed in Phase 41 [VERIFIED: phase scope]. |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Quote request-shape drift against current Stripe schema | Tampering | Product-backed integration setup plus targeted unit assertions on encoded params and fresh `stripe-mock` runs [VERIFIED: current failures + `test/lattice_stripe/quote_test.exs`; CITED: https://github.com/stripe/stripe-mock]. |
| Binary endpoint accidentally decoded as JSON | Tampering | Keep `Quote.pdf/3` on `Client.download/3` and prove raw binary in both unit and integration tests [VERIFIED: `lib/lattice_stripe/quote.ex` + `test/lattice_stripe/client_test.exs` + SDK probe]. |
| Verifier overclaims beyond what the mock proved | Repudiation | Require explicit scope notes in `36-VERIFICATION.md` that `stripe-mock` proves routing/encoding/decode sanity, not real lifecycle persistence [VERIFIED: phase context + stripe-mock README]. |

## Sources

### Primary (HIGH confidence)

- Internal codebase: `lib/lattice_stripe/quote.ex`, `lib/lattice_stripe/client.ex`, `test/integration/quote_integration_test.exs`, `test/lattice_stripe/quote_test.exs`, `test/support/fixtures/quote.ex`, `test/test_helper.exs`, `test/support/test_helpers.ex`, `mix.exs` [VERIFIED: codebase grep / file read].
- Internal planning artifacts: `.planning/phases/41-quote-lifecycle-e2e-verification/41-CONTEXT.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, `.planning/phases/36-quote/36-VALIDATION.md`, `.planning/phases/39-credit-note-verification-closure/39-VERIFICATION.md`, `.planning/phases/35-mandate-setupattempt/35-VERIFICATION.md`, `.planning/v1.3-v1.3-MILESTONE-AUDIT.md` [VERIFIED: file read / grep].
- Empirical repo-local execution: `mix test test/integration/quote_integration_test.exs --include integration`, SDK quote lifecycle probe, `docker ps`, `mix --version`, `docker --version` [VERIFIED: command output].
- Stripe Quote API reference: https://docs.stripe.com/api/quotes [CITED: official docs].
- Stripe Quote lifecycle overview: https://docs.stripe.com/quotes [CITED: official docs].
- Stripe Quote PDF endpoint: https://docs.stripe.com/api/quotes/pdf [CITED: official docs].
- Stripe testing guidance: https://docs.stripe.com/testing-use-cases [CITED: official docs].
- `stripe-mock` README: https://github.com/stripe/stripe-mock [CITED: official README].

### Secondary (MEDIUM confidence)

- Stripe Ruby development README showing Stripe SDK suites rely on `stripe-mock`: https://github.com/stripe/stripe-ruby [CITED: official repo].

### Tertiary (LOW confidence)

- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - The phase reuses the repo’s existing ExUnit/Finch/`stripe-mock` stack, and the environment plus docs were verified directly [VERIFIED: `mix.exs` + environment audit + official docs].
- Architecture: HIGH - The exact files, test harness, and neighboring closure-document pattern are present in the repo today [VERIFIED: codebase + planning artifacts].
- Pitfalls: HIGH - The two biggest risks were reproduced empirically: stale quote fixture validation failure and non-stateful quote lifecycle responses under current `stripe-mock` [VERIFIED: test run + SDK probe].

**Research date:** 2026-05-25  
**Valid until:** 2026-06-01 [VERIFIED: fast-moving Stripe docs + `stripe-mock:latest` behavior can change quickly].
