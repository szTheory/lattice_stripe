# Phase 40: Mandate & SetupAttempt Integration Closure - Pattern Map

**Mapped:** 2026-05-25
**Files analyzed:** 4
**Analogs found:** 4 / 4

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `test/integration/mandate_integration_test.exs` | test | request-response | `test/integration/account_integration_test.exs` | exact |
| `.planning/phases/35-mandate-setupattempt/35-VERIFICATION.md` | test | batch | `.planning/phases/34-creditnote/34-VERIFICATION.md` | exact |
| `.planning/REQUIREMENTS.md` | config | transform | `.planning/phases/39-credit-note-verification-closure/39-02-SUMMARY.md` + current `.planning/REQUIREMENTS.md` | role-match |
| `test/support/fixtures/mandate.ex` | test | transform | `test/support/fixtures/mandate.ex` | exact |

## Pattern Assignments

### `test/integration/mandate_integration_test.exs` (test, request-response)

**Primary analog:** `test/integration/account_integration_test.exs`
**Supporting analog:** `test/integration/setup_attempt_integration_test.exs`

**Module doc + stripe-mock boundary** from [test/integration/account_integration_test.exs](/Users/jon/projects/lattice_stripe/test/integration/account_integration_test.exs:2):
```elixir
@moduledoc """
Integration tests for `LatticeStripe.Account` against stripe-mock.

...

stripe-mock is stateless — it validates against the OpenAPI spec and returns
canned-but-randomized responses. Assertions check SHAPE (structs, `is_binary(id)`)
not SEMANTICS (actual status transitions).
"""
```

**TCP guard + Finch startup** from [test/integration/setup_attempt_integration_test.exs](/Users/jon/projects/lattice_stripe/test/integration/setup_attempt_integration_test.exs:10):
```elixir
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
```

**Per-test client setup** from [test/integration/setup_attempt_integration_test.exs](/Users/jon/projects/lattice_stripe/test/integration/setup_attempt_integration_test.exs:22):
```elixir
setup do
  {:ok, client: test_integration_client()}
end
```

**Retrieve-only shape assertion** from [test/integration/account_integration_test.exs](/Users/jon/projects/lattice_stripe/test/integration/account_integration_test.exs:66):
```elixir
test "retrieve/3 by id returns %Account{} with matching id", %{client: client} do
  {:ok, %Account{id: id}} =
    Account.create(client, %{
      "type" => "custom",
      "country" => "US"
    })

  assert {:ok, %Account{id: ^id}} = Account.retrieve(client, id)
end
```

**Mandate-specific typed-shape assertions to copy** from [test/lattice_stripe/mandate_test.exs](/Users/jon/projects/lattice_stripe/test/lattice_stripe/mandate_test.exs:50):
```elixir
mandate = Mandate.from_map(mandate_json())

assert mandate.status == :active
assert mandate.type == :single_use
assert mandate.customer_acceptance.type == :online
```

**Fixture payload shape** from [test/support/fixtures/mandate.ex](/Users/jon/projects/lattice_stripe/test/support/fixtures/mandate.ex:4):
```elixir
def mandate_json(overrides \\ %{}) do
  Map.merge(
    %{
      "id" => "mandate_test1234567890abc",
      "object" => "mandate",
      "status" => "active",
      "type" => "single_use",
      "payment_method" => "pm_test1234567890abc",
      "customer_acceptance" => mandate_customer_acceptance_json(),
      "single_use" => mandate_single_use_json()
    },
    overrides
  )
end
```

**What to copy for Phase 40**
- Use the `AccountIntegrationTest` doc style, not the bare `SetupAttemptIntegrationTest` style, because Phase 40 needs explicit audit-facing `stripe-mock` caveats.
- Keep the module narrow: one `retrieve/3` proof is enough.
- Prefer shape assertions only: `%Mandate{}`, `is_binary(id)` or matching id when retrievable, and bounded typed top-level fields if present.
- Do not add deep semantic assertions for `customer_acceptance`, expanded `payment_method`, or `extra`; those already belong to unit coverage.

---

### `.planning/phases/35-mandate-setupattempt/35-VERIFICATION.md` (test, batch)

**Primary analog:** `.planning/phases/34-creditnote/34-VERIFICATION.md`
**Supporting analog:** `.planning/phases/33-disputes/33-VERIFICATION.md`

**Frontmatter + closed-state format** from [.planning/phases/34-creditnote/34-VERIFICATION.md](/Users/jon/projects/lattice_stripe/.planning/phases/34-creditnote/34-VERIFICATION.md:1):
```yaml
---
phase: 34-creditnote
verified: 2026-05-25T07:07:43Z
status: closed
score: 6/6
overrides_applied: 0
re_verification: true
---
```

**Goal Achievement / Observable Truths table** from [.planning/phases/34-creditnote/34-VERIFICATION.md](/Users/jon/projects/lattice_stripe/.planning/phases/34-creditnote/34-VERIFICATION.md:17):
```markdown
## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
```

**Artifact Verification section** from [.planning/phases/33-disputes/33-VERIFICATION.md](/Users/jon/projects/lattice_stripe/.planning/phases/33-disputes/33-VERIFICATION.md:33):
```markdown
### Artifact Verification

| Artifact | Status | Evidence |
|----------|--------|----------|
```

**Behavioral Spot-Checks pattern** from [.planning/phases/34-creditnote/34-VERIFICATION.md](/Users/jon/projects/lattice_stripe/.planning/phases/34-creditnote/34-VERIFICATION.md:44):
```markdown
### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| CreditNote unit coverage | `mix test test/lattice_stripe/credit_note_test.exs` | 26 tests, 0 failures on 2026-05-25 | PASS |
| CreditNote integration coverage | `mix test test/integration/credit_note_integration_test.exs --include integration` | 8 tests, 0 failures on 2026-05-25 | PASS |
```

**Scope-of-proof notes** from [.planning/phases/34-creditnote/34-VERIFICATION.md](/Users/jon/projects/lattice_stripe/.planning/phases/34-creditnote/34-VERIFICATION.md:62):
```markdown
### Scope-of-Proof Notes

- The 2026-05-25 integration rerun used `stripe-mock` on `localhost:12111`.
- That integration evidence proves request/response wiring and typed decoding for the shipped CreditNote SDK surface.
- It does not claim full real-Stripe lifecycle semantics beyond what `stripe-mock` can model.
```

**What to copy for Phase 40**
- Keep `status: closed`, not `passed`, so the verifier matches the accepted milestone-closure artifact style.
- Score should be `2/2` or `3/3` depending on whether the author frames the goal as two requirements or three closure truths; either is acceptable if the truth table and requirement table stay aligned.
- Cite fresh targeted commands only:
  - `mix test test/lattice_stripe/mandate_test.exs`
  - `mix test test/lattice_stripe/setup_attempt_test.exs`
  - `mix test test/integration/mandate_integration_test.exs --include integration`
  - `mix test test/integration/setup_attempt_integration_test.exs --include integration`
- Requirement table should stay AUTH-only.
- Gaps summary should explicitly say the prior audit findings were `missing 35-VERIFICATION.md` and `missing Mandate integration coverage`.

---

### `.planning/REQUIREMENTS.md` (config, transform)

**Primary analog:** current `.planning/REQUIREMENTS.md`
**Supporting analog:** `.planning/phases/39-credit-note-verification-closure/39-02-SUMMARY.md`

**Requirement checkbox rows to update** from [.planning/REQUIREMENTS.md](/Users/jon/projects/lattice_stripe/.planning/REQUIREMENTS.md:29):
```markdown
### Payment Authorization

- [ ] **AUTH-01**: Developer can retrieve mandate details via `Mandate.retrieve/3`
- [ ] **AUTH-02**: Developer can list setup attempts filtered by setup_intent via `SetupAttempt.list/3` and `stream!/3`
```

**Traceability rows to update** from [.planning/REQUIREMENTS.md](/Users/jon/projects/lattice_stripe/.planning/REQUIREMENTS.md:86):
```markdown
| AUTH-01 | Phase 40 | Pending |
| AUTH-02 | Phase 40 | Pending |
```

**Scoped traceability-update rule** from [.planning/phases/39-credit-note-verification-closure/39-02-SUMMARY.md](/Users/jon/projects/lattice_stripe/.planning/phases/39-credit-note-verification-closure/39-02-SUMMARY.md:58):
```markdown
- Updated only the `CRDN-01` through `CRDN-06` traceability rows in `.planning/REQUIREMENTS.md` from `Pending` to `Verified`.
- Preserved the phase boundary by keeping Quote, Mandate, DX, roadmap, and STATE reconciliation outside this plan.
```

**What to copy for Phase 40**
- Flip only `AUTH-01` and `AUTH-02` from unchecked to checked.
- Flip only the two AUTH traceability rows from `Pending` to `Verified`.
- Leave QUOT and DX rows untouched.
- Do not broaden into roadmap cleanup here even though `ROADMAP.md` still shows Phase 35 plans as `TBD`; that belongs to Phase 42 per the current roadmap.

---

### `test/support/fixtures/mandate.ex` (test, transform)

**Analog:** self

**Mergeable fixture helper pattern** from [test/support/fixtures/mandate.ex](/Users/jon/projects/lattice_stripe/test/support/fixtures/mandate.ex:4):
```elixir
def mandate_json(overrides \\ %{}) do
  Map.merge(base_map, overrides)
end
```

**What to copy for Phase 40**
- Prefer reusing this fixture unchanged.
- Only add fixture data if the new integration test needs a tiny shape assertion that cannot rely on `stripe-mock` randomness.
- Do not introduce new fixture modules for this phase.

## Shared Patterns

### stripe-mock Guard
**Source:** [test/integration/setup_attempt_integration_test.exs](/Users/jon/projects/lattice_stripe/test/integration/setup_attempt_integration_test.exs:10)
**Apply to:** `test/integration/mandate_integration_test.exs`
```elixir
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
```

### Shape-First Integration Assertions
**Source:** [test/integration/account_integration_test.exs](/Users/jon/projects/lattice_stripe/test/integration/account_integration_test.exs:13)
**Apply to:** new Mandate integration proof and `35-VERIFICATION.md` scope notes
```elixir
stripe-mock is stateless — it validates against the OpenAPI spec and returns
canned-but-randomized responses. Assertions check SHAPE (structs, `is_binary(id)`)
not SEMANTICS (actual status transitions).
```

### Closure-Phase Evidence Discipline
**Source:** [.planning/phases/39-credit-note-verification-closure/39-01-SUMMARY.md](/Users/jon/projects/lattice_stripe/.planning/phases/39-credit-note-verification-closure/39-01-SUMMARY.md:56)
**Apply to:** `35-VERIFICATION.md`
```markdown
- Re-ran focused unit coverage.
- Re-ran focused `stripe-mock` integration coverage.
- Confirmed whether any API/test/doc repair was actually required before writing the verifier.
```

### AUTH-Only Traceability Scope
**Source:** [.planning/phases/40-mandate-setupattempt-integration-closure/40-CONTEXT.md](/Users/jon/projects/lattice_stripe/.planning/phases/40-mandate-setupattempt-integration-closure/40-CONTEXT.md:39)
**Apply to:** `.planning/REQUIREMENTS.md` and `35-VERIFICATION.md`
```markdown
- Update the tightest required planning surface first: create `35-VERIFICATION.md` and update AUTH-01/AUTH-02 traceability in `.planning/REQUIREMENTS.md`.
- Do not fold broader neighboring planning-truth cleanup into this phase.
```

## No Analog Found

None. The codebase already has exact closure-phase verifier patterns, a list-resource integration test pattern, and a retrieve-style `stripe-mock` integration pattern suitable for a narrow Mandate proof.

## Metadata

**Analog search scope:** `test/integration/`, `test/lattice_stripe/`, `test/support/fixtures/`, `.planning/phases/33-disputes/`, `.planning/phases/34-creditnote/`, `.planning/phases/35-mandate-setupattempt/`, `.planning/phases/39-credit-note-verification-closure/`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`
**Files scanned:** 19
**Pattern extraction date:** 2026-05-25
