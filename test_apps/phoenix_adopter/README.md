# Phoenix adopter example

This isolated Phoenix host demonstrates the core LatticeStripe integration without live Stripe credentials, network delivery, or server sockets. It is a test app and does not add Phoenix or Mox to the SDK's runtime dependencies.

From a fresh checkout, fetch dependencies and run the example:

```sh
cd test_apps/phoenix_adopter
mix deps.get
mix test
```

The host depends on the checked-out SDK through `path: "../../"` and keeps its own `mix.lock`. Phoenix owns the Endpoint, application supervision, routes, and application configuration. LatticeStripe starts its default Finch pool under its own application supervisor; the test asserts that the host does not create a duplicate pool. Checkout uses an explicit Mox transport that returns synthetic Stripe-shaped data, so the test cannot make an API request.

The `/checkout` route creates a typed subscription Checkout Session. The webhook endpoint mounts `LatticeStripe.Webhook.Plug` before request parsing so signature verification sees the original request bytes. A correctly signed synthetic completion event reaches the typed handler; changing the body while retaining the signature is rejected before dispatch.

This demonstrates request construction, response decoding, host supervision, and webhook signature verification. Checkout creation is not proof of payment: the verified webhook is the asynchronous confirmation boundary. This harness does not demonstrate live Stripe delivery, durable event processing, or duplicate-event handling. For production guidance, see the [Checkout guide](../../guides/checkout.md) and [webhook guide](../../guides/webhooks.md).
