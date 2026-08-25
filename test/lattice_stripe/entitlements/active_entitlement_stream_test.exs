defmodule LatticeStripe.Entitlements.ActiveEntitlementStreamTest do
  @moduledoc """
  ENT-02 — the pagination contract for `ActiveEntitlement.stream!/3`.

  This lives in its own file rather than folding into `active_entitlement_test.exs` (D-21).
  Pagination is the real hazard in this phase: Stripe's `limit` defaults to 10, and the
  "read page 1 and stop" bug shipped in five official Stripe SDKs. stripe-mock cannot prove
  pagination — it returns one item per list and ignores `limit`/`starting_after` — so the
  Mox-at-Transport multi-page pattern below is the only place the contract is genuinely
  provable.
  """

  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  alias LatticeStripe.Entitlements.ActiveEntitlement
  alias LatticeStripe.Testing.Fixtures.Entitlements

  setup :verify_on_exit!

  # Test Helpers

  # Raw transport tuple, modelled on test/lattice_stripe/list_test.exs:26-45. The `url` is
  # the canonical list path so `List.build_next_page_request/1` reconstructs the right path.
  defp list_response(items, has_more) do
    {:ok,
     %{
       status: 200,
       headers: [{"request-id", "req_#{System.unique_integer([:positive])}"}],
       body: Jason.encode!(Entitlements.active_entitlement_list_json(items, has_more))
     }}
  end

  defp error_response(status) do
    {:ok,
     %{
       status: status,
       headers: [{"request-id", "req_err_#{System.unique_integer([:positive])}"}],
       body:
         Jason.encode!(%{
           "error" => %{"type" => "api_error", "message" => "Server error", "code" => nil}
         })
     }}
  end

  defp entitlement(id, overrides \\ %{}) do
    Entitlements.active_entitlement_json(Map.merge(%{"id" => id}, overrides))
  end

  defp customer_params, do: %{"customer" => "cus_123"}

  # cursor construction across the page seam

  describe "stream!/3 cursor construction" do
    test "page 2 request uses starting_after from the last id of page 1" do
      LatticeStripe.MockTransport
      |> expect(:request, fn req ->
        refute req.url =~ "starting_after"
        list_response([entitlement("ent_a"), entitlement("ent_b")], true)
      end)
      |> expect(:request, fn req ->
        # The seam is adjacent: the cursor is the LAST id of page 1, so ent_b is emitted
        # once and never twice.
        assert req.url =~ "starting_after=ent_b"
        list_response([entitlement("ent_c")], false)
      end)

      ids =
        test_client()
        |> ActiveEntitlement.stream!(customer_params())
        |> Enum.map(& &1.id)

      assert ids == ["ent_a", "ent_b", "ent_c"]
    end

    # the single highest-value assertion in this phase, and a SECURITY
    # test rather than merely a pagination test. If `base_params` preservation in
    # `LatticeStripe.List.build_next_page_request/1` regresses, page 2 comes back
    # unfiltered and this stream returns the ENTIRE ACCOUNT's entitlements instead of one
    # customer's — a cross-tenant data leak. It is entitlements-specific and is not
    # covered by test/lattice_stripe/list_test.exs. Do not fold it into a generic
    # pagination case or rename it to something generic.
    test "page 2 preserves the customer filter" do
      LatticeStripe.MockTransport
      |> expect(:request, fn req ->
        assert req.url =~ "customer=cus_123"
        list_response([entitlement("ent_a"), entitlement("ent_b")], true)
      end)
      |> expect(:request, fn req ->
        assert req.url =~ "customer=cus_123"
        assert req.url =~ "starting_after=ent_b"
        list_response([entitlement("ent_c")], false)
      end)

      items =
        test_client()
        |> ActiveEntitlement.stream!(customer_params())
        |> Enum.to_list()

      assert length(items) == 3
    end
  end

  # completeness, ordering, and laziness

  describe "stream!/3 enumeration" do
    test "streaming N pages makes exactly N transport calls" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req -> list_response([entitlement("ent_a")], true) end)
      |> expect(:request, fn _req -> list_response([entitlement("ent_b")], true) end)
      |> expect(:request, fn _req -> list_response([entitlement("ent_c")], false) end)

      items =
        test_client()
        |> ActiveEntitlement.stream!(customer_params())
        |> Enum.to_list()

      # `verify_on_exit!` is the call counter — three `expect/3`s, no separate tally.
      assert length(items) == 3
    end

    test "items from every page are emitted in wire order as typed structs" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req ->
        list_response([entitlement("ent_a"), entitlement("ent_b")], true)
      end)
      |> expect(:request, fn _req -> list_response([entitlement("ent_c")], false) end)

      items =
        test_client()
        |> ActiveEntitlement.stream!(customer_params())
        |> Enum.to_list()

      assert [
               %ActiveEntitlement{id: "ent_a"},
               %ActiveEntitlement{id: "ent_b"},
               %ActiveEntitlement{id: "ent_c"}
             ] = items

      ids = Enum.map(items, & &1.id)
      assert ids == Enum.uniq(ids)
    end

    test "Stream.take/2 on a two-page stream fetches only page 1" do
      # A single `expect/3` IS the assertion: an early-terminating consumer never pays for
      # page 2. A second transport call would fail `verify_on_exit!`.
      expect(LatticeStripe.MockTransport, :request, 1, fn _req ->
        list_response([entitlement("ent_a"), entitlement("ent_b")], true)
      end)

      items =
        test_client()
        |> ActiveEntitlement.stream!(customer_params())
        |> Stream.take(1)
        |> Enum.to_list()

      assert [%ActiveEntitlement{id: "ent_a"}] = items
    end

    test "an empty first page yields an empty list in one call" do
      expect(LatticeStripe.MockTransport, :request, 1, fn _req ->
        list_response([], false)
      end)

      assert test_client()
             |> ActiveEntitlement.stream!(customer_params())
             |> Enum.to_list() == []
    end

    test "entitlements sharing a lookup_key keep their relative wire order across the page seam" do
      shared = %{"lookup_key" => "premium_support"}

      LatticeStripe.MockTransport
      |> expect(:request, fn _req ->
        list_response([entitlement("ent_a", shared), entitlement("ent_b", shared)], true)
      end)
      |> expect(:request, fn _req ->
        list_response([entitlement("ent_c", shared)], false)
      end)

      items =
        test_client()
        |> ActiveEntitlement.stream!(customer_params())
        |> Enum.to_list()

      assert Enum.map(items, &{&1.id, &1.lookup_key}) == [
               {"ent_a", "premium_support"},
               {"ent_b", "premium_support"},
               {"ent_c", "premium_support"}
             ]
    end
  end

  # request scoping on pages the caller never constructs

  describe "stream!/3 request scoping on page 2" do
    test "the stripe-account header carries to page 2" do
      # A dropped Connect header would execute the page-2 read against the PLATFORM
      # account rather than the connected account.
      LatticeStripe.MockTransport
      |> expect(:request, fn req ->
        assert {"stripe-account", "acct_connected"} in req.headers
        list_response([entitlement("ent_a")], true)
      end)
      |> expect(:request, fn req ->
        assert {"stripe-account", "acct_connected"} in req.headers
        list_response([entitlement("ent_b")], false)
      end)

      items =
        [stripe_account: "acct_connected"]
        |> test_client()
        |> ActiveEntitlement.stream!(customer_params())
        |> Enum.to_list()

      assert length(items) == 2
    end

    test "no idempotency-key is sent on page 2" do
      LatticeStripe.MockTransport
      |> expect(:request, fn req ->
        assert Enum.any?(req.headers, fn {k, _v} -> k == "idempotency-key" end)
        list_response([entitlement("ent_a")], true)
      end)
      |> expect(:request, fn req ->
        # `LatticeStripe.List` deletes :idempotency_key from _opts when building a page
        # request. Assert the key is absent from the OUTGOING request, not from source.
        refute Enum.any?(req.headers, fn {k, _v} -> k == "idempotency-key" end)
        list_response([entitlement("ent_b")], false)
      end)

      items =
        test_client()
        |> ActiveEntitlement.stream!(customer_params(), idempotency_key: "idem_123")
        |> Enum.to_list()

      assert length(items) == 2
    end
  end

  # prohibition — enumeration is complete or it fails loudly, never partial

  describe "stream!/3 error propagation" do
    test "a 500 on page 2 raises LatticeStripe.Error" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req -> list_response([entitlement("ent_a")], true) end)
      |> expect(:request, fn _req -> error_response(500) end)

      assert_raise LatticeStripe.Error, fn ->
        test_client()
        |> ActiveEntitlement.stream!(customer_params())
        |> Enum.to_list()
      end
    end
  end
end
