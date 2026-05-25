# Phase 35: Mandate & SetupAttempt - Discussion Log

**Date:** 2026-05-24
**Mode:** `gsd-discuss-phase 35` with all gray areas selected, codebase-first analysis, local research synthesis, and parallel subagent comparison memos
**Outcome:** Context locked and ready for planning

## User direction

The user explicitly asked for:

- all gray areas to be discussed
- subagent-backed research for each area
- pros/cons/tradeoffs, examples, ecosystem lessons, and DX analysis
- one-shot recommendations so they do not need to make every low/medium-impact decision manually
- coherent recommendations aligned with LatticeStripe's goals and philosophy
- local `prompts/` research to be treated as canonical context where relevant

## Inputs considered

### Project artifacts

- `.planning/PROJECT.md`
- `.planning/REQUIREMENTS.md`
- `.planning/STATE.md`
- `.planning/ROADMAP.md`
- prior context files for Phases 5, 22, 24, 32, 33, and 34

### Research artifacts

- `.planning/research/FEATURES.md`
- `.planning/research/PITFALLS.md`
- `.planning/research/ARCHITECTURE.md`
- `.planning/research/STACK.md`
- relevant `prompts/*.md` deep-research files

### External references consulted

- Stripe docs for Mandates and SetupAttempts
- Stripe official SDK patterns and ecosystem precedents surfaced through research and subagents
- `stripity_stripe` as the closest Elixir ecosystem comparison point

## Gray area 1: SetupAttempt surface shape

### Options considered

1. Strict list-only surface on `SetupAttempt`
2. Extra convenience helpers on `SetupAttempt`
3. Parent-oriented helper surface on `SetupIntent`

### Recommendation locked

- Choose option 1.
- `SetupAttempt` stays strictly `list/3`, `list!/3`, `stream!/3`.
- No convenience aliases.
- Require `"setup_intent"` locally.

### Why

- Best fit for Stripe's actual endpoint shape
- Strongest alignment with LatticeStripe's explicit, low-magic surface
- Avoids convenience-surface creep and weak ownership boundaries
- Preserves a clean distinction between SDK resource coverage and app-level orchestration

### Examples discussed

```elixir
{:ok, resp} =
  LatticeStripe.SetupAttempt.list(client, %{"setup_intent" => "seti_123"})

attempts =
  client
  |> LatticeStripe.SetupAttempt.stream!(%{"setup_intent" => "seti_123"})
  |> Enum.to_list()
```

## Gray area 2: Nested typing depth

### Options considered

1. Deep typed tree for all nested objects
2. Selective typing for bounded sub-objects only
3. Top-level structs only, all nested values raw

### Recommendation locked

- Choose option 2.
- Type bounded mandate sub-objects that clearly help.
- Keep polymorphic payment-method snapshots raw.

### Concrete decisions

- `%Mandate.CustomerAcceptance{}`: yes
- `%Mandate.SingleUse{}`: yes
- `Mandate.multi_use`: raw map
- `Mandate.payment_method_details`: raw map
- `SetupAttempt.payment_method_details`: raw map

### Why

- Best DX-to-maintenance ratio
- Keeps the stable, high-signal parts typed
- Avoids combinatorial nested-struct churn as Stripe adds payment-method variants
- Matches the project's existing anti-overmodeling instinct

## Gray area 3: Historical error modeling

### Options considered

1. Reuse `%LatticeStripe.Error{}`
2. Introduce `%LatticeStripe.SetupAttempt.SetupError{}`
3. Leave `setup_error` as raw map

### Recommendation locked

- Choose option 2.
- Use a dedicated `%LatticeStripe.SetupAttempt.SetupError{}` struct.

### Why this over the strongest precedent

Most official/generated SDK precedent favors reusing a generic Stripe error model. That is acceptable in generated clients, but it is not the best fit here.

Reasons for overruling the precedent:

- In LatticeStripe, `%LatticeStripe.Error{}` already carries strong meaning as the request-failure channel
- `setup_error` is historical data on a successful resource response, not a failed request
- Reusing the same struct would blur those concepts and make pattern matching more semantically misleading
- A small dedicated nested struct delivers clearer semantics without significant surface cost

### Example shape discussed

```elixir
case attempt.setup_error do
  %LatticeStripe.SetupAttempt.SetupError{type: :card_error, code: "card_declined"} ->
    :retry_with_new_payment_method

  nil ->
    :no_historical_failure
end
```

## Gray area 4: Enum modeling and fail-fast validation

### Options considered

1. Parse-time atomization plus local required-param validation
2. Parse-time atomization but let Stripe reject missing params
3. Keep strings and let Stripe validate

### Recommendation locked

- Choose option 1.
- Atomize bounded top-level enums during `from_map/1`.
- Keep unknown values as strings.
- Fail fast when `SetupAttempt.list/3` or `stream!/3` is called without `"setup_intent"`.

### Concrete enum decisions

- `Mandate.status`: atomized
- `Mandate.type`: atomized
- `SetupAttempt.status`: atomized
- `SetupAttempt.usage`: atomized
- `Mandate.CustomerAcceptance.type`: atomized
- Deep leaves inside raw-map `payment_method_details`: not atomized

### Why

- Consistent with Phase 22 and newer LatticeStripe resources
- Better Elixir pattern matching and lower stringly-typed user code
- Clearer local failure than a remote 400 for a known required scope param

## Contradictions resolved during synthesis

### SetupAttempt retrieve support

Local research artifacts contained an outdated/incorrect suggestion that `SetupAttempt.retrieve/3` may exist.

Resolution:

- Follow current Stripe API docs, not the stale research note.
- Phase 35 locks `SetupAttempt` as list-only.

### Generic error reuse vs semantic precision

Some ecosystem precedent favored decoding `setup_error` into a generic Stripe error type.

Resolution:

- For LatticeStripe, semantic precision outranks broad-shape reuse here.
- Dedicated nested struct chosen.

## Process preference surfaced by user

The user expressed a workflow preference:

- for low/medium-impact discuss decisions, GSD should bias toward deeper research plus cohesive recommended defaults rather than repeatedly asking the user to choose every tradeoff manually
- reserve explicit user choice for genuinely high-impact decisions

This was applied in this discussion by locking recommendations after research synthesis rather than requesting incremental approvals.

## Final recommendation set

The final set is intentionally cohesive:

1. Small read-only public API
2. Local fail-fast validation where the library has strong knowledge
3. Selective typing for bounded high-signal structures
4. Raw maps for polymorphic snapshots
5. Parse-time atomization for bounded enums
6. Dedicated nested error struct for historical failure data

That set best matches:

- the project's Elixir-first ergonomics
- principle of least surprise
- strong boundaries between SDK coverage and higher-level orchestration
- maintainable handwritten-library architecture rather than generated-client bloat

