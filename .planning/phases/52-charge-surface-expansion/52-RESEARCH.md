# Phase 52: Charge Surface Expansion — Research

**Researched:** 2026-05-27
**Status:** Complete

## Summary

Phase 52 expands `LatticeStripe.Charge` from retrieve-only to list/search/update/capture parity by mechanically cloning `PaymentIntent` wiring with `/v1/charges` paths. No new infrastructure, registry changes, or `create`/`cancel` — PI-first D-06 is reframed as "no payment initiation," not read-only. Proof is Mox-at-Transport under `test/lattice_stripe/charge/`, docs-truth grep on `charge.ex` @moduledoc, TaxId-style export contract, and optional stripe-mock shape smokes.

## Stripe API Endpoints

| Operation | Method | Path | Params |
|-----------|--------|------|--------|
| list | GET | `/v1/charges` | filter map (limit, customer, payment_intent, …) |
| search | GET | `/v1/charges/search` | `%{"query" => query}` |
| update | POST | `/v1/charges/:id` | metadata, description (Stripe-updatable fields) |
| capture | POST | `/v1/charges/:id/capture` | optional amount, receipt_email, … |
| retrieve | GET | `/v1/charges/:id` | existing |

Search uses bare query string arg (`search(client, query, opts)`), matching PaymentIntent/Customer — not Invoice's params-map overload.

## Mechanical Template: PaymentIntent

Copy from `lib/lattice_stripe/payment_intent.ex`:

```elixir
# list
%Request{method: :get, path: "/v1/charges", params: params, opts: opts}
|> Client.request(client, &1)
|> Resource.unwrap_list(&from_map/1)

# stream!
req = %Request{method: :get, path: "/v1/charges", params: params, opts: opts}
List.stream!(client, req) |> Stream.map(&from_map/1)

# search
%Request{method: :get, path: "/v1/charges/search", params: %{"query" => query}, opts: opts}

# update
%Request{method: :post, path: "/v1/charges/#{id}", params: params, opts: opts}
|> Resource.unwrap_singular(&from_map/1)

# capture
%Request{method: :post, path: "/v1/charges/#{id}/capture", params: params, opts: opts}
```

Add aliases: `List`, `Response` (Charge currently missing both).

## Hybrid Touches (not from PI alone)

| Source | What to copy |
|--------|----------------|
| Refund `@moduledoc` | Note that `update/4` is limited to **metadata and description** (not "metadata only") |
| Existing Charge | Pre-network `ArgumentError` on empty retrieve id; PII-safe `Inspect` — unchanged |
| stripe-node `charges.capture` | `capture/4` @doc must warn: do not capture PI-initiated charges; use `PaymentIntent.capture/4` |

**Do not use Dispute** as template — no search, domain-specific helpers.

## @moduledoc Rewrite (D-01)

Section order:

1. Opening — Charge as **result record** of payment attempt; PI confirmation creates Charge
2. `## When to use this module` — Connect reconciliation, support/audit list+search, post-hoc metadata
3. `## When not to use this module` — accept payment → PI; capture PI charge → `PaymentIntent.capture/4`; cancel → `PaymentIntent.cancel/4`; refund → `Refund.create/3`
4. `## Usage` — retrieve w/ expand, list/stream, search, update, capture examples
5. `## Connect platform fee reconciliation` — keep existing content
6. `## SDK surface (intentionally omitted)` — no `create`/`cancel`; D-06 = no payment initiation
7. `## Security and Inspect` — existing PII hide-list
8. `## Stripe API Reference`

**Remove:** "retrieve-only access", "Only three public functions exist", "Charges are never directly manipulated".

## Test Strategy (D-03, D-04)

### Module surface (TaxId pattern)

Delete `describe "module surface (D-06 retrieve-only)"` (8 negative-only tests).

Replace with:

```elixir
describe "module surface" do
  test "exports list, search, update, capture, retrieve, and from_map" do
    for {fun, arity} <- [
          {:retrieve, 2}, {:retrieve, 3}, {:retrieve!, 2}, {:retrieve!, 3},
          {:list, 2}, {:list, 3}, {:list!, 2}, {:list!, 3},
          {:stream!, 1}, {:stream!, 2}, {:stream!, 3},
          {:search, 2}, {:search, 3}, {:search!, 2}, {:search!, 3},
          {:search_stream!, 2}, {:search_stream!, 3},
          {:update, 3}, {:update, 4}, {:update!, 3}, {:update!, 4},
          {:capture, 3}, {:capture, 4}, {:capture!, 3}, {:capture!, 4},
          {:from_map, 1}
        ] do
      assert function_exported?(Charge, fun, arity)
    end
  end

  test "does not export create or cancel" do
    refute function_exported?(Charge, :create, 2)
    refute function_exported?(Charge, :create, 3)
    refute function_exported?(Charge, :cancel, 2)
    refute function_exported?(Charge, :cancel, 3)
  end
end
```

### Mox wire tests

New files under `test/lattice_stripe/charge/` — one `describe` per verb group, mirroring `payment_intent_test.exs` assertions:

- `list_test.exs` — GET `/v1/charges`, list response shape
- `search_test.exs` — GET `/v1/charges/search`, query param
- `update_test.exs` — POST `/v1/charges/:id`, metadata + description body
- `capture_test.exs` — POST `/v1/charges/:id/capture`

Keep existing `charge_test.exs` for retrieve/from_map/Inspect; relocate optional per executor discretion.

### docs-truth (CHRG-05)

New test in `docs_truth_test.exs`:

```elixir
test "Charge @moduledoc reflects expanded PI-first surface" do
  source = File.read!("lib/lattice_stripe/charge.ex")
  assert source =~ "PaymentIntent"
  assert source =~ "list/3"
  assert source =~ "search/3"
  assert source =~ "capture/4"
  assert source =~ "application_fee"
  refute source =~ "retrieve-only"
  refute source =~ "Only three public functions"
end
```

### Integration (recommended polish)

Extend `test/integration/charge_integration_test.exs` with shape-first smokes for list, search, update, capture — same stance as `dispute_integration_test.exs`.

## Out of Scope (locked)

- `create/3`, `cancel/3` — REQUIREMENTS + Phase 18 D-06
- `LatticeStripe.Testing.charge/1` — no adopter workflow in guides/testing.md
- `guides/charges.md`, README/JTBD routes
- Tax-style `adoption_contract_test.exs`

## Risks

| Risk | Mitigation |
|------|------------|
| Adopters capture PI-initiated charges via `Charge.capture/4` | `@doc` on capture/4 with explicit PI redirect |
| Moduledoc drift from code | docs-truth grep block |
| D-06 regression (create/cancel added) | Negative export refute in module surface test |

## Validation Architecture

Nyquist sampling for Phase 52:

| Layer | Command | When |
|-------|---------|------|
| Quick | `mix test test/lattice_stripe/charge_test.exs test/lattice_stripe/charge/ --warnings-as-errors` | After each task touching Charge tests |
| Compile | `mix compile --warnings-as-errors` | After charge.ex edits |
| Docs-truth | `mix test test/lattice_stripe/docs_truth_test.exs --only line:N` | After docs_truth task |
| Full unit | `mix test --exclude integration --warnings-as-errors` | After plan wave |
| Integration | `mix test test/integration/charge_integration_test.exs --include integration` | Final polish (stripe-mock required) |

Automated verify on every task; no watch mode. Integration tests are manual-gated by stripe-mock availability but tagged `@moduletag :integration` so CI can run when Docker service is up.

---

## RESEARCH COMPLETE
