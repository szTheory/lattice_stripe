---
phase: 19-cross-cutting-polish-release
reviewed: 2026-04-13T00:00:00Z
depth: standard
files_reviewed: 29
files_reviewed_list:
  - lib/lattice_stripe/billing/guards.ex
  - lib/lattice_stripe/error.ex
  - lib/lattice_stripe/form_encoder.ex
  - lib/lattice_stripe/json/jason.ex
  - lib/lattice_stripe/request.ex
  - lib/lattice_stripe/resource.ex
  - lib/lattice_stripe/retry_strategy.ex
  - lib/lattice_stripe/subscription_schedule.ex
  - lib/lattice_stripe/testing/test_clock/owner.ex
  - lib/lattice_stripe/transport.ex
  - lib/lattice_stripe/transport/finch.ex
  - lib/lattice_stripe/webhook/cache_body_reader.ex
  - lib/lattice_stripe/webhook/plug.ex
  - test/readme_test.exs
  - mix.exs
  - release-please-config.json
  - README.md
  - CHANGELOG.md
  - guides/api_stability.md
  - guides/cheatsheet.cheatmd
  - guides/checkout.md
  - guides/client-configuration.md
  - guides/connect-accounts.md
  - guides/connect-money-movement.md
  - guides/connect.md
  - guides/error-handling.md
  - guides/getting-started.md
  - guides/payments.md
  - guides/webhooks.md
findings:
  critical: 0
  warning: 3
  info: 8
  total: 11
status: issues_found
---

# Phase 19: Code Review Report

**Reviewed:** 2026-04-13
**Depth:** standard
**Files Reviewed:** 29
**Status:** issues_found

## Summary

Phase 19 is a docs / polish / release-staging phase. The code changes are light — mostly `@moduledoc false` flips on internal modules — and the security posture of the new `test/readme_test.exs` (which uses `Code.eval_string/1`) is sound: it evals only content extracted from the source-controlled `README.md` against a local stripe-mock, gated behind `@moduletag :integration`, and the README is itself review-gated. No critical issues found.

Three warnings cluster around documentation correctness that *will* mislead users or break release-please tooling:

1. **CHANGELOG.md has two `## [Unreleased]` headings** (lines 7 and 119). release-please matches on heading text — a second `## [Unreleased]` risks the Highlights block being lifted to the wrong section or duplicated.
2. **`guides/cheatsheet.cheatmd` pattern-matches on `:auth_error`** — an atom that does not exist in `LatticeStripe.Error`'s documented `error_type()`. Users copy-pasting from the cheatsheet will get a silently-unreachable clause.
3. **`guides/webhooks.md` line 378 mis-names the test-signature helper**, claiming LatticeStripe provides `Testing.generate_webhook_payload/3` but then showing a `Webhook.generate_test_signature/2` call. Both functions exist, but the prose points at the wrong one.

The eight Info items are quality / cleanup observations — stale version pins, orphan public modules, and dead `groups_for_modules` config.

## Warnings

### WR-01: Duplicate `## [Unreleased]` heading in CHANGELOG

**File:** `CHANGELOG.md:7,119`
**Issue:** The CHANGELOG has **two** `## [Unreleased]` headings. The first (line 7) contains the staged v1.0.0 Highlights narrative and the Phase 18 feat/fix bullets; the second (line 119) is a stale "Added / Initial release" stanza left over from earlier scaffolding.

release-please uses heading matching for idempotency (see 19-RESEARCH.md "Pitfall 2"). When the Release PR is generated with a `## [1.0.0](...)` heading, release-please will replace the *first* `## [Unreleased]` — the second one will remain and render as a second unreleased section below the v1.0.0 stanza.

This is also the section the Phase 19 D-11/D-12 instructions point at ("LIFT the `### Highlights` block below and prepend it directly under that generated heading"), so the lift step will succeed — but the dangling second `## [Unreleased]` will ship to HexDocs as a confusing artifact.

**Fix:** Delete lines 119-131 of `CHANGELOG.md` entirely. The content (`Initial release of LatticeStripe`, core / resources / webhook etc.) is already covered by the v0.2.0 stanza at line 56 and the v1.0.0 Highlights narrative at lines 18-31.

```diff
-## [Unreleased]
-
-### Added
-
-- Initial release of LatticeStripe
-- Core: Client configuration, transport behaviour, JSON codec, form encoding
-- Resources: Customer, PaymentIntent, SetupIntent, PaymentMethod, Refund, Checkout.Session
-- Webhook signature verification with Phoenix Plug integration
-- Auto-pagination via Elixir Streams
-- Automatic retry with exponential backoff and idempotency keys
-- Telemetry events for request lifecycle monitoring
-- Test helpers for webhook event construction
```

### WR-02: Cheatsheet uses `:auth_error` — an atom that does not exist

**File:** `guides/cheatsheet.cheatmd:152`
**Issue:** The "Pattern match on errors" example matches on `%Error{type: :auth_error}`, but the documented `LatticeStripe.Error.error_type()` (see `lib/lattice_stripe/error.ex:60-70` and `guides/error-handling.md:57`) uses **`:authentication_error`**. `:auth_error` is never produced by `parse_type/1` (`lib/lattice_stripe/error.ex:154-161`), so this clause is dead code. Users copy-pasting from the cheatsheet will silently fall through to the catch-all and never handle auth failures.

**Fix:**
```diff
-  {:error, %Error{type: :auth_error}} ->
+  {:error, %Error{type: :authentication_error}} ->
     {:error, "Invalid API key"}
```

### WR-03: `webhooks.md` points at the wrong test helper name

**File:** `guides/webhooks.md:378-401`
**Issue:** The prose claims:

> LatticeStripe provides `LatticeStripe.Testing.generate_webhook_payload/3` to generate correctly-signed test webhook payloads

...but the example on line 391 then calls `LatticeStripe.Webhook.generate_test_signature(payload, secret)`. Both functions exist in the codebase (see `lib/lattice_stripe/webhook.ex:207` and `lib/lattice_stripe/testing.ex:136`) but they have different signatures and purposes — `generate_webhook_payload/3` returns an event map, `generate_test_signature/2` returns just the `Stripe-Signature` header value. The prose, the function shown, and the call-site usage are inconsistent.

**Fix:** Either rewrite the prose to match the example (recommended — the example is correct):

```diff
-LatticeStripe provides `LatticeStripe.Testing.generate_webhook_payload/3` to generate
-correctly-signed test webhook payloads:
+LatticeStripe provides `LatticeStripe.Webhook.generate_test_signature/2` to produce
+valid `Stripe-Signature` headers for test payloads:
```

...or rewrite the example to call `Testing.generate_webhook_payload/3` end-to-end.

## Info

### IN-01: Orphan public resource modules not grouped in ExDoc

**File:** `mix.exs:46-138`, `lib/lattice_stripe/{price,product,coupon,promotion_code}.ex`
**Issue:** `LatticeStripe.Price`, `LatticeStripe.Product`, `LatticeStripe.Coupon`, and `LatticeStripe.PromotionCode` all carry public `@moduledoc` strings but are not referenced in any `groups_for_modules` group. They will appear in an ungrouped "Modules" section at the bottom of HexDocs, outside the nine-group D-19 layout.

Per the phase memory (`project_phase12_13_deletion.md`), these resources were "deleted" at commit 39b98c9 but the files evidently still exist on the current branch. Either (a) they are real public API and need to be added to an appropriate group, or (b) they are stale and should be deleted / marked `@moduledoc false`.

**Fix:** Decide the intent and either add them to a new `Catalog` (or existing `Billing`) group, delete the files, or flip them to `@moduledoc false` with a note in `guides/api_stability.md`.

### IN-02: `Internals` ExDoc group is effectively empty

**File:** `mix.exs:127-137`
**Issue:** Every module listed in the `Internals:` group has `@moduledoc false`:

- `LatticeStripe.Transport.Finch` — `lib/.../transport/finch.ex:2`
- `LatticeStripe.Json.Jason` — `lib/.../json/jason.ex:2`
- `LatticeStripe.RetryStrategy.Default` — `lib/.../retry_strategy.ex:39`
- `LatticeStripe.FormEncoder` — `lib/.../form_encoder.ex:2`
- `LatticeStripe.Resource` — `lib/.../resource.ex:2`
- `LatticeStripe.Billing.Guards` — `lib/.../billing/guards.ex:2`

ExDoc skips `@moduledoc false` modules regardless of grouping, so this group renders empty. `LatticeStripe.Transport` and `LatticeStripe.Json` (listed in the same group) *are* public — they should probably move to a group with a more descriptive name like `"Behaviours"` or `"Extension Points"`.

**Fix:** Either remove the `Internals` group entirely and re-home `Transport` / `Json` / `RetryStrategy` under a `Behaviours` group, or keep the group and drop the six `@moduledoc false` modules that can never render.

### IN-03: `LatticeStripe.Webhook.CacheBodyReader` is not listed in `api_stability.md`

**File:** `guides/api_stability.md:42-48`
**Issue:** The "What is NOT public API" list enumerates seven hidden internals; `CacheBodyReader` is present. **But** in `lib/lattice_stripe/webhook/plug.ex:88-90`, the moduledoc refers users to `CacheBodyReader` by fully-qualified name ("LatticeStripe.Webhook.CacheBodyReader (hidden internal)"). This is consistent with `api_stability.md`, so the two are in sync. However, `guides/webhooks.md:110-135` and `guides/webhooks.md:237-247` instruct users to configure it as a `:body_reader` — making it a *de facto* public API surface despite the `@moduledoc false`.

**Fix:** Either:
- (a) Flip `CacheBodyReader` to `@moduledoc` (with a public doc) since users are told to reference it by name in their endpoint config, and remove it from the "NOT public API" list in `api_stability.md`.
- (b) Keep it hidden and add a note in `api_stability.md` that the `{LatticeStripe.Webhook.CacheBodyReader, :read_body, []}` MFA tuple form is stable-by-convention even though the module is nominally private.

Option (a) is safer and more consistent with usage.

### IN-04: `README.md` and `getting-started.md` and `cheatsheet.cheatmd` use inconsistent version pins

**File:** `README.md:21`, `guides/getting-started.md:14`, `guides/cheatsheet.cheatmd:11`
**Issue:** Three different version pins appear in user-facing install snippets:

- `README.md` line 21: `{:lattice_stripe, "~> 0.2"}`
- `guides/getting-started.md` line 14: `{:lattice_stripe, "~> 0.1"}`
- `guides/cheatsheet.cheatmd` line 11: `{:lattice_stripe, "~> 0.1"}`

Phase 19 is staging the 1.0.0 release. All three should read `~> 1.0` by the time the release PR merges. The README is especially load-bearing because `test/readme_test.exs` evaluates its Quick Start blocks — the `filter_runnable_blocks/1` helper skips the `deps do` block so this particular mismatch won't fail the test, but it *will* ship to Hex.pm.

**Fix:** Bulk-update all three to `{:lattice_stripe, "~> 1.0"}` as part of the 1.0.0 release PR.

### IN-05: `test/readme_test.exs` `Code.eval_string/1` is safe but unbounded

**File:** `test/readme_test.exs:37`
**Issue:** The test reads `README.md`, extracts fenced elixir blocks, does two hard-coded string substitutions, and passes the result to `Code.eval_string/1`. This is safe in practice — `README.md` is source-controlled and changes are PR-reviewed — but:

1. The eval is unbounded. A malformed block (e.g. an infinite loop in a doctest someone adds) will hang the test suite indefinitely; there is no timeout.
2. The eval happens at the `ExUnit.Case` level with an empty binding, so a block that depends on a previous block's variables will cascade-fail. The current layout happens to work because the Quick Start is linear, but any future Quick Start rewrite that introduces branching (`case`, `if`) across blocks will be fragile.
3. `Code.eval_string/1` evaluates in the current process, so any side effect (spawning a GenServer, starting Finch) persists across the test. `setup_all` already starts `ReadmeTest.Finch`, but a README block that starts its own named process would collide on re-run.

None of these are vulnerabilities — the input is trusted — but they are reliability cliffs for future README edits.

**Fix:** Consider wrapping the eval in a task with a timeout, e.g.

```elixir
task = Task.async(fn -> Code.eval_string(script, []) end)
Task.await(task, 30_000)
```

...so a runaway block fails the test at 30 s rather than timing out the whole suite.

### IN-06: `Webhook.Plug.get_raw_body/1` silently returns `""` on `{:more, ...}`

**File:** `lib/lattice_stripe/webhook/plug.ex:272-283`
**Issue:** When `conn.private[:raw_body]` is absent, `get_raw_body/1` falls through to `Plug.Conn.read_body(conn)` with no `:length` opt, taking the default 8 MB chunk size. If the body is larger than that (not realistic for a single Stripe webhook, but structurally possible), `read_body/1` returns `{:more, partial, conn}` — which the current `case` clause matches as "no match" and returns `""`. A `""` body then propagates to `Webhook.construct_event/4` and signature verification fails with `{:error, :no_matching_signature}`, producing a 400.

The behaviour is safe (the bad webhook is rejected) but the error message is misleading — a timeout-looking "no matching signature" rather than "body too large". Stripe's largest webhook payloads are well under 8 MB, so this is latent rather than active.

**Fix:** Add an explicit `{:more, _, _}` clause with a clearer error signal, or drop the fallback entirely and require `CacheBodyReader` / mount-before-parsers (the two documented strategies).

```elixir
defp get_raw_body(conn) do
  case conn.private[:raw_body] do
    nil ->
      case Plug.Conn.read_body(conn) do
        {:ok, body, _conn} -> body
        {:more, _partial, _conn} -> ""   # body exceeds chunk size — reject below
        {:error, _} -> ""
      end

    body ->
      body
  end
end
```

### IN-07: `Billing.Guards.has_proration_behavior?` accepts `items[].proration_behavior` for Schedule updates

**File:** `lib/lattice_stripe/billing/guards.ex:36, 43-50`
**Issue:** The guard's `items_has?/1` clause lets a `params["items"][0]["proration_behavior"]` value satisfy the "explicit proration required" check. This is correct for `Subscription.update/4` (Stripe accepts `items[].proration_behavior` there), but is wired into `SubscriptionSchedule.update/4` as well (via the shared guard), and Stripe does **not** accept `items[].proration_behavior` on schedule updates — only top-level and `phases[].proration_behavior`.

The `SubscriptionSchedule` moduledoc (`lib/.../subscription_schedule.ex:57-69`) and the phases_has? comment (lines 56-59 of `guards.ex`) both explicitly document that `phases[].items[]` is NOT walked — which is correct — but neither addresses the top-level `items[]` array. In practice, a user who passes `params = %{"items" => [%{"proration_behavior" => "none"}]}` to `SubscriptionSchedule.update/4` passes the guard, then Stripe rejects the request with `invalid_request_error`.

This is a guard-too-lax / defense-in-depth issue, not a bug — Stripe still catches it. But it defeats the purpose of the guard, which is to fail client-side before the network round-trip.

**Fix:** Either (a) split the guard into `check_proration_required_subscription/2` and `check_proration_required_schedule/2` and only walk `items[]` in the former, or (b) keep the shared guard and document that schedule callers should not pass a top-level `items[]` (it's ignored by Stripe on that endpoint anyway).

### IN-08: `CHANGELOG.md` Highlights narrative uses a markdown link that HexDocs won't resolve

**File:** `CHANGELOG.md:20`
**Issue:** The Highlights paragraph ends with `see [API Stability](guides/api_stability.md) for the full contract.` When CHANGELOG.md is rendered on HexDocs, it's served at `/changelog.html` and relative paths are resolved against that URL — `guides/api_stability.md` will 404 because HexDocs flattens guides to `/api_stability.html` (no `guides/` prefix).

**Fix:** Use the ExDoc cross-ref form:

```diff
-see [API Stability](guides/api_stability.md) for the full contract.
+see [API Stability](api_stability.html) for the full contract.
```

(Compare `guides/api_stability.md:115` which correctly uses `../changelog.html`.)

---

_Reviewed: 2026-04-13_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
