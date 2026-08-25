# LatticeStripe contributor guide

LatticeStripe is an idiomatic Elixir SDK for Stripe. Its primary design goal is
that adopters can integrate payments with confidence: behavior is correct,
documented, pattern-matchable, and unsurprising.

The shipped source, tests, public guides, and `.planning/PROJECT.md` are the
current truth. Historical planning and `prompts/archive/` explain past choices
but do not override the code or public contract.

## Supported environment

- Elixir 1.15+ and OTP 26+
- Finch transport, Jason JSON, `:telemetry`, and optional Plug integration
- No Dialyzer gate; public typespecs are documentation and extension contracts
- No application database or Ecto layer

## Architecture

- `%LatticeStripe.Client{}` is immutable configuration passed explicitly.
- `LatticeStripe.Client` owns the request pipeline and delegates HTTP, JSON, and
  retry policy through narrow behaviours.
- `LatticeStripe.Resource` holds shared request mechanics; public resource
  modules keep routes, verbs, guards, docs, and return types explicit.
- `LatticeStripe.ObjectTypes` is the compile-time Stripe object decoder.
- `LatticeStripe.List` implements typed pages and lazy cursor streams.
- `LatticeStripe.Error` is the stable structured error boundary.
- `LatticeStripe.Testing` and its fixture modules are shipped adopter-facing
  testing support, not disposable test internals.

Processes exist only at runtime boundaries that need ownership, such as Finch
connections. Do not introduce a resource DSL, code-generated public API,
global mutable client, or hidden process state to reduce ordinary repetition.

## Public API conventions

- Prefer `{:ok, value} | {:error, %LatticeStripe.Error{}}`; layer `!` variants
  on the non-bang implementation where both are appropriate.
- Keep destructive or irreversible operations explicit verbs.
- Preserve per-request option precedence and pass pagination options through
  every page fetch.
- Keep unknown Stripe fields available through existing escape hatches.
- Document consumer intent, inputs, return/error shape, and non-obvious Stripe
  constraints. Do not expose internal planning IDs or implementation history.
- Comments should explain a wire quirk, security/privacy boundary, ordering or
  failure invariant, or another fact the code cannot express on its own.

## Verification

Run the complete local gate before committing a behavior or public-doc change:

```sh
mix ci
```

The alias checks formatting, warnings, Credo, tests, the public API snapshot,
version prose, and warning-free ExDoc. Useful focused checks include:

```sh
mix test path/to/test.exs
mix lattice_stripe.api_surface --check
mix lattice_stripe.version_prose --check
mix docs --warnings-as-errors
mix deps.audit
mix deps.unlock --check-unused
```

Do not update `priv/api/current.txt` merely to make a failure green. Any public
module/function/arity/field/type/callback/protocol change requires an explicit
compatibility decision. The canonical regression locks are:

- `test/lattice_stripe/api_surface_lock_test.exs`
- `test/lattice_stripe/docs_truth_test.exs`
- `test/lattice_stripe/testing/wrapper_completeness_test.exs`
- `test/lattice_stripe/object_types_test.exs`

Integration tests use the transport behaviour for deterministic request proof
and a pinned `stripe-mock` image for protocol smoke coverage. `stripe-mock`
does not prove live Stripe state, complete response realism, or multi-page data.

## Documentation and releases

- `README.md` is the evaluator entry point.
- `guides/getting-started.md`, `guides/user-flows-and-jtbd.md`, and
  `guides/scope.md` route readers into the canonical guides.
- HexDocs is the product UI for this headless library; headings, navigation,
  examples, links, and error microcopy are user experience work.
- Release Please owns package version bumps, changelog release sections,
  GitHub releases, tags, and the normal Hex publish path. Do not hand-edit the
  release manifest to bypass it.

See `CONTRIBUTING.md` for contributor workflow and
`docs/maintainer-release.md` for maintainer-only release operations.
