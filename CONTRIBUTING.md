# Contributing to LatticeStripe

Thank you for your interest in contributing to LatticeStripe!

## Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/szTheory/lattice_stripe.git
   cd lattice_stripe
   ```

2. Install dependencies:
   ```bash
   mix deps.get
   ```

3. Run the test suite:
   ```bash
   mix test
   ```

4. Run the full CI checks locally:
   ```bash
   mix ci
   ```
   This runs: format check, compile warnings, Credo strict, tests, and docs build.

## Running Integration Tests

Integration tests require [stripe-mock](https://github.com/stripe/stripe-mock), Stripe's official mock HTTP server.

Start stripe-mock via Docker:
```bash
docker run -p 12111:12111 -p 12112:12112 stripe/stripe-mock:latest
```

Then run integration tests:
```bash
mix test --include integration
```

## Running `:real_stripe` tests

A small set of tests under `test/real_stripe/` exercises live Stripe test
mode (not `stripe-mock`). They are tagged `:real_stripe` and EXCLUDED by
default — `mix test` never runs them unless you opt in with
`--include real_stripe`.

### Prerequisites

1. A Stripe **test-mode** secret key. Get one from
   https://dashboard.stripe.com/test/apikeys. **Never use a live key** — the
   `LatticeStripe.Testing.RealStripeCase` case template refuses keys that
   start with `sk_live_` as a non-negotiable safety guard.
2. The environment variable `STRIPE_TEST_SECRET_KEY` must be set to that key.

### Recommended: `direnv` + `.envrc`

The repo does not commit any `.envrc` file (`.envrc` is in `.gitignore`).
Create one locally:

```bash
# .envrc (in the repo root — gitignored)
export STRIPE_TEST_SECRET_KEY=sk_test_yourkeyhere
```

Then `direnv allow` once. From then on, `cd`-ing into the repo exports the
key automatically. Install direnv via `brew install direnv` (macOS) or
your distro's package manager, and hook it into your shell per
https://direnv.net/docs/hook.html.

### Running the suite

```bash
# Run ONLY the real_stripe tests (requires STRIPE_TEST_SECRET_KEY):
mix test --include real_stripe --only real_stripe

# Run everything: unit + stripe-mock integration + real Stripe:
mix test --include integration --include real_stripe
```

### CI

GitHub Actions stores `STRIPE_TEST_SECRET_KEY` as a repository secret. The
`:real_stripe` job reads it from the job env. If the secret is missing in a
CI run (e.g. rotated by accident), the tests **flunk loudly** rather than
skipping — use `LatticeStripe.Testing.RealStripeCase`'s `setup_all` gate as
the canonical example for phases 14+.

### Safety

- Keys starting with `sk_live_` cause an immediate `flunk/1` — NON-NEGOTIABLE.
- Non-CI runs with no key → skipped with a friendly message.
- CI runs with no key → flunk (secret rotation must be noticed).
- All real_stripe tests run with `async: false` and a 120s per-test timeout.
- Resources created during tests are cleaned up by `on_exit` (ExUnit Owner
  pattern) and backstopped by `mix lattice_stripe.test_clock.cleanup`.

## Commit Convention

This project uses [Conventional Commits](https://www.conventionalcommits.org/). All commit messages must follow this format:

```
type(scope): description

[optional body]
```

Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `perf`

Examples:
- `feat(customer): add search endpoint`
- `fix(retry): respect Stripe-Should-Retry header`
- `docs(webhook): add Phoenix mounting guide`

Release Please uses these commit messages to automate version bumps and changelog generation.

## Pull Request Process

1. Create a branch from `main` using the naming convention:
   - `feat/description` for features
   - `fix/description` for bug fixes
   - `chore/description` for maintenance
   - `docs/description` for documentation

2. Make your changes with Conventional Commit messages.

3. Ensure all CI checks pass:
   - `mix format --check-formatted`
   - `mix compile --warnings-as-errors`
   - `mix credo --strict`
   - `mix test`
   - `mix docs`

4. Open a PR against `main`. Fill out the PR template.

5. PRs are squash-merged to keep a clean linear history on `main`.

**Note:** Docs-only PRs (changes only to `.md`, `.planning/`, or `guides/` files) may require maintainer bypass of CI status checks since CI is skipped for documentation-only changes.

## Code Style

- Follow existing patterns in the codebase
- Run `mix format` before committing
- Run `mix credo --strict` for style checks
- Typespecs are for documentation only (no Dialyzer)
