defmodule LatticeStripe.SetupAttempt do
  @moduledoc """
  Operations on Stripe SetupAttempt objects.

  SetupAttempts are Stripe-generated history records used to inspect how a
  SetupIntent save attempt progressed, including any historical setup error.
  This module is intentionally read-only and exposes only list/stream access.

  **Requires `"setup_intent"` in params for `list/3` and `stream!/3`.** This
  filter is required because Stripe only supports setup-intent-scoped listing
  for this resource, so missing it raises `ArgumentError` before any network
  call.

  ## Usage

      {:ok, resp} =
        LatticeStripe.SetupAttempt.list(client, %{"setup_intent" => "seti_123"})

      latest_attempt = List.first(resp.data.data)

      client
      |> LatticeStripe.SetupAttempt.stream!(%{"setup_intent" => "seti_123"})
      |> Enum.take(10)
  """

  alias LatticeStripe.{Client, Error, List, Request, Resource, Response}
  alias LatticeStripe.ObjectTypes
  alias LatticeStripe.SetupAttempt.SetupError

  @known_fields ~w[
    id object application attach_to_self created customer customer_account
    flow_directions livemode on_behalf_of payment_method payment_method_details
    setup_error setup_intent status usage
  ]

  defstruct [
    :id,
    :application,
    :attach_to_self,
    :created,
    :customer,
    :customer_account,
    :flow_directions,
    :livemode,
    :on_behalf_of,
    :payment_method,
    :payment_method_details,
    :setup_error,
    :setup_intent,
    :status,
    :usage,
    object: "setup_attempt",
    extra: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          application: struct() | String.t() | map() | nil,
          attach_to_self: boolean() | nil,
          created: integer() | nil,
          customer: LatticeStripe.Customer.t() | String.t() | map() | nil,
          customer_account: map() | nil,
          flow_directions: [String.t()] | nil,
          livemode: boolean() | nil,
          on_behalf_of: struct() | String.t() | map() | nil,
          payment_method: LatticeStripe.PaymentMethod.t() | String.t() | map() | nil,
          payment_method_details: map() | nil,
          setup_error: SetupError.t() | nil,
          setup_intent: LatticeStripe.SetupIntent.t() | String.t() | map() | nil,
          status: atom() | String.t() | nil,
          usage: atom() | String.t() | nil,
          extra: map()
        }

  @doc """
  Lists setup attempts for a specific SetupIntent.

  Sends `GET /v1/setup_attempts` and returns typed `%SetupAttempt{}` items.
  """
  @spec list(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    Resource.require_param!(
      params,
      "setup_intent",
      ~s|SetupAttempt.list/3 requires a "setup_intent" key in params|
    )

    %Request{method: :get, path: "/v1/setup_attempts", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc """
  Like `list/3` but raises `LatticeStripe.Error` on failure.
  """
  @spec list!(Client.t(), map(), keyword()) :: Response.t()
  def list!(%Client{} = client, params \\ %{}, opts \\ []) do
    list(client, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Streams setup attempts for a specific SetupIntent with auto-pagination.
  """
  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    Resource.require_param!(
      params,
      "setup_intent",
      ~s|SetupAttempt.stream!/3 requires a "setup_intent" key in params|
    )

    req = %Request{method: :get, path: "/v1/setup_attempts", params: params, opts: opts}
    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      id: known["id"],
      object: known["object"] || "setup_attempt",
      application: parse_expandable(known["application"]),
      attach_to_self: known["attach_to_self"],
      created: known["created"],
      customer: parse_expandable(known["customer"]),
      customer_account: known["customer_account"],
      flow_directions: known["flow_directions"],
      livemode: known["livemode"],
      on_behalf_of: parse_expandable(known["on_behalf_of"]),
      payment_method: parse_expandable(known["payment_method"]),
      payment_method_details: known["payment_method_details"],
      setup_error: SetupError.from_map(known["setup_error"]),
      setup_intent: parse_expandable(known["setup_intent"]),
      status: atomize_status(known["status"]),
      usage: atomize_usage(known["usage"]),
      extra: extra
    }
  end

  defp parse_expandable(value) when is_map(value), do: ObjectTypes.maybe_deserialize(value)
  defp parse_expandable(value), do: value

  defp atomize_status("requires_confirmation"), do: :requires_confirmation
  defp atomize_status("requires_action"), do: :requires_action
  defp atomize_status("processing"), do: :processing
  defp atomize_status("succeeded"), do: :succeeded
  defp atomize_status("failed"), do: :failed
  defp atomize_status("abandoned"), do: :abandoned
  defp atomize_status(other), do: other

  defp atomize_usage("off_session"), do: :off_session
  defp atomize_usage("on_session"), do: :on_session
  defp atomize_usage(other), do: other
end
