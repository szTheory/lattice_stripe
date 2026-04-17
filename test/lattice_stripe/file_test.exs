defmodule LatticeStripe.FileTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  alias LatticeStripe.{Error, File, FileLink, Response}
  alias LatticeStripe.Test.Fixtures

  setup :verify_on_exit!

  describe "from_map/1" do
    test "builds struct from known fields" do
      file = File.from_map(Fixtures.File.basic())
      assert file.id == "file_test123"
      assert file.object == "file"
      assert file.purpose == "dispute_evidence"
      assert file.size == 1024
      assert file.filename == "evidence.pdf"
      assert file.type == "pdf"
      assert file.url == "https://files.stripe.com/v1/files/file_test123/contents"
    end

    test "stores unknown fields in extra" do
      file = File.from_map(Fixtures.File.basic())
      assert file.extra["zzz_forward_compat_field"] == "extra_value"
    end

    test "parses nested links as %List{data: [%FileLink{}, ...]}" do
      file = File.from_map(Fixtures.File.with_links())
      assert %LatticeStripe.List{} = file.links
      assert [%FileLink{id: "link_test456"}] = file.links.data
    end

    test "handles nil links" do
      file = File.from_map(Fixtures.File.basic(%{"links" => nil}))
      assert is_nil(file.links)
    end
  end

  describe "create/3" do
    test "sends upload and returns {:ok, %File{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.contains?(req.url, "/v1/files")
        ok_response(Fixtures.File.basic())
      end)

      assert {:ok, %File{id: "file_test123", purpose: "dispute_evidence"}} =
               File.create(client, %{"file" => "binary-data", "purpose" => "dispute_evidence"})
    end

    test "returns {:error, %Error{}} on failure" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} =
               File.create(client, %{"file" => "data", "purpose" => "test"})
    end
  end

  describe "create!/3" do
    test "raises on error" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise LatticeStripe.Error, fn ->
        File.create!(client, %{"file" => "data", "purpose" => "test"})
      end
    end
  end

  describe "retrieve/3" do
    test "returns {:ok, %File{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/files/file_test123")
        ok_response(Fixtures.File.basic())
      end)

      assert {:ok, %File{id: "file_test123"}} = File.retrieve(client, "file_test123")
    end
  end

  describe "list/3" do
    test "returns {:ok, %Response{data: %List{}}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.contains?(req.url, "/v1/files")
        ok_response(%{
          "object" => "list",
          "data" => [Fixtures.File.basic()],
          "has_more" => false,
          "url" => "/v1/files"
        })
      end)

      assert {:ok, %Response{data: %LatticeStripe.List{data: [%File{}]}}} =
               File.list(client)
    end
  end

  describe "immutability guards" do
    test "update/4 is not exported (files are immutable per D-17)" do
      refute function_exported?(LatticeStripe.File, :update, 4)
    end

    test "delete/3 is not exported (files cannot be deleted per D-17)" do
      refute function_exported?(LatticeStripe.File, :delete, 3)
    end
  end

  describe "Inspect" do
    test "masks url field" do
      file = File.from_map(Fixtures.File.basic())
      inspected = inspect(file)
      assert inspected =~ "LatticeStripe.File"
      assert inspected =~ "file_test123"
      assert inspected =~ "dispute_evidence"
      refute inspected =~ "https://files.stripe.com/v1/files/file_test123/contents"
    end
  end
end
