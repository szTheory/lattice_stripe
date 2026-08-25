# Deferred Items — Phase 65

Follow-ups and out-of-scope discoveries recorded at phase close (65-06).

**Status update (UAT closeout):** item 1 is DONE — the rename shipped, and was widened beyond
the three `basic/1` builders to the whole non-conforming set (9 functions), because the API
surface lock was about to freeze the naming in place. Item 2 remains deferred, but is now
test-locked rather than merely documented. Items 3 and 4 are unchanged.

---

## 1. ~~The three meter fixtures expose `basic/1`~~ — DONE (UAT closeout)

- **Recorded by:** 65-03 (Rationale), reaffirmed by 65-05; carried forward here as the phase's
  standing follow-up.
- **What:** `LatticeStripe.Testing.Fixtures.MeterEvent.basic/1`,
  `...MeterEventSummary.basic/1` and `...MeterErrorReport.basic/1` are the **only** public fixture
  builders on the surface that do not use the `<object>_json/1` convention. Measured on disk at
  phase close: 15 of the 18 public fixture modules use `<object>_json` naming; exactly these 3 use
  `basic`.
- **Why they are that way:** not a competing naming decision. 65-02 promoted them under a
  "payload bodies and function names transfer unchanged" rule, so `basic/1` is an artifact of
  verbatim movement. 65-03 then resolved Q2 as `move-and-rename` and renamed
  `Subscription.basic/1` → `subscription_json/1`, which is what left these three as the outliers.
- **Why it is urgent-ish and cheap now:** these module and function names become semver-covered
  public API **at the Hex 1.8.0 tag**. Renaming before the tag costs three `@doc`/`@spec`/def
  renames plus their in-repo call sites. Renaming after the tag is a **breaking change** for
  adopters and needs a deprecation cycle.
- **Deliberately NOT done in Phase 65:** no plan in this phase instructed the rename, and 65-06's
  scope is prose corrections plus the gate. Renaming three public builders inside a closeout plan
  would be scope creep on a one-way public-API door.
- **Suggested fix:** rename to `meter_event_json/1`, `meter_event_summary_json/1` and
  `meter_error_report_json/1` in a single commit with their call sites, before tagging 1.8.0.
- **RESOLVED at UAT closeout**, and widened. Renaming only the three `basic/1` builders would
  have left the inconsistency in place: `list_response/1`, `with_items/1`, `paused/1`,
  `canceled/1`, `event/1` and `no_meter_found_event/1` were equally non-conforming. All 9 were
  renamed in one `!` commit. A conformance guard now lives in
  `test/lattice_stripe/testing/wrapper_completeness_test.exs`' sibling checks and, more
  durably, in `priv/api/current.txt` — the fixture surface is now semver-locked, so a future
  drift is a visible diff rather than a silent one.

---

## 2. `entitlements.active_entitlement_summary` changes the ERROR SHAPE of `Webhook.fetch_related_object/3`

- **Recorded by:** 65-04 ("Webhook coupling" section); repeated here because it is a **behaviour
  change**, not merely an added capability, and a per-plan summary is easy to miss at ship time.
- **What:** `@object_map` is dual-purpose — `ObjectTypes.fetch_module/1` is also the fail-fast gate
  in `Webhook.fetch_related_object/3` (`lib/lattice_stripe/webhook.ex`), where an unknown type
  short-circuits to `{:error, {:unknown_object_type, type}}` with **zero** HTTP requests
  (Phase 47 D-05). Registering the summary key flips that branch.
- **The consequence:** `entitlements.active_entitlement_summary` has **no `id`** and **no
  single-object URL**. Were Stripe ever to deliver it as a v2 `related_object`, the resulting
  `GET related_object.url` would **404** rather than returning the tidy
  `{:error, {:unknown_object_type, _}}` it returned before Phase 65.
- **Inert today:** Stripe delivers entitlement summaries as v1 snapshot events, not v2 thin events
  (Assumption A4), so no live code path reaches this. It was left intact rather than "fixed",
  deliberately — the fail-fast coupling is documented Phase 47 D-05 behaviour and changing it is
  an architectural decision, not a bug fix.
- **What a future phase might do:** if v2 delivery of this object ever becomes real, the branch
  needs an explicit "registered but not individually retrievable" case that returns a typed error
  rather than issuing a doomed GET.
- **NOW TEST-LOCKED (UAT closeout).** Still deferred, but no longer merely documented. A paired
  characterization test in `test/lattice_stripe/webhook/fetch_test.exs` pins both halves of the
  current behaviour, and a triage invariant in `test/lattice_stripe/object_types_test.exs`
  partitions all 52 `@object_map` keys so a future row must declare its retrievability instead of
  silently flipping fetch behaviour.
- **Why it stays deferred is now a semver argument, not an effort one.** Adding
  `{:error, {:not_retrievable, _}}` widens a documented return union. An adopter with an
  exhaustive three-clause `case` over the published variants gets a runtime `CaseClauseError`,
  and Elixir does not warn on a non-exhaustive `case` — so this is major-flavoured breakage,
  inappropriate for a minor release, on a path that is inert today. The registry also cannot
  know retrievability: it maps object-type to module and carries no URL, since
  `RelatedObject.url` comes verbatim off the wire.

---

## 3. `guides/getting-started.md` `../README.md` relative link is broken on HexDocs

- **Recorded by:** STATE and carried by 65-01 through 65-05 as "65-06 owns it".
- **Status: NOT fixed in Phase 65, by design.** It is one of the **38 pre-existing `mix docs`
  warnings** that form this phase's differential baseline. 65-06-PLAN.md scopes it out explicitly:
  clearing the 38 warnings is "Phase 67-shaped work, out of scope here", and `guides/getting-started.md`
  is not in 65-06's `files_modified`.
- **Location:** `guides/getting-started.md:20` — `[README](../README.md)`. The relative path
  resolves on GitHub but not in the rendered HexDocs tree.
- **Route to:** Phase 67 (DX Hardening & Milestone Doc Close), together with the other 37 warnings
  (Tax.* nested types, `File.create/3`, and the hidden `ObjectTypes` / `BillingPortal.Guards` /
  `Webhook.check_tolerance` autolinks).

---

## 4. The two pre-existing flaky tests remain open (inherited from Phase 64)

- `test/lattice_stripe/client_test.exs:912` (retry telemetry attempts count, ~1 in 20) and
  `test/lattice_stripe/batch_test.exs:72` (batch error isolation, ~1 in 30), both proven
  pre-existing on commit `a22e197`. See
  `.planning/phases/64-meter-event-summary-reads/deferred-items.md` for the full analysis and
  suggested fixes.
- **Neither fired during any Phase 65 run**, across all six plans. No new information; recorded so
  the phase-65 close does not read as having silently resolved them.
