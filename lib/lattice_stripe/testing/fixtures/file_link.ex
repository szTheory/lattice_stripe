defmodule LatticeStripe.Testing.Fixtures.FileLink do
  @moduledoc """
  Canonical raw fixtures for Stripe FileLink objects.
  """

  @doc """
  Returns a Stripe-shaped FileLink map.
  """
  @spec file_link_json(map()) :: map()
  def file_link_json(overrides \\ %{}) do
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

  @doc """
  Returns a FileLink map with an expanded File object.
  """
  @spec file_link_with_expanded_file_json(map()) :: map()
  def file_link_with_expanded_file_json(overrides \\ %{}) do
    expanded = %{
      "id" => "file_test123",
      "object" => "file",
      "created" => 1_700_000_000,
      "purpose" => "dispute_evidence",
      "size" => 1024,
      "filename" => "evidence.pdf"
    }

    file_link_json(Map.merge(%{"file" => expanded}, overrides))
  end
end
