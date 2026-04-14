defmodule LatticeStripe.BillingPortal.SessionIntegrationTest do
  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration
  @moduletag :billing_portal

  # ---------------------------------------------------------------------------
  # TEST-05 (portal portion) — Full portal flow against stripe-mock
  #
  # NOT covered here (intentional):
  #   - PORTAL-04 guard matrix — stripe-mock does NOT enforce sub-field
  #     validation (RESEARCH Finding 1); guards live in guards_test.exs.
  #   - RESEARCH Finding 2 (unknown flow type 422) — already covered in unit
  #     tests as a Guards.check_flow_data!/1 case; stripe-mock accepts it as
  #     400, not 422.
  # ---------------------------------------------------------------------------

  alias LatticeStripe.BillingPortal.Session
  alias LatticeStripe.BillingPortal.Session.FlowData

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
    client = test_integration_client()

    {:ok, customer} =
      LatticeStripe.Customer.create(client, %{"email" => "portal_integration@example.com"})

    {:ok, client: client, customer_id: customer.id}
  end

  test "create/3 with customer returns {:ok, %Session{url: url}} with non-empty url",
       %{client: client, customer_id: customer_id} do
    {:ok, session} =
      Session.create(client, %{
        "customer" => customer_id,
        "return_url" => "https://example.com/account"
      })

    assert %Session{} = session
    assert is_binary(session.url)
    assert String.length(session.url) > 0
    assert session.url =~ ~r{^https://}
  end

  test "create/3 populates all 11 PORTAL-05 response fields from stripe-mock",
       %{client: client, customer_id: customer_id} do
    {:ok, session} =
      Session.create(client, %{
        "customer" => customer_id,
        "return_url" => "https://example.com/account"
      })

    # id shape
    assert session.id =~ ~r/^bps_/
    # object type
    assert session.object == "billing_portal.session"
    # customer echoed back
    assert session.customer == customer_id
    # url present and HTTPS
    assert is_binary(session.url) and String.length(session.url) > 0
    # return_url echoed back
    assert session.return_url == "https://example.com/account"
    # created is an integer timestamp
    assert is_integer(session.created)
    # livemode is a boolean
    assert is_boolean(session.livemode)
    # struct fields present (may be nil — stripe-mock fills them with defaults)
    assert Map.has_key?(session, :locale)
    assert Map.has_key?(session, :configuration)
    assert Map.has_key?(session, :on_behalf_of)
    # flow key present (stripe-mock returns all four branch keys)
    assert Map.has_key?(session, :flow)
  end

  test "create/3 decodes flow echo into %FlowData{}",
       %{client: client, customer_id: customer_id} do
    # Note per RESEARCH Finding 5: stripe-mock always returns all four flow
    # branch keys populated regardless of input, so we only assert the struct
    # shape here.
    {:ok, session} =
      Session.create(client, %{
        "customer" => customer_id,
        "return_url" => "https://example.com/account",
        "flow_data" => %{
          "type" => "subscription_cancel",
          "subscription_cancel" => %{"subscription" => "sub_test"}
        }
      })

    assert %FlowData{} = session.flow
    assert is_binary(session.flow.type) or is_nil(session.flow.type)
  end

  test "create/3 with stripe_account: opt threads header through",
       %{client: client, customer_id: customer_id} do
    # PORTAL-06 integration check — stripe-mock accepts any acct_* value
    result =
      Session.create(
        client,
        %{"customer" => customer_id},
        stripe_account: "acct_test"
      )

    assert match?({:ok, %Session{}}, result)
  end

  test "create!/3 bang variant returns unwrapped %Session{}",
       %{client: client, customer_id: customer_id} do
    session =
      Session.create!(client, %{
        "customer" => customer_id,
        "return_url" => "https://example.com/account"
      })

    assert %Session{} = session
    assert is_binary(session.url)
    assert String.length(session.url) > 0
  end
end
