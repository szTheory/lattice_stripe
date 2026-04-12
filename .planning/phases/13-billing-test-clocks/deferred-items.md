# Deferred Items — Phase 13

## Pre-existing flaky tests (out of scope for Phase 13)

### ProductTest function_exported? intermittent failures

**Discovered during:** Plan 13-03 (unrelated to TestClock work).

**Symptoms:** `test/lattice_stripe/product_test.exs` tests in the
"function surface (D-05 absence)" describe block intermittently fail with
`function_exported?(Product, :retrieve, 2)` returning `false`. Re-running
the same file passes.

**Root cause:** `function_exported?/3` returns `false` if the module has
not yet been code-loaded in the BEAM for that test process. The Product
module tests do not force-load the module before calling
`function_exported?`, so the check can race with code loading.

**Scope:** Pre-existing issue — reproducible on `main` with no 13-03
changes (verified by running `mix test test/lattice_stripe/product_test.exs`
twice back-to-back, producing 1 failure then 0 failures).

**Suggested fix (future cleanup plan):** Add `Code.ensure_loaded!(Product)`
to a `setup_all` block, or replace `function_exported?/3` with
`Module.defines?/2` at compile time. Same fix should be applied to any
other resource test files that use `function_exported?/3` for surface
assertions.

**Not addressed in Phase 13** because it is unrelated to Test Clock work
and is a test-infrastructure concern that belongs in a cross-cutting
test-hygiene plan.
