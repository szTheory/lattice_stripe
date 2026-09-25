# Phoenix adopter example

This isolated Phoenix host demonstrates the core LatticeStripe integration without live Stripe credentials, network delivery, or server sockets. It is a test app and does not add Phoenix or Mox to the SDK's runtime dependencies.

From a fresh checkout, resolve the adopter's lockfile and run its full suite:

```sh
cd test_apps/phoenix_adopter
mix deps.get --check-locked
mix test
```

CI runs the same suite with warnings treated as errors. To select an individual
profile, run its test file from this directory:

```sh
mix test test/b2b_invoice_profile_test.exs
mix test test/usage_reconciliation_profile_test.exs
mix test test/connect_context_profile_test.exs
```

The host depends on the checked-out SDK through `path: "../../"` and keeps its own `mix.lock`. Phoenix owns the Endpoint, application supervision, routes, and application configuration. LatticeStripe starts its default Finch pool under its own application supervisor; the test asserts that the host does not create a duplicate pool. Checkout uses an explicit Mox transport that returns synthetic Stripe-shaped data, so the test cannot make an API request.

For post-publish proof, run `scripts/maintainer/release_evidence_check.sh --version X.Y.Z --sha FULL_RELEASE_SHA` from the repository root. It verifies the main/tag/Release/`ci-gate` chain, compares Hex's public checksum with the downloaded package tarball, checks versioned HexDocs, and runs `scripts/maintainer/published_hex_adopter_smoke.sh X.Y.Z`. The smoke copies this host into a temporary project, sets `MIX_LATTICE_STRIPE_HEX_VERSION` to an exact version, and checks both Mix's Hex-package source and the generated lock entry before compiling and running the synthetic core-flow tests. Its dependency/deps/build/Hex cache state is isolated and it unsets Stripe credential variables; normal CI continues using the local path dependency.

The `/checkout` route creates a typed subscription Checkout Session. The webhook endpoint mounts `LatticeStripe.Webhook.Plug` before request parsing so signature verification sees the original request bytes. A correctly signed synthetic completion event reaches the typed handler; changing the body while retaining the signature is rejected before dispatch.

The B2B profile requests API version `2026-05-27.dahlia` to prove that a synthetic invoice response decodes `amount_paid_off_stripe` alongside `amount_paid`. Its fixture and the structured 400 case exercise SDK request and error contracts only. An SDK response or verified event is not proof of durable reconciliation or processing. This harness does not demonstrate live Stripe delivery or duplicate-event handling. For production guidance, see the [Checkout guide](../../guides/checkout-signup-and-portal.md) and [webhook guide](../../guides/webhooks.md).
