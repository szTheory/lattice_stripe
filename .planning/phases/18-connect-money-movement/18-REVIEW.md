---
phase: 18-connect-money-movement
reviewed: 2026-04-12T00:00:00Z
depth: standard
files_reviewed: 16
files_reviewed_list:
  - lib/lattice_stripe/bank_account.ex
  - lib/lattice_stripe/card.ex
  - lib/lattice_stripe/external_account.ex
  - lib/lattice_stripe/external_account/unknown.ex
  - lib/lattice_stripe/charge.ex
  - lib/lattice_stripe/transfer.ex
  - lib/lattice_stripe/transfer_reversal.ex
  - lib/lattice_stripe/payout.ex
  - lib/lattice_stripe/payout/trace_id.ex
  - lib/lattice_stripe/balance.ex
  - lib/lattice_stripe/balance/amount.ex
  - lib/lattice_stripe/balance/source_types.ex
  - lib/lattice_stripe/balance_transaction.ex
  - lib/lattice_stripe/balance_transaction/fee_detail.ex
  - mix.exs
  - guides/connect.md
findings:
  critical: 0
  warning: 3
  info: 5
  total: 8
status: issues_found
---

# Phase 18: Code Review Report

**Reviewed:** 2026-04-12
**Depth:** standard
**Files Reviewed:** 16
**Status:** issues_found

## Summary

Phase 18 (Connect money movement) is in very good shape. Every locked decision
holds: D-02 (no `Transfer.reverse` delegator), D-03 (canonical
`(client, id, params, opts)` for `Payout.cancel`/`reverse` and
`TransferReversal.create`), D-05 (`BalanceTransaction.source` kept raw),
D-06 (`Charge` retrieve-only), and D-07 (`payment_intent.ex` is out of scope
and not touched in this file set). Polymorphic dispatch on `ExternalAccount`
uses string-keyed discriminators with no atom conversion, and the `Unknown`
fallback is reachable for any novel `"object"` value. F-001 `:extra` maps
are present on every struct, including nested ones
(`Payout.TraceId`, `Balance.Amount`, `Balance.SourceTypes`,
`BalanceTransaction.FeeDetail`, `ExternalAccount.Unknown`). PII hide-lists
on `BankAccount` and `Card` are complete and consistent with the moduledocs.

Issues found fall into two themes:

1. **Expandable references typed as bare `String.t()`** — Several
   expandable fields (`Charge.destination`, `Charge.source_transfer`,
   every expandable field on `Transfer`, and every expandable field on
   `TransferReversal`) are typed `String.t() | nil` rather than
   `String.t() | map() | nil`. `Payout` and `Charge.balance_transaction`
   got this right; the other modules did not. This is the focus-area item
   "expandable references" called out in the review brief. It is a
   typespec correctness issue: the moment a user passes `expand: [...]`
   on any of these modules, the returned struct violates its own
   `@type t`.

2. **Pre-network id validation inconsistency inside `Payout` and
   `BalanceTransaction`** — `Payout.update/4` (and `update!/4`) and
   `BalanceTransaction.retrieve/3` (and `retrieve!/3`) use
   `when is_binary(id)` guards without a matching `nil`/`""` clause, so
   calling them with `nil` raises `FunctionClauseError` instead of the
   friendly `ArgumentError` every other money-movement function in the
   phase raises. Tests that expect the pre-network `ArgumentError`
   contract will silently fail this path.

## Warnings

### WR-01: Transfer / TransferReversal expandable fields missing `map()` in typespec

**File:** `lib/lattice_stripe/transfer.ex:134-139, 144` and
`lib/lattice_stripe/transfer_reversal.ex:92-99`

**Issue:** The Phase 18 brief (focus area "Expandable references") requires
expandable references to be typed `binary() | map() | nil` so that
`from_map/1` producing an inlined expanded object does not violate the
struct's own `@type t`. `Transfer` has five expandable fields that are
typed as `String.t() | nil` only:

- `balance_transaction` (line 134)
- `destination` (line 138)
- `destination_payment` (line 139)
- `source_transaction` (line 144)
- (and arguably `reversals` wrapper, but that is decoded specially)

`TransferReversal` has four expandable fields with the same flaw
(lines 92-99):

- `balance_transaction`
- `destination_payment_refund`
- `source_refund`
- `transfer`

All of these fields become a map the moment a caller passes
`expand: ["balance_transaction"]` (etc.) — which the Phase 18 guide
explicitly encourages in `guides/connect.md:390-402` for `Payout` and
`guides/connect.md:506-528` for `Charge`. `Payout` got this right
(see `lib/lattice_stripe/payout.ex:147-152`), so this is inconsistent
within the phase, not a design decision.

**Fix:** Update typespecs (no struct / runtime change required). For
`lib/lattice_stripe/transfer.ex`:

```elixir
@type t :: %__MODULE__{
        ...
        balance_transaction: String.t() | map() | nil,
        ...
        destination: String.t() | map() | nil,
        destination_payment: String.t() | map() | nil,
        ...
        source_transaction: String.t() | map() | nil,
        ...
      }
```

And for `lib/lattice_stripe/transfer_reversal.ex`:

```elixir
@type t :: %__MODULE__{
        ...
        balance_transaction: String.t() | map() | nil,
        destination_payment_refund: String.t() | map() | nil,
        ...
        source_refund: String.t() | map() | nil,
        transfer: String.t() | map() | nil,
        ...
      }
```

### WR-02: Charge expandable fields `destination` and `source_transfer` missing `map()` in typespec

**File:** `lib/lattice_stripe/charge.ex:145, 164`

**Issue:** `Charge.balance_transaction` is correctly typed
`String.t() | map() | nil` (line 138) — confirming the author knew the
pattern — but `destination` (line 145) and `source_transfer` (line 164)
are typed `String.t() | nil` despite both being expandable per the
Stripe Charge API. The moduledoc even shows the expand idiom at
lines 28-31 for `balance_transaction`, so users will apply the same
pattern to `destination` and `source_transfer` and hit an unexpected map.

Note `transfer_data` is already typed `map() | nil` (line 168) which is
fine — it is always an inline object, never an id.

**Fix:**

```elixir
destination: String.t() | map() | nil,
...
source_transfer: String.t() | map() | nil,
```

### WR-03: Inconsistent pre-network id validation on `Payout.update` and `BalanceTransaction.retrieve`

**File:** `lib/lattice_stripe/payout.ex:231, 355` and
`lib/lattice_stripe/balance_transaction.ex:102, 117`

**Issue:** The Phase 18 brief requires pre-network guards on every
id-taking function so tests don't need mock setup to cover the
missing-id path. Every money-movement module in this phase follows that
contract except these four function heads:

- `Payout.update/4` (payout.ex:231) — `when is_binary(id)` with no
  `nil`/`""` clause. Calling `Payout.update(client, nil, %{})` raises
  `FunctionClauseError` rather than the expected
  `ArgumentError, "Payout.update/4 requires a non-empty \"payout id\""`.
  Same for `update!/4` (payout.ex:355).
- `BalanceTransaction.retrieve/3` (balance_transaction.ex:102) —
  `when is_binary(id)` as a clause guard, then an `if id == ""` check
  inside the body. `nil` hits `FunctionClauseError`; `""` raises
  `ArgumentError` as intended but via a two-step path. `retrieve!/3`
  (line 117) has the same shape.

The rest of the phase (`Payout.retrieve`/`cancel`/`reverse`, `Transfer.*`,
`TransferReversal.*`, `Charge.retrieve`, `ExternalAccount.*`) raises
`ArgumentError` with a helpful message for both `nil` and `""`. These
four inconsistent heads break that contract.

**Fix:** Add matching `nil`/`""` clauses ahead of the `is_binary` clause.
For `Payout.update/4`:

```elixir
def update(client, id, params, opts \\ [])

def update(%Client{}, nil, _params, _opts),
  do: raise(ArgumentError, ~s|Payout.update/4 requires a non-empty "payout id"|)

def update(%Client{}, "", _params, _opts),
  do: raise(ArgumentError, ~s|Payout.update/4 requires a non-empty "payout id"|)

def update(%Client{} = client, id, params, opts) when is_binary(id) do
  %Request{method: :post, path: "/v1/payouts/#{id}", params: params, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end
```

For `BalanceTransaction.retrieve/3`, drop the runtime `if` and use
clause heads matching the phase convention:

```elixir
def retrieve(client, id, opts \\ [])

def retrieve(%Client{}, id, _opts) when id in [nil, ""] do
  raise ArgumentError,
        "BalanceTransaction.retrieve/3 requires a non-empty balance_transaction id"
end

def retrieve(%Client{} = client, id, opts) when is_binary(id) do
  %Request{method: :get, path: "/v1/balance_transactions/#{id}", params: %{}, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end
```

Apply the symmetric fix to `update!/4` and `retrieve!/3`. This also
removes the `is_binary(id)` guard on the bang variants, which currently
swallows the `nil` contract a second time.

## Info

### IN-01: `BankAccount` moduledoc mentions `account_number` but struct has no such field

**File:** `lib/lattice_stripe/bank_account.ex:17-19`

**Issue:** The PII section reads "`account_number` (if ever present —
Stripe normally strips it after tokenization)". The struct does not
define `:account_number`, `@known_fields` does not include it, and
`cast/1` does not map it (it would flow into `:extra` if Stripe ever
sent it). The hide-list documentation promises a protection that is
actually defensive-by-omission. This is not wrong per se, but a reader
grepping for `account_number` in the source will come up empty and may
mistakenly add it to `defstruct` "for completeness", breaking the PII
guarantee.

**Fix:** Reword to make the defensive-by-omission explicit:

```elixir
# The struct intentionally does NOT define an :account_number field —
# Stripe strips the raw number after tokenization, and if a future API
# version ever returned it, it would flow into :extra (never into
# :inspect output). Never add :account_number to defstruct.
```

### IN-02: Inconsistent `nil`/`""` guard style across Phase 18

**File:** multiple — see below

**Issue:** Three different idioms for the pre-network id check coexist:

1. `ExternalAccount` uses a private `validate_id!/2` helper
   (external_account.ex:272).
2. `Charge` and `Payout` use separate function clauses for `nil` and
   `""` (charge.ex:210-215, payout.ex:212-216, payout.ex:291-295).
3. `Transfer` and `TransferReversal` use `when id in [nil, ""]` in a
   single clause (transfer.ex:181, transfer_reversal.ex:125).

All three are correct and produce the same contract. They are just a
style drift that will make future maintenance noisier (grep for the
error message won't be consistent, and PR reviews will ping on style).

**Fix:** Pick one convention (probably the `when id in [nil, ""]` style
— it is the most concise and is used by the two newest modules) and
apply in a follow-up cleanup commit. Not blocking for Phase 18 ship.

### IN-03: `ExternalAccount.Unknown.cast/1` hardcodes string keys instead of deriving from `@known_fields`

**File:** `lib/lattice_stripe/external_account/unknown.ex:18, 35`

**Issue:** `@known_fields` is the atom list `~w(id object)a` (line 18),
but `cast/1` drops via the literal string list `["id", "object"]`
(line 35). If a future change adds a field to `@known_fields`, the
`Map.drop/2` call will silently go stale and stash the new field in
`:extra`. Every other module in the phase derives the drop list from
`@known_fields` (see `balance/amount.ex:31`, `balance/source_types.ex:27`,
`balance_transaction/fee_detail.ex:34`, `payout/trace_id.ex:52`).

**Fix:**

```elixir
def cast(map) when is_map(map) do
  known_string_keys = Enum.map(@known_fields, &Atom.to_string/1)
  {known, extra} = Map.split(map, known_string_keys)

  %__MODULE__{
    id: known["id"],
    object: known["object"],
    extra: extra
  }
end
```

### IN-04: `Payout.update/4` and `update!/4` `when is_binary(id)` guard hides params misuse

**File:** `lib/lattice_stripe/payout.ex:231, 355`

**Issue:** Related to WR-03 but separate stylistic point: the current
head also lacks a `is_map(params)` guard. `Transfer.update/4`
(transfer.ex:209) guards both id and params (`is_binary(id) and
is_map(params)`); `Payout.update/4` guards only the id. Passing a
keyword list as `params` would crash deeper in `Client.request` rather
than at the API boundary.

**Fix:** Match the `Transfer.update/4` guard style once WR-03 is
addressed:

```elixir
def update(%Client{} = client, id, params, opts)
    when is_binary(id) and is_map(params) do
  ...
end
```

### IN-05: `Transfer.from_map/1` falls through silently if `reversals` is a non-map non-`nil` value

**File:** `lib/lattice_stripe/transfer.ex:257-272`

**Issue:** `raw_reversals = map["reversals"] || %{}` defaults to an
empty map when absent, but if Stripe ever returned `reversals: false`
or `reversals: "some string"` (unlikely but not impossible in API
drift), both `case` blocks fall through to the catch-all and the field
is silently stripped — no trace in `:extra`, no error. This is a
forward-compat edge case and unlikely to fire, but the F-001
guarantee ("no data is silently lost") is technically violated for
this single field.

**Fix:** Keep the unexpected raw value in `extra["reversals_raw"]`:

```elixir
{reversal_structs, reversals_meta, reversals_raw} =
  case map["reversals"] do
    %{"data" => data} = m when is_list(data) ->
      {Enum.map(data, &TransferReversal.from_map/1), Map.drop(m, ["data"]), nil}

    %{} = m ->
      {[], Map.drop(m, ["data"]), nil}

    nil ->
      {[], %{}, nil}

    other ->
      {[], %{}, other}
  end
```

and stash `reversals_raw` under `extra["reversals_raw"]` when non-nil.
Low priority — the realistic Stripe wire format always matches the
first two clauses.

---

_Reviewed: 2026-04-12_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
