---
phase: 13-billing-test-clocks
fixed_at: 2026-04-12T04:25:00Z
review_path: .planning/phases/13-billing-test-clocks/13-REVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 3
skipped: 0
status: all_fixed
---

# Phase 13: Code Review Fix Report

**Fixed at:** 2026-04-12T04:25:00Z
**Source review:** .planning/phases/13-billing-test-clocks/13-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 3
- Fixed: 3
- Skipped: 0

## Fixed Issues

### CR-01: `__using__` macro client binding is disconnected from `resolve_client!/1`

**Files modified:** `lib/lattice_stripe/testing/test_clock.ex`
**Commit:** a39e442
**Applied fix:** Injected a `setup` callback into the `__using__` macro's `quote` block that reads the `@__lattice_test_clock_client__` module attribute at test setup time, resolves it (calling `stripe_client/0` if it is a module atom with that function exported, or using it directly if it is already a `%Client{}` struct), and populates the process dictionary via `Process.put(:__lattice_stripe_bound_client__, client)`. This bridges the compile-time client binding to the runtime `resolve_client!/1` lookup path.

### WR-01: TOCTOU race in `Owner.cleanup/2`

**Files modified:** `lib/lattice_stripe/testing/test_clock/owner.ex`
**Commit:** a102568
**Applied fix:** Wrapped the entire `cleanup/2` function body (including the `registered/1` GenServer call, the delete loop, and the `GenServer.stop/1` call) in an outer `try/catch :exit, _ -> :ok` block. If the Owner process dies between the `Process.alive?` check and any subsequent GenServer call, the exit is caught and swallowed gracefully, returning `:ok`.

### WR-02: `advance/2` mixes time units with client option in the same keyword list

**Files modified:** `lib/lattice_stripe/testing/test_clock.ex`
**Commit:** 6a482ce
**Applied fix:** Added an explicit `## Options` section to the `advance/2` `@doc` documenting the `:client` keyword as a per-call client override (`%LatticeStripe.Client{}`), with a note that it falls back to the process-bound client from the `use` macro when omitted. Also added a second example showing `advance(clock, days: 30, client: my_client)` usage.

---

_Fixed: 2026-04-12T04:25:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
