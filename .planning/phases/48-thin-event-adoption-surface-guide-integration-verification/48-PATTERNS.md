# Phase 48: Thin-Event Adoption Surface - Pattern Map

**Mapped:** 2026-05-27
**Files analyzed:** 9 (2 created, 7 modified)
**Analogs found:** 9 / 9 (all in-repo, no external pattern fallback needed)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `guides/webhooks-thin-events.md` (NEW) | guide (Operations & DX sibling) | docs-prose / cross-link graph | `guides/webhooks.md` | exact (sibling trust rail) |
| `test/lattice_stripe/webhook/thin_event_test.exs` (NEW) | test (Mox-at-Transport chained roundtrip) | request-response (mocked) | `test/lattice_stripe/webhook/fetch_test.exs` | exact (same idiom + extension) |
| `test/lattice_stripe/docs_truth_test.exs` (MOD) | test (grep regression) | file-IO + regex match | self (extends own file with 4 patterns 3A-3E) | exact (in-file idiom) |
| `lib/lattice_stripe/webhook/plug.ex` (MOD) | module (`@moduledoc` extension) | doc-string surface | self lines 110-116 (`Configuration Options` block) | exact (one-line extension) |
| `guides/webhooks.md` (MOD) | guide (reverse-link section) | docs-prose | self ("See also" + footnote pattern) | exact (in-file extension) |
| `README.md` (MOD) | top-level surface map | docs-prose | self lines 31-42 / line 126 | exact (in-file extension) |
| `guides/user-flows-and-jtbd.md` (MOD) | guide (JTBD routing layer) | docs-prose | self lines 75-95 / 311-338 | exact (in-file extension) |
| `mix.exs` (MOD) | config (ExDoc placement) | static config list | self lines 40-52 / 81-94 (`extras` + `Operations & DX` group) | exact (symmetric `webhooks.md` template) |
| `CHANGELOG.md` (MOD) | release notes | docs-prose | self lines 9-28 (existing `[1.5.0]` block) | exact (append-bullet idiom) |

## Pattern Assignments

### `test/lattice_stripe/webhook/thin_event_test.exs` (NEW — test, chained-roundtrip Mox-at-Transport)

**Analog:** `test/lattice_stripe/webhook/fetch_test.exs` (378 lines, direct idiom template per RESEARCH.md §Test Idiom Template Survey)

**Module header + imports pattern** (`fetch_test.exs` lines 1-13):
```elixir
defmodule LatticeStripe.Webhook.FetchTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers
  import LatticeStripe.Test.Fixtures.Event, only: [event_map: 1]
  import LatticeStripe.Test.Fixtures.EventNotification
  import LatticeStripe.Test.Fixtures.Customer, only: [customer_json: 1]

  alias LatticeStripe.{Customer, Error, Event, EventNotification, Webhook}
  alias LatticeStripe.EventNotification.RelatedObject

  setup :verify_on_exit!
```
- **Copy directly.** Change module name to `LatticeStripe.Webhook.ThinEventTest`. Add `Testing` to the alias list. Add `@secret "whsec_test_thinevent"` module attr.
- **`async: true` is load-bearing** — Mox boundary, no shared state. Do NOT tag `:integration` (Phase 48 D-02 + CONTEXT.md "Established Patterns": `:integration` means real-HTTP stripe-mock precondition; this file is Mox-at-Transport).
- **`setup :verify_on_exit!`** enforces zero-HTTP on fail-fast paths (typed-error branches must NOT call `expect(LatticeStripe.MockTransport, :request, ...)` — see lines 50-57, 199-219 for the no-expect pattern).

**Mox `expect` + URL assertion pattern** (`fetch_test.exs` lines 20-34):
```elixir
test "sends GET /v2/core/events/{id} and returns {:ok, %Event{}}" do
  client = test_client()
  notif = EventNotification.from_map(event_notification_map())

  expect(LatticeStripe.MockTransport, :request, fn req ->
    assert req.method == :get
    assert String.contains?(req.url, "/v2/core/events/#{notif.id}")
    refute String.contains?(req.url, "/v1/events/")
    ok_response(event_map(%{"id" => notif.id}))
  end)

  assert {:ok, %Event{id: id}} = Webhook.fetch_event(client, notif)
  assert id == notif.id
end
```
- **Pattern:** `client = test_client()` → build notif from fixture → `expect/3` arrow asserts request shape + returns `ok_response/1` → assert typed struct decode.
- Chained-roundtrip extension: replace the bare `EventNotification.from_map(...)` with `Testing.generate_thin_event_payload/3` → `Webhook.parse_event_notification/4` BEFORE the `expect/3`. This is the load-bearing addition for VERIFY-03 per RESEARCH.md §Test Idiom Template Survey.

**Zero-HTTP fail-fast pattern** (`fetch_test.exs` lines 50-57, 199-219, 221-227):
```elixir
test "returns {:error, :no_event_id} for %EventNotification{id: nil} (no HTTP)" do
  client = test_client()
  # No expect(LatticeStripe.MockTransport, ...) call — :verify_on_exit!
  # enforces that zero transport requests are made on this code path.
  assert {:error, :no_event_id} =
           Webhook.fetch_event(client, %EventNotification{id: nil})
end
```
- **Pattern:** Omit `expect/3`. The `setup :verify_on_exit!` callback verifies the mock was NOT called, which is the fail-fast contract proof. Use this for `:no_matching_signature`, `:missing_header`, `:invalid_header` cases in the new malformed-payload describe block.

**`describe` block organization** (`fetch_test.exs` lines 19, 135, 174, 304):
- One `describe` per helper signature variant: `"fetch_event/3"`, `"fetch_event!/3"`, `"fetch_related_object/3"`, `"fetch_related_object!/3"`.
- New file mirrors this with describe-per-VERIFY-03-must-have:
  1. `describe "verify happy path (Testing → parse)"`
  2. `describe "fetch-after-verify roundtrip — Event branch (parse → fetch_event)"`
  3. `describe "fetch-after-verify roundtrip — RelatedObject branch (parse → fetch_related_object)"`
  4. `describe "malformed-payload failure boundary"`
  5. `describe "tolerance: 0 reconciled semantics on the thin-event surface"`

**Test helper imports source** (`test/support/test_helpers.ex` lines 1-13, 31-38):
```elixir
def test_client(overrides \\ []) do
  defaults = [
    api_key: "sk_test_123",
    finch: :test_finch,
    transport: LatticeStripe.MockTransport,
    telemetry_enabled: false,
    max_retries: 0
  ]
  Client.new!(Keyword.merge(defaults, overrides))
end

def ok_response(body) do
  {:ok, %{status: 200, headers: [{"request-id", "req_test"}], body: Jason.encode!(body)}}
end
```
- `max_retries: 0` is critical for `async: true` — prevents retry-storm noise on Mox-returned error responses.

---

### `guides/webhooks-thin-events.md` (NEW — guide, Operations & DX sibling)

**Analog:** `guides/webhooks.md` (216 lines, sibling trust rail) — mirror section ordering, adjusted for controller-owned dispatch.

**Opening anchor pattern** (`webhooks.md` lines 1-13):
```markdown
# Webhooks

Stripe webhooks are how your application learns what actually became true after an
API call. Your app can start a payment, subscription update, dispute workflow, or
quote flow, but webhooks confirm whether Stripe later accepted, finalized, failed,
or retried that work.

If you only keep one rule from this guide, keep this one:

**Your app starts work. Webhooks confirm reality.**

For Stripe's full event and delivery reference, see
[Stripe Webhooks](https://docs.stripe.com/webhooks).
```
- **Mirror this opening.** New guide MUST contain the substring `Webhooks confirm` (D-03 3A grep lock; Phase 44 D-14 anchor).
- Add a one-paragraph snapshot-vs-thin orientation just after the anchor.

**Section ordering pattern** (`webhooks.md` H2 sequence):
1. `## The raw-body invariant` (lines 15-29) — cross-link back to this in new guide rather than re-explaining (Phase 44 D-24 discipline)
2. `## Canonical Phoenix quickstart` (lines 31-107) — sub-sections `### 1. Mount...`, `### 2. Implement a handler module`
3. `## What to do with the event` (lines 109-120)
4. `## Local testing` (lines 122-150)
5. `## Advanced alternative: ...` (lines 152-180)
6. `## Troubleshooting` (lines 182-204)
7. `## See also` (lines 206-216)

- **Adapted ordering for thin-event guide** (D-01 + RESEARCH.md): raw-body invariant cross-link → Phoenix controller spine (NOT Plug+handler) → fetch-after-verify worked example → idempotency sketch (Ecto schema per RESEARCH.md §Idempotency Sketch Recommendation) → rate-limit guidance (must contain `100 req/s` AND `90/s`) → Connect `event.context` aside → testing (`stripe-mock /v2/` gap one-liner) → see also.

**Phoenix controller code-block pattern** (`webhooks.md` lines 73-103):
- Triple-backtick `elixir` fenced block.
- Module name `MyApp.StripeWebhookHandler` / `MyAppWeb.StripeThinEventController` (lib namespace + Web suffix for controller).
- `@behaviour` / `use MyAppWeb, :controller` import directives match adopter Phoenix conventions.
- Thin actions: pattern-match + delegate. No business logic in the controller body (Phase 45 D-04 + D-27 library-scoped framing).
- **Critical correction from RESEARCH.md §Phoenix Controller Idiom:** Use `conn.private[:raw_body]` NOT `conn.assigns.raw_body` (the CONTEXT.md `<specifics>` block has drift; verified against `lib/lattice_stripe/webhook/cache_body_reader.ex:21,25`).

**Local-testing section pattern** (`webhooks.md` lines 122-150):
```markdown
For application tests, `LatticeStripe.Testing.generate_webhook_payload/3` builds a
signed payload/header pair that passes `LatticeStripe.Webhook.construct_event/4`:

\`\`\`elixir
alias LatticeStripe.Testing
alias LatticeStripe.Testing.Fixtures

@webhook_secret "whsec_test_secret"

{payload, sig_header} =
  Testing.generate_webhook_payload(
    "quote.accepted",
    Fixtures.Quote.accepted_quote_json(),
    secret: @webhook_secret
  )
\`\`\`

See [Testing](testing.md) for the public fixture-builder surface.
```
- **Mirror this pattern** with `Testing.generate_thin_event_payload/3`. Add the stripe-mock `/v2/` gap one-liner from CONTEXT.md `<specifics>` lines 274-275.

**See also pattern** (`webhooks.md` lines 206-216):
```markdown
## See also

- [Checkout Signup and Portal Follow-Through](checkout-signup-and-portal.md)
- [Connect Platform Flow](connect-platform-flow.md)
- ...
- [Testing](testing.md)
- [Error Handling](error-handling.md)
```
- **Forward-link requirements (D-03 3D):** new guide MUST link to `webhooks.md`, `testing.md`, `error-handling.md` as Markdown link refs.

---

### `guides/webhooks.md` (MOD — add closing "Thin events (`/v2/events`)" section)

**Analog:** `webhooks.md` self — extend AFTER existing "See also" section (lines 206-216).

**Reverse-link section shape** (per CONTEXT.md `<specifics>` lines 277-286):
```markdown
## Thin events (`/v2/events`)

Stripe also delivers **thin events** to `/v2/event-destinations` endpoints.
A thin event payload carries only `{id, type, related_object}` — your app
fetches authoritative state after verification. See
[Webhooks: Thin Events](webhooks-thin-events.md) for the canonical Phoenix
pattern, fetch-after-verify idempotency, and rate-limit guidance.
```
- **Both substrings required** for D-03 3D grep lock: lowercase `thin event` (in body prose, not just the link text `Thin Events`) AND `webhooks-thin-events.md`.
- **Placement:** AFTER `## See also` so the trust rail's first impression (snapshot quickstart) stays stable.
- **Length:** ~6 lines per CONTEXT.md `<specifics>`.

---

### `test/lattice_stripe/docs_truth_test.exs` (MOD — 4 patterns 3A/3B/3C/3D + 3E)

**Analog:** self — extend with 4 new test blocks; 1 in-file edit to existing test.

**File-read + grep pattern** (`docs_truth_test.exs` lines 42-56 `"readme routes evaluators..."`):
```elixir
test "readme routes evaluators into the guide ladder and published 1.3 line" do
  readme = File.read!("README.md")

  assert readme =~ "guides/user-flows-and-jtbd.md"
  assert readme =~ "guides/subscriptions.md"
  # ...
  assert readme =~ "{:lattice_stripe, \"~> 1.3\"}"
  refute readme =~ "What's new in v1.1"
end
```
- **Pattern:** `File.read!` → series of `assert source =~ "substring"` (and `refute` for negative locks).
- **No `describe` blocks** in this file — flat `test "..."` is the established convention (line 1: `use ExUnit.Case, async: true`).

**ExDoc placement extension pattern** (`docs_truth_test.exs` lines 8-40):
```elixir
test "exdoc keeps the primary public truth surfaces published" do
  docs = docs_config()
  extras = docs[:extras]
  groups = docs[:groups_for_extras] |> Map.new()

  # ... existing assertions
  assert "guides/webhooks.md" in groups["Operations & DX"]
  assert "guides/testing.md" in groups["Operations & DX"]
end
```
- **D-03 3C edit:** extend in-place (do NOT add a new test). Add `assert "guides/webhooks-thin-events.md" in extras` and `assert "guides/webhooks-thin-events.md" in groups["Operations & DX"]`.

**Regex grep pattern for `@moduledoc` (3E)** — analog: existing WEBFIX-01 changelog grep (`docs_truth_test.exs` lines 175-186):
```elixir
test "CHANGELOG.md documents WEBFIX-01 reconciliation under v1.5" do
  # WEBFIX-01 / Phase 47 D-03 regression-prevention contract: a future
  # "fix it to be stricter" PR that silently drops the CHANGELOG entry
  # MUST fail this grep test. The inline source comment + this test +
  # the function-boundary test + the Plug-boundary test together
  # triangulate the decision so the drift cannot silently come back.
  changelog = File.read!("CHANGELOG.md")

  assert changelog =~ "WEBFIX-01"
  assert changelog =~ ~r/##\s*\[?1\.5/
end
```
- **Comment block convention** — multi-line block comment above each new lock test that names the regression-prevention contract.
- **Regex flavor for `Webhook.Plug @moduledoc`** — RESEARCH.md §Webhook.Plug @moduledoc Extension recommends `~r/@moduledoc.*tolerance.*0.*testing only/s` (the `s` dotall flag is load-bearing because `@moduledoc` triple-quote strings span newlines).

**New-block placement convention:**
- Existing test order: ExDoc placement → README → getting-started → JTBD/recipes → flagship-guides → cheatsheet → CHANGELOG 1.3 → CHANGELOG 1.5 WEBFIX-01.
- **Recommended insertions** (RESEARCH.md §Docs-Truth Regression Pattern):
  - 3A — append new `test "webhooks-thin-events guide locks the thin-event adopter contract"` block at end of file (after WEBFIX-01 test).
  - 3B — append new `test "webhooks-thin-events guide is the v1.5 install-line canary"` block (separate test, single-line lock).
  - 3D — new sibling block `test "webhooks-thin-events guide is cross-linked from README/JTBD/webhooks.md"` (RESEARCH.md recommends splitting, not folding into flagship-guides test).
  - 3E — new block `test "Webhook.Plug @moduledoc documents tolerance: 0 testing-only semantics"`.

---

### `lib/lattice_stripe/webhook/plug.ex` (MOD — one-line `@moduledoc` extension)

**Analog:** self lines 108-116 (existing "Configuration Options" block).

**Existing pattern** (`plug.ex` lines 108-117):
```
    ## Configuration Options

    - `:secret` (required) — Webhook signing secret. See "Secret Resolution" above.
    - `:handler` — Module implementing `LatticeStripe.Webhook.Handler`. If omitted,
      runs in pass-through mode.
    - `:at` — Mount path (e.g., `"/webhooks/stripe"`). When set, the plug only
      processes requests matching this path; other paths pass through. Non-POST
      requests to this path return `405 Method Not Allowed`.
    - `:tolerance` — Maximum age of the webhook timestamp in seconds (default: 300).
    """
```

**Replacement pattern (per CONTEXT.md D-03 3E + RESEARCH.md §Webhook.Plug @moduledoc Extension):**
```
    - `:tolerance` — Maximum age of the webhook timestamp in seconds (default: 300).
      Set `0` to disable the staleness check (testing only — see the inline comment
      on `LatticeStripe.Webhook.check_tolerance/2` and the v1.5 CHANGELOG WEBFIX-01 entry).
```
- **Three required substrings co-located in the `@moduledoc` block:** `tolerance`, `0`, `testing only` — match the 3E regex grep `~r/@moduledoc.*tolerance.*0.*testing only/s`.
- **Style consistency:** matches the prose convention of the `:at` description (two-line continuation, sentence case, backticks around literal values).
- **Cross-reference convention:** matches the existing NimbleOptions schema `doc:` string at line 145 ("Set 0 to disable the staleness check (testing only)") — keeps both surfaces aligned.

---

### `README.md` (MOD — hardening-ops route + Webhooks bullet expansion)

**Analog:** self lines 31-42 (Choose Your Route) + line 126 (Webhooks bullet).

**Choose Your Route pattern** (`README.md` lines 41-42):
```markdown
- **I am hardening ops and support paths**:
  [Error Handling](guides/error-handling.md), [Testing](guides/testing.md), [Webhooks](guides/webhooks.md)
```
- **Edit:** append `[Webhooks: Thin Events](guides/webhooks-thin-events.md)` to the list.
- **Link-text convention:** title-case "Webhooks: Thin Events" matches sibling guide naming.

**"What's already in the box" Webhooks bullet pattern** (`README.md` line 126):
```markdown
- Phoenix-ready `Webhook.Plug` with raw-body capture and signature verification
```
- **Edit (per CONTEXT.md D-04 + RESEARCH.md):** expand to surface `thin-event` AND `/v2/events`. Suggested wording:
```markdown
- Phoenix-ready `Webhook.Plug` snapshot path + thin-event (`/v2/events`) helpers for fetch-after-verify integration
```
- **Do NOT touch the v1.3 Release status block** (per CONTEXT.md D-04 + deferred items; release prep is out of phase scope).
- **Do NOT flip the `~> 1.3` install line** (per D-03 3B canary architecture).

---

### `guides/user-flows-and-jtbd.md` (MOD — Start Here route + Job 7 Read next)

**Analog:** self lines 75-95 (Start Here) + lines 311-338 (Job 7).

**Start Here route pattern** (`user-flows-and-jtbd.md` lines 93-94):
```markdown
- **Runtime truth, support, and debugging**:
  [Webhooks](webhooks.md), [Error Handling](error-handling.md), [Testing](testing.md)
```
- **Edit:** append `[Webhooks: Thin Events](webhooks-thin-events.md)` to the list.

**Job 7 Read next pattern** (`user-flows-and-jtbd.md` lines 331-338):
```markdown
Read next:

- [Testing](testing.md)
- [Telemetry](telemetry.md)
- [OpenTelemetry](opentelemetry.md)
- [Circuit Breaker](circuit-breaker.md)
- [Performance](performance.md)
- [Webhooks](webhooks.md)
```
- **Edit:** append `[Webhooks: Thin Events](webhooks-thin-events.md)` as a new bullet (planner discretion on placement order; recommended last to preserve the Phase 47 v1.4 ordering).
- **Do NOT add a new Job 8** (per CONTEXT.md D-04 + deferred items: thin-events is an evolution of Job 7, not a peer job).

---

### `mix.exs` (MOD — add new guide to `extras` + `Operations & DX` group)

**Analog:** self lines 44 (`extras`) + line 84 (`groups_for_extras` → `Operations & DX`) — symmetric `webhooks.md` template.

**`extras` list pattern** (`mix.exs` lines 40-52):
```elixir
extras: [
  # ...
  "guides/customer-portal.md",
  "guides/webhooks.md",          # <-- insert NEW after this line
  "guides/error-handling.md",
  "guides/testing.md",
  # ...
],
```
- **Edit:** insert `"guides/webhooks-thin-events.md",` immediately after `"guides/webhooks.md",`.

**`groups_for_extras` → `Operations & DX` pattern** (`mix.exs` lines 81-94):
```elixir
{"Operations & DX",
 [
   "guides/client-configuration.md",
   "guides/webhooks.md",                # <-- insert NEW after this line
   "guides/error-handling.md",
   "guides/testing.md",
   # ...
 ]},
```
- **Edit:** insert `"guides/webhooks-thin-events.md",` immediately after `"guides/webhooks.md",` in the `Operations & DX` group.
- **Symmetry:** both insertions adjacent to `webhooks.md` — the sidebar order puts the v2 sibling immediately under the v1 trust rail per RESEARCH.md §ExDoc `groups_for_extras` Placement Strategy.

---

### `CHANGELOG.md` (MOD — append bullet to existing `[1.5.0]` section)

**Analog:** self lines 9-28 (existing `[1.5.0]` block from Phase 47).

**Existing `[1.5.0]` block pattern** (`CHANGELOG.md` lines 9-28):
```markdown
### [1.5.0] — Thin-Event SDK Surface & Webhook Reconciliation

> Pre-release notes for the upcoming v1.5 line. The mix.exs version bump
> happens at release time outside this entry's scope.

#### Fixed

- **WEBFIX-01 — `Webhook.check_tolerance/2` `tolerance: 0` semantics reconciled.**
  Before this release, `tolerance: 0` returned `{:error, :timestamp_expired}`...
- **WEBFIX-01 — `Webhook.Plug` NimbleOptions `:tolerance` schema relaxed.**
  Changed from `:pos_integer` to `:non_neg_integer`...
```

**Append-bullet pattern** — planner choice (per RESEARCH.md):
- **Option A:** append to existing `#### Fixed` block (lower-friction; thematically aligned with WR-04 closure being a Fix).
- **Option B (RECOMMENDED):** add a new `#### Added` block (cleaner — GUIDE-03 + VERIFY-03 are new docs/test surface, not bug fixes).

**Suggested bullet shape (per RESEARCH.md §CHANGELOG entry):**
```markdown
- **GUIDE-03 + VERIFY-03 — Thin-event adoption surface published.** New canonical
  Phoenix thin-event guide `guides/webhooks-thin-events.md` documents
  `parse_event_notification/4` + `fetch_event/3` + `fetch_related_object/3` with
  fetch-after-verify idempotency keyed on `event.id`, the verification-vs-payload-shape
  failure boundary, the Stripe 100 req/s rate-limit ceiling, and Connect routing via
  `event.context`. Integration coverage in `test/lattice_stripe/webhook/thin_event_test.exs`
  proves the chained generate → parse → fetch flows under happy-path, malformed-payload,
  and `tolerance: 0` boundary conditions. Docs-truth regression in `docs_truth_test.exs`
  locks the new guide content and closes Phase 47 WR-04 by extending the
  `Webhook.Plug` `@moduledoc` `tolerance: 0` mention.
```
- **Style match:** bold-prefix REQ-ID + sentence-case summary, matching the WEBFIX-01 entries above.

## Shared Patterns

### `async: true` + Mox at Transport boundary
**Source:** `test/lattice_stripe/webhook/fetch_test.exs:1-13` + `test/support/test_helpers.ex:6-16`
**Apply to:** `test/lattice_stripe/webhook/thin_event_test.exs`

```elixir
use ExUnit.Case, async: true
import Mox
import LatticeStripe.TestHelpers
setup :verify_on_exit!
# test_client/0 returns a Client with transport: LatticeStripe.MockTransport
```

The `:verify_on_exit!` callback is the load-bearing primitive for fail-fast assertions — typed-error code paths simply omit `expect/3` and Mox verifies zero transport calls were made. Use this idiom for `:no_matching_signature`, `:missing_header`, `:invalid_header`, `:no_related_object`, `:unknown_object_type` test cases.

### File-read + grep regression lock
**Source:** `test/lattice_stripe/docs_truth_test.exs:42-56` + `:175-186`
**Apply to:** all D-03 sub-decisions 3A/3B/3D/3E

```elixir
source = File.read!("path/to/file")
assert source =~ "load-bearing substring"
# or for cross-line patterns:
assert source =~ ~r/multi.*line.*regex/s
```

Flat `test "..."` blocks, no `describe` grouping. Each test is independent and `async: true`-safe.

### Sibling-not-recipe guide framing
**Source:** `guides/webhooks.md` (216 lines) — Operations & DX trust rail; assertive, low-magic tone; one canonical path; cross-link aggressively rather than re-explain.
**Apply to:** `guides/webhooks-thin-events.md`

- Mirror section ordering (raw-body invariant via cross-link → quickstart spine → handler example → testing → see also).
- Stay ~140-180 lines (D-01 length calibration) — `webhooks.md` is 216 lines; thin-event sibling is slightly shorter because it cross-links to the raw-body invariant rather than re-explaining.
- One Phoenix controller spine + one idempotency sketch + footguns inline. No equal-weight alternatives (Phase 45 D-03 "one recommended path").

### Docs-truth canary architecture (B2 install-line pattern)
**Source:** `test/lattice_stripe/docs_truth_test.exs:54` (existing `~> 1.3` lock) + RESEARCH.md §D-03 3B
**Apply to:** new `test "webhooks-thin-events guide is the v1.5 install-line canary"`

- Existing tests at lines 54, 61, 165 continue to assert `~> 1.3` for README, getting-started, cheatsheet.
- New test asserts `~> 1.5` ONLY for `webhooks-thin-events.md`.
- Once v1.5 ships and someone flips the cross-cutting `~> 1.3` → `~> 1.5`, existing tests fail until lockstep completes — naturally enforcing the canary contract.

### Cross-link reverse-edge lock
**Source:** Phase 44 D-24 cross-link discipline as encoded in `docs_truth_test.exs:148-159`
**Apply to:** D-03 3D cross-link graph locks

```elixir
# Forward edge from new guide
thin = File.read!("guides/webhooks-thin-events.md")
assert thin =~ "webhooks.md"
assert thin =~ "testing.md"
assert thin =~ "error-handling.md"

# Reverse edge from parent + ladder
webhooks = File.read!("guides/webhooks.md")
assert webhooks =~ "webhooks-thin-events.md"
assert webhooks =~ "thin event"  # lowercase, in prose

readme = File.read!("README.md")
assert readme =~ "webhooks-thin-events.md"

jtbd = File.read!("guides/user-flows-and-jtbd.md")
assert jtbd =~ "webhooks-thin-events.md"
```

## No Analog Found

None. All 9 files have direct in-repo analogs at exact or extension match quality. The phase is intentionally low-novelty: it extends Phase 47 surface area with adopter-facing docs + chained-roundtrip tests + docs-truth locks, all of which have established templates.

## Metadata

**Analog search scope:**
- `test/lattice_stripe/webhook/` (Mox-at-Transport test idiom)
- `test/lattice_stripe/docs_truth_test.exs` (grep regression idiom)
- `test/support/` (helpers + fixtures)
- `guides/` (sibling guide ordering)
- `lib/lattice_stripe/webhook/plug.ex` (`@moduledoc` extension target)
- `mix.exs` (`extras` + `groups_for_extras` symmetric template)
- `README.md` + `guides/user-flows-and-jtbd.md` (discovery wiring)
- `CHANGELOG.md` (existing v1.5.0 entry pattern)

**Files scanned:** 12 (5 analog test files, 4 guide files, 3 config/top-level files)

**Pattern extraction date:** 2026-05-27

**Sources verified at source-line level:**
- `test/lattice_stripe/webhook/fetch_test.exs` lines 1-378 (full read)
- `test/lattice_stripe/docs_truth_test.exs` lines 1-186 (full read)
- `test/support/test_helpers.ex` lines 1-63 (full read)
- `guides/webhooks.md` lines 1-216 (full read)
- `lib/lattice_stripe/webhook/plug.ex` lines 100-148 (`@moduledoc` + schema block)
- `mix.exs` lines 40-96 (`extras` + `groups_for_extras` blocks)
- `README.md` lines 20-130 (route table + Webhooks bullet)
- `guides/user-flows-and-jtbd.md` lines 75-95 + 305-338 (Start Here + Job 7)
- `CHANGELOG.md` lines 1-40 (existing v1.5.0 block)
