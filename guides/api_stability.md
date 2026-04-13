# API Stability

> LatticeStripe 1.0.0 commits to API stability under standard semantic
> versioning. This guide documents exactly what is covered by that contract
> and what is explicitly excluded.

LatticeStripe follows [Semantic Versioning 2.0.0](https://semver.org) from
v1.0.0 forward. Once you pin to `~> 1.0`, you can expect additive changes
within the 1.x line and never a silent break. The contract applies to
the surface described below — anything outside it is an implementation
detail and may change without a major bump.

## What is public API

Every module documented in HexDocs (that is, every module *without*
`@moduledoc false`) is public API. The semver contract covers:

- **Public module names and aliases** — renaming or removing a public
  module is a major bump.
- **Public function signatures** — name, arity, parameter shape, and
  return type of every `@doc`-annotated function.
- **Public struct field names** — *adding* fields to a public struct is
  non-breaking; *removing* or *renaming* a field is breaking.
- **Error reason atoms** in `LatticeStripe.Error` — the `:type` field's
  documented atom set is stable. New atoms may be added (minor bump);
  existing ones will not silently change meaning.
- **Telemetry event names and metadata keys** in
  `LatticeStripe.Telemetry` — the documented event list and measurement
  keys are stable for the 1.x line.
- **NimbleOptions schema keys** in `LatticeStripe.Config` — options
  accepted by `LatticeStripe.Client.new!/1` and `new/1` are stable
  within 1.x. Adding options is non-breaking; removing them is a major
  bump.

## What is NOT public API

Modules with `@moduledoc false` are internal implementation details.
They are visible in the source tree — this is Elixir, there is no
privacy enforcement — but they are explicitly excluded from the semver
contract. These modules may change in any patch release without notice:

- `LatticeStripe.FormEncoder`
- `LatticeStripe.Request`
- `LatticeStripe.Resource`
- `LatticeStripe.Transport.Finch`
- `LatticeStripe.Json.Jason`
- `LatticeStripe.RetryStrategy.Default`
- `LatticeStripe.Webhook.CacheBodyReader`
- `LatticeStripe.Billing.Guards`

If your application depends on any of these modules, you are relying on
an implementation detail and should expect breakage. Prefer the public
behaviours listed below as extension points.

## Extension points (public behaviours)

Three behaviours are public API precisely because they are designed for
user implementation. Custom implementations of these behaviours are
supported and will continue to be supported for the 1.x lifetime:

- **`LatticeStripe.Transport`** — swap the HTTP client. LatticeStripe
  ships a Finch adapter by default, but any module implementing this
  behaviour can be plugged in via the `:transport` config.
- **`LatticeStripe.Json`** — swap the JSON codec. Jason is the default;
  any codec implementing `encode/1` and `decode/1` works.
- **`LatticeStripe.RetryStrategy`** — customize retry logic. The default
  strategy honours Stripe's `Stripe-Should-Retry` header and the
  `idempotency-replayed` response header, but platforms with exotic
  retry budgets can supply their own module.

These are the designed-in extension points. Building on top of them is
safe across the 1.x line.

## Versioning policy

After v1.0.0, LatticeStripe follows post-1.0 semver strictly:

- **Patch** (1.0.x) — bug fixes, documentation corrections, internal
  refactors, dependency version bumps that do not change the public
  surface. No behaviour changes that a working application would notice.
- **Minor** (1.x.0) — additive features only: new resource modules, new
  function arities, new optional fields on existing structs, new
  NimbleOptions schema keys, new Telemetry metadata keys, new
  `LatticeStripe.Error` reason atoms. Nothing that would break an
  existing correctly-typed call site.
- **Major** (x.0.0) — breaking changes to the public API: removed or
  renamed functions, changed function signatures, removed struct
  fields, changed error type semantics, dropped Elixir/OTP version
  support.

**This overrides the pre-1.0 rule from Phase 11 D-16.** While the
library was in 0.x, breaking changes were allowed in minor bumps. From
v1.0.0 forward, that rule no longer applies — a breaking change
requires a major bump, full stop. Pin to `~> 1.0` with confidence.

## Deprecation policy

When a public API is scheduled for removal, LatticeStripe will mark the
affected function or module with `@deprecated` in a minor release,
accompanied by a CHANGELOG entry explaining the migration path. The
deprecated surface continues to work normally until the next major
release, at which point it may be removed.

Deprecation warnings are emitted by the Elixir compiler at call sites
during `mix compile`. Treat them as a heads-up to plan migration before
the next major — the deprecated call will not suddenly stop working
inside the current major line.

## See also

- [CHANGELOG](../changelog.html) — every release's changes, with
  Highlights narratives for major versions
- [Extending LatticeStripe](extending-lattice-stripe.md) — concrete
  recipes for the three public behaviours
- [Getting Started](getting-started.md) — first steps for new users
