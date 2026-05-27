# Phase 48: Thin-Event Adoption Surface — Guide & Integration Verification - Context

**Gathered:** 2026-05-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Ship the adopter-facing surface for the v1.5 thin-event helpers Phase 47 already landed: one canonical Phoenix-friendly guide teaching verify → fetch-after-verify → idempotent dispatch, the chained-helper integration tests that prove the helpers behave end-to-end, the docs-truth regression net that keeps the guide honest against drift, and the discovery wiring that routes evaluators from README/JTBD into the new guide via the existing webhook trust rail.

**Locked deliverables (from REQUIREMENTS.md, both v1.5 REQ-IDs land in this phase):**
- `guides/webhooks-thin-events.md` published as a short canonical Operations & DX sibling to `guides/webhooks.md` (GUIDE-03)
- Integration test coverage at `test/lattice_stripe/webhook/thin_event_test.exs` proving fetch-after-verify roundtrip, malformed-payload failure boundary, and `tolerance: 0` reconciliation at the thin-event helper surface (VERIFY-03)
- Docs-truth regression suite extended in `test/lattice_stripe/docs_truth_test.exs` so the new guide stays enforceable (VERIFY-03)
- Phase 47 deferred WR-04 closure: `Webhook.Plug` `@moduledoc` Configuration Options block surfaces `tolerance: 0` semantics + matching docs-truth grep (carried forward from Phase 47 VERIFICATION.md `deferred` block)

Explicitly out of phase scope (carried forward from Phase 47 D-08 + thread + REQUIREMENTS.md "Out of Scope"):
- A thin-event-aware `LatticeStripe.Webhook.Plug` dispatch mode (Phase 47 D-08 — deferred to v1.5.x or v1.6)
- A `LatticeStripe.Webhook.Handler` callback parallel for thin events (`handle_event_notification/1`)
- Bulk thin-event replay / dead-letter / processor abstractions (Accrue territory)
- v1.5 install-line refresh across README/getting-started/cheatsheet/webhooks.md from `~> 1.3` → `~> 1.5` (separate v1.5 release task; the new guide is the canary)

</domain>

<decisions>
## Implementation Decisions

### Guide shape, depth & ExDoc placement (D-01)
- **D-01:** `guides/webhooks-thin-events.md` is a **short canonical Operations & DX sibling to `guides/webhooks.md`**, ~140–180 lines, lives in the existing `Operations & DX` ExDoc group (`mix.exs:81-95`), placed adjacent to `guides/webhooks.md`. The guide is a *trust rail*, not a Flagship Recipe workflow playbook, and not a Canonical Guide surface-reference walk. Posture: one Phoenix controller spine + one idempotency sketch + footguns inline; assertive, low-magic tone per Phase 45 D-25. Rationale:
  1. Family coherence — thin-event is the v2 branch of the existing webhook trust rail; placing it next to `webhooks.md` preserves the Phase 44 D-06 elevation of webhooks as first-class without splitting into two webhook guides.
  2. Matches Phase 47 D-08's locked decision that `Webhook.Plug` stays unchanged for thin events — adopters wire their own Phoenix controller; the guide teaches one diff vs snapshot (custom controller instead of plug+handler), three helpers, and the new error atom set.
  3. Avoids Accrue scope drift that Flagship Recipe framing (Phase 45 D-01 workflow-playbook posture) naturally pulls toward (worker dispatch, retry policy, dead-letter).
  4. Cross-SDK consistency — stripe-node, stripe-ruby, stripe-go all document thin events as a sibling story to snapshot events, not as a separate workflow playbook.
  5. Length calibration matches Operations & DX siblings (`webhooks.md` is 216 lines; `error-handling.md` is similar order).

  Guide content scope (one canonical spine, no equal-weight alternatives per Phase 45 D-03):
  - Brief snapshot-vs-thin orientation (1 paragraph + the "Webhooks confirm reality" anchor from Phase 44 D-14)
  - Verification-vs-payload-shape failure boundary explained (REQUIREMENTS.md GUIDE-03)
  - Custom Phoenix controller spine using `Webhook.parse_event_notification/4` (raw-body invariant from existing `webhooks.md` carried forward; controller-owned instead of `Webhook.Plug`)
  - Fetch-after-verify worked example via `Webhook.fetch_event/3` and `Webhook.fetch_related_object/3`, including the `{:error, :no_related_object}` snapshot-event branch and the `{:error, {:unknown_object_type, type}}` typed-error footgun
  - Idempotency keyed on `event.id` (NOT on fetched resource state), with a thin idempotency-table sketch
  - Rate-limit guidance — stay <90/s under Stripe's 100 req/s ceiling; acknowledge fetch-after-verify doubles call rate (REQUIREMENTS.md GUIDE-03)
  - Connect/context-aware routing via `event.context` (REQUIREMENTS.md GUIDE-03)
  - One-line note on the stripe-mock `/v2/` gap for adopter testing (use `Testing.generate_thin_event_payload/3` + Mox at the `LatticeStripe.Transport` boundary; reference the project's own test suite as the canonical pattern)
  - Cross-links to `webhooks.md`, `testing.md`, `error-handling.md` (per Phase 44 D-24 aggressive cross-linking)

### Integration test strategy (D-02)
- **D-02:** **Mox-based roundtrip suite at `test/lattice_stripe/webhook/thin_event_test.exs`** (`async: true`, Mox at `LatticeStripe.Transport` behaviour). No new dev dependencies. No `@moduletag :skip` boundary documentation test under `test/integration/` (the existing `test/lattice_stripe/billing/meter_event_stream_integration_test.exs` is the in-repo anti-pattern, not the template — call this out explicitly to the planner). The stripe-mock `/v2/` gap is documented as one line of prose inside `guides/webhooks-thin-events.md` per D-01, NOT as a test artifact. Rationale:
  1. CLAUDE.md "What NOT to Use" table explicitly excludes Bypass; the project's locked priors are "Mox for unit tests, stripe-mock for integration tests." When stripe-mock cannot validate `/v2/` endpoints (it returns `{:error, %Error{type: :invalid_request_error, code: "invalid_v2_key"}}` — confirmed by `test/support/stripe_explorer_harness.ex:157-165`), the spirit of the prior (authoritative external boundary) has no implementation, and falling back to Bypass defeats the original exclusion.
  2. REQUIREMENTS.md VERIFY-03 explicitly states "Tests live under existing `test/lattice_stripe/webhook*` namespace" — NOT `test/integration/`. This is the namespace signal.
  3. Cross-SDK consistency — stripe-node (`nock` at fetch boundary), stripe-go (`httptest` for V2BaseEvent fixtures, no real HTTP for thin events), stripe-java (`MockWebServer` with fixtures, never real `/v2/events`), stripe-python (fixture monkey-patching at the requestor boundary) — every mature Stripe SDK tests thin-event helpers at the client-fetch boundary with fixtures, not via a real HTTP server. Stripity Stripe (Bypass-based) is the ecosystem case study against this approach.
  4. Phase 47 already paid for the Mox-at-Transport infrastructure in `test/lattice_stripe/webhook/fetch_test.exs` (378 lines); the new file extends the same idiom with cross-helper chains rather than introducing a new tier.
  5. Coverage that satisfies VERIFY-03's four must-haves at the helper boundary:
     - Verification happy path: `Testing.generate_thin_event_payload/3` → `Webhook.parse_event_notification/4` → assert typed `%EventNotification{}`
     - Fetch-after-verify roundtrip (Event branch): chained through `Webhook.fetch_event/3` with Mox expecting GET `/v2/core/events/{id}`; assert `%Event{related_object: %RelatedObject{}}` decode
     - Fetch-after-verify roundtrip (RelatedObject branch): chained through `Webhook.fetch_related_object/3` with Mox expecting GET against the verbatim `related_object.url`; assert typed `%Customer{}` via `ObjectTypes` dispatch
     - Malformed-payload failure boundary: bad JSON post-verify, missing-required-field decode behavior, wrong signature `{:error, :no_matching_signature}`, missing header `{:error, :missing_header}` — locks the verification-vs-payload-shape failure boundary the guide teaches (current Phase 47 contract preserved; WR-02 fix-to-typed-error stays deferred)
     - `tolerance: 0` reconciled semantics: signed payload with stale `:timestamp`, `parse_event_notification/4` with `tolerance: 0` returns `{:ok, _}` — extends the WEBFIX-01 regression net (already locked on `construct_event/4` and Plug schema in Phase 47) to the thin-event helper surface

### Docs-truth regression scope (D-03)
- **D-03:** **All recommended sub-decisions adopted (3A + 3B-canary + 3C + 3D + 3E)**, expressed as new tests / extensions to `test/lattice_stripe/docs_truth_test.exs`:

  - **3A (new guide content locks):** A new `test "webhooks-thin-events guide locks the thin-event adopter contract"` block asserts `webhooks-thin-events.md` contains:
    - Function names: `parse_event_notification`, `fetch_event`, `fetch_related_object`
    - Error atoms: `:no_matching_signature`, `:timestamp_expired`, `:no_related_object`, `:unknown_object_type`
    - Rate-limit phrasing: both `100 req/s` and `90/s` substrings (canonical from REQUIREMENTS.md GUIDE-03)
    - `event.id` (idempotency anchor per GUIDE-03)
    - `event.context` (Connect routing anchor per GUIDE-03)
    - `Webhooks confirm` (canonical truth anchor from Phase 44 D-14)
    - `/v2/events` (canonical surface name)
    - A verification-vs-payload-shape phrase (e.g., `verification` and `payload shape` both present, or a fixed canonical phrase chosen at planning)

  - **3B (install-line canary — B2):** The new guide's install snippet says `{:lattice_stripe, "~> 1.5"}`; a new docs-truth assertion locks `~> 1.5` for `webhooks-thin-events.md` ONLY. Existing tests continue to assert `~> 1.3` for README, getting-started, cheatsheet, etc. The new guide is the **canary** — once v1.5 is released, the cross-cutting install-line flip will fail every existing docs-truth assertion until the rest are updated, naturally enforcing lockstep without coupling that flip to Phase 48. Rationale: Phase 44 D-10 "explicit inline honesty at the point of use" — until 1.5.0 is on Hex, only the new 1.5-only guide can honestly claim `~> 1.5`; other guides remain stable on shipped-truth `~> 1.3`.

  - **3C (ExDoc placement lock):** Extend existing test `"exdoc keeps the primary public truth surfaces published"` to assert:
    - `"guides/webhooks-thin-events.md" in extras`
    - `"guides/webhooks-thin-events.md" in groups["Operations & DX"]`

  - **3D (cross-link graph locks):** Extend an existing test (or add a new sibling) to assert:
    - Forward links from the new guide: `webhooks-thin-events.md` contains `webhooks.md`, `testing.md`, `error-handling.md`
    - Reverse link from parent: `webhooks.md` contains `webhooks-thin-events.md` AND a `thin event` orientation phrase (locks the new "Thin events (/v2/events)" closing section in `webhooks.md` per D-04 below)
    - README contains `webhooks-thin-events.md` (locks the hardening-ops sub-link per D-04)
    - `user-flows-and-jtbd.md` contains `webhooks-thin-events.md` (locks the Start Here route + Job 7 `Read next` cluster per D-04)

  - **3E (WR-04 Plug @moduledoc fold-in):** Update `lib/lattice_stripe/webhook/plug.ex:116` `@moduledoc` "Configuration Options" block to extend the `:tolerance` line:
    ```
    - `:tolerance` — Maximum age of the webhook timestamp in seconds (default: 300).
      Set `0` to disable the staleness check (testing only — see the inline comment
      on `LatticeStripe.Webhook.check_tolerance/2` and the v1.5 CHANGELOG WEBFIX-01 entry).
    ```
    Add a new docs-truth grep test analogous to the existing `"CHANGELOG.md documents WEBFIX-01 reconciliation under v1.5"` test: read `plug.ex` source, assert the `@moduledoc` substring contains `tolerance` and `0` and `testing only`. Closes Phase 47 deferred item WR-04 in lockstep with the rest of the docs-truth surface.

### Discovery wiring — README + JTBD (D-04)
- **D-04:** **Sub-bullet under existing hardening-ops route + extend `webhooks.md` + JTBD Job 7 `Read next`** (no new JTBD Job 8, no v1.5 release-status block flip). Concrete edits:

  - **`README.md` "Choose Your Route"** — the existing route `"I am hardening ops and support paths"` line gains `webhooks-thin-events.md` as an additional cross-link alongside `error-handling.md`, `testing.md`, `webhooks.md`.

  - **`README.md` "What's already in the box" → Webhooks bullet** — the existing line "Phoenix-ready `Webhook.Plug` with raw-body capture and signature verification" expands to mention thin-event helpers: e.g., `Phoenix-ready Webhook.Plug snapshot path + thin-event (/v2/events) helpers for fetch-after-verify integration`. Exact wording is planner's discretion as long as it surfaces `thin-event` and `/v2/events`. Do NOT touch the "Release status" block — that's locked at v1.3 until release prep.

  - **`guides/user-flows-and-jtbd.md` "Start Here By Situation" → "Runtime truth, support, and debugging"** route gains `webhooks-thin-events.md` as a sub-link.

  - **`guides/user-flows-and-jtbd.md` Job 7 ("Sleep at night after shipping billing") `Read next`** gains `webhooks-thin-events.md`.

  - **`guides/webhooks.md`** — add a closing "Thin events (`/v2/events`)" section (~6 lines) explaining the snapshot-vs-thin diff and forward-linking to `webhooks-thin-events.md`. The section must contain both the substring `thin event` AND the link `webhooks-thin-events.md` to satisfy the D-03 reverse-link lock. Place AFTER the existing "See also" section so the trust rail's first impression (snapshot quickstart) stays stable.

  - Phase 44 D-08 scope discipline preserved: JTBD remains a compact routing layer, not a peer-rank cookbook. No new Job 8. The thin-event story is an evolution of Job 7 ("Sleep at night") and the hardening-ops route, not a new job in its own right.

### Claude's discretion
- Exact `webhooks-thin-events.md` section ordering, headings, prose framing (as long as D-01 content scope + D-03 phrase locks land).
- Exact wording of the README "What's already in the box" Webhooks bullet expansion (must surface `thin-event` and `/v2/events`).
- The exact idempotency-table sketch shape in the guide (Ecto-style schema sketch? bare map dedup? ETS? planner picks the most adopter-useful sketch within the library-scoped + Phoenix-friendly posture from Phase 45 D-04 + D-27).
- The fixture shapes used by `test/lattice_stripe/webhook/thin_event_test.exs` (reuse `test/support/fixtures/event_notification.ex` from Phase 47 plan 47-01 wherever possible; new fixtures only if a roundtrip case needs them).
- Planner's choice on a few small extras for the docs-truth tests (e.g., grouping the new guide-content asserts under one `describe` block vs distributing across existing tests).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project planning & roadmap
- `.planning/PROJECT.md` — milestone shape, design philosophy, "verify shipped surface against `lib/` source" decision
- `.planning/ROADMAP.md` §"Phase 48" — locked goal + 5 success criteria
- `.planning/REQUIREMENTS.md` — 2 v1.5 REQ-IDs landing in this phase (GUIDE-03, VERIFY-03)
- `.planning/STATE.md` — current position (Phase 48 awaiting plan)
- `.planning/RETROSPECTIVE.md` — v1.4 lesson: REQUIREMENTS.md traceability lagged completion; keep checkbox state in lockstep with SUMMARY frontmatter

### Phase 47 (immediate predecessor — all 8 decisions are pre-answered)
- `.planning/phases/47-thin-event-sdk-surface-webhook-reconciliation/47-CONTEXT.md` — D-01..D-08 lock the helper surface this phase is documenting + testing
- `.planning/phases/47-thin-event-sdk-surface-webhook-reconciliation/47-VERIFICATION.md` — 6/6 must-haves verified; deferred WR-04 explicitly labeled "addressed in Phase 48"
- `.planning/phases/47-thin-event-sdk-surface-webhook-reconciliation/47-REVIEW.md` §WR-04 (lines 136-153) — exact `plug.ex:116` fix per D-03 sub-decision 3E

### v1.4 archived phases that lock the docs architecture this phase extends
- `.planning/milestones/v1.4-phases/44-guide-discovery-support-truth/44-CONTEXT.md` — Phase 44 D-01..D-18 lock layered ExDoc grouping, surface-first canonical + task-first routing, inline truth at action point, "webhooks confirm reality" anchor
- `.planning/milestones/v1.4-phases/45-flagship-recipes-i/45-CONTEXT.md` — Phase 45 D-01..D-27 lock workflow-playbook scale, one-recommended-path, library-scoped, footguns-inline tone (D-01 explicitly REJECTS this scale for thin-events; carry forward Phase 45's tone discipline but NOT its scale)
- `.planning/milestones/v1.4-phases/44-guide-discovery-support-truth/44-02-PLAN.md` + SUMMARY — VERIFY-02 docs-truth extension pattern this phase mirrors for VERIFY-03

### v1.5 thread context (locked-in shape)
- `.planning/threads/thin-event-webhook-evaluation.md` — locked-in v1.5 surface, idempotency-on-event.id directive, rate-limit guidance (<90/s under 100 req/s)
- `.planning/threads/v1-5-next-milestone-assessment.md` §"Wedge A — Thin-Event Webhook Support (SELECTED for v1.5)" — canonical docs scope: "guides/webhooks-thin-events.md with Phoenix handler, fetch-after-verify idempotency, rate-limit guidance (keep delivery <90/s to stay under Stripe's 100 req/s ceiling), Connect/context-aware events"

### Source files this phase modifies
- `lib/lattice_stripe/webhook/plug.ex:116` — extend `@moduledoc` Configuration Options block per D-03 sub-decision 3E (WR-04 closure)
- `guides/webhooks.md` — add closing "Thin events (`/v2/events`)" section per D-04 (reverse-link to new guide; ~6 lines)
- `README.md` — extend "I am hardening ops and support paths" route + "What's already in the box" Webhooks bullet per D-04 (do NOT touch v1.3 Release status block)
- `guides/user-flows-and-jtbd.md` — extend "Runtime truth, support, and debugging" Start Here route + Job 7 `Read next` per D-04
- `test/lattice_stripe/docs_truth_test.exs` — extend per D-03 (new test block for the new guide; extend existing ExDoc placement test; extend or add cross-link assertion tests; new Plug @moduledoc grep test for 3E)
- `mix.exs:81-95` — add `"guides/webhooks-thin-events.md"` to the `Operations & DX` group in `groups_for_extras` AND to the top-level `extras:` list

### Source files this phase creates
- `guides/webhooks-thin-events.md` — new canonical Operations & DX sibling per D-01 (~140–180 lines)
- `test/lattice_stripe/webhook/thin_event_test.exs` — new Mox-based roundtrip suite per D-02 (`async: true`, `import Mox`, `setup :verify_on_exit!`, mirrors the idiom in `test/lattice_stripe/webhook/fetch_test.exs`)

### Existing helper surface (Phase 47, do NOT re-implement)
- `lib/lattice_stripe/webhook.ex` — `parse_event_notification/4`, `fetch_event/3`, `fetch_related_object/3`, all bang variants, `check_tolerance/2` `tolerance: 0` clause, inline comment recording WEBFIX-01 decision
- `lib/lattice_stripe/event_notification.ex` + `event_notification/related_object.ex` — `%EventNotification{}`, `%EventNotification.RelatedObject{}`, both `from_map/1` impls
- `lib/lattice_stripe/event.ex` — `Event.t()` with `related_object` field shared from `EventNotification.RelatedObject.t()`
- `lib/lattice_stripe/object_types.ex` — `fetch_module/1` typed-gate (used internally by `fetch_related_object/3`)
- `lib/lattice_stripe/testing.ex` — `generate_thin_event_payload/3`, `event_notification/1`
- `test/lattice_stripe/webhook/fetch_test.exs` — unit-level Mox coverage; reference idiom for the new `thin_event_test.exs`
- `test/lattice_stripe/webhook_test.exs` — `describe "parse_event_notification/4"` blocks (lines 301+); reference idiom for the verify-side of the chained roundtrip
- `test/lattice_stripe/testing_test.exs` — `describe "generate_thin_event_payload/3"` block (line 119+) + end-to-end roundtrip; reference idiom for the chained generate→parse case
- `test/support/fixtures/event_notification.ex` — `event_notification_map/0`, `event_notification_map_no_related_object/0`; reuse fixtures

### Deep-research baseline (prompts/, informed D-01..D-04)
- `prompts/elixir-best-practices-deep-research.md` — assertive matching over defensive ambiguity (informed D-02 fail-fast + D-01 typed-error guide phrasing)
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — minimal-dep + behaviour-boundary mocks (informed D-02 reject-Bypass)
- `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md` — docs-truth + CI regression patterns (informed D-03)
- `prompts/phoenix-best-practices-deep-research.md` — thin web-layer, controller-owned dispatch (informed D-01 controller-spine framing)
- `prompts/stripe-sdk-api-surface-area-deep-research.md` — cross-SDK reference patterns (informed D-01 family-coherence + D-02 cross-SDK Mox-at-Transport idiom)
- `prompts/comprehensive-master-reference-document-stripe-sdk-reference-deep-research.md` — Stripe SDK reference doctrine (informed D-01)
- `prompts/stripe-lib-priority-user-flows-deep-research.md` — adopter user flows (informed D-04 hardening-ops route placement)
- `prompts/stripe-explanation-domain-language-deep-research.md` — thin event vs snapshot event domain language (informed D-01 guide framing)
- `prompts/The definitive Stripe library gap in Elixir - a master research document.md` — overarching vision

### External Stripe references (for planner research-phase, not pre-read)
- Stripe docs: `https://docs.stripe.com/event-destinations` (thin events overview)
- Stripe docs: `https://docs.stripe.com/api/v2/events` (thin-event payload shape, `related_object` field set)
- Stripe rate-limit ceiling docs: 100 req/s steady-state ceiling (cite explicitly in the guide for the <90/s guidance)
- stripe-node v49+ `parseEventNotification` reference shape
- Cross-SDK thin-event docs (stripe-node, stripe-go, stripe-ruby, stripe-java, stripe-python) — confirm sibling-not-recipe documentation framing

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test/lattice_stripe/webhook/fetch_test.exs` (378 lines) — direct idiom template for `test/lattice_stripe/webhook/thin_event_test.exs`: same `import Mox`, `setup :verify_on_exit!`, `LatticeStripe.MockTransport` per-test `expect`, `test_client/0` helper, Mox-verified zero-HTTP for typed-error paths. New file extends the idiom with chained generate→parse→fetch flows.
- `test/lattice_stripe/testing_test.exs` `describe "generate_thin_event_payload/3"` (line 119+) — the load-bearing cross-plan roundtrip from Phase 47 already exists; new test file builds on that pattern for the additional fetch-after-verify chain coverage.
- `test/support/fixtures/event_notification.ex` — `event_notification_map/0`, `event_notification_map_no_related_object/0`; reuse for malformed-payload and roundtrip cases.
- `test/support/fixtures/event.ex`, `test/support/fixtures/customer.ex` — fixture helpers for fetched-resource assertions.
- `test/support/test_helpers.ex` — `test_client/0`, `ok_response/1` helpers used by the existing `fetch_test.exs` pattern.
- `guides/webhooks.md` (216 lines) — canonical sibling structure: raw-body invariant → quickstart Plug pattern → handler example → local testing → advanced alternative → troubleshooting → "See also". Mirror this section ordering (adjusted for controller-owned dispatch instead of Plug-driven) in `webhooks-thin-events.md`.
- `guides/webhooks.md` "See also" section — append `webhooks-thin-events.md` as a forward link AND add the new "Thin events (`/v2/events`)" closing section per D-04.
- `guides/testing.md`, `guides/error-handling.md` — pre-existing cross-link targets per D-03 sub-decision 3D + Phase 44 D-24.
- `mix.exs:54-96` `groups_for_extras` — extend `Operations & DX` group with the new guide path.
- `test/lattice_stripe/docs_truth_test.exs` (186 lines, 8 tests including the Phase 47 WEBFIX-01 grep) — extend in lockstep with the new guide; reference pattern for the WR-04 Plug @moduledoc grep test is the existing `"CHANGELOG.md documents WEBFIX-01 reconciliation under v1.5"` test at lines 175-186.

### Established Patterns
- **Docs-truth = single test module, `async: true`** — Phase 44 D-04 ladder is encoded as grep assertions per guide/file; new locks slot in cleanly as additional `test "..."` blocks or `assert` lines in existing tests. No new test infrastructure needed.
- **`@tag :integration` semantics in this repo** — means "stripe-mock real HTTP via `:gen_tcp.connect(~c"localhost", 12_111, ...)` precondition." NEW thin-event tests do NOT tag `:integration` — they're `async: true` Mox-at-Transport per D-02. Naming chosen to avoid the collision: `thin_event_test.exs` not `thin_event_integration_test.exs`.
- **`Webhook.Plug` snapshot mode unchanged** (Phase 47 D-08) — the new guide does NOT teach mounting `Webhook.Plug` for thin events; it teaches a custom Phoenix controller that calls `parse_event_notification/4` directly. This is the locked Phase 47 architecture.
- **Library-scoped Phoenix examples** (Phase 45 D-04, D-27) — controller examples in the new guide stay thin (controller action + `parse_event_notification/4` call + handler dispatch). No worker-queue patterns, no entitlement-state machines, no dunning policy. The idempotency sketch is a thin dedup primitive (e.g., a tiny processed_events table + Ecto-style sketch) — adopters bring their own persistence layer.
- **Verify-then-decode invariant** (Phase 47 D-07) — the guide explicitly teaches this: signature check FIRST (which is why `:no_matching_signature` / `:timestamp_expired` / `:missing_header` / `:invalid_header` are the 4 atoms returned BEFORE any JSON decode; bad JSON post-verify raises today per Phase 47 — the guide must teach this current contract honestly).
- **`Inspect` impl on `RelatedObject`** (Phase 47 plan 47-01 + REVIEW WR-05) — does show `:extra` when non-empty. New guide should NOT teach `IO.inspect(notification)` as a debug pattern without acknowledging the `:extra` surface; the example dispatch shows pattern-matching against typed fields, not inspect-driven debugging.

### Integration Points
- **Phase 47 surface contract** — every helper in `Webhook` that the new guide teaches already has its locked signature, typed-error set, and bang variant. Phase 48 does NOT touch helper signatures; it only documents and tests at the helper boundary.
- **CHANGELOG `[Unreleased] → [1.5.0]` section** (Phase 47-shipped) — Phase 48 appends one bullet to the existing v1.5 entry for the new guide + integration test surface. Example bullet shape (planner can adjust): "GUIDE-03: published `guides/webhooks-thin-events.md` with the canonical Phoenix thin-event adopter pattern. VERIFY-03: added `test/lattice_stripe/webhook/thin_event_test.exs` covering fetch-after-verify roundtrip, malformed-payload failure boundary, and `tolerance: 0` reconciliation; extended `docs_truth_test.exs` to lock the new guide and the `Webhook.Plug` `@moduledoc` `tolerance: 0` mention (closing Phase 47 WR-04)."
- **No new helper surface introduced.** Phase 48 is documentation + tests + a one-line `Webhook.Plug` `@moduledoc` extension. Zero `lib/` API additions beyond the docstring edit.
- **JTBD ladder preserved** — Phase 44 D-06 elevated webhooks/testing/error-handling/metering/Connect/portal as first-class follow-through surfaces; Phase 48 D-04 extends this by adding `webhooks-thin-events.md` as a v2 branch of the webhook trust rail, NOT as a new peer-rank surface.

</code_context>

<specifics>
## Specific Ideas

- **Canonical adopter pattern in the new guide** (mirroring Phase 47 specifics block):
  ```elixir
  # lib/my_app_web/controllers/stripe_thin_event_controller.ex
  defmodule MyAppWeb.StripeThinEventController do
    use MyAppWeb, :controller

    alias LatticeStripe.{EventNotification, Webhook}
    alias LatticeStripe.EventNotification.RelatedObject

    @secret System.fetch_env!("STRIPE_THIN_EVENT_SECRET")

    def receive(conn, _params) do
      raw_body = conn.assigns.raw_body
      sig_header = get_req_header(conn, "stripe-signature") |> List.first()

      with {:ok, %EventNotification{} = notif} <-
             Webhook.parse_event_notification(raw_body, sig_header, @secret),
           :ok <- maybe_dispatch(MyApp.Stripe.client(), notif) do
        send_resp(conn, 200, "")
      else
        {:error, :no_matching_signature} -> send_resp(conn, 400, "bad signature")
        {:error, :timestamp_expired} -> send_resp(conn, 400, "stale")
        {:error, :missing_header} -> send_resp(conn, 400, "missing header")
        {:error, :invalid_header} -> send_resp(conn, 400, "invalid header")
      end
    end

    # idempotency keyed on event.id (NOT on fetched resource state)
    defp maybe_dispatch(client, %EventNotification{id: id} = notif) do
      case MyApp.Stripe.IdempotentEvents.claim(id) do
        :ok -> dispatch(client, notif)
        :already_processed -> :ok
      end
    end

    defp dispatch(client, %EventNotification{
           related_object: %RelatedObject{type: "customer"}
         } = notif) do
      {:ok, customer} = Webhook.fetch_related_object(client, notif)
      MyApp.Workers.SyncCustomer.enqueue(customer)
      :ok
    end

    defp dispatch(client, %EventNotification{related_object: nil} = notif) do
      {:ok, event} = Webhook.fetch_event(client, notif)
      MyApp.Workers.LogSnapshotEvent.enqueue(event)
      :ok
    end

    defp dispatch(_client, _notif), do: :ok
  end
  ```
  This is the canonical adopter shape; the guide makes this the recommended path (Phase 45 D-03 "one recommended path"). Raw-body preservation note routes back to `webhooks.md` rather than re-explaining (cross-link discipline).

- **stripe-mock `/v2/` gap one-liner in the guide** (suggested phrasing for the "Testing" section):
  > Stripe's open-source `stripe-mock` server does not currently validate `/v2/` endpoints. Test your thin-event handler with `LatticeStripe.Testing.generate_thin_event_payload/3` plus `Mox` at the `LatticeStripe.Transport` behaviour boundary — see LatticeStripe's own `test/lattice_stripe/webhook/thin_event_test.exs` for the reference pattern.

- **Reverse-link section in `webhooks.md`** (~6 lines suggested shape, planner discretion):
  ```markdown
  ## Thin events (`/v2/events`)

  Stripe also delivers **thin events** to `/v2/event-destinations` endpoints.
  A thin event payload carries only `{id, type, related_object}` — your app
  fetches authoritative state after verification. See
  [Webhooks: Thin Events](webhooks-thin-events.md) for the canonical Phoenix
  pattern, fetch-after-verify idempotency, and rate-limit guidance.
  ```

- **README "What's already in the box" Webhooks bullet expansion suggestion:**
  > Phoenix-ready `Webhook.Plug` snapshot path + thin-event (`/v2/events`) helpers for fetch-after-verify integration

- **Test file outline (`test/lattice_stripe/webhook/thin_event_test.exs`):**
  ```elixir
  defmodule LatticeStripe.Webhook.ThinEventTest do
    use ExUnit.Case, async: true
    import Mox
    import LatticeStripe.TestHelpers
    import LatticeStripe.Test.Fixtures.EventNotification

    alias LatticeStripe.{Customer, Event, EventNotification, Testing, Webhook}
    alias LatticeStripe.EventNotification.RelatedObject

    setup :verify_on_exit!

    @secret "whsec_test_secret"

    describe "verify happy path" do
      # generate → parse → assert typed %EventNotification{}
    end

    describe "fetch-after-verify roundtrip — Event branch" do
      # generate → parse → fetch_event/3 (Mox GET /v2/core/events/{id}) → %Event{}
    end

    describe "fetch-after-verify roundtrip — RelatedObject branch" do
      # generate (with related_object) → parse → fetch_related_object/3 (Mox GET url verbatim) → %Customer{}
    end

    describe "malformed-payload failure boundary" do
      # bad JSON post-verify; wrong sig; missing header; missing required field
    end

    describe "tolerance: 0 reconciled semantics on the thin-event surface" do
      # signed payload with stale timestamp; parse_event_notification/4 with tolerance: 0; {:ok, _}
    end
  end
  ```

</specifics>

<deferred>
## Deferred Ideas

- **v1.5 install-line refresh across README/getting-started/cheatsheet/webhooks.md** — flip `~> 1.3` → `~> 1.5` is a release-prep task, not Phase 48 scope. The new guide is the canary that fails CI when the rest aren't flipped (Sub-decision 3B = B2).
- **Updating `README.md` "Release status" block from v1.3 to v1.5** — release prep, not Phase 48 scope. Phase 48 explicitly leaves the v1.3 status block alone.
- **A `LatticeStripe.Webhook.Handler` callback parallel for thin events** (`handle_event_notification/1` or `handle_event/1` overload) — Phase 47 D-08 deferred; needs its own discuss-phase once mixed-mode Plug-dispatch design is resolved. Hold until v1.5.x patch or v1.6.
- **A thin-event-aware `LatticeStripe.Webhook.Plug` dispatch mode** — Phase 47 D-08 deferred. Real design problem (path-based? content-shape-based? handler-attribute-based?); deserves its own discuss-phase. Hold until v1.5.x patch or v1.6.
- **WR-02 (Phase 47 REVIEW): typed-error replacement for `Jason.decode!` raise on malformed JSON post-verify** — not in Phase 48 scope; the current Phase 47 contract (raise on bad JSON) is what Phase 48 documents honestly. Reconsider as a v1.5.x or v1.6 helper-API change with its own discuss-phase.
- **WR-03 (Phase 47 REVIEW): `Testing.generate_webhook_payload/3` `:timestamp` opt should drive `created` like the thin-event helper does** — symmetric cross-helper fix; not Phase 48 docs+tests scope. Capture for v1.5.x cleanup.
- **WR-05 (Phase 47 REVIEW): `RelatedObject` Inspect impl shows `:extra` when non-empty** — credential-leak hardening; not Phase 48 docs+tests scope. Capture for v1.5.x cleanup. Guide should NOT teach `IO.inspect(notification)` as a debug pattern to avoid amplifying this surface.
- **Bypass-based real-HTTP integration tests for `/v2/core/events/{id}` roundtrip** — D-02 explicitly rejects this; if a future adopter need surfaces (e.g., Finch pipeline regression discovered in the wild), reconsider with its own discuss-phase. The cross-SDK ecosystem evidence (every mature Stripe SDK tests thin events at the client-fetch boundary with fixtures, never via a real HTTP server) is strong against revisiting.
- **A `@moduletag :integration` boundary-doc test asserting `:invalid_v2_key` against stripe-mock for `/v2/core/events/{id}`** — D-02 explicitly rejects this (the existing `test/lattice_stripe/billing/meter_event_stream_integration_test.exs` is the in-repo anti-pattern, not the template). The stripe-mock gap is documented in prose in `guides/webhooks-thin-events.md` instead.
- **A new JTBD Job 8 "Modernize to thin-event webhooks"** — D-04 explicitly rejects elevating thin events to peer rank with Jobs 1-7; revisit only if real adopter pull (Hex download stats, GitHub issues, Slack mentions) emerges showing thin events are a top-of-funnel adopter concern.
- **Live event tail LiveBook (`notebooks/event_inspector.livemd`)** — v1.7 polish milestone candidate per `.planning/threads/v1-5-next-milestone-assessment.md`. Not v1.5 scope.

</deferred>

---

*Phase: 48-thin-event-adoption-surface-guide-integration-verification*
*Context gathered: 2026-05-27*
