---
phase: 21-customer-portal
plan: 03
type: execute
wave: 2
depends_on:
  - 21-02
files_modified:
  - lib/lattice_stripe/billing_portal/session.ex
  - lib/lattice_stripe/billing_portal/guards.ex
  - test/lattice_stripe/billing_portal/session_test.exs
  - test/lattice_stripe/billing_portal/guards_test.exs
autonomous: true
requirements:
  - PORTAL-01
  - PORTAL-02
  - PORTAL-04
  - PORTAL-05
  - PORTAL-06
must_haves:
  truths:
    - "Session.create/3 with valid customer returns {:ok, %Session{url: url}} via Mox-mocked Transport"
    - "Session.create/3 raises ArgumentError BEFORE network call when customer is missing"
    - "Session.create/3 raises ArgumentError BEFORE network call for all 4 guard-matrix missing-field cases"
    - "Session.create/3 raises ArgumentError with 'unknown flow_data.type' for non-whitelisted strings, enumerating 4 valid types"
    - "Session.create!/3 bang variant raises on error result"
    - "Session.create/3 threads stripe_account: opt through to the request headers (Mox assertion)"
    - "Session struct's Inspect impl hides :url and :flow fields"
    - "Session.from_map/1 decodes all 10 PORTAL-05 fields + flow via FlowData.from_map/1"
  artifacts:
    - path: "lib/lattice_stripe/billing_portal/session.ex"
      provides: "LatticeStripe.BillingPortal.Session resource module + defimpl Inspect"
      contains: "defmodule LatticeStripe.BillingPortal.Session"
    - path: "lib/lattice_stripe/billing_portal/guards.ex"
      provides: "LatticeStripe.BillingPortal.Guards pre-flight validator (@moduledoc false)"
      contains: "check_flow_data!"
  key_links:
    - from: "lib/lattice_stripe/billing_portal/session.ex"
      to: "lib/lattice_stripe/billing_portal/guards.ex"
      via: "BillingPortal.Guards.check_flow_data!(params) call in create/3"
      pattern: "BillingPortal.Guards.check_flow_data!"
    - from: "lib/lattice_stripe/billing_portal/session.ex"
      to: "lib/lattice_stripe/billing_portal/session/flow_data.ex"
      via: "FlowData.from_map(map[\"flow\"]) in Session.from_map/1"
      pattern: "FlowData.from_map"
---

<objective>
Ship the Session resource module, Guards pre-flight validator, and Inspect masking implementation VERBATIM as locked in CONTEXT.md D-01 and D-03. This is the core phase deliverable — every PORTAL-* requirement closes here.

Purpose: Deliver `LatticeStripe.BillingPortal.Session.create/3` such that (a) valid calls round-trip through stripe-mock to `%Session{url: url}`, (b) missing required sub-fields raise `ArgumentError` pre-network with actionable messages, (c) session URLs never leak via default Inspect output (Phase 20 D-02 forward commitment).
Output: 2 `.ex` files, full unit test coverage (14+ assertions), all PORTAL-01..06 requirements satisfied.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/21-customer-portal/21-CONTEXT.md
@.planning/phases/21-customer-portal/21-RESEARCH.md
@lib/lattice_stripe/checkout/session.ex
@lib/lattice_stripe/billing/meter_event_adjustment.ex
@lib/lattice_stripe/billing/guards.ex
@lib/lattice_stripe/billing/meter_event.ex
@lib/lattice_stripe/resource.ex
@lib/lattice_stripe/billing_portal/session/flow_data.ex
@test/support/fixtures/billing_portal.ex

<interfaces>
<!-- LatticeStripe.BillingPortal.Guards — VERBATIM from CONTEXT.md D-01 lines 61-135. -->
<!-- Executor implements this exactly as written; do NOT rewrite. -->

```elixir
defmodule LatticeStripe.BillingPortal.Guards do
  @moduledoc false
  # Guard numbering scheme (discoverability entry point):
  #
  #   PORTAL-GUARD-01 — check_flow_data!/1 (flow_data.type dispatch + required sub-fields)
  #
  # Pre-flight guards live alongside their resource namespace per Phase 20 D-01.
  # BillingPortal and Billing are unrelated Stripe surfaces that happen to share
  # the word "billing"; see .planning/v1.1-accrue-context.md.

  @fn_name "LatticeStripe.BillingPortal.Session.create/3"

  @doc """
  Pre-flight guard for `LatticeStripe.BillingPortal.Session.create/3`.

  Raises `ArgumentError` when `flow_data.type` is a known type whose required
  nested sub-fields are missing, OR when `flow_data.type` is an unknown string,
  OR when `flow_data` is present but malformed. Silent-passes when `flow_data`
  is omitted entirely (valid — Stripe renders the default portal homepage).

  Reads string keys only (Stripe wire format — Phase 20 D-06). Atom-keyed
  params bypass the guard; the HTTP layer will surface Stripe's 400.
  """
  @spec check_flow_data!(map()) :: :ok
  def check_flow_data!(%{"flow_data" => flow}) when is_map(flow), do: check_flow!(flow)
  def check_flow_data!(_), do: :ok

  # payment_method_update has no required sub-fields.
  defp check_flow!(%{"type" => "payment_method_update"}), do: :ok

  # subscription_cancel requires .subscription_cancel.subscription
  defp check_flow!(%{"type" => "subscription_cancel",
                     "subscription_cancel" => %{"subscription" => s}})
       when is_binary(s) and byte_size(s) > 0, do: :ok
  defp check_flow!(%{"type" => "subscription_cancel"} = f),
    do: raise_missing!("subscription_cancel", "subscription_cancel.subscription", f)

  # subscription_update requires .subscription_update.subscription
  defp check_flow!(%{"type" => "subscription_update",
                     "subscription_update" => %{"subscription" => s}})
       when is_binary(s) and byte_size(s) > 0, do: :ok
  defp check_flow!(%{"type" => "subscription_update"} = f),
    do: raise_missing!("subscription_update", "subscription_update.subscription", f)

  # subscription_update_confirm requires .subscription_update_confirm.subscription
  # AND .subscription_update_confirm.items (non-empty list)
  defp check_flow!(%{"type" => "subscription_update_confirm",
                     "subscription_update_confirm" => %{"subscription" => s, "items" => i}})
       when is_binary(s) and byte_size(s) > 0 and is_list(i) and i != [], do: :ok
  defp check_flow!(%{"type" => "subscription_update_confirm"} = f),
    do: raise_missing!("subscription_update_confirm",
                       "subscription_update_confirm.subscription AND .items (non-empty list)", f)

  # Unknown type string — enumerate the valid set in the error.
  defp check_flow!(%{"type" => type}) when is_binary(type) do
    raise ArgumentError,
          "#{@fn_name}: unknown flow_data.type #{inspect(type)}. Valid types: " <>
            ~s["subscription_cancel", "subscription_update", ] <>
            ~s["subscription_update_confirm", "payment_method_update".]
  end

  # Malformed flow_data (no type key, or non-binary type).
  defp check_flow!(flow) do
    raise ArgumentError,
          ~s[#{@fn_name}: flow_data must contain a "type" key, got: #{inspect(flow)}]
  end

  defp raise_missing!(type, path, flow) do
    raise ArgumentError,
          ~s[#{@fn_name}: flow_data.type is "#{type}" but required field ] <>
            ~s[#{path} is missing. Got flow_data: #{inspect(flow)}]
  end
end
```

<!-- Session.create/3 call site shape (RESEARCH Pattern 1, mirrors MeterEventAdjustment) -->

```elixir
def create(%Client{} = client, params, opts \\ []) when is_map(params) do
  Resource.require_param!(params, "customer",
    "LatticeStripe.BillingPortal.Session.create/3 requires a customer param")

  BillingPortal.Guards.check_flow_data!(params)

  %Request{method: :post, path: "/v1/billing_portal/sessions", params: params, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end
```

<!-- Session defimpl Inspect — VERBATIM from CONTEXT.md D-03 lines 299-353. -->
<!-- See CONTEXT.md for the full block with rationale comments — copy the whole thing. -->

```elixir
defimpl Inspect, for: LatticeStripe.BillingPortal.Session do
  import Inspect.Algebra

  def inspect(session, opts) do
    fields = [
      id: session.id,
      object: session.object,
      livemode: session.livemode,
      customer: session.customer,
      configuration: session.configuration,
      on_behalf_of: session.on_behalf_of,
      created: session.created,
      return_url: session.return_url,
      locale: session.locale
    ]

    pairs =
      fields
      |> Enum.map(fn {k, v} ->
        concat([Atom.to_string(k), ": ", to_doc(v, opts)])
      end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.BillingPortal.Session<" | pairs] ++ [">"])
  end
end
```

<!-- Resource.require_param!/3 — existing primitive -->
@spec require_param!(map(), String.t(), String.t()) :: :ok
def require_param!(params, key, message)
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: BillingPortal.Guards module + full guard matrix tests</name>
  <files>lib/lattice_stripe/billing_portal/guards.ex, test/lattice_stripe/billing_portal/guards_test.exs</files>
  <behavior>
Replace `@tag :skip` stubs in guards_test.exs with the CONTEXT.md D-01 ten-case matrix:

1. No `flow_data` key → `:ok`
2. `%{"flow_data" => %{"type" => "payment_method_update"}}` → `:ok`
3. subscription_cancel happy path (with `subscription_cancel.subscription` binary) → `:ok`
4. subscription_cancel missing sub-object → raises, message contains `"subscription_cancel.subscription"`
5. subscription_cancel with empty `subscription_cancel.subscription` → raises, same message
6. subscription_update happy path → `:ok`
7. subscription_update missing sub-object → raises, message contains `"subscription_update.subscription"`
8. subscription_update_confirm happy path (subscription binary + non-empty items list) → `:ok`
9. subscription_update_confirm with `items: []` → raises, message contains `"subscription_update_confirm.subscription AND .items"`
10. Unknown type `"subscription_pause"` → raises, message contains `"unknown flow_data.type"` AND all 4 valid types enumerated

Plus 2 extra: malformed flow_data (no type key) → raises "must contain a \"type\" key"; non-map flow_data (e.g. atom) → passes via `check_flow_data!(_)` catchall → `:ok`.

Every raise asserts message contains `"LatticeStripe.BillingPortal.Session.create/3"` prefix.
  </behavior>
  <action>
Create `lib/lattice_stripe/billing_portal/guards.ex` VERBATIM from the `<interfaces>` block above (CONTEXT.md D-01 code is locked — do not alter a single line, including comment block, `@fn_name`, clause ordering, `@moduledoc false`). Mirror `lib/lattice_stripe/billing/guards.ex` module shape for ordering conventions.

Flesh out `test/lattice_stripe/billing_portal/guards_test.exs` — remove `@tag :skip` from every test, implement all 12 assertions above. Use `assert_raise ArgumentError, ~r/pattern/, fn -> ... end` for raise cases. Tests run with `async: true`. Reference the full D-01 matrix in CONTEXT.md for exact message substrings.
  </action>
  <verify>
    <automated>cd /Users/jon/projects/lattice_stripe && mix test test/lattice_stripe/billing_portal/guards_test.exs</automated>
  </verify>
  <done>Guards module compiled with `@moduledoc false`; all 12 guard_test.exs cases green; unknown-type error lists all 4 valid types; every raise message includes the fully-qualified function name; closes PORTAL-04.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Session resource module + from_map + defimpl Inspect</name>
  <files>lib/lattice_stripe/billing_portal/session.ex, test/lattice_stripe/billing_portal/session_test.exs</files>
  <behavior>
- `Session.create/3` with `%{"customer" => "cus_1"}` via Mox-mocked Transport (returning fixture basic/0) → `{:ok, %Session{id: "bps_123", customer: "cus_test123", url: "https://..."}}`
- `Session.create/3` with `%{}` → raises `ArgumentError, ~r/requires a customer param/` BEFORE Mox is called (assert via `verify!` that no Transport call was made).
- `Session.create/3` with customer + malformed flow_data → raises via Guards.check_flow_data! BEFORE Mox called.
- `Session.create!/3` on `{:error, %Error{}}` → raises; on `{:ok, session}` → returns `%Session{}` unwrapped.
- `Session.create/3` with `opts: [stripe_account: "acct_test"]` → Mox expects request with `Stripe-Account` header; assertion on forwarded opts per MeterEventAdjustment precedent (PORTAL-06).
- `Session.from_map/1` on `BillingPortal.Session.with_subscription_cancel_flow/0` fixture → fully decoded struct with `session.flow.subscription_cancel.subscription == "sub_123"` (atom-dot chain).
- `inspect(%Session{url: "https://billing.stripe.com/secret_token", ...})` → string contains `"id:"`, `"customer:"`, `"livemode:"`, `"return_url:"`; does NOT contain `"https://billing.stripe.com/secret_token"` AND does NOT contain `"FlowData"` substring.
  </behavior>
  <action>
Create `lib/lattice_stripe/billing_portal/session.ex` containing:

1. **`defmodule LatticeStripe.BillingPortal.Session`** with comprehensive `@moduledoc` covering:
   - What the Billing Portal is (one-paragraph framing)
   - `create/3` usage with `customer` + optional keys summary
   - Cross-link to `LatticeStripe.BillingPortal.Session.FlowData` for deep-link flow schemas
   - Security note: `:url` is single-use ~5 min TTL bearer credential, masked by default in Inspect output, access via `session.url` directly when redirecting
   - Note per D-04/CONTEXT Discretion F: "portal configuration is managed via Stripe dashboard in v1.1 — `LatticeStripe.BillingPortal.Configuration` planned for v1.2+"

2. **`alias`/`import`:** `alias LatticeStripe.{Client, Request, Resource}`; `alias LatticeStripe.BillingPortal.{Guards}`; `alias LatticeStripe.BillingPortal.Session.FlowData`.

3. **`@known_fields ~w(id object customer url return_url created livemode locale configuration on_behalf_of flow)`** — all 11 Stripe response fields for PORTAL-05.

4. **`@type t :: %__MODULE__{...}`** + `defstruct` with those 11 fields + `extra: %{}` — follow checkout/session.ex shape.

5. **`create/3`** — RESEARCH Pattern 1. Exact shape from `<interfaces>` block above. Order: `Resource.require_param!(params, "customer", ...)` → `Guards.check_flow_data!(params)` → `%Request{method: :post, path: "/v1/billing_portal/sessions", params: params, opts: opts}` → `Client.request/2` → `Resource.unwrap_singular(&from_map/1)`. `@spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, LatticeStripe.Error.t()}`. Comprehensive `@doc` with examples for basic create, flow_data cases, and `stripe_account:` opt.

6. **`create!/3`** — bang variant: `client |> create(params, opts) |> Resource.unwrap_bang!()`. `@spec create!(Client.t(), map(), keyword()) :: t()`.

7. **`from_map/1`** — two clauses (`nil` → `nil`, `is_map` → `%__MODULE__{...}`). Each of the 11 `@known_fields` gets `map["<key>"]`, EXCEPT `flow` which uses `FlowData.from_map(map["flow"])`. `extra: Map.drop(map, @known_fields)`.

8. **`defimpl Inspect, for: LatticeStripe.BillingPortal.Session`** — VERBATIM from `<interfaces>` block (CONTEXT.md D-03 lines 299-353, including full rationale comment block). Place at bottom of session.ex after the module's `end`.

NO retrieve/list/update/delete functions (PORTAL-02 — Stripe API does not expose).

Flesh out `test/lattice_stripe/billing_portal/session_test.exs` — remove `@tag :skip` from all describe blocks and implement the behaviors listed above. Uses `LatticeStripe.MockTransport` (Mox) per Phase 20 precedent; test_helper.exs already sets up Mox global mode.

Inspect test (D-03 spec):
```elixir
test "masks :url and :flow in Inspect output" do
  session = %Session{
    id: "bps_123", object: "billing_portal.session", livemode: false,
    customer: "cus_test", url: "https://billing.stripe.com/secret_abc",
    return_url: "https://example.com", created: 123,
    flow: %FlowData{type: "subscription_cancel"}
  }
  output = inspect(session)
  assert output =~ "#LatticeStripe.BillingPortal.Session<"
  assert output =~ "id: \"bps_123\""
  assert output =~ "customer: \"cus_test\""
  refute output =~ session.url
  refute output =~ "FlowData"
  refute output =~ "secret_abc"
end
```
  </action>
  <verify>
    <automated>cd /Users/jon/projects/lattice_stripe && mix test test/lattice_stripe/billing_portal/session_test.exs test/lattice_stripe/billing_portal/guards_test.exs</automated>
  </verify>
  <done>Session resource compiles; session_test.exs green; all PORTAL-01/02/04/05/06 + D-03 Inspect requirements covered; `inspect(session) =~ session.url` returns false.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Caller → `Session.create/3` params | Untrusted host-app params (unvalidated customer, flow_data shapes, return_url) |
| `%Session{}` → Logger/APM/telemetry | Decoded struct carries `:url` bearer credential; any `inspect/1` call can leak |
| Caller → Stripe via Transport | Connect `stripe_account:` opt must thread correctly or portal session belongs to wrong account |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-21-05 | Information Disclosure | `%Session{}.url` via Logger.info(session) / crash dump / telemetry handler | mitigate | `defimpl Inspect` allowlist (D-03) hides `:url` and `:flow`. Tested via `refute inspect(session) =~ session.url` in session_test.exs. This is the Phase 21 SC #4 gate. |
| T-21-06 | Elevation of Privilege | malformed `flow_data.type` silently forwarded to Stripe, causing 400 leak of internal error to end user | mitigate | `BillingPortal.Guards.check_flow_data!/1` binary catchall (`when is_binary(type)`) makes unknown strings structurally impossible to forward. Tested via case 10 of guard matrix (PORTAL-04). |
| T-21-07 | Spoofing | missing Connect `stripe_account:` opt creates portal session on platform account instead of connected account | mitigate | `Session.create/3` opts threading tested via Mox header assertion in session_test.exs (PORTAL-06). Existing `Client.request/2` primitive handles `Stripe-Account` header from `opts[:stripe_account]`. |
| T-21-08 | Information Disclosure | unvalidated `return_url` enables open-redirect from host app | accept | Stripe enforces HTTPS and URL-shape validation server-side; SDK forwards string as-is. Host app responsibility to validate per-user. Documented in the guide (plan 21-04) §"Security and session lifetime". |
| T-21-09 | Tampering | confused-deputy on `customer` ID (caller passes wrong customer) | accept | SDK has no user-context to validate against; host app's authorization layer is responsible. `Resource.require_param!` catches missing `customer` only. |
| T-21-10 | Information Disclosure | `:flow` sub-struct rendering `after_completion.redirect.return_url` in Inspect output | mitigate | D-03 hides entire `:flow` field from default Inspect. `IO.inspect(session, structs: false)` is the documented escape hatch. |
</threat_model>

<verification>
- `mix compile --warnings-as-errors` clean
- `mix test test/lattice_stripe/billing_portal/` full green (guards + session + flow_data)
- `mix credo --strict lib/lattice_stripe/billing_portal/` clean
- Manual grep: `grep -n "defmodule LatticeStripe.BillingPortal.Session" lib/lattice_stripe/billing_portal/session.ex` → exactly one match
- Manual grep: `grep -n "retrieve\|list\|update\|delete" lib/lattice_stripe/billing_portal/session.ex` → zero matches (PORTAL-02)
</verification>

<success_criteria>
1. `Session.create/3` happy path returns `{:ok, %Session{url: url}}` when Transport mock returns fixture basic/0.
2. `Session.create/3` raises `ArgumentError` pre-network for all 12 guards_test.exs cases (Guards invoked before Client.request).
3. `Session.create/3` with `opts: [stripe_account: "acct_x"]` threads header through Mox expectation.
4. `Session.from_map/1` fully decodes all 11 fields, `flow` via `FlowData.from_map/1`, unknown keys into `:extra`.
5. `inspect(session)` output does NOT contain `session.url` and does NOT contain `"FlowData"`.
6. No retrieve/list/update/delete functions defined.
</success_criteria>

<output>
After completion, create `.planning/phases/21-customer-portal/21-03-session-resource-guards-SUMMARY.md`.
</output>
