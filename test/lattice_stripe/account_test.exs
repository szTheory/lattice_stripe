defmodule LatticeStripe.AccountTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  alias LatticeStripe.{Account, Error, List, Response}

  alias LatticeStripe.Account.{
    BusinessProfile,
    Capability,
    Company,
    Individual,
    Requirements,
    Settings,
    TosAcceptance
  }

  alias LatticeStripe.Test.Fixtures.Account, as: Fixtures

  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # from_map/1
  # ---------------------------------------------------------------------------

  describe "from_map/1" do
    test "returns nil when given nil" do
      assert Account.from_map(nil) == nil
    end

    test "maps basic known fields" do
      account = Account.from_map(Fixtures.basic())

      assert account.id == "acct_test1234567890"
      assert account.object == "account"
      assert account.business_type == "company"
      assert account.charges_enabled == true
      assert account.livemode == false
      assert account.country == "US"
    end

    test "casts business_profile into %BusinessProfile{}" do
      account = Account.from_map(Fixtures.basic())

      assert %BusinessProfile{name: "Acme Corp", support_email: "support@acme.test"} =
               account.business_profile

      # forward-compat field captured in extra
      assert account.business_profile.extra["zzz_forward_compat_field"] ==
               "extra_value_in_business_profile"
    end

    test "casts requirements into %Requirements{}" do
      account = Account.from_map(Fixtures.basic())

      assert %Requirements{currently_due: ["business_profile.mcc", "business_profile.url"]} =
               account.requirements
    end

    test "casts future_requirements into %Requirements{} — same struct module as requirements" do
      account = Account.from_map(Fixtures.basic())

      assert %Requirements{currently_due: []} = account.future_requirements
      # Both fields are the same struct module — D-01 reuse
      assert account.requirements.__struct__ == Requirements
      assert account.future_requirements.__struct__ == Requirements
    end

    test "casts tos_acceptance into %TosAcceptance{}" do
      account = Account.from_map(Fixtures.basic())

      assert %TosAcceptance{date: 1_700_000_000, service_agreement: "full"} =
               account.tos_acceptance
    end

    test "inspect of tos_acceptance does NOT leak ip or user_agent" do
      account = Account.from_map(Fixtures.basic())
      inspected = inspect(account.tos_acceptance)

      refute inspected =~ "203.0.113.42"
      refute inspected =~ "Mozilla/5.0 Test"
    end

    test "casts company into %Company{}" do
      account = Account.from_map(Fixtures.basic())

      assert %Company{name: "Acme Corp LLC", directors_provided: true, owners_provided: true} =
               account.company
    end

    test "inspect of company does NOT leak tax_id or phone" do
      account = Account.from_map(Fixtures.basic())
      inspected = inspect(account.company)

      refute inspected =~ "00-0000000"
      refute inspected =~ "+15555550101"
    end

    test "individual is nil for company-type accounts" do
      account = Account.from_map(Fixtures.basic())

      assert account.individual == nil
    end

    test "casts individual into %Individual{} when present" do
      fixture_with_individual =
        Fixtures.basic(%{
          "business_type" => "individual",
          "individual" => %{
            "first_name" => "Jane",
            "last_name" => "Doe",
            "email" => "jane@example.test"
          }
        })

      account = Account.from_map(fixture_with_individual)

      assert %Individual{} = account.individual
    end

    test "casts settings into %Settings{}" do
      account = Account.from_map(Fixtures.basic())

      assert %Settings{} = account.settings
    end

    test "casts capabilities into a map of string keys to %Capability{}" do
      account = Account.from_map(Fixtures.basic())

      assert %{
               "card_payments" => card_pay,
               "transfers" => transfers,
               "us_bank_account_payments" => us_bank
             } = account.capabilities

      assert %Capability{status: :active, requested: true} = card_pay
      assert %Capability{status: :pending, requested: true} = transfers
      assert %Capability{status: :unrequested, requested: false} = us_bank
    end

    test "Capability.status_atom/1 returns correct atom for capabilities" do
      account = Account.from_map(Fixtures.basic())

      assert Capability.status_atom(account.capabilities["card_payments"]) == :active
      assert Capability.status_atom(account.capabilities["transfers"]) == :pending

      assert Capability.status_atom(account.capabilities["us_bank_account_payments"]) ==
               :unrequested
    end

    test "capabilities is nil when not present in map" do
      account = Account.from_map(Map.delete(Fixtures.basic(), "capabilities"))

      assert account.capabilities == nil
    end

    test "unknown top-level fields land in :extra" do
      account = Account.from_map(Fixtures.basic())

      assert account.extra == %{"zzz_forward_compat_field" => "extra_value_at_top_level"}
    end

    test "from_map handles deleted stub shape gracefully" do
      account = Account.from_map(Fixtures.deleted())

      assert account.id == "acct_test1234567890"
      assert account.extra["deleted"] == true
    end
  end

  # ---------------------------------------------------------------------------
  # create/3
  # ---------------------------------------------------------------------------

  describe "create/3" do
    test "sends POST /v1/accounts and returns {:ok, %Account{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/accounts")
        ok_response(Fixtures.basic())
      end)

      assert {:ok, %Account{id: "acct_test1234567890"}} =
               Account.create(client, %{"type" => "custom", "country" => "US"})
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{type: :invalid_request_error}} = Account.create(client, %{})
    end

    test "create!/3 returns %Account{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Fixtures.basic())
      end)

      assert %Account{id: "acct_test1234567890"} =
               Account.create!(client, %{"type" => "custom"})
    end

    test "create!/3 raises on error" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn -> Account.create!(client, %{}) end
    end

    test "forwards opts[:idempotency_key] to Request opts" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert Enum.any?(req.headers, fn {k, v} ->
                 String.downcase(k) == "idempotency-key" and v == "test-ik-create"
               end)

        ok_response(Fixtures.basic())
      end)

      assert {:ok, %Account{}} =
               Account.create(client, %{"type" => "custom"}, idempotency_key: "test-ik-create")
    end
  end

  # ---------------------------------------------------------------------------
  # retrieve/3
  # ---------------------------------------------------------------------------

  describe "retrieve/3" do
    test "sends GET /v1/accounts/:id and returns {:ok, %Account{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/accounts/acct_test1234567890")
        ok_response(Fixtures.basic())
      end)

      assert {:ok, %Account{id: "acct_test1234567890"}} =
               Account.retrieve(client, "acct_test1234567890")
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = Account.retrieve(client, "acct_test1234567890")
    end

    test "retrieve!/3 returns %Account{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Fixtures.basic())
      end)

      assert %Account{id: "acct_test1234567890"} =
               Account.retrieve!(client, "acct_test1234567890")
    end

    test "retrieve!/3 raises on error" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn -> Account.retrieve!(client, "acct_test1234567890") end
    end
  end

  # ---------------------------------------------------------------------------
  # update/4
  # ---------------------------------------------------------------------------

  describe "update/4" do
    test "sends POST /v1/accounts/:id and returns {:ok, %Account{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/accounts/acct_test1234567890")
        ok_response(Fixtures.basic())
      end)

      assert {:ok, %Account{}} =
               Account.update(client, "acct_test1234567890", %{"email" => "new@example.test"})
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} =
               Account.update(client, "acct_test1234567890", %{"email" => "x@x.test"})
    end

    test "update!/4 returns %Account{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Fixtures.basic())
      end)

      assert %Account{} =
               Account.update!(client, "acct_test1234567890", %{"email" => "new@example.test"})
    end

    test "update!/4 raises on error" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn ->
        Account.update!(client, "acct_test1234567890", %{"email" => "x@x.test"})
      end
    end

    test "D-04b: capabilities nested map update idiom — update/4 passes capabilities as params" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert req.body =~ "card_payments"
        ok_response(Fixtures.basic())
      end)

      assert {:ok, %Account{}} =
               Account.update(client, "acct_test1234567890", %{
                 "capabilities" => %{
                   "card_payments" => %{"requested" => true},
                   "transfers" => %{"requested" => true}
                 }
               })
    end
  end

  # ---------------------------------------------------------------------------
  # delete/3
  # ---------------------------------------------------------------------------

  describe "delete/3" do
    test "sends DELETE /v1/accounts/:id and returns {:ok, %Account{extra: %{deleted: true}}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :delete
        assert String.ends_with?(req.url, "/v1/accounts/acct_test1234567890")
        ok_response(Fixtures.deleted())
      end)

      assert {:ok, %Account{id: "acct_test1234567890"} = acct} =
               Account.delete(client, "acct_test1234567890")

      assert acct.extra["deleted"] == true
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = Account.delete(client, "acct_test1234567890")
    end

    test "delete!/3 returns %Account{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Fixtures.deleted())
      end)

      assert %Account{id: "acct_test1234567890"} =
               Account.delete!(client, "acct_test1234567890")
    end

    test "delete!/3 raises on error" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn -> Account.delete!(client, "acct_test1234567890") end
    end
  end

  # ---------------------------------------------------------------------------
  # reject/4
  # ---------------------------------------------------------------------------

  describe "reject/4" do
    test "sends POST /v1/accounts/:id/reject with reason=fraud" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/accounts/acct_test1234567890/reject")
        assert req.body =~ "reason=fraud"
        ok_response(Fixtures.basic())
      end)

      assert {:ok, %Account{}} = Account.reject(client, "acct_test1234567890", :fraud)
    end

    test "sends POST /v1/accounts/:id/reject with reason=terms_of_service" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.body =~ "reason=terms_of_service"
        ok_response(Fixtures.basic())
      end)

      assert {:ok, %Account{}} =
               Account.reject(client, "acct_test1234567890", :terms_of_service)
    end

    test "sends POST /v1/accounts/:id/reject with reason=other" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.body =~ "reason=other"
        ok_response(Fixtures.basic())
      end)

      assert {:ok, %Account{}} = Account.reject(client, "acct_test1234567890", :other)
    end

    test "raises FunctionClauseError for invalid reason atom" do
      client = test_client()

      assert_raise FunctionClauseError, fn ->
        Account.reject(client, "acct_test1234567890", :wrong_atom)
      end
    end

    test "raises FunctionClauseError for typo atom :fruad" do
      client = test_client()

      assert_raise FunctionClauseError, fn ->
        Account.reject(client, "acct_test1234567890", :fruad)
      end
    end

    test "reject!/4 returns %Account{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Fixtures.basic())
      end)

      assert %Account{} = Account.reject!(client, "acct_test1234567890", :fraud)
    end

    test "reject!/4 raises Error on failure" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn ->
        Account.reject!(client, "acct_test1234567890", :fraud)
      end
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = Account.reject(client, "acct_test1234567890", :fraud)
    end
  end

  # ---------------------------------------------------------------------------
  # list/3
  # ---------------------------------------------------------------------------

  describe "list/3" do
    test "sends GET /v1/accounts and returns {:ok, %Response{data: %List{data: [%Account{}]}}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/accounts")
        ok_response(list_json([Fixtures.basic()], "/v1/accounts"))
      end)

      assert {:ok, %Response{data: %List{data: [%Account{id: "acct_test1234567890"}]}}} =
               Account.list(client)
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = Account.list(client)
    end

    test "list!/3 returns %Response{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(list_json([Fixtures.basic()], "/v1/accounts"))
      end)

      assert %Response{data: %List{data: [%Account{}]}} = Account.list!(client)
    end

    test "list!/3 raises on error" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn -> Account.list!(client) end
    end
  end

  # ---------------------------------------------------------------------------
  # stream!/3
  # ---------------------------------------------------------------------------

  describe "stream!/3" do
    test "yields %Account{} structs from auto-paginated stream" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(list_json([Fixtures.basic()], "/v1/accounts"))
      end)

      assert [%Account{id: "acct_test1234567890"}] =
               Account.stream!(client) |> Enum.take(5)
    end

    test "stream!/3 raises Error when page fetch fails" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn ->
        Account.stream!(client) |> Enum.take(5)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # D-04b: request_capability/4 is rejected as fake ergonomics
  # ---------------------------------------------------------------------------

  describe "D-04b: request_capability/4 is rejected as fake ergonomics" do
    test "LatticeStripe.Account does NOT export request_capability/4 per Phase 17 D-04b" do
      refute function_exported?(LatticeStripe.Account, :request_capability, 4)
      refute function_exported?(LatticeStripe.Account, :request_capability, 3)
    end
  end

  # ---------------------------------------------------------------------------
  # Inspect PII smoke test
  # ---------------------------------------------------------------------------

  describe "Inspect PII smoke test" do
    test "inspect(%Account{}) does NOT leak PII from any nested struct" do
      account = Account.from_map(Fixtures.basic())
      inspected = inspect(account)

      # TosAcceptance PII fields
      refute inspected =~ "203.0.113.42"
      refute inspected =~ "Mozilla/5.0 Test"

      # Company PII fields
      refute inspected =~ "00-0000000"
    end
  end
end
