defmodule LatticeStripe.ListTest do
  use ExUnit.Case, async: true

  import Mox

  alias LatticeStripe.{Client, List, Request}

  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # Test Helpers
  # ---------------------------------------------------------------------------

  defp test_client(overrides \\ []) do
    defaults = [
      api_key: "sk_test_123",
      finch: :test_finch,
      transport: LatticeStripe.MockTransport,
      telemetry_enabled: false,
      max_retries: 0
    ]

    Client.new!(Keyword.merge(defaults, overrides))
  end

  defp list_response(items, has_more, opts \\ []) do
    url = Keyword.get(opts, :url, "/v1/customers")
    object = Keyword.get(opts, :object, "list")
    next_page = Keyword.get(opts, :next_page)

    body = %{
      "object" => object,
      "data" => items,
      "has_more" => has_more,
      "url" => url
    }

    body = if next_page, do: Map.put(body, "next_page", next_page), else: body

    {:ok,
     %{
       status: 200,
       headers: [{"request-id", "req_#{System.unique_integer([:positive])}"}],
       body: Jason.encode!(body)
     }}
  end

  defp error_response(status) do
    body = %{
      "error" => %{
        "type" => "api_error",
        "message" => "Server error",
        "code" => nil
      }
    }

    {:ok,
     %{
       status: status,
       headers: [{"request-id", "req_err_#{System.unique_integer([:positive])}"}],
       body: Jason.encode!(body)
     }}
  end

  defp customers_req(params \\ %{}) do
    %Request{method: :get, path: "/v1/customers", params: params}
  end

  # ---------------------------------------------------------------------------
  # Struct
  # ---------------------------------------------------------------------------

  describe "struct" do
    test "has correct default fields" do
      list = %List{}
      assert list.data == []
      assert list.has_more == false
      assert list.url == nil
      assert list.total_count == nil
      assert list.next_page == nil
      assert list.object == "list"
      assert list.extra == %{}
      assert list._params == %{}
      assert list._opts == []
    end

    test "can be constructed with values" do
      list = %List{
        data: [%{"id" => "cus_1"}],
        has_more: true,
        url: "/v1/customers",
        total_count: 100,
        object: "list"
      }

      assert length(list.data) == 1
      assert list.has_more == true
      assert list.url == "/v1/customers"
      assert list.total_count == 100
    end

    test "has _first_id and _last_id fields defaulting to nil" do
      list = %List{}
      assert list._first_id == nil
      assert list._last_id == nil
    end
  end

  # ---------------------------------------------------------------------------
  # from_json/1 - cursor-based list
  # ---------------------------------------------------------------------------

  describe "from_json/1 - cursor-based list" do
    test "populates data, has_more, url, and object" do
      json = %{
        "object" => "list",
        "data" => [%{"id" => "cus_1", "object" => "customer"}],
        "has_more" => true,
        "url" => "/v1/customers"
      }

      list = List.from_json(json)

      assert list.object == "list"
      assert list.data == [%{"id" => "cus_1", "object" => "customer"}]
      assert list.has_more == true
      assert list.url == "/v1/customers"
    end

    test "defaults data to [] when missing" do
      json = %{"object" => "list", "has_more" => false}
      list = List.from_json(json)
      assert list.data == []
    end

    test "defaults has_more to false when missing" do
      json = %{"object" => "list", "data" => []}
      list = List.from_json(json)
      assert list.has_more == false
    end

    test "populates total_count when present" do
      json = %{"object" => "list", "data" => [], "has_more" => false, "total_count" => 42}
      list = List.from_json(json)
      assert list.total_count == 42
    end

    test "total_count is nil when not present" do
      json = %{"object" => "list", "data" => [], "has_more" => false}
      list = List.from_json(json)
      assert list.total_count == nil
    end

    test "puts unknown keys into extra map" do
      json = %{
        "object" => "list",
        "data" => [],
        "has_more" => false,
        "custom_field" => "custom_value",
        "another_extra" => 42
      }

      list = List.from_json(json)

      assert list.extra == %{"custom_field" => "custom_value", "another_extra" => 42}
    end

    test "extra is empty map when no unknown keys" do
      json = %{"object" => "list", "data" => [], "has_more" => false}
      list = List.from_json(json)
      assert list.extra == %{}
    end

    test "populates _first_id and _last_id from data items" do
      json = %{
        "object" => "list",
        "data" => [%{"id" => "cus_1"}, %{"id" => "cus_2"}, %{"id" => "cus_3"}],
        "has_more" => false
      }

      list = List.from_json(json)

      assert list._first_id == "cus_1"
      assert list._last_id == "cus_3"
    end

    test "_first_id and _last_id are nil for empty data" do
      json = %{"object" => "list", "data" => [], "has_more" => false}
      list = List.from_json(json)

      assert list._first_id == nil
      assert list._last_id == nil
    end

    test "_first_id and _last_id equal the same id for single-item list" do
      json = %{
        "object" => "list",
        "data" => [%{"id" => "cus_only"}],
        "has_more" => false
      }

      list = List.from_json(json)

      assert list._first_id == "cus_only"
      assert list._last_id == "cus_only"
    end

    test "_first_id and _last_id are nil when items have no id" do
      json = %{
        "object" => "list",
        "data" => [%{"name" => "no id here"}],
        "has_more" => false
      }

      list = List.from_json(json)

      assert list._first_id == nil
      assert list._last_id == nil
    end
  end

  # ---------------------------------------------------------------------------
  # from_json/1 - search result
  # ---------------------------------------------------------------------------

  describe "from_json/1 - search result" do
    test "populates next_page and object: search_result" do
      json = %{
        "object" => "search_result",
        "data" => [%{"id" => "cus_1"}],
        "has_more" => true,
        "url" => "/v1/customers/search",
        "next_page" => "page_token_123"
      }

      list = List.from_json(json)

      assert list.object == "search_result"
      assert list.next_page == "page_token_123"
      assert list.has_more == true
    end

    test "next_page is nil when not present" do
      json = %{"object" => "list", "data" => [], "has_more" => false}
      list = List.from_json(json)
      assert list.next_page == nil
    end
  end

  # ---------------------------------------------------------------------------
  # from_json/3 - with params and opts
  # ---------------------------------------------------------------------------

  describe "from_json/3 - with params and opts" do
    test "stores params in _params field" do
      json = %{"object" => "list", "data" => [], "has_more" => false}
      params = %{"limit" => 10, "expand" => ["data.default_source"]}
      list = List.from_json(json, params)

      assert list._params == params
    end

    test "stores opts in _opts field" do
      json = %{"object" => "list", "data" => [], "has_more" => false}
      opts = [stripe_account: "acct_123", timeout: 5000]
      list = List.from_json(json, %{}, opts)

      assert list._opts == opts
    end

    test "defaults params to empty map and opts to [] when not provided" do
      json = %{"object" => "list", "data" => [], "has_more" => false}
      list = List.from_json(json)

      assert list._params == %{}
      assert list._opts == []
    end
  end

  # ---------------------------------------------------------------------------
  # Inspect protocol
  # ---------------------------------------------------------------------------

  describe "Inspect protocol" do
    test "shows item count for non-empty list" do
      list = %List{data: [%{"id" => "cus_1"}, %{"id" => "cus_2"}]}
      inspected = inspect(list)
      assert inspected =~ "2 item(s)"
    end

    test "shows 0 items for empty list" do
      list = %List{}
      inspected = inspect(list)
      assert inspected =~ "0 item(s)"
    end

    test "shows first item id/object without PII" do
      list = %List{
        data: [%{"id" => "cus_123", "object" => "customer", "email" => "pii@example.com"}]
      }

      inspected = inspect(list)

      assert inspected =~ "cus_123"
      assert inspected =~ "customer"
      refute inspected =~ "pii@example.com"
    end

    test "hides all item details in data field" do
      list = %List{
        data: [%{"id" => "cus_1", "card_number" => "4242424242424242"}]
      }

      inspected = inspect(list)

      refute inspected =~ "4242424242424242"
    end

    test "shows has_more, url, and object" do
      list = %List{
        data: [],
        has_more: true,
        url: "/v1/customers",
        object: "list"
      }

      inspected = inspect(list)

      assert inspected =~ "true"
      assert inspected =~ "/v1/customers"
    end
  end

  # ---------------------------------------------------------------------------
  # api_version/0
  # ---------------------------------------------------------------------------

  describe "api_version/0" do
    test "LatticeStripe.api_version/0 returns pinned API version string" do
      assert LatticeStripe.api_version() == "2026-03-25.dahlia"
    end
  end

  # ---------------------------------------------------------------------------
  # stream!/2 - from-scratch pagination
  # ---------------------------------------------------------------------------

  describe "stream!/2 - single-page list" do
    test "emits all items and halts when has_more is false" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req ->
        list_response([%{"id" => "cus_1"}, %{"id" => "cus_2"}], false)
      end)

      client = test_client()
      req = customers_req()

      items =
        client
        |> List.stream!(req)
        |> Enum.to_list()

      assert items == [%{"id" => "cus_1"}, %{"id" => "cus_2"}]
    end

    test "halts immediately on empty exhausted list (data: [], has_more: false)" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req ->
        list_response([], false)
      end)

      client = test_client()
      req = customers_req()

      items =
        client
        |> List.stream!(req)
        |> Enum.to_list()

      assert items == []
    end
  end

  describe "stream!/2 - multi-page list" do
    test "fetches page 2 when page 1 has_more: true and emits items from both pages" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req ->
        list_response([%{"id" => "cus_1"}, %{"id" => "cus_2"}], true)
      end)
      |> expect(:request, fn _req ->
        list_response([%{"id" => "cus_3"}], false)
      end)

      client = test_client()
      req = customers_req()

      items =
        client
        |> List.stream!(req)
        |> Enum.to_list()

      assert items == [%{"id" => "cus_1"}, %{"id" => "cus_2"}, %{"id" => "cus_3"}]
    end

    test "3-page list makes exactly 3 transport calls" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req ->
        list_response([%{"id" => "cus_1"}], true)
      end)
      |> expect(:request, fn _req ->
        list_response([%{"id" => "cus_2"}], true)
      end)
      |> expect(:request, fn _req ->
        list_response([%{"id" => "cus_3"}], false)
      end)

      client = test_client()
      req = customers_req()

      items =
        client
        |> List.stream!(req)
        |> Enum.to_list()

      assert length(items) == 3
      # Mox verify_on_exit! ensures exactly 3 calls were made
    end

    test "page 2 request uses starting_after cursor from last item of page 1" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req ->
        list_response([%{"id" => "cus_a"}, %{"id" => "cus_b"}], true)
      end)
      |> expect(:request, fn req ->
        assert req.url =~ "starting_after=cus_b"
        list_response([%{"id" => "cus_c"}], false)
      end)

      client = test_client()
      req = customers_req()

      items =
        client
        |> List.stream!(req)
        |> Enum.to_list()

      assert length(items) == 3
    end
  end

  describe "stream!/2 - laziness" do
    test "Stream.take(stream, 1) on a multi-page list only fetches page 1" do
      # Only 1 transport call should happen — Mox enforces the count
      LatticeStripe.MockTransport
      |> expect(:request, 1, fn _req ->
        list_response([%{"id" => "cus_1"}, %{"id" => "cus_2"}], true)
      end)

      client = test_client()
      req = customers_req()

      items =
        client
        |> List.stream!(req)
        |> Stream.take(1)
        |> Enum.to_list()

      assert items == [%{"id" => "cus_1"}]
    end

    test "composes with Enum.map to transform items" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req ->
        list_response([%{"id" => "cus_1"}, %{"id" => "cus_2"}], false)
      end)

      client = test_client()
      req = customers_req()

      ids =
        client
        |> List.stream!(req)
        |> Enum.map(& &1["id"])

      assert ids == ["cus_1", "cus_2"]
    end

    test "composes with Stream.filter to filter items across pages" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req ->
        list_response(
          [%{"id" => "cus_1", "active" => true}, %{"id" => "cus_2", "active" => false}],
          true
        )
      end)
      |> expect(:request, fn _req ->
        list_response([%{"id" => "cus_3", "active" => true}], false)
      end)

      client = test_client()
      req = customers_req()

      active_ids =
        client
        |> List.stream!(req)
        |> Stream.filter(& &1["active"])
        |> Enum.map(& &1["id"])

      assert active_ids == ["cus_1", "cus_3"]
    end
  end

  describe "stream!/2 - error handling" do
    test "raises LatticeStripe.Error when a page fetch returns an error" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req ->
        list_response([%{"id" => "cus_1"}], true)
      end)
      |> expect(:request, fn _req ->
        error_response(500)
      end)

      client = test_client()
      req = customers_req()

      assert_raise LatticeStripe.Error, fn ->
        client
        |> List.stream!(req)
        |> Enum.to_list()
      end
    end
  end

  describe "stream!/2 - backward pagination" do
    test "uses first item ID as cursor when ending_before param is present" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req ->
        list_response([%{"id" => "cus_b"}, %{"id" => "cus_a"}], true)
      end)
      |> expect(:request, fn req ->
        assert req.url =~ "ending_before=cus_b"
        list_response([%{"id" => "cus_d"}, %{"id" => "cus_c"}], false)
      end)

      client = test_client()
      req = %Request{method: :get, path: "/v1/customers", params: %{"ending_before" => "cus_z"}}

      items =
        client
        |> List.stream!(req)
        |> Enum.to_list()

      assert length(items) == 4
    end
  end

  describe "stream!/2 - search pagination" do
    test "uses page token instead of starting_after for search_result responses" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req ->
        list_response(
          [%{"id" => "cus_1"}],
          true,
          object: "search_result",
          next_page: "token_abc"
        )
      end)
      |> expect(:request, fn req ->
        assert req.url =~ "page=token_abc"
        refute req.url =~ "starting_after"

        list_response(
          [%{"id" => "cus_2"}],
          false,
          object: "search_result"
        )
      end)

      client = test_client()

      req = %Request{
        method: :get,
        path: "/v1/customers/search",
        params: %{"query" => "email:test@example.com"}
      }

      items =
        client
        |> List.stream!(req)
        |> Enum.to_list()

      assert items == [%{"id" => "cus_1"}, %{"id" => "cus_2"}]
    end

    test "multi-page search_result fetches correctly using page tokens" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req ->
        list_response([%{"id" => "cus_1"}], true, object: "search_result", next_page: "tok_1")
      end)
      |> expect(:request, fn req ->
        assert req.url =~ "page=tok_1"
        list_response([%{"id" => "cus_2"}], true, object: "search_result", next_page: "tok_2")
      end)
      |> expect(:request, fn req ->
        assert req.url =~ "page=tok_2"
        list_response([%{"id" => "cus_3"}], false, object: "search_result")
      end)

      client = test_client()

      req = %Request{
        method: :get,
        path: "/v1/customers/search",
        params: %{"query" => "email:test"}
      }

      items =
        client
        |> List.stream!(req)
        |> Enum.to_list()

      assert items == [%{"id" => "cus_1"}, %{"id" => "cus_2"}, %{"id" => "cus_3"}]
    end
  end

  describe "stream!/2 - opts forwarding (D-31)" do
    test "carries expand, stripe_account, stripe_version forward across page fetches" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req ->
        list_response([%{"id" => "cus_1"}], true)
      end)
      |> expect(:request, fn req ->
        # Verify opts-derived headers appear on page 2 request
        headers = req.headers

        stripe_account =
          Enum.find_value(headers, fn {k, v} -> if k == "stripe-account", do: v end)

        stripe_version =
          Enum.find_value(headers, fn {k, v} -> if k == "stripe-version", do: v end)

        assert stripe_account == "acct_connect_123"
        assert stripe_version == "2024-01-01.beta"

        list_response([%{"id" => "cus_2"}], false)
      end)

      client = test_client()

      req = %Request{
        method: :get,
        path: "/v1/customers",
        params: %{},
        opts: [stripe_account: "acct_connect_123", stripe_version: "2024-01-01.beta"]
      }

      items =
        client
        |> List.stream!(req)
        |> Enum.to_list()

      assert length(items) == 2
    end

    test "idempotency_key is NOT forwarded to page fetches" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req ->
        list_response([%{"id" => "cus_1"}], true)
      end)
      |> expect(:request, fn req ->
        # Verify no idempotency-key header on page 2 (GET requests don't need it)
        idempotency_header =
          Enum.find(req.headers, fn {k, _v} -> k == "idempotency-key" end)

        assert idempotency_header == nil

        list_response([%{"id" => "cus_2"}], false)
      end)

      client = test_client()

      req = %Request{
        method: :get,
        path: "/v1/customers",
        params: %{},
        opts: [idempotency_key: "idk_should_not_forward"]
      }

      items =
        client
        |> List.stream!(req)
        |> Enum.to_list()

      assert length(items) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # stream/2 - from-existing-list
  # ---------------------------------------------------------------------------

  describe "stream/2 - from-existing-list" do
    test "emits items and halts when has_more is false (no API call)" do
      # No transport expect — Mox will fail if any call is made
      client = test_client()

      list = %List{
        data: [%{"id" => "cus_1"}, %{"id" => "cus_2"}],
        has_more: false,
        url: "/v1/customers",
        object: "list",
        _params: %{},
        _opts: []
      }

      items =
        list
        |> List.stream(client)
        |> Enum.to_list()

      assert items == [%{"id" => "cus_1"}, %{"id" => "cus_2"}]
    end

    test "re-emits first page items then fetches and emits page 2 when has_more: true" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req ->
        list_response([%{"id" => "cus_3"}, %{"id" => "cus_4"}], false)
      end)

      client = test_client()

      list = %List{
        data: [%{"id" => "cus_1"}, %{"id" => "cus_2"}],
        has_more: true,
        url: "/v1/customers",
        object: "list",
        _params: %{},
        _opts: [],
        _first_id: "cus_1",
        _last_id: "cus_2"
      }

      items =
        list
        |> List.stream(client)
        |> Enum.to_list()

      assert items == [
               %{"id" => "cus_1"},
               %{"id" => "cus_2"},
               %{"id" => "cus_3"},
               %{"id" => "cus_4"}
             ]
    end

    test "empty exhausted list (data: [], has_more: false) emits nothing and halts with no API call" do
      # No transport expect — Mox will fail if any call is made
      client = test_client()

      list = %List{
        data: [],
        has_more: false,
        url: "/v1/customers",
        object: "list",
        _params: %{},
        _opts: []
      }

      items =
        list
        |> List.stream(client)
        |> Enum.to_list()

      assert items == []
    end
  end
end
