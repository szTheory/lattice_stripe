# Advisor Research — Cleanup Scope + API Audit

**Scope:** Phase 19, LatticeStripe v1.0.0 cut. Two coupled gray areas: (Q1) which accumulated cleanup to pull into 1.0 vs defer, and (Q2) how to lock the public API surface before semver stability kicks in forever.

**Key prior decisions to not contradict:**
- Phase 10 D-03 — internal modules live in an "Internals" ExDoc group, **not** hidden with `@moduledoc false`.
- Phase 11 D-16 — pre-1.0 semver-ish (breaking = minor bump, feature = patch). This inverts at 1.0.
- CLAUDE.md — "typespecs for documentation only, not enforced" (no Dialyzer).
- Repo reality check: `grep TODO|FIXME|XXX|HACK` across `lib/` returns **zero hits**. Cleanup scope is mostly about CONTEXT.md deferred blocks and VERIFICATION.md warnings, not rotting inline comments.

---

## Q1: Cleanup Scope

### Options

| Option | Pros | Cons | Complexity | Recommendation |
|--------|------|------|------------|----------------|
| **A. Maximalist ("zero-debt 1.0")** — drain every CONTEXT.md `<deferred>` block, every VERIFICATION.md warning, every typespec gap, every code-review info-finding before cutting 1.0 | No backlog crossing the 1.0 boundary; strong story for v1.0 announcement | Scope explosion — Phase 19 becomes a de-facto Phase 9.5 for every prior phase; delays v1.0 indefinitely; "deferred" items were deferred *for reasons*, often correctly | Huge surface, many files — Risk: endless-polish trap, morale, missing the release window | Rec only if Cashier/Pay downstream blocker is already unblocked and timeline pressure is low |
| **B. API-boundary-only ("lock surface, defer internals")** — include only items that touch the public API surface (names, arities, return shapes, error types, typespecs on public functions, public moduledocs). Defer everything behind the API boundary to post-1.0 patch/minor releases | Smallest scope that still honors semver — 1.0 locks what users depend on. Internal cleanup is safe post-1.0 because it's non-breaking. Matches how Phoenix/Ecto/Broadway actually shipped 1.0 (see precedent) | Leaves some known-ugly internals in 1.0.0; requires a disciplined definition of "public surface" | ~public modules only — Risk: mis-classifying something as internal that users grab via Hyrum's law | **Recommended default** — decisive, mechanical, and honors semver at the only boundary that matters |
| **C. Triaged hybrid** — classify every deferred item into {include, defer-to-1.1, defer-to-2.0}, then execute the include bucket | More nuanced, captures "quick wins" that aren't strictly API-boundary | Triage meeting becomes the work; judgement calls proliferate; harder to mechanize | Medium — Risk: bikeshedding each item | Rec if you expect the backlog is heterogeneous and contains obvious high-value non-API fixes |

### Precedent

- **Broadway 1.0.0 (2021-08-30)** shipped with backwards-incompatible changes (removed `Broadway.TermStorage`, renamed telemetry measurements, renamed event namespaces). It did **not** try to reach a "zero-debt" state — it locked the API surface and batched the remaining known breakages into the 1.0 cut itself. [[Broadway CHANGELOG](https://github.com/dashbitco/broadway/blob/main/CHANGELOG.md)]
- **Req** (still pre-1.0 at v0.5.17 as of April 2026) — the explicit reason Req hasn't cut 1.0 is that the maintainer (wojtekmach) is still comfortable making breaking changes at the API boundary and uses the 0.x minor bumps as the signal. The lesson: **you only cut 1.0 when you're ready to stop breaking the surface, not when you're ready to stop changing anything**. [[Req changelog](https://github.com/wojtekmach/req/blob/main/CHANGELOG.md)]
- **Elixir official library guidelines** — "pre-1.0 libraries provide no guarantees about what might change from one version to the next." The flip side: 1.0 is specifically a surface-stability commitment, not a code-quality commitment. [[Library guidelines](https://hexdocs.pm/elixir/library-guidelines.html)]
- **Oban** ships minor releases with internal refactors, plugin supervision tree rework, and stability improvements **without** bumping major — concrete proof that non-breaking internal work is fine on a patch/minor after 1.0. [[Oban CHANGELOG](https://hexdocs.pm/oban/changelog.html)]

### Recommendation

**Adopt Option B ("API-boundary-only") with a mechanical include/defer rule the planner can apply without judgement.**

Mechanical rule for each candidate cleanup item:

> **INCLUDE in 19 iff the item is observable from a user's call site.** That is: (a) it changes a public module/function name, arity, or return shape; (b) it changes an error type, error reason atom, or telemetry event name/metadata; (c) it fixes a `@doc` / `@moduledoc` / `@typedoc` on a public module; (d) it fixes a typespec on a *public* function; (e) it changes default config values or NimbleOptions schema for public options.
>
> **DEFER to post-1.0 otherwise.** Specifically defer: internal refactors, dead code cleanup, additional test coverage for already-covered branches, typespec polish on private functions, VERIFICATION.md informational findings that don't change behavior, and any `deferred` block item that the original phase explicitly marked as non-breaking.

Rationale: LatticeStripe's `lib/` tree has zero inline TODO/FIXME markers (verified via grep at commit `3ceb913`), so the cleanup backlog is entirely in planning artifacts. The planning artifacts exist precisely *because* items were judged non-critical at the time — re-litigating them in Phase 19 is a polishing trap. Locking the API and shipping 1.0 unblocks Cashier/Pay downstream work (per project mission), which is a higher-leverage outcome than draining the backlog. Phase 19 becomes surgical: walk the public surface once, defer everything else to a visibly-scheduled 1.1.

---

## Q2: Public API Surface Audit

### Options

| Option | Pros | Cons | Complexity | Recommendation |
|--------|------|------|------------|----------------|
| **A. Status quo — keep Phase 10 D-03** ("Internals" ExDoc group visible, no renames, no formal stability contract, no deprecations) | Zero churn; preserves existing docs; Phase 10 D-03 already litigated | Users can (and will, per Hyrum's law) reach into `LatticeStripe.Resource`, `LatticeStripe.FormEncoder`, `LatticeStripe.Request` because they're *visible* in docs. Once 1.0 ships, those become de facto public and can't be refactored without a major bump | Low — Risk: Hyrum's law on helper modules | Not recommended at 1.0 |
| **B. Hide internals with `@moduledoc false`, lock the external surface** — flip D-03 for 1.0: every module in the `Internals` group gets `@moduledoc false`. External surface (Core, Payments, Billing, Connect, Checkout, Webhooks, Telemetry, Testing) stays fully documented. Publish a short "API Stability" page in guides. No rename sweep unless something is actively wrong. No preemptive `@deprecated` | Clean semver boundary: only the documented surface is covered by the 1.0 guarantee. Matches the Elixir ecosystem convention. Future internal refactors (Resource helper, FormEncoder) are free. Matches what users actually need | Requires flipping Phase 10 D-03 (which was correct for 0.x learning phase, wrong for 1.0 commitment). One new guide page | ~10-20 modules gain `@moduledoc false` + one new guide — Risk: users who were already depending on internals get a one-time breakage at 1.0 (acceptable, it's a major) | **Recommended** |
| **C. Option B + aggressive rename sweep** — do a one-pass consistency sweep (verb choice, `create/1` vs `create/2`, option key naming, error reason atoms). Rename anything inconsistent before the 1.0 freeze | Cleanest possible surface; maximum long-term ergonomics | High risk of introducing regressions right before cutting 1.0; every rename is a breaking change; the existing names were validated across 8+ resource phases and are already internally consistent | High surface — Risk: last-minute bugs, churn in downstream integration tests, guide examples | Rec only if the audit *finds* a specific inconsistency — do not rename for renaming's sake |
| **D. Option B + `@deprecated` any known warts for 2.0** | Communicates intent; gives users a migration runway | No concrete deprecations are identified right now; adding `@deprecated` with nothing to deprecate is noise. Deprecations are a post-1.0 tool, not a 1.0-cut tool | Low — Risk: phantom deprecations | Defer — introduce `@deprecated` organically in 1.x when real warts surface |

### Precedent

- **Elixir's own docs guidance**: "Besides the modules and functions libraries provide as part of their public interface, libraries may also implement important functionality that is not part of their API... should not have documentation for end users." The recommended convention is `@moduledoc false` for internal modules. [[Writing Documentation](https://hexdocs.pm/elixir/writing-documentation.html)]
- **Phoenix, Ecto, Plug, Finch, Broadway** — all use `@moduledoc false` liberally for internal helpers (e.g., `Phoenix.Router.Helpers`, `Ecto.Query.Builder.*`, `Plug.Conn.Adapter`, `Finch.HTTP1.Pool`). None ship an "Internals" visible group at 1.0+. The "visible internals" pattern is an early-learning-phase choice that gets flipped at 1.0. [[Elixir library-guidelines](https://hexdocs.pm/elixir/library-guidelines.html)]
- **Broadway 1.0** batched its breaking changes into the 1.0 cut itself (removed modules, renamed telemetry), then stopped breaking things. It did **not** do a speculative rename sweep — changes in 1.0.0 were driven by concrete prior complaints, not polish. [[Broadway CHANGELOG](https://github.com/dashbitco/broadway/blob/main/CHANGELOG.md)]
- **Stripe's own SDKs** (stripe-node, stripe-python, stripe-go) follow strict semver: major bump only for API-breaking changes, minor for additive, patch for fixes. They publish an explicit "versioning and support policy" page. LatticeStripe should do the same at 1.0. [[Stripe SDK versioning](https://docs.stripe.com/sdks/versioning)]
- **Hyrum's law** (Hyrum Wright, Google): "With a sufficient number of users of an API, it does not matter what you promise in the contract: all observable behaviors of your system will be depended on by somebody." Implication: if internal modules are *visible* in ExDoc, someone will depend on them. `@moduledoc false` is the cheapest defense.
- **`@deprecated` usage in Elixir** — the attribute emits a compile-time warning and is the standard mechanism for signalling deprecation. It pairs with `@doc deprecated: "..."` for ExDoc rendering. Broadway, Ecto, and Phoenix all use this pattern, but only for *actual* deprecations, not speculative ones. [[Elixir @deprecated](https://hexdocs.pm/elixir/Module.html)]

### Recommendation

**Adopt Option B: flip Phase 10 D-03 for 1.0, hide internals, publish a stability contract, skip speculative renames and deprecations.**

Concrete Phase 19 actions the planner can drop into plans:

1. **Internals hiding pass.** For every module currently in the Phase 10 D-01 "Internals" group (`Transport`, `Transport.Finch`, `JSON`, `JSON.Jason`, `RetryStrategy`, `FormEncoder`, `Request`, `Resource`), add `@moduledoc false`. Keep function-level docs for maintainers. Drop the "Internals" group from `mix.exs` ExDoc config. **Exception:** behaviours that users are *meant* to implement (`Transport`, `RetryStrategy`, `JSON`) stay visible — they're public extension points, not internals. This leaves ~4-5 modules (`FormEncoder`, `Request`, `Resource`, `Transport.Finch`, `JSON.Jason`) to hide.
2. **Stability contract page.** Add `guides/api_stability.md` (or append to `extending.md`) explicitly stating: modules documented in ExDoc are public; modules with `@moduledoc false` are private and may change in any patch release; behaviour contracts (Transport/RetryStrategy/JSON) follow semver; nested typed structs follow semver on field *presence* but not on field *addition* (so users should match with `%Customer{id: id} = c`, not `= %Customer{...}`). Mirror Stripe's SDK versioning page structure. [[Stripe SDK versioning](https://docs.stripe.com/sdks/versioning)]
3. **Public-surface audit checklist**, executed once in Phase 19, covering: (a) every public module has `@moduledoc`; (b) every public function has `@doc` with example; (c) every public function has a `@spec`; (d) error reason atoms are enumerated in the `Error` module `@typedoc`; (e) telemetry event names + metadata map are enumerated in the `Telemetry` moduledoc. No renames unless the audit surfaces a concrete inconsistency; renames are breaking and must be justified individually.
4. **No preemptive `@deprecated`.** Introduce deprecations reactively in 1.x as real warts surface. Adding `@deprecated` with no replacement-target is noise.
5. **Update Phase 11 D-16.** Post-1.0 semver flips: major = breaking public surface, minor = additive public surface, patch = fixes + internal refactors. Document this in CHANGELOG preamble at the 1.0 cut.

Rationale: LatticeStripe's "north star" is "unsurprising for Elixir devs" — Elixir devs expect `@moduledoc false` internals and a short stability page, not a visible Internals group (that was a 0.x learning-phase choice). Hyrum's law makes the visible-internals pattern dangerous at 1.0 because any user who grabs `LatticeStripe.Resource` today turns it into a breaking-change blocker tomorrow. The rename sweep and preemptive-deprecation options are both lower-leverage and higher-risk than just locking what's already stable.

---

## Executive Recommendation

**Ship 1.0 by locking the documented API surface and deferring everything behind it.** Phase 19 should execute a surgical public-surface audit (moduledocs, docs, typespecs, error atoms, telemetry events) while flipping Phase 10 D-03 to hide non-behaviour internals with `@moduledoc false` and publishing a short API stability page. Do not drain CONTEXT.md deferred blocks unless they cross the public API boundary, do not rename for polish, and do not add speculative `@deprecated`. The mechanical rule — "include iff observable from a user's call site; defer otherwise" — gives the planner a bright-line test that avoids the endless-polish trap, matches how Broadway/Oban/Phoenix actually shipped 1.0, and unblocks the downstream Cashier/Pay work that justifies LatticeStripe's existence.

## Sources

- [Elixir Library Guidelines](https://hexdocs.pm/elixir/library-guidelines.html) — semver and pre-1.0 guarantees
- [Elixir Writing Documentation](https://hexdocs.pm/elixir/writing-documentation.html) — `@moduledoc false` convention
- [Elixir Module docs (`@deprecated`)](https://hexdocs.pm/elixir/Module.html)
- [Broadway CHANGELOG](https://github.com/dashbitco/broadway/blob/main/CHANGELOG.md) — 1.0.0 breaking-change batching
- [Oban CHANGELOG](https://hexdocs.pm/oban/changelog.html) — post-1.0 internal refactor cadence
- [Req CHANGELOG](https://github.com/wojtekmach/req/blob/main/CHANGELOG.md) — deliberate pre-1.0 dwell
- [Stripe SDK versioning policy](https://docs.stripe.com/sdks/versioning) — model for LatticeStripe's stability page
- [Stripe API versioning blog](https://stripe.com/blog/api-versioning)
- Phase 10 CONTEXT.md D-01..D-05 (in-repo)
- Phase 11 CONTEXT.md D-16 (in-repo)
- Repo `lib/` grep for TODO/FIXME/XXX/HACK → zero hits at `3ceb913`
