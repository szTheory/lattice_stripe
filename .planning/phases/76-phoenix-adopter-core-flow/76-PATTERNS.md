# Phase 76: Phoenix Adopter Core Flow - Pattern Map

**Mapped:** 2026-09-24  
**Files analyzed:** 8 target groups from Phase 76 CONTEXT and RESEARCH  
**Analogs found:** 7 / 8 (host-app path-dependency harness has no in-repo equivalent)

> Scope note: Phase 76 CONTEXT and RESEARCH now lock the host app at `test_apps/phoenix_adopter`. This is a headless SDK adoption proof; no UI, brand system, or Ecto persistence behavior is in scope.

## File Classification

| Target | Role | Data flow | Closest tracked analog | Match quality |
|---|---|---|---|---|
| `test_apps/phoenix_adopter/mix.exs` and `mix.lock` | config / test host app | dependency resolution, application boot | `mix.exs` | role-match; no path-dependency adopter app exists |
| `test_apps/phoenix_adopter/config/{config,test}.exs` | config | startup configuration | `lib/lattice_stripe/application.ex`, `guides/webhooks.md` | partial |
| `test_apps/phoenix_adopter/lib/.../application.ex`, endpoint/router and minimal billing context/controller | OTP app / route / controller | request-response | `guides/webhooks.md` endpoint recipe; `guides/checkout-signup-and-portal.md` | role-match; these are public recipes, not compiled host code |
| `test_apps/phoenix_adopter/test/...` | integration test | request-response + event-driven webhook | `test/lattice_stripe/webhook/plug_test.exs`; `test/lattice_stripe/checkout/session_test.exs` | role-match |
| `test_apps/phoenix_adopter/test/support/...` (only if test isolation needs helpers) | test utility | fixture/transform | `test/support/test_helpers.ex`; `LatticeStripe.Testing` | role-match |
| `.github/workflows/ci.yml` | CI config | batch / verification | self, optional dependency job and Tax adoption gate | exact for workflow style |
| `guides/checkout-signup-and-portal.md` / `guides/webhooks.md` (only if gaps are found) | adopter docs | docs-prose / discovery | self | exact; avoid duplicating existing guidance |
| `mix.exs` (only if package metadata/docs navigation must change) | package config | static config | self | exact |

## Pattern Assignments

### Phoenix path-dependency host app (`test_apps/phoenix_adopter/**`)

**Analog:** None in the tracked repository. The library has no Phoenix dependency and no existing executable consumer application. Do not treat `_build`, `deps`, or `.gsd` mirrors as analogs. The closest guidance is `guides/checkout-signup-and-portal.md` and `guides/webhooks.md`; the closest boot contract is `lib/lattice_stripe/application.ex`.

**Package dependency and supervision constraints** (`mix.exs` lines 190-205; `lib/lattice_stripe/application.ex` lines 1-63):

```elixir
{:finch, "~> 0.21"},
{:jason, "~> 1.4"},
{:telemetry, "~> 1.0"},
{:nimble_options, "~> 1.0"},
{:plug_crypto, "~> 2.0"},
{:plug, "~> 1.16", optional: true},
```

The Phoenix host must bring its own Phoenix/Plug dependencies. LatticeStripe deliberately keeps Plug optional; do not make Phoenix or Ecto a runtime dependency of the SDK for this proof. The package application starts its default Finch pool automatically; a host-owned pool can be passed explicitly via `finch:`. The host fixture should demonstrate the documented path and process ownership, not add a second idle pool accidentally.

**No-secret client setup** (`lib/lattice_stripe/client.ex` lines 50-65; `test/support/test_helpers.ex` lines 6-18):

```elixir
@enforce_keys [:api_key]
defstruct [
  :api_key,
  :finch,
  :stripe_account,
  base_url: "https://api.stripe.com",
  api_version: "2026-03-25.dahlia",
  transport: LatticeStripe.Transport.Finch,
  ...
]
```

Use a clearly synthetic `sk_test_...` key and deterministic transport/fixture flow; never read production credentials in the CI contract. A `path: "../../.."` relative path must be computed from the adopter project's `mix.exs` location and asserted by actually resolving the package as a dependency. Keep any nested lockfile and dependency fetch reproducible. There is no Ecto mapping layer in LatticeStripe; introduce a Repo only if CONTEXT explicitly requires persistence, not just because Phoenix commonly ships with Ecto.

### Checkout/subscription request path (host request/response test)

**Analog:** `test/lattice_stripe/checkout/session_test.exs` (tracked), with public flow wording from `guides/checkout-signup-and-portal.md`.

**Mock transport idiom** (`session_test.exs` lines 1-13, 17-34):

```elixir
use ExUnit.Case, async: true
import Mox
import LatticeStripe.TestHelpers
setup :verify_on_exit!

client = test_client()
expect(LatticeStripe.MockTransport, :request, fn req ->
  assert req.method == :post
  assert String.ends_with?(req.url, "/v1/checkout/sessions")
  assert req.body =~ "mode=subscription"
  ok_response(checkout_session_subscription_json())
end)

assert {:ok, %Session{mode: :subscription, subscription: "sub_test123"}} =
         Session.create(client, params)
```

Copy the explicit Client + transport seam, request assertions, and typed-response match. For a Phoenix boundary test, drive a real `Plug.Test`/Phoenix endpoint request to the app route and inject a deterministic transport, so the test proves host wiring plus SDK decoding. Avoid external HTTP or live Stripe calls. The current `test/integration/checkout_session_integration_test.exs` is a stripe-mock protocol suite tagged `:integration`, expects a service on port 12111, and is not an analog for a credential-free host-app CI gate.

### Webhook endpoint and handler path

**Analog:** `test/lattice_stripe/webhook/plug_test.exs` (tracked), plus `guides/webhooks.md` for canonical endpoint ordering and handler contract.

**Signature and Plug.Test setup** (`plug_test.exs` lines 1-10, 81-100):

```elixir
@secret "whsec_plug_test_secret"
@payload Jason.encode!(EventFixture.event_map())

defp valid_sig_header do
  Webhook.generate_test_signature(@payload, @secret)
end

defp build_conn(method, path, body, sig_header) do
  conn = Plug.Test.conn(method, path, body)
  %{conn | req_headers: [{"stripe-signature", sig_header} | conn.req_headers]}
end
```

For host-app tests, prefer shipped `LatticeStripe.Testing.generate_webhook_payload/3` plus a fixed `whsec_test...` secret and send the raw signed body to the actual endpoint. Assert the handler receives a typed `%LatticeStripe.Event{}` and that the route returns the documented response. Mount `LatticeStripe.Webhook.Plug` before `Plug.Parsers` (guide lines 31-53); raw bytes are signature input. Keep handler work thin and return promptly (`guides/webhooks.md` lines 70-107). Do not test dispatch only by directly invoking the handler if the phase's criterion is host boundary integration.

### Shared application config and transport seam

**Source:** `lib/lattice_stripe/application.ex` lines 1-63; `lib/lattice_stripe/transport.ex` lines 1-50; `test/support/test_helpers.ex` lines 6-45.

`LatticeStripe.Client` is immutable config passed explicitly, and `LatticeStripe.Transport` is the intended HTTP boundary. Test code's canonical defaults are `api_key: "sk_test_123"`, `finch: :test_finch`, `transport: LatticeStripe.MockTransport`, `telemetry_enabled: false`, and `max_retries: 0`; zero retries keeps async Mox expectations deterministic. At the host-app level, inject a test transport or use the package's supported fixture/testing API. Do not substitute application-global mutable client state or bypass the Client to make the proof easy.

### CI entry for the adopter contract

**Analog:** `.github/workflows/ci.yml` (tracked), especially the matrix test job and single-configuration adoption gate around lines 153-200; `test/lattice_stripe/tax/adoption_contract_test.exs` lines 1-19, 72-115.

```yaml
- name: Run tests
  run: mix test

- name: Tax adoption contract
  if: matrix.elixir == '1.19' && matrix.otp == '28'
  run: mix test test/lattice_stripe/tax/adoption_contract_test.exs --warnings-as-errors
```

The adopter app should have one explicit, discoverable CI command and run with synthetic data only. Decide whether CI calls nested `mix test` from the adopter directory or provides a root alias; do not hide a second Mix project behind broad custom shell logic. Preserve existing CI matrix and make the gate run once unless cross-version Phoenix compatibility is an explicit requirement. CI currently ignores `.planning/**` only, so a committed test-only app is normally visible to CI.

## Shared Patterns

### Checkout truth and event truth

**Sources:** `guides/checkout-signup-and-portal.md` lines 13-38, 104-120, 122-143; `guides/webhooks.md` lines 109-120.

Create a hosted subscription Checkout Session and use the URL for the browser interaction. Treat the success route as UX; treat verified webhooks and follow-up retrieval as billing-state evidence. Keep app controllers thin and app policy in an application context/service. Do not claim that accepting one synthetic event proves Stripe lifecycle delivery, duplicate handling, persistent idempotency, or provisioning correctness unless those are actually tested.

### Public docs are existing UX contracts

**Sources:** `prompts/README.md`; `CLAUDE.md` Documentation and releases section; `mix.exs` `docs.extras` and `groups_for_extras`.

`prompts/README.md` says `payments_domain_field_guide.md` is the current prompt-domain reference and archived prompts are historical; shipped code/docs and `.planning/PROJECT.md` take precedence. There is no separate brand book: UX for this headless package is API, errors, examples, guide navigation, and HexDocs. The recurring signup and webhook trust rails already exist in canonical guides. If a doc edit becomes part of scope, extend/cross-link those guides and register any new guide in both ExDoc lists; do not create a competing quickstart without a proven information gap.

## No Analog Found

| Target | Why no analog |
|---|---|
| Test-only Phoenix host app imported with a local path dependency | No tracked host Phoenix app exists in the repository. The package itself has no Phoenix or Ecto dependency. Use current Phoenix generator conventions only if needed, and keep the sample minimal to the success criteria. |

## Metadata

**Analog search scope:** `lib/lattice_stripe/`, `test/`, `guides/`, `mix.exs`, `.github/workflows/ci.yml`, `prompts/`, `.planning/ROADMAP.md`, and `CLAUDE.md`.  
**Tracked-source gate:** Every code analog named above was verified with `git ls-files`; no ignored runtime mirror is referenced.  
**Files scanned:** 11 strong analogs / guidance files.  
**Pattern extraction date:** 2026-09-24.  
**Refresh needed:** No. The paths and ownership now align with Phase 76 CONTEXT and RESEARCH; refine exact filenames during planning if the selected Phoenix skeleton needs a different module layout.
