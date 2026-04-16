---
phase: 24-rate-limit-awareness-richer-errors
reviewed: 2026-04-16T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - lib/lattice_stripe/client.ex
  - lib/lattice_stripe/telemetry.ex
  - lib/lattice_stripe/error.ex
  - test/lattice_stripe/telemetry_test.exs
  - test/lattice_stripe/error_test.exs
  - guides/telemetry.md
findings:
  critical: 0
  warning: 3
  info: 4
  total: 7
status: issues_found
---

# Phase 24: Code Review Report

**Reviewed:** 2026-04-16T00:00:00Z
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Phase 24 adds rate-limit awareness (capturing `Stripe-Rate-Limited-Reason` in telemetry stop
metadata) and richer error enrichment (fuzzy param suggestions via `String.jaro_distance/2` on
`invalid_request_error` responses, plus new named fields `param`, `decline_code`, `charge`,
`doc_url`, `raw_body` on the `Error` struct).

The implementation is generally solid. The telemetry plumbing is correct and the fuzzy suggestion
feature is a nice DX touch. Three warnings deserve attention before merging:

1. `parse_type/1` is called twice on the same `type_str` value inside `from_response/3`, which is
   a minor wasteful double-parse that could also mask future bugs if the two call sites diverge.
2. The `id_segment?/1` function relies on a hard-coded list of known Stripe ID prefixes; `acct_`
   (Connect account IDs) is absent, which will silently mis-classify Connect account paths.
3. `do_request_with_retries/7` passes `_attempt = 1` and `_total_attempts = 1` as the same seed
   value, making `retries = total_attempts - 1` always accurate for the first call but the naming
   could create confusion if `attempt` and `total_attempts` were ever incremented independently —
   they're currently kept in sync but the dual-counter design warrants a comment.

No critical (security, crash, data-loss) issues found.

---

## Warnings

### WR-01: `parse_type/1` called twice on same input in `from_response/3`

**File:** `lib/lattice_stripe/error.ex:128-136`

**Issue:** Inside the `%{"error" => %{"type" => type_str} = error_map}` branch, `parse_type/1` is
called at line 130 to build `type:` and again at line 132 inside `maybe_enrich_message/3`. This
means the same string is walked through five function-head comparisons twice per error response.
More importantly, if `maybe_enrich_message/3` and the `type:` field ever receive different results
(e.g., after a future refactor changes one call site), the enriched message would reflect a
different type than the struct's own `type` field — a subtle inconsistency bug.

**Fix:** Bind the parsed type once and reuse it:

```elixir
%{"error" => %{"type" => type_str} = error_map} ->
  parsed_type = parse_type(type_str)
  %__MODULE__{
    type: parsed_type,
    code: Map.get(error_map, "code"),
    message: maybe_enrich_message(
      parsed_type,
      Map.get(error_map, "message"),
      Map.get(error_map, "param")
    ),
    param: Map.get(error_map, "param"),
    decline_code: Map.get(error_map, "decline_code"),
    charge: Map.get(error_map, "charge"),
    doc_url: Map.get(error_map, "doc_url"),
    status: status,
    request_id: request_id,
    raw_body: decoded_body
  }
```

---

### WR-02: `acct_` prefix missing from `id_segment?/1` known prefixes

**File:** `lib/lattice_stripe/telemetry.ex:655-659`

**Issue:** `id_segment?/1` checks for a hard-coded list of known Stripe ID prefixes:

```elixir
known_prefixes = ~w[cus_ pi_ seti_ pm_ re_ cs_ evt_ ch_ in_ sub_ prod_ price_ ii_ il_]
```

`acct_` (Connect account IDs) is absent from this list. A Stripe Connect path like
`/v1/accounts/acct_1234567890abc/login_links` has three segments `["accounts",
"acct_1234567890abc", "login_links"]`, and `id_segment?("acct_1234567890abc")` will fall through
to the length-and-regex heuristic. The string `"acct_1234567890abc"` is 18 characters, passes the
`> 10` and `~r/^[a-zA-Z0-9_]+$/` checks, and is not in `known_action_words()`, so it would still
be classified as an ID — but only by coincidence of length. A short `acct_` ID like
`acct_abc123` (11 chars) would also survive. However, `acct_` omission is an obvious gap for a
library marketing itself as a Stripe Connect SDK. Other absent prefixes include `tr_` (Transfer),
`po_` (Payout), `promo_` (PromotionCode), `si_` (SubscriptionItem).

**Fix:** Add the missing prefixes:

```elixir
known_prefixes = ~w[
  acct_ cus_ pi_ seti_ pm_ re_ cs_ evt_ ch_ in_ sub_
  prod_ price_ ii_ il_ tr_ po_ promo_ si_ txn_
]
```

---

### WR-03: `build_stop_metadata` for success response includes `rate_limited_reason` unconditionally

**File:** `lib/lattice_stripe/telemetry.ex:480-488`

**Issue:** `build_stop_metadata/5` for the `{:ok, %Response{}}` case calls
`parse_rate_limited_reason(resp_headers)` and always puts the result (which is `nil` on non-429)
into the stop metadata map. This is fine for the `:error` clauses (where a 429 is plausible), but
on a success path the `Stripe-Rate-Limited-Reason` header will never be present, so `nil` is
unconditionally injected. This is not a bug per se — `nil` is the documented value — but the
`guides/telemetry.md` (line 101) documents `rate_limited_reason` with type `String.t() | nil` and
says "nil for all non-429 responses," implying it appears in the metadata on both paths. The actual
behaviour is consistent with the documentation; however, the `stop event success: :error_type and
:idempotency_key are absent on success` test (`telemetry_test.exs:624`) checks that those keys are
absent but does NOT assert that `rate_limited_reason` is present as `nil` on success — the test at
line 1076 does cover the nil case. No test gap here, but the asymmetry (`:error_type` absent on
success, `:rate_limited_reason` always present) is worth documenting in a comment inside
`build_stop_metadata` to prevent a future contributor from "cleaning up" the nil injection on the
success path and breaking downstream handlers that rely on the key always being present.

**Fix:** Add an inline comment clarifying the intent:

```elixir
# rate_limited_reason is always present (nil on success) so handlers can safely
# do `Map.get(metadata, :rate_limited_reason)` without `Map.has_key?` guards.
rate_limited_reason: parse_rate_limited_reason(resp_headers)
```

---

## Info

### IN-01: `truncate_body/2` uses `binary_part/3` which can split a multi-byte UTF-8 codepoint

**File:** `lib/lattice_stripe/client.ex:546`

**Issue:** `binary_part(body, 0, max)` slices at byte offset 500, which can split a multi-byte
UTF-8 character in a non-JSON response body (e.g., a Cloudflare HTML maintenance page with a
Unicode character near byte 500). The appended `"..."` would then produce an invalid UTF-8 binary
stored in `raw_body["_raw"]`. This is unlikely in practice (most Stripe and CDN maintenance pages
are ASCII), but it can trip up downstream code or logging frameworks that validate UTF-8.

**Fix:** Use `String.slice/2` which respects codepoint boundaries, or call `String.valid?/1` before
concatenating:

```elixir
defp truncate_body(body, max) when byte_size(body) <= max, do: body
defp truncate_body(body, max) do
  # String.slice/3 is codepoint-safe; falls back gracefully on invalid UTF-8 input
  String.slice(body, 0, max) <> "..."
end
```

---

### IN-02: `@all_resource_modules` in `error.ex` must be manually kept in sync

**File:** `lib/lattice_stripe/error.ex:218-253`

**Issue:** The compile-time `@all_resource_modules` list is hand-maintained. The comment at line
217 says "When a new resource module is added to ObjectTypes, add it here too." This creates a
drift risk: adding a new resource module but forgetting to add it to this list means the fuzzy
suggestion feature silently has a smaller candidate pool. The Phase 30 drift detection mentioned
in the comment is not yet implemented.

This is informational — not a breaking bug — but the coupling is tight enough that a missing
module won't surface as a compile error or test failure, only as a slightly worse user experience.

**Fix (short term):** Add a `@moduledoc` note or a `# TODO(phase-30)` comment directly above the
list reminding contributors to keep it synchronized. For example:

```elixir
# IMPORTANT: Keep this list in sync with all modules listed in
# LatticeStripe.ObjectTypes. Phase 30 will add automated drift detection.
# Missing a module here degrades fuzzy suggestion quality but won't crash.
@all_resource_modules [...]
```

---

### IN-03: Default logger does not log `rate_limited_reason` for successful requests that carry the header

**File:** `lib/lattice_stripe/telemetry.ex:419-429`

**Issue:** `handle_default_log/4` builds `rate_limit_suffix` from `metadata[:rate_limited_reason]`
and appends it to the message, then sets the effective log level to `:warning` if
`metadata[:http_status] == 429`. But `rate_limited_reason` is documented as always present in stop
metadata (nil on non-429). If somehow Stripe returns a 200 with that header (unlikely but
theoretically possible), the suffix would be appended but the level would not be escalated. This
is a cosmetic inconsistency, not a bug.

More practically: the level escalation guard (`metadata[:http_status] == 429`) is independent of
`rate_limit_suffix` presence. They could diverge if Stripe ever returns a rate-limit reason header
on a non-429 status. A single `if` based on `rate_limited_reason != nil` would be more intent-
expressive.

**Fix (optional):** Unify the two conditions:

```elixir
{rate_limit_suffix, effective_level} =
  case Map.get(metadata, :rate_limited_reason) do
    nil -> {"", level}
    reason -> {" (rate_limited: #{reason})", :warning}
  end
```

---

### IN-04: `telemetry_test.exs` section 11 setup block detaches `auto_advance_logger_id` but the handler was attached in test case 11, not in section 10's setup

**File:** `test/lattice_stripe/telemetry_test.exs:1044-1050`

**Issue:** The `setup` block for the "rate-limit telemetry" describe block (section 11, lines
1044-1050) detaches both `:lattice_stripe_default_logger` and `:lattice_stripe_auto_advance_logger`
in `on_exit`. However, the tests in section 11 only call `attach_handler/1` (which uses unique
handler IDs) or `LatticeStripe.Telemetry.attach_default_logger/1` for the logger test. The auto
advance handler is not attached in any section 11 test, so the detach is harmless but unnecessary
noise copied from section 10's setup.

Additionally, test at line 1094 calls `LatticeStripe.Telemetry.attach_default_logger(level: :info)`
without `assert :ok =`, unlike the equivalent test in section 10 at line 950. Minor inconsistency.

**Fix:** The `on_exit` detach for `auto_advance_logger_id` in section 11's setup can be removed as
it is unreachable dead code. Optionally add `assert :ok =` for consistency:

```elixir
setup do
  on_exit(fn -> :telemetry.detach(:lattice_stripe_default_logger) end)
  :ok
end
```

---

_Reviewed: 2026-04-16T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
