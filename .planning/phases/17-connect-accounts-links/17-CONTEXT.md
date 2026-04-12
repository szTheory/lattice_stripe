# Phase 17: Connect Accounts & Account Links - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning
**Milestone:** v2.0-connect (first phase of Connect track; follows completed Billing track)

<domain>
## Phase Boundary

Developers can onboard Stripe Connect connected accounts end-to-end — manage the full account lifecycle via `LatticeStripe.Account`, generate Stripe-hosted onboarding URLs via `LatticeStripe.AccountLink`, and generate single-use Express dashboard return URLs via `LatticeStripe.LoginLink`. Includes a coherent typed-struct model for the Account resource's nested fields, a novel typed-inner/open-outer shape for the `capabilities` map, and full continuation of Phase 14/15/16 conventions.

**Requirement:** **CNCT-01** (Account lifecycle, retrieve, update, onboarding).

**In scope:**
- `LatticeStripe.Account` resource module — `create/3`, `retrieve/3`, `update/4`, `delete/3`, `list/3`, `stream!/3` + bang variants
- `Account.reject/4` action verb with atom-guarded reason
- 6 nested typed struct modules under `LatticeStripe.Account.*` (see D-01)
- 1 typed inner struct for `capabilities` map values (see D-02) — separate from D-01 budget
- `LatticeStripe.AccountLink` resource module — `create/3` + bang variant only (single-use, no retrieve/update/delete)
- `LatticeStripe.LoginLink` resource module — `create/3` + bang variant only (single-use Express dashboard return URL)
- stripe-mock integration tests covering account lifecycle, reject, account-link creation, login-link creation
- `guides/connect.md` with onboarding narrative (account → account link → KYC → login link)
- ExDoc "Connect" module group wired in `mix.exs` docs config
- Webhook-handoff callout ("drive application state from webhook events, not SDK responses") — Phase 15 precedent

**Out of scope (deferred to Phase 18):**
- `LatticeStripe.ExternalAccount` (full polymorphic CRUD for bank accounts + cards on connected accounts) — belongs with payouts
- `LatticeStripe.Transfer` / `TransferReversal`
- `LatticeStripe.Payout`
- `LatticeStripe.Balance` / `BalanceTransaction`
- Destination charges, separate charge/transfer patterns, `application_fee_amount` threading
- Requirements: CNCT-02, CNCT-03, CNCT-04, CNCT-05

**Out of scope (other):**
- `Account.Persons` sub-resource (create/retrieve/update/delete individual persons beyond the representative) — `Individual` struct covers the common case; defer until user demand surfaces
- `Account.request_capability/4` convenience helper — rejected as "fake ergonomics" (see D-04)
- `AccountLink.create/3` positional `type` arg — rejected to preserve SDK-wide `create(client, params, opts)` shape (see D-04)
- Client-side validation of `business_type` vs `company`/`individual` mutual exclusion — let Stripe 400 flow through `%LatticeStripe.Error{}` (Phase 15 D5 "no fake ergonomics")
- Standard/Express vs Custom account-type convenience constructors — `type` in params is sufficient

</domain>

<decisions>
## Implementation Decisions (Locked — D-01..D-04)

### D-01 — Nested typed struct budget on `%Account{}` (budget amended)

**Amend Phase 16 D1 rule:** the 5-field budget now counts **distinct nested struct modules**, not promoted parent fields. This ratifies what Phase 16 already did when reusing `SubscriptionSchedule.Phase` across `phases[]` and `default_settings`. CONTEXT and moduledoc for `Account` must call out the reframing.

**Promoted fields on `%Account{}` — 6 fields, 6 struct modules:**

| # | Field(s) on `%Account{}` | Module | Notes |
|---|---|---|---|
| 1 | `business_profile` | `LatticeStripe.Account.BusinessProfile` | High pattern-match frequency — name, url, mcc, support_email, support_phone, product_description |
| 2 | `requirements` **+** `future_requirements` | `LatticeStripe.Account.Requirements` | **Single struct reused at both sites** per Stripe docs (identical shape: currently_due, eventually_due, past_due, pending_verification, disabled_reason, current_deadline, errors, alternatives). Moduledoc documents both use sites. |
| 3 | `tos_acceptance` | `LatticeStripe.Account.TosAcceptance` | Fixed 4-field shape (date, ip, service_agreement, user_agent). **PII-safe Inspect** — holds `ip` and `user_agent`. |
| 4 | `company` | `LatticeStripe.Account.Company` | Active when `business_type = "company"`. **PII-safe Inspect** — holds tax_id, phone, address. |
| 5 | `individual` | `LatticeStripe.Account.Individual` | Active when `business_type = "individual"` (mutually exclusive with `company`). **PII-safe Inspect** — holds `dob`, `ssn_last_4`, `first_name`, `last_name`, `address`. |
| 6 | `settings` | `LatticeStripe.Account.Settings` | **Outer-only** — sub-objects (`branding`, `card_payments`, `dashboard`, `payments`, `payouts`) stay as plain maps absorbed by `:extra`. Moduledoc must explicitly call out the depth cap so future maintainers don't see it as inconsistency. |

**All 6 modules follow F-001:** `@known_fields` attribute + `:extra` map in defstruct + `Map.split` in `cast/1` to partition known vs extra.

**No `Jason.Encoder`** on any struct (established convention).

**Rejected:**
- Unified `Account.Party` struct collapsing `company` + `individual` — loses mutual-exclusion pattern-matching that's load-bearing in real Connect code. Divergent fields (dob/ssn_last_4 vs structure/directors_provided/owners_provided) are identity, not incidental.
- Cascading `Settings` sub-objects into their own structs — would add 5+ more modules, blow the budget, and yield no real ergonomic win because `:extra` already handles forward-compat for key-access patterns.
- Dropping `tos_acceptance` or `settings` in favor of a 5-field hard cap — `tos_acceptance` is a trivially stable 4-field shape that's free to type; `settings.payouts.schedule` is read in real onboarding flows.

### D-02 — `capabilities` shape: typed inner, open outer map

**`Account.capabilities` stays a plain `map(String.t(), LatticeStripe.Account.Capability.t())` on `%Account{}`.** This does **not** consume a slot in D-01's budget because it's an open-keyed forwarding map, not a promoted field with a fixed shape.

**New module: `LatticeStripe.Account.Capability`**

```elixir
defmodule LatticeStripe.Account.Capability do
  @moduledoc """
  A single capability entry from `Account.capabilities`.

  The outer `capabilities` map on `%Account{}` is keyed by Stripe's
  open-ended capability name strings (e.g. `"card_payments"`,
  `"transfers"`, `"us_bank_account_payments"`). Each value is a
  `%Capability{}`. The inner shape is stable; new capability *names*
  added by Stripe flow through automatically as new map keys.

      iex> account.capabilities["card_payments"]
      %LatticeStripe.Account.Capability{status: "active", requested: true, ...}

      iex> LatticeStripe.Account.Capability.status_atom(
      ...>   account.capabilities["card_payments"]
      ...> )
      :active
  """

  @known_fields ~w(status requested requested_at requirements disabled_reason)a

  defstruct @known_fields ++ [extra: %{}]

  @type t :: %__MODULE__{
          status: String.t() | nil,
          requested: boolean() | nil,
          requested_at: integer() | nil,
          requirements: map() | nil,
          disabled_reason: String.t() | nil,
          extra: map()
        }

  @doc false
  def cast(nil), do: nil
  def cast(map) when is_map(map) do
    known_string_keys = Enum.map(@known_fields, &Atom.to_string/1)
    {known, extra} = Map.split(map, known_string_keys)

    struct(__MODULE__,
      status: known["status"],
      requested: known["requested"],
      requested_at: known["requested_at"],
      requirements: known["requirements"],
      disabled_reason: known["disabled_reason"],
      extra: extra
    )
  end

  @known_statuses ~w(active inactive pending unrequested disabled)

  @doc """
  Returns `status` as an atom from a known set, or `:unknown` for
  forward compatibility. Never calls `String.to_atom/1` on user input.
  """
  @spec status_atom(t() | String.t() | nil) :: atom()
  def status_atom(%__MODULE__{status: s}), do: status_atom(s)
  def status_atom(nil), do: nil
  def status_atom(s) when s in @known_statuses, do: String.to_existing_atom(s)
  def status_atom(_), do: :unknown
end
```

**In `LatticeStripe.Account`, cast the capabilities field at `from_map/1` time:**

```elixir
defp cast_capabilities(nil), do: nil
defp cast_capabilities(caps) when is_map(caps) do
  Map.new(caps, fn {name, obj} -> {name, LatticeStripe.Account.Capability.cast(obj)} end)
end
```

**Why this specific shape:**
- Inner shape is stable (same 5 fields for years) → typed inner wins
- Outer keys are open (Stripe ships 3-5 new capability names/year) → plain map outer wins
- `status` as atom is ergonomic but `String.to_atom/1` on Stripe input is a footgun → opt-in `status_atom/1` helper with `:unknown` fallback gives the ergonomic win safely
- This is **not** "fake ergonomics" — we're not wrapping a Stripe param, we're giving a stable inner object the standard struct treatment

**Rejected:**
- Plain map-of-maps (stripity_stripe's `term` approach) — leaves ergonomic value on the floor given the stable inner shape
- Atom-keyed mega-struct with one field per capability (stripe-go/java/rust approach) — those are OpenAPI-generated and re-ship every release, so staleness is free; LatticeStripe is hand-maintained so the cost curve inverts
- Naive atom-cast of `status` field at decode time — `String.to_atom/1` on unknown Stripe values leaks atoms

### D-03 — Phase 17/18 scope boundary

**Phase 17 = `Account` + `AccountLink` + `LoginLink`.**
**Phase 18 = `ExternalAccount` (full CRUD) + Transfers + Payouts + Balance + BalanceTransactions + destination charges + platform fees.**

**External Accounts → Phase 18.** Every cross-SDK data point agrees: stripity_stripe has top-level `Stripe.ExternalAccount`, stripe-node/python/go/java group External Accounts under the Connect payouts namespace, and Stripe's own API reference places them next to Payouts not under Account onboarding. When a LatticeStripe user greps `external_account`, they're asking "how do I pay this account out" → Phase 18 question.

**Login Links → Phase 17 as standalone `LatticeStripe.LoginLink`** (not `Account.create_login_link/4`). Mirrors the `AccountLink` pattern exactly (single-use, POST-only, no retrieve/update/delete), matches stripity_stripe placement, and completes the Express onboarding narrative in one phase: create account → create account link → [user completes KYC] → create login link for return visits.

**Rejected:**
- External Accounts in Phase 17 — would bloat 17, orphan them from the payout consumers that need them, and break the Stripe API reference's own grouping.
- Login Links as a function on `Account` (`Account.create_login_link/4`) — would break the "one resource module per Stripe resource" convention that `AccountLink` already established.
- Login Links deferred entirely — Express devs need the dashboard return path; it's tiny (one POST, ~40 src LOC + ~60 test LOC).

**Guide narrative split:**
- `guides/connect.md` onboarding section (Phase 17): "create account → account link → user completes KYC → login link for return visits"
- `guides/connect.md` money-movement section (Phase 18): "attach external account → balance → transfer → payout"
- Phase 17's guide closes with a forward pointer: "External account attachment is covered in Phase 18 alongside payouts."

### D-04 — Atom guards and helpers

**Guiding principle (extension of Phase 15 D5):** Function-head atom guards earn their place when (1) the endpoint is a dedicated single-purpose verb, (2) the meaningful argument is a small closed enum, (3) the enum is stable enough that SDK churn won't strand users. Spelling-sugar helpers without a guard or validation are "fake ergonomics" and are omitted. Consistency with the SDK-wide `create(client, params, opts)` shape outranks marginal typo protection on multi-field creates.

#### D-04a — `Account.reject/4` — atom-guarded ✅

```elixir
@reject_reasons [:fraud, :terms_of_service, :other]

@doc """
Reject a connected account.

`reason` must be one of `:fraud`, `:terms_of_service`, or `:other`.
Dispatches to `POST /v1/accounts/:id/reject` with the atom converted
to its Stripe string form.
"""
@spec reject(
        LatticeStripe.Client.t(),
        String.t(),
        :fraud | :terms_of_service | :other,
        keyword()
      ) :: {:ok, t()} | {:error, LatticeStripe.Error.t()}
def reject(client, id, reason, opts \\ [])
    when reason in @reject_reasons do
  # dispatches to POST /v1/accounts/:id/reject with reason as string
end

def reject!(client, id, reason, opts \\ [])
    when reason in @reject_reasons do
  # bang variant
end
```

**Rationale:** Direct analog of Phase 15 D5 `pause_collection/5`. Dedicated endpoint, single semantic argument, 3-value enum unchanged since Stripe Connect launched (~2016). Atoms are compile-time literals in the guard — never `String.to_atom/1` on user input, so no atom-table DOS risk.

#### D-04b — `Account.request_capability/4` — omit ❌

**Rejected.** Textbook "fake ergonomics" (Phase 15 D5). It's a pure wrapper over `update/4` with no guard (capabilities are an open, growing ~30+ string set — any whitelist goes stale every quarter), no validation, no atom typing. Users use `Account.update/4` with the nested-map idiom:

```elixir
LatticeStripe.Account.update(client, "acct_123", %{
  capabilities: %{
    "card_payments" => %{requested: true},
    "transfers" => %{requested: true}
  }
})
```

**Action:** Document this idiom in `LatticeStripe.Account` moduledoc with a runnable example under a "Requesting capabilities" section.

#### D-04c — `AccountLink.create/3` — map-based, no positional `type` arg ❌

**Rejected** the atom-guarded 4-arity variant. Keep:

```elixir
@spec create(LatticeStripe.Client.t(), map(), keyword()) ::
        {:ok, t()} | {:error, LatticeStripe.Error.t()}
def create(client, params, opts \\ []) when is_map(params) do
  # POST /v1/account_links
end
```

**Rationale:** `AccountLink.create` is a multi-field create (`account`, `type`, `refresh_url`, `return_url`, `collect`, `collection_options`) — elevating `type` to a positional arg would break the SDK-wide `create(client, params, opts)` shape for marginal typo protection on a 2-value enum. The D5 pattern fits dedicated single-purpose verbs (`pause_collection`, `reject`), not multi-field creates.

**Future option (NOT in scope for Phase 17):** If real user demand surfaces post-ship, add thin wrappers `AccountLink.create_onboarding/3` and `AccountLink.create_update/3`. Track in deferred.md, do not implement now.

### Claude's Discretion

The following fall under Claude's judgment during planning/execution — not every micro-decision needs user approval:

- Exact field order in each nested struct (follow Stripe API doc order unless there's a reason to deviate)
- Exact `@moduledoc` wording, examples, and heading structure (follow Phase 14/15/16 moduledoc patterns)
- Test fixture shapes (follow `test/support/fixtures/` patterns from Phase 06)
- stripe-mock integration test coverage depth (mirror Phase 15/16 subscription/schedule coverage)
- Whether `Account.create/3` pre-validates `type` param (recommend NO per Phase 15 D5 "no fake ergonomics")
- ExDoc module group wiring details (add "Connect" group after "Billing")
- Whether `LoginLink` needs `@typedoc` for a 3-field struct (yes — follow Phase 10 D-03 "all key public structs get @typedoc")
- Inspect hiding specifics on Company/Individual/TosAcceptance — hide the exact PII fields per stripe-node's PII audit
- Whether to wire `Stripe-Account` header threading into any of these calls specifically — **no**, it's already handled at Client level (`lib/lattice_stripe/client.ex:178,390-427`), confirmed during scout. No code changes needed to Client for Phase 17.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents (researcher, planner, executor) MUST read these before planning or implementing.**

### Project-level decisions and state
- `.planning/PROJECT.md` — vision, principles, non-negotiables, technology stack
- `.planning/REQUIREMENTS.md` §"Connect" — CNCT-01 through CNCT-05 requirement definitions (currently under "v2 Requirements" — Phase 17 implements CNCT-01 only)
- `.planning/STATE.md` — current milestone position, accumulated decisions log
- `.planning/ROADMAP.md` Phase 17 entry — goal, depends-on, success criteria

### Prior phase contexts that establish patterns Phase 17 must follow
- `.planning/phases/14-invoices-invoice-line-items/14-CONTEXT.md` — D-06 nested struct cutoff heuristic (promote fields users pattern-match on; leave simple K-V as plain maps)
- `.planning/phases/14-invoices-invoice-line-items/14-CONTEXT.md` — `LatticeStripe.Billing.Guards` namespace pattern for cross-resource guards
- `.planning/phases/15-subscriptions-subscription-items/15-CONTEXT.md` — D4 flat namespace (`LatticeStripe.SubscriptionItem` not `Subscription.Item`), D4 reuse-over-duplicate (`Invoice.AutomaticTax` → `Subscription.automatic_tax`), D5 pause_collection atom-guard pattern, D5 "no fake ergonomics" principle (`pause/4` rejected), webhook-handoff callout requirement
- `.planning/phases/15-subscriptions-subscription-items/15-REVIEW-FIX.md` — F-001 `@known_fields` + `:extra` split pattern (added because unknown Stripe fields were being silently dropped)
- `.planning/phases/16-subscription-schedules/16-CONTEXT.md` — D1 5-field nested struct budget (amended in Phase 17 D-01 to count distinct modules, not parent fields), Phase ↔ default_settings struct reuse precedent

### Codebase files Phase 17 code must be coherent with
- `lib/lattice_stripe/client.ex:52-95` — Client struct definition, `stripe_account` field already present
- `lib/lattice_stripe/client.ex:176-196` — per-request `stripe_account` opts override (already wired — no changes needed)
- `lib/lattice_stripe/client.ex:388-427` — `build_headers/5` and `maybe_add_stripe_account/2` (already wired — no changes needed)
- `lib/lattice_stripe/resource.ex` — shared `unwrap_singular/2`, `unwrap_list/2`, `unwrap_bang!/1`, `require_param!/2` helpers — use these, do not reimplement
- `lib/lattice_stripe/customer.ex:36-55,462-467` — canonical example of `@known_fields`, `:extra`, and `defimpl Inspect` for PII hiding
- `lib/lattice_stripe/subscription_schedule.ex` + `lib/lattice_stripe/subscription_schedule/` directory — most recent precedent for a multi-nested-struct resource
- `lib/lattice_stripe/billing/guards.ex` — the `Billing.Guards` namespace pattern (Phase 17 doesn't add guards, but planner should know this namespace exists in case Connect grows a similar cross-resource guard layer)
- `test/support/fixtures/` — reusable fixture modules (Phase 06 established) — add `AccountFixtures`, `AccountLinkFixtures`, `LoginLinkFixtures`
- `test/integration/` — stripe-mock integration test setup; `test_integration_client/0` helper; follow Phase 15/16 integration test structure

### Stripe API references (web)
- https://docs.stripe.com/api/accounts — Account resource, all 7 operations, full field list
- https://docs.stripe.com/api/accounts/reject — reject endpoint, reason enum (`fraud`, `terms_of_service`, `other`)
- https://docs.stripe.com/api/account_links — AccountLink resource, create-only, `type` enum (`account_onboarding`, `account_update`)
- https://docs.stripe.com/api/account/login_link — LoginLink resource, create-only, Express-only
- https://docs.stripe.com/api/capabilities — Capability inner object shape, status enum values (`active`, `inactive`, `pending`, `unrequested`, `disabled`)
- https://docs.stripe.com/connect/account-capabilities — open growing set of capability identifiers

### Cross-SDK comparison references used during research
- https://github.com/beam-community/stripity-stripe — closest Elixir precedent; uses `term` for Account nested fields, standalone `Stripe.ExternalAccount` and `Stripe.LoginLink` modules
- https://github.com/stripe/stripe-node — TypeScript reference for typed shape coverage
- https://stripe.dev/stripe-java/com/stripe/model/Account.Capabilities.html — atom-keyed mega-struct approach (rejected for LatticeStripe because LS is hand-maintained)
- https://github.com/stripe/stripe-go — Go idioms for capability modeling

</canonical_refs>

<code_context>
## Existing Code Insights (from scout)

### Reusable Assets (use, don't duplicate)
- **`LatticeStripe.Resource`** (`lib/lattice_stripe/resource.ex`) — shared `unwrap_singular/2`, `unwrap_list/2`, `unwrap_bang!/1`, `require_param!/2`. All 7 `Account` operations, both `AccountLink` and `LoginLink` `create/3` functions, and `Account.reject/4` must use these helpers, not reimplement.
- **Client `stripe_account` header threading** (`client.ex:178,390-427`) — per-client AND per-request opts override already wired end-to-end. **Phase 17 requires zero changes to `Client` or `build_headers`.** Confirmed during scout. Document in `guides/connect.md` how to pass `stripe_account: "acct_..."` at client-creation time or per-request time.
- **`@known_fields` + `:extra` pattern** — canonical example in `lib/lattice_stripe/customer.ex:36-55,462-467`. Copy this pattern exactly into all 7 new struct modules.
- **`defimpl Inspect`** PII-hiding pattern — canonical example in `customer.ex:467+` and more completely in `checkout/session.ex`. Use for `Account.Company`, `Account.Individual`, `Account.TosAcceptance`.
- **Fixtures** — `test/support/fixtures/` already has Customer/PI/SI/PM/Refund/Checkout.Session fixtures (Phase 06). Add `AccountFixtures`, `AccountLinkFixtures`, `LoginLinkFixtures`, `CapabilityFixtures` following the same file structure.
- **`LatticeStripe.List`** — `list/3` and `stream!/3` pattern from Customer/PaymentIntent. Account supports list but `AccountLink` and `LoginLink` do not (Stripe API has no list endpoint for single-use resources).

### Established Patterns
- **Flat namespace** for top-level resources (`LatticeStripe.AccountLink`, not `LatticeStripe.Account.Link`) — Phase 15 D4. `LoginLink` follows same rule.
- **Nested structs under resource directory** (`LatticeStripe.Account.BusinessProfile` lives at `lib/lattice_stripe/account/business_profile.ex`) — Phase 14/15/16 convention.
- **Bang variants** for every public fallible function — Phase 4 onwards.
- **`Jason.Encoder` NOT derived** on any resource struct — established convention (they're decoded from Stripe, never encoded to Stripe).
- **Pre-network `require_param!`** for endpoint-required params (e.g., `Account.reject/4` must pre-validate the account `id` presence — ArgumentError before any HTTP call).
- **Webhook-handoff callout** in every resource guide — "drive application state from webhook events, not SDK responses" (Phase 15 D5 precedent, `guides/subscriptions.md`).

### Integration Points
- `mix.exs` — ExDoc `groups_for_modules:` add "Connect" group containing `LatticeStripe.Account`, `LatticeStripe.AccountLink`, `LatticeStripe.LoginLink`, and all `Account.*` nested modules. Place after "Billing" group.
- `mix.exs` — ExDoc `extras:` add `guides/connect.md` to the extras list in the "Guides" section.
- `test/test_helper.exs` — integration test runner already configured for stripe-mock; no changes.
- `lib/lattice_stripe/telemetry.ex` — no changes needed; Account resource path parsing will be auto-derived by `parse_resource_and_operation/2` from URL path (Phase 08 D-05).

### Creative Options Enabled
- The already-wired per-request `stripe_account` opts override means `guides/connect.md` can show a first-class pattern: one Client for the platform, `opts: [stripe_account: "acct_..."]` passed to any resource call (Customer, PaymentIntent, etc.) to act on behalf of the connected account. This is the canonical Connect integration shape and LatticeStripe already supports it end-to-end.
- The `:extra` map on `Account.Settings` absorbs forward-compat for the 5 sub-objects cleanly — if Stripe adds a new branding field, users' code doesn't break, and the value is still accessible via `account.settings.extra["branding"]["new_field"]`.

</code_context>

<specifics>
## Specific Ideas from Discussion

- **D-01 budget reframing** is a deliberate policy decision, not phase-local. Subsequent phases should treat "5-field budget" as "5 distinct nested struct modules, with reuse encouraged." Add to STATE.md decisions log after commit.
- **`Capability.status_atom/1` helper shape** is locked exactly as drafted in D-02 — uses `String.to_existing_atom/1` inside the guard clause (safe because `@known_statuses` pre-declares the atoms at compile time) and falls through to `:unknown` for any unknown value. Never calls `String.to_atom/1` on user input.
- **Phase 18 scope is now broader than the original ROADMAP.md stub** — adds `ExternalAccount` (full polymorphic bank+card CRUD). Update ROADMAP.md Phase 18 entry to reflect this.
- **guides/connect.md** must include the "act on behalf of a connected account via `stripe_account:` opts" pattern prominently — this is the single most important Connect idiom and the Client already supports it.
- **Account PII fields** must be audited against stripe-node's PII field list to ensure `Inspect` hides the right fields. Reference: `Company{tax_id, phone, address}`, `Individual{dob, ssn_last_4, first_name, last_name, address, phone, email, id_number}`, `TosAcceptance{ip, user_agent}`.

</specifics>

<deferred>
## Deferred Ideas

- **`Account.Persons` sub-resource** — Stripe Connect allows creating/retrieving/updating/deleting individual "Person" objects on a connected account beyond the single `individual`/`company` representative. The `Individual` struct covers the common single-representative case. Revisit if user demand surfaces. Stripe API ref: `/v1/accounts/:id/persons`.
- **`AccountLink.create_onboarding/3` and `AccountLink.create_update/3` thin wrappers** — considered in D-04c as future ergonomic sugar. Not in Phase 17. Track here and implement only if real user demand surfaces post-ship.
- **Standard/Express/Custom account-type convenience constructors** (`Account.create_express/3` etc.) — rejected as fake ergonomics for now. `type` in params is sufficient. Could be reconsidered once Stripe deprecates `type` in favor of the `controller` model across all SDKs.
- **Unified `Account.Party` struct** (collapsing Company + Individual) — rejected in D-01 because mutual exclusion is load-bearing. Record here for future reconsideration if Stripe ever flattens `business_type` semantics.
- **Cascading `Account.Settings` sub-objects into typed structs** (`Account.Settings.Payouts`, `Account.Settings.Branding`, etc.) — deferred. If heavy user pattern-matching on settings sub-objects emerges, revisit as a standalone phase addition.

### Reviewed Todos (not folded)

No todos cross-referenced for Phase 17 — none pending in STATE.md Accumulated Context that touch Connect scope.

</deferred>

---

*Phase: 17-connect-accounts-links*
*Context gathered: 2026-04-12*
*Research: 4 parallel gsd-advisor-researcher agents covered Gray Areas A/B/C/D*
