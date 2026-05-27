---
phase: 47-thin-event-sdk-surface-webhook-reconciliation
reviewed: 2026-05-27T00:00:00Z
depth: standard
files_reviewed: 16
files_reviewed_list:
  - lib/lattice_stripe/event.ex
  - lib/lattice_stripe/event_notification.ex
  - lib/lattice_stripe/event_notification/related_object.ex
  - lib/lattice_stripe/object_types.ex
  - lib/lattice_stripe/testing.ex
  - lib/lattice_stripe/webhook.ex
  - lib/lattice_stripe/webhook/plug.ex
  - test/lattice_stripe/docs_truth_test.exs
  - test/lattice_stripe/event_notification_test.exs
  - test/lattice_stripe/event_test.exs
  - test/lattice_stripe/object_types_test.exs
  - test/lattice_stripe/testing_test.exs
  - test/lattice_stripe/webhook/fetch_test.exs
  - test/lattice_stripe/webhook/plug_test.exs
  - test/lattice_stripe/webhook_test.exs
  - test/support/fixtures/event_notification.ex
findings:
  critical: 0
  warning: 5
  info: 4
  total: 9
status: issues_found
---

# Phase 47: Code Review Report

**Reviewed:** 2026-05-27
**Depth:** standard
**Files Reviewed:** 16
**Status:** issues_found

## Summary

Phase 47 adds the thin-event SDK surface (`Webhook.parse_event_notification/4`, `fetch_event/3`, `fetch_related_object/3`), the `%EventNotification{}` + `%RelatedObject{}` struct pair, the WEBFIX-01 four-surface reconciliation for `tolerance: 0`, and `Testing.generate_thin_event_payload/3` + `Testing.event_notification/1` helpers.

The **security-critical surface is sound**: HMAC verification still funnels through the unchanged `verify_signature/4` primitive, `Plug.Crypto.secure_compare/2` is preserved for timing-safe comparison, the typed-error fail-fast contract (`{:unknown_object_type, type}`, `:no_event_id`, `:no_related_object`) is implemented correctly with Mox `:verify_on_exit!` enforcing zero HTTP traffic on the typed-error paths, and the four-surface reconciliation (docstring, code clause, Plug NimbleOptions schema, tests) is internally consistent.

No critical/blocker issues were found. Findings cluster around (1) defensive degradation when input maps are partially populated (`type: nil` related-object payloads), (2) two `Jason.decode!` boundaries that fail loudly post-verification rather than returning typed errors, (3) one cross-helper inconsistency in how `:timestamp` opts map onto the `created` wire field between the snapshot and thin-event helpers, and (4) a small set of documentation/typespec drifts.

## Narrative Findings (AI reviewer)

### Warnings

#### WR-01: `fetch_related_object/3` emits non-string `type` in typed error tuple

**File:** `lib/lattice_stripe/webhook.ex:452-453`
**Issue:** When `notification.related_object.type` is `nil` (e.g., a thin-event payload whose `related_object` is `%{"id" => "...", "url" => "..."}` with no `type`), `ObjectTypes.fetch_module(nil)` correctly returns `:error`, and `fetch_related_object/3` returns `{:error, {:unknown_object_type, nil}}`. The `@spec` at line 430 declares the second tuple element as `String.t()`, so the runtime value `nil` violates the contract that downstream pattern-matchers (and the bang variant) rely on.

The bang variant at `webhook.ex:485-489` interpolates the value into a message string — when `type == nil`, the raised exception carries `message: "Unknown Stripe object type: "` (trailing colon + nothing), which is unhelpful and inconsistent with the `Unknown Stripe object type: v2.core.account` message the test fixture proves.

**Fix:**
```elixir
case ObjectTypes.fetch_module(type) do
  {:ok, _module} ->
    # ...
  :error ->
    {:error, {:unknown_object_type, type || "(missing)"}}
end
```
Or guard the function head to only accept binary `type`:
```elixir
def fetch_related_object(
      %Client{} = _client,
      %EventNotification{related_object: %RelatedObject{type: nil}},
      _opts
    ),
    do: {:error, :no_related_object}
```
The second form is preferable because a `related_object` with no `type` is functionally equivalent to no related_object — it cannot be dispatched, and the existing `:no_related_object` semantics already cover the "cannot dispatch" path. Add a test that builds an `EventNotification` whose `related_object.type` is nil and asserts the chosen error atom.

---

#### WR-02: `parse_event_notification/4` and `construct_event/4` raise on malformed JSON instead of returning a typed error

**File:** `lib/lattice_stripe/webhook.ex:229-231` (new code), `lib/lattice_stripe/webhook.ex:130-133` (pre-existing pattern)
**Issue:** Both `construct_event/4` (pre-existing) and `parse_event_notification/4` (new in Phase 47) call `Jason.decode!/1` on the verified payload. When Stripe-signed payloads are valid JSON this is safe, but the four documented `verify_error()` atoms (`:missing_header`, `:invalid_header`, `:no_matching_signature`, `:timestamp_expired`) plus the typed `{:ok, struct()}` return shape are the entire documented contract — a future `:invalid_payload` (or `Jason.DecodeError`) is reachable from a degraded Stripe response and bypasses the typed-error contract that adopters' supervisors and `with` chains rely on.

The new `parse_event_notification/4` inherits this hazard verbatim from `construct_event/4`. Since this is the first time the SDK is shipping two webhook entry points that share the verify+decode shape, now is the cheapest time to make the boundary fail predictably.

**Fix:** Replace `Jason.decode!/1` with `Jason.decode/1` and return a typed error on failure:
```elixir
case verify_signature(payload, sig_header, secret, opts) do
  {:ok, _timestamp} ->
    case Jason.decode(payload) do
      {:ok, decoded} -> {:ok, EventNotification.from_map(decoded)}
      {:error, _} -> {:error, :invalid_payload}
    end

  {:error, _reason} = error ->
    error
end
```
Extend `@type verify_error` to include `:invalid_payload` and add an entry to the bang-variant `case` so the exception's `:reason` field reflects the new atom. Apply the same change to `construct_event/4` for parity. Add a regression test that signs a known-garbage payload with the correct secret and asserts `{:error, :invalid_payload}` rather than `Jason.DecodeError`.

---

#### WR-03: `Testing.generate_thin_event_payload/3` and `generate_webhook_payload/3` disagree on whether `:timestamp` opt drives the `created` wire field

**File:** `lib/lattice_stripe/testing.ex:234` (snapshot) vs. `lib/lattice_stripe/testing.ex:313-314` (thin)
**Issue:** `generate_thin_event_payload/3` derives `created_iso` from the `:timestamp` opt:
```elixir
created_iso = DateTime.from_unix!(timestamp) |> DateTime.to_iso8601()
```
So the signed `t=` value and the JSON `created` field are guaranteed to agree (the tests at `testing_test.exs:168-185` and the test docstring lock this in).

`generate_webhook_payload/3` (snapshot helper) does NOT do this. At line 234 it hard-codes `"created" => System.system_time(:second)` regardless of the `:timestamp` opt. A user passing `timestamp: old_ts` to test a stale-signature scenario gets a payload whose body says "created at NOW" while the signature header says "signed at OLD_TS". This is harmless for verify-side tests (the staleness check reads `t=` from the header) but is surprising when an adopter test does `assert decoded_payload["created"] == ts` after signing with a fixed timestamp — a contract the thin-event helper provides but the snapshot one silently doesn't.

**Fix:** Mirror the thin-event approach so the two helpers behave the same way:
```elixir
def generate_webhook_payload(type, object_data \\ %{}, opts) do
  {secret, opts} = Keyword.pop!(opts, :secret)
  {timestamp, event_opts} = Keyword.pop(opts, :timestamp, System.system_time(:second))
  # ... rest of opts handling ...

  raw_map = %{
    # ...
    "created" => timestamp,  # was: System.system_time(:second)
    # ...
  }

  payload = Jason.encode!(raw_map)
  sig_header = Webhook.generate_test_signature(payload, secret, timestamp: timestamp)
  {payload, sig_header}
end
```
Add a regression test analogous to the thin-event one at `testing_test.exs:168-185` asserting `Jason.decode!(payload)["created"] == fixed_ts`.

---

#### WR-04: Public `:tolerance` docstring on `Webhook.Plug` doesn't surface the `0` semantics

**File:** `lib/lattice_stripe/webhook/plug.ex:116`
**Issue:** The module docstring "Configuration Options" section lists:
```
- `:tolerance` — Maximum age of the webhook timestamp in seconds (default: 300).
```
The NimbleOptions schema doc at line 145-146 now says "Set 0 to disable the staleness check (testing only)", and the `Webhook.construct_event/4` docstring at lines 114-117 documents the `0` semantics, but the public Plug `@moduledoc` — which is what HexDocs renders on the webhook landing page — silently drops the new contract. Adopters reading the Plug docs first will not learn that `tolerance: 0` is a supported escape hatch.

This matters specifically because WEBFIX-01's whole point was four-surface reconciliation: docstring + code clause + Plug schema + tests. The Plug schema doc string changed, but the Plug **module docstring** did not.

**Fix:** Extend the line at `plug.ex:116`:
```
- `:tolerance` — Maximum age of the webhook timestamp in seconds (default: 300).
  Set `0` to disable the staleness check (testing only — see the inline comment
  on `LatticeStripe.Webhook.check_tolerance/2` and the v1.5 CHANGELOG WEBFIX-01 entry).
```
Consider adding a `docs_truth_test.exs` assertion that the public Plug `@moduledoc` mentions `tolerance: 0` and `testing only` — same regression-prevention pattern as the existing WEBFIX-01 CHANGELOG grep test at `docs_truth_test.exs:175-186`.

---

#### WR-05: `RelatedObject` Inspect impl can leak credential-shaped fields via `:extra`

**File:** `lib/lattice_stripe/event_notification/related_object.ex:93-98`
**Issue:** The `Inspect` impl on `RelatedObject` shows `:extra` whenever the map is non-empty:
```elixir
fields =
  if obj.extra == %{} do
    base_fields
  else
    base_fields ++ [extra: obj.extra]
  end
```
The parent `EventNotification` Inspect impl correctly hides its own `:extra` map (per the test at `event_notification_test.exs:99-110` and Pitfall 4 security regression test at `event_notification_test.exs:121-139`) and the related test for `EventNotification` rightly asserts that credential-shaped strings stuffed into `extra` do not appear in the inspect output.

But if a future Stripe wire payload ships an unknown sub-field on the `related_object` object (e.g., `"api_key" => "sk_live_..."` — implausible but the wire format is what it is), `EventNotification.inspect/2` shows `related_object: %RelatedObject{...}` at line 158, which recursively renders the `RelatedObject` inspect impl, which shows `extra:` with the leaky value. The Pitfall 4 protection on the outer struct is bypassed via the inner struct's looser Inspect rule.

**Fix:** Either hide `RelatedObject.extra` unconditionally (matching `EventNotification.extra` behavior):
```elixir
fields = base_fields
```
…or add the same Pitfall 4 security regression test against `RelatedObject` directly (stuff a credential-shaped string into `related_object.extra` and assert `inspect/1` does not surface it). The conservative fix is unconditional hiding — `related_object.extra` is by definition "unknown fields not in the documented Stripe wire format" and so cannot be relied on by adopters, and the security cost of surfacing it is non-zero while the debugging cost of hiding it is near-zero (adopters can always `IO.inspect(obj, structs: false)` or pattern-match `obj.extra` directly).

---

### Info

#### IN-01: `Event.@type t :created` typespec is `integer() | nil` but v2-fetched events ship an ISO 8601 string

**File:** `lib/lattice_stripe/event.ex:101` (typespec) and `lib/lattice_stripe/webhook.ex:283-293` (acknowledged in docstring)
**Issue:** The `created` field's typespec on `LatticeStripe.Event` is `integer() | nil`, but the `fetch_event/3` docstring at `webhook.ex:283-293` openly acknowledges that v2-fetched events ship `created` as an ISO 8601 string (e.g., `"2026-03-09T13:00:28.435Z"`). Per project constraint "No Dialyzer — typespecs are documentation-only", the runtime behavior is unaffected, but the typespec is now actively misleading on a documented field for one of the two `fetch_event/3` code paths.

The Phase 47 docstring at line 293 also mentions a "Phase 47 Open Question 2" widening the typespec. Either widen now to `integer() | String.t() | nil`, or convert the type to a sum description (`unix_seconds :: integer()` + `iso8601_string :: String.t()` + `nil`) so consumers writing pattern matches against `event.created` get an accurate documentation surface.

**Fix:**
```elixir
@type t :: %__MODULE__{
        # ...
        created: integer() | String.t() | nil,
        # ...
      }
```
Update the inline doc comment in `@typedoc` at lines 80-94 to match (the `created` bullet at line 82 currently says "Unix timestamp" only).

---

#### IN-02: `Webhook.compute_signature/3` and `secure_compare/2` use is OK; hex-comparison is intentionally conservative

**File:** `lib/lattice_stripe/webhook.ex:682-687`
**Issue:** `compute_signature/3` produces a 64-char lowercase hex string. Comparing two equal-length lowercase hex strings via `Plug.Crypto.secure_compare/2` is strictly correct (timing-safe) but slightly heavier than `==` since both sides are always the same length and the alphabet is fixed.

This is a code-style observation, not a defect. `secure_compare/2` is the right call for HMAC comparison — it future-proofs against any code-path that ever produces variable-length output, and the cost is microscopic. No fix needed; flagged here only to confirm the choice was reviewed.

**Fix:** None required.

---

#### IN-03: `Testing.generate_test_signature/3` accepts non-binary `secret` via Erlang iodata

**File:** `lib/lattice_stripe/webhook.ex:580-585`
**Issue:** `generate_test_signature/3` has `when is_binary(payload)` but no guard on `secret`. The downstream `:crypto.mac(:hmac, :sha256, secret, signed_payload)` accepts any iodata for the key, so passing a list, iolist, or charlist "works" at runtime. The `@spec` declares `String.t()` only. This is documented-as-binary, runtime-accepts-iodata drift — harmless but a future contributor could write `Webhook.generate_test_signature(payload, ~c"secret", [])` and not get any feedback.

**Fix:** Add the guard:
```elixir
def generate_test_signature(payload, secret, opts \\ [])
    when is_binary(payload) and is_binary(secret) do
```
This is consistent with `normalize_secrets/1` which already requires `is_binary(secret) or is_list(secrets)` for the verify path.

---

#### IN-04: `fetch_related_object/3` uses `related_object.url` verbatim as a request path — trust is anchored solely in the verified signature

**File:** `lib/lattice_stripe/webhook.ex:445`
**Issue:** The line:
```elixir
%Request{method: :get, path: url, params: %{}, opts: opts}
```
uses whatever URL Stripe shipped in the verified payload as the request path. This is correct — the HMAC signature is the security boundary, and Stripe's signed payload is authoritative — but it does mean a future code change that bypasses signature verification (e.g., a `fetch_related_object_unverified/3` debug helper) would inherit a "trust the URL field" property that's only safe in the verified context. The current docstring section "Typed-error contract (Phase 47 D-05 + D-07)" at lines 380-390 does not explicitly call this out.

**Fix:** Optional — add a short paragraph to the `fetch_related_object/3` docstring noting that `related_object.url` is trusted because it arrives via a verified payload, and that this function should never be called with a hand-constructed `EventNotification` that wasn't returned by `parse_event_notification/4`.

---

_Reviewed: 2026-05-27_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
