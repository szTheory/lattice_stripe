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

4. Run the full contributor gate locally:
   ```bash
   mix ci
   ```
   This runs: format check, compile warnings, Credo strict, tests, and docs build.

   Maintainers preparing a release also run:
   ```bash
   ./scripts/maintainer/repo_hygiene_check.sh
   ```
   See [docs/maintainer-release.md](docs/maintainer-release.md) for the release train procedure.

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

## Public API Surface Lock

`priv/api/current.txt` is a mechanically generated snapshot of everything covered by the
semver contract in [guides/api_stability.md](guides/api_stability.md): every module under
`lib/` without `@moduledoc false`, plus its public functions (every callable arity,
including those reachable through default arguments), struct field names, types, behaviour
callbacks, and protocol implementations. It is committed, and CI fails when it and the code
disagree.

**When the check fails it prints exactly which entries were added and removed.** Read that
list before doing anything else.

- **If you did not mean to change the public API, the failure is the bug.** Change the code
  back. The usual accidental causes are renaming a function, deleting a default argument
  value, removing a struct field, adding `@moduledoc false` or `@doc false` to something
  adopters already use, or dropping a `defimpl Inspect` — that last one silently starts
  leaking PII into logs.

- **If the change is deliberate**, regenerate the lock locally and commit it *in the same
  commit as the code change*:

  ```bash
  mix lattice_stripe.api_surface --update
  git add priv/api/current.txt
  ```

  Regeneration is refused when `CI` is set. That is intentional: where regenerating is
  possible in the gating environment it becomes the reflex, and the gate stops gating.

- **Anything listed under `REMOVED` is a breaking change.** Removing a module, a function,
  an arity (including by deleting a default argument value), a struct field, a callback or
  a protocol implementation all break adopters pinned to the current major. Mark the commit
  with `!` and record the removal in `guides/api_stability.md`:

  ```
  feat(account)!: remove Account.reject/4 in favour of Account.reject/3
  ```

  Note the project is pre-2.0 with `bump-minor-pre-major: false`, so a `!` commit cuts a
  **major** release. That is deliberately expensive — it is the cost of the break, not the
  cost of the tooling.

- **Entries only under `ADDED` are a feature.** A normal `feat:` commit is right. Adding a
  struct field is explicitly non-breaking.

Please do not regenerate the lock to make a red build green. It silences the break instead
of fixing it, and the next person to touch that code inherits the mess with no record of
where it came from.

To run the check on its own:

```bash
mix lattice_stripe.api_surface --check
```

Exit codes are distinct so CI can tell the two failure kinds apart: `0` clean, `100` the
surface changed, `101` the check itself could not run.

## Documentation Warnings

`mix docs --warnings-as-errors` runs in both `mix ci` and the CI **Quality** lane, so a broken
documentation reference fails the build.

The one non-obvious rule: **do not backtick a reference to something ExDoc cannot link.** That
means `@moduledoc false` modules, `@doc false` functions, and `defp` functions. Backticks are what
make ExDoc attempt the link, so naming an internal in prose is fine — ``LatticeStripe.ObjectTypes``
is not. Write it unbackticked, or describe the behaviour instead of naming the module.

Two other cases that bite:

- **Relative links only resolve to files listed in `extras:`.** `README.md` and
  `notebooks/*.livemd` are not extras, so link them by absolute GitHub URL. `CHANGELOG.md` is an
  extra and can be linked relatively.
- **Guides have no alias context.** Inside a guide, `` `File.create/3` `` resolves to Elixir's
  stdlib `File`, not ours. Fully qualify as `` `LatticeStripe.File.create/3` ``.

## Pull Request Process

1. Create a branch from `main` using the naming convention:
   - `feat/description` for features
   - `fix/description` for bug fixes
   - `chore/description` for maintenance
   - `docs/description` for documentation

2. Make your changes with Conventional Commit messages.

3. Ensure CI passes on your PR. GitHub requires the **`ci-gate`** job (format, compile, test matrix, integration, docs_truth, quality). Locally, `mix ci` covers the contributor gate.

4. Open a PR against `main`. Fill out the PR template.

5. PRs are squash-merged to keep a clean linear history on `main`.

**Note:** Changes to guides, `README.md`, or other `.md` files (outside `.planning/`) run the full CI suite, including `test/lattice_stripe/docs_truth_test.exs`. Planning-only edits under `.planning/` still skip CI.

## Code Style

- Follow existing patterns in the codebase
- Run `mix format` before committing
- Run `mix credo --strict` for style checks
- Typespecs are for documentation only (no Dialyzer)
