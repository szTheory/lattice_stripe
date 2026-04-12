# Phase 1: Transport & Client Configuration - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-31
**Phase:** 01-transport-client-configuration
**Areas discussed:** Client API Surface, Request Interface, Finch Pool Management, Error Boundaries, Form Encoding, Response Decoding, Config Validation, Module Structure, Transport Behaviour, Telemetry Prep, Test Strategy, Dependencies

---

## Client API Surface

| Option | Description | Selected |
|--------|-------------|----------|
| Explicit struct only | Client.new(api_key: ...) is the only way. Library never reads Application config. | ✓ |
| Struct + app config fallback | Client.new() with no args falls back to Application.get_env | |
| You decide | Claude picks | |

**User's choice:** Explicit struct only
**Notes:** Researched 5 patterns: Global App Env, Explicit Struct, Req Composable, Named Process, Process Dictionary. User needed full code examples and tradeoff analysis for each. Elixir Library Guidelines explicitly recommend explicit config for Hex packages. Both new!/1 (raises) and new/1 (ok/error tuple) provided.

---

## Request Interface

| Option | Description | Selected |
|--------|-------------|----------|
| Request struct pipeline | Build %Request{} data, Client dispatches. ExAws-inspired. | ✓ |
| Direct client functions | Resource modules call Client.post() directly | |
| You decide | Claude picks | |

**User's choice:** Request struct pipeline
**Notes:** Researched 4 patterns: Stripity Stripe (functional builder), ExAws (protocol dispatch), Tesla (middleware stack), Req (step pipeline). User needed full internal code examples showing how each pattern works end-to-end. Request struct chosen for testability and future extensibility (telemetry, retry, middleware hooks).

---

## Finch Pool Management

| Option | Description | Selected |
|--------|-------------|----------|
| User manages | User adds Finch to their supervision tree | ✓ |
| Library auto-starts | LatticeStripe starts its own pool | |
| Default + opt-out | Library starts default, user can override | |

**User's choice:** User manages
**Notes:** Elixir Library Guidelines say libraries should not start processes without user explicitly adding them to supervision tree. One extra line in application.ex, documented in README quickstart.

---

## Error Boundaries

| Option | Description | Selected |
|--------|-------------|----------|
| Basic Error struct in Phase 1 | Single %Error{type, code, message, status, request_id} | ✓ |
| Minimal raw errors | Phase 1 returns raw %{status, body} | |

**User's choice:** Basic Error struct
**Notes:** Pattern-matchable from day one via :type atom field. Phase 2 enriches without breaking changes (additive fields only).

---

## Form Encoding

| Option | Description | Selected |
|--------|-------------|----------|
| Own encoder | ~40 lines recursive code, no dependency | ✓ |
| You decide | Claude picks | |

**User's choice:** Own encoder
**Notes:** Handles nested maps, arrays, deeply nested params. Standard approach — every Stripe SDK does this internally.

---

## Response Decoding

| Option | Description | Selected |
|--------|-------------|----------|
| Structs + extra field | Typed structs for covered resources, maps for rest | ✓ |
| Plain maps (string keys) | Simplest, never breaks | |
| Plain maps (atom keys) | Nicer but atom-from-untrusted anti-pattern | |

**User's choice:** Structs + extra field
**Notes:** Standard Elixir pattern for API clients. Dot access, pattern matching, autocomplete. Unknown fields go to .extra so structs don't break on Stripe API changes.

---

## Config Validation

| Option | Description | Selected |
|--------|-------------|----------|
| NimbleOptions + both APIs | new!/1 raises, new/1 returns ok/error. Auto-generates docs. | ✓ |
| You decide | Claude picks | |

**User's choice:** NimbleOptions + both APIs
**Notes:** Standard in Elixir ecosystem (Finch, Broadway use NimbleOptions). Catches config errors at creation time with clear messages.

---

## Module Structure

| Option | Description | Selected |
|--------|-------------|----------|
| Flat resources layout | LatticeStripe.Customer, nested only when Stripe nests | ✓ |
| Need changes | User wants adjustments | |

**User's choice:** Flat resources, as proposed
**Notes:** No intermediate directories (no resources/, api/). Behaviours in top-level files, adapters in sub-dirs.

---

## Transport Behaviour

| Option | Description | Selected |
|--------|-------------|----------|
| Single fn + plain map | One request/1 callback, plain map in/out | ✓ |
| Single fn + struct | Same but with typed Request/Response structs | |
| Multiple verb functions | Separate get/post/delete callbacks | |

**User's choice:** Single fn + plain map (Claude's recommendation, confirmed by user)
**Notes:** User asked for best practices research. Narrowest possible behaviour — standard Elixir pattern. Plain maps at transport boundary so adapter authors don't need to know library internals.

---

## Telemetry Prep

| Option | Description | Selected |
|--------|-------------|----------|
| Wire from Phase 1 | telemetry.span in Client.request/2, zero overhead when unused | ✓ |
| Defer to Phase 8 | Keep Phase 1 minimal | |

**User's choice:** Wire from Phase 1
**Notes:** Standard practice — Phoenix, Ecto, Finch all ship telemetry from day one. 3-4 lines, no-op when no handler attached.

---

## Test Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Unit + Mox, async: true | Layer 1 (pure unit) + Layer 2 (Mox transport). stripe-mock in Phase 9. | ✓ |
| Need changes | User wants adjustments | |

**User's choice:** As described
**Notes:** All tests async: true (no global state). Mox for Transport behaviour mocking.

---

## Dependencies

| Option | Description | Selected |
|--------|-------------|----------|
| Lean standard list | Finch, Jason, Telemetry, NimbleOptions, Plug (optional), Mox/ExDoc/Credo dev | ✓ |
| Need changes | User wants adjustments | |

**User's choice:** As described
**Notes:** No Dialyxir. Plug optional (only for webhooks). Finch ~> 0.19 for wider compat.

---

## Claude's Discretion

- User-Agent header string format
- Stripe API version string to pin
- Internal helper function organization
- NimbleOptions schema field ordering
- Error message wording
- Test fixture data shapes

## Deferred Ideas

None — discussion stayed within phase scope
