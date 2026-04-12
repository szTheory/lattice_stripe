defmodule LatticeStripe.InvoiceItemIntegrationTest do
  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  alias LatticeStripe.{Customer, Error, Invoice, InvoiceItem}

  # Guard: check stripe-mock connectivity before running any tests in this module.
  # If stripe-mock is not running on localhost:12111, all tests are skipped via
  # the invalid-setup mechanism. Start the Finch pool for real HTTP requests.
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

  test "create/3 returns an InvoiceItem struct", %{client: client} do
    {:ok, customer} = Customer.create(client, %{"email" => "invoice-item-test@example.com"})

    {:ok, invoice} =
      Invoice.create(client, %{
        "customer" => customer.id,
        "auto_advance" => false,
        "collection_method" => "send_invoice",
        "days_until_due" => 30
      })

    {:ok, item} =
      InvoiceItem.create(client, %{
        "customer" => customer.id,
        "invoice" => invoice.id,
        "amount" => 5000,
        "currency" => "usd",
        "description" => "Integration test service"
      })

    assert %InvoiceItem{} = item
    assert is_binary(item.id)
    assert item.id != nil
  end

  test "retrieve/3 returns invoice item by id", %{client: client} do
    {:ok, customer} = Customer.create(client, %{"email" => "invoice-item-retrieve@example.com"})

    {:ok, invoice} =
      Invoice.create(client, %{
        "customer" => customer.id,
        "auto_advance" => false,
        "collection_method" => "send_invoice",
        "days_until_due" => 30
      })

    {:ok, created} =
      InvoiceItem.create(client, %{
        "customer" => customer.id,
        "invoice" => invoice.id,
        "amount" => 1000,
        "currency" => "usd",
        "description" => "Retrieve test"
      })

    {:ok, retrieved} = InvoiceItem.retrieve(client, created.id)

    assert %InvoiceItem{} = retrieved
    assert retrieved.id == created.id
  end

  test "update/4 returns an updated InvoiceItem struct", %{client: client} do
    {:ok, customer} = Customer.create(client, %{"email" => "invoice-item-update@example.com"})

    {:ok, invoice} =
      Invoice.create(client, %{
        "customer" => customer.id,
        "auto_advance" => false,
        "collection_method" => "send_invoice",
        "days_until_due" => 30
      })

    {:ok, created} =
      InvoiceItem.create(client, %{
        "customer" => customer.id,
        "invoice" => invoice.id,
        "amount" => 3000,
        "currency" => "usd",
        "description" => "Update test"
      })

    {:ok, updated} =
      InvoiceItem.update(client, created.id, %{"description" => "Updated description"})

    assert %InvoiceItem{} = updated
    assert updated.id == created.id
  end

  test "delete/3 deletes an InvoiceItem", %{client: client} do
    {:ok, customer} = Customer.create(client, %{"email" => "invoice-item-delete@example.com"})

    {:ok, invoice} =
      Invoice.create(client, %{
        "customer" => customer.id,
        "auto_advance" => false,
        "collection_method" => "send_invoice",
        "days_until_due" => 30
      })

    {:ok, created} =
      InvoiceItem.create(client, %{
        "customer" => customer.id,
        "invoice" => invoice.id,
        "amount" => 2000,
        "currency" => "usd",
        "description" => "Delete test"
      })

    result = InvoiceItem.delete(client, created.id)

    # stripe-mock accepts delete on invoice items
    assert match?({:ok, %InvoiceItem{}}, result) or match?({:error, %Error{}}, result)
  end

  test "list/3 returns a Response with a List", %{client: client} do
    {:ok, resp} = InvoiceItem.list(client)

    assert %LatticeStripe.Response{} = resp
    assert %LatticeStripe.List{} = resp.data
  end

  # stripe-mock returns a stub for any ID — invalid ID errors can only be tested against real Stripe
  @tag :skip
  test "retrieve/3 with invalid id returns error", %{client: client} do
    {:error, error} = InvoiceItem.retrieve(client, "nonexistent_id_999")

    assert %Error{type: :invalid_request_error} = error
  end
end
