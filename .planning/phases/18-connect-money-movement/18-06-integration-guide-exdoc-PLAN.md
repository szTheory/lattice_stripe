---
phase: 18
plan: 06
type: execute
wave: 4
depends_on: [18-01, 18-02, 18-03, 18-04, 18-05]
files_modified:
  - test/integration/external_account_integration_test.exs
  - test/integration/transfer_integration_test.exs
  - test/integration/transfer_reversal_integration_test.exs
  - test/integration/payout_integration_test.exs
  - test/integration/balance_integration_test.exs
  - test/integration/balance_transaction_integration_test.exs
  - test/integration/charge_integration_test.exs
  - guides/connect.md
  - mix.exs
autonomous: true
requirements: [CNCT-02, CNCT-03, CNCT-04, CNCT-05]
tags: [connect, integration, stripe-mock, guide, exdoc, reconciliation]

must_haves:
  truths:
    - "Every Phase 18 resource has a stripe-mock integration test covering the canonical happy path"
    - "guides/connect.md money-movement section is appended to Phase 17's onboarding half and covers all 8 D-07 subsections"
    - "Every money-movement narrative transition in the guide ends with a webhook-handoff callout (charge.succeeded, application_fee.created, payout.paid, transfer.reversed)"
    - "Reconciliation guide section presents BOTH idioms side-by-side: per-object expand and per-payout BalanceTransaction.list"
    - "ExDoc 'Connect' module group includes all new Phase 18 modules; LatticeStripe.Charge appears under the existing 'Payments' group (D-06)"
    - "mix ci runs clean: format, compile --warnings-as-errors, credo strict, full test suite, mix docs --warnings-as-errors"
    - "PaymentIntent code is NOT touched (D-07 lock; explicit guard in this plan)"
  artifacts:
    - path: "test/integration/external_account_integration_test.exs"
      provides: "stripe-mock CRUDL coverage for ExternalAccount: bank + card + mixed list"
      contains: "ExternalAccountIntegrationTest"
    - path: "test/integration/transfer_integration_test.exs"
      provides: "stripe-mock Transfer lifecycle + separate-charge-and-transfer scenario"
      contains: "TransferIntegrationTest"
    - path: "test/integration/transfer_reversal_integration_test.exs"
      provides: "stripe-mock TransferReversal create+list"
      contains: "TransferReversalIntegrationTest"
    - path: "test/integration/payout_integration_test.exs"
      provides: "stripe-mock Payout lifecycle including cancel + reverse with expand"
      contains: "PayoutIntegrationTest"
    - path: "test/integration/balance_integration_test.exs"
      provides: "stripe-mock Balance retrieve platform + per-connected-account via stripe_account: opt"
      contains: "BalanceIntegrationTest"
    - path: "test/integration/balance_transaction_integration_test.exs"
      provides: "stripe-mock BalanceTransaction retrieve + list filtered by payout"
      contains: "BalanceTransactionIntegrationTest"
    - path: "test/integration/charge_integration_test.exs"
      provides: "stripe-mock Charge retrieve with balance_transaction expansion"
      contains: "ChargeIntegrationTest"
    - path: "guides/connect.md"
      provides: "Money-movement section appended to Phase 17 onboarding half (8 numbered subsections per D-07)"
      contains: "Money Movement"
  key_links:
    - from: "guides/connect.md money-movement section"
      to: "every Phase 18 module"
      via: "Worked code blocks reference each module by name with copy-pasteable examples against stripe-mock"
      pattern: "LatticeStripe\\.(BankAccount|Card|ExternalAccount|Transfer|TransferReversal|Payout|Balance|BalanceTransaction|Charge)"
    - from: "mix.exs ExDoc groups_for_modules"
      to: "Phase 18 modules"
      via: "Connect group expanded with new modules; Charge added to Payments group"
      pattern: "groups_for_modules"
---

<objective>
Close Phase 18 by:

1. Adding stripe-mock integration tests for every new resource (7 test files), validating real HTTP request/response cycles against the official Stripe OpenAPI mock server.
2. Appending the money-movement section to `guides/connect.md` (Phase 17 wrote the onboarding half) per the D-07 8-subsection outline, with webhook-handoff callouts at every narrative transition.
3. Wiring all new Phase 18 modules into `mix.exs` ExDoc groups: new Connect modules append to the existing Phase 17 "Connect" group; `LatticeStripe.Charge` joins the existing "Payments" group per D-06.
4. Running `mix ci` to verify format, compile, credo strict, full test suite, and mix docs --warnings-as-errors all pass.

Closes CNCT-02, CNCT-03, CNCT-04, CNCT-05 holistically. D-07 explicitly forbids any code changes to `lib/lattice_stripe/payment_intent.ex` — this plan must include an explicit guard against it.

Output: 7 integration test files, 1 guide append, 1 mix.exs update.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/18-connect-money-movement/18-CONTEXT.md
@.planning/phases/18-connect-money-movement/18-RESEARCH.md
@.planning/phases/18-connect-money-movement/18-VALIDATION.md
@guides/connect.md
@mix.exs
@test/integration

<interfaces>
From test/test_helper.exs (already wired by Phase 9):
```elixir
LatticeStripe.test_integration_client/0  # returns a Client pointed at localhost:12111 stripe-mock
ExUnit.Case  # use with @moduletag :integration
```

From mix.exs (Phase 17 already added the "Connect" group):
```elixir
groups_for_modules: [
  Payments: [...],
  Billing: [...],
  Connect: [LatticeStripe.Account, LatticeStripe.Account.Capability, ..., LatticeStripe.AccountLink, LatticeStripe.LoginLink],
  Webhooks: [...],
  Testing: [...],
  Telemetry: [...]
]
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: stripe-mock integration tests for all 7 Phase 18 resource families</name>
  <files>test/integration/external_account_integration_test.exs, test/integration/transfer_integration_test.exs, test/integration/transfer_reversal_integration_test.exs, test/integration/payout_integration_test.exs, test/integration/balance_integration_test.exs, test/integration/balance_transaction_integration_test.exs, test/integration/charge_integration_test.exs</files>
  <read_first>
    - test/integration (list existing Phase 14/15/16/17 integration tests for the canonical shape)
    - Pick one Phase 17 integration test (e.g., `test/integration/account_integration_test.exs` if it exists) and copy its setup/teardown structure
    - test/test_helper.exs (integration config)
    - All 5 prior plans' source modules to know exact public function signatures
    - .planning/phases/18-connect-money-movement/18-VALIDATION.md (sampling rate + per-task verification map)
  </read_first>
  <action>
**For each integration test file, follow the established Phase 14–17 pattern:**

```elixir
defmodule LatticeStripe.Integration.<Resource>IntegrationTest do
  use ExUnit.Case, async: false
  @moduletag :integration

  alias LatticeStripe.<Resource>

  setup do
    {:ok, client: LatticeStripe.test_integration_client()}
  end

  describe "<resource> CRUDL against stripe-mock" do
    test "create -> retrieve -> update -> list happy path", %{client: client} do
      ...
    end
  end
end
```

**Per-resource integration coverage:**

**`test/integration/external_account_integration_test.exs`**
- Setup: create a Connect account first (call `LatticeStripe.Account.create/3` if the helper exists from Phase 17, otherwise inline the POST `/v1/accounts` call)
- Test 1: `ExternalAccount.create(client, account_id, %{external_account: "btok_us"})` — expect `%BankAccount{}` returned
- Test 2: `ExternalAccount.create(client, account_id, %{external_account: "tok_visa_debit"})` — expect `%Card{}` returned
- Test 3: `ExternalAccount.retrieve(client, account_id, ba_id)` returns the same struct type
- Test 4: `ExternalAccount.update(client, account_id, ba_id, %{metadata: %{"k" => "v"}})`
- Test 5: `ExternalAccount.list(client, account_id)` — mixed list returns at least one BankAccount and one Card; pattern-match works
- Test 6: `ExternalAccount.delete(client, account_id, ba_id)` — `:extra["deleted"] == true`
- Test 7: `ExternalAccount.stream!(client, account_id) |> Enum.take(5)` — yields struct mix

If stripe-mock returns a fixed canned object regardless of token (common stripe-mock behavior), the test should still verify the dispatcher branches correctly using `case` on the returned struct type.

**`test/integration/transfer_integration_test.exs`**
- Test 1: `Transfer.create(client, %{amount: 1000, currency: "usd", destination: "acct_test"})` returns `{:ok, %Transfer{}}`
- Test 2: `Transfer.retrieve(client, transfer_id)` returns the same struct; `transfer.reversals` is a list (may be empty against stripe-mock)
- Test 3: `Transfer.update(client, transfer_id, %{metadata: %{...}})`
- Test 4: `Transfer.list(client, %{limit: 5})` returns wrapped Response{data: List{}}
- Test 5: `Transfer.stream!(client, %{limit: 2}) |> Enum.take(5)` lazy
- Test 6 (CNCT-03 separate-charge-and-transfer scenario): `PaymentIntent.create(client, %{amount: 1500, currency: "usd", payment_method: "pm_card_visa", confirm: true, transfer_group: "ORDER_42"})` THEN `Transfer.create(client, %{amount: 1200, currency: "usd", destination: "acct_test", transfer_group: "ORDER_42", source_transaction: "ch_..."})` — the goal is to exercise the params shape against stripe-mock; if stripe-mock rejects the source_transaction id format, document the limitation and use a hand-crafted ch_test ID

**`test/integration/transfer_reversal_integration_test.exs`**
- Test 1: After creating a transfer, `TransferReversal.create(client, transfer_id, %{amount: 100})`
- Test 2: `TransferReversal.retrieve(client, transfer_id, reversal_id)` round-trips
- Test 3: `TransferReversal.list(client, transfer_id)` returns wrapped list
- Test 4: `TransferReversal.stream!(client, transfer_id) |> Enum.take(3)`

**`test/integration/payout_integration_test.exs`**
- Test 1: `Payout.create(client, %{amount: 500, currency: "usd"})` returns `{:ok, %Payout{}}`; if `payout.trace_id` is non-nil it is a `%Payout.TraceId{}` struct
- Test 2: `Payout.retrieve(client, payout_id)` round-trips
- Test 3: `Payout.update(client, payout_id, %{metadata: %{}})`
- Test 4: `Payout.list(client, %{limit: 5})`
- Test 5: `Payout.stream!(client, %{limit: 2}) |> Enum.take(5)` lazy
- Test 6: `Payout.cancel(client, payout_id)` — common-case ergonomic path (no params)
- Test 7: `Payout.cancel(client, payout_id, %{expand: ["balance_transaction"]})` — D-03 expand path
- Test 8: `Payout.reverse(client, payout_id, %{metadata: %{"reason" => "test"}})`

If stripe-mock rejects cancel/reverse on its canned payout (state machine), wrap in `try`/`rescue` or assert against the specific `%LatticeStripe.Error{type: :invalid_request_error}` shape — document the constraint.

**`test/integration/balance_integration_test.exs`** — most important per D-07 / Pitfall 2:
- Test 1: `Balance.retrieve(client)` returns platform balance — `%Balance{}` with `available`/`pending`/etc. lists of `%Balance.Amount{}`
- Test 2: `Balance.retrieve(client, stripe_account: "acct_test")` — returns connected account balance; ASSERT the request was made with the `stripe-account` header set to `"acct_test"` (this may require Mox-style transport spy OR can be inferred from stripe-mock's response shape)
- Test 3: Balance.Amount reuse — assert `match?(%LatticeStripe.Balance.Amount{}, hd(balance.available))` for every list field
- Test 4: `Balance.retrieve!/2` raises on `{:error, _}`

**`test/integration/balance_transaction_integration_test.exs`**
- Test 1: `BalanceTransaction.retrieve(client, "txn_test")` returns `%BalanceTransaction{}`; `bt.fee_details` is `[%FeeDetail{}]` if stripe-mock provides them, else empty list
- Test 2: `BalanceTransaction.list(client, %{limit: 5})` returns wrapped list
- Test 3: `BalanceTransaction.list(client, %{payout: "po_test"})` — payout filter (may return empty against stripe-mock)
- Test 4: `BalanceTransaction.stream!(client, %{limit: 2}) |> Enum.take(5)`
- Test 5: Reconciliation pattern verification — `Enum.filter(bt.fee_details, &(&1.type == "application_fee"))` runs without crashing (may return empty)

**`test/integration/charge_integration_test.exs`**
- Test 1: `Charge.retrieve(client, "ch_test")` returns `%Charge{}`
- Test 2: `Charge.retrieve(client, "ch_test", expand: ["balance_transaction"])` — `charge.balance_transaction` is a map (expanded), not a string
- Test 3: PII Inspect verification against the live stripe-mock response: `inspect(charge)` does NOT contain literal payment-method-details PII

**Each integration test file uses `@moduletag :integration` so it is excluded from the default `mix test` run** and only runs via `mix test --only integration`. This matches the Phase 9 / Phase 17 convention.

**If stripe-mock is not running locally**, every integration test should fail-loud with the descriptive message established by Phase 9 D-09 ("`docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest`"). Do NOT use `{:skip, reason}` — that's not supported in ExUnit 1.19. Use `raise` with the Docker command per Phase 9 precedent.
  </action>
  <verify>
    <automated>mix test --only integration test/integration/external_account_integration_test.exs test/integration/transfer_integration_test.exs test/integration/transfer_reversal_integration_test.exs test/integration/payout_integration_test.exs test/integration/balance_integration_test.exs test/integration/balance_transaction_integration_test.exs test/integration/charge_integration_test.exs</automated>
  </verify>
  <acceptance_criteria>
    - All 7 integration test files exist under `test/integration/`
    - Each contains `@moduletag :integration` and `LatticeStripe.test_integration_client()` call in setup
    - `mix test --only integration test/integration/external_account_integration_test.exs` exits 0 (with stripe-mock running)
    - `mix test --only integration test/integration/balance_integration_test.exs` exits 0
    - `mix test --only integration` (full integration suite) exits 0
    - `grep -q 'stripe_account' test/integration/balance_integration_test.exs` succeeds (D-07 / Pitfall 2 mitigation tested)
    - `grep -q 'expand' test/integration/payout_integration_test.exs` succeeds (D-03 expand-on-cancel verified)
    - `! grep -r 'lib/lattice_stripe/payment_intent.ex' .planning/phases/18-connect-money-movement/` (D-07 explicit guard: NO PaymentIntent code touched)
  </acceptance_criteria>
  <done>All 7 integration test files exist, exercise stripe-mock for every Phase 18 resource family, cover the D-03/D-07/Pitfall-2 critical paths, and pass under `mix test --only integration`.</done>
</task>

<task type="auto">
  <name>Task 2: guides/connect.md money-movement section + mix.exs ExDoc wiring + final mix ci</name>
  <files>guides/connect.md, mix.exs</files>
  <read_first>
    - guides/connect.md (Phase 17 onboarding half — read entire file to understand existing structure and tone)
    - mix.exs (especially the `docs/0` / `groups_for_modules:` block)
    - .planning/phases/18-connect-money-movement/18-CONTEXT.md D-07 (the 8-subsection outline — copy verbatim as the section structure)
    - .planning/phases/18-connect-money-movement/18-RESEARCH.md "Anti-patterns to avoid" + "Common Pitfalls" (informs the warnings in the guide)
    - .planning/phases/15-subscriptions-subscription-items/15-CONTEXT.md webhook-handoff callout requirement (P15 D5 — "drive application state from webhook events, not SDK responses")
  </read_first>
  <action>
**Append a new top-level section to `guides/connect.md`** titled `## Money Movement` (or whichever heading level fits the existing onboarding half). Follow the D-07 8-subsection outline VERBATIM:

1. **External accounts** — bank accounts and debit cards via `ExternalAccount.create`/`retrieve`/`update`/`delete`/`list`. Show the `case` pattern-matching idiom on `%BankAccount{}` / `%Card{}` / `%ExternalAccount.Unknown{}`. Include a default_for_currency example. End with: **Webhook callout** — "react to `account.external_account.created` / `.updated` / `.deleted`, do not poll".

2. **Balance** — `Balance.retrieve(client)` for platform vs `Balance.retrieve(client, stripe_account: "acct_123")` for connected account, side by side. Show interpreting `available` / `pending` / `connect_reserved` / `instant_available`. Read source_types breakdown via `amount.source_types.card` etc. **CRITICAL: this section MUST prominently warn against the loop antipattern** — calling `Balance.retrieve(client)` inside `Enum.each(connected_accounts, ...)` returns the platform balance every time. Quote D-07 / Pitfall 2 verbatim if useful.

3. **Transfers** — `Transfer.create(client, %{amount, currency, destination, transfer_group})`, `Transfer.retrieve`, `Transfer.list`. Show creating a `TransferReversal` via `TransferReversal.create(client, transfer_id, %{amount: ...})`. **Webhook callout** — "react to `transfer.created` / `transfer.reversed`, do not poll".

4. **Payouts** — `Payout.create(client, %{amount, currency, method: :instant})`. Show `Payout.cancel` and `Payout.reverse` with the `expand: ["balance_transaction"]` form (D-03). Read `payout.trace_id.status` for settlement tracking. **Webhook callout** — "react to `payout.paid` / `payout.failed`, do not poll".

5. **Destination charges** — raw `PaymentIntent.create` with `application_fee_amount`, `transfer_data`, `on_behalf_of`, `transfer_group`. Make it explicit that LatticeStripe ships NO `create_destination_charge` wrapper — the params ARE the API surface (D-07). Quote the `application_fee_amount` field name from `payment_intent.ex:66-77` verbatim. **Webhook callout** — "react to `charge.succeeded` + `application_fee.created`, do not poll".

6. **Separate charges and transfers** — three-step flow: (a) `PaymentIntent.create` with `transfer_group`, (b) confirm, (c) `Transfer.create` with `source_transaction: ch_...` and same `transfer_group`. Explicit note: **`source_transaction` prevents transfers from running ahead of settled funds**. Multi-destination fan-out example (loop over destinations in `Transfer.create` calls, each with the same `transfer_group`).

7. **Reconciling platform fees** — TWO PARALLEL IDIOMS, both documented side-by-side:
   - **Per-object idiom:** `PaymentIntent.retrieve(client, "pi_...", expand: ["latest_charge.balance_transaction"])`, walk `pi.latest_charge.balance_transaction.fee_details |> Enum.filter(&(&1.type == "application_fee"))`. Note that since `latest_charge` is opaque on PI today, users may need `Charge.retrieve(client, charge_id, expand: ["balance_transaction"])` instead — show that form explicitly.
   - **Per-payout batch idiom:** `BalanceTransaction.list(client, %{payout: po.id})` AND `BalanceTransaction.stream!(client, %{payout: po.id})` for large payouts. Walk each BT's `fee_details`. Show how to expand `bt.source` and manually cast via `Charge.from_map` / `Transfer.from_map` / `Refund.from_map` per D-05 rule 5.
   - **Webhook callout** — "trigger reconciliation on `payout.paid`, do not poll".

8. **Closing** — short pointer: "the Connect surface is now complete; see `LatticeStripe` ExDoc Connect group for module reference".

**Every code block must be copy-pasteable against stripe-mock or a real test-mode Stripe key.** Favor minimal but realistic params (`amount: 1000`, `currency: "usd"`, `destination: "acct_..."`).

**Webhook-handoff callouts** — use a consistent visual style. Suggest:
```markdown
> **Webhook handoff** — react to `event.name` rather than polling. See [Webhooks guide](webhooks.md).
```

**Update `mix.exs`** — find the `groups_for_modules:` block in `docs/0`. Append to the existing "Connect" group:

```elixir
LatticeStripe.BankAccount,
LatticeStripe.Card,
LatticeStripe.ExternalAccount,
LatticeStripe.ExternalAccount.Unknown,
LatticeStripe.Transfer,
LatticeStripe.TransferReversal,
LatticeStripe.Payout,
LatticeStripe.Payout.TraceId,
LatticeStripe.Balance,
LatticeStripe.Balance.Amount,
LatticeStripe.Balance.SourceTypes,
LatticeStripe.BalanceTransaction,
LatticeStripe.BalanceTransaction.FeeDetail,
```

Append to the existing "Payments" group:
```elixir
LatticeStripe.Charge,
```

**D-07 EXPLICIT GUARD:** Before committing this task, verify that `lib/lattice_stripe/payment_intent.ex` has NOT been modified during Phase 18 by running `git diff --stat lib/lattice_stripe/payment_intent.ex` — the output MUST be empty. If it is non-empty, REVERT the changes immediately.

**Final `mix ci` run**: After the guide append + mix.exs update, run `mix ci` and verify all 5 quality gates pass:
1. `mix format --check-formatted`
2. `mix compile --warnings-as-errors`
3. `mix credo --strict`
4. `mix test`
5. `mix docs --warnings-as-errors`

Then run integration suite explicitly: `mix test --only integration`.
  </action>
  <verify>
    <automated>mix ci && mix test --only integration</automated>
  </verify>
  <acceptance_criteria>
    - `guides/connect.md` contains a new `## Money Movement` section (or equivalent heading) with all 8 D-07 subsections present
    - `grep -c 'Webhook handoff' guides/connect.md` returns at least 4 (one per major narrative transition: external accounts, transfers, payouts, destination charges, reconciliation)
    - `grep -q 'stripe_account:' guides/connect.md` succeeds (Pitfall 2 mitigation present in Balance section)
    - `grep -q 'application_fee_amount' guides/connect.md` succeeds (destination charges section)
    - `grep -q 'source_transaction' guides/connect.md` succeeds (separate charges and transfers section)
    - `grep -q 'BalanceTransaction.list' guides/connect.md` succeeds (per-payout reconciliation idiom)
    - `grep -q 'expand:.*balance_transaction' guides/connect.md` succeeds (per-object reconciliation idiom)
    - `grep -q 'LatticeStripe.BankAccount' mix.exs` succeeds (ExDoc Connect group wiring)
    - `grep -q 'LatticeStripe.Charge' mix.exs` succeeds (ExDoc Payments group wiring)
    - `git diff --stat lib/lattice_stripe/payment_intent.ex` is empty (D-07 explicit guard — payment_intent NOT touched)
    - `mix ci` exits 0 (format + compile + credo + test + docs)
    - `mix test --only integration` exits 0
    - `mix docs --warnings-as-errors` exits 0
  </acceptance_criteria>
  <done>guides/connect.md money-movement section appended with all 8 D-07 subsections + 4+ webhook callouts + reconciliation dual-idiom; mix.exs ExDoc groups wired for all Phase 18 modules; mix ci green; integration suite green; PaymentIntent file untouched per D-07 enforcement guard.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| guide examples ↔ user code | Copy-pasted reconciliation snippets must be correct; a wrong `Balance.retrieve` example would propagate Pitfall 2 to every reader |
| Phase 18 scope ↔ PaymentIntent code | D-07 forbids any PaymentIntent code change; an accidental edit (e.g., during refactor sweep) would silently violate the locked decision |
| stripe-mock ↔ real Stripe | stripe-mock is OpenAPI-derived but has known limitations on state-machine endpoints (cancel/reverse on canned objects); integration tests must not rely on behaviors stripe-mock does not implement |
| Reconciliation guide ↔ webhook discipline | LatticeStripe consistently tells users to drive state from webhooks; the Connect guide is the most critical place to repeat that |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-18-27 | I (Information disclosure) | Guide example shows `Balance.retrieve(client)` inside a connected-account loop | mitigate | Section 2 of the guide explicitly warns against the antipattern; integration test asserts `stripe_account:` opt threading; acceptance criterion grep guard requires `stripe_account:` literal in guide |
| T-18-28 | E (Elevation of privilege) | PaymentIntent code accidentally modified during Phase 18 (D-07 violation) | mitigate | Acceptance criterion `git diff --stat lib/lattice_stripe/payment_intent.ex` MUST be empty; explicit revert instruction in task action |
| T-18-29 | T (Tampering) | Webhook-handoff discipline silently dropped from the guide | mitigate | Acceptance criterion `grep -c 'Webhook handoff' guides/connect.md` requires at least 4 occurrences; aligns with P15 D5 "drive state from webhooks" |
| T-18-30 | R (Repudiation) | Reconciliation guide presents only one of the two idioms, leading users to pick the wrong one for their use case | mitigate | Acceptance criteria require BOTH grep guards: `expand:.*balance_transaction` AND `BalanceTransaction.list` |
| T-18-31 | T (Tampering) | Integration tests pass against stripe-mock but break against real Stripe due to stripe-mock leniency | accept | stripe-mock is OpenAPI-derived; this is a known testing-ladder limitation; production users will catch any divergence in their own integration tests; document the limitation in CHANGELOG if Phase 19 surfaces a real-Stripe-only issue |
| T-18-32 | E (Elevation of privilege) | Charge module appears in "Connect" group instead of "Payments" group (D-06 violation) | mitigate | Acceptance criterion `grep -q 'LatticeStripe.Charge' mix.exs` AND visual / mix docs verification — Charge MUST be under Payments group per D-06 |
</threat_model>

<verification>
- `mix ci` exits 0 (format + compile --warnings-as-errors + credo strict + test + mix docs --warnings-as-errors)
- `mix test --only integration` exits 0 (all 7 new integration test files green)
- `git diff --stat lib/lattice_stripe/payment_intent.ex` is empty (D-07 enforcement)
- `mix docs` produces HTML output with all Phase 18 modules in correct ExDoc groups (Connect for everything except Charge → Payments)
- All acceptance-criteria grep guards pass
- Manual: open `doc/index.html` and confirm:
  - Connect group lists the 13 new Phase 18 modules
  - Payments group includes `LatticeStripe.Charge`
  - guides/connect.md money-movement section renders correctly with 4+ webhook callouts
  - All code blocks have proper syntax highlighting
</verification>

<success_criteria>
- All 7 integration test files exist and pass against stripe-mock
- `guides/connect.md` money-movement section exists with all 8 D-07 subsections
- 4+ webhook-handoff callouts present in the guide
- Reconciliation section presents BOTH per-object and per-payout idioms side-by-side
- `mix.exs` ExDoc groups updated: 13 new modules under Connect; Charge under Payments
- `mix ci` green (5 quality gates)
- `mix test --only integration` green
- `lib/lattice_stripe/payment_intent.ex` UNTOUCHED (D-07 enforced via git diff guard)
- Phase 18 ships ready for Phase 19 polish + v1.0 release cut
</success_criteria>

<output>
After completion, create `.planning/phases/18-connect-money-movement/18-06-SUMMARY.md`
</output>
