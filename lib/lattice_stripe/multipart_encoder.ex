defmodule LatticeStripe.MultipartEncoder do
  @moduledoc false

  @crlf "\r\n"

  @spec encode(binary(), String.t(), map(), keyword()) :: {binary(), String.t()}
  def encode(file_binary, filename, string_fields, opts \\ []) do
    boundary = Keyword.get(opts, :boundary) || random_boundary()

    parts =
      string_fields
      |> Enum.map(fn {key, value} -> text_part(boundary, to_string(key), to_string(value)) end)

    file_part = file_part(boundary, file_binary, filename)
    closing = "--#{boundary}--#{@crlf}"

    body = IO.iodata_to_binary([parts, file_part, closing])
    {body, boundary}
  end

  defp text_part(boundary, name, value) do
    [
      "--#{boundary}#{@crlf}",
      "Content-Disposition: form-data; name=\"#{name}\"#{@crlf}",
      @crlf,
      value,
      @crlf
    ]
  end

  defp file_part(boundary, binary, filename) do
    [
      "--#{boundary}#{@crlf}",
      "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"#{@crlf}",
      "Content-Type: application/octet-stream#{@crlf}",
      @crlf,
      binary,
      @crlf
    ]
  end

  defp random_boundary do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end
