defmodule LatticeStripe.Entitlements.FeatureTest do
  @moduledoc """
  ENT-04 — the complete `Entitlements.Feature` verb surface.

  Stripe ships `[get, post]` on `/v1/entitlements/features` and `[get, post]` on `/{id}`
  and nothing else (F-06), so create/retrieve/update/list plus `stream!/3` is not a partial
  surface — it is the whole one. The `describe "module surface"` block at the bottom is
  therefore load-bearing in both directions: it pins what ships AND pins the absence of the
  verbs Stripe does not offer.
  """

  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  alias LatticeStripe.Entitlements.Feature
  alias LatticeStripe.Testing.Fixtures.Entitlements

  setup :verify_on_exit!

  @path "/v1/entitlements/features"

  defp feature_list_json(items, has_more \\ false), do: list_json(items, @path, has_more)

  defp create_params, do: %{"lookup_key" => "premium_support", "name" => "Premium Support"}

  # create/3

  describe "Feature.create/3" do
    test "POSTs /v1/entitlements/features and returns a typed struct" do
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, @path)
        assert req.body =~ "lookup_key=premium_support"
        assert req.body =~ "name=Premium+Support"

        ok_response(Entitlements.feature_json())
      end)

      assert {:ok,
              %Feature{
                id: "feat_123",
                object: "entitlements.feature",
                lookup_key: "premium_support",
                name: "Premium Support",
                active: true
              }} = Feature.create(test_client(), create_params())
    end

    # Two calls carrying the same key must send the same header both times, which
    # is what makes a retried create de-duplicate at Stripe instead of creating a second
    # feature. A single `expect/3` with a count of 2 asserts it on BOTH attempts.
    test "sends a stable idempotency-key header on both of two identical create attempts" do
      expect(LatticeStripe.MockTransport, :request, 2, fn req ->
        assert {"idempotency-key", "key_1"} in req.headers
        ok_response(Entitlements.feature_json())
      end)

      client = test_client()

      assert {:ok, %Feature{}} = Feature.create(client, create_params(), idempotency_key: "key_1")
      assert {:ok, %Feature{}} = Feature.create(client, create_params(), idempotency_key: "key_1")
    end
  end

  describe "Feature.create!/3" do
    test "returns the bare struct on success" do
      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Entitlements.feature_json())
      end)

      assert %Feature{id: "feat_123"} = Feature.create!(test_client(), create_params())
    end

    test "raises LatticeStripe.Error when Stripe returns an error payload" do
      expect(LatticeStripe.MockTransport, :request, fn _req -> error_response() end)

      assert_raise LatticeStripe.Error, fn ->
        Feature.create!(test_client(), create_params())
      end
    end
  end

  # both required params are guarded BEFORE any transport call

  describe "Feature.create/3 pre-network required-param guards" do
    # No Mox expectation is set in either test below. `verify_on_exit!` is therefore itself
    # the evidence that the raise happened before the transport was ever reached.

    test "raises ArgumentError naming lookup_key when it is absent, and makes no transport call" do
      assert_raise ArgumentError,
                   "LatticeStripe.Entitlements.Feature.create/3 requires a lookup_key param",
                   fn -> Feature.create(test_client(), %{"name" => "x"}) end
    end

    test "raises ArgumentError naming name when it is absent, and makes no transport call" do
      assert_raise ArgumentError,
                   "LatticeStripe.Entitlements.Feature.create/3 requires a name param",
                   fn -> Feature.create(test_client(), %{"lookup_key" => "x"}) end
    end

    test "guards in wire order — an empty params map names lookup_key first" do
      assert_raise ArgumentError,
                   "LatticeStripe.Entitlements.Feature.create/3 requires a lookup_key param",
                   fn -> Feature.create(test_client(), %{}) end
    end
  end

  # retrieve/3

  describe "Feature.retrieve/3" do
    test "GETs /v1/entitlements/features/{id} and returns a typed struct" do
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "#{@path}/feat_123")

        ok_response(Entitlements.feature_json())
      end)

      assert {:ok, %Feature{id: "feat_123", lookup_key: "premium_support"}} =
               Feature.retrieve(test_client(), "feat_123")
    end
  end

  describe "Feature.retrieve!/3" do
    test "returns the bare struct on success" do
      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Entitlements.feature_json())
      end)

      assert %Feature{id: "feat_123"} = Feature.retrieve!(test_client(), "feat_123")
    end

    test "raises LatticeStripe.Error when Stripe returns an error payload" do
      expect(LatticeStripe.MockTransport, :request, fn _req -> error_response() end)

      assert_raise LatticeStripe.Error, fn ->
        Feature.retrieve!(test_client(), "feat_nope")
      end
    end
  end

  # update/4. Archiving IS update/4 with active: false ; there is no
  # archive verb, so this test is the only proof the archive operation is reachable.

  describe "Feature.update/4" do
    test "POSTs /v1/entitlements/features/{id} with active: false and decodes the archived feature" do
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "#{@path}/feat_123")
        assert req.body =~ "active=false"

        ok_response(Entitlements.feature_json(%{"active" => false}))
      end)

      assert {:ok, %Feature{id: "feat_123", active: false}} =
               Feature.update(test_client(), "feat_123", %{"active" => false})
    end
  end

  describe "Feature.update!/4" do
    test "returns the bare struct on success" do
      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Entitlements.feature_json(%{"name" => "Renamed"}))
      end)

      assert %Feature{name: "Renamed"} =
               Feature.update!(test_client(), "feat_123", %{"name" => "Renamed"})
    end
  end

  # list/3

  describe "Feature.list/3" do
    test "GETs /v1/entitlements/features and returns typed structs" do
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ @path

        ok_response(feature_list_json([Entitlements.feature_json()]))
      end)

      assert {:ok, %LatticeStripe.Response{data: %LatticeStripe.List{} = list}} =
               Feature.list(test_client())

      assert [%Feature{id: "feat_123"}] = list.data
    end

    # the `archived` filter is the caller's only way to see inactive
    # features. If it stopped reaching the wire, a reconciler would silently go back to
    # diffing against a filtered view and report archived features as deletions.
    test "passes the archived filter through to the query string unchanged" do
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.url =~ "archived=true"

        ok_response(feature_list_json([Entitlements.feature_json(%{"active" => false})]))
      end)

      assert {:ok, %LatticeStripe.Response{data: %LatticeStripe.List{data: [%Feature{}]}}} =
               Feature.list(test_client(), %{"archived" => "true"})
    end

    # Stripe defines no unique-lookup retrieval, so the return type is a LIST even
    # when exactly one feature matches. This test is what stops a future contributor
    # "helpfully" unwrapping the singleton and inventing >1-result semantics Stripe does
    # not define.
    test "a lookup_key filter matching exactly one feature still returns a %List{} of one" do
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.url =~ "lookup_key=premium_support"

        ok_response(feature_list_json([Entitlements.feature_json()]))
      end)

      assert {:ok, %LatticeStripe.Response{data: %LatticeStripe.List{} = list}} =
               Feature.list(test_client(), %{"lookup_key" => "premium_support"})

      assert %LatticeStripe.List{} = list
      assert length(list.data) == 1
      assert [%Feature{lookup_key: "premium_support"}] = list.data
    end

    test "an empty page decodes to a typed empty list, not nil and not an error" do
      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(feature_list_json([]))
      end)

      assert {:ok, %LatticeStripe.Response{data: %LatticeStripe.List{} = list}} =
               Feature.list(test_client())

      assert list.data == []
      assert list.has_more == false
    end

    test "two features sharing a name keep their relative wire order" do
      items = [
        Entitlements.feature_json(%{"id" => "feat_a", "lookup_key" => "a"}),
        Entitlements.feature_json(%{"id" => "feat_b", "lookup_key" => "b"})
      ]

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(feature_list_json(items))
      end)

      assert {:ok, %LatticeStripe.Response{data: %LatticeStripe.List{} = list}} =
               Feature.list(test_client())

      assert Enum.map(list.data, &{&1.id, &1.name}) == [
               {"feat_a", "Premium Support"},
               {"feat_b", "Premium Support"}
             ]
    end
  end

  describe "Feature.list!/3" do
    test "returns the response directly" do
      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(feature_list_json([Entitlements.feature_json()]))
      end)

      assert %LatticeStripe.Response{data: %LatticeStripe.List{data: [%Feature{}]}} =
               Feature.list!(test_client())
    end
  end

  # stream!/3. Full pagination mechanics are proven once, for the shared
  # LatticeStripe.List cursor machine, in active_entitlement_stream_test.exs.

  describe "Feature.stream!/3" do
    test "emits typed %Feature{} values over a single page" do
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ @path

        ok_response(feature_list_json([Entitlements.feature_json()]))
      end)

      assert [%Feature{id: "feat_123", lookup_key: "premium_support"}] =
               test_client() |> Feature.stream!() |> Enum.to_list()
    end

    test "carries the archived filter onto every page it fetches" do
      LatticeStripe.MockTransport
      |> expect(:request, fn req ->
        assert req.url =~ "archived=true"
        ok_response(feature_list_json([Entitlements.feature_json(%{"id" => "feat_a"})], true))
      end)
      |> expect(:request, fn req ->
        assert req.url =~ "archived=true"
        assert req.url =~ "starting_after=feat_a"
        ok_response(feature_list_json([Entitlements.feature_json(%{"id" => "feat_b"})], false))
      end)

      ids =
        test_client()
        |> Feature.stream!(%{"archived" => "true"})
        |> Enum.map(& &1.id)

      assert ids == ["feat_a", "feat_b"]
    end
  end

  # from_map/1

  describe "Feature.from_map/1" do
    test "decodes the wire object into a %Feature{}" do
      assert %Feature{
               id: "feat_123",
               object: "entitlements.feature",
               active: true,
               lookup_key: "premium_support",
               name: "Premium Support",
               metadata: %{},
               livemode: false
             } = Feature.from_map(Entitlements.feature_json())
    end

    test "returns nil for nil" do
      assert Feature.from_map(nil) == nil
    end

    test "is idempotent on an already-typed struct" do
      once = Feature.from_map(Entitlements.feature_json())

      assert Feature.from_map(once) == once
    end

    test "captures unknown wire keys in :extra" do
      feature = Feature.from_map(Entitlements.feature_json(%{"future_field" => "surprise"}))

      assert feature.extra == %{"future_field" => "surprise"}
      refute Map.has_key?(Map.from_struct(feature), :future_field)
    end
  end

  # L1 — structural surface lock. With no Dialyzer and documentation-only
  # typespecs, this is the ONLY enforcement of public surface shape.

  describe "module surface" do
    test "exports the complete shipped verb surface" do
      assert function_exported?(Feature, :create, 2)
      assert function_exported?(Feature, :create, 3)
      assert function_exported?(Feature, :create!, 2)
      assert function_exported?(Feature, :create!, 3)
      assert function_exported?(Feature, :retrieve, 2)
      assert function_exported?(Feature, :retrieve, 3)
      assert function_exported?(Feature, :retrieve!, 2)
      assert function_exported?(Feature, :retrieve!, 3)
      assert function_exported?(Feature, :update, 3)
      assert function_exported?(Feature, :update, 4)
      assert function_exported?(Feature, :update!, 3)
      assert function_exported?(Feature, :update!, 4)
      assert function_exported?(Feature, :list, 1)
      assert function_exported?(Feature, :list, 3)
      assert function_exported?(Feature, :list!, 1)
      assert function_exported?(Feature, :list!, 3)
      assert function_exported?(Feature, :stream!, 1)
      assert function_exported?(Feature, :stream!, 3)
      assert function_exported?(Feature, :from_map, 1)
    end

    # Stripe ships no DELETE for features. Locking the *complete* surface — not just
    # the part that exists — is what stops a future contributor adding a 404-producing
    # delete/3 by analogy with every other resource in this library.
    test "does not export a delete verb — Stripe ships no DELETE for features" do
      refute function_exported?(Feature, :delete, 2)
      refute function_exported?(Feature, :delete, 3)
    end

    # archiving is update/4 with active: false. A wrapper would have to be named
    # after the wire field it sets (set_active/4), and the house rule is that explicit
    # verbs mirror explicit Stripe endpoints. Both arities of a defaulted-opts verb are
    # refuted, so a `def archive(client, id, opts \\ [])` cannot slip past this lock.
    test "does not export archive or unarchive — archiving is update/4 with active: false" do
      refute function_exported?(Feature, :archive, 2)
      refute function_exported?(Feature, :archive, 3)
      refute function_exported?(Feature, :unarchive, 2)
      refute function_exported?(Feature, :unarchive, 3)
      refute function_exported?(Feature, :set_active, 3)
      refute function_exported?(Feature, :set_active, 4)
    end

    # Stripe defines no unique-lookup retrieval, so a helper would have to invent
    # 0-result and >1-result semantics. The recipe lives in the moduledoc instead.
    test "does not export a lookup_key retrieval helper" do
      refute function_exported?(Feature, :retrieve_by_lookup_key, 2)
      refute function_exported?(Feature, :retrieve_by_lookup_key, 3)
    end

    test "stream! has no non-bang twin — auto-pagination raises, it does not return tuples" do
      refute function_exported?(Feature, :stream, 1)
      refute function_exported?(Feature, :stream, 2)
      refute function_exported?(Feature, :stream, 3)
    end
  end
end
