---
phase: 15
reviewed_at: 2026-04-12
depth: standard
files_reviewed: 21
findings_total: 8
critical: 0
high: 1
medium: 3
low: 2
info: 2
---

# Phase 15 Code Review

## Summary

Phase 15 delivers a well-structured, idiomatic Elixir SDK surface for Stripe Subscriptions and SubscriptionItems. The code follows the Invoice precedent closely: `@known_fields` + `extra` on every struct, defensive `from_map/nil` guards, custom `Inspect` implementations masking PII, proration guard wired to all five mutation paths, and correct `List.stream!/2` usage for both standard and search pagination. Security threat mitigations T-15-01 through T-15-05 are correctly implemented. No hardcoded secrets, no debug artifacts, no `Jason.Encoder` derivation. One high-severity finding: `AutomaticTax` has no `extra` field or `@known_fields` splitting, meaning unknown future fields from Stripe are silently dropped when decoded in the Subscription context — but this is an inherited limitation from Phase 14 rather than a new regression introduced here. The proration guard extension for `items[]` arrays is correct and well-tested. The main gap is thin unit-test coverage for several bang variants (`pause_collection!`, `resume!`, `list!`, `stream!`) and a stale arity reference in an error string.

---

## Findings

### [HIGH] F-001 — `AutomaticTax` silently drops unknown fields when reused in Subscription context

**File:** `lib/lattice_stripe/invoice/automatic_tax.ex:52-58`
**Category:** correctness / forward-compatibility

**Evidence:**
```elixir
def from_map(map) when is_map(map) do
  %__MODULE__{
    enabled: map["enabled"],
    liability: map["liability"],
    status: map["status"]
  }
end
```

`AutomaticTax` has no `@known_fields` / `extra` split. It has no `extra` field at all in its struct. Any unknown key Stripe adds to the `automatic_tax` object (Stripe has added fields to this object in prior API versions) is silently discarded with no trace in the decoded struct. This affects Subscription objects that carry `automatic_tax` because `Subscription.from_map/1` delegates directly to `AutomaticTax.from_map/1` at line 448. Users who rely on a future `automatic_tax` subfield will get `nil` and no indication anything was dropped.

This is an inherited deficiency from Phase 14 that Phase 15 carries forward without comment. The Phase 15 code correctly reuses `AutomaticTax`, but the reuse amplifies the risk because Subscriptions are the primary billing object — logs/observability will not surface the loss.

**Fix:** Add `extra` field and `@known_fields` / `Map.split` to `AutomaticTax`, following the `PauseCollection` pattern:

```elixir
@known_fields ~w[enabled liability status]

defstruct [:enabled, :liability, :status, extra: %{}]

def from_map(map) when is_map(map) do
  {known, extra} = Map.split(map, @known_fields)
  %__MODULE__{
    enabled: known["enabled"],
    liability: known["liability"],
    status: known["status"],
    extra: extra
  }
end
```

Note: this fix belongs in `lib/lattice_stripe/invoice/automatic_tax.ex` and should be done as a followup to keep Phase 15 commits clean.

---

### [MEDIUM] F-002 — `search_stream!` bang variant missing `@doc` tag

**File:** `lib/lattice_stripe/subscription.ex:404`
**Category:** code quality / documentation

**Evidence:**
```elixir
@doc """
Returns a lazy stream of all Subscriptions matching a search query.

Requires `"query"` in params. Raises on fetch failure.
"""
@spec search_stream!(Client.t(), map(), keyword()) :: Enumerable.t()
def search_stream!(%Client{} = client, params, opts \\ []) do
```

`search_stream!` has its own `@doc` (correct), but the doc body does not note the bang semantics — it doesn't clarify what "Raises on fetch failure" means relative to the non-bang counterpart (there is no `search_stream/3` tuple-returning variant). A user scanning the docs will be puzzled about the `!` convention because there's no tuple-returning `search_stream/3` to pair it with. This is different from the `stream!` vs `list` pairing where `list` returns `{:ok, _}` and `stream!` raises.

**Fix:** Revise the doc to make the raise semantics explicit and note there is no non-bang search_stream:

```elixir
@doc """
Returns a lazy stream of all Subscriptions matching a search query.

Requires `"query"` in params. Each page fetch raises `LatticeStripe.Error`
on failure (there is no tuple-returning `search_stream/3` variant — streaming
is inherently eager across pages and cannot return `{:ok, _}` for mid-stream
errors).
"""
```

---

### [MEDIUM] F-003 — `SubscriptionItem.stream!/2` arity label is wrong in error message and moduledoc

**File:** `lib/lattice_stripe/subscription_item.ex:15`, `lib/lattice_stripe/subscription_item.ex:215`
**Category:** correctness / documentation

**Evidence (line 15):**
```elixir
`list/3` and `stream!/2` require the `"subscription"` param
```

**Evidence (line 215):**
```elixir
~s|SubscriptionItem.stream!/2 requires a "subscription" key in params.|
```

The function signature is:
```elixir
def stream!(%Client{} = client, params, opts \\ [])
```

This is a 3-arity function (`stream!/3`). It is callable as `stream!(client, params)` with `opts` defaulting to `[]`, but the canonical arity per Elixir convention is the maximum defined arity — `stream!/3`. When a user searches `h SubscriptionItem.stream!` in IEx or reads the error message at runtime, they'll see a 3-arity spec but the error message says `stream!/2`, causing confusion.

**Fix:**
```elixir
# @moduledoc line 15:
`list/3` and `stream!/3` require the `"subscription"` param

# Error message line 215:
~s|SubscriptionItem.stream!/3 requires a "subscription" key in params.|
```

---

### [MEDIUM] F-004 — Unit tests for bang variants are incomplete: `pause_collection!`, `resume!`, `list!`, `stream!` have no unit-level coverage

**File:** `test/lattice_stripe/subscription_test.exs`
**Category:** test quality

**Evidence:** The `describe "bang variants"` block only covers `create!` success and `create!` raises-on-error:

```elixir
describe "bang variants" do
  test "create! returns %Subscription{} on success" do ...
  test "create! raises on error" do ...
end
```

`pause_collection!`, `resume!`, `list!`, `stream!`, `update!`, `retrieve!`, `cancel!`, `search!`, `search_stream!` have no dedicated bang-variant unit tests. The standard pattern in this codebase (see `invoice_test.exs`) covers at least a success path for each bang variant.

The gap is most notable for `pause_collection!` and `resume!` — these are lifecycle-critical paths that users will call in production, and no unit test exercises the raise path or verifies the delegate chain `pause_collection! -> pause_collection -> update -> Resource.unwrap_bang!`.

**Fix:** Add bang-variant tests for at minimum `pause_collection!`, `resume!`, and `cancel!`. Pattern from `create!`:

```elixir
test "pause_collection! raises on error" do
  client = test_client()
  expect(LatticeStripe.MockTransport, :request, fn _req -> error_response() end)
  assert_raise Error, fn ->
    Subscription.pause_collection!(client, "sub_test1234567890", :keep_as_draft)
  end
end
```

---

### [LOW] F-005 — `cancel/3` and `cancel/4` share a `@doc` only on the 3-arity head; `cancel/4` has `@doc` but is the second clause on the same function, and `cancel!` has two separate `@doc` tags

**File:** `lib/lattice_stripe/subscription.ex:261-290`
**Category:** code quality / documentation consistency

**Evidence:**
```elixir
@doc """
Cancels a Subscription.
...
The 3-arity form is a convenience for `cancel(client, id, %{}, opts)`.
"""
@spec cancel(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
def cancel(%Client{} = client, id, opts \\ []) ...

@spec cancel(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
def cancel(%Client{} = client, id, params, opts) ...
```

The `@doc` is only on the first clause. This is actually Elixir-idiomatic (first clause carries the doc), so this is not wrong. However, the two `cancel!` `@doc` tags at lines 281 and 286 are redundant — in Elixir, only the first `@doc` before a function name applies; the second `@doc` for `cancel!/4` will shadow or cause a compiler warning since the same function name already has a doc.

**Fix:** Verify whether this causes a compiler warning under `mix compile --warnings-as-errors`. If it does, merge the two `@doc` strings for `cancel!` into one on the first clause and remove the second:

```elixir
@doc "Like `cancel/3` and `cancel/4` but raises on failure."
@spec cancel!(Client.t(), String.t(), keyword()) :: t()
def cancel!(%Client{} = client, id, opts \\ []) ...

@spec cancel!(Client.t(), String.t(), map(), keyword()) :: t()
def cancel!(%Client{} = client, id, params, opts) ...
```

---

### [LOW] F-006 — `SubscriptionItem` `@moduledoc` references `stream!/2` in listing requirements section but the spec shows `stream!/3`

**File:** `lib/lattice_stripe/subscription_item.ex:210`
**Category:** documentation

**Evidence:**
```elixir
@spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
```

The spec correctly shows 3-arity, but the `@moduledoc` at line 15 says `stream!/2`. This is the same root issue as F-003 but the spec and doc disagree within the same file.

This is grouped with F-003 for the fix — both occurrences need updating together.

---

### [INFO] F-007 — `Subscription.stream!/3` has no unit test at all (not even a guard test)

**File:** `test/lattice_stripe/subscription_test.exs`
**Category:** test coverage observation

`Subscription.stream!` is covered in the integration test (`subscription_integration_test.exs:127`) but has no unit-level test. `search_stream!` at least has a guard test (line 410-418). For a function that auto-paginates (and will raise on page-fetch failure mid-stream), having a unit test verifying the happy-path structure `[%Subscription{}]` would be consistent with the Invoice test style. This is informational — integration coverage exists.

---

### [INFO] F-008 — `SubscriptionItem` `Inspect` shows `subscription` ID in plain text

**File:** `lib/lattice_stripe/subscription_item.ex:268-284`
**Category:** PII / security observation

**Evidence:**
```elixir
base = [
  id: item.id,
  object: item.object,
  subscription: item.subscription,   # exposed raw
  quantity: item.quantity,
  metadata: metadata_repr,
  billing_thresholds: billing_repr
]
```

`subscription` is a Stripe subscription ID (`sub_...`), which is not itself PII. However, it does expose which subscription an item belongs to — in a multi-tenant environment, logging a `SubscriptionItem` would reveal the parent subscription ID. The threat model (T-15-01) does not specifically require masking this field, and it is arguably analogous to `id` (a resource identifier, not personal data). Flagged as INFO rather than HIGH because Stripe subscription IDs are not personally identifiable.

If a decision is made to mask it, the pattern is:
```elixir
subscription: item.subscription   # keep as-is (safe ID)
# OR, if masking is desired:
has_subscription?: not is_nil(item.subscription)
```

No action required — this is for the team to decide.

---

## Praise (what went well)

- **Proration guard coverage is excellent.** The `guards_test.exs` covers all the tricky edge cases: `items[]` with proration, `items[]` without, empty list, non-map elements, mixed list, and the `subscription_details` nesting. This is exactly what T-15-03 required.
- **PII masking is thorough and correct.** `Subscription` hides `customer`, `payment_settings`, `default_payment_method`, and `latest_invoice`. `CancellationDetails` masks `comment` as `"[FILTERED]"` with a clear doc warning. `SubscriptionItem` masks `metadata` as `:present`. All Inspect implementations follow the Invoice precedent faithfully.
- **`decode_items/1` preserves `id` on nested SubscriptionItems.** The regression guard against the stripity_stripe #208 bug is correctly implemented, documented, and tested — including the unit test asserting `item1.id == "si_test1"` without depending on `%SubscriptionItem{}` pattern match (which could fail if modules load out of order).
- **`pause_collection/5` function-head guard.** Using `behavior in [:keep_as_draft, :mark_uncollectible, :void]` at the function head is idiomatic and correct. The test verifying `FunctionClauseError` on invalid atoms is present.
- **Idempotency key tests.** Every mutation function has a dedicated idempotency_key forwarding test asserting on the header value. T-15-02 is well-covered.
- **`@known_fields` + `extra` on all 3 new nested structs.** `PauseCollection`, `CancellationDetails`, and `TrialSettings` all follow the pattern correctly.
- **mix.exs wiring is complete.** Billing module group includes all 5 new modules (`Subscription`, `CancellationDetails`, `PauseCollection`, `TrialSettings`, `SubscriptionItem`, `Billing.Guards`). `guides/subscriptions.md` is in extras. No duplicate entries, no new runtime deps.
- **Webhook handoff callout in guide.** The "Webhooks own state transitions" section in `guides/subscriptions.md` is prominent, actionable, and lists the exact event names users need to wire up (T-15-04 satisfied).
- **No `Jason.Encoder` derivation.** All structs use custom `Inspect` via `defimpl`. No `@derive [Jason.Encoder]` anywhere.
- **No `IO.inspect`, `debugger`, `TODO`, or `FIXME` in any new file.**

---

## Recommendations for Phase 16+

- **Fix `AutomaticTax` (F-001) before Phase 16.** Subscription Schedules in Phase 16 will also use `AutomaticTax` if schedules carry it. A quick `@known_fields` + `extra` addition to `invoice/automatic_tax.ex` eliminates silent field-dropping across both Invoice and Subscription contexts.
- **Add bang variant unit tests (F-004) to close the test pattern.** The missing tests for `pause_collection!`, `resume!`, and `cancel!` are a 15-minute fill. The integration tests exercise the paths, but unit coverage at the Mox level is faster to run and easier to debug.
- **Standardize arity labels in error strings (F-003).** A credo custom check or a simple grep CI gate (`grep -r "stream!/2" lib/`) would prevent future recurrence across the growing module surface.
- **Decide on `subscription` field masking in SubscriptionItem Inspect (F-008)** before the codebase grows. Consistent policy now avoids revisiting 20 Inspect implementations later.
