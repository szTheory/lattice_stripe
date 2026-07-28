# Entitlements

Stripe Entitlements answers one question: *what is this customer allowed to use
right now?* You define a **feature** once per capability you sell, attach it to
the Products customers buy, and Stripe maintains an **active entitlement** per
customer per feature. LatticeStripe exposes that family as typed modules under
`LatticeStripe.Entitlements.*`.

This guide covers reading a customer's entitlements, the webhook-driven
reconciler pattern that keeps a local copy honest, and managing the feature
catalog itself. Code examples reflect function signatures shipped in v1.10.

## Scope boundary

LatticeStripe is an HTTP client SDK — typed resources, `{:ok, struct}` /
`{:error, %LatticeStripe.Error{}}`, and testing fixtures. Nothing more.

**In scope:** `LatticeStripe.Entitlements.ActiveEntitlement` (read-only),
`LatticeStripe.Entitlements.Feature` (full CRUDL), and
`LatticeStripe.Entitlements.ActiveEntitlementSummary` (webhook decoding).

**There is no `entitled?` helper, and there will not be one.** This library
ships no per-request predicate that asks Stripe whether a customer holds a
feature. The reason is not minimalism — it is that an authorization **gate**
which makes a network call fails **open**. Under a network partition the call
times out, the caller has no answer, and the pragmatic fallback every
implementation reaches for is to let the request through. That grants a customer
access to something they did not buy, at exactly the moment you are least able
to notice.

Do this instead:

1. **Reconcile** when the `entitlements.active_entitlement_summary.updated`
   webhook fires — call
   `LatticeStripe.Entitlements.ActiveEntitlementSummary.stream_entitlements!/3`
   (or `LatticeStripe.Entitlements.ActiveEntitlement.stream!/3` when you are
   reconciling outside a webhook) and enumerate it fully.
2. **Persist** the resulting lookup keys to a local store — a database table, an
   ETS cache, whatever your application already trusts — alongside a
   `reconciled_at` timestamp.
3. **Gate locally** on every request. Authorization reads your store, never the
   network. It is fast, it is available when Stripe is not, and it cannot time
   out.
4. **Fail closed on staleness.** When the stored snapshot is older than your
   freshness budget, **fail closed** — deny access and re-reconcile. You choose
   the failure mode rather than letting the network choose it for you.

That recipe is the whole replacement. It is four steps, it is testable, and it
is why the helper is absent rather than pending.

Provisioning features onto Products, entitlement analytics, and any
authorization framework of your own are **out of SDK scope** — see
[scope.md](scope.md) for the project-wide contract.

## Mental model

```
Entitlements.Feature (catalog definition, feat_…)
  ├── lookup_key — immutable, your system's identifier
  └── active — false means archived
          │
          │  attached to a Product   (Product.Feature, prodft_… — a later phase)
          ▼
Product / Price
          │
          │  customer buys it
          ▼
Entitlements.ActiveEntitlement (ent_…)
  ├── lookup_key — mirrors the feature's
  └── feature — expandable
          │
          │  any change fires a webhook
          ▼
Entitlements.ActiveEntitlementSummary (webhook only, no id)
  └── entitlements — an inlined %LatticeStripe.List{} page
```

LatticeStripe covers the **definition** end (`Feature`) and the **result** end
(`ActiveEntitlement`, `ActiveEntitlementSummary`) today. The *attachment* in the
middle — the `product_feature` object that records "this Product grants this
feature" — arrives in a later release; until then, attach features in the Stripe
Dashboard or via `LatticeStripe.Client.request/2`.

## Reading a customer's entitlements

`customer` is a **required** filter. Stripe serves no account-wide active
entitlement list, so both `list/3` and `stream!/3` raise `ArgumentError` before
any network call when it is missing. The guard checks key **presence, not value
emptiness** — a `customer` of `""` passes it and fails at Stripe instead.

```elixir
alias LatticeStripe.Entitlements.ActiveEntitlement

{:ok, resp} = ActiveEntitlement.list(client, %{"customer" => "cus_123"})
keys = Enum.map(resp.data.data, & &1.lookup_key)
```

**`list/3` returns one page, and Stripe's `limit` defaults to 10.** A customer
with eleven active entitlements looks unentitled to the eleventh. A truncated
read makes a paying customer look like a freeloader, so `list/3` is for
inspection, not for reconciliation.

`stream!/3` is the complete-enumeration path. It follows `has_more` across every
page and raises `LatticeStripe.Error` rather than quietly returning a short
list:

```elixir
# Every page, held in memory:
all =
  client
  |> ActiveEntitlement.stream!(%{"customer" => "cus_123"})
  |> Enum.to_list()

# Bounded — only the pages needed to yield 50 items are ever fetched:
first_50 =
  client
  |> ActiveEntitlement.stream!(%{"customer" => "cus_123"})
  |> Stream.take(50)
  |> Enum.to_list()
```

`retrieve/3` fetches one entitlement by its `ent_`-prefixed id. Every function
here has a bang twin (`list!/3`, `retrieve!/3`) that raises instead of returning
a tuple; `stream!/3` has no non-bang twin, because a lazy stream cannot return
an error tuple for a failure that happens pages later.

`ActiveEntitlement` is deliberately **read-only** — no create, update, or
delete. Entitlements are derived from purchases; you change them by changing
what the customer bought.

Each entitlement carries its own `lookup_key`, mirroring the feature's, so the
common reconciliation read needs no `expand` param at all.

## The reconciler pattern

This is the shape to copy. One call, no cursor bookkeeping:

```elixir
alias LatticeStripe.Entitlements.ActiveEntitlementSummary

def reconcile_from_event(%LatticeStripe.Event{} = event, client) do
  summary = ActiveEntitlementSummary.from_map(event.data["object"])

  entitlements =
    client
    |> ActiveEntitlementSummary.stream_entitlements!(summary)
    |> Enum.to_list()

  MyApp.Billing.reconcile(summary.customer, entitlements)
end
```

`stream_entitlements!/3` performs a **full canonical re-fetch** keyed on
`summary.customer`, at 100 per page, following `has_more` to the end. It ignores
the summary's inlined page entirely.

That is deliberate, and it is why there is no `has_more` branch above. Resuming
from the inline page's cursor would stitch a head-of-list captured when the
webhook fired to a tail queried moments later — a hybrid snapshot whose ordering
assumption spans two points in time. One call means one point in time, which is
the only version of this that is simple to reason about during an incident. The
consumer never has to learn how many entitlements Stripe inlines.

## The active entitlement summary

`LatticeStripe.Entitlements.ActiveEntitlementSummary` is delivered **by webhook
only**. It arrives as the `data.object` of an
`entitlements.active_entitlement_summary.updated` event, and Stripe serves it
from no HTTP endpoint at all. There is therefore no `retrieve` here, and that is
not a gap — there is nothing to retrieve it from. The only surface is
`from_map/1` and `stream_entitlements!/3`.

It also has **no top-level `id`**. The Stripe object carries no `id` property,
not even an optional one, so the struct has no `:id` field. Do not add one.

The nested `entitlements` field is a typed `%LatticeStripe.List{}` whose `data`
is a list of `%LatticeStripe.Entitlements.ActiveEntitlement{}` structs. Treat it
as a **page**, not a snapshot: it is truncated, and the truncation is precisely
the bug `stream_entitlements!/3` exists to remove.

## Managing features

`LatticeStripe.Entitlements.Feature` is the catalog definition — the thing you
create once per capability you sell. The surface below is the *complete* Stripe
surface, not a partial one.

| Function | HTTP | Purpose |
|----------|------|---------|
| `create/3` | `POST /v1/entitlements/features` | Define a feature; `lookup_key` and `name` required |
| `retrieve/3` | `GET /v1/entitlements/features/{id}` | Fetch one feature by its `feat_` id |
| `update/4` | `POST /v1/entitlements/features/{id}` | Change `name`, `metadata`, or `active` |
| `list/3` | `GET /v1/entitlements/features` | One page; filters `archived` and `lookup_key` |
| `stream!/3` | `GET /v1/entitlements/features` | Every page, lazily — the catalog-drift path |

Each non-bang function has a bang twin (`create!/3`, `retrieve!/3`, `update!/4`,
`list!/3`) that raises `LatticeStripe.Error` instead of returning a tuple.

**There is no delete verb**, because Stripe ships no `DELETE` for features.
**Archiving is `update/4` with `active: false`**, and unarchiving is `update/4`
with `active: true` — there is no `archive/3` or `unarchive/3`, for the same
reason `LatticeStripe.Price` and `LatticeStripe.Product` have none:

```elixir
alias LatticeStripe.Entitlements.Feature

{:ok, feature} =
  Feature.create(client, %{
    "lookup_key" => "premium_support",
    "name" => "Premium Support"
  })

{:ok, _archived} = Feature.update(client, feature.id, %{"active" => false})
```

Two words, one concept: the object field is **`active`**, the list filter is
**`archived`**, and their sense is inverted. Because `list/3` omits archived
features by default, a catalog reconciler that passes no filter will see them
*vanish* and diff them as deletions — pass `%{"archived" => true}` explicitly
and reconcile both views.

## lookup_key as your system identifier

Filter the list by lookup key:

```elixir
{:ok, resp} = Feature.list(client, %{"lookup_key" => "premium_support"})
```

That returns a **list, not a singleton**, even when exactly one feature matches.
Stripe defines no unique-lookup retrieval, so there is no
`retrieve_by_lookup_key` helper here — it would have to invent semantics for the
zero-result and multi-result cases that Stripe does not define. You decide what
those mean for your system.

The real unlock is that **`lookup_key` is immutable after create**. It is absent
from the update request body schema entirely, so Stripe silently ignores an
attempt to change it. That immutability is what makes it safe to key host
application configuration — and your local authorization store — on the lookup
key rather than on the generated `feat_` id.

## Attaching features to products

Attaching an entitlement feature to a Product is what causes purchases to
produce active entitlements. The `product_feature` attachment object
(`LatticeStripe.Product.Feature`, ids prefixed `prodft_`) is not yet part of the
typed surface; this section will cover creating, listing, and removing
attachments when it lands. Until then, attach features in the Stripe Dashboard
or through `LatticeStripe.Client.request/2`.

## Testing

Entitlements are unit-tested the way every other resource family is: Mox at the
Transport boundary, with wire-shaped fixture maps. Public
`LatticeStripe.Testing` fixtures for the entitlement objects are not yet
exported; this section will document them, and the object-type registry entries
that make webhook payloads deserialize automatically, when they ship. See
[testing.md](testing.md) for the Mox setup this family will follow.

## Webhooks

The event to subscribe to is
`entitlements.active_entitlement_summary.updated`, dispatched from your
`LatticeStripe.Webhook.Handler` implementation. Today, decode its payload
explicitly with `ActiveEntitlementSummary.from_map/1` as shown in
[The reconciler pattern](#the-reconciler-pattern); this section will cover
automatic deserialization and the full handler wiring when the registry entries
land. See [webhooks.md](webhooks.md) for signature verification and handler
setup.

## Error handling

Entitlement calls return `{:error, %LatticeStripe.Error{}}`. Common cases: a
missing or unknown `customer`, a duplicate `lookup_key` on create, and an
`ArgumentError` raised *before* the network when a required param is absent —
that last one is a bug in your call site, not a Stripe failure, which is why it
raises rather than returning a tuple.

`stream!/3` and `stream_entitlements!/3` raise on any page fetch failure, so a
partial enumeration surfaces as an error rather than as a short list. Never
catch that and proceed with what you got — a short list is the truncation bug
wearing a disguise.

See [error-handling.md](error-handling.md) for struct fields, retries, and
idempotency on write endpoints.

## See also

- [customer-portal.md](customer-portal.md) — how customers self-manage what they
  bought
- [metering.md](metering.md) — what they consumed, once they are entitled to it
- [subscriptions.md](subscriptions.md) — the purchases that produce entitlements
- [error-handling.md](error-handling.md) — `%LatticeStripe.Error{}` reference
- [webhooks.md](webhooks.md) — signature verification and handler dispatch
- [scope.md](scope.md) — what this library deliberately does not do
