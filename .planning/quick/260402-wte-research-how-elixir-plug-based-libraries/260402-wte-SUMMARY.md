# Quick Task 260402-wte: Summary

**Task:** Research how Elixir Plug-based libraries handle path matching and mounting strategies
**Date:** 2026-04-03
**Status:** Complete

## What Was Done

Researched six areas of Plug-based path matching and mounting in the Elixir/Phoenix ecosystem:

1. **stripity_stripe WebhookPlug** — fetched full source via GitHub API, documented exact `init/1` and `call/2` implementation
2. **Plug.Router forward/2** — documented `Plug.forward/4` source: path_info/script_name manipulation
3. **Phoenix Router forward/4 and scope+post** — documented conn shape, pipeline behavior, differences from Plug.Router
4. **Other libraries** — Plug.Static (`at:` prefix matching), Absinthe.Plug (no path opts), Phoenix.LiveDashboard (router macro), elixir_plaid (CacheBodyReader pattern)
5. **Two mounting strategies** — endpoint.ex vs router.ex, with a third hybrid (CacheBodyReader + controller)
6. **Phoenix endpoint.ex conventions** — ordering rules, why raw-body plugs must precede Plug.Parsers

## Key Findings

- **stripity_stripe's pattern** is the ecosystem standard for webhook plugs: `at:` option → `String.split(path, "/", trim: true)` in `init/1`, then structural pattern matching using the same variable name in `%Conn{path_info: path_info}` and `%{path_info: path_info}` in `call/2`. Non-matching requests: `def call(conn, _), do: conn`.

- **`Plug.forward/4` internals**: Splits `path_info` into consumed `base` and remaining `split_path`. The forwarded plug sees `path_info: split_path`, `script_name: original_script ++ base`. Original values are restored after the target plug returns.

- **Absinthe.Plug**: No path options at all — relies entirely on router `forward`. This only works because Absinthe doesn't need raw body access.

- **Plug.Static `at:`**: Uses `Plug.Router.Utils.split()` (same as stripity_stripe), then `subset/2` for prefix matching (not exact matching).

- **LiveDashboard**: Router macro pattern (`live_dashboard "/dashboard"` in `router.ex`). No endpoint placement needed.

- **The fundamental constraint**: Any plug needing raw body for signature verification MUST be placed before `Plug.Parsers` in `endpoint.ex`, OR use the `CacheBodyReader` body_reader pattern in `Plug.Parsers` config.

## Recommendation for LatticeStripe

The `endpoint.ex` + `at:` option pattern is the right choice for `LatticeStripe.WebhookPlug`. It matches the stripity_stripe convention, keeps user configuration in one place, and raw body access is the entire reason the plug exists.

## Artifacts

- PLAN.md: `.planning/quick/260402-wte-research-how-elixir-plug-based-libraries/260402-wte-PLAN.md`
- RESEARCH.md: `.planning/quick/260402-wte-research-how-elixir-plug-based-libraries/260402-wte-RESEARCH.md`
