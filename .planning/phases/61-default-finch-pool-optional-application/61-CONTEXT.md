# Phase 61 Context — Default Finch Pool & Optional Application

**Source:** Locked from SEED-005 (accrue gap brief §3.1) + maintainer decision (v1.10 plan). No discuss-phase run — the design fork was already decided.
**Requirement:** DX-01
**Goal:** A developer can make live Stripe calls without manually starting and wiring a Finch pool.

## Domain

`LatticeStripe.Client` currently requires a `:finch` pool name in **two** places — the NimbleOptions schema (`lib/lattice_stripe/config.ex:69-74`, `required: true`) and `@enforce_keys [:api_key, :finch]` (`lib/lattice_stripe/client.ex:51`). The library has **no `Application`/supervision tree** today (`mix.exs` `application/0` returns only `[extra_applications: [:logger]]`, no `mod:`), so the Finch pool is entirely the caller's responsibility. This is a documented footgun: a consumer (accrue) that never wires `:finch` raises `NimbleOptions.ValidationError` on every live call, invisibly, because its tests use a fake transport. `finch` is already a hard runtime dependency, so shipping a default pool adds no new dependency.

## Locked Decisions

- **D-01 — Ship `LatticeStripe.Application`.** Add a `use Application` module with a supervision tree, and set `mod: {LatticeStripe.Application, []}` in `mix.exs` `application/0`. It starts a default Finch pool named **`LatticeStripe.Finch`**.
- **D-02 — Default the `:finch` option.** In the NimbleOptions schema (`config.ex`), change `finch:` from `required: true` to `default: LatticeStripe.Finch`. Callers may still pass their own pool name to override.
- **D-03 — Drop `:finch` from `@enforce_keys`** in `client.ex` (keep it as a struct field with the default). `Client.new!/1` and `new/1` must succeed when `:finch` is omitted, resolving to the default pool.
- **D-04 — Backwards compatible.** Existing callers that pass `:finch` (or start their own pool) keep working unchanged. This is an additive relaxation, not a breaking change — document it as such in the CHANGELOG.
- **D-05 — Opt-out for BYO-supervision.** Users who manage their own Finch must be able to prevent the default pool from starting (e.g. `config :lattice_stripe, start_default_finch: false`). The default (unset) starts `LatticeStripe.Finch`. *(Exact opt-out mechanism: Claude's discretion, informed by research into how Finch/Oban/Swoosh ship default/optional pools.)*
- **D-06 — Sensible default pool config**, overridable via app config. Do not over-engineer pool sizing; Finch defaults are acceptable for the default pool.

## Scope Fence

**In scope:** the `Application` module + `mod:` wiring; relaxing the two `:finch` requirements; the opt-out toggle; docs/README/getting-started note that a default pool now exists and you can still bring your own; CHANGELOG entry; tests.

**Out of scope:** any other DX item (Error headers, CacheBodyReader, etc. — those are Phases 67); changing the `Transport` behaviour; touching `api_key` (stays `required: true`); any Stripe resource surface.

## Stability Contracts (MUST NOT break — SEED-005 §6)

- `Client.new!/1` still takes a **keyword list** (not a bare api_key string).
- `api_version` default stays `"2026-03-25.dahlia"`.
- `nil stripe_account` still omits the `Stripe-Account` header.
- Per-request opts still override per-client settings.

## Success Criteria

1. `LatticeStripe.Client.new!(api_key: "sk_test_x")` (no `:finch`) succeeds and resolves to the `LatticeStripe.Finch` default pool.
2. A live request through a client built without `:finch` reaches Finch via the default pool (no `NimbleOptions.ValidationError`, no `@enforce_keys` error).
3. Passing an explicit `finch:` pool name still works and overrides the default.
4. The default pool can be disabled for BYO-supervision users, verified by config.
5. `mix ci` stays green (`format`, `compile --warnings-as-errors`, `credo --strict`, `test`, `docs --warnings-as-errors`), and the new public `Application` module has valid `@moduledoc` + ExDoc registration.

## Risks

- Auto-starting an app (`mod:`) starts a process on boot — must be opt-out-able (D-05) and idle-cheap, or BYO-supervision users get a duplicate pool.
- Relaxing `@enforce_keys`/`required` must not let a truly-missing pool fail silently later — the default must actually be wired end-to-end into `transport_opts` (`client.ex:221`).
