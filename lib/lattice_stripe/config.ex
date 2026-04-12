defmodule LatticeStripe.Config do
  @moduledoc """
  Client configuration schema and validation.

  Uses NimbleOptions to validate all client options at creation time,
  providing clear error messages for invalid configuration.

  ## Required Options

  - `:api_key` - Your Stripe API key (`sk_test_...` or `sk_live_...`)
  - `:finch` - Name of the Finch pool started in your supervision tree

  ## Optional Options

  See `schema/0` for full option documentation with defaults.

  ## Example

      # In your application supervisor:
      children = [
        {Finch, name: MyApp.Finch}
      ]

      # Create a validated config:
      {:ok, config} = LatticeStripe.Config.validate(
        api_key: "sk_test_...",
        finch: MyApp.Finch
      )
  """

  @schema NimbleOptions.new!(
            api_key: [
              type: :string,
              required: true,
              doc: "Stripe API key (sk_test_... or sk_live_...)"
            ],
            base_url: [
              type: :string,
              default: "https://api.stripe.com",
              doc: "Stripe API base URL. Override for testing with stripe-mock."
            ],
            api_version: [
              type: :string,
              default: "2026-03-25.dahlia",
              doc: "Stripe API version to pin requests to."
            ],
            transport: [
              type: :atom,
              default: LatticeStripe.Transport.Finch,
              doc: "Transport module implementing LatticeStripe.Transport behaviour."
            ],
            json_codec: [
              type: :atom,
              default: LatticeStripe.Json.Jason,
              doc: "JSON codec module implementing LatticeStripe.Json behaviour."
            ],
            retry_strategy: [
              type: :atom,
              default: LatticeStripe.RetryStrategy.Default,
              doc:
                "Module implementing LatticeStripe.RetryStrategy behaviour for retry decisions."
            ],
            finch: [
              type: :atom,
              required: true,
              doc:
                "Name of the Finch pool to use for HTTP requests. Must be started in your supervision tree."
            ],
            timeout: [
              type: :pos_integer,
              default: 30_000,
              doc: "Default request timeout in milliseconds."
            ],
            max_retries: [
              type: :non_neg_integer,
              default: 2,
              doc:
                "Maximum number of retries for failed requests. 0 disables retries. Default 2 means up to 3 total attempts."
            ],
            stripe_account: [
              type: {:or, [:string, nil]},
              default: nil,
              doc: "Default Stripe-Account header for Connect platforms."
            ],
            telemetry_enabled: [
              type: :boolean,
              default: true,
              doc: "Whether to emit telemetry events for requests."
            ],
            require_explicit_proration: [
              type: :boolean,
              default: false,
              doc:
                "When true, proration-sensitive operations (Invoice.upcoming/3, Invoice.create_preview/3, Subscription mutations) require an explicit proration_behavior parameter. When false (default), the parameter passes through to Stripe's default, matching stripe-ruby/node/python SDK behavior."
            ]
          )

  @doc """
  Returns the NimbleOptions schema used for validation.
  """
  def schema, do: @schema

  @doc """
  Validates the given options against the config schema.

  Returns `{:ok, validated_opts}` on success or `{:error, %NimbleOptions.ValidationError{}}`
  on failure.
  """
  def validate(opts) do
    NimbleOptions.validate(opts, @schema)
  end

  @doc """
  Validates the given options against the config schema, raising on failure.

  Returns the validated keyword list on success, or raises
  `NimbleOptions.ValidationError` with a descriptive message on failure.
  """
  def validate!(opts) do
    NimbleOptions.validate!(opts, @schema)
  end
end
