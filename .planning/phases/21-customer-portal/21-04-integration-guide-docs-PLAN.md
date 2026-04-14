---
phase: 21-customer-portal
plan: 04
type: execute
wave: 3
depends_on:
  - 21-03
files_modified:
  - test/integration/billing_portal_session_integration_test.exs
  - guides/customer-portal.md
  - guides/subscriptions.md
  - guides/webhooks.md
  - mix.exs
autonomous: true
requirements:
  - PORTAL-01
  - TEST-05
  - DOCS-02
  - DOCS-03
must_haves:
  truths:
    - "Integration test against stripe-mock creates a portal session and asserts %Session{url: url} with non-empty string"
    - "guides/customer-portal.md exists at ~240 lines with 7 H2 sections per D-04 envelope"
    - "mix.exs groups_for_modules gains 'Customer Portal' group with 6 modules (Session + FlowData + 4 sub-structs)"
    - "mix.exs extras list includes guides/customer-portal.md"
    - "guides/subscriptions.md and guides/webhooks.md have reciprocal See also cross-links to customer-portal.md"
    - "mix docs --warnings-as-errors is clean"
  artifacts:
    - path: "test/integration/billing_portal_session_integration_test.exs"
      provides: "Full :integration-tagged portal flow test against stripe-mock"
    - path: "guides/customer-portal.md"
      provides: "MODERATE-envelope guide (240 lines ± 40, 7 H2)"
      min_lines: 200
    - path: "mix.exs"
      provides: "ExDoc 'Customer Portal' group registration"
      contains: "Customer Portal"
  key_links:
    - from: "mix.exs groups_for_modules"
      to: "lib/lattice_stripe/billing_portal/session.ex and session/flow_data*.ex"
      via: "Customer Portal group entry listing 6 modules"
      pattern: "Customer Portal"
    - from: "guides/subscriptions.md"
      to: "guides/customer-portal.md"
      via: "See also link in §Lifecycle operations and §Proration"
      pattern: "customer-portal.md"
---

<objective>
Close Phase 21 with three parallel concerns that all depend on plan 21-03's resource module: (1) the `:integration`-tagged portal flow test against stripe-mock (PORTAL-01, TEST-05 portal portion), (2) the MODERATE-envelope `guides/customer-portal.md` guide (DOCS-02, 240 lines ± 40, 7 H2 per D-04), and (3) `mix.exs` extras + groups_for_modules registration (DOCS-03 Customer Portal group) plus reciprocal cross-links from `subscriptions.md` and `webhooks.md`.

Purpose: Ship PORTAL-01's integration proof, the user-facing guide Accrue needs for CHKT-02, and the ExDoc registration that surfaces the 6 new modules under a discoverable group. This is the LAST plan before the zero-touch release-please auto-ship of v1.1.0 — the final `feat:` commit of this plan triggers the release workflow.
Output: 1 integration test file fleshed out, 1 new guide, 3 edited guide/config files.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/21-customer-portal/21-CONTEXT.md
@.planning/phases/21-customer-portal/21-RESEARCH.md
@.planning/v1.1-accrue-context.md
@test/integration/checkout_session_integration_test.exs
@test/integration/billing_portal_session_integration_test.exs
@test/support/fixtures/billing_portal.ex
@lib/lattice_stripe/billing_portal/session.ex
@guides/checkout.md
@guides/subscriptions.md
@guides/webhooks.md
@guides/metering.md
@mix.exs
</context>

<tasks>

<task type="auto">
  <name>Task 1: Flesh out integration test against stripe-mock</name>
  <files>test/integration/billing_portal_session_integration_test.exs</files>
  <action>
Take the Wave 0 skeleton created in plan 21-01 and replace the `@tag :skip` stub with real `:integration`-tagged tests. Use `test_integration_client()` from `test/support/test_helpers.ex` (already wired). Pattern reference: `test/integration/checkout_session_integration_test.exs`.

Tests to implement (all require docker stripe-mock running on localhost:12111):

1. `test "create/3 with customer returns {:ok, %Session{url: url}} with non-empty url"` — happy path closes PORTAL-01 + TEST-05 (portal). Assert `url` is a binary and `String.length(url) > 0` and matches `~r{^https://}`.

2. `test "create/3 populates all 11 PORTAL-05 response fields from stripe-mock"` — assert `session.id =~ ~r/^bps_/`, `session.object == "billing_portal.session"`, `session.customer == "cus_test"`, etc. Note per RESEARCH Finding 5: stripe-mock always returns all four flow branch keys populated regardless of input.

3. `test "create/3 decodes flow echo into %FlowData{}"` — pass `flow_data: %{"type" => "subscription_cancel", "subscription_cancel" => %{"subscription" => "sub_test"}}` and assert `%LatticeStripe.BillingPortal.Session.FlowData{} = session.flow`.

4. `test "create/3 with stripe_account: opt threads header through"` — PORTAL-06 integration check. Pass `opts: [stripe_account: "acct_test"]`; just assert no error (stripe-mock accepts any acct_*).

5. `test "create!/3 bang variant returns unwrapped %Session{}"` — happy path.

NOT covered (intentional, documented with a comment at top of file): PORTAL-04 guard matrix — stripe-mock does NOT enforce sub-field validation (RESEARCH Finding 1); guards live in guards_test.exs. Also document that Finding 2 (unknown flow type 422) IS testable here but already covered in unit tests.

Use a `setup` block that builds the test customer via `LatticeStripe.Customer.create/3` with `%{"email" => "portal_integration@example.com"}` and passes the returned `cus_*` ID. (Existing integration tests do this — mirror pattern.)
  </action>
  <verify>
    <automated>cd /Users/jon/projects/lattice_stripe && docker ps --format '{{.Names}}' | grep -q stripe-mock && mix test test/integration/billing_portal_session_integration_test.exs --include integration</automated>
  </verify>
  <done>5 integration tests green; `url` field verified non-empty and HTTPS-shaped; closes PORTAL-01 + TEST-05 (portal portion).</done>
</task>

<task type="auto">
  <name>Task 2: Write guides/customer-portal.md</name>
  <files>guides/customer-portal.md</files>
  <action>
Create `guides/customer-portal.md` with the D-04-locked envelope: **240 lines ± 40, 7 H2 sections**. Use `guides/checkout.md` as the tonal/structural template. Match the binding H2 outline from CONTEXT.md D-04 verbatim:

1. **`## What the Customer Portal is`** (~15 lines) — intro, 4 flow-type bullet summary, one-sentence framing.
2. **`## Quickstart`** (~25 lines) — minimal `Session.create/3` call with `customer` + `return_url`, redirect the url, note that no `flow_data` = portal homepage.
3. **`## Deep-link flows`** — intro paragraph linking to `LatticeStripe.BillingPortal.Session.FlowData` moduledoc, then 4 H3 subsections:
   - `### Updating a payment method` (~15 lines)
   - `### Canceling a subscription` (~20 lines) — cross-link to `[Subscriptions — Lifecycle operations](subscriptions.md)`
   - `### Updating a subscription` (~20 lines) — cross-link to `subscriptions.md` §Proration
   - `### Confirming a subscription update` (~20 lines)
4. **`## End-to-end Phoenix example`** (~50 lines) — Accrue-style 5-line wrapper `def portal_url(user, return_to)` returning `{:ok, url}`, then `BillingController.portal/2` with `redirect(conn, external: session.url)`, plus return handler re-rendering account page. Literally satisfies DOCS-02 "Accrue-style usage example".
5. **`## Security and session lifetime`** (~35 lines) — **OWNS THE D-03 TEACHING**. Must cover:
   - `session.url` is single-use, ~5 min TTL
   - Never log or persist the url — bearer credential
   - LatticeStripe masks `:url` in `Inspect` output by default; show before/after `IO.inspect(session)` output demonstrating `url` absent
   - Document the `IO.inspect(session, structs: false)` escape hatch
   - `return_url` should be HTTPS route you control
   - On customer return, re-verify server-side — portal redirect is NOT authentication, use webhooks for state-change confirmation
6. **`## Common pitfalls`** (~25 lines) — checkout.md-style bold-lede bullets; surface the D-01 guard messages (customer required; return_url HTTPS; flow_data.type mismatch; don't cache session.url; changes fire webhooks not return-URL payloads).
7. **`## See also`** — cross-links to `[Subscriptions](subscriptions.md)`, `[Webhooks](webhooks.md)`, `[Checkout](checkout.md)`, and `` `LatticeStripe.BillingPortal.Session` ``.

All code samples must compile against the real `LatticeStripe.BillingPortal.Session.create/3` API from plan 21-03 (string-keyed params, NOT atom-keyed — Phase 20 D-06). Verify the `mix docs` ExDoc cross-references resolve by running `mix docs --warnings-as-errors` at the end of the task.

The guide MUST reference the `Inspect` masking behavior with an actual code example showing what `inspect(session)` renders — this is the behavior users cannot discover from the moduledoc alone.
  </action>
  <verify>
    <automated>cd /Users/jon/projects/lattice_stripe && test -f guides/customer-portal.md && awk 'END { if (NR < 200 || NR > 280) exit 1 }' guides/customer-portal.md && grep -cE '^## ' guides/customer-portal.md | awk '$1 != 7 { exit 1 }'</automated>
  </verify>
  <done>guide exists at 200-280 lines, exactly 7 H2 sections, all 4 flow types covered, Security section present with Inspect masking teaching + escape hatch, Phoenix controller example compiles, cross-links present.</done>
</task>

<task type="auto">
  <name>Task 3: mix.exs ExDoc registration + reciprocal cross-links</name>
  <files>mix.exs, guides/subscriptions.md, guides/webhooks.md</files>
  <action>
**mix.exs edits (DOCS-03 Customer Portal group):**

1. Add `"guides/customer-portal.md"` to the `extras:` list alphabetically near `"guides/connect-money-movement.md"`. Verify the existing `guides/*.{md,cheatmd}` wildcard in `groups_for_extras` picks it up automatically (no edit needed there — just confirm via `mix docs`).

2. Add `"Customer Portal"` group to `groups_for_modules` listing exactly 6 modules:
   - `LatticeStripe.BillingPortal.Session`
   - `LatticeStripe.BillingPortal.Session.FlowData`
   - `LatticeStripe.BillingPortal.Session.FlowData.AfterCompletion`
   - `LatticeStripe.BillingPortal.Session.FlowData.SubscriptionCancel`
   - `LatticeStripe.BillingPortal.Session.FlowData.SubscriptionUpdate`
   - `LatticeStripe.BillingPortal.Session.FlowData.SubscriptionUpdateConfirm`

   Do NOT include `LatticeStripe.BillingPortal.Guards` — it has `@moduledoc false` and belongs with `LatticeStripe.Billing.Guards` in the `Internals` group (per RESEARCH Pitfall 5). Mirror shape of existing `"Billing Metering"` group if present.

**guides/subscriptions.md edits (reciprocal cross-links per D-04):**

1. In `§Lifecycle operations`, add a See also bullet: `- [Customer Portal — Canceling a subscription](customer-portal.html#canceling-a-subscription) — let customers self-serve via Stripe's hosted portal.`
2. In `§Proration`, add a See also bullet: `- [Customer Portal — Updating a subscription](customer-portal.html#updating-a-subscription) — portal-hosted proration preview.`

**guides/webhooks.md edits:**

1. Add a pointer (in the most relevant section — likely "When to use webhooks" or the top-level intro) explaining that Customer Portal flows dispatch state changes via webhooks, NOT return-URL payloads. Link to `[Customer Portal — Security and session lifetime](customer-portal.html#security-and-session-lifetime)`.
  </action>
  <verify>
    <automated>cd /Users/jon/projects/lattice_stripe && mix docs --warnings-as-errors 2>&1 | tail -20 && grep -q "Customer Portal" mix.exs && grep -q "customer-portal" guides/subscriptions.md && grep -q "customer-portal" guides/webhooks.md</automated>
  </verify>
  <done>`mix docs --warnings-as-errors` clean; Customer Portal group visible in generated HTML; 6 modules listed; reciprocal cross-links present in subscriptions.md and webhooks.md.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Guide code examples → copy-paste user code | Users copy code from the guide verbatim; examples must use secure defaults (HTTPS return_url, no logging of session.url) |
| Integration test → stripe-mock | Local trusted loopback; real customer creation via test client |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-21-11 | Information Disclosure | guide code example that logs `session.url` during redirect flow | mitigate | Guide §Security explicitly demonstrates `IO.inspect(session)` masking the url and teaches the escape hatch. Phoenix example uses `redirect(conn, external: session.url)` directly without an intermediate log line. |
| T-21-12 | Information Disclosure | guide code example with `http://` return_url | mitigate | §Security and §Common pitfalls both explicitly require HTTPS return_url; pitfall bullet "return_url must be absolute HTTPS" reinforces. |
| T-21-13 | Spoofing | guide examples that treat portal redirect as authentication | mitigate | §Security explicitly states "portal redirect is NOT authentication — use webhooks for state-change confirmation"; §Common pitfalls reinforces with the "webhooks, not return-URL payloads" bullet; webhooks.md reciprocal cross-link closes the loop. |
</threat_model>

<verification>
- `mix docs --warnings-as-errors` clean — registers the new guide and group
- `mix test --include integration test/integration/billing_portal_session_integration_test.exs` — 5 tests green against stripe-mock
- `mix credo --strict` clean across modified files
- Manual review: guide word count in envelope; 7 H2 sections present; all 4 flow types covered; Security section teaches Inspect masking with real output example
- Reciprocal cross-links present in subscriptions.md and webhooks.md
</verification>

<success_criteria>
1. Integration test proves `Session.create/3` returns `%Session{url: non_empty_binary}` against stripe-mock.
2. `guides/customer-portal.md` exists with 7 H2, ~240 lines, all 4 flow types, Accrue-style Phoenix example, security teaching with Inspect masking escape hatch.
3. `mix.exs` has `"Customer Portal"` group with 6 modules + guide in `extras`.
4. `guides/subscriptions.md` and `guides/webhooks.md` have reciprocal See also links.
5. `mix docs --warnings-as-errors` clean.
6. Final `feat:` commit of this task triggers release-please auto-ship of v1.1.0 (zero-touch per v1.1-accrue-context.md).
</success_criteria>

<output>
After completion, create `.planning/phases/21-customer-portal/21-04-integration-guide-docs-SUMMARY.md`.
</output>
