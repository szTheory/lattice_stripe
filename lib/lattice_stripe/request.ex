defmodule LatticeStripe.Request do
  @moduledoc """
  A Stripe API request as pure data.

  Resource modules build Request structs describing what to call.
  `Client.request/2` dispatches them through the configured transport.

  ## Fields

  - `method` - HTTP method (`:get`, `:post`, `:delete`)
  - `path` - API path (e.g., `"/v1/customers"`, `"/v1/customers/cus_123"`)
  - `params` - Request parameters (body for POST, query for GET)
  - `opts` - Per-request overrides: `[stripe_account: "acct_...", timeout: 5_000, idempotency_key: "...", api_key: "sk_...", stripe_version: "...", expand: ["data.customer"]]`
  """

  @typedoc """
  A Stripe API request as pure data.

  Built by resource modules (e.g., `LatticeStripe.Customer.create/3`) and dispatched
  by `LatticeStripe.Client.request/2`.

  - `method` - HTTP method (`:get`, `:post`, `:delete`)
  - `path` - API path (e.g., `"/v1/customers"`, `"/v1/customers/cus_123"`)
  - `params` - Request parameters: body for POST, query string for GET
  - `opts` - Per-request overrides such as `:idempotency_key`, `:stripe_account`,
    `:api_key`, `:stripe_version`, `:expand`, or `:timeout`
  """
  @type t :: %__MODULE__{
          method: :get | :post | :delete,
          path: String.t(),
          params: map(),
          opts: keyword()
        }

  defstruct [
    :method,
    :path,
    params: %{},
    opts: []
  ]
end
