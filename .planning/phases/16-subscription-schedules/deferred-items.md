## Pre-existing format issues (out of scope for Plan 16-02)

Discovered during Plan 16-02 verification (`mix format --check-formatted`).
NOT touched by this plan — purely pre-existing in unrelated files.

- `lib/lattice_stripe/invoice.ex` (parse_lines pipe formatting)
- `test/lattice_stripe/invoice_test.exs` (trailing blank line)
- `test/lattice_stripe/config_test.exs` (long line wrapping)

Recommend: schedule a chore commit or fold into the next phase touching those files.
