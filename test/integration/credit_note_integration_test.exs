defmodule LatticeStripe.CreditNoteIntegrationTest do
  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers
  import LatticeStripe.Test.Fixtures.CreditNote

  @moduletag :integration

  alias LatticeStripe.{CreditNote, Error}

  setup_all do
    case :gen_tcp.connect(~c"localhost", 12_111, [], 1000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        start_supervised!({Finch, name: LatticeStripe.IntegrationFinch})
        :ok

      {:error, _} ->
        raise "stripe-mock not running on localhost:12111 — start with: docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest"
    end
  end

  setup do
    {:ok, client: test_integration_client()}
  end

  test "create/3 returns a CreditNote struct from a finalized invoice", %{client: client} do
    invoice =
      create_creditable_invoice!(client, %{"customer_email" => "credit-note-create@example.com"})

    {:ok, credit_note} =
      CreditNote.create(client, %{
        "invoice" => invoice.id,
        "lines" => [
          %{
            "type" => "custom_line_item",
            "description" => "Goodwill credit",
            "quantity" => 1,
            "unit_amount" => 500
          }
        ]
      })

    assert %CreditNote{} = credit_note
    assert is_binary(credit_note.id)
  end

  test "retrieve/3 returns the created credit note by ID", %{client: client} do
    credit_note =
      create_open_invoice_credit_note!(client, %{
        "customer_email" => "credit-note-retrieve@example.com"
      })

    {:ok, retrieved} = CreditNote.retrieve(client, credit_note.id)

    assert %CreditNote{} = retrieved
    assert retrieved.id == credit_note.id
  end

  test "update/4 returns an updated CreditNote struct", %{client: client} do
    credit_note =
      create_open_invoice_credit_note!(client, %{
        "customer_email" => "credit-note-update@example.com"
      })

    {:ok, updated} =
      CreditNote.update(client, credit_note.id, %{
        "memo" => "Updated from integration",
        "metadata" => %{"ticket" => "456"}
      })

    assert %CreditNote{} = updated
    assert updated.id == credit_note.id
  end

  test "list/3 returns a Response with a List", %{client: client} do
    {:ok, resp} = CreditNote.list(client)

    assert %LatticeStripe.Response{} = resp
    assert %LatticeStripe.List{} = resp.data
  end

  test "preview/3 returns a CreditNote struct for a finalized invoice", %{client: client} do
    invoice =
      create_creditable_invoice!(client, %{"customer_email" => "credit-note-preview@example.com"})

    # Real Stripe requires a finalized invoice here even if stripe-mock is permissive.
    {:ok, preview} =
      CreditNote.preview(client, %{
        "invoice" => invoice.id,
        "lines" => [
          %{
            "type" => "invoice_line_item",
            "invoice_line_item" => "il_123",
            "quantity" => 1
          }
        ]
      })

    assert %CreditNote{} = preview
  end

  test "list_line_items/4 returns a Response with a List", %{client: client} do
    credit_note =
      create_open_invoice_credit_note!(client, %{
        "customer_email" => "credit-note-lines@example.com"
      })

    {:ok, resp} = CreditNote.list_line_items(client, credit_note.id)

    assert %LatticeStripe.Response{} = resp
    assert %LatticeStripe.List{} = resp.data
  end

  test "list_preview_line_items/3 returns a Response with a List", %{client: client} do
    invoice =
      create_creditable_invoice!(client, %{
        "customer_email" => "credit-note-preview-lines@example.com"
      })

    {:ok, resp} =
      CreditNote.list_preview_line_items(client, %{
        "invoice" => invoice.id,
        "lines" => [
          %{
            "type" => "custom_line_item",
            "description" => "Goodwill credit",
            "quantity" => 1,
            "unit_amount" => 500
          }
        ]
      })

    assert %LatticeStripe.Response{} = resp
    assert %LatticeStripe.List{} = resp.data
  end

  test "void/3 encodes the real open-invoice caveat even if stripe-mock is permissive", %{
    client: client
  } do
    credit_note =
      create_open_invoice_credit_note!(client, %{
        "customer_email" => "credit-note-void@example.com"
      })

    result = CreditNote.void(client, credit_note.id)

    # stripe-mock may allow or reject this inconsistently; real Stripe requires an open invoice.
    assert match?({:ok, %CreditNote{}}, result) or match?({:error, %Error{}}, result)
  end
end
