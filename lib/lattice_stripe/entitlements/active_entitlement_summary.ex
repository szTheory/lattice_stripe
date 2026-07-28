defmodule LatticeStripe.Entitlements.ActiveEntitlementSummary do
  @moduledoc """
  A point-in-time snapshot of everything a customer is currently entitled to.

  Wire object `entitlements.active_entitlement_summary`. This object is **delivered by
  webhook only** — it arrives as the `data.object` of an
  `entitlements.active_entitlement_summary.updated` event, and Stripe serves it from no
  HTTP endpoint at all. There is therefore no `retrieve/2` here, and that is **not a gap**:
  there is nothing to retrieve it from. The only way to obtain one is to receive it.

  It also has **no top-level** `id` — the object carries no `id` property, not even an
  optional one, and no `x-resourceId`, which is an independent structural confirmation that
  it is not an addressable resource. The struct consequently has no `:id` field.

  See [Entitlements](guides/entitlements.md) for the end-to-end story.

  ## Stripe inlines at most ten entitlements

  The nested `entitlements` envelope is a **page**, not a snapshot. Stripe inlines at most
  **ten** active entitlements and sets `has_more` when there are more. Treating that inline
  page as a complete picture is the bug this module was written to remove: a customer with
  eleven active entitlements looks unentitled to the eleventh, and a reconciler that writes
  the inline page to a local store revokes access the customer legitimately holds.

  Use `stream_entitlements!/3`. It performs a **full canonical re-fetch** keyed on the
  summary's `customer`, at `limit=100` per page, following `has_more` to the end. It ignores
  the inline page entirely and deliberately does not resume from its cursor — resuming would
  stitch a head-of-list captured when the webhook fired to a tail queried later, producing a
  hybrid whose ordering assumption spans two points in time. One call, one point in time.

  ## The inlined url is rewritten

  Stripe's webhook payload sets the inlined list's `url` to
  `"/v1/customer/cus_ABC123customer/entitlements"` — singular `customer`, path-scoped. That
  string is not one of the paths in Stripe's OpenAPI spec; its callability is not
  established and it 404s against `stripe-mock`. Because `LatticeStripe.List.stream/2`
  builds each next page from `list.url`, this module rewrites the nested list's `url` to the
  canonical `/v1/entitlements/active_entitlements`, populates `_params` with the customer
  filter, and derives `_last_id` from the raw wire maps. A consumer who reaches for
  `LatticeStripe.List.stream(summary.entitlements, client)` instead of the blessed path
  therefore still gets a documented, callable, tenant-scoped request.

  ## Reconciling from a webhook

      alias LatticeStripe.Entitlements.ActiveEntitlementSummary

      def reconcile_from_event(%LatticeStripe.Event{} = event, client) do
        summary = ActiveEntitlementSummary.from_map(event.data["object"])

        entitlements =
          client
          |> ActiveEntitlementSummary.stream_entitlements!(summary)
          |> Enum.to_list()

        MyApp.Entitlements.reconcile(summary.customer, entitlements)
      end

  Dispatch it from your `LatticeStripe.Webhook.Handler` on the
  `entitlements.active_entitlement_summary.updated` event type.

  Gate your application against the local store that `reconcile/2` writes — never against a
  network call on the authorization path. See
  `LatticeStripe.Entitlements.ActiveEntitlement` for why.
  """

  alias LatticeStripe.{Client, List}
  alias LatticeStripe.Entitlements.ActiveEntitlement

  # Exactly the four fields Stripe's spec marks required. Note the absence of "id".
  @known_fields ~w(object customer entitlements livemode)

  @type t :: %__MODULE__{
          object: String.t() | nil,
          customer: String.t() | nil,
          entitlements: List.t() | nil,
          livemode: boolean() | nil,
          extra: map()
        }

  # There is deliberately NO :id field. The Stripe object has no `id` property — not even
  # an optional one — and carries no `x-resourceId`. This is not an oversight and must not
  # be "fixed": adding :id would invent a field the wire never sends.
  defstruct [
    :customer,
    :entitlements,
    :livemode,
    object: "entitlements.active_entitlement_summary",
    extra: %{}
  ]

  # ---------------------------------------------------------------------------
  # RECONCILE
  # ---------------------------------------------------------------------------

  @doc """
  Returns a lazy stream of **all** of the summarized customer's active entitlements.

  A full canonical re-fetch against `/v1/entitlements/active_entitlements` at `limit=100`,
  keyed on `summary.customer`. The summary's inline page is ignored entirely — see the
  module documentation for why a cursor-resume would be worse rather than cheaper.

  Raises `LatticeStripe.Error` if any page fetch fails, so a partial enumeration surfaces
  as an error rather than as a short list.

      entitlements =
        client
        |> LatticeStripe.Entitlements.ActiveEntitlementSummary.stream_entitlements!(summary)
        |> Enum.to_list()

  There is no non-bang twin, for the same reason
  `LatticeStripe.Entitlements.ActiveEntitlement.stream!/3` has none.
  """
  @spec stream_entitlements!(Client.t(), t(), keyword()) :: Enumerable.t()
  def stream_entitlements!(%Client{} = client, %__MODULE__{customer: customer}, opts \\ [])
      when is_binary(customer) do
    ActiveEntitlement.stream!(client, %{"customer" => customer, "limit" => "100"}, opts)
  end

  # ---------------------------------------------------------------------------
  # DECODE
  # ---------------------------------------------------------------------------

  @doc """
  Decode a Stripe-shaped string-keyed map into an `%ActiveEntitlementSummary{}`.

  The nested `entitlements` envelope becomes a `LatticeStripe.List` whose `data` is a list
  of `LatticeStripe.Entitlements.ActiveEntitlement` structs, with its `url` and `_params`
  rewritten for canonical pagination.

  Idempotent: applied to an already-decoded struct it returns it unchanged, and
  `from_map(nil)` returns `nil`. Unknown top-level keys land in `:extra`.
  """
  @spec from_map(map() | t() | nil) :: t() | nil
  def from_map(nil), do: nil

  # The struct clause MUST precede the `is_map/1` clause — a struct is a map.
  def from_map(%__MODULE__{} = summary), do: summary

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)
    customer = known["customer"]

    %__MODULE__{
      object: known["object"] || "entitlements.active_entitlement_summary",
      customer: customer,
      entitlements: parse_entitlements(known["entitlements"], customer),
      livemode: known["livemode"],
      extra: extra
    }
  end

  defp parse_entitlements(nil, _customer), do: nil

  # ORDER IS LOAD-BEARING. `List.from_json/3` derives `_last_id` by pattern-matching
  # `%{"id" => id}` on RAW string-keyed maps; typed `%ActiveEntitlement{}` structs do not
  # match that pattern. Typing `data` before the `from_json/3` call compiles, passes every
  # other test, and leaves `_last_id` nil — after which `build_next_page_request/1` falls to
  # its empty-params branch and either truncates at ten or re-requests page 1 forever.
  # `from_json/3` FIRST on the raw map; the `Enum.map` typing goes in the struct update.
  defp parse_entitlements(%{"object" => "list", "data" => data} = list, customer)
       when is_list(data) do
    %{
      List.from_json(list, %{"customer" => customer}, [])
      | data: Enum.map(data, &ActiveEntitlement.from_map/1),
        url: ActiveEntitlement.list_path()
    }
  end

  defp parse_entitlements(other, _customer), do: other
end
