# Credit Notes

`LatticeStripe.CreditNote` exposes Stripe's credit-note endpoints directly: create,
retrieve, update, list, preview, void, and both issued and preview line-item access.

Credit notes are lower-level billing primitives. This guide stays Stripe-shaped on
purpose: raw params go in, typed structs come back out.

## Lifecycle constraints

- Credit notes can only be created from finalized invoices.
- `LatticeStripe.CreditNote.preview/3` uses the same params shape as create and is the
  safest way to validate a request before creating anything.
- Voiding is irreversible and is only valid while the credit note is attached to an
  open invoice.

## Preview a credit note

Use `LatticeStripe.CreditNote.preview/3` to validate the request and inspect the
typed response before creating anything.

```elixir
{:ok, preview} =
  LatticeStripe.CreditNote.preview(client, %{
    "invoice" => "in_123",
    "lines" => [
      %{
        "type" => "invoice_line_item",
        "invoice_line_item" => "il_123",
        "quantity" => 1
      }
    ]
  })
```

For a custom credit line item:

```elixir
{:ok, preview} =
  LatticeStripe.CreditNote.preview(client, %{
    "invoice" => "in_123",
    "lines" => [
      %{
        "type" => "custom_line_item",
        "description" => "Goodwill credit",
        "quantity" => 1,
        "unit_amount" => 500
      }
    ]
  })
```

## Create a credit note

`LatticeStripe.CreditNote.create/3` accepts the same raw params map as preview.

```elixir
{:ok, credit_note} =
  LatticeStripe.CreditNote.create(client, %{
    "invoice" => "in_123",
    "lines" => [
      %{
        "type" => "custom_line_item",
        "description" => "Goodwill credit",
        "quantity" => 1,
        "unit_amount" => 500
      }
    ],
    "memo" => "Applied after support review"
  })
```

## Browse line items

Issued credit notes:

```elixir
{:ok, response} = LatticeStripe.CreditNote.list_line_items(client, credit_note.id)
items = response.data.data
```

Preview line items:

```elixir
{:ok, response} =
  LatticeStripe.CreditNote.list_preview_line_items(client, %{
    "invoice" => "in_123",
    "lines" => [
      %{
        "type" => "invoice_line_item",
        "invoice_line_item" => "il_123",
        "quantity" => 1
      }
    ]
  })

items = response.data.data
```

Use `stream!/3`, `stream_line_items!/4`, or `stream_preview_line_items!/3` when you want
auto-pagination.

## Void a credit note

```elixir
{:ok, voided} = LatticeStripe.CreditNote.void(client, credit_note.id)
```

Voiding is irreversible and only applies to credit notes attached to open invoices.
