# SEED-005 — Accrue Surface Closure (Entitlements + verified gaps)

Status: **CAPTURED — VERIFIED.** Ready to feed `/gsd-new-milestone` (v1.8.0).
Captured: 2026-07-27
Target: **Hex 1.8.0** (GSD milestone v1.10 — numbering diverges because v1.8/v1.9
were doc-only, no Hex bump). All work additive → minor bump.
Evidence: `.planning/research/accrue-gap-brief-2026-07-27.txt` (full brief, verified
against Accrue's vendored `lattice_stripe` 1.7.13 source, not inferred from docs).

> Provenance: an earlier background agent hallucinated a "v1.57/v1.58 /
> Phase 211-217 / 25 REQ-IDs" structure that never existed on disk — all of it was
> discarded. This seed is rebuilt from the maintainer's verified gap brief.

---

## Why this exists (reopen justification)

`accrue` (the downstream billing lib) consumes `lattice_stripe`. It pins `~> 1.1`
but locks 1.7.13, and its entire planning corpus reasons against 1.1. It has a
**verified, blocking** need for Stripe-native Entitlements plus a handful of surface
gaps. Maintenance mode reserved exactly one reopen trigger — "new resource family
with documented adopter pull" — and this is it. Recorded in `.planning/PROJECT.md`
under "Reopen for Adopter Pull (2026-07-27)".

**Framing correction (important):** roughly *half* of accrue's recorded
"lattice_stripe gaps" already shipped upstream (see §4). So the single highest-ROI
item is not code — it's a migration note telling accrue what already landed.

---

## Scope decisions (locked 2026-07-27)

- **Milestone scope:** the brief's "if you only do five things" list + Product.Feature
  (§1–§2 below + the finch fix + Product↔Feature). Lower-priority DX (brief §3.2–3.11)
  is deferred to **SEED-006**, not this milestone.
- **Finch fix approach:** ship an optional `LatticeStripe.Application` that starts a
  default `LatticeStripe.Finch` pool and **default the `:finch` option** to it (relax
  `required: true`, drop from `@enforce_keys`). Backwards-compatible.

---

## P0 — Genuinely missing, blocks already-designed accrue work

### 1.1  `LatticeStripe.Entitlements.*` — THE ask (top priority by a wide margin)
Verified absent (`grep -ril entitlement lib` → 0 in 1.7.13).
- `Entitlements.ActiveEntitlement`: `list/3`, `stream!/3`, `retrieve/3` over
  `/v1/entitlements/active_entitlements` (customer filter).
- `Entitlements.Feature`: create/retrieve/update/list over `/v1/entitlements/features`.

**Design constraint (shapes the API):** accrue consumes this in a **reconciler**,
never on the entitlement gate path — enforced by a merge-blocking CI gate
(`accrue/scripts/ci/verify_entitlement_sync_isolation.sh`). **Build a pull/pagination
shape (`list`/`stream!`). Do NOT build a per-request `entitled?(customer, feature)`
helper** — accrue can't use it and it invites hosts to put a network call on their
auth path.

Accrue scars proving the need:
- Its entitlement webhook reducer is the *only* non-refetch-canonical reducer
  (`accrue/lib/accrue/webhook/default_handler.ex:485-490`), forced into
  monotonic-snapshot mode — a correctness weakness, not style.
- It already persists the pagination handle waiting for us
  (`accrue/lib/accrue/billing/entitlement_summary.ex:14-16`).
- Stripe inlines ≤10 entitlements + `has_more`; accrue can't follow the cursor, so
  it ships a `[:accrue, :ops, :entitlement_summary_truncated]` telemetry event + a
  `truncated` DB column purely to admit the gap (`accrue/guides/telemetry.md:463`).
- Standing deferral whose revisit trigger is *literally our release*
  (`accrue/.planning/STATE.md:717`, `.../v1.39-REQUIREMENTS.md:56`).

**Caveat:** `active_entitlement_summary` has **no top-level `id`** — deserializer
and id-keyed logic must tolerate that (`accrue/lib/accrue/billing/entitlement_summary.ex:9-13`).

### 1.2  Product ↔ Feature attachment (`/v1/products/:id/features`) — highest long-term product leverage
Verified partial: `Product.features`/`marketing_features` exist as raw untyped
`[map()]` (`product.ex:67,100,408`); no `Product.Feature` module, no attach endpoints.
- Add `Product.Feature` create/list/delete + type the existing `features` field.
- Why: accrue's entitlement catalog is 100% duplicated host config
  (`accrue/lib/accrue/config.ex:453-541`) that drifts silently from Stripe. With
  Product.Feature reads, accrue can *derive* the catalog from Stripe + ship real
  drift detection — kills a class of "paid but no feature" tickets.

---

## P1 — Genuinely missing, blocks queued accrue work

### 2.1  Meter event summaries (`GET /v1/billing/meters/:id/event_summaries`)
Verified absent — billing/ has all four meter WRITE surfaces and **no read**.
- `Billing.Meter.EventSummary.list/4` (+ `stream!`); params: customer, start_time,
  end_time, value_grouping_window.
- Why: accrue has **zero usage-read surface** — can push meter events, never read
  totals back. Blocks accrue's SEED-004 M3 "Usage / meters" admin room and any
  customer-facing "usage this period". **Do NOT build more metering writes** — accrue
  uses exactly one (`Billing.MeterEvent.create/3`) and ignores the rest.
- Docs contract to confirm: `MeterEvent.create/3` accepts arbitrary custom `payload`
  dimensions + decimal-string `value`s (accrue currently drops the host `:payload`).

### 2.2  ObjectTypes registrations + fixtures — cheapest high-value win
`object_types.ex` (~48 entries) is missing:
`entitlements.active_entitlement`, `entitlements.active_entitlement_summary`,
`billing.meter_event` (module already exists — registrable as-is),
`billing.meter_event_summary`, `billing.meter_error_report`. Each key must match the
wire `"object"` string verbatim → a module with `from_map/1`. Model
`Billing.MeterErrorReport` for the last.
- Cost to accrue today: its webhook handler scavenges raw maps by trial and error —
  even looking for the entitlement summary under a *meter* key
  (`accrue/lib/accrue/webhook/default_handler.ex:798-809`).
- **Bonus (cheap):** add public `Testing.Fixtures` for entitlement summary + meter
  objects + core billing (subscription, invoice, customer, payment_intent). Accrue
  hand-built a 76-line entitlement-summary fixture because none exists
  (`accrue/test/support/stripe_fixtures.ex:403-479`).

---

## P2 (in-scope) — DX

### 3.1  `finch:` required → default pool  ** live accrue bug **
`finch:` is `required: true` (`config.ex:69-74`) + `@enforce_keys` (`client.ex:51`),
and accrue never passes it → its live Stripe lane **raises on every call** (invisible
because CI uses a Fake). Fix = optional `LatticeStripe.Application` + default pool
(decision above). Prevents the footgun for *every* consumer.

### 3.3 / 3.4 / 3.10 (folded into Wave 3)
- `Error` struct has no `headers`/`retry_after` → accrue's `RateLimitError.retry_after`
  is permanently nil (`error.ex:91-102`; Stripe sends `Retry-After` as a header).
- Promote `Webhook.CacheBodyReader` out of `@moduledoc false` — it's the single most
  copy-pasted thing in Stripe-on-Elixir integrations (accrue duplicated 52 lines).
- Doc it permanently: `Charge.create` will never exist; `PaymentIntent.create(confirm:
  true)` is the sanctioned path.

---

## §4 — DO NOT BUILD: already shipped in 1.7.13 (accrue's docs are wrong)

**Action item: publish a "1.1 → 1.7 what landed" migration guide** (`guides/`).
Zero code; unblocks four accrue deferrals + surfaces two live accrue bugs. Already
shipped & unconsumed by accrue: BillingPortal.Configuration, Charge.list/search,
TestHelpers.TestClock, Testing.Fixtures, Dispute, Tax.*, CreditNote, Payout, Quote,
BalanceTransaction, EventNotification (thin events). BillingPortal.Configuration is
notable — it unblocks an accrue *threat mitigation* (portal-cancel dunning bypass).

---

## §5 — DO NOT BUILD (accrue non-goals)
Sigma, Reporting/RevRec, Radar, Terminal, Payment Links, standalone Credit
Notes/Quotes. (Scoped to the accrue consumer; weigh separately if lattice_stripe
pursues general coverage.)

---

## §6 — Stability contracts to FREEZE (breaking these is worse than shipping nothing)
1. `nil stripe_account` → the `Stripe-Account` header is **omitted** (not sent empty).
2. Per-request opts override per-client settings.
3. `api_version` default `"2026-03-25.dahlia"` (a public accrue marketing claim).
4. `Client.new!/1` takes a **keyword list** (not a bare api_key string).

---

## Next action
`/gsd-new-milestone` v1.8.0 "Accrue Surface Closure" using this seed as input →
REQUIREMENTS + ROADMAP → discuss→plan→execute. Recommended start: **Wave 0**
(migration guide + finch fix), then Entitlements (Wave 1). Post-tag: bump accrue's
`~> 1.1` pin, delete its Charge.list 501 shim + finch footgun, wire the reconciler
to the new `stream!`. Deferred DX (brief §3.2, 3.5–3.9, 3.11) → **SEED-006**.
