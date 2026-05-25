# Phase 35: Mandate & SetupAttempt - Pattern Map

**Mapped:** 2026-05-24
**Files analyzed:** 13
**Analogs found:** 13 / 13

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/lattice_stripe/mandate.ex` | service | request-response | `lib/lattice_stripe/setup_intent.ex` | role-match |
| `lib/lattice_stripe/mandate/customer_acceptance.ex` | model | transform | `lib/lattice_stripe/dispute/evidence_details.ex` | role-match |
| `lib/lattice_stripe/mandate/single_use.ex` | model | transform | `lib/lattice_stripe/account/requirements.ex` | exact |
| `lib/lattice_stripe/setup_attempt.ex` | service | request-response | `lib/lattice_stripe/payment_method.ex` | exact |
| `lib/lattice_stripe/setup_attempt/setup_error.ex` | model | transform | `lib/lattice_stripe/dispute/evidence_details.ex` | role-match |
| `lib/lattice_stripe/object_types.ex` | config | transform | `lib/lattice_stripe/object_types.ex` | exact |
| `mix.exs` | config | transform | `mix.exs` | exact |
| `test/support/fixtures/mandate.ex` | test | transform | `test/support/fixtures/refund.ex` | exact |
| `test/support/fixtures/setup_attempt.ex` | test | transform | `test/support/fixtures/setup_intent.ex` | exact |
| `test/lattice_stripe/object_types_test.exs` | test | transform | `test/lattice_stripe/object_types_test.exs` | exact |
| `test/lattice_stripe/mandate_test.exs` | test | request-response | `test/lattice_stripe/setup_intent_test.exs` | role-match |
| `test/lattice_stripe/setup_attempt_test.exs` | test | request-response | `test/lattice_stripe/payment_method_test.exs` | exact |
| `test/integration/setup_attempt_integration_test.exs` | test | request-response | `test/integration/setup_intent_integration_test.exs` | exact |

## Pattern Assignments

### `lib/lattice_stripe/mandate.ex` (service, request-response)

**Primary analog:** `lib/lattice_stripe/setup_intent.ex`  
**Supporting analogs:** `lib/lattice_stripe/refund.ex`, `lib/lattice_stripe/dispute.ex`

- Copy the standard alias tuple and explicit `@known_fields` / `defstruct` / `@type` layout from `SetupIntent`.
- Keep the public request surface minimal:
  - `retrieve/3`
  - `retrieve!/3`
  - `from_map/1`
- Parse `customer_acceptance` with a dedicated nested struct and `single_use` with a tiny dedicated struct.
- Leave `multi_use` and `payment_method_details` raw.
- Use `ObjectTypes.maybe_deserialize/1` only for `payment_method` when Stripe returned an expanded map.
- Add private enum helpers for `status` and `type` with unknown-string passthrough.

### `lib/lattice_stripe/mandate/customer_acceptance.ex` and `single_use.ex` (models, transform)

**Primary analog:** `lib/lattice_stripe/dispute/evidence_details.ex`  
**Supporting analog:** `lib/lattice_stripe/account/requirements.ex`

- Use the repo’s standard nested-struct pattern:
  - `@known_fields ~w[...]`
  - `defstruct @known_fields ++ [:extra]` or explicit atom fields with `extra: %{}`
  - `from_map(nil), do: nil`
  - `Map.split/2` and explicit assignment
- `CustomerAcceptance.type` should atomize `online` / `offline`.
- Keep `online` and `offline` sub-branches raw maps to avoid over-modeling.
- `SingleUse` should stay intentionally tiny: `amount`, `currency`, `extra`.

### `lib/lattice_stripe/setup_attempt.ex` (service, request-response)

**Primary analog:** `lib/lattice_stripe/payment_method.ex`  
**Supporting analogs:** `lib/lattice_stripe/setup_intent.ex`, `lib/lattice_stripe/resource.ex`

- Copy the required-param guard from `PaymentMethod.list/3` and `stream!/3`, but require `"setup_intent"` instead of `"customer"`.
- Public API should be:
  - `list/3`
  - `list!/3`
  - `stream!/3`
  - `from_map/1`
- Do **not** add `retrieve/3`, `create/3`, or convenience aliases.
- Use `Resource.unwrap_list(&from_map/1)` and `List.stream!(client, req) |> Stream.map(&from_map/1)`.
- Top-level expandables should use `ObjectTypes.maybe_deserialize/1` when expanded:
  - `setup_intent`
  - `customer`
  - `payment_method`
  - `application`
  - `on_behalf_of`

### `lib/lattice_stripe/setup_attempt/setup_error.ex` (model, transform)

**Primary analog:** `lib/lattice_stripe/dispute/evidence_details.ex`  
**Supporting analog:** `lib/lattice_stripe/error.ex` for field naming only

- Treat this as a nested historical-data struct, not a reusable request error.
- Include fields such as:
  - `code`
  - `message`
  - `type`
  - `decline_code`
  - `doc_url`
  - `param`
  - `payment_method`
  - `extra`
- Allow optional newer fields such as `advice_code`, `network_advice_code`, and `network_decline_code` if execution decides they are worth first-pass support from the current Stripe object doc.
- Parse `payment_method` with `ObjectTypes.maybe_deserialize/1` only when expanded.

### `lib/lattice_stripe/object_types.ex` and `mix.exs` (config, transform)

**Analogs:** self

- Add:
  - `"mandate" => LatticeStripe.Mandate`
  - `"setup_attempt" => LatticeStripe.SetupAttempt`
- Place `LatticeStripe.Mandate`, `LatticeStripe.Mandate.CustomerAcceptance`, `LatticeStripe.Mandate.SingleUse`, `LatticeStripe.SetupAttempt`, and `LatticeStripe.SetupAttempt.SetupError` in the existing `Payments` ExDoc group near `PaymentMethod` and `SetupIntent`.
- Do not create a new ExDoc group.

### Test fixtures and unit tests

**Fixtures analogs:** `test/support/fixtures/setup_intent.ex`, `test/support/fixtures/refund.ex`  
**Unit-test analogs:** `test/lattice_stripe/setup_intent_test.exs`, `test/lattice_stripe/payment_method_test.exs`

- Use mergeable `*_json/1` helpers with Stripe-shaped maps.
- `mandate_json/1` should include:
  - `customer_acceptance`
  - `payment_method`
  - `payment_method_details`
  - `status`
  - `type`
  - either `single_use` or `multi_use`
- `setup_attempt_json/1` should include:
  - required `setup_intent`
  - `payment_method`
  - `payment_method_details`
  - `setup_error`
  - `status`
  - `usage`
- Unit tests should explicitly cover:
  - retrieve/list endpoint paths
  - `ArgumentError` on missing `"setup_intent"`
  - enum atomization with string passthrough
  - expanded payment-method parsing inside `setup_error`

### `test/integration/setup_attempt_integration_test.exs` (test, request-response)

**Primary analog:** `test/integration/setup_intent_integration_test.exs`

- Reuse the `stripe-mock` TCP guard and `test_integration_client()` setup.
- Keep integration scope narrow:
  - `list/3` with a valid `setup_intent`
  - `stream!/3` shape sanity
- Mandate does not need first-pass integration coverage because Phase 35’s risk sits mostly in parser semantics and the required list filter, not in a complex lifecycle.
