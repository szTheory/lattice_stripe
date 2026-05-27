defmodule LatticeStripe.EventNotification.RelatedObject do
  @moduledoc """
  Represents the `related_object` sub-resource referenced by a Stripe thin-event
  notification (or a v2-fetched `%LatticeStripe.Event{}`).

  Thin-event notifications point at the underlying resource (e.g. an account, customer,
  invoice) without embedding the full snapshot. Adopters pattern-match this sub-struct
  to dispatch to typed fetchers via `LatticeStripe.Webhook.fetch_related_object/3`.

  ## Fields

  - `id` — Stripe ID of the related resource (e.g., `"acct_1T93Q4Pmpb34Vto6"`)
  - `type` — Stripe object type string (e.g., `"v2.core.account"`, `"customer"`)
  - `url` — Relative API path to fetch the resource (e.g., `"/v2/core/accounts/acct_..."`)
  - `extra` — Unknown fields from Stripe not yet in this struct

  This sub-struct is the **single source of truth** for `related_object` on both
  `LatticeStripe.EventNotification.t()` and `LatticeStripe.Event.t()`. The same
  module is decoded from both wire shapes.

  ## Stripe API Reference

  See the [Stripe thin-event payload](https://docs.stripe.com/event-destinations)
  for field definitions.
  """

  @known_fields ~w[id type url]

  defstruct [:id, :type, :url, extra: %{}]

  @typedoc """
  A `related_object` reference on a Stripe thin-event payload.
  """
  @type t :: %__MODULE__{
          id: String.t() | nil,
          type: String.t() | nil,
          url: String.t() | nil,
          extra: map()
        }

  @doc """
  Converts a decoded Stripe API map to a `%RelatedObject{}` struct.

  Returns `nil` when given `nil` — this is load-bearing because parent decoders
  (`EventNotification.from_map/1`, `Event.from_map/1`) call this function
  unconditionally on the `"related_object"` map key, which may be absent.

  Maps all known fields. Any unrecognized fields are collected into `extra` so
  no data is silently lost. Always succeeds (infallible) for map inputs.

  ## Example

      iex> LatticeStripe.EventNotification.RelatedObject.from_map(%{
      ...>   "id" => "acct_1T93Q4Pmpb34Vto6",
      ...>   "type" => "v2.core.account",
      ...>   "url" => "/v2/core/accounts/acct_1T93Q4Pmpb34Vto6"
      ...> })
      %LatticeStripe.EventNotification.RelatedObject{
        id: "acct_1T93Q4Pmpb34Vto6",
        type: "v2.core.account",
        url: "/v2/core/accounts/acct_1T93Q4Pmpb34Vto6",
        extra: %{}
      }
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      id: known["id"],
      type: known["type"],
      url: known["url"],
      extra: extra
    }
  end
end

defimpl Inspect, for: LatticeStripe.EventNotification.RelatedObject do
  import Inspect.Algebra

  def inspect(obj, opts) do
    # Show key display fields. Show extra only when non-empty to reduce noise.
    # url is a relative API path (e.g. "/v2/core/accounts/..."), not a signed URL —
    # safe to display in inspect output.
    base_fields = [
      id: obj.id,
      type: obj.type,
      url: obj.url
    ]

    fields =
      if obj.extra == %{} do
        base_fields
      else
        base_fields ++ [extra: obj.extra]
      end

    pairs =
      fields
      |> Enum.map(fn {k, v} ->
        concat([Atom.to_string(k), ": ", to_doc(v, opts)])
      end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.EventNotification.RelatedObject<" | pairs] ++ [">"])
  end
end
