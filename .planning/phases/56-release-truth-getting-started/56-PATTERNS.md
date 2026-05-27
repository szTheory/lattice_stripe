# Phase 56 — Pattern Map

**Mapped:** 2026-05-27

## Files to Modify

| File | Role | Closest Analog | Pattern to Replicate |
|------|------|----------------|----------------------|
| `guides/getting-started.md` | HexDocs main onboarding | `README.md` line 8 | Minimal blockquote one-liner only |
| `test/lattice_stripe/docs_truth_test.exs` | docs regression SSOT | Install pin tests (lines 4–19, 70–83) | `expected_install_snippet/0` + `@stale_install_pins` ritual |

## Analog: Install SSOT (extend for prose)

```elixir
@stale_install_pins ["1.1", "1.2", "1.3", "1.5"]

defp expected_install_snippet do
  [major, minor | _] = String.split(LatticeStripe.MixProject.project()[:version], ".")
  "{:lattice_stripe, \"~> #{major}.#{minor}\"}"
end
```

**Extend with:** `current_release_line/0` and `@stale_release_status_claims`.

## Analog: Positive + refute content lock (webhooks-thin-events)

```elixir
test "webhooks-thin-events guide locks the thin-event adopter contract" do
  guide = File.read!("guides/webhooks-thin-events.md")
  assert guide =~ "parse_event_notification"
  # ... positive anchors ...
  assert guide =~ "100 req/s"
end
```

**Apply to getting-started:** positive on derived release line + semantic anchor; refute stale claim strings.

## Analog: Describe-per-guide organization

Phase 48/57 pattern — separate describe blocks per guide contract:

```elixir
describe "guides/getting-started.md" do
  test "release-status prose matches current Hex surface" do
    # TRUTH-02
  end

  test "branches from first success into high-leverage guides" do
    # migrated cross-link test
  end
end
```

## Analog: README release block (partial — refactor target)

```elixir
test "readme release block and hexdocs clusters reflect v1.7 surface" do
  readme = File.read!("README.md")
  assert readme =~ "1.7"
  refute readme =~ "1.3.x` line is the current published"
end
```

**Refactor to:** `assert readme =~ current_release_line()` and iterate `@stale_release_status_claims`.

## Target prose (getting-started Installation section)

```markdown
```elixir
defp deps do
  [
    {:lattice_stripe, "~> 1.7"},
    {:finch, "~> 0.21"}
  ]
end
```

> **Release status:** **`1.7.x`** ships as the current published line on Hex (capstone release **1.7.0**).

Then fetch your dependencies:
```

## PATTERN MAPPING COMPLETE
