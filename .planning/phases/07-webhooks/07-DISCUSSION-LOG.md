# Phase 7: Webhooks - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-03
**Phase:** 07-webhooks
**Areas discussed:** Module structure, Event struct design, Plug integration depth, Raw body strategy, Plug response behavior, Event as API resource, Testing helpers, Multi-secret support, Plug config validation, Tolerance configuration, Signature error detail, Event type constants, Plug path matching, Bang variants, Plug.Conn assigns naming, Code.ensure_loaded? guard scope, Plug dep handling, Event Inspect implementation, Webhook public API surface, Handler return value validation, Plug non-POST handling, Event.from_map error handling, Webhook logging, Documentation scope, Event retrieve/list pattern, MFA secret resolution, Webhook.Plug test strategy

---

## Module Structure

| Option | Description | Selected |
|--------|-------------|----------|
| Split by concern | Webhook (verify), Event (top-level resource), Webhook.Plug, Webhook.Handler | ✓ |
| Single module | Everything in LatticeStripe.Webhook | |
| Flat top-level modules | Webhook, Event, WebhookPlug all at top level | |

**User's choice:** Split by concern (Option A)
**Notes:** Event is a Stripe API resource (GET /v1/events), not just a webhook payload. Top-level like Customer/PaymentIntent.

---

## Event Struct Design

| Option | Description | Selected |
|--------|-------------|----------|
| Fully typed top-level + raw maps | All 11 fields typed, data/request as raw maps, extra catch-all | ✓ |
| Dedicated nested structs | Event.Data and Event.Request inline structs | |
| Auto-parse data.object | Detect object type and parse into typed struct | |

**User's choice:** Fully typed top-level + raw maps (Option A)
**Notes:** Follows existing resource pattern. data.object varies by event type — raw map is the honest representation.

---

## Plug Integration Depth

| Option | Description | Selected |
|--------|-------------|----------|
| Both (handler optional) | Verify+assign by default, dispatch to Handler when handler: given | ✓ |
| Verification-only Plug | Just verify and assign, never dispatch | |
| Plug + Handler behaviour | Always dispatch to handler (stripity_stripe style) | |

**User's choice:** Both — handler optional (Option C)
**Notes:** Simple mode for custom controllers/Oban, handler mode for quick integration.

---

## Raw Body Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Both strategies | Ship CacheBodyReader + fallback to direct read_body | ✓ |
| CacheBodyReader only | Users must configure body_reader in Plug.Parsers | |
| Mount before Parsers only | No CacheBodyReader (stripity_stripe approach) | |
| Documentation only | Don't ship body caching | |

**User's choice:** Both strategies (Option D)
**Notes:** Works whether mounted in router (CacheBodyReader) or before Parsers (direct read).

---

## Plug Response Behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Verify-gate pattern | 400 bad sig, pass-through no handler, handler return maps to HTTP status | ✓ |
| Always 200 after verification | 200 even on handler errors | |
| User controls everything | Assigns only, never sends response | |

**User's choice:** Verify-gate (Option A)
**Notes:** Matches every official SDK. Handler exceptions re-raise to Plug error handler.

---

## Event as API Resource

| Option | Description | Selected |
|--------|-------------|----------|
| Include in Phase 7 | retrieve, list, stream alongside webhook verification | ✓ |
| Defer to later phase | Phase 7 only builds struct + webhook verification | |
| Retrieve only | Ship retrieve, defer list/stream | |

**User's choice:** Include in Phase 7
**Notes:** Struct already being built — adding CRUD is ~30 lines following Resource pattern.

---

## Testing Helpers

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, ship it | generate_test_signature/2 — ~10 lines, matches all official SDKs | ✓ |
| Defer to Phase 9 | Ship in Testing Infrastructure phase | |
| No — users use Mox | Users mock Webhook module | |

**User's choice:** Ship it in Phase 7

---

## Multi-Secret Support

| Option | Description | Selected |
|--------|-------------|----------|
| String or list | Accept String.t() | [String.t()], guard-based normalization | ✓ |
| Single secret only | Match all official SDKs, one string | |
| Separate functions | construct_event/3 vs construct_event_multi/3 | |

**User's choice:** String or list (Option B)
**Notes:** Covers Stripe Connect (two endpoints). Follows Ecto.Repo.preload pattern. Better than all official SDKs.

---

## Plug Config Validation

| Option | Description | Selected |
|--------|-------------|----------|
| NimbleOptions | Validate secret, handler, at, tolerance in init/1 | ✓ |
| Manual validation | Hand-written guards/checks | |

**User's choice:** NimbleOptions

---

## Tolerance Configuration

| Option | Description | Selected |
|--------|-------------|----------|
| Both | construct_event kwarg + Plug init option, default 300s | ✓ |
| construct_event kwarg only | Plug always uses 300s (stripity_stripe approach) | |
| Plug option only | construct_event always uses 300s | |

**User's choice:** Both

---

## Signature Error Detail

| Option | Description | Selected |
|--------|-------------|----------|
| Specific atoms | :missing_header, :invalid_header, :no_matching_signature, :timestamp_expired | ✓ |
| Error struct + atom code | Reuse LatticeStripe.Error with type + code | |
| String messages | Bare {:error, "..."} strings (stripity_stripe style) | |

**User's choice:** Specific atoms
**Notes:** Follows Plug.Crypto/Phoenix.Token convention. Translates Go SDK sentinel pattern.

---

## Event Type Constants

| Option | Description | Selected |
|--------|-------------|----------|
| Raw strings only | No constants module, string pattern matching | ✓ |
| Optional constants module | @payment_intent_succeeded etc. | |
| Atom conversion | Convert type to atom | |

**User's choice:** Raw strings only
**Notes:** 250+ types that change per API version. String `<>` matching works for wildcards.

---

## Plug Path Matching

| Option | Description | Selected |
|--------|-------------|----------|
| Optional at: | With at: for endpoint-level, without for router-level | ✓ |
| No at: option | Router-only mounting | |
| Require at: always | Mandatory, redundant with router | |

**User's choice:** Optional at:
**Notes:** Matches Plug.Static and stripity_stripe patterns. Supports both mounting strategies.

---

## Bang Variants

| Option | Description | Selected |
|--------|-------------|----------|
| Bang + dedicated exception | construct_event!/3, SignatureVerificationError with :message + :reason | ✓ |
| Bang + ArgumentError | Simpler but wrong semantics | |
| No bang variants | Breaks LatticeStripe convention | |

**User's choice:** Bang + dedicated exception

---

## Plug.Conn Assigns Naming

| Option | Description | Selected |
|--------|-------------|----------|
| :stripe_event | Namespaced, avoids collision | ✓ |
| :event | Short but collision risk | |
| Configurable | assign_key: option | |

**User's choice:** :stripe_event

---

## Code.ensure_loaded? Guard Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Plug + CacheBodyReader only | Guard modules that import Plug.Conn | ✓ |
| Plug + Handler + CacheBodyReader | Guard all Plug-related modules | |
| Everything under Webhook.* | Over-guards pure modules | |

**User's choice:** Plug + CacheBodyReader only
**Notes:** Handler is a pure behaviour (no Plug types). Exception must compile for bang variants.

---

## Plug Dep Handling

| Option | Description | Selected |
|--------|-------------|----------|
| plug_crypto required, plug optional | {:plug_crypto, "~> 2.0"} + {:plug, "~> 1.16", optional: true} | ✓ |
| plug required | Forces plug on all users | |
| Roll own HMAC | No plug_crypto, hand-roll compare | |

**User's choice:** plug_crypto required, plug optional

---

## Event Inspect Implementation

| Option | Description | Selected |
|--------|-------------|----------|
| Manual defimpl whitelist | Show id, type, object, created, livemode. Hide data, request, account, extra | ✓ |
| @derive {Inspect, except: [...]} | Concise but less control | |
| No custom Inspect | Leaks sensitive data | |

**User's choice:** Manual defimpl whitelist

---

## Webhook Public API Surface

| Option | Description | Selected |
|--------|-------------|----------|
| 5 functions confirmed | construct_event/4, !/4, verify_signature/4, !/4, generate_test_signature/3 | ✓ |
| Drop verify_signature | 3 functions only | |

**User's choice:** 5 functions confirmed

---

## Handler Return Validation

| Option | Description | Selected |
|--------|-------------|----------|
| Raise on invalid | RuntimeError with clear message listing expected returns | ✓ |
| No validation | Let any return through | |
| Warn but don't raise | Logger.warning | |

**User's choice:** Raise on invalid

---

## Plug Non-POST Handling

| Option | Description | Selected |
|--------|-------------|----------|
| 405 Method Not Allowed | With Allow: POST header, technically correct per HTTP spec | ✓ |
| 400 Bad Request | Like stripity_stripe | |
| Pass through | Only handle POST, ignore others | |

**User's choice:** 405 Method Not Allowed

---

## Event.from_map Error Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Infallible, fill nils | Follow existing resource pattern | ✓ |
| Validate required fields | Raise or return error on missing id/type | |
| Separate validate function | from_map stays infallible, add validate/1 | |

**User's choice:** Infallible, fill nils

---

## Webhook Logging

| Option | Description | Selected |
|--------|-------------|----------|
| No logging, defer telemetry to P8 | Libraries shouldn't log directly | ✓ |
| Logger.warning on failures | Helps debugging but couples to Logger | |
| Telemetry events in Phase 7 | Ship observability with the feature | |

**User's choice:** No logging, defer telemetry

---

## Documentation Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Inline docs in Phase 7 | @moduledoc + @doc following existing pattern | ✓ |
| Minimal docs, defer to P10 | Bare one-liner moduledocs | |
| No docs | Skip entirely | |

**User's choice:** Inline docs in Phase 7

---

## Event Retrieve/List Pattern

| Option | Description | Selected |
|--------|-------------|----------|
| Standard resource pattern | retrieve/list/stream + bang variants, read-only | ✓ |
| Retrieve only | No list/stream | |

**User's choice:** Standard resource pattern

---

## MFA Secret Resolution

| Option | Description | Selected |
|--------|-------------|----------|
| Support MFA + functions | {M,F,A} tuples and zero-arity fns, resolved in call/2 | ✓ |
| Static only | Only string/list | |

**User's choice:** Support MFA

---

## Webhook.Plug Test Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Plug.Test + generate_test_signature | Separate files for crypto and Plug tests | ✓ |
| Mox-based transport mocking | Overkill for inbound-only Plug | |
| Defer to Phase 9 | Minimal smoke tests only | |

**User's choice:** Plug.Test + generate_test_signature

---

## Claude's Discretion

- Internal HMAC implementation details
- NimbleOptions schema structure details
- File organization within webhook/ directory
- Test fixture organization

## Deferred Ideas

- Webhook telemetry events — Phase 8
- Integration tests against stripe-mock — Phase 9
- LatticeStripe.Testing webhook helpers — Phase 9
- Documentation guides — Phase 10
- Auto-parsing data.object into typed structs — future if requested
- Event type constants module — explicitly rejected
