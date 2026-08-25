# Phase 67: DX Hardening & Milestone Doc Close - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-25
**Phase:** 67-dx-hardening-milestone-doc-close
**Areas discussed:** HTTP error response metadata, public webhook body reader, Charge creation policy documentation, milestone documentation close

---

## HTTP Error Response Metadata

| Option | Description | Selected |
|--------|-------------|----------|
| Headers only | Preserve raw response evidence and let every consumer interpret Retry-After. Simple core API, but repetitive and less discoverable for the dominant rate-limit job. | |
| Parsed value only | Expose a convenient retry delay, but discard duplicate/raw headers and make future diagnostics or provider metadata unavailable. | |
| Headers plus uncapped parsed seconds | Preserve ordered raw headers and add a narrow `retry_after` convenience derived from valid delay-seconds, independent of internal retry caps. | ✓ |
| Strategy delay | Expose the retry engine's capped millisecond delay. Easy to implement, but conflates transport evidence with policy and surprises consumers. | |

**User's choice:** Option 1 in the final package-selection prompt, accepting the complete recommendation set.
**Notes:** Research compared Stripe SDK error metadata, HTTP Retry-After semantics, current client/retry flow, and idiomatic immutable Elixir structs. HTTP-date remains available raw but is not parsed in this phase.

---

## Public Webhook Body Reader

| Option | Description | Selected |
|--------|-------------|----------|
| Remain private | Avoid a semver commitment, but leave a documented advanced Phoenix/Plug integration dependent on a nonpublic helper. | |
| Promote unchanged | Smallest diff, but freezes a latent bug where successive `:more` chunks overwrite earlier bytes. | |
| Hardened minimal public API | Fix ordered chunk accumulation, expose only `read_body/2`, retain `conn.private[:raw_body]`, and document optional Plug support and memory/security costs. | ✓ |
| Configurable storage abstraction | Support arbitrary keys/backends/spooling. Flexible, but far beyond the current job and adds permanent surface area without demonstrated need. | |

**User's choice:** Option 1 in the final package-selection prompt, accepting the complete recommendation set.
**Notes:** The selected approach follows Plug's body-reader callback and `conn.private` conventions. Mounting the webhook plug before parsers remains the preferred path; CacheBodyReader is the advanced fallback.

---

## Charge Creation Policy Documentation

| Option | Description | Selected |
|--------|-------------|----------|
| Moduledoc only | Keeps policy close to the absent API, but misses workflow-oriented readers. | |
| Payments guide only | Gives richer workflow context, but leaves module/API explorers without a durable answer. | |
| Full explanation everywhere | Maximizes repetition, but creates drift, noisy docs, and brittle broad-text tests. | |
| Two canonical surfaces | Put the complete durable policy in the Charge moduledoc and Charge-reconciliation guide section, with only a compact README cue. | ✓ |

**User's choice:** Option 1 in the final package-selection prompt, accepting the complete recommendation set.
**Notes:** The guide must cover both the direct server-side PaymentIntent replacement (`"confirm" => true`) and client-side confirmation/SCA flows. Public prose must explain the consumer job, not internal phase-decision history.

---

## Milestone Documentation Close

| Option | Description | Selected |
|--------|-------------|----------|
| Plan cleanup from stale count | Treat the earlier 38-warning report as current and create cleanup tasks. Conflicts with live repository evidence. | |
| Differential warning baseline | Allow known warnings while blocking new ones. Useful during migration, but unnecessary and weaker than the current zero-warning state. | |
| Accept live zero-warning evidence | Plan no warning cleanup, retain strict local/CI gates, and rerun the milestone audit after Phase 67. | ✓ |
| Rewrite the old audit | Make historical paperwork look current, but destroy the audit trail and obscure when evidence was collected. | |

**User's choice:** Option 1 in the final package-selection prompt, accepting the complete recommendation set.
**Notes:** `mix docs --warnings-as-errors` passed at the current HEAD. The existing milestone audit remains historical; normal state and re-audit mechanisms should capture current truth.

---

## the agent's Discretion

- Exact prose, headings, test names, and internal helper factoring within the locked contracts.
- Whether error header lookup shares a private helper with `LatticeStripe.Response`.
- Exact placement of security, memory, and Phoenix process-model cautions within the relevant guides.

## Deferred Ideas

- HTTP-date parsing for `Retry-After`.
- Configurable or disk-backed webhook body storage and multipart support.
- Broader SEED-006 DX work, including signature-error unification.
- Retry-policy, scheduler, queue, or global-rate-limiter changes.
- The two already-tracked flaky tests.
- Broad duplication of the Charge policy outside its canonical surfaces.

---

*Phase: 67-dx-hardening-milestone-doc-close*
*Discussion log generated: 2026-08-25*
