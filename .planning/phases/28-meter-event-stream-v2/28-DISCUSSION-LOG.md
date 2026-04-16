# Phase 28: meter_event_stream v2 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-16
**Phase:** 28-meter-event-stream-v2
**Areas discussed:** Session lifecycle management, Transport/auth integration, API surface design, Error handling for session expiry, Testing strategy
**Mode:** --auto (all decisions auto-selected)

---

## Session Lifecycle Management

| Option | Description | Selected |
|--------|-------------|----------|
| Stateless (caller manages token) | create_session returns struct, caller holds and passes to send_events | ✓ |
| GenServer session manager | Process that auto-refreshes sessions | |
| Functional wrapper with auto-check | Higher-level function that manages session internally | |

**User's choice:** [auto] Stateless — caller manages token (recommended default)
**Notes:** Consistent with LatticeStripe's pure-functional, no-process philosophy. PROJECT.md: "processes only when truly needed."

---

## Transport / Auth Integration

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse Transport with different headers | Build v2 headers in MeterEventStream, call transport.request/1 | ✓ |
| New Transport behaviour method | Add a v2_request callback to Transport | |
| Separate HTTP module | Dedicated v2 HTTP module bypassing Transport | |

**User's choice:** [auto] Reuse Transport behaviour with different headers (recommended default)
**Notes:** Transport contract is auth-agnostic. Only the header construction differs for v2.

---

## API Surface Design

| Option | Description | Selected |
|--------|-------------|----------|
| Two-function explicit API | create_session/2 + send_events/3, no hidden state | ✓ |
| Single stream/3 with auto-session | Higher-level function that manages session lifecycle | |
| Three-function with convenience wrapper | create_session + send_events + with_session helper | |

**User's choice:** [auto] Two-function explicit API (recommended default)
**Notes:** Matches success criteria exactly. More Elixir-idiomatic. Aligns with stripe-python/ruby.

---

## Error Handling for Session Expiry

| Option | Description | Selected |
|--------|-------------|----------|
| Client-side check + server passthrough | Check expires_at locally, normalize server errors to same atom | ✓ |
| Server-only | Let server handle all expiry detection | |
| Auto-renewal | Automatically create new session on expiry | |

**User's choice:** [auto] Client-side expiry check + server-side error passthrough (recommended default)
**Notes:** Saves network round-trip on known-expired sessions. No surprises — no automatic renewal.

---

## Testing Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Probe stripe-mock; Mox fallback | Check v2 support first, fall back to mocked unit tests | ✓ |
| Mox-only | Skip stripe-mock entirely for v2 | |
| Block on stripe-mock support | Wait until stripe-mock adds v2 endpoints | |

**User's choice:** [auto] Probe stripe-mock first; Mox fallback for unit tests (recommended default)
**Notes:** Success criterion #4 explicitly allows documented skip. Pragmatic approach.

---

## Claude's Discretion

- Internal module organization (Session struct placement)
- Telemetry metadata fields
- Whether to add convenience `with_session/3`
- Documentation structure (new guide vs extend existing metering guide)

## Deferred Ideas

None — discussion stayed within phase scope
