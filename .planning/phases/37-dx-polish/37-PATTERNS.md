# Phase 37: DX Polish - Pattern Map

**Mapped:** 2026-05-25
**Files analyzed:** 18
**Analogs found:** 18 / 18

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/lattice_stripe/testing.ex` | service | transform | `lib/lattice_stripe/testing.ex` | exact |
| `lib/lattice_stripe/testing/fixtures.ex` | service | transform | `lib/lattice_stripe/testing.ex` | role-match |
| `lib/lattice_stripe/testing/fixtures/file.ex` | model/helper | transform | `test/support/fixtures/file.ex` | role-match |
| `lib/lattice_stripe/testing/fixtures/file_link.ex` | model/helper | transform | `test/support/fixtures/file_link.ex` | role-match |
| `lib/lattice_stripe/testing/fixtures/dispute.ex` | model/helper | transform | `test/support/fixtures/dispute.ex` | role-match |
| `lib/lattice_stripe/testing/fixtures/credit_note.ex` | model/helper | transform | `test/support/fixtures/credit_note.ex` | role-match |
| `lib/lattice_stripe/testing/fixtures/mandate.ex` | model/helper | transform | `test/support/fixtures/mandate.ex` | role-match |
| `lib/lattice_stripe/testing/fixtures/setup_attempt.ex` | model/helper | transform | `test/support/fixtures/setup_attempt.ex` | role-match |
| `lib/lattice_stripe/testing/fixtures/quote.ex` | model/helper | transform | `test/support/fixtures/quote.ex` | role-match |
| `test/lattice_stripe/testing_test.exs` | test | transform | `test/lattice_stripe/testing_test.exs` | exact |
| `guides/webhooks.md` | docs | user-flow | `guides/customer-portal.md` | tone-match |
| `guides/testing.md` | docs | user-flow | `guides/testing.md` | exact |
| `guides/recipes.md` | docs | user-flow | `guides/user-flows-and-jtbd.md` | role-match |
| `README.md` | docs | user-flow | `README.md` | exact |
| `CHANGELOG.md` | docs | history/truth | `CHANGELOG.md` | exact |
| `mix.exs` | config/docs | transform | `mix.exs` | exact |
| `test/lattice_stripe/docs_*_test.exs` | docs test | transform | existing ExUnit style | role-match |
| `guides/*.md` | docs | user-flow | existing guide set | exact |

## Pattern Assignments

### Public fixture modules under `lib/lattice_stripe/testing/fixtures/`

**Primary analog:** `test/support/fixtures/*.ex`  
**Supporting analog:** `lib/lattice_stripe/testing.ex`

- Copy the repo’s existing fixture style: mergeable raw Stripe maps, scenario helpers, and forward-compatible unknown fields where applicable.
- Normalize naming toward explicit `*_json/1`-style builders for public helpers.
- Keep public modules small and resource-focused. One module per v1.3 family.
- Reuse existing internal fixture payload shapes instead of inventing new canonical data.

### `lib/lattice_stripe/testing.ex`

**Primary analog:** self  
**Supporting analogs:** resource `from_map/1` contracts and `LatticeStripe.Webhook`

- Extend the module by layering on top of fixture builders rather than replacing them.
- Follow the existing explicit-helper pattern:
  - one function for event structs
  - one function for signed payloads
  - separate helpers for typed resource structs if added
- Do not add shape-switching options like `as:`.
- Keep webhook signing behavior centralized through the existing `Webhook.generate_test_signature/3` path.

### `guides/webhooks.md`

**Primary analog:** `guides/customer-portal.md`  
**Supporting analogs:** current `guides/webhooks.md`, `lib/lattice_stripe/webhook/plug.ex`

- Lead with one copy-paste-ready Phoenix path.
- Keep the example concrete:
  - `endpoint.ex`
  - handler module
  - path gate with `at:`
  - runtime secret resolution
- Teach the operating model first, then branch into alternatives and troubleshooting.
- Present `CacheBodyReader` + `forward` as advanced fallback only after the canonical quickstart succeeds.

### `guides/testing.md`

**Primary analog:** self  
**Supporting analog:** `lib/lattice_stripe/testing.ex`

- Preserve the current structure around Mox, webhook tests, and `stripe-mock`.
- Add the public fixture-builder story near the top of “Testing Webhook Handlers” / helper guidance so developers discover it before hand-rolling raw maps.
- Prefer realistic examples using dispute, credit note, and quote-family payloads to match the new v1.3 surface.

### `guides/recipes.md`

**Primary analog:** `guides/user-flows-and-jtbd.md`  
**Supporting analogs:** `guides/customer-portal.md`, `guides/credit_notes.md`

- Keep the guide compact and bridge-oriented.
- Use a repeated recipe template:
  - job/problem framing
  - relevant LatticeStripe calls
  - webhook confirmation point
  - next guides to read
- Do not introduce app-policy abstractions, billing orchestrators, or reusable workflow helpers.

### `README.md`, `CHANGELOG.md`, `mix.exs`

**Analogs:** self

- Update visible version/install/docs truth in the existing tone and structure.
- Register `guides/recipes.md` in ExDoc `extras` and keep sidebar grouping aligned with current guide organization.
- Preserve explicit release-status framing in `CHANGELOG.md`; do not imply a publish action occurred.

### Docs-truth tests

**Primary analog:** existing ExUnit tests  
**Supporting analog:** `mix docs --warnings-as-errors`

- If docs-focused tests are added, keep them narrow and durable:
  - version snippet checks
  - ExDoc extras registration checks
  - presence of guide files referenced from README or docs indexes
- Avoid brittle full-file string snapshots.

## Specific Reuse Guidance

### Resource fixture promotion

- Public fixture modules should wrap or mirror the logic in:
  - `test/support/fixtures/file.ex`
  - `test/support/fixtures/file_link.ex`
  - `test/support/fixtures/dispute.ex`
  - `test/support/fixtures/credit_note.ex`
  - `test/support/fixtures/mandate.ex`
  - `test/support/fixtures/setup_attempt.ex`
  - `test/support/fixtures/quote.ex`
- Preserve scenario helpers where they materially reduce test noise.
- Avoid leaking integration-only helpers like “create resource in stripe-mock” into the public package surface unless they are clearly test-environment-safe and intentional.

### Webhook examples

- `LatticeStripe.Webhook.Plug` in `endpoint.ex` before `Plug.Parsers` is the default pattern.
- `LatticeStripe.Webhook.CacheBodyReader` belongs in the advanced alternative section only.
- Use runtime secret resolution examples, preferring MFA or zero-arity function.

### Recipes content

- Reuse terminology already established in:
  - `guides/user-flows-and-jtbd.md`
  - `guides/customer-portal.md`
  - `guides/credit_notes.md`
  - `guides/webhooks.md`
- The recipes should cross-link these guides rather than duplicating their full explanations.

## Risk Notes

- The main API-shape risk is exposing public fixture helpers whose names or return contracts feel temporary. Solve that with raw-map canonicality and explicit wrappers.
- The main docs risk is continuing to present both webhook mounting strategies as equally primary.
- The main trust risk is fixing prose while leaving version/install/docs metadata stale.

## Execution Default

- Parser/resource contracts stay where they are.
- New public DX work is mostly additive.
- Documentation should follow the repo’s strongest pattern: one clear path first, then deeper alternatives.
