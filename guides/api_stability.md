# API Stability

LatticeStripe follows [Semantic Versioning 2.0.0](https://semver.org). The 2.x
release line may add capabilities, but it does not silently change documented
calls or values that existing applications depend on. A breaking public change
requires a new major release and an upgrade path.

This guide defines that boundary. It is for application authors deciding what
they can safely depend on and extension authors deciding where customization is
supported.

## What is public API

Every module rendered in HexDocs is public API. The compatibility contract
covers:

- **Public module names and aliases.** Renaming or removing one is breaking.
- **Public functions.** Names, arities, accepted parameter shapes, return
  shapes, raised exceptions, and documented behavior are stable within 2.x.
- **Public structs.** Documented field names, field types, and value
  representations are stable. For example, changing a timestamp from a Unix
  integer to a `DateTime`, a documented status from an atom to a string, or an
  expanded field from a typed struct to a raw map is breaking. Adding an
  optional field is additive; removing or renaming a field is breaking.
- **Errors.** Documented `LatticeStripe.Error` types, field meanings, and error
  tuple shapes are stable. New error types may be added without changing the
  meaning of existing ones.
- **Configuration.** Options accepted by `LatticeStripe.Client.new/1` and
  `new!/1`, their documented types, defaults, and precedence rules are stable.
- **Telemetry.** Documented event names, measurements, and metadata keys are
  stable. New metadata may be added, so handlers should read the keys they need
  instead of asserting exact map equality.
- **Public testing helpers and fixtures.** Function names and documented output
  shapes are application-facing contracts because adopter test suites compile
  against them.

Stripe can add fields and enum values without notice. LatticeStripe preserves
unknown resource fields in each struct's `extra` map and leaves unknown finite
values unchanged. Match the values you handle and provide a fallback instead of
assuming today's set is exhaustive.

## What is not public API

Modules marked `@moduledoc false` are implementation details. Elixir does not
enforce module privacy, but calling those modules opts out of the compatibility
contract. They can change in a patch release when an internal refactor requires
it.

This includes internal encoders, concrete default adapters, resource decoding
helpers, default retry policy implementation, and billing guard helpers. Use
the documented resource modules and public behaviours instead.

`LatticeStripe.Request` is public because `LatticeStripe.Client.request/2`
accepts it. The concrete modules used behind public behaviours are not public
merely because their source is visible.

## Supported extension points

Three behaviours are designed for application implementations:

- **`LatticeStripe.Transport`** — replace the HTTP transport or provide a test
  transport.
- **`LatticeStripe.Json`** — replace the JSON codec.
- **`LatticeStripe.RetryStrategy`** — customize retry decisions and backoff.

Implementations of these behaviours may rely on their documented callbacks and
types throughout 2.x. Other internal modules are not extension points.

## Release meanings

- **Patch (2.x.y)** — compatible bug fixes, documentation corrections,
  security fixes, dependency updates, and internal refactors.
- **Minor (2.y.0)** — additive modules, functions, optional fields, options,
  error types, or telemetry metadata. Existing documented calls and value
  representations continue to work.
- **Major (x.0.0)** — removals, renames, changed parameter or result shapes,
  changed struct field types or value representations, changed error semantics,
  or dropped Elixir/OTP support.

A fix that would change documented runtime behavior is not hidden in a patch.
It is either implemented compatibly, deprecated first, or reserved for a major
release.

## Deprecation policy

When a public API is scheduled for removal, a compatible release marks it with
`@deprecated` and the changelog identifies the replacement. The deprecated
surface keeps working for the rest of the current major line. Removal can occur
in the next major release.

Treat compiler deprecation warnings as migration notice, not an immediate
runtime failure. New code should use the replacement so the eventual major
upgrade remains mechanical.

## See also

- [Client Configuration](client-configuration.md) — client options and
  per-request precedence
- [Testing](testing.md) — public fixtures and supported transport mocking
- [Extending LatticeStripe](extending-lattice-stripe.md) — examples for the
  three supported behaviours
- [Changelog](../CHANGELOG.md) — release-by-release additions, fixes, and
  migrations
