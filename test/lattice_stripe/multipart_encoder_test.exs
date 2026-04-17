defmodule LatticeStripe.MultipartEncoderTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.MultipartEncoder

  describe "encode/4" do
    test "returns deterministic body when boundary injected" do
      {body, boundary} =
        MultipartEncoder.encode(
          "file-content",
          "evidence.pdf",
          %{"purpose" => "dispute_evidence"},
          boundary: "testboundary123"
        )

      assert boundary == "testboundary123"
      assert body =~ "--testboundary123\r\n"
      assert body =~ ~s(Content-Disposition: form-data; name="purpose"\r\n)
      assert body =~ "dispute_evidence"
      assert body =~ ~s(Content-Disposition: form-data; name="file"; filename="evidence.pdf"\r\n)
      assert body =~ "Content-Type: application/octet-stream\r\n"
      assert body =~ "file-content"
      assert body =~ "--testboundary123--\r\n"
    end

    test "generates random boundary when not injected" do
      {_body1, boundary1} = MultipartEncoder.encode("data", "f.txt", %{})
      {_body2, boundary2} = MultipartEncoder.encode("data", "f.txt", %{})
      assert byte_size(boundary1) == 32
      assert boundary1 != boundary2
    end

    test "encodes multiple string fields" do
      {body, _} =
        MultipartEncoder.encode(
          "bin",
          "upload",
          %{"purpose" => "dispute_evidence", "file_link_data[create]" => "true"},
          boundary: "multi"
        )

      assert body =~ ~s(name="purpose")
      assert body =~ ~s(name="file_link_data[create]")
    end

    test "handles empty string fields map" do
      {body, _} = MultipartEncoder.encode("bin", "f.txt", %{}, boundary: "empty")
      assert body =~ ~s(name="file")
      refute body =~ ~s(name="purpose")
    end

    test "preserves binary file content exactly" do
      binary = <<0, 1, 2, 255, 128, 64>>
      {body, _} = MultipartEncoder.encode(binary, "data.bin", %{}, boundary: "bintest")
      assert body =~ binary
    end
  end
end
