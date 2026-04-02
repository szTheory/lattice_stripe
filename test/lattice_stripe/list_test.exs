defmodule LatticeStripe.ListTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.List

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
  end

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
  end

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

  describe "api_version/0" do
    test "LatticeStripe.api_version/0 returns pinned API version string" do
      assert LatticeStripe.api_version() == "2026-03-25.dahlia"
    end
  end
end
