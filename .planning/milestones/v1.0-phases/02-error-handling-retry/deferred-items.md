# Deferred Items — Phase 02

Items found during Plan 03 execution that are pre-existing and out of scope.

## Pre-existing Credo Issues

### lib/lattice_stripe/retry_strategy.ex

1. **`is_connection_error?` naming** (line 134-135): Credo flags predicates starting with `is` that should use `?` suffix only. This is a minor readability issue from Plan 02.

2. **Cyclomatic complexity of `retry?/2`** (line 58): Credo reports complexity 11 (max 9). The `cond` with 7 branches is inherently complex per the Stripe retry logic. Refactoring into sub-functions would obscure the retry decision flow.

### lib/lattice_stripe/form_encoder.ex

3. **`Enum.map_join/3` efficiency** (lines 46, 106): Credo recommends using `Enum.map_join/3` over `Enum.map/2 |> Enum.join/2`. Pre-existing from Phase 01.

## Recommendation

These items should be addressed in a dedicated cleanup plan or as part of a future CI lint-fix pass.
