---
phase: 32-file-filelink
reviewed: 2026-04-16T00:00:00Z
depth: standard
files_reviewed: 14
files_reviewed_list:
  - lib/lattice_stripe/client.ex
  - lib/lattice_stripe/config.ex
  - lib/lattice_stripe/file.ex
  - lib/lattice_stripe/file_link.ex
  - lib/lattice_stripe/multipart_encoder.ex
  - lib/lattice_stripe/object_types.ex
  - lib/lattice_stripe/response.ex
  - test/integration/file_integration_test.exs
  - test/lattice_stripe/client_test.exs
  - test/lattice_stripe/file_link_test.exs
  - test/lattice_stripe/file_test.exs
  - test/lattice_stripe/multipart_encoder_test.exs
  - test/support/fixtures/file.ex
  - test/support/fixtures/file_link.ex
findings:
  critical: 0
  warning: 2
  info: 2
  total: 4
status: issues_found
---

# Phase 32: Code Review Report

**Reviewed:** 2026-04-16T00:00:00Z
**Depth:** standard
**Files Reviewed:** 14
**Status:** issues_found

## Summary

Reviewed all source and test files for phase 32 (File/FileLink). The new `LatticeStripe.File`, `LatticeStripe.FileLink`, and `LatticeStripe.MultipartEncoder` modules are well-structured and follow established SDK patterns. Transport plumbing in `Client` for `upload/4` and `download/3` is correct. Two warnings were found: `File.create/3` breaks its `{:ok, t()} | {:error, Error.t()}` contract by allowing a `KeyError` to escape, and `MultipartEncoder.encode/4` silently produces malformed multipart output when a nested map is passed as a field value. Two info items cover a missing doc inconsistency in `Config` and an unused `"object"` key in the `File` defstruct.

## Warnings

### WR-01: `File.create/3` raises `KeyError` on missing `"file"` param — breaks stated contract

**File:** `lib/lattice_stripe/file.ex:104`

**Issue:** `Map.fetch!(params, "file")` raises `KeyError` (an unhandled exception) when the caller omits the `"file"` key. The function's typespec declares `{:ok, t()} | {:error, Error.t()}`, so callers who handle only those two shapes will encounter an unexpected crash. Every other SDK function that validates input returns `{:error, %Error{}}` rather than raising.

**Fix:** Replace the bang fetch with a guarded pattern or an explicit error:

```elixir
def create(%Client{} = client, params \\ %{}, opts \\ []) do
  case Map.fetch(params, "file") do
    {:ok, file_binary} ->
      upload_params = Map.drop(params, ["file"])
      Client.upload(client, file_binary, upload_params, opts)
      |> Resource.unwrap_singular(&from_map/1)

    :error ->
      {:error,
       %LatticeStripe.Error{
         type: :invalid_request_error,
         message: ~s(required param "file" is missing from params)
       }}
  end
end
```

---

### WR-02: `MultipartEncoder.encode/4` silently corrupts output for nested-map field values

**File:** `lib/lattice_stripe/multipart_encoder.ex:12`

**Issue:** All entries in `string_fields` are serialized with `to_string(value)`. For a plain string this works. For any value that is not a binary — such as the documented `"file_link_data"` nested map — `to_string/1` produces the Elixir map's inspect representation (e.g., `%{"create" => "true", "expires_at" => 1700000000}`), which is not valid form data and will be rejected by Stripe. The `Client.upload/4` doc and `File.create/3` doc both mention `"file_link_data"` as a valid parameter, implying callers may pass it as a map.

The bug is silent: the body is encoded without error, the request goes to Stripe, and Stripe returns a 400 or silently ignores the field.

**Fix:** Either (a) validate that every field value is a binary and return an error for non-binaries, or (b) guard the clause to raise a clear `ArgumentError` at encode time:

```elixir
# Option A: strict binary check
defp text_part(boundary, name, value) when is_binary(value) do
  [
    "--#{boundary}#{@crlf}",
    "Content-Disposition: form-data; name=\"#{name}\"#{@crlf}",
    @crlf,
    value,
    @crlf
  ]
end

# In encode/4, map over fields and raise for non-binary values:
parts =
  Enum.map(string_fields, fn {key, value} ->
    unless is_binary(value) do
      raise ArgumentError,
            "MultipartEncoder: field #{inspect(key)} value must be a binary string, got: #{inspect(value)}. " <>
            "Flatten nested params to bracket notation before encoding (e.g., \"file_link_data[create]\" => \"true\")."
    end
    text_part(boundary, to_string(key), value)
  end)
```

Note: The test in `multipart_encoder_test.exs:38` already demonstrates the correct bracket-notation workaround (`"file_link_data[create]" => "true"`), but the `Client.upload/4` and `File.create/3` docs do not warn callers that nested maps must be pre-flattened.

## Info

### IN-01: `Config` `operation_timeouts` doc omits `:upload` and `:download` keys

**File:** `lib/lattice_stripe/config.ex:83-84`

**Issue:** The NimbleOptions doc for `operation_timeouts` lists the valid keys as `:list`, `:search`, `:create`, `:retrieve`, `:update`, `:delete`. However, `Client.upload/4` and `Client.download/3` both resolve their effective timeout via `resolve_timeout(client, :upload, opts)` and `resolve_timeout(client, :download, opts)`, and the `Client` typedoc (line 85) explicitly lists `:upload` and `:download` as valid keys. Users reading the `Config` docs would not know they can configure separate timeouts for upload and download operations.

**Fix:** Add `:upload` and `:download` to the key list in the doc string:

```elixir
doc: """
Per-operation timeout overrides in milliseconds.
Keys: `:list`, `:search`, `:create`, `:retrieve`, `:update`, `:delete`, `:upload`, `:download`.
...
"""
```

---

### IN-02: `File` defstruct includes `object: "file"` default but `@known_fields` does not guard it from `extra`

**File:** `lib/lattice_stripe/file.ex:35-51`

**Issue:** `@known_fields` on line 35 includes `"object"` as a known field, so it is correctly dropped from `extra` during `from_map/1`. This is fine. The observation is a minor stylistic inconsistency: `object` is the only field with a non-nil default in the struct (`object: "file"`) yet `from_map/1` on line 73 explicitly overwrites it with `map["object"] || "file"`, making the struct default redundant. This is not a bug but adds confusion — the default is never relied upon since every `from_map/1` call sets the field explicitly.

**Fix:** Either remove the default from the defstruct (making it consistent with other fields):

```elixir
defstruct [
  :id,
  :object,   # no default — always set by from_map/1
  ...
]
```

Or keep the default and remove the `|| "file"` fallback in `from_map/1`, but leave a comment explaining the intent. The same pattern exists in `FileLink` (`object: "file_link"` line 47) so whichever convention is chosen should be applied consistently across both modules.

---

_Reviewed: 2026-04-16T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
