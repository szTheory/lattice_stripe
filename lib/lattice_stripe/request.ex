defmodule LatticeStripe.Request do
  @moduledoc false

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
