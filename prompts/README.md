# Project research

This directory preserves the research that shaped LatticeStripe without making
old design explorations look like current implementation instructions.

## Current reference

- [`payments_domain_field_guide.md`](payments_domain_field_guide.md) — durable
  Stripe domain language, object relationships, events, and integration
  boundaries. Use this when domain context is needed.

## Historical research

The documents in [`archive/`](archive/) are point-in-time inputs from the
project's initial design. They remain useful for rationale and alternatives,
but the shipped source, public documentation, tests, and `.planning/PROJECT.md`
take precedence whenever they differ.

There is no separate brand book or UI design system: LatticeStripe is a
headless Hex library. Its user experience is the public Elixir API, error
contracts, examples, guides, and HexDocs information architecture.
