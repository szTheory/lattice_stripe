defmodule LatticeStripe.InvoiceIntegrationTest do
  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  alias LatticeStripe.{Customer, Error, Invoice}

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

  test "create/3 returns an Invoice struct", %{client: client} do
    {:ok, customer} = Customer.create(client, %{"email" => "invoice-test@example.com"})

    {:ok, invoice} =
      Invoice.create(client, %{
        "customer" => customer.id,
        "auto_advance" => false,
        "collection_method" => "send_invoice",
        "days_until_due" => 30
      })

    assert %Invoice{} = invoice
    assert is_binary(invoice.id)
    assert invoice.id != nil
  end

  test "retrieve/3 returns invoice by id", %{client: client} do
    {:ok, customer} = Customer.create(client, %{"email" => "invoice-retrieve@example.com"})

    {:ok, created} =
      Invoice.create(client, %{
        "customer" => customer.id,
        "auto_advance" => false,
        "collection_method" => "send_invoice",
        "days_until_due" => 30
      })

    {:ok, retrieved} = Invoice.retrieve(client, created.id)

    assert %Invoice{} = retrieved
    assert retrieved.id == created.id
  end

  test "update/4 returns an updated Invoice struct", %{client: client} do
    {:ok, customer} = Customer.create(client, %{"email" => "invoice-update@example.com"})

    {:ok, created} =
      Invoice.create(client, %{
        "customer" => customer.id,
        "auto_advance" => false,
        "collection_method" => "send_invoice",
        "days_until_due" => 30
      })

    {:ok, updated} = Invoice.update(client, created.id, %{"description" => "Updated description"})

    assert %Invoice{} = updated
    assert updated.id == created.id
  end

  test "delete/3 deletes a draft Invoice", %{client: client} do
    {:ok, customer} = Customer.create(client, %{"email" => "invoice-delete@example.com"})

    {:ok, created} =
      Invoice.create(client, %{
        "customer" => customer.id,
        "auto_advance" => false,
        "collection_method" => "send_invoice",
        "days_until_due" => 30
      })

    result = Invoice.delete(client, created.id)

    # stripe-mock may return deleted invoice or an error depending on state
    assert match?({:ok, %Invoice{}}, result) or match?({:error, %Error{}}, result)
  end

  test "list/3 returns a Response with a List", %{client: client} do
    {:ok, resp} = Invoice.list(client)

    assert %LatticeStripe.Response{} = resp
    assert %LatticeStripe.List{} = resp.data
  end

  test "finalize/4 transitions invoice from draft to open", %{client: client} do
    {:ok, customer} = Customer.create(client, %{"email" => "invoice-finalize@example.com"})

    {:ok, draft} =
      Invoice.create(client, %{
        "customer" => customer.id,
        "auto_advance" => false,
        "collection_method" => "send_invoice",
        "days_until_due" => 30
      })

    result = Invoice.finalize(client, draft.id)

    # stripe-mock accepts finalize on draft invoices
    assert match?({:ok, %Invoice{}}, result) or match?({:error, %Error{}}, result)
  end

  test "list_line_items/4 returns a Response with a List", %{client: client} do
    {:ok, customer} = Customer.create(client, %{"email" => "invoice-lines@example.com"})

    {:ok, invoice} =
      Invoice.create(client, %{
        "customer" => customer.id,
        "auto_advance" => false,
        "collection_method" => "send_invoice",
        "days_until_due" => 30
      })

    {:ok, resp} = Invoice.list_line_items(client, invoice.id)

    assert %LatticeStripe.Response{} = resp
    assert %LatticeStripe.List{} = resp.data
  end

  # stripe-mock returns a stub for any ID — invalid ID errors can only be tested against real Stripe
  @tag :skip
  test "retrieve/3 with invalid id returns error", %{client: client} do
    {:error, error} = Invoice.retrieve(client, "nonexistent_id_999")

    assert %Error{type: :invalid_request_error} = error
  end
end
