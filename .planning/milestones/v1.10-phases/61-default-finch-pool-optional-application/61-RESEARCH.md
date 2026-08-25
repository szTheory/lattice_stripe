# Phase 61: Default Finch Pool & Optional Application - Research

**Researched:** 2026-07-27
**Domain:** Elixir OTP Application/supervision trees, Finch pool defaults, NimbleOptions schema defaults, backward-compatible SDK ergonomics
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01 — Ship `LatticeStripe.Application`.** Add a `use Application` module with a supervision tree, and set `mod: {LatticeStripe.Application, []}` in `mix.exs` `application/0`. It starts a default Finch pool named **`LatticeStripe.Finch`**.
- **D-02 — Default the `:finch` option.** In the NimbleOptions schema (`config.ex`), change `finch:` from `required: true` to `default: LatticeStripe.Finch`. Callers may still pass their own pool name to override.
- **D-03 — Drop `:finch` from `@enforce_keys`** in `client.ex` (keep it as a struct field with the default). `Client.new!/1` and `new/1` must succeed when `:finch` is omitted, resolving to the default pool.
- **D-04 — Backwards compatible.** Existing callers that pass `:finch` (or start their own pool) keep working unchanged. This is an additive relaxation, not a breaking change — document it as such in the CHANGELOG.
- **D-05 — Opt-out for BYO-supervision.** Users who manage their own Finch must be able to prevent the default pool from starting (e.g. `config :lattice_stripe, start_default_finch: false`). The default (unset) starts `LatticeStripe.Finch`. *(Exact opt-out mechanism: Claude's discretion, informed by research into how Finch/Oban/Swoosh ship default/optional pools.)*
- **D-06 — Sensible default pool config**, overridable via app config. Do not over-engineer pool sizing; Finch defaults are acceptable for the default pool.

**Scope Fence — In scope:** the `Application` module + `mod:` wiring; relaxing the two `:finch` requirements; the opt-out toggle; docs/README/getting-started note that a default pool now exists and you can still bring your own; CHANGELOG entry; tests.

**Scope Fence — Out of scope:** any other DX item (Error headers, CacheBodyReader, etc. — those are Phases 67); changing the `Transport` behaviour; touching `api_key` (stays `required: true`); any Stripe resource surface.

**Stability Contracts (MUST NOT break — SEED-005 §6):**
- `Client.new!/1` still takes a **keyword list** (not a bare api_key string).
- `api_version` default stays `"2026-03-25.dahlia"`.
- `nil stripe_account` still omits the `Stripe-Account` header.
- Per-request opts still override per-client settings.

**Success Criteria (from CONTEXT.md):**
1. `LatticeStripe.Client.new!(api_key: "sk_test_x")` (no `:finch`) succeeds and resolves to the `LatticeStripe.Finch` default pool.
2. A live request through a client built without `:finch` reaches Finch via the default pool (no `NimbleOptions.ValidationError`, no `@enforce_keys` error).
3. Passing an explicit `finch:` pool name still works and overrides the default.
4. The default pool can be disabled for BYO-supervision users, verified by config.
5. `mix ci` stays green (`format`, `compile --warnings-as-errors`, `credo --strict`, `test`, `docs --warnings-as-errors`), and the new public `Application` module has valid `@moduledoc` + ExDoc registration.

**Risks (from CONTEXT.md):**
- Auto-starting an app (`mod:`) starts a process on boot — must be opt-out-able (D-05) and idle-cheap, or BYO-supervision users get a duplicate pool.
- Relaxing `@enforce_keys`/`required` must not let a truly-missing pool fail silently later — the default must actually be wired end-to-end into `transport_opts` (`client.ex:221`).

### Claude's Discretion

- Exact opt-out mechanism (D-05) — this research recommends `config :lattice_stripe, start_default_finch: false`, matching the CONTEXT.md example verbatim (see Open Questions #1 for why it should be treated as locked-in-practice, not just illustrative).
- Default pool config override mechanism (D-06) — this research recommends `config :lattice_stripe, default_finch_pools: %{...}` (see Open Questions #2 and Code Examples).

### Deferred Ideas (OUT OF SCOPE)

None listed in 61-CONTEXT.md beyond the Scope Fence "Out of scope" items above (Error headers/CacheBodyReader → Phase 67; Transport behaviour changes; `api_key` requirement changes; any Stripe resource surface).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-------------------|
| DX-01 | Developer can make live Stripe calls without manually starting a Finch pool — an optional `LatticeStripe.Application` starts a default `LatticeStripe.Finch` pool and the `:finch` option defaults to it (relax `required: true`; drop from `@enforce_keys`). Existing callers that pass `:finch` keep working (backwards-compatible) | Fully covered — see Architecture Patterns (Application wiring, NimbleOptions `default:`), Code Examples / Framework Quick Reference (concrete implementation), Common Pitfalls #1-#4 (silent-failure guards, `@enforce_keys` removal safety, duplicate-pool risk, `mix test` boot behavior), and Validation Architecture (Phase Requirements → Test Map maps every CONTEXT.md Success Criterion 1-5 to a concrete test). |
</phase_requirements>

## Summary

This phase wires a zero-config default: `LatticeStripe` gains an OTP `Application` callback (`mod: {LatticeStripe.Application, []}`) that starts a single named Finch pool (`LatticeStripe.Finch`) using Finch's own defaults, then makes `Config`/`Client` resolve to that pool name when the caller omits `:finch`. This is a narrow, well-trodden pattern in the Elixir HTTP-client ecosystem — `req` (the Finch-based batteries-included client) ships exactly this shape today: `Req.Application` unconditionally starts `{Req.Finch, name: Req.Finch}` under a one-for-one supervisor, and `mix.exs` registers it via `mod: {Req.Application, []}`. LatticeStripe's job is simpler (one static named pool, not `req`'s per-host `DynamicSupervisor`), so the plan can copy `req`'s wiring pattern and drop the dynamic-supervisor part entirely.

The one piece `req` does *not* model is the opt-out (D-05) — `req` always starts its pool unconditionally because Req.Finch is structurally required for every Req call. Oban and Swoosh, by contrast, never auto-start at all (no `mod:` in their own `mix.exs`); users add `{Oban, ...}` / `{Finch, name: Swoosh.Finch}` to their own supervisor because those libraries need consumer-specific config (an Ecto repo, a named pool per mailer) that has no library-safe default. LatticeStripe's default pool has no such requirement (a plain named Finch pool needs no consumer input), so the auto-start-with-opt-out design in D-05 is the right middle ground, but it isn't copyable from one single comparator — it composes the standard "conditionally build the children list in `start/2` from `Application.get_env/3`" idiom (a documented, common Elixir pattern for boot-time toggles, distinct from the general anti-pattern of libraries consuming application env for business logic) with `req`'s single-child-spec shape.

**Primary recommendation:** Add `LatticeStripe.Application` (`use Application`) whose `start/2` conditionally includes `{Finch, name: LatticeStripe.Finch, pools: default_pools()}` based on `Application.get_env(:lattice_stripe, :start_default_finch, true)`; register `mod: {LatticeStripe.Application, []}` in `mix.exs`; change `config.ex`'s `finch:` entry to `default: LatticeStripe.Finch`; drop `:finch` from `client.ex`'s `@enforce_keys` (leave it as a defstruct field, no default needed there since `Config.validate!/1` always supplies a value before `struct!/2` runs).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Default Finch pool process lifecycle | Application/Supervision (library boot) | — | A named, supervised process must be started exactly once per BEAM node; only an `Application` callback can own this — a plain module function cannot guarantee singleton startup. |
| `:finch` pool name resolution | Config (NimbleOptions schema) | Client (struct) | `Config.validate!/1` is the single choke point all `Client.new/1`/`new!/1` calls pass through — defaulting there guarantees every code path (including any future entry point) inherits the default without duplicating logic in `Client`. |
| Opt-out toggle | Application env (consumer-supplied) | Application (library boot, read at start/2) | Read once at boot in `start/2`, not per-request — this is infrastructure configuration (should this OTP app manage this process), not request-time business logic, which is the documented exception to "don't use app env in libraries." |
| Backwards compatibility (existing `:finch` callers) | Config/Client (unchanged code path) | — | No behavior change needed — NimbleOptions `default:` only activates when the key is absent; explicit values always win. |

## Standard Stack

### Core
No new dependencies. Finch (`~> 0.21`) is already a hard runtime dependency (`mix.exs:282`); this phase only changes *when/how* it is supervised, not which library provides HTTP pooling.

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| NimbleOptions | ~> 1.0 (already a dep) | `default:` key on the `:finch` schema entry | Already used for every other optional key in `config.ex` — no new pattern, just switching `required: true` → `default: LatticeStripe.Finch` on one entry. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `Application.get_env(:lattice_stripe, :start_default_finch, true)` read inside `start/2` | A separate `LatticeStripe.Supervisor` module manually started via `Supervisor.start_link/2` that consumers call themselves | Rejected — this reintroduces exactly the manual-wiring footgun DX-01 exists to eliminate (SEED-005 §3.1: accrue never wired Finch because nothing forced it to). `mod:` auto-start is the entire point of the phase. |
| One static named pool `LatticeStripe.Finch` | `req`'s `DynamicSupervisor` + per-host pool pattern | Rejected — massive overkill for a single-API-host SDK (all Stripe calls go to `api.stripe.com`/`files.stripe.com`); `req` needs per-host pools because it's a general-purpose HTTP client hitting arbitrary URLs. D-06 explicitly says "do not over-engineer pool sizing." |
| `Application.get_env` opt-out | Compile-time `Application.compile_env/3` | Rejected for this key — `compile_env` locks the value at compile time (of *LatticeStripe's* compilation, which happens when the *dependency* compiles, before the consumer's `config/config.exs` for their own app is even relevant in the umbrella/release sense) and would require recompiling lattice_stripe itself on toggle. `Application.get_env/3` read inside `start/2` (which runs at consumer boot, after all config is loaded) is correct here. |

**Installation:** No new packages. No `mix deps.get` needed for this phase.

**Version verification:** N/A — no new packages. Finch `~> 0.21` version already pinned and installed in `mix.lock`; confirmed via `mix.exs:282` (existing dependency, unchanged).

## Package Legitimacy Audit

Not applicable — this phase adds zero new dependencies. `finch` and `nimble_options` are pre-existing runtime dependencies already vetted in the project's STACK research (see CLAUDE.md Technology Stack section, both confidence HIGH).

## Architecture Patterns

### System Architecture Diagram

```
mix.exs
  application/0 → mod: {LatticeStripe.Application, []}
         │
         ▼
  OTP boot sequence (consumer app start, or `mix test` auto-boot)
         │
         ▼
  LatticeStripe.Application.start/2
         │
         ├─ Application.get_env(:lattice_stripe, :start_default_finch, true)
         │      │
         │      ├─ true (default)  ──► children = [{Finch, name: LatticeStripe.Finch, pools: ...}]
         │      └─ false (opt-out) ──► children = []
         │
         ▼
  Supervisor.start_link(children, strategy: :one_for_one)
         │
         ▼
  (LatticeStripe.Finch pool running under the app's own supervision tree, name-registered)

─────────────────────────────────────────────────────────────

Client.new!(api_key: "sk_...")   [no :finch given]
         │
         ▼
  Config.validate!/1  (NimbleOptions)
         │  finch: [type: :atom, default: LatticeStripe.Finch, ...]
         ▼
  validated[:finch] == LatticeStripe.Finch
         │
         ▼
  struct!(Client, validated)  →  %Client{finch: LatticeStripe.Finch, ...}
         │
         ▼
  Client.request/2 → transport_opts = [finch: client.finch, ...]  (client.ex:221)
         │
         ▼
  Transport.Finch.request/1 → Finch.request(req, client.finch, opts)
         │
         ▼
  Resolves to the already-running LatticeStripe.Finch pool (started at boot) — no crash, no nil.
```

### Recommended Project Structure
```
lib/
├── lattice_stripe/
│   ├── application.ex     # NEW — OTP Application callback, starts default Finch pool
│   ├── config.ex          # MODIFIED — finch: required: true → default: LatticeStripe.Finch
│   └── client.ex           # MODIFIED — drop :finch from @enforce_keys
├── lattice_stripe.ex        # unchanged (warm_up/1 still takes an explicit client)
mix.exs                      # MODIFIED — application/0 gains mod: {LatticeStripe.Application, []}
test/
└── lattice_stripe/
    └── application_test.exs  # NEW
```

### Pattern 1: Config-gated child list in `start/2`
**What:** Build the `children` list conditionally instead of hard-coding it, based on `Application.get_env/3` read once at boot.
**When to use:** Any library shipping an auto-started default resource that must remain overridable by consumers who manage that resource themselves.
**Example:**
```elixir
# Pattern basis: req's Req.Application (unconditional variant — no opt-out needed there
# because Req.Finch is structurally required for every Req call).
# Source: https://github.com/wojtekmach/req/blob/main/lib/req/application.ex
defmodule Req.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Req.Finch, name: Req.Finch},
      {DynamicSupervisor, strategy: :one_for_one, name: Req.FinchSupervisor},
      {Req.Test.Ownership, name: Req.Test.Ownership}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```
LatticeStripe adapts this by adding the config gate `req` doesn't need (see Framework Quick Reference below for the full adapted shape).

### Pattern 2: NimbleOptions `default:` instead of `required: true`
**What:** Relax a schema key from `required: true` to `default: <module-atom>` so validation succeeds when the key is omitted, while still accepting and honoring an explicit override.
**When to use:** Any config key that has a library-safe default but must remain overridable.
**Example:**
```elixir
# config.ex — before (current, line 69-74):
finch: [
  type: :atom,
  required: true,
  doc: "Name of the Finch pool to use for HTTP requests. Must be started in your supervision tree."
],

# after:
finch: [
  type: :atom,
  default: LatticeStripe.Finch,
  doc:
    "Name of the Finch pool to use for HTTP requests. Defaults to LatticeStripe.Finch, " <>
      "started automatically unless disabled via `config :lattice_stripe, start_default_finch: false`. " <>
      "Pass your own pool name to override."
],
```
This mirrors every other optional key already in the same schema (`transport`, `json_codec`, `retry_strategy` all use `default: <module>` for atom-typed module references) — no new NimbleOptions idiom, just applying the existing local pattern to `:finch`.

### Anti-Patterns to Avoid
- **Reading `Application.get_env(:lattice_stripe, :start_default_finch, ...)` per-request instead of once at boot:** The opt-out is infrastructure config (should this OTP app own this process), not business logic — read it exactly once, in `Application.start/2`. Reading it per-request would violate the project's own "Client is a plain struct with no process state" philosophy (`client.ex:1-9` moduledoc) and add per-call `Application.get_env` overhead for zero benefit.
- **Giving the `:finch` NimbleOptions entry a `default:` that isn't a real running pool name:** The default value literally must be the same atom the `Application` starts the pool under (`LatticeStripe.Finch`) — any drift between the two (e.g., typo, or the pool started under a different name) reintroduces the exact silent-failure footgun DX-01 exists to close (see Common Pitfalls below).
- **Making `LatticeStripe.Application` a `GenServer` or adding any state:** Per PROJECT.md ("processes only when truly needed") and the existing pattern (Finch itself is the only process), the `Application` module should do nothing but supervise — no custom logic, no state, no message handling.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Pool sizing / connection limits | A custom pool-size heuristic or "smart default" calculator | Finch's built-in default (`%{default: [size: 50, count: 1]}`) | D-06 explicitly says not to over-engineer pool sizing; Finch's own default is already tuned for general HTTP client workloads and is what every comparator (`req`, Swoosh via its own `{Finch, name: Swoosh.Finch}` child spec) relies on unless the consumer opts into custom pool config. |
| Ensuring the pool starts exactly once even with multiple `use Application` modules in a release | Manual PID/registry bookkeeping | OTP's own `Application` behaviour + named process registration (`Finch.start_link(name: LatticeStripe.Finch)` fails loudly on name collision) | This is exactly what OTP's application/supervision infrastructure is for — Elixir already guarantees singleton startup per registered name within a node. |

**Key insight:** The entire phase is "wire two Elixir-standard-library mechanisms together" (OTP `Application`/`Supervisor` for lifecycle, `NimbleOptions` `default:` for config resolution) — there is no genuinely novel engineering here, which is why the risk section below focuses entirely on wiring/ordering pitfalls, not algorithmic ones.

## Common Pitfalls

### Pitfall 1: Default pool name/config drift between `Application` and `Config` schema
**What goes wrong:** `LatticeStripe.Application` starts `{Finch, name: LatticeStripe.Finch}` but `config.ex`'s `default:` value is written as a different atom, or vice versa — a client built with no `:finch` then resolves to a pool name with no running process. This fails *silently* at `Config.validate!/1` (no error — NimbleOptions just returns the default atom) and only surfaces on the first live request as a `Finch` process-not-found crash, which is the exact "invisible until a real customer call" footgun DX-01 is meant to eliminate (61-CONTEXT.md Domain section, Risk #2).
**Why it happens:** The two call sites (`lib/lattice_stripe/application.ex` and `lib/lattice_stripe/config.ex`) are separate files with no compile-time link between them — nothing forces the atom literal to match.
**How to avoid:** Define `LatticeStripe.Finch` as a single module-attribute constant referenced from both files (e.g. `@default_finch_pool LatticeStripe.Finch` — though as a bare module-name atom this doesn't strictly need a shared constant since it's just `LatticeStripe.Finch` written identically in two places), OR add an integration test that starts the real application and asserts `Client.new!(api_key: "sk_test_x").finch == Process.whereis(LatticeStripe.Finch) |> is_pid()` end-to-end (see Validation Architecture).
**Warning signs:** Any test that only checks `Config.validate!/1`'s return value (`result[:finch] == LatticeStripe.Finch`) without ever starting the real `LatticeStripe.Application` supervision tree — that only proves the *default atom* is right, not that a pool by that name is *actually running*.

### Pitfall 2: `@enforce_keys` removal masking a genuinely missing pool later
**What goes wrong:** D-03 drops `:finch` from `@enforce_keys` in `client.ex:51`. If a future code path constructs `%Client{}` via `struct!/2` directly (bypassing `Config.validate!/1` entirely — e.g., in a test helper that doesn't go through `new!/1`), `@enforce_keys` no longer catches a missing `:finch`, and the struct field defaults to `nil` (Elixir's `defstruct` behavior for fields with no explicit default), which then reaches `transport_opts = [finch: nil, ...]` (client.ex:221) and fails deep inside `Finch.request/3` with a much less clear error.
**Why it happens:** `@enforce_keys` was the *only* guard against a truly-absent `:finch` on direct struct construction; NimbleOptions `default:` only protects the `Config.validate!/1` → `Client.new!/1`/`new/1` path, not raw `struct!(Client, ...)` calls.
**How to avoid:** Confirm (via `grep -rn "struct!(Client\|struct(Client\|%Client{" lib/ test/`) that every construction path in the library itself goes through `Config.validate!/1` — it does today (`client.ex:130`, `client.ex:148`, both call `Config.validate!/1`/`Config.validate/1` first). Document in the `Client.t()` typedoc / moduledoc that `finch` is guaranteed non-`nil` only via `new!/1`/`new/1`, not via bare `struct!/2`, so downstream code (accrue, other consumers) doesn't start hand-constructing `%Client{}` structs directly.
**Warning signs:** Any test or consumer code building `%LatticeStripe.Client{api_key: ..., ...}` via struct literal syntax instead of `Client.new!/1`.

### Pitfall 3: Duplicate/orphaned Finch pool for consumers who already start their own `MyApp.Finch`
**What goes wrong:** A consumer app that (per the *current*, pre-phase docs — `guides/getting-started.md:33`, README) already starts `{Finch, name: MyApp.Finch}` in their own supervisor and passes `finch: MyApp.Finch` explicitly upgrades to this version. If they don't realize the library now *also* auto-starts `LatticeStripe.Finch`, they end up with two idle Finch pools running (their own `MyApp.Finch`, unused if they only ever pass `finch: MyApp.Finch` — actually still used since they pass it explicitly; the *new* `LatticeStripe.Finch` pool becomes the orphan, sitting idle, consuming a small number of BEAM processes/connection-pool resources for nothing).
**Why it happens:** D-04 backward compatibility means existing explicit `finch:` callers are functionally unaffected, but the *new* default pool starts regardless (unless opted out) because BYO-supervision detection isn't possible — the library cannot know a consumer is passing `finch: MyApp.Finch` at `Application.start/2` time (config validation happens later, per-`Client.new!/1` call, not at boot).
**How to avoid:** This is why D-05's opt-out exists — the CHANGELOG entry and docs (client-configuration.md, getting-started.md) must clearly tell existing BYO-Finch consumers to add `config :lattice_stripe, start_default_finch: false` if they don't want the extra idle pool. This is a *documentation* pitfall, not a code pitfall — the risk is real but low-cost (one idle default-sized Finch pool, ~1 shard, no active connections until used) and explicitly flagged as acceptable in 61-CONTEXT.md Risks section ("must be opt-out-able... or BYO-supervision users get a duplicate pool" — duplicate, not broken).
**Warning signs:** None functionally (nothing breaks) — this is purely a "slightly wasteful default" risk to call out in docs, not a bug to guard against in tests.

### Pitfall 4: `mix test` now boots the real application, changing test isolation assumptions
**What goes wrong:** Once `mix.exs` gets `mod: {LatticeStripe.Application, []}`, `mix test` (which always runs `Application.ensure_all_started/1` for the project under test before the test suite) will start the real `LatticeStripe.Finch` pool for the *entire test run*, even though every existing unit test (`client_test.exs`, `config_test.exs`) uses `LatticeStripe.MockTransport` and never touches real Finch, and every integration test starts its own separate `LatticeStripe.IntegrationFinch` pool via `start_supervised!/1` (confirmed via `grep -rn "start_supervised!({Finch" test/` — 19 integration test files, all using a distinct pool name, none named `LatticeStripe.Finch`).
**Why it happens:** This is inherent to adding `mod:` to any library's `mix.exs` — it is not a bug, but existing tests were written when no application boot happened at all (today, `application/0` returns only `[extra_applications: [:logger]]`, no `mod:`), so nobody has verified test-suite behavior with a live app-level Finch pool coexisting with per-test Mox mocks and per-test named Finch pools.
**How to avoid:** No collision risk exists today (verified — no existing test uses the literal name `LatticeStripe.Finch`), so this is low-risk, but the plan should include one smoke assertion that `mix test` still passes green with the app booted (i.e., run the full suite once during execution, not just new unit tests) and should NOT assume unit tests need to reach for the real default pool — they should keep passing explicit `finch: :test_finch` / `LatticeStripe.MockTransport` exactly as `client_test.exs` already does (no test changes needed there).
**Warning signs:** Any new test flakiness tied to Finch connection pool startup/shutdown ordering across `async: true` test files (unlikely, since `LatticeStripe.Finch` under the default app supervisor persists for the whole `mix test` run rather than being started/stopped per test).

## Code Examples

### `LatticeStripe.Application` — full adapted shape
```elixir
# Source: pattern adapted from Req.Application (unconditional variant) —
# https://github.com/wojtekmach/req/blob/main/lib/req/application.ex
# Config-gate idiom (conditional children list from Application.get_env/3) is the
# standard, widely-used Elixir library convention for boot-time opt-out toggles
# (distinct from the documented anti-pattern of libraries consuming app env for
# request-time business logic — see hexdocs.pm/elixir/Application.html "Application
# environment" section, which specifically warns against runtime *business-logic*
# config, not boot-time infrastructure toggles).
defmodule LatticeStripe.Application do
  @moduledoc """
  Optional OTP application for LatticeStripe.

  Starts a default Finch pool named `LatticeStripe.Finch` so callers can make live
  Stripe API calls without manually starting and wiring a Finch pool. `LatticeStripe.Client`
  options default `:finch` to this pool name.

  ## Disabling the default pool

  If you already manage your own Finch pool (or your own supervision tree entirely),
  disable the default pool startup:

      config :lattice_stripe, start_default_finch: false

  Pass your own pool name via `finch:` when creating a client — this works whether
  or not the default pool is running.
  """

  use Application

  @default_pool_name LatticeStripe.Finch

  @impl true
  def start(_type, _args) do
    children = default_finch_children()

    Supervisor.start_link(children, strategy: :one_for_one, name: LatticeStripe.Supervisor)
  end

  defp default_finch_children do
    if Application.get_env(:lattice_stripe, :start_default_finch, true) do
      [{Finch, name: @default_pool_name, pools: default_pools()}]
    else
      []
    end
  end

  # D-06: sensible default, overridable via app config. Finch's own defaults
  # (%{default: [size: 50, count: 1]}) are used unless the consumer overrides.
  defp default_pools do
    Application.get_env(:lattice_stripe, :default_finch_pools, %{})
  end
end
```

### `mix.exs` — `application/0`
```elixir
def application do
  [
    mod: {LatticeStripe.Application, []},
    extra_applications: [:logger]
  ]
end
```

### `config.ex` — schema change
```elixir
finch: [
  type: :atom,
  default: LatticeStripe.Finch,
  doc:
    "Name of the Finch pool to use for HTTP requests. Defaults to LatticeStripe.Finch, " <>
      "started automatically at application boot unless disabled via " <>
      "`config :lattice_stripe, start_default_finch: false`. Pass your own pool name to override."
],
```

### `client.ex` — `@enforce_keys`
```elixir
@enforce_keys [:api_key]
defstruct [
  :api_key,
  :finch,
  ...
]
```
No `default:` needed on the `defstruct` field itself — `Config.validate!/1` always injects a non-nil `:finch` (either the caller's value or the NimbleOptions default) before `struct!(__MODULE__, validated)` runs (`client.ex:130`, `client.ex:148`). The struct-level default is unnecessary and would be dead code (see Pitfall 2 for the one caveat: bare `struct!/2` calls that skip `Config.validate!/1` entirely bypass this).

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| `:finch` required in both NimbleOptions schema and `@enforce_keys`, no library-level supervision | `:finch` optional with a library-started default pool, `mod:`-registered `Application` | This phase (v1.10 Phase 61) | Closes the accrue-verified footgun (SEED-005 §3.1): a consumer that forgets to wire Finch previously got a `NimbleOptions.ValidationError` at `Client.new!/1` time (loud, but still required manual Finch setup even to get past validation) — the library had *zero* supervision tree at all before this phase (`mix.exs:265-269` currently returns only `[extra_applications: [:logger]]`). |

**Deprecated/outdated:** Nothing is deprecated — this is purely additive per D-04. The `finch:` option's `doc:` string and `client-configuration.md`/`getting-started.md` prose describing it as "required" (verified stale post-phase — `guides/getting-started.md:80` currently reads "Both `api_key` and `finch` are required," `guides/client-configuration.md:14` reads "Every client requires exactly two options") must be updated in this phase's docs task (in scope per 61-CONTEXT.md Scope Fence: "docs/README/getting-started note that a default pool now exists").

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | No hex library in this ecosystem demonstrates the exact combination of "auto-start via `mod:`" + "consumer opt-out via `Application.get_env`" for a single named process pool (I searched for this specific combination and found none — `req` auto-starts unconditionally with no opt-out; `Oban`/`Swoosh` never auto-start at all) — so the opt-out mechanism in the Framework Quick Reference is a composition of two independently-documented idioms, not a copy of one library's proven pattern. | Architecture Patterns, Framework Quick Reference | Low — both composed idioms (OTP `Application`/`Supervisor` children lists, `Application.get_env/3` reads in `start/2`) are individually standard, well-documented Elixir/OTP mechanisms, not novel engineering. Worst case if wrong: the specific `Application.get_env` key name (`:start_default_finch`) is a la carte and could be bikeshed differently, but the mechanism itself is sound. |
| A2 | `default_finch_pools/0` reading `Application.get_env(:lattice_stripe, :default_finch_pools, %{})` is the right shape for D-06 "overridable via app config" — no CONTEXT.md guidance pins the exact config key name for pool-size overrides. | Code Examples | Low — this is Claude's-discretion territory per D-06 ("Do not over-engineer... Finch defaults are acceptable"); if the planner/executor picks a different key name it doesn't affect correctness, only naming consistency. |

## Open Questions

1. **Exact opt-out config key name.**
   - What we know: D-05 explicitly proposes `config :lattice_stripe, start_default_finch: false` as an example ("*e.g.*") — not locked as the literal key name, but strongly suggested.
   - What's unclear: Whether the planner should treat this as locked (use verbatim) or as illustrative (free to rename).
   - Recommendation: Treat `start_default_finch` as locked — it's specific enough (echoed in 61-CONTEXT.md Success Criteria #4: "verified by config") that reusing it exactly avoids ambiguity for the plan-checker and matches user expectation set by the CONTEXT doc.

2. **Whether `LatticeStripe.Supervisor` needs a registered `name:`.**
   - What we know: `Supervisor.start_link/2` doesn't require a `name:` option; omitting it just means the top supervisor isn't globally addressable by name (fine for a one-child supervisor).
   - What's unclear: Whether naming it aids debugging (e.g., `Supervisor.which_children(LatticeStripe.Supervisor)` in future ops guides) enough to be worth the extra atom.
   - Recommendation: Name it (`name: LatticeStripe.Supervisor`) as shown in the Code Examples — negligible cost, matches the pattern of naming every OTP-registered process in this codebase (Finch pools are always named), and gives a debuggable handle for future guides (e.g., `guides/production-checklist.md`).

## Environment Availability

Skipped — this phase has no external tool/service dependencies beyond the Elixir/Erlang toolchain and packages already present in `mix.lock` (Finch, NimbleOptions). No Docker/stripe-mock/network dependency is needed for the phase's own unit tests; existing integration tests (already gated behind `@moduletag :integration`, excluded by default per `test/test_helper.exs:2`) are unaffected in scope.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib) — no new framework |
| Config file | `test/test_helper.exs` (Mox mocks defined here; `:integration`/`:fuse_integration`/`:otel_integration` excluded by default) |
| Quick run command | `mix test test/lattice_stripe/application_test.exs test/lattice_stripe/config_test.exs test/lattice_stripe/client_test.exs` |
| Full suite command | `mix test` (excludes `:integration` tags by default, per existing `ExUnit.configure/1`) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|--------------------|--------------|
| DX-01 (SC-1) | `Client.new!(api_key: "sk_test_x")` with no `:finch` succeeds, `client.finch == LatticeStripe.Finch` | unit | `mix test test/lattice_stripe/config_test.exs -x` | ✅ extend existing file |
| DX-01 (SC-1) | `Client.new!/1` with no `:finch` does NOT raise `NimbleOptions.ValidationError` or `ArgumentError` (enforce_keys) | unit | `mix test test/lattice_stripe/client_test.exs -x` | ✅ extend existing file |
| DX-01 (SC-2) | A client built without `:finch`, under the real (test-env) booted `LatticeStripe.Application`, successfully dispatches through `Transport.Finch` to the actually-running `LatticeStripe.Finch` pool (no process-not-found crash) | integration (real app boot, real Finch, no network — target an unroutable/localhost port or use `Finch.request/3`'s connection-error path as the assertion, OR gate behind stripe-mock like existing integration tests) | `mix test test/lattice_stripe/application_test.exs --include integration` OR unit-level: assert `Process.whereis(LatticeStripe.Finch)` is a pid + `is_pid/1` after app boot | ❌ Wave 0 — new file |
| DX-01 (SC-3) | Passing explicit `finch: MyOwnPool` still validates and is honored (unchanged behavior) | unit | `mix test test/lattice_stripe/config_test.exs -x` (existing tests already cover this — `finch: MyFinch` is passed in every existing `config_test.exs` case; add one asserting override wins over default) | ✅ extend existing file |
| DX-01 (SC-4) | `config :lattice_stripe, start_default_finch: false` prevents `LatticeStripe.Finch` from starting | unit (test the `children` list logic directly, e.g. a small pure function `LatticeStripe.Application.default_finch_children/0` or equivalent, invoked with `Application.put_env/3` toggled) — full end-to-end boot-suppression is harder to test within the same `mix test` run since the app is already booted; test the decision logic in isolation instead | `mix test test/lattice_stripe/application_test.exs -x` | ❌ Wave 0 — new file |
| SC-5 (`mix ci` green) | `mix format --check-formatted`, `compile --warnings-as-errors`, `credo --strict`, `test`, `docs --warnings-as-errors` all pass with the new public `Application` module | smoke / CI gate | `mix ci` | ✅ existing alias (`mix.exs:319-327`), no new file |

### Sampling Rate
- **Per task commit:** `mix test test/lattice_stripe/application_test.exs test/lattice_stripe/config_test.exs test/lattice_stripe/client_test.exs` (fast, no stripe-mock needed)
- **Per wave merge:** `mix test` (full suite, excludes `:integration`)
- **Phase gate:** `mix ci` full alias green before `/gsd-verify-work` — this is the phase's own Success Criterion 5, already codified as a CI gate.

### Wave 0 Gaps
- [ ] `test/lattice_stripe/application_test.exs` — covers DX-01 SC-2 (default pool actually resolvable/running), SC-4 (opt-out toggle). Suggested structure: since `LatticeStripe.Application` is already booted by the time `mix test` starts (via `mix test`'s automatic `Application.ensure_all_started/1`), most assertions in this file should be either (a) black-box — assert `Process.whereis(LatticeStripe.Finch)` is a live pid, proving the default app boot path actually started the pool — or (b) test the *decision function* in isolation by refactoring the config-read into a small private/testable function and calling it directly with `Application.put_env(:lattice_stripe, :start_default_finch, false)` / cleanup via `on_exit/1`. Prefer (a) for the "it actually works" proof and (b) for the opt-out branch, since flipping the real app's boot state mid-suite is fragile (the pool would already be running from `mix test`'s own boot before any test toggles the env var).
- [ ] No new test framework or fixtures needed — `test/test_helper.exs` and existing Mox setup are untouched by this phase.
- [ ] Framework install: none — ExUnit is stdlib.

## Security Domain

Not applicable in the ASVS-relevant sense — this phase touches process supervision and config defaulting, not authentication, session management, input validation of untrusted data, or cryptography. No new attack surface is introduced (the default Finch pool makes outbound HTTPS calls to `api.stripe.com`/`files.stripe.com` exactly as before; no new inbound surface, no new secret handling). `security_enforcement` is not explicitly disabled in `.planning/config.json`, but there is no applicable ASVS category for this phase's scope — noting this explicitly rather than fabricating a table.

## Framework Quick Reference

The concrete `use Application` + Finch child-spec shape (also duplicated inline above under Code Examples, repeated here per the task's explicit required-section instruction):

```elixir
# lib/lattice_stripe/application.ex
defmodule LatticeStripe.Application do
  @moduledoc """
  Optional OTP application for LatticeStripe. Starts a default Finch pool
  named `LatticeStripe.Finch`. See moduledoc examples for the opt-out toggle.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children =
      if Application.get_env(:lattice_stripe, :start_default_finch, true) do
        [{Finch, name: LatticeStripe.Finch, pools: default_pools()}]
      else
        []
      end

    Supervisor.start_link(children, strategy: :one_for_one, name: LatticeStripe.Supervisor)
  end

  defp default_pools do
    Application.get_env(:lattice_stripe, :default_finch_pools, %{})
  end
end
```

```elixir
# mix.exs
def application do
  [
    mod: {LatticeStripe.Application, []},
    extra_applications: [:logger]
  ]
end
```

```elixir
# Consumer opt-out (BYO-supervision), in the CONSUMING app's config/config.exs:
config :lattice_stripe, start_default_finch: false
```

```elixir
# Consumer pool-size override, without opting out entirely:
config :lattice_stripe, default_finch_pools: %{default: [size: 100, count: 4]}
```

**Finch's own default pool config** (used when `default_finch_pools` is unset): `%{default: [size: 50, count: 1]}` — 50 max HTTP/1 connections per shard, 1 shard. [CITED: finch.hexdocs.pm/Finch.html]

## Sources

### Primary (HIGH confidence)
- [Req.Application source (raw GitHub)](https://raw.githubusercontent.com/wojtekmach/req/main/lib/req/application.ex) — verbatim fetched source confirming the `use Application` + single Finch child-spec + `mod:` registration pattern.
- [Req mix.exs `application/0` (raw GitHub)](https://raw.githubusercontent.com/wojtekmach/req/main/mix.exs) — confirmed `mod: {Req.Application, []}` wiring.
- [Finch documentation](https://finch.hexdocs.pm/Finch.html) — confirmed exact child-spec shape (`{Finch, name: ..., pools: ...}`) and default pool config (`%{default: [size: 50, count: 1]}`).
- [Elixir `Application` module docs](https://elixir.hexdocs.pm/Application.html) — confirmed `mod:` key mechanics and the documented caution against libraries using application env for business logic (used to justify the boot-time-toggle exception in this research, not to contradict it).
- Local codebase (verified via Read/grep): `lib/lattice_stripe/config.ex:31-116` (schema, `finch:` at 69-74), `lib/lattice_stripe/client.ex:51-131,221` (`@enforce_keys`, `new!/1`, `transport_opts`), `mix.exs:265-269,282,319-327` (`application/0`, Finch dep, `mix ci` alias), `.credo.exs:102` (`Readability.ModuleDoc` active in strict config), `test/lattice_stripe/{config,client}_test.exs` (existing test patterns), 19 `test/integration/*.exs` files (confirmed all use `LatticeStripe.IntegrationFinch`, no name collision with the new `LatticeStripe.Finch`), `guides/getting-started.md:80`, `guides/client-configuration.md:14` (stale "required" prose to update in-phase).

### Secondary (MEDIUM confidence)
- [Swoosh Finch adapter default pool name](https://hexdocs.pm/swoosh/Swoosh.ApiClient.Finch.html) (via WebSearch summary, not directly fetched) — Swoosh names its consumer-started pool `Swoosh.Finch` by convention but does not auto-start it (no `mod:` in Swoosh's own `mix.exs`); used as a contrast case, not a copied pattern.
- Oban documentation (via WebSearch summary) — confirmed Oban is never auto-started; consumers add `{Oban, config}` to their own supervisor. Used as contrast for why LatticeStripe's simpler case can auto-start where Oban cannot.

### Tertiary (LOW confidence)
- None — this phase's domain (OTP Application, Finch, NimbleOptions) is narrow enough that primary/secondary sources plus direct codebase verification covered every claim.

## Project Constraints (from CLAUDE.md)

- **No Dialyzer** — typespecs are documentation-only, not enforced. The new `LatticeStripe.Application` module should still carry accurate `@spec`/typedoc-style docs for consistency, but no Dialyzer gate applies.
- **HTTP: Transport behaviour with Finch as default adapter** — this phase does not touch the `Transport` behaviour (explicitly out of scope per CONTEXT.md Scope Fence); it only changes Finch pool *lifecycle*, not the transport abstraction.
- **Dependencies: minimal, only what's truly needed** — zero new dependencies added by this phase (Finch and NimbleOptions are pre-existing).
- **`mix ci` alias** (`format --check-formatted`, `compile --warnings-as-errors`, `credo --strict`, `test`, `docs --warnings-as-errors`) must stay green — directly restated as CONTEXT.md Success Criterion 5; `.credo.exs:102` confirms `Readability.ModuleDoc` is active in strict mode, so `LatticeStripe.Application` needs a real `@moduledoc` (not `false`).
- **GSD Workflow Enforcement** — all file edits for this phase must flow through `/gsd-plan-phase` → `/gsd-execute-phase`, not direct ad-hoc edits.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies; Finch/NimbleOptions already vetted and in use.
- Architecture: HIGH — `req`'s source was fetched verbatim and confirms the core wiring pattern; the opt-out composition is a standard, individually-documented OTP idiom (flagged as A1 in Assumptions Log since no single comparator demonstrates the exact combination).
- Pitfalls: HIGH — all four pitfalls are grounded in direct inspection of this codebase's actual files (client.ex:221 transport_opts, existing integration test Finch pool names, the current lack of any `mod:`), not speculation.

**Research date:** 2026-07-27
**Valid until:** 2026-08-26 (30 days — stable Elixir/OTP domain, no fast-moving dependencies involved)
