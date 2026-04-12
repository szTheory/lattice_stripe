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
