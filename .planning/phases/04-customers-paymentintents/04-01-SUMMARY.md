---
phase: 04-customers-paymentintents
plan: "01"
subsystem: resources
tags: [customer, crud, list, search, stream, inspect, pii]
dependency_graph:
  requires:
    - lib/lattice_stripe/client.ex
    - lib/lattice_stripe/request.ex
    - lib/lattice_stripe/response.ex
    - lib/lattice_stripe/list.ex
    - lib/lattice_stripe/error.ex
  provides:
    - lib/lattice_stripe/customer.ex
  affects:
    - Pattern for all subsequent resource modules (PaymentIntent, SetupIntent, etc.)
tech_stack:
  added: []
  patterns:
    - "build %Request{} -> Client.request/2 -> unwrap_singular/unwrap_list -> typed struct"
    - "from_map/1 with @known_fields for struct mapping + extra overflow"
    - "Custom Inspect hiding PII fields"
    - "Bang variants via unwrap_bang!/1 helper"
    - "stream!/3 wraps List.stream!/2 |> Stream.map(&from_map/1)"
key_files:
  created:
    - lib/lattice_stripe/customer.ex
    - test/lattice_stripe/customer_test.exs
  modified: []
decisions:
  - "search URL assertion uses =~ not String.ends_with? because GET params append query string to URL"
  - "from_map/1 made public (not defp) so callers building streams can apply it directly"
  - "Inspect shows id/object/livemode/deleted only; hides email/name/phone/description/address/shipping"
metrics:
  duration_minutes: 3
  completed_date: "2026-04-02"
  tasks_completed: 1
  tasks_total: 1
  files_created: 2
  files_modified: 0
requirements:
  - CUST-01
  - CUST-02
  - CUST-03
  - CUST-04
  - CUST-05
  - CUST-06
---

# Phase 04 Plan 01: Customer Resource Module Summary

**One-liner:** Customer CRUD/list/search/stream module establishing the typed-struct resource pattern with PII-hiding Inspect for all subsequent resources.

## What Was Built

`LatticeStripe.Customer` — the first resource module in the SDK, implementing the `build_request -> Client.request -> unwrap_response` pipeline pattern.

### Files Created

- **`lib/lattice_stripe/customer.ex`** (324 lines) — Customer struct with 26 known Stripe fields, all CRUD operations, list/search, auto-pagination streams, bang variants, `from_map/1`, and PII-hiding Inspect implementation.
- **`test/lattice_stripe/customer_test.exs`** (339 lines) — 21 Mox-based tests covering all operations, `from_map/1` defaults, and Inspect PII hiding.

### Pattern Established

Every subsequent resource module follows this exact pattern:

```elixir
@known_fields ~w[id object ...]  # string sigil for Jason string-key output

defstruct [..., object: "resource_type", deleted: false, extra: %{}]

def create(%Client{} = client, params \\ %{}, opts \\ []) do
  %Request{method: :post, path: "/v1/resource", params: params, opts: opts}
  |> then(&Client.request(client, &1))
  |> unwrap_singular()
end

defp unwrap_singular({:ok, %Response{data: data}}), do: {:ok, from_map(data)}
defp unwrap_singular({:error, %Error{}} = error), do: error

defp from_map(map) when is_map(map) do
  %__MODULE__{
    id: map["id"],
    # ... all fields
    extra: Map.drop(map, @known_fields)
  }
end
```

### Requirements Satisfied

| Requirement | Description | Status |
|-------------|-------------|--------|
| CUST-01 | Create customer with email, name, metadata | DONE |
| CUST-02 | Retrieve, update, delete by ID | DONE |
| CUST-03 | List with filters, typed %Customer{} items | DONE |
| CUST-04 | Search with query string, typed results | DONE |
| CUST-05 | stream!/2 and search_stream!/3 for lazy pagination | DONE |
| CUST-06 | Custom Inspect hides PII, shows id/object/livemode/deleted | DONE |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed search test URL assertion**
- **Found during:** Task 1 GREEN verification
- **Issue:** Test asserted `String.ends_with?(req.url, "/v1/customers/search")` but GET requests include query params in the URL (`?query=email%3A...`), so the URL doesn't end with the path.
- **Fix:** Changed to `req.url =~ "/v1/customers/search"` which matches the path substring correctly.
- **Files modified:** `test/lattice_stripe/customer_test.exs`
- **Commit:** 420f4a2

No other deviations.

## Test Results

- 21 Customer-specific tests: all pass
- 256 total tests (full suite): all pass, 0 regressions
- `mix compile --warnings-as-errors`: clean
- `mix format --check-formatted`: clean

## Self-Check: PASSED

- `lib/lattice_stripe/customer.ex`: EXISTS
- `test/lattice_stripe/customer_test.exs`: EXISTS
- Commit b889119 (RED test): EXISTS
- Commit 420f4a2 (GREEN implementation): EXISTS
