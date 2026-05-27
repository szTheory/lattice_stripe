---
phase: 48-thin-event-adoption-surface-guide-integration-verification
reviewed: 2026-05-27T00:00:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - CHANGELOG.md
  - README.md
  - guides/user-flows-and-jtbd.md
  - guides/webhooks-thin-events.md
  - guides/webhooks.md
  - lib/lattice_stripe/webhook/plug.ex
  - mix.exs
  - test/lattice_stripe/docs_truth_test.exs
  - test/lattice_stripe/webhook/thin_event_test.exs
findings:
  critical: 2
  warning: 2
  info: 1
  total: 5
status: issues_found
---

# Phase 48: Code Review Report

**Reviewed:** 2026-05-27T00:00:00Z
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Phase 48 ships GUIDE-03 (canonical thin-event adopter guide), VERIFY-03 (chained integration
test suite for thin-event helpers), and closes Phase 47 WR-04 (Webhook.Plug @moduledoc
tolerance: 0 documentation). The underlying parse/verify/fetch implementation is Phase 47
work and is out of scope. This review focuses on the new guide content, test file, docs-truth
test, plug documentation, and supporting mix/README/CHANGELOG surface.

The Elixir source (`plug.ex`, `thin_event_test.exs`, `docs_truth_test.exs`) is generally
clean and well-structured. Two critical issues are present in the Phoenix controller example
in `guides/webhooks-thin-events.md`: a function-call contract mismatch that causes
`FunctionClauseError` at runtime, and a compile-time secret anti-pattern that conflicts with
Elixir release best practices. Both exist only in the guide, but guides are production
artifacts — the purpose of GUIDE-03 is precisely that adopters copy these patterns.

---

## Critical Issues

### CR-01: `claim/1` called with string `id` but defined to accept `%EventNotification{}`

**File:** `guides/webhooks-thin-events.md:70`

**Issue:** The Phoenix controller spine example contains a direct contract mismatch between
the call site and the function definition shown two sections later in the same guide:

```
# dispatch/2 extracts `id` from the struct and passes the STRING:
defp dispatch(client, %EventNotification{id: id} = notif) do
  case MyApp.Stripe.IdempotentEvents.claim(id) do        # <-- passes String.t()
    :ok                -> dispatch_typed(client, notif)
    :already_processed -> :ok
  end
end

# But IdempotentEvents.claim/1 pattern-matches on the full struct:
def claim(%LatticeStripe.EventNotification{id: id, type: type}) do  # <-- expects struct
  ...
end
```

Any adopter who copies both snippets verbatim gets a `FunctionClauseError` at runtime on
the first webhook delivery. Stripe's delivery retry will exhaust before this is noticed in
test environments that mock the upstream call.

**Fix:** Either pass the full `notif` struct to `claim/1`, or change `claim/1`'s parameter
to accept a string:

Option A — pass the struct (preferred; the struct carries `type` needed for the DB insert):
```elixir
# In dispatch/2:
case MyApp.Stripe.IdempotentEvents.claim(notif) do
```

Option B — accept a string in `claim/1` (loses `type` tracking):
```elixir
def claim(event_id) when is_binary(event_id) do
  ...
end
```

---

### CR-02: Compile-time secret evaluation in guide controller — conflicts with Elixir release idiom

**File:** `guides/webhooks-thin-events.md:51`

**Issue:** The Phoenix controller example uses a module attribute for the webhook secret:

```elixir
@secret System.fetch_env!("STRIPE_THIN_EVENT_SECRET")
```

`System.fetch_env!/1` inside a module attribute is evaluated at **compile time**, not at
runtime. This causes two problems:

1. **Compile-time failure:** If `STRIPE_THIN_EVENT_SECRET` is absent from the build
   environment (e.g., in CI, Docker image builds, or local development without env vars
   pre-loaded), the entire module fails to compile with a `System.EnvError`.

2. **Secret baked into BEAM bytecode:** In Mix releases (the standard production deployment
   pattern), `config/runtime.exs` and `System.fetch_env!` in application startup are the
   correct secret resolution points. A module-attribute evaluation bakes the secret value
   into the compiled `.beam` file, which contradicts standard Elixir release security
   hygiene.

The parent guide `guides/webhooks.md` consistently shows the runtime pattern (lines 62, 175):

```elixir
secret: {MyApp.BillingConfig, :stripe_webhook_secret, []}
# or
secret: fn -> System.fetch_env!("STRIPE_WEBHOOK_SECRET") end
```

The thin-events guide is inconsistent with the webhook guide it references and introduces
the footgun into what is positioned as the canonical adopter pattern.

**Fix:** Replace the module attribute with a zero-arity function call at use time:

```elixir
defmodule MyAppWeb.StripeThinEventController do
  use MyAppWeb, :controller
  # Remove: @secret System.fetch_env!("STRIPE_THIN_EVENT_SECRET")

  def receive(conn, _params) do
    secret = Application.fetch_env!(:my_app, :stripe_thin_event_secret)
    # or: System.fetch_env!("STRIPE_THIN_EVENT_SECRET") called HERE, at runtime
    raw_body = conn.private[:raw_body] || ""
    sig_header = conn |> get_req_header("stripe-signature") |> List.first()

    with {:ok, %EventNotification{} = notif} <-
           Webhook.parse_event_notification(raw_body, sig_header, secret),
    ...
  end
end
```

---

## Warnings

### WR-01: Bare pattern matches on `fetch_related_object/fetch_event` in guide — crashes controller on fetch failure

**File:** `guides/webhooks-thin-events.md:79,86`

**Issue:** Both `dispatch_typed/2` branches in the guide example use bare (left-hand) matches
for the fetch calls:

```elixir
# Line 78-82 (fetch_related_object branch):
defp dispatch_typed(client, %EventNotification{...} = notif) do
  {:ok, %LatticeStripe.Customer{} = customer} =       # bare match — RAISES on {:error, _}
    Webhook.fetch_related_object(client, notif)
  ...
end

# Line 85-89 (fetch_event branch):
defp dispatch_typed(client, %EventNotification{related_object: nil} = notif) do
  {:ok, %LatticeStripe.Event{} = event} =             # bare match — RAISES on {:error, _}
    Webhook.fetch_event(client, notif)
  ...
end
```

Both `fetch_related_object/3` and `fetch_event/3` return `{:error, %Error{}}` on HTTP failure
(network timeout, Stripe 5xx, etc.). A bare match on that error tuple raises `MatchError`,
crashing the controller process. Because this happens INSIDE `dispatch/2` which is called
from the `with` pipeline, the exception propagates through the caller and is NOT handled by
the `with/else` block — the `else` only handles the 4 verify-error atoms from
`parse_event_notification/4`.

In a Phoenix application, the `ErrorHandler` will rescue and return 500, but Stripe
interprets any non-2xx response as delivery failure and retries. Without idempotency
correctly placed (see CR-01 above), retry re-delivery of a transient fetch failure causes
duplicate processing once Stripe eventually succeeds.

The guide presents `dispatch_typed` as the pattern adopters should follow. Bare matches
propagate the anti-pattern directly into production applications.

**Fix:** Use `case` expressions on the fetch calls to return a proper result instead of
raising:

```elixir
defp dispatch_typed(client, %EventNotification{
       related_object: %RelatedObject{type: "customer"}
     } = notif) do
  case Webhook.fetch_related_object(client, notif) do
    {:ok, %LatticeStripe.Customer{} = customer} ->
      MyApp.Workers.SyncCustomer.enqueue(customer)
      :ok
    {:error, reason} ->
      # Log and return {:error, reason} or re-raise depending on your retry strategy.
      # Returning {:error, _} causes the with/else to fall through — add a catch-all else
      # clause or raise explicitly so Phoenix returns 500 and Stripe retries.
      {:error, reason}
  end
end
```

Note that adding `{:error, reason}` return paths to `dispatch_typed` also requires adding a
catch-all else clause in `receive/2`'s `with` block (currently the else only handles the 4
verify-error atoms).

---

### WR-02: `LatticeStripe.EventNotification` and `RelatedObject` are absent from `groups_for_modules` in `mix.exs`

**File:** `mix.exs:206-212`

**Issue:** `LatticeStripe.EventNotification` and `LatticeStripe.EventNotification.RelatedObject`
are public modules with non-`false` `@moduledoc`, and they form the typed surface that adopters
pattern-match in thin-event handlers. They are not listed in the `Webhooks` group in
`groups_for_modules`:

```elixir
# mix.exs lines 206-212 — current state:
Webhooks: [
  LatticeStripe.Webhook,
  LatticeStripe.Webhook.Plug,
  LatticeStripe.Webhook.Handler,
  LatticeStripe.Webhook.SignatureVerificationError,
  LatticeStripe.Event
  # EventNotification and RelatedObject are MISSING
],
```

ExDoc will still generate pages for these modules but they will appear in the ungrouped
"Modules" sidebar section rather than in the "Webhooks" cluster. The thin-events guide,
`parse_event_notification/4` docstring, and `fetch_related_object/3` docstring all reference
`LatticeStripe.EventNotification` and `LatticeStripe.EventNotification.RelatedObject` by
name as public API. The discoverability gap is amplified because this is the adoption surface
for v1.5 thin events.

There is no test in `docs_truth_test.exs` that would catch this drift — the truth test only
covers `groups_for_extras`, not `groups_for_modules`.

**Fix:** Add both modules to the `Webhooks` group:

```elixir
Webhooks: [
  LatticeStripe.Webhook,
  LatticeStripe.Webhook.Plug,
  LatticeStripe.Webhook.Handler,
  LatticeStripe.Webhook.SignatureVerificationError,
  LatticeStripe.Event,
  LatticeStripe.EventNotification,
  LatticeStripe.EventNotification.RelatedObject
],
```

Optionally, add a `docs_truth_test.exs` assertion on `groups_for_modules` to lock this
against future drift.

---

## Info

### IN-01: `thin_event_test.exs` has no test for `fetch_related_object` returning `{:error, :no_related_object}` or `{:error, {:unknown_object_type, type}}`

**File:** `test/lattice_stripe/webhook/thin_event_test.exs`

**Issue:** The test suite covers the happy paths and verification failure modes well (DB1–DB5).
`fetch_related_object/3`'s two typed-error paths — `{:error, :no_related_object}` and
`{:error, {:unknown_object_type, type}}` — are documented in both the guide and the
`webhooks-thin-events.md` "verification-vs-payload-shape failure boundary" section as
important footguns for adopters, but neither is exercised in `thin_event_test.exs`.

These paths are exercised by unit tests for `Webhook` elsewhere (Phase 47 scope), but the
VERIFY-03 integration test file that specifically locks the chained thin-event flows does not
include a test that demonstrates the typed-error short-circuit behavior (zero HTTP calls for
unknown type, graceful `{:error, :no_related_object}` for nil related_object branch).

This is an incompleteness in the regression net for the surface GUIDE-03 teaches, not a bug
in the implementation.

**Fix:** Add two describe blocks to `thin_event_test.exs`:

```elixir
describe "fetch_related_object error paths" do
  test "{:error, :no_related_object} when related_object is nil (zero HTTP)" do
    # Use verify_on_exit! to enforce no transport call is made
    {payload, sig_header} =
      Testing.generate_thin_event_payload("v2.core.event.snapshot", nil, secret: @secret)

    {:ok, notif} = Webhook.parse_event_notification(payload, sig_header, @secret)
    assert {:error, :no_related_object} = Webhook.fetch_related_object(test_client(), notif)
  end

  test "{:error, {:unknown_object_type, type}} for unknown related_object type (zero HTTP)" do
    {payload, sig_header} =
      Testing.generate_thin_event_payload(
        "v2.future.thing.created",
        %{"id" => "obj_1", "type" => "v2.future.thing", "url" => "/v2/future/things/obj_1"},
        secret: @secret
      )

    {:ok, notif} = Webhook.parse_event_notification(payload, sig_header, @secret)
    assert {:error, {:unknown_object_type, "v2.future.thing"}} =
             Webhook.fetch_related_object(test_client(), notif)
  end
end
```

---

_Reviewed: 2026-05-27T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
