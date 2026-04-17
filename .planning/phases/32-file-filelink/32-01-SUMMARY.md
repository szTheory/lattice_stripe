---
phase: 32-file-filelink
plan: "01"
subsystem: transport-infrastructure
tags:
  - multipart
  - file-upload
  - config
  - fixtures
dependency_graph:
  requires:
    - lib/lattice_stripe/form_encoder.ex
    - lib/lattice_stripe/config.ex
    - lib/lattice_stripe/client.ex
    - lib/lattice_stripe/response.ex
  provides:
    - lib/lattice_stripe/multipart_encoder.ex
    - files_base_url config field
    - binary() in Response typespec
    - File and FileLink fixture builders
  affects:
    - lib/lattice_stripe/client.ex
    - lib/lattice_stripe/config.ex
    - lib/lattice_stripe/response.ex
tech_stack:
  added:
    - ":crypto.strong_rand_bytes/16 for multipart boundary generation"
    - "IO.iodata_to_binary/1 for efficient multipart assembly"
  patterns:
    - "Injectable boundary for deterministic test output (Keyword.get opt)"
    - "RFC 2046 multipart/form-data with CRLF line endings"
    - "@moduledoc false internal module pattern"
key_files:
  created:
    - lib/lattice_stripe/multipart_encoder.ex
    - test/lattice_stripe/multipart_encoder_test.exs
    - test/support/fixtures/file.ex
    - test/support/fixtures/file_link.ex
  modified:
    - lib/lattice_stripe/config.ex
    - lib/lattice_stripe/client.ex
    - lib/lattice_stripe/response.ex
decisions:
  - "Injectable boundary via opts[:boundary] for deterministic test output; random boundary via :crypto.strong_rand_bytes(16) in production"
  - "files_base_url added adjacent to base_url in Config schema with default https://files.stripe.com"
  - "Response @type t data widened to binary() | map() | LatticeStripe.List.t() | nil for download responses"
metrics:
  duration_seconds: 91
  completed_date: "2026-04-17"
  tasks_completed: 2
  files_created: 4
  files_modified: 3
---

# Phase 32 Plan 01: MultipartEncoder and Infrastructure Summary

**One-liner:** RFC 2046 multipart/form-data encoder with injectable boundary, files_base_url config field, widened Response typespec for binary downloads, and File/FileLink fixture builders.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create MultipartEncoder module and unit tests | 1beb046 | lib/lattice_stripe/multipart_encoder.ex, test/lattice_stripe/multipart_encoder_test.exs |
| 2 | Extend Config, Client struct, Response typespec, and create fixture builders | 19f489d | lib/lattice_stripe/config.ex, lib/lattice_stripe/client.ex, lib/lattice_stripe/response.ex, test/support/fixtures/file.ex, test/support/fixtures/file_link.ex |

## What Was Built

### MultipartEncoder (lib/lattice_stripe/multipart_encoder.ex)

RFC 2046-compliant `multipart/form-data` encoder. `encode/4` accepts a file binary, filename, string fields map, and optional keyword opts. Key behaviors:

- `boundary:` opt makes output deterministic for tests; omitting it generates a random 32-char lowercase hex boundary via `:crypto.strong_rand_bytes(16)`
- `IO.iodata_to_binary/1` assembles parts efficiently (no string concatenation overhead)
- CRLF line endings throughout per RFC 2046
- File part always uses `Content-Type: application/octet-stream` and `name="file"` per Stripe's multipart spec
- Returns `{body_binary, boundary_string}` tuple so callers can set the `Content-Type` header

### Config/Client/Response Extensions

- `files_base_url` added to Config NimbleOptions schema (default: `"https://files.stripe.com"`) and Client defstruct/`@type t`
- `operation_timeouts` typedoc extended with `:upload` and `:download` keys for Plan 02
- Response `@type t` data field widened to `binary() | map() | LatticeStripe.List.t() | nil` to support `Client.download/3` returning raw binary

### Test Fixture Builders

- `LatticeStripe.Test.Fixtures.File` — `basic/1` with forward-compat field + `with_links/1` variant with embedded file_links list
- `LatticeStripe.Test.Fixtures.FileLink` — `basic/1` with forward-compat field + `with_expanded_file/1` variant with expanded file map

## Verification

- `mix compile --warnings-as-errors` — PASS
- `mix test test/lattice_stripe/multipart_encoder_test.exs` — 5 tests, 0 failures
- `mix test test/lattice_stripe/client_test.exs` — 67 tests, 0 failures
- `mix test` full suite — 1788 tests, 0 failures, 1 skipped

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — fixture builders use realistic data, no stubs that block plan goals.

## Threat Flags

None — no new network endpoints or auth paths introduced. MultipartEncoder is pure data transformation. `files_base_url` follows same trust model as `base_url` (developer-configured, T-32-02 accepted).

## Self-Check: PASSED

- `lib/lattice_stripe/multipart_encoder.ex` — EXISTS
- `test/lattice_stripe/multipart_encoder_test.exs` — EXISTS
- `test/support/fixtures/file.ex` — EXISTS
- `test/support/fixtures/file_link.ex` — EXISTS
- Commit `1beb046` — EXISTS
- Commit `19f489d` — EXISTS
