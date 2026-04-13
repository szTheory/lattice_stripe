# Advisor Research — README Quickstart + Automated Test

**Scope:** Phase 19 cross-cutting polish. Decide (Q1) the shape of the README hero for v1.0 now that Billing (Phases 14-16) and Connect (Phases 17-18) have landed, and (Q2) whether to automate the "60-second test" success criterion in CI.

**Phase 10 baseline (D-18..D-23):**
- Hero: `PaymentIntent.create` (~10 lines, client + payment)
- Target length: ~100-150 lines
- Finch child spec in supervision tree (3 lines)
- Standard badges, compatibility table

**What changed since Phase 10:** LatticeStripe now covers Payments + Checkout + Webhooks + **Billing (Invoice, Subscription, SubscriptionItem, SubscriptionSchedule)** + **Connect (Account, AccountLink, ExternalAccount, Transfer, Payout, Balance, BalanceTransaction)**. The existing README (see `/Users/jon/projects/lattice_stripe/README.md`) already lists Connect in the feature bullets but the hero still shows only a PaymentIntent.

---

## Q1: README Quickstart Hero for v1.0

### The core question

Does the "60-second test" mean *one minute to charge a card* (single-domain hero, trust signals elsewhere), or *one minute to understand LatticeStripe's scope* (multi-domain teasers)? Tom Preston-Werner's [README-driven-development post](https://tom.preston-werner.com/2010/08/23/readme-driven-development.html) and the [standard-readme spec](https://github.com/RichardLitt/standard-readme) both agree on one thing: the README's job is to get the reader to *their first success*, not to enumerate the library. The feature list handles scope; the hero handles success.

### Ecosystem precedent

I pulled hero examples from 10 libraries spanning Elixir core infra, Elixir SDKs, and Stripe's first-party SDKs:

| Library | Hero scope | Hero size | Total README |
|---|---|---|---|
| **Finch** ([README](https://github.com/sneako/finch/blob/main/README.md)) | Single: supervision + one GET | ~5 lines | ~211 lines, 11 code blocks |
| **Req** ([README](https://github.com/wojtekmach/req/blob/main/README.md)) | Single: `Req.get!` one-liner, then 3 feature snippets | 2 lines | ~297 lines, 24-bullet feature list |
| **Ecto** ([README](https://github.com/elixir-ecto/ecto/blob/master/README.md)) | Single: Repo + Schema + Query in one flow | ~50 lines | ~214 lines |
| **Phoenix** ([README](https://github.com/phoenixframework/phoenix/blob/main/README.md)) | **No hero code** — `mix phx.new` + docs links | 0 feature lines | ~66 lines |
| **Broadway** ([README](https://github.com/dashbitco/broadway/blob/main/README.md)) | Single: one SQS pipeline (30 lines) | 30 lines | ~106 lines |
| **Oban** ([README](https://github.com/oban-bg/oban/blob/main/README.md)) | Progressive: config → worker → enqueue (3 blocks) | ~25 lines across 3 blocks | ~250 lines |
| **Swoosh** ([README](https://github.com/swoosh/swoosh/blob/main/README.md)) | Single hero (compose email), then 7-8 topical blocks | ~15 lines | very long, adapter table |
| **Bandit** ([README](https://github.com/mtrudel/bandit/blob/main/README.md)) | Config block (Phoenix integration) | ~8 lines | plain code blocks, not doctest |
| **stripe-node** ([README](https://github.com/stripe/stripe-node/blob/master/README.md)) | `customers.create` only | ~4 lines | single-domain |
| **stripe-python** ([README](https://github.com/stripe/stripe-python/blob/master/README.md)) | `customers.list` + `customers.retrieve` | ~5 lines | single-domain |
| **stripe-ruby** ([README](https://github.com/stripe/stripe-ruby/blob/master/README.md)) | `customers.list` / `customers.retrieve` via `StripeClient` | ~4 lines | single-domain, Connect is a sub-section |

**Observations that matter for v1.0:**
1. **Every Stripe first-party SDK uses a single-domain hero**, and it's usually *Customers*, not even PaymentIntent. Their reasoning: Customers is the universal starting point that gates every other Stripe flow. None of stripe-node, stripe-python, stripe-go, or stripe-ruby tabs / multi-tiers their hero to show Billing or Connect — those live in dedicated guide pages.
2. **Elixir libraries with broad scope (Oban, Swoosh) still use one hero**, then list features and link out. They treat the hero as "the first screenful of IEx output," not as a feature tour.
3. **The one library that does a multi-block progression (Oban: config → worker → enqueue)** does it because each block is a *prerequisite* of the next — it's still one story, not three domains. Broadway's 30-line example is also one story.
4. **No library I examined tabs its quickstart by domain.** Tabbed quickstarts are a *docs-site* pattern (Stripe's own https://docs.stripe.com uses them) and don't render on GitHub or HexDocs README views.

### Options

#### Option A: Keep PaymentIntent-only hero (D-18 status quo)
The current `README.md` hero (Finch child spec → `Client.new!` → `PaymentIntent.create`) matches every peer library's approach. Billing/Connect presence is signaled by (a) the feature bullet list, (b) HexDocs guide links, and (c) the `CHANGELOG.md` 0.2 → 1.0 arc.

**Pros:**
- Matches 100% of surveyed precedent (Finch, Req, Ecto, Oban, Swoosh, stripe-*, …).
- One coherent story. Reader reaches first success (a charged card) in <60s.
- Hero is *testable* in one code block against stripe-mock; multi-domain hero needs per-domain fixtures.
- Billing/Connect still discoverable via the Features section and HexDocs guides.
- Smallest diff from current state — we already shipped this in Phase 10 and it passes review.

**Cons:**
- A reader who lands on the README because they specifically need Connect or Subscriptions has to scroll past a PaymentIntent example that's not directly relevant. Mitigated by features list + guide links being above-the-fold in a ~130-line README.
- Doesn't visually signal the "breadth" that Billing+Connect give LatticeStripe over single-domain SDKs. Though no peer does, and stripe-ruby itself doesn't either.

#### Option B: Single hero + "…and more" teaser tier (2-3 line Billing/Connect snippets)
Keep the PaymentIntent hero, but append a small "LatticeStripe also covers" block with 2-3 line teasers: one `Subscription.create` and one `Account.create`. These are *not* runnable in sequence (they'd need separate setup); they're teasers showing "the same client works for these too."

**Pros:**
- Signals breadth cheaply (~10 extra lines).
- Still one primary hero for the 60-second test.
- The teasers can share the same `client` variable visually, reinforcing "one client, many domains."

**Cons:**
- Teasers that aren't runnable in sequence create a subtle copy-paste trap: a reader pastes them and gets errors because they skipped the setup. This is the exact DX problem the 60-second test is designed to prevent.
- Harder to test automatically — each teaser needs its own test fixture or we accept "the hero is tested, the teasers are not."
- No peer library does this. Deviating from precedent needs a stronger reason than "we have more features."

#### Option C: Tabbed/sectioned hero (Payments | Billing | Connect)
Replace the single hero with three parallel sections, each showing a minimal flow for its domain.

**Pros:**
- Every reader finds "their" domain on the landing screen.

**Cons:**
- Tabs don't render on GitHub markdown or HexDocs README views — they degrade to three stacked blocks, tripling the README's hero real estate.
- Triples testing cost.
- Violates the 60-second test: three front-loaded flows means the reader can't scan in 60s. They have to pick a path.
- Zero peer library precedent (this is a docs-*site* pattern, not a README pattern).
- Pushes the feature list and compatibility table below the fold.

#### Option D: Keep D-18 hero, upgrade the feature section
Keep PaymentIntent hero exactly as-is, but **restructure the feature bullets into grouped domain sub-headings** (Payments / Billing / Connect / Platform) with one or two representative module names per group and direct HexDocs links. This addresses the "represent v1.0 scope" concern without touching the hero or the 60-second test.

**Pros:**
- Preserves the tested single-hero pattern.
- Makes scope scannable: a Billing-only reader sees "Billing: Invoice, Subscription, SubscriptionItem, SubscriptionSchedule → guide" in the first screen.
- Minimal diff — a few lines of restructuring.
- Doesn't introduce untested teaser code.
- Every reader gets *both* the success story (hero) and the scope signal (grouped features).

**Cons:**
- Still "just a bullet list" for Billing/Connect readers — they don't see any Billing/Connect code until they click into HexDocs.
- Slightly longer features section.

### Comparison

| Option | Pros | Cons | Complexity | Recommendation |
|---|---|---|---|---|
| A: Status quo PaymentIntent hero | 100% precedent match, smallest diff, testable | Doesn't visually signal Billing/Connect breadth | 0 files — Risk: none | Rec if precedent fidelity + testability trump scope signaling |
| B: Hero + 2-3 line teasers | Cheap breadth signal, shared `client` var | Teasers are untested / unrunnable standalone, no peer precedent | 1 file, ~15 LOC — Risk: copy-paste DX trap, CI can't verify teasers | Not recommended — violates "if it's in the README it should work" |
| C: Tabbed/sectioned hero | Every reader finds their domain | Degrades on GitHub/HexDocs, triples real estate + test cost, zero precedent, breaks 60s test | 1 file, ~60 LOC rewrite — Risk: renders as 3 stacked blocks | Not recommended |
| D: Hero unchanged + grouped features | Preserves tested hero, makes scope scannable, minimal diff | Billing/Connect still "just bullets" above the fold | 1 file, ~20 LOC — Risk: none | **Primary recommendation** |

### Recommended README skeleton (Option D)

```markdown
# LatticeStripe

[![Hex.pm](https://img.shields.io/hexpm/v/lattice_stripe.svg)](https://hex.pm/packages/lattice_stripe)
[![CI](https://github.com/szTheory/lattice_stripe/actions/workflows/ci.yml/badge.svg)](https://github.com/szTheory/lattice_stripe/actions/workflows/ci.yml)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/lattice_stripe)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A production-grade, idiomatic Elixir SDK for the Stripe API. Payments, Billing,
Connect, and Webhooks — one client, one pipeline, one place to instrument.

Full documentation on [HexDocs](https://hexdocs.pm/lattice_stripe).

## Installation

    def deps do
      [{:lattice_stripe, "~> 1.0"}]
    end

## Quick Start

LatticeStripe uses [Finch](https://github.com/sneako/finch) for HTTP. Add it to
your supervision tree:

    children = [
      {Finch, name: MyApp.Finch}
    ]

Create a client and charge a card:

    client = LatticeStripe.Client.new!(
      api_key: "sk_test_...",
      finch: MyApp.Finch
    )

    {:ok, payment_intent} =
      LatticeStripe.PaymentIntent.create(client, %{
        "amount" => 2000,
        "currency" => "usd",
        "payment_method" => "pm_card_visa",
        "confirm" => true,
        "automatic_payment_methods" => %{
          "enabled" => true,
          "allow_redirects" => "never"
        }
      })

## What's in LatticeStripe

**Payments** — [`Customer`], [`PaymentIntent`], [`PaymentMethod`], [`SetupIntent`],
[`Refund`], [`Checkout.Session`]. See the [Payments guide].

**Billing** — [`Invoice`], [`Subscription`], [`SubscriptionItem`],
[`SubscriptionSchedule`]. See the [Billing guide].

**Connect** — [`Account`], [`AccountLink`], [`ExternalAccount`], [`Transfer`],
[`Payout`], [`Balance`], [`BalanceTransaction`]. See the [Connect guide].

**Platform** — auto-pagination streams, `:telemetry` events, pluggable
`Transport` / `JSON` / `RetryStrategy` behaviours, structured `Error` types,
automatic idempotency keys, `Stripe-Should-Retry` backoff,
[`Webhook.Plug`] with timing-safe HMAC verification.

## Compatibility

| Requirement | Version |
|-------------|---------|
| Elixir      | >= 1.15 |
| Erlang/OTP  | >= 26   |
| Stripe API  | 2026-03-25.dahlia |

## Documentation / Contributing / License
(as today)
```

Net change from current: ~15 lines restructured in the feature section, hero is literally unchanged from Phase 10's D-18 lock. Reader gets hero success story + v1.0 scope in the first ~60 lines.

### Recommendation for Q1

**Option D.** It is the only option that preserves the single-hero 60-second test (which every peer library validates), the only one that keeps the hero automatable in CI (Q2), and the only one that costs <20 LOC of diff. Options B and C both create DX traps (untested or stacked code) with no ecosystem precedent. Option A is also defensible and is my fallback if the feature grouping feels like over-engineering, but Option D's grouped feature section is how Oban, Swoosh, and Bandit actually communicate breadth, so there's precedent.

---

## Q2: Automated 60-second Quickstart Test

### The core question

Phase 19's success criterion #3 is literally "README quickstart still passes the 60-second test with current dependency versions." How do we verify this without a human manually copy-pasting into IEx every release?

### Key finding: Elixir 1.15+ has this built in

Since **Elixir 1.15.0**, `ExUnit.DocTest.doctest_file/1,2` can extract doctests directly from a markdown file like README.md. This is the *official, zero-dependency* mechanism.

    defmodule LatticeStripe.ReadmeTest do
      use ExUnit.Case, async: true
      doctest_file "README.md"
    end

Source: [ExUnit.DocTest docs](https://hexdocs.pm/ex_unit/ExUnit.DocTest.html), [elixirforum thread on docception → doctest_file migration](https://elixirforum.com/t/docception-run-doctests-for-markdown-files/21286), [docception README noting its own deprecation](https://github.com/evnu/docception).

LatticeStripe's minimum is Elixir 1.15 (CLAUDE.md), so `doctest_file` is available on every supported version.

### The catch: doctest syntax vs. idiomatic README code

`doctest_file` is still `DocTest`. It expects `iex>` prompts and `...>` continuations; code blocks without prompts are **ignored**, not tested. A doctest-style hero looks like this:

    iex> client = LatticeStripe.Client.new!(api_key: "sk_test_...", finch: MyApp.Finch)
    iex> {:ok, pi} = LatticeStripe.PaymentIntent.create(client, %{"amount" => 2000, ...})
    iex> pi.amount
    2000

vs. the current "copy-paste into your app" style:

    client = LatticeStripe.Client.new!(api_key: "sk_test_...", finch: MyApp.Finch)
    {:ok, payment_intent} = LatticeStripe.PaymentIntent.create(client, %{...})

Three real problems with forcing doctest format in the hero:

1. **Readers copy-paste `iex>` prefixes into their `application.ex`** and get syntax errors. This is the most common doctest-in-README footgun cited on elixirforum.
2. **Stripe IDs are non-deterministic** (`pi_1NxyzAbc...`). You can't assert on `pi.id`, only on stable fields like `pi.amount` or `pi.currency`.
3. **Finch must be running** for the doctest to execute, which means the test module needs a `setup_all` that starts Finch + configures the base URL to stripe-mock. This is doable but not "zero config."

Peer libraries that ship doctests in markdown (searched GitHub for `doctest_file`) are overwhelmingly **stdlib-pure modules** (parsers, data structures, small utilities) where every snippet is deterministic and requires no setup. HTTP SDKs almost never use `doctest_file` — the only ones I found were in-module doctests on pure functions (form encoders, signature verifiers), not on full request flows.

### Options

#### Option A: `doctest_file "README.md"` with iex-style hero
Rewrite the README hero in doctest format. Spin up Finch + point at stripe-mock in a `setup_all`. Assert on stable fields.

**Pros:**
- Zero new deps, official Elixir pattern.
- If the README drifts, `mix test` fails immediately.
- Runs on every PR, not just releases.

**Cons:**
- Hero no longer reads like idiomatic copy-paste code (`iex>` prefixes everywhere).
- Copy-paste footgun for users.
- Non-deterministic fields can't be asserted; the doctest has to be carefully pruned to only stable assertions.
- Requires stripe-mock running in CI — already have this from Phase 9, but now it becomes a hard dep for default `mix test`, not just `--include integration`. Phase 9 D-01 explicitly excludes integration from default `mix test`.
- Conflicts with Phase 9 D-01 ("default `mix test` fast and CI-independent").

#### Option B: Custom `test/readme_test.exs` that *parses* code fences and `Code.eval_string`s them
Write a ~30-LOC test that reads README.md, extracts `​```elixir` fenced blocks, concatenates them into one script, substitutes the API key / Finch name, and `Code.eval_string/1`s it against stripe-mock. Assert no exceptions.

**Pros:**
- Hero stays in idiomatic copy-paste form (no `iex>` prompts).
- Full hero is tested end-to-end.
- Substitutions (API key, Finch name, stripe-mock base URL) are controllable.
- Tagged `@tag :integration` so it's off-by-default per Phase 9 D-01, on in CI's integration job.

**Cons:**
- Custom parsing code to maintain (~30 LOC).
- `Code.eval_string` has no line numbers in failures — debugging a broken README means eyeballing the concatenated script. Mitigate by `eval`ing blocks one at a time and reporting block index.
- If the hero has multiple code blocks (supervision + client + PaymentIntent), all need to execute in a shared binding, which `Code.eval_string` supports via the `binding` return.

#### Option C: Separate `mix readme.verify` task, manual pre-release only
Pure manual check as part of the release checklist. Maintainer runs `mix readme.verify` before `mix hex.publish`.

**Pros:**
- No CI cost, no Phase 9 D-01 conflict.
- Can be more thorough (e.g., actually start a real app, boot Finch).

**Cons:**
- Only catches drift at release time. If the README breaks three months before the next release, users copy-pasting a broken quickstart are the ones who find out.
- Relies on maintainer discipline. Phase 19's success criterion talks about *passing* the 60-second test, not about remembering to run it.
- Fails the "automated" part of automated testing.

#### Option D: Tag code blocks with \`\`\`elixir + custom extractor via a hex lib
Libraries like [`markdown_test`](https://github.com/MainShayne233/markdown_test) and [`docception`](https://github.com/evnu/docception) used to fill this gap, but both are effectively superseded by `doctest_file` and are unmaintained (last commits years ago).

**Pros:**
- Nothing material over Option B; we'd be adopting an unmaintained dep.

**Cons:**
- Unmaintained deps are a security/maintenance liability for a library targeting production SaaS.

#### Option E: No automated README test — document as release checklist only
Same as C but without even the mix task. Just a line in `CONTRIBUTING.md` / release runbook: "before cutting a release, copy the README quickstart into a fresh app and run it."

**Pros:**
- Zero infrastructure cost.
- Matches every peer library surveyed — none of Finch, Req, Ecto, Oban, Swoosh, Broadway, Bandit, stripe-node, stripe-python, or stripe-ruby run automated README code tests. (stripe-node has TypeScript type-check on snippets; stripe-python has none found.)

**Cons:**
- No machine enforcement of Phase 19 success criterion #3.
- Human-error prone.

### Comparison

| Option | Pros | Cons | Complexity | Recommendation |
|---|---|---|---|---|
| A: `doctest_file` with iex hero | Official, zero deps, runs every PR | Hero no longer reads as copy-paste, copy-paste footgun, conflicts with Phase 9 D-01 | 1 test file + README rewrite — Risk: DX regression on the hero | Rec only if hero can stay iex-style (it shouldn't) |
| B: Custom fence-parsing integration test | Hero stays idiomatic, full end-to-end verification, off-by-default via `:integration` tag | ~30 LOC custom parser, harder failure debugging | 1 new test file, 1 CI step — Risk: brittle on README structure changes | **Primary recommendation** |
| C: `mix readme.verify` manual task | No CI cost, no default-test impact | Only catches drift at release time, maintainer discipline | 1 mix task ~40 LOC — Risk: forgotten runs | Rec as fallback if Option B is too heavy |
| D: Unmaintained hex lib (docception/markdown_test) | Off-the-shelf | Unmaintained, superseded by doctest_file | 1 dep — Risk: security/maintenance | Not recommended |
| E: Release checklist only | Matches all peer libraries, zero cost | Unautomated, human-error prone | 1 CONTRIBUTING edit — Risk: drift between releases | Rec if Option B ends up >50 LOC or flaky |

### Concrete sketch of Option B

    # test/readme_test.exs
    defmodule LatticeStripe.ReadmeTest do
      use ExUnit.Case, async: false

      @moduletag :integration
      @moduletag :readme

      @readme Path.join(__DIR__, "../README.md") |> Path.expand()

      setup_all do
        # stripe-mock is already running on :12111 per Phase 9 D-02
        start_supervised!({Finch, name: MyApp.Finch})
        :ok
      end

      test "README quickstart blocks execute against stripe-mock" do
        blocks = extract_elixir_blocks(File.read!(@readme))
        # Substitute production values with stripe-mock-compatible ones.
        script =
          blocks
          |> Enum.join("\n")
          |> String.replace(~s("sk_test_..."), ~s("sk_test_readme"))
          |> rewrite_client_for_stripe_mock()

        {result, _binding} = Code.eval_string(script, [])
        # The hero binds `payment_intent`; assert its shape.
        assert match?(%LatticeStripe.PaymentIntent{}, result) or result == :ok
      end

      defp extract_elixir_blocks(md) do
        ~r/```elixir\n(.*?)\n```/s
        |> Regex.scan(md, capture: :all_but_first)
        |> Enum.map(&hd/1)
      end

      defp rewrite_client_for_stripe_mock(script) do
        # Inject base_url override for stripe-mock without touching the README.
        String.replace(
          script,
          "LatticeStripe.Client.new!(",
          ~s|LatticeStripe.Client.new!(base_url: "http://localhost:12111", |
        )
      end
    end

**Budget:** ~40 LOC total. Runs only under `mix test --include integration` (Phase 9 D-01 preserved). Gated in CI by the same `integration` job that already boots stripe-mock (Phase 9 D-02, Phase 11 CI).

**Brittleness honest assessment:**
- Adding a new code block to the README *might* break the test if the block isn't intended to run (e.g., showing a bad pattern). Mitigation: test extracts only blocks from the `## Quick Start` section via a section-delimited regex, not every fenced block.
- Stripe API version drift: stripe-mock tracks Stripe's OpenAPI spec and auto-updates. When the pinned Stripe API version changes, the README example must stay compatible with whatever stripe-mock image is pinned in CI. This is actually a *feature* — it catches API drift before release.
- The failure mode when it breaks is obvious: "README quickstart no longer works against stripe-mock." Exactly what Phase 19 success criterion #3 wants to catch.

### Recommendation for Q2

**Option B (custom fence-parsing integration test, `@tag :integration`).** It's the only option that simultaneously (a) keeps the README hero in idiomatic copy-paste form for DX, (b) respects Phase 9 D-01's fast-default-test rule by tagging integration, (c) actually automates Phase 19 success criterion #3, and (d) reuses the stripe-mock infra from Phase 9. `doctest_file` is the "official" answer but forces an iex-prompted hero that hurts DX and conflicts with Phase 9. Manual / release-only options fail the "automated" half of the criterion. If Option B balloons past ~50 LOC or proves flaky in a first CI run, fall back to Option C (`mix readme.verify` manual task) — still better than nothing, and matches what the rest of the ecosystem does.

---

## Executive recommendation

**Ship Option D for Q1 and Option B for Q2 together.** Keep the Phase 10 D-18 PaymentIntent hero exactly as-is (it matches every surveyed peer library including Stripe's own first-party SDKs and passes the 60-second test), restructure the feature bullets into grouped Payments / Billing / Connect / Platform sub-sections with direct HexDocs guide links so v1.0 scope is scannable in the first screenful, and add a ~40 LOC `test/readme_test.exs` tagged `@tag :integration` that regex-extracts fenced elixir blocks from the Quick Start section, rewrites the client base URL to stripe-mock, and `Code.eval_string`s them as a single binding — reusing the stripe-mock container already booted in Phase 9 / Phase 11 CI. This is the smallest diff from current state that both represents v1.0's full Billing+Connect surface and machine-enforces the Phase 19 success criterion "README quickstart still passes the 60-second test," without forcing the hero into doctest syntax (which every attempt at README-as-doctest in HTTP SDK land has found hurts more than it helps).

## Sources

- [ExUnit.DocTest (Elixir 1.15+ `doctest_file`)](https://hexdocs.pm/ex_unit/ExUnit.DocTest.html)
- [Docception README — notes its own deprecation by doctest_file](https://github.com/evnu/docception)
- [elixirforum: Docception / doctest_file discussion](https://elixirforum.com/t/docception-run-doctests-for-markdown-files/21286)
- [markdown_test (MainShayne233)](https://github.com/MainShayne233/markdown_test)
- [Finch README](https://github.com/sneako/finch/blob/main/README.md)
- [Req README](https://github.com/wojtekmach/req/blob/main/README.md)
- [Ecto README](https://github.com/elixir-ecto/ecto/blob/master/README.md)
- [Phoenix README](https://github.com/phoenixframework/phoenix/blob/main/README.md)
- [Broadway README](https://github.com/dashbitco/broadway/blob/main/README.md)
- [Oban README](https://github.com/oban-bg/oban/blob/main/README.md)
- [Swoosh README](https://github.com/swoosh/swoosh/blob/main/README.md)
- [Bandit README](https://github.com/mtrudel/bandit/blob/main/README.md)
- [stripe-node README](https://github.com/stripe/stripe-node/blob/master/README.md)
- [stripe-python README](https://github.com/stripe/stripe-python/blob/master/README.md)
- [stripe-ruby README](https://github.com/stripe/stripe-ruby/blob/master/README.md)
- [stripe-mock](https://github.com/stripe/stripe-mock)
- [Tom Preston-Werner: README Driven Development](https://tom.preston-werner.com/2010/08/23/readme-driven-development.html)
- [standard-readme spec](https://github.com/RichardLitt/standard-readme)
- Project: `.planning/phases/10-documentation-guides/10-CONTEXT.md` D-18..D-23
- Project: `.planning/phases/09-testing-infrastructure/09-CONTEXT.md` D-01, D-02
- Project: `.planning/ROADMAP.md` Phase 19 success criteria
