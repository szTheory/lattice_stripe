defmodule LatticeStripe.Test.Fixtures.FileLink do
  @moduledoc false

  def basic(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "link_test123",
        "object" => "file_link",
        "created" => 1_700_000_000,
        "expired" => false,
        "expires_at" => nil,
        "file" => "file_test123",
        "livemode" => false,
        "metadata" => %{},
        "url" => "https://files.stripe.com/links/MDB...",
        "zzz_forward_compat_field" => "extra_value"
      },
      overrides
    )
  end

  def with_expanded_file(overrides \\ %{}) do
    expanded = %{
      "id" => "file_test123",
      "object" => "file",
      "created" => 1_700_000_000,
      "purpose" => "dispute_evidence",
      "size" => 1024,
      "filename" => "evidence.pdf"
    }

    basic(Map.merge(%{"file" => expanded}, overrides))
  end
end
