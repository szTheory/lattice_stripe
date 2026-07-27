# SEED-006 — Accrue-driven DX / ergonomics (deferred from v1.8.0)

Status: **CAPTURED — PARKED.** Lower-priority DX split out of SEED-005 so v1.8.0
stays focused on the P0/P1 surface gaps. Revisit after v1.8.0 ships, or when accrue
pulls on a specific item.
Captured: 2026-07-27
Evidence: `.planning/research/accrue-gap-brief-2026-07-27.txt` (Section 3), verified
against accrue's vendored `lattice_stripe` 1.7.13.

Each item below is evidenced by machinery accrue had to duplicate. None is blocking;
all are additive.

- **3.2  Semver discipline on struct shape / value types.** v1.3.0 shipped status
  atomization + typed-expand as a *minor* bump, which `~> 1.1` silently accepted.
  Ask: treat struct-shape/value-type changes as major, or gate behind an opt-in
  client flag (e.g. `atomize_statuses: true`) for one deprecation cycle.
- **3.5  Opt-in DateTime deserialization.** Timestamps come back as raw Unix ints;
  accrue has 13 `DateTime.from_unix` sites + 4 near-identical converters. Ask: a
  `datetimes: true` client option (opt-in so it's non-breaking — see 3.2).
- **3.6  Canonical deep `to_map/1`.** Accrue reimplements the same dual-key accessor
  (`Map.get(m, k) || Map.get(m, Atom.to_string(k))`) in **15 files** because struct
  top-level keys are atoms while nested/webhook keys are strings. Ask:
  `LatticeStripe.Resource.to_map/1,2` with configurable key shape
  (`:string | :atom | :existing_atom`).
- **3.7  `platform_scoped: true` request opt.** Some Connect endpoints (Account
  Links, Login Links) 400 if `Stripe-Account` is present; accrue builds a whole
  second client to work around it. Ask: a per-request `platform_scoped: true` (or
  `stripe_account: :none`) that suppresses the header without a second client.
- **3.8  Documented `idempotency_key_fn` hook.** We auto-gen per-POST UUID keys;
  accrue generates deterministic operation-seeded keys (survives process death).
  Now there are two idempotency systems. Ask: a documented `idempotency_key_fn`
  client hook so a consumer's scheme can be THE scheme.
- **3.9  Stub transport / official fake.** We have the primitives (Transport
  behaviour + Testing.Fixtures) but they aren't wired into a usable fake; accrue
  hand-carved a 2,736-line simulator. Ask (scoped): `transport:
  LatticeStripe.Transport.Stub` returning correctly-shaped typed structs for core
  billing objects. (Accrue explicitly does NOT want us to own its Fake — just a
  canonical shape to diff against.)
- **3.11  Misc.** Memoized/named client to avoid per-call NimbleOptions validation
  (`LatticeStripe.Client.fetch(:default)`); docs callouts for native `:expand`,
  auto-pagination adoption, retries/timeouts, telemetry integration, and
  `require_explicit_proration` as a recommended-on safety.

Related, cross-cutting (also in the brief): signature-verification failures surface
two different shapes (typed `SignatureVerificationError` AND an `%Error{code:
"signature_verification_failed"}`) — pick one. Worth folding into the 3.3 error work.
