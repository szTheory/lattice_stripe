# Phase 21: Customer Portal - Context

**Gathered:** 2026-04-14
**Status:** Ready for planning
**Milestone:** v1.1 (Accrue unblockers — final phase)
**Commit anchor:** 51149ed

<domain>
## Phase Boundary

Ship `LatticeStripe.BillingPortal.Session` — a create-only resource that returns a short-lived, single-use authenticated URL the host app redirects customers to. Includes a polymorphic `Session.FlowData` nested-struct tree for deep-linking into four flow types (`subscription_cancel`, `subscription_update`, `subscription_update_confirm`, `payment_method_update`), client-side flow-type validation that prevents server-side 400s, `:url` Inspect masking, integration tests against stripe-mock, and `guides/customer-portal.md`. Unblocks Accrue CHKT-02 (Customer Portal wrapper) — the last v1.1 feature before the zero-touch release-please auto-ship.

**Requirements:** PORTAL-01..06, TEST-02, TEST-04, TEST-05 (portal portion), DOCS-02, DOCS-03 (Customer Portal group).

**In scope:**

- `LatticeStripe.BillingPortal.Session` resource module — `create/3` + `create!/3` only. No retrieve/list/update/delete (Stripe API does not expose them).
- 5 nested typed sub-struct modules under `LatticeStripe.BillingPortal.Session.FlowData.*`:
  - `FlowData` (parent, polymorphic on `type`)
  - `FlowData.AfterCompletion`
  - `FlowData.SubscriptionCancel`
  - `FlowData.SubscriptionUpdate`
  - `FlowData.SubscriptionUpdateConfirm`
  - (No module for `payment_method_update` — it has zero extra fields.)
- New `LatticeStripe.BillingPortal.Guards` module with `check_flow_data!/1` pre-flight validator using the GUARD-03 pattern-match idiom.
- `defimpl Inspect, for: LatticeStripe.BillingPortal.Session` — allowlist masking of `:url` and `:flow`.
- `test/support/fixtures/billing_portal.ex` — canonical `Session` fixture with at least one `FlowData` shape per flow type (TEST-02).
- Wave 0 `stripe-mock` probe for `/v1/billing_portal/sessions` (TEST-04).
- `:integration`-tagged full portal flow test (TEST-05 portal portion).
- `guides/customer-portal.md` — new MODERATE-envelope guide (~240 lines, 7 H2).
- `mix.exs` updates — add guide to `extras`, add `"Customer Portal"` group to `groups_for_modules`.
- Cross-links from `guides/subscriptions.md` §Lifecycle/§Proration and `guides/webhooks.md` (reciprocal).

**Out of scope (locked deferrals):**

- `BillingPortal.Configuration` CRUDL (v1.1 D4 — hosts manage portal config via Stripe dashboard for v1.1; may ship v1.2+).
- `Session` retrieve/list/update/delete (Stripe API does not expose).
- Release-cut phase (zero-touch via release-please per `.planning/v1.1-accrue-context.md`; last `feat:` commit of Phase 21 auto-ships v1.1.0).
- Atom normalization of `flow_data.type` on ingress (Phase 20 D-06 — string-keyed wire format only).
- Function-head atom guards on `flow_data.type` in `Session.create/3` (Phase 17 D-04c — this pattern fits positional closed enums only, not nested-map string-valued keys).
- NimbleOptions schema validation of `flow_data` (Phase 19 D-16, Phase 20 D-01 — validates keyword lists well, nested string-keyed maps poorly; contradicts minimal-deps philosophy).
- Typed sub-modules for `AfterCompletion.redirect` / `AfterCompletion.hosted_confirmation` / `SubscriptionCancel.retention` / `SubscriptionUpdateConfirm.items` / `SubscriptionUpdateConfirm.discounts` — these stay as raw maps (`map()` or `[map()]`) per the "shallow leaf objects don't warrant modules" principle applied in Checkout.Session's `line_items` treatment.

</domain>

<decisions>
## Implementation Decisions (Locked — D-01..D-04)

### D-01 — Flow-type validation architecture

**Module:** new `LatticeStripe.BillingPortal.Guards` at `lib/lattice_stripe/billing_portal/guards.ex` with `@moduledoc false`.

**Public surface:** single function `check_flow_data!/1 :: (map()) :: :ok`.

**Dispatch shape:** pattern-match function-head clauses on a private `check_flow!/1` — one happy-path clause per flow type asserting the required nested shape, one missing-field clause per type raising with a type-specific message, a `when is_binary(type)` catchall for unknown strings, and a final catchall for malformed `flow_data`. Mirrors the GUARD-03 (`check_adjustment_cancel_shape!/1`) idiom exactly.

**Call site:** `LatticeStripe.BillingPortal.Session.create/3`, after `Resource.require_param!(params, "customer", ...)` and before the `Resource.request/6` call. One line.

**Full implementation:**

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

**Test matrix (10 cases, belongs in Plan 21-0X resource plan):**

1. No `flow_data` key → `:ok`
2. `flow_data: %{"type" => "payment_method_update"}` → `:ok`
3. `flow_data: %{"type" => "subscription_cancel", "subscription_cancel" => %{"subscription" => "sub_123"}}` → `:ok`
4. `flow_data: %{"type" => "subscription_cancel", "subscription_cancel" => %{}}` → raises, message contains `"subscription_cancel.subscription"`
5. `flow_data: %{"type" => "subscription_cancel"}` → raises, message contains `"subscription_cancel.subscription"`
6. `flow_data: %{"type" => "subscription_update", "subscription_update" => %{"subscription" => "sub_456"}}` → `:ok`
7. `flow_data: %{"type" => "subscription_update"}` → raises, message contains `"subscription_update.subscription"`
8. `flow_data: %{"type" => "subscription_update_confirm", "subscription_update_confirm" => %{"subscription" => "sub_789", "items" => [%{}]}}` → `:ok`
9. `flow_data: %{"type" => "subscription_update_confirm", "subscription_update_confirm" => %{"subscription" => "sub_789", "items" => []}}` → raises (empty items list), message contains `"subscription_update_confirm.subscription AND .items"`
10. `flow_data: %{"type" => "subscription_pause"}` → raises, message contains `"unknown flow_data.type"` AND lists all four valid types

**Rationale:** Pattern-match clauses beat `cond` dispatch (precision stack traces, independently testable branches), beat data-driven `@required_fields` maps (better per-type error messages, closer semantic match to the locked GUARD-03 idiom, handles the `items` non-empty check naturally), beat extending `Billing.Guards` (namespace false friend — `billing` and `billing_portal` are unrelated Stripe surfaces), and beat inline private functions in `Session.ex` (violates Phase 20 D-01 "guards alongside resource namespace", untestable without touching the resource module). The `pause_collection/5` precedent PORTAL-04 cites is philosophical parallel — validate a closed enum before the network call — not implementation parallel, since `behavior` there is a positional atom argument. stripity_stripe does zero client-side validation (flow_data.subscription typed as plain optional, invalid shapes round-trip to Stripe as 400s); stripe-node/ruby/python are OpenAPI-generated and share that gap. LatticeStripe's entire differentiator on PORTAL-04 is catching the footgun pre-network with an actionable message that names the missing field path and enumerates valid types in the unknown-type error. The binary catchall (`when is_binary(type)`) makes "unknown type silently forwarded to Stripe" structurally impossible — any non-whitelisted string falls into the catchall and raises. Success Criterion #2 and #3 are both satisfied by construction.

**Rejected:**
- `cond` dispatch (Option 2) — less precise stack traces, branch ordering fragility; GUARD-03 pattern-match is the closer semantic match for "nested required sub-object + closed enum dispatch".
- Extending `LatticeStripe.Billing.Guards` (Option 3) — namespace false friend; Phase 20 D-01 literally says "alongside the resource namespace" and `BillingPortal.*` is a separate namespace from `Billing.*`.
- Inline private functions in `Session.ex` (Option 4) — contradicts Phase 20 D-01 precedent; untestable without touching the resource module; harder to extend if Stripe adds a 5th flow type.
- Data-driven `@required_fields` dispatch map (Option 5) — generic error messages weaken the DX win that is PORTAL-04's whole point; `subscription_update_confirm.items` non-empty check doesn't fit the uniform "paths" schema cleanly, forcing custom logic that undermines the DRY argument.
- NimbleOptions — already rejected in Phase 19 D-16 and Phase 20 D-01 for nested string-keyed map params.
- Function-head atom guards in `Session.create/3` — Phase 17 D-04c forbids for nested-in-map enums.

---

### D-02 — FlowData nested-struct shape: 5-module polymorphic-flat layout

**Module tree (5 files under `lib/lattice_stripe/billing_portal/session/flow_data/`):**

1. `flow_data.ex` — parent `LatticeStripe.BillingPortal.Session.FlowData`. Fields: `:type`, `:after_completion`, `:subscription_cancel`, `:subscription_update`, `:subscription_update_confirm`, `:extra`.
2. `flow_data/after_completion.ex` — `LatticeStripe.BillingPortal.Session.FlowData.AfterCompletion`. Fields: `:type`, `:redirect` (raw map), `:hosted_confirmation` (raw map), `:extra`.
3. `flow_data/subscription_cancel.ex` — Fields: `:subscription`, `:retention` (raw map), `:extra`.
4. `flow_data/subscription_update.ex` — Fields: `:subscription`, `:extra`.
5. `flow_data/subscription_update_confirm.ex` — Fields: `:subscription`, `:items` (list of raw maps), `:discounts` (list of raw maps), `:extra`.

**No module for `payment_method_update`** — it has zero extra fields beyond `type`. Its presence is fully expressed by `flow_data.type == "payment_method_update"` in the parent `FlowData` struct.

**Shallow leaf sub-fields deliberately kept as raw maps:**
- `AfterCompletion.redirect` / `.hosted_confirmation` — single-field terminal objects
- `SubscriptionCancel.retention` (`%{type, coupon_offer: %{coupon}}`) — leaf with shallow sub-shape
- `SubscriptionUpdateConfirm.items` (`[%{id, price?, quantity?}]`) — user-submitted collection, mirrors Checkout.Session `line_items: map()` treatment
- `SubscriptionUpdateConfirm.discounts` (`[%{coupon?, promotion_code?}]`) — same reasoning

This matches Meter's footprint exactly (5 nested sub-structs for a single parent resource).

**Parent `FlowData` full sketch:**

```elixir
defmodule LatticeStripe.BillingPortal.Session.FlowData do
  @moduledoc """
  The `flow` sub-object echoed back on a `LatticeStripe.BillingPortal.Session`.

  Polymorphic on `type`: one of `"subscription_cancel"`, `"subscription_update"`,
  `"subscription_update_confirm"`, `"payment_method_update"`. Only the branch
  matching `type` is populated; the others are `nil`. Unknown flow types added
  by future Stripe API versions land in `:extra` unchanged — existing branches
  continue to work and consumers read the new type from `flow.extra["<new>"]`
  until LatticeStripe promotes it to a first-class sub-struct.
  """

  alias LatticeStripe.BillingPortal.Session.FlowData.{
    AfterCompletion,
    SubscriptionCancel,
    SubscriptionUpdate,
    SubscriptionUpdateConfirm
  }

  @known_fields ~w(type after_completion subscription_cancel
                   subscription_update subscription_update_confirm)

  @type t :: %__MODULE__{
          type: String.t() | nil,
          after_completion: AfterCompletion.t() | nil,
          subscription_cancel: SubscriptionCancel.t() | nil,
          subscription_update: SubscriptionUpdate.t() | nil,
          subscription_update_confirm: SubscriptionUpdateConfirm.t() | nil,
          extra: map()
        }

  defstruct [
    :type,
    :after_completion,
    :subscription_cancel,
    :subscription_update,
    :subscription_update_confirm,
    extra: %{}
  ]

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    %__MODULE__{
      type: map["type"],
      after_completion: AfterCompletion.from_map(map["after_completion"]),
      subscription_cancel: SubscriptionCancel.from_map(map["subscription_cancel"]),
      subscription_update: SubscriptionUpdate.from_map(map["subscription_update"]),
      subscription_update_confirm:
        SubscriptionUpdateConfirm.from_map(map["subscription_update_confirm"]),
      extra: Map.drop(map, @known_fields)
    }
  end
end
```

Each sub-struct follows the locked `Meter.ValueSettings` template exactly: `@known_fields` list, `defstruct` with `:extra` default `%{}`, `@spec from_map(map() | nil) :: t() | nil`, `nil`/`is_map` guards, `Map.drop(map, @known_fields)` for the extra capture.

**Integration with Session:**
- `LatticeStripe.BillingPortal.Session` struct has a `:flow` field.
- `Session.from_map/1` decodes it as `FlowData.from_map(map["flow"])`, yielding `%FlowData{} | nil`.
- Outgoing `flow_data` params on `Session.create/3` stay **string-keyed raw maps** per Phase 20 D-06 — there is no encode path, only decode. Users pass `%{"type" => "subscription_cancel", "subscription_cancel" => %{"subscription" => "sub_123"}}` directly.

**DX access pattern:** `session.flow.subscription_cancel.subscription` — pure atom dot-access, no string-key hop. `session.flow.after_completion.redirect["return_url"]` for the shallow raw-map leaf (one hop allowed).

**Forward compatibility story:** Stripe adds `subscription_pause` in a future API version →
1. Session response JSON has `"flow": {"type": "subscription_pause", "subscription_pause": {...}}`
2. `FlowData.from_map/1` sets `flow.type = "subscription_pause"`, all four existing branch fields stay `nil`, and `flow.extra = %{"subscription_pause" => %{...}}`
3. Existing user code reading `flow.subscription_cancel` continues to return `nil` without crashing.
4. New users opting in read `flow.extra["subscription_pause"]` as a raw map.
5. LatticeStripe v1.2 adds a 6th sub-module `FlowData.SubscriptionPause` and promotes `@known_fields` to include it.

**Rationale:** Three forces converge on Option 2. First, **coherence with Phase 20**: `Meter` already ships 5 nested sub-structs (`DefaultAggregation`, `CustomerMapping`, `ValueSettings`, `StatusTransitions`) + `MeterEventAdjustment.Cancel`. Shipping `FlowData` as flat raw maps would force users to code-switch between `meter.value_settings.event_payload_key` (atom dot) and `session.flow.subscription_cancel["subscription"]` (string bracket) across the same SDK — the exact surprise Phase 20 D-03 was written to prevent. Second, **Checkout.Session is a counter-example, not a precedent**: `shipping_options`/`payment_method_options`/`automatic_tax` are `map() | nil` because those sub-objects are enormous (dozens of payment method variants with deep sub-shapes). Phase 10 predated the Phase 17/20 nested-struct commitment — it is legacy debt the project has already decided not to repeat. FlowData is tiny, fully enumerated, four types, at most three levels deep — the exact size the nested-struct idiom was designed for. Third, **polymorphism is not a blocker**: Stripe's wire format keeps each branch in its own named key (`subscription_cancel`, `subscription_update`, ...) rather than inlining fields under a single `data` key. The parent `FlowData` struct holds all four branch fields with `nil` indicating inactivity — exactly like `Meter` has all four sub-structs populated by `from_map/1` unconditionally. Option 3 (polymorphic union, 4 per-type structs with no parent) would force every consumer to `case` on four concrete types at every call site — worse DX than `session.flow.subscription_cancel` being `nil`. Options 1/4 lose the typed-struct guarantee that Accrue's CHKT-02 will rely on for round-trip tests. stripity_stripe takes Option 4 (flat raw maps) — that's their whole approach — but LatticeStripe's contract is concrete structs users can pattern-match against, which is the differentiator Accrue is consuming.

**Rejected:**
- Option 1 (flat FlowData + raw maps for branches) — breaks atom-dot access DX; users string-key their way through every branch.
- Option 3 (polymorphic union, no parent) — no `%FlowData{}` to pattern-match against; new Stripe flow types have no home in the typespec; forces exhaustive `case` at every call site.
- Option 4 (fully flat, raw maps everywhere) — stripity_stripe's approach; violates Phase 20 D-03 for a user-facing polymorphic field.
- Option 5 (parametric `:branch_data` opaque map) — invents a synthetic field Stripe didn't send; breaks round-trip symmetry; loses raw wire shape.
- Promoting `retention` / `items` / `discounts` / `redirect` / `hosted_confirmation` to additional sub-modules — out of scope; shallow leaves; inlining matches Checkout.Session `line_items` precedent and keeps module count at 5 (matching Meter footprint exactly).

---

### D-03 — BillingPortal.Session Inspect allowlist

**Pattern:** allowlist `defimpl Inspect` using `Inspect.Algebra`, matching `Customer` / `MeterEvent` / `Checkout.Session` precedents.

**Visible fields (exact order):** `id`, `object`, `livemode`, `customer`, `configuration`, `on_behalf_of`, `created`, `return_url`, `locale`

**Hidden fields:** `url`, `flow`

**Critical precedent uncovered:** `Checkout.Session`'s `url` is **already hidden** in its existing `defimpl Inspect` (lib/lattice_stripe/checkout/session.ex:658-684). "Stripe session URLs are uniformly masked in LatticeStripe" is therefore a *de facto* SDK invariant already; Phase 21 is making it explicit for the higher-sensitivity portal variant.

**Per-field rationale:**

Visible:
- **`id`** — primary identifier (`bps_...`). Appears in Dashboard. Precedent across all three existing impls.
- **`object`** — `"billing_portal.session"`. Disambiguates from Checkout.Session in mixed logs. Zero sensitivity.
- **`livemode`** — critical environment signal. Precedent across all three existing impls.
- **`customer`** — `cus_*` ID. Pointer, not PII — identifies nothing without Stripe API access. Biggest debugging win for multi-customer log noise. Under GDPR a Stripe customer ID alone is not a direct identifier.
- **`configuration`** — `bpc_*` ID or `nil`. Critical for debugging deep-link / custom-branded portal flows. Not sensitive — visible in Dashboard.
- **`on_behalf_of`** — Connect account ID or `nil`. The only way to tell which connected account the portal session belongs to in a multi-tenant Connect platform. Not a credential.
- **`created`** — unix timestamp. Helps reason about the ~5-minute TTL window.
- **`return_url`** — host-controlled URL. Not an auth token. Host already knows it (they passed it in). Helps "why did customer land on /foo instead of /bar" debug.
- **`locale`** — `"en"`, `"auto"`, etc. Occasional debug signal for i18n issues.

Hidden:
- **`url`** — **THE ASSET UNDER PROTECTION**. Single-use, ~5-minute TTL, full customer impersonation for portal scope. Any Logger/APM/crash-dump/telemetry leak during the TTL window is an account takeover vector on the billing surface. This is Phase 21 Success Criterion #4 and the Phase 20 D-02 forward commitment.
- **`flow`** — nested `%FlowData{}` struct. Hidden for two reasons: (1) bloats Inspect output (violates the "structural one-liner" shape of every other impl), (2) `flow.after_completion.redirect` can echo arbitrary redirect URLs and `subscription_cancel.retention.coupon_offer` can carry promotional data that is flow-specific and not worth auditing field-by-field at this level. Debug via `session.flow` direct access or `IO.inspect(session, structs: false)`.

**Drop-in implementation:**

```elixir
defimpl Inspect, for: LatticeStripe.BillingPortal.Session do
  import Inspect.Algebra

  def inspect(session, opts) do
    # Allowlist structural + routing fields only. Hide:
    #
    #   :url  — short-lived (~5 min), single-use authenticated redirect
    #           that impersonates the customer for the portal session.
    #           Leaks via Logger, APM, crash dumps, or telemetry handlers
    #           are an account-takeover vector within the TTL window.
    #           This is the asset Phase 21 SC #4 protects.
    #
    #   :flow — nested %FlowData{} sub-object. Hidden to keep Inspect
    #           output a structural one-liner (matches Customer /
    #           MeterEvent / Checkout.Session shape) and to avoid
    #           surfacing flow-specific redirect/confirmation data
    #           field-by-field. Access directly via `session.flow`
    #           when debugging flow_data deep links.
    #
    # Debugging escape hatch — see every field including :url and :flow:
    #
    #     IO.inspect(session, structs: false)
    #     # or
    #     session.url
    #     session.flow
    #
    # Precedent: Customer (lib/lattice_stripe/customer.ex),
    # MeterEvent (lib/lattice_stripe/billing/meter_event.ex),
    # Checkout.Session (lib/lattice_stripe/checkout/session.ex) —
    # all three allowlist structural fields and hide the sensitive
    # surface. Checkout.Session already hides its own :url, establishing
    # the "Stripe session URLs are uniformly masked" SDK invariant.
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

**Test coverage (2 tests in `test/lattice_stripe/billing_portal/session_test.exs`):**
1. Assert `inspect(session) =~ "#LatticeStripe.BillingPortal.Session<"` and shows `id:` / `object:` / `livemode:` visibly.
2. Assert `refute inspect(session) =~ session.url` (the actual URL string must not appear anywhere in Inspect output) AND `refute inspect(session) =~ "FlowData"` (flow struct must not leak).

**Rationale:** Structurally, Portal.Session resembles Checkout.Session far more than Customer or MeterEvent — both are short-lived Stripe-hosted session objects wrapping a sensitive redirect URL and carrying routing IDs (`customer`/`configuration`/`on_behalf_of` vs. `customer`/`mode`/`status`). Customer and MeterEvent are long-lived domain resources where PII/payload is the sensitive surface; for a portal session the sensitive surface is exactly one field — `:url` — and the pragmatic posture is to match Checkout.Session's shape (visible structural IDs, hidden session token). Portal.Session has no `mode`/`status` lifecycle, so its structural fields are the routing IDs (`customer`/`configuration`/`on_behalf_of`) instead. Crucially, Checkout.Session's impl already hides its own `:url` without fanfare — so the "Stripe session URLs are uniformly masked in LatticeStripe" invariant is already load-bearing; Phase 21 is making it explicit and documented for the higher-sensitivity portal variant. Threat model: Logger → APM, crash dumps → Sentry/Honeybadger, telemetry handlers persisting events to S3, pair-programming screen shares — all scenarios where the 5-minute TTL is long enough for an attacker watching the pipe to hijack the portal session. Masking `:url` in `inspect/2` closes the accidental-leak path while `IO.inspect(x, structs: false)` preserves intentional debugging. Aligns with Phoenix.Token / Guardian token-masking philosophy (auth tokens never render by default), explicitly rejects the Plug.Conn "render everything, trust the developer" end which Customer/MeterEvent/Checkout.Session have collectively already rejected three times. Forward compat into v1.2 `BillingPortal.Configuration`: Configuration is a pure config object with no credentials, lands on its own verbose-but-safe allowlist, and the Session impl needs zero revisiting when Configuration ships (`configuration: "bpc_..."` already points users to it in the Inspect output).

**Rejected:**
- Option A (minimal Customer-style allowlist: `id`, `object`, `livemode` only) — rejected: blinds debugging on the `customer`/`configuration`/`on_behalf_of` routing IDs that are the entire point of a session object; forces `IO.inspect(s, structs: false)` for routine work.
- Option C (verbose allowlist showing everything except `url` and `flow`) — rejected: no precedent in the SDK, closest to Plug.Conn "render everything" which is the explicit SDK counter-example; requires vigilance on every future API field Stripe adds; widens attack surface on `customer_email`-style additions.

---

### D-04 — Guide envelope for `guides/customer-portal.md`

**Envelope:** MODERATE — **240 lines ± 40, 7 H2 sections**.

**Plan slot:** **Bundle into the resource-landing plan (currently sketched as 21-03 in the v1.1 brief)** per the brief's own note *"Short plan, maybe bundled with 21-03"*. A MODERATE guide at this size is ~half a day of editorial work on top of the resource implementation and does not warrant a dedicated 21-04 slot. If Phase 21's gsd-plan-phase discovers 21-03 is already heavy, the guide can split out into its own plan at that point — start bundled.

**ExDoc registration:**
- Add `"guides/customer-portal.md"` to `mix.exs` `extras` list (alphabetically near `connect-money-movement.md`).
- `groups_for_extras` picks it up via the existing `guides/*.{md,cheatmd}` wildcard — no change needed there.
- Add `"Customer Portal"` group to `mix.exs` `groups_for_modules` per DOCS-03 (already locked in REQUIREMENTS.md). Modules in that group: `LatticeStripe.BillingPortal.Session`, `LatticeStripe.BillingPortal.Session.FlowData`, and the 4 FlowData sub-modules (`AfterCompletion`, `SubscriptionCancel`, `SubscriptionUpdate`, `SubscriptionUpdateConfirm`). `LatticeStripe.BillingPortal.Guards` has `@moduledoc false` — not in any group.

**Exact H2 outline (binding for the doc-writer task):**

1. **What the Customer Portal is** (~15 lines) — intro paragraph, 4 flow-type bullet summary, one-sentence framing of the single-call flow.
2. **Quickstart** (~25 lines) — minimal `Session.create/3` call with `customer` + `return_url`, redirect the url, one paragraph on what Stripe shows by default (no `flow_data` = portal homepage).
3. **Deep-link flows** — introduction paragraph linking to `LatticeStripe.BillingPortal.Session.FlowData` moduledoc for the full schema, followed by four H3 subsections:
   - `### Updating a payment method` (~15 lines) — `flow_data.type = "payment_method_update"`, when to use, minimal example.
   - `### Canceling a subscription` (~20 lines) — `flow_data.type = "subscription_cancel"` + required `subscription_cancel.subscription`, example with retention coupon_offer. One-sentence cross-link: *"For the server-side `Subscription.cancel/3` equivalent and its semantics, see [Subscriptions — Lifecycle operations](subscriptions.md)."*
   - `### Updating a subscription` (~20 lines) — `flow_data.type = "subscription_update"` + required `subscription_update.subscription`. Cross-link to `subscriptions.md` §Proration.
   - `### Confirming a subscription update` (~20 lines) — `flow_data.type = "subscription_update_confirm"` with `items` + `discounts`; when you'd use this (pre-computed upgrade preview handed off to Stripe for confirmation).
4. **End-to-end Phoenix example** (~50 lines) — an `Accrue`-style 5-line wrapper module showing `def portal_url(user, return_to)` returning `{:ok, url}`, then a `BillingController.portal/2` that calls the wrapper and does `redirect(conn, external: session.url)`, plus the return handler re-rendering the account page. Satisfies DOCS-02's *"Accrue-style usage example"* literally.
5. **Security and session lifetime** (~35 lines) — owns the D-03 teaching:
   - `session.url` is single-use and expires (~5 minutes per Stripe documentation)
   - Never log or persist the url — it is a bearer credential
   - LatticeStripe masks the `:url` field in `Inspect` output by default; show an example of `IO.inspect(session)` output demonstrating `url` is absent; document the `IO.inspect(session, structs: false)` escape hatch
   - `return_url` should be an HTTPS route you control
   - On customer return, re-verify the session server-side; the portal redirect is NOT authentication — use webhooks for state-change confirmation.
6. **Common pitfalls** (~25 lines) — checkout.md-style bold-lede bullets surfacing the D-01 guard's error messages:
   - **customer is required** — pre-network `ArgumentError`, fixable by passing `"customer" => "cus_..."`.
   - **return_url must be absolute HTTPS** — Stripe rejects relative or http URLs.
   - **flow_data.type must match its sub-field key** — e.g. `type: "subscription_cancel"` requires `subscription_cancel.subscription`, not top-level `subscription`.
   - **Don't cache `session.url`** — single-use and short-lived.
   - **Portal changes fire webhooks, not a return-URL payload** — use `customer.subscription.updated` / `.deleted` to confirm state changes.
7. **See also** — cross-links:
   - `[Subscriptions](subscriptions.md)` — server-side cancel/update semantics and proration
   - `[Webhooks](webhooks.md)` — `customer.subscription.updated` / `.deleted` confirmation
   - `[Checkout](checkout.md)` — the create-side twin for new customers
   - `` `LatticeStripe.BillingPortal.Session` `` — module reference and FlowData schema

**Reciprocal cross-links to add elsewhere:**
- `guides/subscriptions.md` §Lifecycle operations — add a "See also" bullet pointing to `guides/customer-portal.md` §Canceling a subscription.
- `guides/subscriptions.md` §Proration — add a "See also" bullet pointing to §Updating a subscription.
- `guides/webhooks.md` — add a pointer to `guides/customer-portal.md` §Security and session lifetime explaining that portal flows dispatch via webhooks, not return-URL payloads.
- `guides/checkout.md` — optional reciprocal "See also" pointing to Customer Portal for existing-customer flows.

**Rationale:** `guides/checkout.md` is the structural twin — 274 lines, 11 H2s for a single-resource create-centric API whose branching axis is a string discriminator (`mode` × 3 values). Portal is the same shape with a wider-but-shallower discriminator (`flow_data.type` × 4 values) and fewer surrounding operations (no `expire`/`list_line_items`/`list`). That argues for *slightly less* than checkout.md — 240 lines, 7 H2s. Metering.md's 620 lines are earned by 3 resources, a hot path, 2-layer idempotency, a GUARD-01 trap, and a webhook error-report reconciliation flow — none of which BillingPortal.Session has, so copying that envelope would produce padding that duplicates either the FlowData moduledoc (reference, not narrative) or `subscriptions.md` §Lifecycle operations (which already owns cancel/update semantics). The LatticeStripe convention — consistent with Phoenix/Ecto — is that the **moduledoc is the field reference** and the **guide is the narrative**: the guide should *link* to `LatticeStripe.BillingPortal.Session.FlowData` for the field schema and only show the 2-3 fields each flow actually needs in context. The Security section must be its own H2 (not a paragraph) because D-03 `:url` Inspect-masking is a behavior users cannot discover from the moduledoc alone — promoting it to H2 makes the guide the teaching surface, matching how `client-configuration.md` promotes per-request overrides to a full H2. On Phoenix-vs-Plug-vs-library: checkout.md shows a Phoenix controller without apology, and this guide should too — Phoenix is the overwhelming majority host, and "Accrue-style" per DOCS-02 means "a thin wrapper that returns `{:ok, url}` to a caller", which shows as a 5-line module *above* the Phoenix controller example. Idiomatically matches Swoosh adapter guides, Oban plugin guides, Phoenix `Phoenix.Controller`-adjacent guides — all in the 200-300 line band with a Quickstart → Feature branches → Integration example → Pitfalls → See also cadence.

**Rejected:**
- TIGHT envelope (~150 lines, 6 H2, no Phoenix example) — rejected: no Phoenix controller forces users to assemble one from moduledoc fragments; fails DOCS-02's "Accrue-style usage example" requirement.
- METERING-MATCH envelope (~500 lines, 11 H2) — rejected: padding city; BillingPortal.Session has one function, no hot path, no idempotency, no GUARD trap, no webhook error report; most sections would duplicate moduledoc (FlowData schema), subscriptions.md (cancel/update), or client-configuration.md (Connect via `stripe_account:` opt); violates the Phoenix/Ecto "narrative not reference" guide/moduledoc split; editorial cost to keep accurate over time is high for near-zero additional user value.

### Claude's Discretion

Two gray areas deliberately left as Claude's discretion since they are trivial:

- **D. Plan breakdown (3 vs 4 plans)** — gsd-plan-phase will decide based on the resource-plan weight after research. Start from the v1.1 brief's 4-plan sketch (Wave 0 bootstrap / FlowData nested structs / resource module + guard / integration tests + guide) and collapse or expand as the plan surface area warrants. D-04 commits to bundling the guide with the resource plan (21-03 in the v1.1 brief numbering) as a default; split only if the resource plan is already heavy.
- **F. `configuration` param type handling** — accept `binary()` (Stripe `bpc_*` configuration ID) as the documented type on `Session.create/3`'s `params["configuration"]` field; do NOT write a pre-flight guard for it (Stripe's 400 is clear enough if the host passes a map). Document in the moduledoc that portal configuration is managed via the Stripe dashboard in v1.1 (locked v1.1 D4).

### Folded Todos

No todos matched Phase 21 scope in the cross-reference step (`gsd-tools todo match-phase 21` returned zero matches).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### v1.1 Milestone Context
- `.planning/v1.1-accrue-context.md` — authoritative v1.1 brief with locked decisions D1-D5, Accrue unblocker framing, zero-touch release flow rationale, and Phase 21 plan sketch (4 plans).

### Roadmap and Requirements
- `.planning/ROADMAP.md` §"Phase 21: Customer Portal" (lines 66-76) — goal, dependencies, success criteria.
- `.planning/REQUIREMENTS.md` PORTAL-01..06 (lines 35-40), TEST-02 (line 51), TEST-04 (line 53), TEST-05 portal portion (line 54), DOCS-02 (line 59), DOCS-03 Customer Portal group (line 61), PORTAL-FUTURE-01 (line 74), mapping rows (lines 116-134).

### Locked Prior Phase Decisions
- `.planning/phases/20-billing-metering/20-CONTEXT.md` §D-01 — Guards-module-alongside-resource-namespace pattern; `cond` vs pattern-match clause idioms; string-key reads only rationale; NimbleOptions rejection reaffirmed.
- `.planning/phases/20-billing-metering/20-CONTEXT.md` §D-02 — allowlist Inspect masking template; MeterEvent allowlist; **forward commitment that Phase 21 applies the same pattern to `BillingPortal.Session.url`** (satisfied by D-03 above).
- `.planning/phases/20-billing-metering/20-CONTEXT.md` §D-03 — nested sub-struct idiom for Meter.* sub-modules; `@known_fields` + `from_map/1` + `:extra` template.
- `.planning/phases/20-billing-metering/20-CONTEXT.md` §D-04 — MeterEventAdjustment.Cancel sub-module precedent (parent resource with one nested sub-struct).
- `.planning/phases/20-billing-metering/20-CONTEXT.md` §D-06 — string-keyed wire format only; no atom→string param normalization.
- Phase 19 D-16 (referenced in Phase 20 D-01) — NimbleOptions rejected for nested string-keyed map validation.
- Phase 17 D-04c — function-head atom guards fit positional closed enums only, not nested-in-map string-valued keys (cited in D-01 rejection of inline function-head validation).
- Phase 17 D-01 — "every decoded Stripe resource hides its sensitive surface by default" (cited in D-03 rationale).

### Stripe API Reference
- [Stripe Customer Portal Sessions API](https://docs.stripe.com/api/customer_portal/sessions) — full object reference, `flow_data` schema, required sub-fields per flow type.
- [Stripe Customer Portal overview](https://docs.stripe.com/customer-management) — conceptual docs cited in guide §"What the Customer Portal is".

### In-Repo Reference Files
- `lib/lattice_stripe/checkout/session.ex` — structural twin. Note `@known_fields` list, `defstruct` block, `from_map/1` recursion, and `defimpl Inspect` at lines 658-684 (which already hides `:url`, establishing the SDK invariant D-03 extends).
- `lib/lattice_stripe/billing/guards.ex` — canonical Guards module template. `check_meter_value_settings!/1` (GUARD-01, `cond` style) and `check_adjustment_cancel_shape!/1` (GUARD-03, pattern-match style — D-01's direct template).
- `lib/lattice_stripe/billing/meter.ex` — `Guards.check_*!/1` call site template for where to invoke the guard in `create/3`.
- `lib/lattice_stripe/billing/meter_event.ex` — `defimpl Inspect` lines ~103+, allowlist template with rationale comments.
- `lib/lattice_stripe/billing/meter_event_adjustment.ex` + `lib/lattice_stripe/billing/meter_event_adjustment/cancel.ex` — parent resource + single nested sub-struct (the closest D-02 shape analog).
- `lib/lattice_stripe/billing/meter/default_aggregation.ex`, `customer_mapping.ex`, `value_settings.ex`, `status_transitions.ex` — 4 nested sub-struct templates to copy for FlowData sub-modules.
- `lib/lattice_stripe/customer.ex` lines 467-489 — older `defimpl Inspect` allowlist template.
- `lib/lattice_stripe/resource.ex` — `require_param!/3` primitive for top-level required-field raises (used for `customer` required check in `Session.create/3`).
- `lib/lattice_stripe/subscription.ex` — `pause_collection/5` (cited in PORTAL-04 as the philosophical parallel for validating a closed enum pre-network).

### Guide Reference Files
- `guides/checkout.md` — structural twin (274 lines, 11 H2s); D-04's direct template, slightly trimmed.
- `guides/metering.md` — depth-extreme reference (~620 lines); D-04 explicitly argues against matching this envelope.
- `guides/subscriptions.md` — §"Lifecycle operations" and §"Proration" are the mandatory cross-link targets from D-04's deep-link flow subsections.
- `guides/webhooks.md` — cross-link target for the Security and Common Pitfalls sections.
- `mix.exs` — `extras:` and `groups_for_modules:` are the registration surfaces for D-04.

### External Library Comparisons (reviewed during research)
- [stripity_stripe Stripe.BillingPortal.Session docs](https://hexdocs.pm/stripity_stripe/Stripe.BillingPortal.Session.html) — zero client-side flow validation; flat raw map sub-objects. Cited in D-01 and D-02 rationale as the explicit gap LatticeStripe fills.
- [stripe-go billingportal_session.go](https://github.com/stripe/stripe-go/blob/master/billingportal_session.go) — OpenAPI-generated thin wrapper; same no-pre-flight-validation gap.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`LatticeStripe.Checkout.Session`** (`lib/lattice_stripe/checkout/session.ex`) — direct structural analog. Copy its `@known_fields` / `defstruct` / `from_map/1` / `defimpl Inspect` shape for `BillingPortal.Session`. Note: already hides `:url` in its Inspect impl.
- **`LatticeStripe.Billing.Guards`** (`lib/lattice_stripe/billing/guards.ex`) — precedent for a `Guards` module holding `check_*!/1` validators. `check_adjustment_cancel_shape!/1` (GUARD-03) is the direct template for D-01's pattern-match clause style.
- **`LatticeStripe.Resource.require_param!/3`** — existing primitive for top-level required-param raises. `Session.create/3` uses this for `customer` as a one-liner before calling `BillingPortal.Guards.check_flow_data!/1`.
- **Phase 20 Meter sub-struct modules** (`lib/lattice_stripe/billing/meter/*.ex`) — 4 nested sub-struct templates to copy for the 4 `FlowData.*` sub-modules. Each has `@known_fields` + `defstruct` + `@type t` + `from_map/1` + `:extra`.
- **`LatticeStripe.Billing.MeterEventAdjustment`** + its `Cancel` sub-module — parent resource + single nested sub-struct pattern; closest shape analog to `Session` + `FlowData` tree.
- **`LatticeStripe.Customer` Inspect impl** (`customer.ex:467-489`) — older allowlist Inspect template; per-field rationale commenting style is D-03's model.
- **`LatticeStripe.Billing.MeterEvent` Inspect impl** (`meter_event.ex:~103+`) — v1.1-established allowlist template with explicit sensitivity-rationale comments.
- **`test/support/fixtures/metering.ex`** — shape template for the new `test/support/fixtures/billing_portal.ex` (TEST-02). Follows the `def session(overrides \\ %{})` + `Map.merge/2` idiom.
- **`guides/checkout.md`** — tonal/structural template for `guides/customer-portal.md` (D-04).

### Established Patterns
- **Pre-flight guards in a `*.Guards` module alongside resource namespace** (Phase 20 D-01): `BillingPortal.Guards` lives at `lib/lattice_stripe/billing_portal/guards.ex`, not extending `Billing.Guards`. The `billing` / `billing_portal` namespace split is intentional — they are unrelated Stripe surfaces that share the word "billing".
- **String-keyed wire format only** (Phase 20 D-06): `Session.create/3` params come in string-keyed (`%{"customer" => ..., "flow_data" => %{"type" => ...}}`) and leave string-keyed. Atom-keyed params bypass the guard intentionally; the HTTP layer surfaces Stripe's 400 for them.
- **Nested sub-struct decode idiom** (Phase 17 / Phase 20): `defstruct` + `@known_fields` + `from_map(nil) :: nil` + `from_map(map) when is_map(map)` + `:extra` (Map.drop of unknown keys) + `@type t :: %__MODULE__{...}`.
- **Allowlist `defimpl Inspect`** (Phase 17 D-01, reinforced Phase 20 D-02): `Inspect.Algebra` with hardcoded visible-field list; per-field rationale comment block at top; `IO.inspect(x, structs: false)` escape hatch documented.
- **Resource modules follow `Resource.request/6` call shape** — `create/3` builds params, runs guards, hands off to `LatticeStripe.Resource.request(client, :post, "/v1/billing_portal/sessions", params, opts, __MODULE__)`.
- **Integration tests tagged `:integration`** — skipped by default, run against `stripe-mock` in CI. See Phase 20 Plan 20-05 and `config/test.exs` for the test mode gate.

### Integration Points
- **`mix.exs`** — `extras:` list (add `guides/customer-portal.md`), `groups_for_modules:` list (add `"Customer Portal"` group with 6 modules: Session, FlowData, AfterCompletion, SubscriptionCancel, SubscriptionUpdate, SubscriptionUpdateConfirm). Note: `BillingPortal.Guards` has `@moduledoc false` and is not in any group.
- **`lib/lattice_stripe.ex`** moduledoc resource index — add `BillingPortal.Session` to the module listing per DOCS-04.
- **`test/support/fixtures/billing_portal.ex`** — new file, canonical `Session` + `FlowData` fixtures per flow type (TEST-02).
- **`test/lattice_stripe/billing_portal/session_test.exs`** — unit tests (guard matrix, Inspect masking, from_map decoding).
- **`test/integration/billing_portal_session_integration_test.exs`** — `:integration`-tagged stripe-mock test (TEST-05 portal portion).
- **`guides/subscriptions.md` + `guides/webhooks.md`** — reciprocal "See also" cross-links into `guides/customer-portal.md` per D-04.

</code_context>

<specifics>
## Specific Ideas

- **`@fn_name` module attribute in `BillingPortal.Guards`** — used in every error message to ensure the function identifier stays in sync if the resource moves. Matches the rationale comment style in Phase 20 D-01's sketch.
- **Binary catchall via `when is_binary(type)`** (D-01) — the structural guarantee that "unknown flow_data.type silently forwarded to Stripe" is impossible. Use this exact clause shape; do not substitute a plain catchall without the binary guard.
- **`items` non-empty check** (D-01 clause 8) — `is_list(i) and i != []` rather than `is_list(i) and length(i) > 0`; avoids unnecessary list traversal.
- **`@moduledoc false` on `BillingPortal.Guards`** (D-01) — private to the resource; not a public API surface; not in any `groups_for_modules` group. Matches `Billing.Guards` precedent.
- **5-module FlowData footprint** (D-02) — exactly matches Meter's 4-sub-struct + parent footprint. Deliberate symmetry; do not add a 6th sub-module for `AfterCompletion.Redirect` or `SubscriptionCancel.Retention`.
- **Inspect output shape** (D-03) — `#LatticeStripe.BillingPortal.Session<...>` angle-bracket delimiters, comma-space separator, exact field order `id, object, livemode, customer, configuration, on_behalf_of, created, return_url, locale`. No trailing comma.
- **Inspect masking test** (D-03) — use `refute inspect(session) =~ session.url` (the actual URL string) rather than `refute inspect(session) =~ "url:"`; the stronger assertion catches accidental partial leaks.
- **Guide §Security example** (D-04) — show a literal `IO.inspect(session)` output line in the guide so users see with their own eyes that `url` is absent. This is the teaching mechanism for the masking behavior.
- **Accrue wrapper example** (D-04 §4) — 5-line module, not a full GenServer. Signature: `def portal_url(user, return_to) :: {:ok, String.t()} | {:error, Error.t()}`. Thin wrapper that calls `BillingPortal.Session.create/3` and extracts `.url`.
- **Reciprocal cross-links added in THIS phase**, not deferred — both directions of every link in `guides/subscriptions.md`, `guides/webhooks.md`, and `guides/checkout.md` (optional) should land in Plan 21-0X guide work.

</specifics>

<deferred>
## Deferred Ideas

- **`BillingPortal.Configuration` CRUDL** — locked v1.1 D4; defer to v1.2+. Hosts manage portal config via Stripe dashboard for v1.1. When it ships, v1.2 adds its own `defimpl Inspect` following the D-03 allowlist pattern and adds modules to the existing "Customer Portal" ExDoc group.
- **`BillingPortal.Session.FlowData.Retention` sub-module** — `retention` stays a raw map in v1.1 (D-02). If Stripe extends retention beyond the current `type` + `coupon_offer.coupon` shape, v1.2+ promotes it to a 6th sub-module.
- **`BillingPortal.Session.FlowData.AfterCompletion.Redirect` / `.HostedConfirmation` sub-modules** — stay raw maps in v1.1 (D-02). Single-field terminal objects; promote in v1.2+ if the shapes grow.
- **Typed sub-modules for `SubscriptionUpdateConfirm.items[]` / `.discounts[]`** — stay `[map()]` in v1.1. User-submitted collections mirror the existing Subscription.items / Discount raw-map treatment; promote only if a concrete DX need arises.
- **Encoding FlowData back to the wire** — v1.1 is decode-only. `Session.create/3` accepts raw string-keyed maps for `flow_data`; there is no `FlowData.to_params/1` or `%FlowData{}`-accepting `create/3` variant. If Accrue later wants to compose FlowData programmatically, v1.2+ can add an encode path behind a deliberate protocol (`FormEncoder` or similar).
- **Telemetry / observability section in `guides/customer-portal.md`** — deferred from D-04's envelope; portal sessions have no hot path that warrants custom telemetry guidance beyond the existing `guides/telemetry.md`.
- **FAQ section in the guide** — deferred; D-04's "Common pitfalls" subsumes the questions that would go there.
- **Connect platform deep-dive section** — `on_behalf_of` is surfaced in the Inspect allowlist and documented in the moduledoc, but not given its own H2; hosts using Connect follow `guides/connect-accounts.md` for platform configuration.

### Reviewed Todos (not folded)

No todos were surfaced by `gsd-tools todo match-phase 21`.

</deferred>

---

*Phase: 21-customer-portal*
*Context gathered: 2026-04-14*
*Commit anchor: 51149ed*
