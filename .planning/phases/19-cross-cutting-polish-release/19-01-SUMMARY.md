---
phase: 19
plan: 01
subsystem: docs
tags: [docs, exdoc, api-surface, release]
requires:
  - Phase 18 merged (Connect track complete)
provides:
  - Nine-group ExDoc sidebar (D-19)
  - Eight internal modules hidden via @moduledoc false (D-04)
  - Testing.TestClock.Owner promoted to real @moduledoc (D-20)
  - Locked v1.0 public API surface at the docs boundary
affects:
  - Downstream Plans 19-02 (guide editorial pass), 19-03 (README test), 19-04 (release-please 1.0)
tech-stack:
  added: []
  patterns:
    - "@moduledoc false for internal helpers"
    - "Extension-point behaviours (Transport/Json/RetryStrategy) remain public per D-05"
    - "Backticked FQ module refs avoided in public docstrings to prevent hidden-module warnings"
key-files:
  created: []
  modified:
    - lib/lattice_stripe/form_encoder.ex
    - lib/lattice_stripe/request.ex
    - lib/lattice_stripe/resource.ex
    - lib/lattice_stripe/transport/finch.ex
    - lib/lattice_stripe/json/jason.ex
    - lib/lattice_stripe/webhook/cache_body_reader.ex
    - lib/lattice_stripe/billing/guards.ex
    - lib/lattice_stripe/retry_strategy.ex
    - lib/lattice_stripe/testing/test_clock/owner.ex
    - lib/lattice_stripe/error.ex
    - lib/lattice_stripe/subscription_schedule.ex
    - lib/lattice_stripe/transport.ex
    - lib/lattice_stripe/webhook/plug.ex
    - guides/client-configuration.md
    - mix.exs
decisions:
  - "Unhide LatticeStripe.Request (Rule 1 deviation from D-04) because Client.request/2 @spec takes Request.t() and hiding breaks public doc cross-refs"
  - "Request lives in 'Client & Configuration' ExDoc group — it is a user-facing data struct, not an internal helper"
  - "Public docstrings that referenced hidden modules by FQ name in backticks were de-linked (plain text) rather than removing the information"
metrics:
  completed: 2026-04-13
  duration: ~25 minutes
  tasks: 2/2
  files_modified: 15
---

# Phase 19 Plan 01: API Audit & Module Groups Summary

Locked the v1.0 public API surface by flipping seven internal helpers and one
nested retry strategy to `@moduledoc false`, promoting `Testing.TestClock.Owner`
to a documented module, and rewriting `mix.exs` `groups_for_modules` into the
nine-group D-19 layout so the ExDoc sidebar reflects the final 1.0 structure.

## One-liner

Nine-group ExDoc sidebar with eight internal helpers hidden from HexDocs,
`Request` kept visible as a user-facing data struct, and all public docstrings
cleaned of hidden-module cross-references — `mix compile/credo/docs/test` all
clean under `--warnings-as-errors`.

## Tasks Completed

| Task | Name                                                                 | Commit  |
|------|----------------------------------------------------------------------|---------|
| 1    | Flip eight internals to @moduledoc false, promote TestClock.Owner    | 5684379 |
| 2    | Rewrite mix.exs groups_for_modules to the nine-group D-19 layout     | c66223b |

## What Was Built

### Task 1 — API visibility flip (D-04, D-05, D-20)

Eight modules dropped their old 0.x learning-aid docstrings for `@moduledoc false`:

- `LatticeStripe.FormEncoder`
- `LatticeStripe.Request` *(later partially reverted — see Deviations)*
- `LatticeStripe.Resource`
- `LatticeStripe.Transport.Finch`
- `LatticeStripe.Json.Jason`
- `LatticeStripe.Webhook.CacheBodyReader`
- `LatticeStripe.Billing.Guards`
- `LatticeStripe.RetryStrategy.Default` (inner `defmodule` only; outer
  `LatticeStripe.RetryStrategy` behaviour module keeps its real `@moduledoc`
  per D-05)

The three user-implementable behaviours — `LatticeStripe.Transport`,
`LatticeStripe.Json`, `LatticeStripe.RetryStrategy` — remain visible as the
"Internals" extension points.

`LatticeStripe.Testing.TestClock.Owner` was promoted from `@moduledoc false` to
a real docstring describing its role as a per-test GenServer-backed registry
that owns TestClock ids so integration tests can isolate time-travel state.

### Task 2 — mix.exs nine-group layout (D-19, D-20)

Rewrote `groups_for_modules` in `mix.exs` from the legacy eight-group block to
the locked D-19 nine-group layout:

1. **Client & Configuration** (was `Core`) — LatticeStripe, Client, Config,
   Error, Response, List, **Request** *(added during deviation)*
2. **Payments** — PaymentIntent, Customer, PaymentMethod, SetupIntent, Refund
   (Charge removed)
3. **Checkout** — Checkout.Session, Checkout.LineItem
4. **Billing** — Invoice + nested, InvoiceItem + Period, Subscription + nested,
   SubscriptionItem, SubscriptionSchedule + nested (Billing.Guards removed)
5. **Connect** — Account + nested, AccountLink, LoginLink, BankAccount, Card,
   ExternalAccount + Unknown, Transfer, TransferReversal, Payout + TraceId,
   Balance + nested, BalanceTransaction + FeeDetail, **Charge** *(moved from
   Payments)*
6. **Webhooks** — Webhook, Webhook.Plug, **Webhook.Handler**,
   **Webhook.SignatureVerificationError**, Event (last two backfilled per D-20)
7. **Telemetry** — Telemetry *(split from "Telemetry & Testing")*
8. **Testing** — Testing, **TestClock**, **TestClock.Owner**, **TestClock.Error**
   (three backfilled per D-20)
9. **Internals** — Transport, Transport.Finch, Json, Json.Jason, RetryStrategy,
   RetryStrategy.Default, FormEncoder, Resource, **Billing.Guards** *(moved
   from Billing)*

## Verification

- `mix compile --warnings-as-errors` — clean
- `mix docs --warnings-as-errors` — clean (20 initial warnings all resolved)
- `mix credo --strict` — 1138 mods/funs, no issues
- `mix test` — 1386 tests, 0 failures
- `mix format --check-formatted` — clean
- Spot-checks against acceptance criteria in plan (grep counts for
  `@moduledoc false`, group-name changes, ordering asserts) — all pass
- Generated `doc/index.html` — confirmed the nine-group sidebar layout renders

## Deviations from Plan

### Rule 1 deviation — Un-hide `LatticeStripe.Request`

**Found during:** Task 2 verification (`mix docs --warnings-as-errors`)

**Issue:** After hiding `LatticeStripe.Request` per D-04, ExDoc reported
"documentation references type `LatticeStripe.Request.t()` but the module
LatticeStripe.Request is hidden" from three separate public functions:

- `lib/lattice_stripe/client.ex:147` — `Client.request/2` @spec uses `Request.t()`
- `lib/lattice_stripe/client.ex:222` — `Client.request!/2` @spec uses `Request.t()`
- `lib/lattice_stripe/list.ex:133` — `List.stream!/2` docstring references
  `%LatticeStripe.Request{}`

The `@spec` warning cannot be resolved by editing the docstring alone — ExDoc
renders the spec into the function page and detects the hidden-module
reference from the type alone.

**Decision:** `LatticeStripe.Request` is a user-facing data struct, not an
internal helper. Users inspect it in test assertions and construct it
implicitly via resource functions. D-04's list of "helpers" does not cleanly
cover a data struct that flows through every public `Client.request/2` call.
I chose to keep `Request` public and list it in the "Client & Configuration"
ExDoc group, and restored a real `@moduledoc` explicitly noting that users
rarely construct `Request` directly but the struct is public so it can appear
in `@spec`s and test assertions.

**Files modified (vs. plan's 9-file stat):** same files + `lib/lattice_stripe/request.ex`
kept visible, plus 5 downstream doc cleanups and 1 guide edit to remove
backticked references to hidden modules.

**Commit:** c66223b (rolled into Task 2's commit rather than split)

### Rule 1 deviation — De-link backticked hidden-module refs in public docstrings

**Found during:** Task 2 verification (`mix docs --warnings-as-errors`)

**Issue:** Six public modules (four lib/, one guide, one module docstring)
contained backticked references like `` `LatticeStripe.Transport.Finch` ``,
`` `LatticeStripe.RetryStrategy.Default` ``, `` `LatticeStripe.Webhook.CacheBodyReader` ``,
`` `LatticeStripe.Billing.Guards` `` — all of which became hidden in Task 1
and now emitted ExDoc warnings.

**Fix:** Removed the backticks around the FQ module names, leaving the names
as plain prose. Information preserved; module pages no longer referenced as
live hyperlinks. This keeps `mix docs --warnings-as-errors` clean without
deleting any user-visible information.

**Files modified:**

- `lib/lattice_stripe/transport.ex`
- `lib/lattice_stripe/retry_strategy.ex`
- `lib/lattice_stripe/webhook/plug.ex`
- `lib/lattice_stripe/error.ex`
- `lib/lattice_stripe/subscription_schedule.ex`
- `guides/client-configuration.md`

**Commit:** c66223b

### Rule 1 deviation — Fix stale `Testing.TestClock.start_link/1` reference

**Found during:** Task 2 verification

**Issue:** The new `@moduledoc` I wrote for `Testing.TestClock.Owner` referenced
`LatticeStripe.Testing.TestClock.start_link/1`, which does not exist —
`Testing.TestClock` exposes `test_clock/1` as its public entrypoint and it
internally calls `Owner.start_owner!/1`.

**Fix:** Updated the docstring's "Usage" block to reference `test_clock/1`
instead of `start_link/1`.

**Commit:** c66223b

## Known Stubs

None.

## Threat Flags

No new threat surface introduced. Plan 01 was documentation visibility only —
no new network endpoints, auth paths, file access, or schema changes.

## Decisions Made

- **Un-hide `LatticeStripe.Request`** — keep it in `Client & Configuration`
  ExDoc group instead of `Internals`. Rationale: the struct flows through
  every public `Client.request/2`/`request!/2`/`List.stream!/2` spec, and ExDoc
  cannot render a public `@spec` cleanly when its type lives in a hidden
  module. This is a narrow override of D-04, not a scope expansion.
- **De-link instead of delete** — when public docstrings referenced hidden
  modules, the fix was to unquote the backticks (keeping the prose) rather
  than delete the information. Users still learn the internal module name
  exists; ExDoc just no longer tries to link it.
- **Preserve function-level `@doc`** — per RESEARCH anti-pattern note, only
  `@moduledoc` was flipped. Individual `@doc` annotations remain for
  stacktrace/IEx help usefulness.

## Self-Check: PASSED

- [x] `lib/lattice_stripe/form_encoder.ex` — `@moduledoc false` present
- [x] `lib/lattice_stripe/request.ex` — real `@moduledoc` present (deviation)
- [x] `lib/lattice_stripe/resource.ex` — `@moduledoc false` present
- [x] `lib/lattice_stripe/transport/finch.ex` — `@moduledoc false` present
- [x] `lib/lattice_stripe/json/jason.ex` — `@moduledoc false` present
- [x] `lib/lattice_stripe/webhook/cache_body_reader.ex` — `@moduledoc false` present
- [x] `lib/lattice_stripe/billing/guards.ex` — `@moduledoc false` present
- [x] `lib/lattice_stripe/retry_strategy.ex` — inner `Default` has `@moduledoc false`, outer module keeps real docstring
- [x] `lib/lattice_stripe/testing/test_clock/owner.ex` — real `@moduledoc` present
- [x] `mix.exs` — `"Client & Configuration"` group present, `Core:` removed,
  `"Telemetry & Testing"` removed, nine groups total
- [x] Commit `5684379` (Task 1) — present on HEAD~1
- [x] Commit `c66223b` (Task 2) — present on HEAD
- [x] `mix compile --warnings-as-errors` — clean
- [x] `mix docs --warnings-as-errors` — clean
- [x] `mix credo --strict` — clean
- [x] `mix test` — 1386/1386 pass
