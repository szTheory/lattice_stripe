# Phase 62: 1.1 → 1.7 What Landed Migration Guide - Pattern Map

**Mapped:** 2026-08-24  
**Files analyzed:** 3 (two planned edits; one configuration verification)  
**Analogs found:** 3 / 3

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match quality |
|---|---|---|---|---|
| `guides/upgrading-1-1-to-1-7.md` | ExDoc extra / migration guide | static reader-routing and information transform | the existing guide itself; `guides/customer-portal.md`; `guides/webhooks-thin-events.md` | exact / role-match |
| `test/lattice_stripe/docs_truth_test.exs` | ExUnit semantic documentation-contract test | file-I/O plus configuration inspection | existing guide-placement and semantic-anchor tests in the same module | exact |
| `mix.exs` | ExDoc publication configuration | build-time static configuration | existing `extras` and `groups_for_extras` entry in `LatticeStripe.MixProject` | exact (verify-only) |

`mix.exs` is not an expected behavioral edit: the guide is already an ExDoc extra under
`Upgrading`. Preserve that declaration unless the implementation discovers it is wrong.
Do not change production library modules, release records, or add a separate docs framework.

## Pattern Assignments

### `guides/upgrading-1-1-to-1-7.md` (ExDoc extra, static reader routing)

**Primary analog:** the existing guide, especially its scope/safety callouts and short
Elixir before/after examples.

**Useful supporting analogs:**

- `guides/customer-portal.md:52-115` for semantic heading hierarchy, prose before a
  focused code block, and an explicit configuration-to-session relationship.
- `guides/webhooks-thin-events.md:113-123` for teaching the verify/fetch surface with
  short, typed return-shape examples rather than recreating the full workflow.
- `guides/user-flows-and-jtbd.md` for task-first routing into canonical guides rather
  than release-author chronology.

**Scope and warning-callout pattern** (`guides/upgrading-1-1-to-1-7.md:5-28`):

```markdown
> #### Scope: this guide stops at 1.7 {: .warning}
>
> The current Hex line is **2.x**. This guide covers the `1.1 → 1.7` leg only...
```

Retain this ExDoc callout syntax and place the historical dependency immediately after it.
Replace the current post-1.7 Finch setup prose with a thin link/handoff to current docs;
do not describe current setup as available under `~> 1.7`.

**Risk-first migration pattern** (`guides/upgrading-1-1-to-1-7.md:38-113`):

````markdown
> #### Breaking change: finite `status` fields return atoms {: .warning}
>
> **Affected if:** you compare a resource's finite `status` field against a
> string...

```elixir
# Before (1.1):
if pi.status == "succeeded" do ...

# After (1.7):
if pi.status == :succeeded do ...
```
````

Keep the three existing decision predicates and their before/after pairs. Add a clear
safe exit plus application-test action after the checklist. Keep the `tolerance: 0`
testing-only/replay-protection warning adjacent to its example.

**Capability routing pattern** (`guides/upgrading-1-1-to-1-7.md:116-324`):

````markdown
**Credit Notes** — issue post-invoice credits and refunds.

```elixir
{:ok, credit_note} = LatticeStripe.CreditNote.create(client, %{...})
```

See `LatticeStripe.CreditNote.create/3` and [credit_notes.md](credit_notes.md).
````

Transform the current family-first blocks into an action-first inventory with the locked
columns **Need / surface / minimum call / canonical next step**, grouping rows under
familiar ExDoc families. Preserve one small decision-bearing snippet per important family,
especially `BillingPortal.Configuration → BillingPortal.Session`; link, rather than
duplicate, full Tax, webhook, and test workflows. Ensure the catalogue includes
`File`/`FileLink`, `Mandate`, and `SetupAttempt`, not only the chronology appendix.

**Inter-guide link pattern:** use relative `.md` sibling links, including anchors where
helpful (for example `customer-portal.md#wire-a-configuration-into-sessions`). Do not use
sibling `.html` links; the shared docs-truth guard rejects them.

**Chronology appendix pattern** (`guides/upgrading-1-1-to-1-7.md:326-353`): keep the
release table after mandatory actions and optional capability routing. Correct its 1.7 row
to remove `default Finch pool`; do not make the table the reader's primary navigation.

### `test/lattice_stripe/docs_truth_test.exs` (ExUnit semantic docs contract, file-I/O)

**Analog:** the existing module-level `docs_config/0` helper and guide-contract tests.

**Configuration-read pattern** (`test/lattice_stripe/docs_truth_test.exs:85-86`,
`176-221`):

```elixir
defp docs_config do
  LatticeStripe.MixProject.project()[:docs]
end

docs = docs_config()
extras = docs[:extras]
groups = docs[:groups_for_extras] |> Map.new()
```

Use the helper and local `groups` conversion in one named test. Assert that the guide
remains in `extras` and `groups["Upgrading"]`; do not create a second test module or
parser.

**Positive/negative anchor pattern** (`test/lattice_stripe/docs_truth_test.exs:229-232`,
`893-927`):

```elixir
guide = File.read!("guides/webhooks-thin-events.md")

assert guide =~ "parse_event_notification"
assert guide =~ "fetch_event"
refute guide =~ "customer-portal.html#"
```

Add one focused test named after the adopter contract (for example,
`"1.1-to-1.7 guide remains historically scoped and discoverable"`). Read the guide once,
then assert concise, durable anchors for:

- historical `1.1 → 1.7` scope and `{:lattice_stripe, "~> 1.7"}` pin;
- the thin 2.0/current-doc handoff;
- all three behavior checks and the `tolerance: 0` production safety boundary;
- the complete inventory and its canonical routes (including File/FileLink, Mandate,
  SetupAttempt, portal, Tax, thin events, money movement, TestClock/fixtures);
- absence of the historical contaminant, `default Finch pool`, and absence of the old
  `Part 2`/`Part 3` navigation labels.

Avoid exact paragraph or rendered-HTML snapshots. Each assertion must protect a concrete
reader harm and allow ordinary copy editing. Existing `@guide_paths` fence and link tests
already provide the broad formatting backstop.

### `mix.exs` (ExDoc configuration, build-time static config)

**Analog:** `LatticeStripe.MixProject.project/0` docs configuration (`mix.exs:23-109`).

```elixir
extras: [
  # ...
  "guides/upgrading-1-1-to-1-7.md",
  "CHANGELOG.md"
],
groups_for_extras: [
  # ...
  {"Upgrading", ["guides/upgrading-1-1-to-1-7.md"]},
  {"Changelog", ["CHANGELOG.md"]}
]
```

Treat this as a verification point, not a rewrite. Keep the filename and group stable so
the published HexDocs URL/sidebar location stays unsurprising. Only edit it if the guide
is absent or incorrectly grouped, then extend the semantic test in the same change.

## Shared Patterns

### Documentation UX and accessibility

**Sources:** `guides/upgrading-1-1-to-1-7.md`, `guides/customer-portal.md`, and the
repository-wide guide guards in `test/lattice_stripe/docs_truth_test.exs:1027-1118`.

- Use semantic `##` / `###` headings that match visible navigation, ExDoc warning/info
  callouts with text labels (never color-only meaning), prose before short Elixir fences,
  and descriptive links.
- Keep public wording at the adopter contract: module, verb, input relationship, return
  shape, safety constraint, and next route. Exclude planning/internal implementation
  history.
- Use `.md` for local guide links so both GitHub and HexDocs work; canonical links are
  routes to deep workflows, not duplicated workflows.

### Historical correctness and source of truth

**Sources:** `CHANGELOG.md:146-200` (1.7 through 1.5 history) and
`CHANGELOG.md:16-38` (2.0 default-Finch release).

Release records/tags establish version facts; the guide translates them into action. Do
not add a duplicate release manifest or tag-dependent CI. Verify every copied module,
function, and arity against public source/current canonical guides before publication.

### Verification

**Sources:** `test/lattice_stripe/docs_truth_test.exs`, `mix.exs`, and existing CI.

Run the focused test while editing, then `mix docs --warnings-as-errors` and `mix ci`.
The focused ExUnit contract supplies the semantic proof that renderer/build checks cannot:
historical pin accuracy, discoverability, risk warnings, and absence of post-1.7 setup
claims.

## No Analog Found

None. This phase deliberately extends established ExDoc extra and ExUnit docs-truth
patterns; it introduces no new runtime, UI, API, or documentation-test architecture.

## Metadata

**Analog search scope:** `guides/`, `test/lattice_stripe/docs_truth_test.exs`, `mix.exs`,
`CHANGELOG.md`  
**Files scanned:** 8 primary docs/config/test/history files  
**Pattern extraction date:** 2026-08-24
