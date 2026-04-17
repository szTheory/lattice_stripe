defmodule LatticeStripe.FileLinkTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  alias LatticeStripe.{File, FileLink, Response}
  alias LatticeStripe.Test.Fixtures

  setup :verify_on_exit!

  describe "from_map/1" do
    test "builds struct from known fields" do
      link = FileLink.from_map(Fixtures.FileLink.basic())
      assert link.id == "link_test123"
      assert link.object == "file_link"
      assert link.expired == false
      assert link.file == "file_test123"
      assert link.metadata == %{}
    end

    test "stores unknown fields in extra" do
      link = FileLink.from_map(Fixtures.FileLink.basic())
      assert link.extra["zzz_forward_compat_field"] == "extra_value"
    end

    test "deserializes expanded file to %File{}" do
      link = FileLink.from_map(Fixtures.FileLink.with_expanded_file())
      assert %File{id: "file_test123", purpose: "dispute_evidence"} = link.file
    end

    test "keeps file as string ID when not expanded" do
      link = FileLink.from_map(Fixtures.FileLink.basic())
      assert link.file == "file_test123"
    end
  end

  describe "create/3" do
    test "sends POST to /v1/file_links and returns {:ok, %FileLink{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/file_links")
        ok_response(Fixtures.FileLink.basic())
      end)

      assert {:ok, %FileLink{id: "link_test123"}} =
               FileLink.create(client, %{"file" => "file_test123"})
    end
  end

  describe "retrieve/3" do
    test "returns {:ok, %FileLink{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/file_links/link_test123")
        ok_response(Fixtures.FileLink.basic())
      end)

      assert {:ok, %FileLink{id: "link_test123"}} =
               FileLink.retrieve(client, "link_test123")
    end
  end

  describe "update/4" do
    test "sends POST to /v1/file_links/:id and returns {:ok, %FileLink{}}" do
      client = test_client()
      updated = Fixtures.FileLink.basic(%{"expires_at" => 1_800_000_000})

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/file_links/link_test123")
        ok_response(updated)
      end)

      assert {:ok, %FileLink{expires_at: 1_800_000_000}} =
               FileLink.update(client, "link_test123", %{"expires_at" => 1_800_000_000})
    end
  end

  describe "list/3" do
    test "returns {:ok, %Response{data: %List{}}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.contains?(req.url, "/v1/file_links")
        ok_response(%{
          "object" => "list",
          "data" => [Fixtures.FileLink.basic()],
          "has_more" => false,
          "url" => "/v1/file_links"
        })
      end)

      assert {:ok, %Response{data: %LatticeStripe.List{data: [%FileLink{}]}}} =
               FileLink.list(client)
    end
  end

  describe "immutability guards" do
    test "delete/3 is not exported (file links expire, not deleted per D-18)" do
      refute function_exported?(LatticeStripe.FileLink, :delete, 3)
    end
  end

  describe "Inspect" do
    test "masks url field" do
      link = FileLink.from_map(Fixtures.FileLink.basic())
      inspected = inspect(link)
      assert inspected =~ "LatticeStripe.FileLink"
      assert inspected =~ "link_test123"
      refute inspected =~ "https://files.stripe.com/links/MDB"
    end
  end
end
