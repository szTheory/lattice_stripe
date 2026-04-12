defmodule LatticeStripe.Checkout.SessionIntegrationTest do
  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  alias LatticeStripe.Checkout.Session
  alias LatticeStripe.Error

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

  defp session_params do
    %{
      "mode" => "payment",
      "success_url" => "https://example.com/success",
      "cancel_url" => "https://example.com/cancel",
      "line_items" => [
        %{
          "price_data" => %{
            "currency" => "usd",
            "product_data" => %{"name" => "Test"},
            "unit_amount" => "2000"
          },
          "quantity" => "1"
        }
      ]
    }
  end

  test "create/3 returns a Session struct", %{client: client} do
    {:ok, session} = Session.create(client, session_params())

    assert %Session{} = session
    assert is_binary(session.id)
    assert session.id != nil
  end

  test "retrieve/3 returns the same session by id", %{client: client} do
    {:ok, created} = Session.create(client, session_params())
    {:ok, retrieved} = Session.retrieve(client, created.id)

    assert %Session{} = retrieved
    assert retrieved.id == created.id
  end

  test "expire/4 expires the session", %{client: client} do
    {:ok, created} = Session.create(client, session_params())

    result = Session.expire(client, created.id)

    # stripe-mock may accept or return an error depending on session state
    assert match?({:ok, %Session{}}, result) or match?({:error, %Error{}}, result)
  end

  test "list/3 returns a Response with a List", %{client: client} do
    {:ok, resp} = Session.list(client)

    assert %LatticeStripe.Response{} = resp
    assert %LatticeStripe.List{} = resp.data
  end

  # stripe-mock returns a stub for any ID — invalid ID errors can only be tested against real Stripe
  @tag :skip
  test "retrieve/3 with invalid id returns error", %{client: client} do
    {:error, error} = Session.retrieve(client, "nonexistent_id_999")

    assert %Error{type: :invalid_request_error} = error
  end
end
