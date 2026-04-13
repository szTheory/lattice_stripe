defmodule LatticeStripe.Account do
  @moduledoc """
  Operations on Stripe Connect Account objects.

  A Connect Account represents a user's connected Stripe account that your
  platform transacts on behalf of. Phase 17 delivers the full account lifecycle
  (`create/3`, `retrieve/3`, `update/4`, `delete/3`, `reject/4`, `list/3`,
  `stream!/3`) plus the companion onboarding URL modules
  `LatticeStripe.AccountLink` and `LatticeStripe.LoginLink`.

  ## Acting on behalf of a connected account

  LatticeStripe already threads the `Stripe-Account` header end-to-end in
  `LatticeStripe.Client`. You can set a connected account either per-client OR
  per-request:

      # Per-client (platform holds the key, acts on one connected account)
      client = LatticeStripe.Client.new!(
        api_key: "sk_test_platform",
        finch: MyApp.Finch,
        stripe_account: "acct_connected"
      )
      LatticeStripe.Customer.create(client, %{email: "c@example.test"})

      # Per-request (platform holds the key, switches connected account per-call)
      LatticeStripe.Customer.create(client, %{email: "c@example.test"},
        stripe_account: "acct_connected")

  The per-request opt takes precedence over the per-client value. See the
  Connect guide for idiomatic patterns.

  ## D-01 nested struct budget reframing

  Phase 17 amends Phase 16's D1 nested-struct budget rule: the 5-module budget
  now counts DISTINCT nested struct modules, not promoted parent fields. This
  resource exercises the reframing — `LatticeStripe.Account.Requirements` is
  defined once and reused at both `%Account{}.requirements` and
  `%Account{}.future_requirements`. Subsequent phases should treat the rule as
  "up to 5 distinct nested struct modules per resource, with reuse encouraged."

  ## Requesting capabilities

  LatticeStripe does NOT provide a `request_capability/4` helper (rejected per
  Phase 17 D-04b as fake ergonomics — the capability name set is an open,
  growing string enum). Use `update/4` with the nested map idiom:

      LatticeStripe.Account.update(client, "acct_123", %{
        capabilities: %{
          "card_payments" => %{requested: true},
          "transfers" => %{requested: true}
        }
      })

  ## Rejecting a connected account

  `reject/4` calls `POST /v1/accounts/:id/reject` with a single `reason` atom.
  The reason is guarded at the function head:

      LatticeStripe.Account.reject(client, "acct_123", :fraud)
      LatticeStripe.Account.reject(client, "acct_123", :terms_of_service)
      LatticeStripe.Account.reject(client, "acct_123", :other)

  Any other atom raises `FunctionClauseError` at call time. This is an
  irreversible action — once rejected, the connected account cannot accept
  charges or transfers. Wire `account.application.deauthorized` and
  `account.updated` webhooks in `LatticeStripe.Webhook` rather than driving
  state from the SDK response.

  ## Webhook handoff

  **Drive your application state from webhook events, not SDK responses.** An
  SDK response reflects the account state at the moment of the call, but
  Stripe may transition the account a moment later (capability activation,
  requirements update, payouts enablement). Wire `account.updated`,
  `account.application.authorized`, and `account.application.deauthorized`
  into your webhook handler.

  ## Stripe API Reference

  See the [Stripe Accounts API](https://docs.stripe.com/api/accounts).
  """

  alias LatticeStripe.{Client, Error, List, Request, Resource, Response}

  alias LatticeStripe.Account.{
    BusinessProfile,
    Capability,
    Company,
    Individual,
    Requirements,
    Settings,
    TosAcceptance
  }

  # Known top-level fields from the Stripe Account object.
  # Used to build the struct and separate known from extra (unknown) fields.
  # String sigil (no `a`) matches Jason's default string-key output.
  @known_fields ~w[
    id object business_profile business_type capabilities charges_enabled
    company controller country created default_currency details_submitted
    email external_accounts future_requirements individual livemode metadata
    payouts_enabled requirements settings tos_acceptance type
  ]

  # credo:disable-for-next-line Credo.Check.Warning.StructFieldAmount
  defstruct [
    :id,
    :business_profile,
    :business_type,
    :capabilities,
    :charges_enabled,
    :company,
    :controller,
    :country,
    :created,
    :default_currency,
    :details_submitted,
    :email,
    :external_accounts,
    :future_requirements,
    :individual,
    :livemode,
    :metadata,
    :payouts_enabled,
    :requirements,
    :settings,
    :tos_acceptance,
    :type,
    object: "account",
    extra: %{}
  ]

  @typedoc "A Stripe Connect Account object."
  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          business_profile: BusinessProfile.t() | nil,
          business_type: String.t() | nil,
          capabilities: %{optional(String.t()) => Capability.t()} | nil,
          charges_enabled: boolean() | nil,
          company: Company.t() | nil,
          controller: map() | nil,
          country: String.t() | nil,
          created: integer() | nil,
          default_currency: String.t() | nil,
          details_submitted: boolean() | nil,
          email: String.t() | nil,
          external_accounts: map() | nil,
          future_requirements: Requirements.t() | nil,
          individual: Individual.t() | nil,
          livemode: boolean() | nil,
          metadata: map() | nil,
          payouts_enabled: boolean() | nil,
          requirements: Requirements.t() | nil,
          settings: Settings.t() | nil,
          tos_acceptance: TosAcceptance.t() | nil,
          type: String.t() | nil,
          extra: map()
        }

  # ---------------------------------------------------------------------------
  # Public API: CRUD
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new Connect Account.

  Sends `POST /v1/accounts`.

  ## Parameters

  - `client` - `%LatticeStripe.Client{}`
  - `params` - Map of account attributes. Common keys:
    - `"type"` - Account type: `"custom"`, `"express"`, or `"standard"`
    - `"country"` - Two-letter country code (e.g., `"US"`)
    - `"email"` - Account email address
  - `opts` - Per-request overrides (e.g., `[idempotency_key: "..."]`)

  ## Returns

  - `{:ok, %Account{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure
  """
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :post, path: "/v1/accounts", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `create/3` but raises on failure."
  @spec create!(Client.t(), map(), keyword()) :: t()
  def create!(%Client{} = client, params \\ %{}, opts \\ []),
    do: client |> create(params, opts) |> Resource.unwrap_bang!()

  @doc """
  Retrieves a Connect Account by ID.

  Sends `GET /v1/accounts/:id`.
  """
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "/v1/accounts/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `retrieve/3` but raises on failure."
  @spec retrieve!(Client.t(), String.t(), keyword()) :: t()
  def retrieve!(%Client{} = client, id, opts \\ []) when is_binary(id),
    do: client |> retrieve(id, opts) |> Resource.unwrap_bang!()

  @doc """
  Updates a Connect Account by ID.

  Sends `POST /v1/accounts/:id`.

  To request capabilities, use the nested map idiom — do not look for a
  `request_capability/4` helper, which does not exist (D-04b). See the
  "Requesting capabilities" section in the module doc.
  """
  @spec update(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/accounts/#{id}", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `update/4` but raises on failure."
  @spec update!(Client.t(), String.t(), map(), keyword()) :: t()
  def update!(%Client{} = client, id, params, opts \\ []) when is_binary(id),
    do: client |> update(id, params, opts) |> Resource.unwrap_bang!()

  @doc """
  Deletes a Connect Account.

  Sends `DELETE /v1/accounts/:id`. Stripe returns a deletion stub
  `%{"id" => ..., "object" => "account", "deleted" => true}`. The returned
  `%Account{}` will have `extra: %{"deleted" => true}`.

  > #### Irreversible {: .warning}
  >
  > Deletion cannot be undone. Only custom and express accounts may be deleted;
  > standard accounts must be rejected via `reject/4` instead.
  """
  @spec delete(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def delete(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :delete, path: "/v1/accounts/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `delete/3` but raises on failure."
  @spec delete!(Client.t(), String.t(), keyword()) :: t()
  def delete!(%Client{} = client, id, opts \\ []) when is_binary(id),
    do: client |> delete(id, opts) |> Resource.unwrap_bang!()

  # ---------------------------------------------------------------------------
  # reject/4 — D-04a atom guard (LOCKED per 17-CONTEXT.md §D-04a)
  # ---------------------------------------------------------------------------

  @reject_reasons [:fraud, :terms_of_service, :other]

  @doc """
  Rejects a Connect account.

  Dispatches to `POST /v1/accounts/:id/reject` with the atom reason converted to
  its Stripe string form. The `reason` MUST be one of `:fraud`,
  `:terms_of_service`, or `:other` — any other atom raises `FunctionClauseError`
  at the call site.

  ## Example

      Account.reject(client, "acct_123", :fraud)

  ## Irreversibility

  Rejection is one-way. Once rejected, the connected account cannot be
  re-activated. This is why `reject/4` guards the reason at the function head —
  a typo like `:fruad` fails loudly at compile-time (for literal atoms) or
  runtime, rather than silently sending an invalid payload to Stripe.
  """
  @spec reject(Client.t(), String.t(), :fraud | :terms_of_service | :other, keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def reject(%Client{} = client, id, reason, opts \\ [])
      when is_binary(id) and reason in @reject_reasons do
    params = %{"reason" => Atom.to_string(reason)}

    %Request{method: :post, path: "/v1/accounts/#{id}/reject", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `reject/4` but raises on failure."
  @spec reject!(Client.t(), String.t(), :fraud | :terms_of_service | :other, keyword()) :: t()
  def reject!(%Client{} = client, id, reason, opts \\ [])
      when is_binary(id) and reason in @reject_reasons do
    client |> reject(id, reason, opts) |> Resource.unwrap_bang!()
  end

  # ---------------------------------------------------------------------------
  # Public API: list + stream
  # ---------------------------------------------------------------------------

  @doc """
  Lists Connect Accounts with optional filters.

  Sends `GET /v1/accounts`.
  """
  @spec list(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :get, path: "/v1/accounts", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc "Like `list/3` but raises on failure."
  @spec list!(Client.t(), map(), keyword()) :: Response.t()
  def list!(%Client{} = client, params \\ %{}, opts \\ []),
    do: client |> list(params, opts) |> Resource.unwrap_bang!()

  @doc """
  Returns a lazy stream of all Connect Accounts matching the given params.

  Auto-paginates via `LatticeStripe.List.stream!/2`. Raises on fetch failure.
  """
  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: "/v1/accounts", params: params, opts: opts}
    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  # ---------------------------------------------------------------------------
  # from_map/1 — nested-struct casting
  # ---------------------------------------------------------------------------

  @doc false
  def from_map(nil), do: nil

  def from_map(%{} = map) do
    {known, extra} = Map.split(map, @known_fields)
    known_atoms = Map.new(known, fn {k, v} -> {String.to_existing_atom(k), v} end)

    struct(
      __MODULE__,
      known_atoms
      |> Map.put(:business_profile, BusinessProfile.from_map(known_atoms[:business_profile]))
      |> Map.put(:requirements, Requirements.from_map(known_atoms[:requirements]))
      |> Map.put(
        :future_requirements,
        Requirements.from_map(known_atoms[:future_requirements])
      )
      |> Map.put(:tos_acceptance, TosAcceptance.from_map(known_atoms[:tos_acceptance]))
      |> Map.put(:company, Company.from_map(known_atoms[:company]))
      |> Map.put(:individual, Individual.from_map(known_atoms[:individual]))
      |> Map.put(:settings, Settings.from_map(known_atoms[:settings]))
      |> Map.put(:capabilities, cast_capabilities(known_atoms[:capabilities]))
      |> Map.put(:extra, extra)
    )
  end

  defp cast_capabilities(nil), do: nil

  defp cast_capabilities(caps) when is_map(caps) do
    Map.new(caps, fn {name, obj} -> {name, Capability.cast(obj)} end)
  end
end
