---
id: SEED-007
status: dormant
planted: 2026-09-25
planted_during: v1.12 complete; awaiting next milestone
trigger_when: when planning a major release or revisiting the minimum supported Elixir version
scope: future milestone
---

# SEED-007 — Revisit Jason as a required runtime dependency

## Why This Matters

Elixir 1.18 added built-in JSON encoding and decoding. LatticeStripe currently
supports Elixir 1.15, so Jason is still needed for the oldest supported versions.
Once the supported minimum reaches 1.18, consider using the built-in `JSON` module
as the default codec so consumers do not have to take Jason as a required runtime
dependency.

The SDK already exposes a configurable `LatticeStripe.Json` codec, but some runtime
paths still call Jason directly. A future migration needs to audit and route those
paths through the codec (or the built-in implementation), while preserving the
observable encoding, decoding, and error behavior relied on by callers.

## When to Surface

**Trigger:** when planning a major release or revisiting the minimum supported Elixir
version. Surface this before deciding whether to raise the minimum to 1.18 or later,
so the dependency tradeoff can be considered alongside compatibility policy.

At that point, reassess whether Jason can be removed from required runtime
dependencies without keeping a compatibility fallback for older Elixir versions.

## Scope Estimate

**Medium** — audit direct Jason call sites across request building, webhooks, drift
checking, and other runtime paths; migrate and verify codec behavior; then update
dependency and supported-version documentation as appropriate.

## Breadcrumbs

- `mix.exs` — current minimum Elixir version (`~> 1.15`) and Jason runtime dependency.
- `.github/workflows/ci.yml` — compatibility matrix includes Elixir 1.15 / OTP 26.
- `lib/lattice_stripe/json.ex` and `lib/lattice_stripe/json/jason.ex` — configurable
  codec behaviour and current Jason adapter.
- `lib/lattice_stripe/client/request_builder.ex`, `lib/lattice_stripe/webhook.ex`,
  and `lib/lattice_stripe/drift.ex` — examples of runtime paths that call Jason
  directly rather than using the configured codec.

## Notes

Elixir's built-in `JSON` module was introduced in 1.18. Revisit this seed during
version-support planning; it does not commit the project to raising the minimum
version or removing Jason until compatibility and migration costs are assessed.
