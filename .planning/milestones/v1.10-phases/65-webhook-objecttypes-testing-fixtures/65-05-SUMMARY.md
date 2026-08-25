---
phase: 65-webhook-objecttypes-testing-fixtures
plan: 05
subsystem: testing
tags: [elixir, stripe, fixtures, exdoc, hex, semver, invoice, obj-03]

requires:
  - phase: 65-webhook-objecttypes-testing-fixtures
    plan: 01
    provides: the promotion/authoring recipe, the MIX_ENV=prod compile gate, and the mutation-checked docs-truth ExDoc group assertion shape
  - phase: 65-webhook-objecttypes-testing-fixtures
    plan: 03
    provides: Q2 = move-and-rename, which fixes the public builder convention as <object>_json/1
provides:
  - "Public LatticeStripe.Testing.Fixtures.Invoice (flat, depth-3) with invoice_json/1"
  - "LatticeStripe.Testing.invoice/1 typed wrapper"
  - "OBJ-03 closed — all four core-billing fixtures are now public"
  - "The import-over-alias caller pattern for a fixture whose last segment collides with a domain-struct alias"
affects: [65-06 docs sweep]

tech-stack:
  added: []
  patterns:
    - "Authoring a fixture from a private test-file defp: lift the body verbatim and diff it against the original before deleting the source, so 'the lift was verbatim' is a checked fact rather than a claim"
    - "When a fixture's last segment collides with a domain-struct alias already in the caller, `import LatticeStripe.Testing.Fixtures.<Object>` beats `alias ..., as: <Object>Fixture` — imports cannot collide with aliases, and every existing call site stays byte-identical"

key-files:
  created:
    - lib/lattice_stripe/testing/fixtures/invoice.ex
  modified:
    - lib/lattice_stripe/testing.ex
    - mix.exs
    - guides/testing.md
    - test/lattice_stripe/testing_test.exs
    - test/lattice_stripe/docs_truth_test.exs
    - test/lattice_stripe/invoice_test.exs
    - .planning/STATE.md

key-decisions:
  - "invoice_test.exs consumes the fixture via `import`, not `alias ..., as: InvoiceFixture` — the file already aliases LatticeStripe.Invoice, and an import sidesteps that collision while leaving all ~40 `invoice_json(` call sites untouched (0 assertion lines changed)"
  - "The lift was proven verbatim by diffing the extracted body against the pre-delete original, not by re-running the tests alone — the tests passing is the consequence, the diff is the evidence"
  - "invoice_json_for_telemetry/1 in telemetry_test.exs was left alone by explicit decision: it is a deliberately reduced telemetry-assertion shape, not a competing canonical wire fixture (grep count unchanged at 4)"
  - "The empty `lines` envelope is asserted as the OBJ-03 empty-input edge in its own test, so a future 'helpful' default of one line item fails loudly instead of silently changing what every lines assertion means"

requirements-completed: [OBJ-03]

coverage:
  - id: D1
    description: "LatticeStripe.Testing.Fixtures.Invoice.invoice_json/1 is public, callable from lib/, and returns a string-keyed map carrying the same ~35 wire fields the private source did"
    requirement: OBJ-03
    verification:
      - kind: other
        ref: "diff of the lifted body against test/lattice_stripe/invoice_test.exs:17-60 (pre-delete) — identical, zero lines differ"
        status: pass
      - kind: other
        ref: "MIX_ENV=prod mix compile — exit 0"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/testing_test.exs#the authored invoice builder is callable at arity 0 (OBJ-03 empty-input edge)"
        status: pass
      - kind: other
        ref: "mix run -e 'IO.puts(is_map(LatticeStripe.Testing.Fixtures.Invoice.invoice_json()))' -> true"
        status: pass
    human_judgment: false
  - id: D2
    description: "LatticeStripe.Testing.invoice/1 returns a %LatticeStripe.Invoice{}"
    requirement: OBJ-03
    verification:
      - kind: unit
        ref: "test/lattice_stripe/testing_test.exs#return a typed Invoice struct from the authored public fixture"
        status: pass
      - kind: other
        ref: "mix run — Testing.invoice(...).__struct__ -> LatticeStripe.Invoice"
        status: pass
    human_judgment: false
  - id: D3
    description: "OBJ-03 empty edge: invoice_json/0's nested lines envelope has object => list, an EMPTY data list, and has_more => false by default"
    requirement: OBJ-03
    verification:
      - kind: unit
        ref: "test/lattice_stripe/testing_test.exs#OBJ-03 empty edge: the default invoice carries an EMPTY lines envelope"
        status: pass
      - kind: other
        ref: "mix run — {j[\"lines\"][\"object\"], j[\"lines\"][\"data\"], j[\"lines\"][\"has_more\"]} -> {\"list\", [], false}"
        status: pass
    human_judgment: false
  - id: D4
    description: "invoice_test.exs's existing assertions all still pass against the public fixture, because the body was lifted verbatim"
    requirement: OBJ-03
    verification:
      - kind: unit
        ref: "mix test test/lattice_stripe/invoice_test.exs — 0 failures"
        status: pass
      - kind: other
        ref: "git diff -U0 test/lattice_stripe/invoice_test.exs | grep -E '^[+-]' | grep -E 'assert|refute' -> ZERO lines"
        status: pass
    human_judgment: false
  - id: D5
    description: "test/lattice_stripe/invoice_test.exs no longer defines a private invoice_json/1 — exactly one definition of the canonical invoice shape exists in the repo (T-65-07)"
    requirement: OBJ-03
    verification:
      - kind: other
        ref: "grep -c 'defp invoice_json' test/lattice_stripe/invoice_test.exs -> 0"
        status: pass
      - kind: other
        ref: "grep -rln 'invoice_json' test lib -> only invoice_test.exs (call sites), telemetry_test.exs (the reduced OPT-OUT shape), and the lib/ definition"
        status: pass
    human_judgment: false
  - id: D6
    description: "LatticeStripe.Testing.Fixtures.Invoice appears in mix.exs groups_for_modules[:Testing] and in guides/testing.md, so an adopter can discover it"
    requirement: OBJ-03
    verification:
      - kind: unit
        ref: "test/lattice_stripe/docs_truth_test.exs#the authored Invoice fixture keeps its ExDoc placement and guide mention"
        status: pass
      - kind: other
        ref: "mutation check — removing the mix.exs Testing: Invoice entry fails exactly that one test (54 tests, 1 failure at docs_truth_test.exs:643); restored, 54/0"
        status: pass
    human_judgment: false
  - id: D7
    description: "T-65-03: no live-key material entered lib/ with the newly authored file"
    requirement: OBJ-03
    verification:
      - kind: other
        ref: "grep -nE 'sk_live|pk_live|whsec_|rk_live|acct_1' lib/lattice_stripe/testing/fixtures/invoice.ex -> no matches"
        status: pass
    human_judgment: false

duration: 4min
completed: 2026-07-29
status: complete
---

# Phase 65 Plan 05: Public Invoice Fixture Summary

**The one Phase 65 fixture with no prior source anywhere — invoice — was authored into `lib/` as `LatticeStripe.Testing.Fixtures.Invoice.invoice_json/1` by lifting the private `defp` out of `invoice_test.exs` byte-for-byte, closing OBJ-03's fourth and final core-billing fixture with zero assertion edits.**

## Did any `invoice_test.exs` assertion have to change?

**No. Zero.** This is the plan's headline question and the answer is the expected one, checked two ways rather than assumed:

1. `git diff -U0 test/lattice_stripe/invoice_test.exs | grep -E '^[+-]' | grep -E 'assert|refute'` returns **no lines at all**. Not one `assert` or `refute` was added, removed, or modified.
2. Before deleting the private source, the extracted body was diffed against it directly — **identical, zero differing lines**. The tests passing is the *consequence*; the diff is the *evidence*. Had the lift drifted by a single value, the diff would have caught it before a single test ran.

The whole-file diff is **5 insertions, 51 deletions** — the 51 are the deleted `defp` and its comment banner, the 5 are the new `import` and its explanatory comment. Nothing else in the file moved.

## Task Commits

1. **Task 1: Author the public Invoice fixture and rewire `invoice_test.exs`** — `0fc3d42` (feat)

## Accomplishments

- **OBJ-03 is now fully closed.** Customer, PaymentIntent and Subscription were promoted by 65-03; Invoice is authored here. All four core-billing fixtures are public, typed-wrapped, and ExDoc-registered.
- **Exactly one canonical invoice shape exists in the repo.** `grep -c 'defp invoice_json' test/lattice_stripe/invoice_test.exs` returns **0**. The `Dispute` drift hazard that 65-PATTERNS.md § Anti-Precedent warns against was not reproduced (T-65-07 discharged structurally, not by policing).
- **The naming convention held without debate.** `invoice_json/1` follows Q2 = `move-and-rename` as inherited from 65-03 — flat at depth 3, `<object>_json` for the canonical builder. The three meter `basic/1` outliers were not copied.
- **The typed wrapper landed with its alias in the same commit.** `Invoice` was inserted into `lib/lattice_stripe/testing.ex`'s single `alias LatticeStripe.{...}` block in alphabetical position (between `FileLink` and `Mandate`) in the same commit as `invoice/1`. An alias landing ahead of its user fails `mix compile --warnings-as-errors` (STATE `[63-01]`); it did not.
- **The ExDoc lock is mutation-checked, not assumed.** Removing `LatticeStripe.Testing.Fixtures.Invoice` from `mix.exs` `groups_for_modules[:Testing]` fails **exactly one** test — the new `docs_truth_test.exs:643` — at 54 tests / 1 failure. Restored; back to 54/0.
- **Zero docs regression.** `mix docs` exits 0 with warnings held at the **38** baseline, and the substring gate returns **0** even with `invoice` added to the pattern.
- **Test count 2326 → 2331** (+5), 0 failures, 1 skipped. `mix credo --strict`: 2303 mods/funs, no issues, green on first run.

## Files Created/Modified

- `lib/lattice_stripe/testing/fixtures/invoice.ex` — **new**. `LatticeStripe.Testing.Fixtures.Invoice` with a real `@moduledoc` ("Canonical raw fixtures for Stripe Invoice objects.", matching the `Customer`/`TaxId` voice exactly), one `@spec invoice_json(map()) :: map()`, and `invoice_json(overrides \\ %{})`. Body is the verbatim lift: ~35 wire fields including the nested `automatic_tax` and `status_transitions` maps and the `lines` list envelope with its empty `"data"`, `"has_more" => false`, and `"/v1/invoices/in_test1234567890/lines"` url. No reference to `LatticeStripe.TestHelpers` (Pitfall 3 never fired — the source `defp` was self-contained).
- `lib/lattice_stripe/testing.ex` — `Invoice` added to the alias block alphabetically; `invoice/1` added after `subscription/1` in the `dispute/1` shape (`@doc`, `@spec`, one-line delegation to `Invoice.from_map/1`).
- `mix.exs` — one module appended to `groups_for_modules[:Testing]` after `...Subscription`. `files:`, `elixirc_paths/1` and `deps/0` untouched (T-65-SC holds — zero packages installed).
- `guides/testing.md` — one fixture bullet added to the public-fixture list; `invoice/1` added to the typed-wrapper sentence.
- `test/lattice_stripe/testing_test.exs` — `Invoice` added to the alias block in the same edit as its first use. Three tests added to the existing `describe "public fixture builders"` (arity-0 callability, the OBJ-03 empty-`lines` edge, override precedence) and one to the existing `describe "typed wrappers"`. **No new `describe` blocks**, per the plan.
- `test/lattice_stripe/docs_truth_test.exs` — one ExDoc group-membership + guide-prose test in the 65-01/02/03 shape, carrying the same structural-not-decorative comment.
- `test/lattice_stripe/invoice_test.exs` — the 46-line private `defp invoice_json/1` and its "Fixture helpers" banner deleted; replaced by a single `import LatticeStripe.Testing.Fixtures.Invoice` with a comment recording *why* it is an import rather than an alias. **All call sites unchanged.**

## Decisions Made

- **`import`, not `alias ..., as: InvoiceFixture`.** This is the case 65-02 originally flagged and 65-03 refined: `invoice_test.exs` already does `alias LatticeStripe.{Error, Invoice, List, Response}`, so `Invoice` is taken by the domain struct and a bare fixture alias would collide. But an **import cannot collide with an alias**, so `import LatticeStripe.Testing.Fixtures.Invoice` resolves cleanly *and* leaves every one of the file's ~40 `invoice_json(` call sites byte-identical. The `as:` suffix form would have compiled equally well but churned every call site for no benefit — exactly the trade 65-03 declined for `subscription_test.exs`. **Three data points now agree: pick the caller form that requires zero call-site churn, and the `as: <Object>Fixture` suffix is a last resort, not a default.**
- **The verbatim lift was verified by diff, before deletion.** The plan says "if any assertion fails after the swap, the lift was not verbatim and the fixture is wrong, not the test" — a good rule, but it detects drift only *after* the fact and only for values some assertion happens to cover. Diffing the extracted body against the source catches drift in fields no test touches (`period_end`, `attempt_count`, `subtotal`) that a passing suite would happily hide.
- **`invoice_json_for_telemetry/1` left untouched, count verified unchanged at 4.** It is a deliberately reduced shape for telemetry assertions. Publishing two competing invoice fixtures would make the canonical one ambiguous — the exact ambiguity this plan exists to remove. `git diff --stat test/lattice_stripe/telemetry_test.exs` shows the file was not modified at all.
- **The empty `lines` envelope got its own named test, not a bundled assertion.** The plan calls the empty collection "the OBJ-03 empty-input edge... deliberate, not a placeholder to fill in." A dedicated test named for that edge is what stops a future contributor from reading the empty list as an oversight and "fixing" it with a sample line item — which would silently change what every `lines` assertion in `invoice_test.exs` means.

## Deviations from Plan

**None.** No bug, missing-critical-functionality, or blocking issue was encountered; no architectural question arose. Every acceptance criterion in the plan passes exactly as written.

The 65-01 `Design.AliasUsage` deviation did **not** recur — the fixture is reached through an `import` at the top of its caller, never fully-qualified, so `mix credo --strict` was green on the first run. The 65-03 line-number-drift lesson was applied preemptively: every edit was made by matching on content, never on a line coordinate from the plan.

---

**Total deviations:** 0
**Impact on plan:** None.

## Issues Encountered

- **Neither known pre-existing flake fired.** `client_test.exs:912` and `batch_test.exs:72` both passed; no re-run was needed.
- **The docs substring gate was run with `invoice` appended to the pattern** (`entitlement|meter|testing|fixture|invoice`) rather than the plan's four-term list, since this plan is the one that could introduce an invoice-related docs warning. It returns **0** on the widened pattern, so the result is strictly stronger than the criterion asked for.

## Verification Results

The five-step differential phase gate from `65-VALIDATION.md`, plus the 65-01 prod-compile gate:

| Gate | Result |
|---|---|
| `mix format --check-formatted` | pass |
| `mix compile --warnings-as-errors` | pass (proves the new alias landed with its user) |
| `mix credo --strict` | **exit 0**, "2303 mods/funs, found no issues" |
| `mix test` | **2331 tests, 0 failures**, 1 skipped (baseline 2326 → +5) |
| Targeted suites (invoice + testing + docs_truth) | **162 tests, 0 failures** |
| `mix docs` | exit 0; warnings **38** (== baseline); `entitlement\|meter\|testing\|fixture\|invoice` matches **0** |
| `MIX_ENV=prod mix compile` | **exit 0** |
| Verbatim-lift diff (extracted body vs. pre-delete source) | **identical, 0 lines differ** |
| Assertion lines changed in `invoice_test.exs` | **0** (`git diff -U0 ... \| grep assert\|refute` empty) |
| `grep -c '@moduledoc false' lib/.../invoice.ex` | **0** |
| `grep -c '@spec' lib/.../invoice.ex` | **1** |
| `grep -c 'defp invoice_json' test/lattice_stripe/invoice_test.exs` | **0** |
| `grep -c 'invoice_json_for_telemetry' test/lattice_stripe/telemetry_test.exs` | **4** (unchanged; file not modified) |
| `mix.exs` `Testing:` group contains the module | **yes** |
| `guides/testing.md` contains the literal module name | **yes** |
| Secrets scrub (`sk_live\|pk_live\|whsec_\|rk_live\|acct_1`) on the authored file | **no matches** (T-65-03 mitigated) |
| Mutation check (D6) | removing the `mix.exs` Invoice entry fails **exactly** the new docs-truth test (54 tests, 1 failure, `docs_truth_test.exs:643`); restored, 54/0 |
| `mix run` — `is_map(Fixtures.Invoice.invoice_json())` | `true` |
| `mix run` — `{lines.object, lines.data, lines.has_more}` | `{"list", [], false}` |
| `mix run` — `Testing.invoice(...).__struct__` | `LatticeStripe.Invoice` |
| Post-commit deletion check | no file deletions; one file created, six modified |

## Known Stubs

None. No placeholder values, TODO/FIXME markers, or unwired data paths were introduced. Every value in the authored fixture is verbatim from the pre-existing private source. The empty `lines.data` list is a **deliberate canonical default** asserted by a named test, not a stub.

## Threat Flags

None. No new network endpoint, auth path, file access pattern, or schema change at a trust boundary. All three dispositions in the plan's threat register are discharged:

- **T-65-03** (Information Disclosure — secrets crossing into `lib/`) — `mitigate`. The scrub ran on the authored file and returned no matches. All identifiers are synthetic and correctly prefixed (`in_test1234567890`, `cus_test123`); no real-looking identifier was introduced during the lift, which the verbatim diff independently confirms.
- **T-65-07** (Tampering — two competing invoice fixture shapes) — `mitigate`. The private `defp` was **deleted**, not left alongside the public module, so there is one definition and nothing to drift. `invoice_json_for_telemetry/1` remains private and reduced by explicit decision and is recorded here as the OPT-OUT the register anticipated.
- **T-65-SC** (Tampering — package-manager installs) — `accept`. Zero packages installed; `mix.exs` `deps/0` unchanged.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- **OBJ-03 is complete.** All four core-billing fixtures named by the requirement (customer, payment_intent, subscription, invoice) are public, flat at depth 3, `<object>_json`-named, typed-wrapped, ExDoc-registered and guide-listed.
- **65-06 owns what remains** and is unblocked: `.planning/ROADMAP.md`, the phase RESEARCH/VALIDATION docs, `lib/lattice_stripe/testing/fixtures.ex`, the stale "v1.3 resource families" claim in `guides/testing.md` (the list now runs to 18 modules), and the `guides/getting-started.md` `../README.md` broken link. None were touched here.
- **The ExDoc warning count is still 38**, so the differential docs gate remains usable for 65-06.
- **The meter `basic/1` follow-up carries forward unchanged** from 65-03: those three builders remain the only public fixture builders not using `<object>_json`, and aligning them is a breaking change once the Hex 1.8.0 tag lands.
- **The authoring recipe now has a fourth data point** and has still never required a change to `files:` or `elixirc_paths/1` in `mix.exs`.
- **No blockers.**

## Self-Check: PASSED

- `lib/lattice_stripe/testing/fixtures/invoice.ex` — exists
- `lib/lattice_stripe/testing.ex` — exists, contains `invoice/1`
- `mix.exs` — exists, contains `LatticeStripe.Testing.Fixtures.Invoice`
- `guides/testing.md` — exists, contains `LatticeStripe.Testing.Fixtures.Invoice`
- `test/lattice_stripe/invoice_test.exs` — exists, contains 0 `defp invoice_json`
- Commit `0fc3d42` — present in git log
- `.planning/phases/65-webhook-objecttypes-testing-fixtures/65-05-SUMMARY.md` — exists

---
*Phase: 65-webhook-objecttypes-testing-fixtures*
*Completed: 2026-07-29*
