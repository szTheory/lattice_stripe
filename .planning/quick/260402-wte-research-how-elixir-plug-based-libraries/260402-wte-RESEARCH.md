# Research: Elixir Plug Path Matching & Mounting Strategies

**Quick Task:** 260402-wte
**Date:** 2026-04-03
**Status:** Complete

---

## 1. stripity_stripe WebhookPlug — The `at:` Pattern

Source: `beam-community/stripity_stripe` — `lib/stripe/webhook_plug.ex` (fetched via GitHub API)

### How `at:` Works

The plug is mounted in `endpoint.ex`, **before** `Plug.Parsers`:

```elixir
plug Stripe.WebhookPlug,
  at: "/webhook/stripe",
  handler: MyAppWeb.StripeHandler,
  secret: "whsec_..."
```

### `init/1` — Splits the path into a list

```elixir
def init(opts) do
  path_info = String.split(opts[:at], "/", trim: true)

  opts
  |> Enum.into(%{})
  |> Map.put_new(:path_info, path_info)
end
```

Key details:
- `String.split("/webhook/stripe", "/", trim: true)` produces `["webhook", "stripe"]`
- `trim: true` handles the leading slash cleanly — no empty string at index 0
- The result is stored under the `:path_info` key in the opts map

### `call/2` — Structural pattern matching on `path_info`

Three clauses, evaluated in order:

```elixir
# Clause 1: POST to the exact path — handle the webhook
def call(
      %Conn{method: "POST", path_info: path_info} = conn,
      %{path_info: path_info, secret: secret, handler: handler} = opts
    ) do
  secret = parse_secret!(secret)
  with [signature] <- get_req_header(conn, "stripe-signature"),
       {:ok, payload, conn} = Conn.read_body(conn),
       {:ok, %Stripe.Event{} = event} <- construct_event(payload, signature, secret, opts),
       :ok <- handle_event!(handler, event) do
    send_resp(conn, 200, "Webhook received.") |> halt()
  else
    {:handle_error, reason} -> send_resp(conn, 400, reason) |> halt()
    _ -> send_resp(conn, 400, "Bad request.") |> halt()
  end
end

# Clause 2: Non-POST request to the exact path — reject
def call(%Conn{path_info: path_info} = conn, %{path_info: path_info}) do
  send_resp(conn, 400, "Bad request.") |> halt()
end

# Clause 3: Path doesn't match — pass through unchanged
def call(conn, _), do: conn
```

**The clever bit:** The pattern `%Conn{path_info: path_info}` and `%{path_info: path_info}` use the **same variable name** in both patterns. Elixir's pattern matching pins `path_info` from the first pattern and requires it to equal the same value in the second pattern. So this is structural equality matching — the conn's `path_info` list must exactly equal the stored `path_info` list from `init/1`.

**Non-matching paths:** Clause 3 — `def call(conn, _), do: conn` — passes the connection through completely unmodified. No halt, no response. This is the correct pass-through behavior for a plug mounted in the endpoint pipeline.

**Raw body access:** `Conn.read_body(conn)` is called inside the plug, before `Plug.Parsers` runs. This works because the plug is mounted before `Plug.Parsers` in `endpoint.ex`. After `Plug.Parsers` runs, the body stream has been consumed and is no longer available.

---

## 2. `Plug.Router.forward/2` — How `path_info` Changes

Source: `hexdocs.pm/plug/Plug.Router.html` + `github.com/elixir-plug/plug/blob/main/lib/plug.ex`

### Usage

```elixir
forward "/users", to: UserRouter
forward "/foo/:bar/qux", to: FooPlug
```

### What Happens to `conn.path_info`

The actual implementation in `Plug.forward/4` (the underlying function):

```elixir
def forward(%Plug.Conn{path_info: path, script_name: script} = conn, new_path, target, opts) do
  {base, split_path} = Enum.split(path, length(path) - length(new_path))
  conn = do_forward(target, %{conn | path_info: split_path, script_name: script ++ base}, opts)
  %{conn | path_info: path, script_name: script}
end
```

Breaking this down:
1. `new_path` is the remaining path passed to the target (the segments after the matched prefix)
2. `Enum.split` divides the original `path_info` into `base` (consumed) and `split_path` (remaining)
3. The forwarded connection has `path_info: split_path` (only trailing segments)
4. `script_name` accumulates consumed segments: `script ++ base`
5. **After** the target plug returns, the original `path_info` and `script_name` are **restored**

### Concrete Example

Request to `/users/sign_in`:
- Before forward: `conn.path_info = ["users", "sign_in"]`, `conn.script_name = []`
- Inside `UserRouter`: `conn.path_info = ["sign_in"]`, `conn.script_name = ["users"]`
- After forward returns: original values restored on the outer conn

Request to `/foo/BAZ/qux` with `forward "/foo/:bar/qux", to: FooPlug`:
- Inside `FooPlug`: `conn.path_info = []`, `conn.params["bar"] = "BAZ"`, `conn.script_name = ["foo", "BAZ", "qux"]`

**The target plug is unaware of where it's mounted.** It sees only the trailing path segments.

---

## 3. Phoenix Router `forward/4` and `scope` + `post`

Source: `hexdocs.pm/phoenix/Phoenix.Router.html`

### `forward/4`

```elixir
scope "/", MyApp do
  pipe_through [:browser, :admin]
  forward "/admin", SomeLib.AdminDashboard
  forward "/api", ApiRouter
end
```

Behavior is identical to `Plug.Router.forward/2` for `path_info` manipulation — the forwarded plug sees only the trailing segments. Phoenix's `forward/4` also runs the router **pipelines** before forwarding, which `Plug.Router.forward/2` does not (Plug.Router has no pipeline concept).

**Key caveat:** "you can only forward to a given `Phoenix.Router` once" — Phoenix needs to generate routes properly.

**Note:** Forwarding to another Phoenix Endpoint is explicitly discouraged because plugs would be invoked twice.

### `scope` + `post` (Controller approach)

```elixir
scope "/", MyAppWeb do
  pipe_through :api
  post "/webhook/stripe", WebhookController, :handle
end
```

When using a standard controller route, the conn received by the controller has **already been through `Plug.Parsers`** — the raw body is gone. This is fine if you use the `CacheBodyReader` pattern (see §5). Without that, you cannot verify a signature.

### What the conn looks like when a Plug receives a forwarded Phoenix request

```
conn.path_info    => trailing segments only (prefix stripped)
conn.script_name  => consumed segments accumulated
conn.method       => unchanged ("POST", "GET", etc.)
conn.params       => merged — includes path params from the forward path pattern
conn.host         => unchanged
conn.assigns      => any assigns from pipeline plugs
conn.halted       => false (otherwise forwarding wouldn't happen)
```

---

## 4. Other Libraries — How They Handle Path Matching

### Plug.Static — `at:` option

Source: `github.com/elixir-plug/plug/blob/main/lib/plug/static.ex`

```elixir
# In init/1:
at: opts |> Keyword.fetch!(:at) |> Plug.Router.Utils.split()
```

Uses the same `Plug.Router.Utils.split/1` helper to convert the path string to a segment list.

In `call/2`:
```elixir
segments = subset(at, conn.path_info)
case path_status(only_rules, segments) do
  :forbidden -> conn    # pass through (no halt — just doesn't serve)
  :allowed -> ...       # serve the file
end
```

The `subset/2` helper does **prefix matching**: it checks whether `conn.path_info` starts with the configured `at` segments. If it does, it returns the remaining segments (the file path). If not, it returns an empty list → `:forbidden` → conn passed through unchanged.

**Important:** Plug.Static uses prefix matching, not exact matching. `/public/images/logo.png` matches `at: "/public"` and serves `images/logo.png`.

**Path matching approach:** Same `String.split(path, "/", trim: true)` → list-of-segments pattern as stripity_stripe.

### Absinthe.Plug — No path options, relies on router

Source: `hexdocs.pm/absinthe/plug-phoenix.html`

Absinthe.Plug accepts **no `at:` or path-matching options**. It processes every request that reaches it.

Two mounting strategies:

```elixir
# Option A: Endpoint-level (all-GraphQL API — every request goes to Absinthe)
plug Absinthe.Plug, schema: MyAppWeb.Schema

# Option B: Router forward (specific path only)
forward "/api", Absinthe.Plug, schema: MyAppWeb.Schema
```

Path isolation in Option B comes entirely from Phoenix's `forward/4` — Absinthe.Plug itself is unaware of the mount path.

**Design principle:** Absinthe.Plug is a fully self-contained handler. It assumes that any request reaching it is a GraphQL request. Path filtering is the caller's responsibility.

### Phoenix.LiveDashboard — Router macro, not endpoint

Source: `hexdocs.pm/phoenix_live_dashboard/Phoenix.LiveDashboard.Router.html`

LiveDashboard uses a **router macro** pattern, not a plug:

```elixir
# router.ex
import Phoenix.LiveDashboard.Router

scope "/" do
  pipe_through [:browser]
  live_dashboard "/dashboard",
    metrics: {MyAppWeb.Telemetry, :metrics}
end
```

The `live_dashboard/2` macro registers LiveView routes and the necessary LiveSocket. It never appears in `endpoint.ex`. This works because LiveDashboard doesn't need raw body access — it's serving a UI, not verifying signatures.

**Key insight:** Libraries that only need parsed data use the router macro or controller pattern. Libraries that need the raw body (webhook signature verification) must either use endpoint.ex placement before Plug.Parsers, or the CacheBodyReader pattern.

### elixir_plaid — CacheBodyReader + standard controller

Source: `hexdocs.pm/elixir_plaid/webhooks.html`

elixir_plaid takes the modern approach: no WebhookPlug. Instead:
1. `endpoint.ex`: `CacheBodyReader` configured as `body_reader` in `Plug.Parsers`
2. `router.ex`: Standard `POST /webhooks/plaid` route to a controller
3. Controller: reads `conn.assigns[:raw_body]` for signature verification

**No `at:` option** — path routing is handled by Phoenix router normally.

---

## 5. The Two Mounting Strategies

### Strategy A: Mount in `endpoint.ex` (before `Plug.Parsers`)

```elixir
# endpoint.ex
plug MyLib.WebhookPlug,
  at: "/webhooks/myservice",
  secret: "...",
  handler: MyApp.WebhookHandler

plug Plug.Parsers,
  parsers: [:urlencoded, :multipart, :json],
  json_decoder: Jason
```

**How it works:**
- The plug receives the raw, unconsumed body (it can call `Plug.Conn.read_body/2`)
- The plug must do its own path matching (the router hasn't run yet)
- Non-matching requests pass through unchanged
- Matching requests: read body, verify signature, halt pipeline

**Advantages:**
- Raw body access without any special setup — body hasn't been consumed yet
- Signature verification is guaranteed before any parsing happens
- Plug is self-contained: users add one line to endpoint.ex
- Simple mental model: one line installs the feature

**Disadvantages:**
- Plug must implement its own path matching (brittle — user must type path twice if they have a controller too)
- Bypasses Phoenix router pipelines — no authentication, logging, etc.
- Runs on every single request (even non-webhook requests check the path)
- Cannot use `plug_builder` pipelines, plug options from pipelines, etc.

**Used by:** stripity_stripe `Stripe.WebhookPlug`, custom plugs with pattern matching on `conn.request_path`

---

### Strategy B: Mount via `forward` in `router.ex`

```elixir
# router.ex
forward "/webhooks/myservice", MyLib.WebhookPlug, secret: "...", handler: MyApp.WebhookHandler
```

**How it works:**
- Phoenix router handles path matching — `forward` strips the matched prefix from `path_info`
- The plug receives `conn.path_info = []` (or remaining subpath segments)
- Router pipelines have already run (authentication, logging, etc.)
- Raw body is **unavailable** — `Plug.Parsers` ran in the pipeline

**Advantages:**
- No path-matching logic in the plug itself
- Router pipelines can add auth, CORS, logging before the plug runs
- Fits naturally into Phoenix router conventions
- Only runs for matching paths (no overhead on other requests)

**Disadvantages:**
- Raw body is gone — Plug.Parsers already consumed it
- Signature verification requires the `CacheBodyReader` workaround
- Two-step setup: CacheBodyReader in endpoint.ex + forward in router.ex
- More complex for users of a library (two configuration locations)

**Used by:** Absinthe.Plug (via `forward`), most non-signature-verifying plugs

---

### Strategy C: Standard route + `CacheBodyReader` (modern hybrid)

```elixir
# endpoint.ex
defmodule MyApp.CacheBodyReader do
  def read_body(conn, opts) do
    with {:ok, body, conn} <- Plug.Conn.read_body(conn, opts) do
      conn = update_in(conn.assigns[:raw_body], &[body | &1 || []])
      {:ok, body, conn}
    end
  end
end

plug Plug.Parsers,
  parsers: [:urlencoded, :multipart, :json],
  json_decoder: Jason,
  body_reader: {MyApp.CacheBodyReader, :read_body, []}
```

```elixir
# router.ex
post "/webhooks/myservice", WebhookController, :handle
```

```elixir
# controller
def handle(conn, _params) do
  raw_body = conn.assigns[:raw_body] |> Enum.join()
  # verify signature against raw_body
end
```

**Advantages:**
- Standard Phoenix routing — works with pipelines, authentication, etc.
- Raw body preserved in `conn.assigns[:raw_body]` for all requests
- Clean controller action — no plug complexity
- Path matching is just normal Phoenix routing

**Disadvantages:**
- CacheBodyReader reads and stores body for **every request** (memory overhead)
- Users must configure both endpoint.ex and router.ex
- Known gotchas: doesn't work in some test environments without special setup

**Used by:** elixir_plaid, Conner Fritz Stripe pattern (alternative version)

---

## 6. Phoenix `endpoint.ex` Conventions

### What goes in `endpoint.ex`

`endpoint.ex` is the outermost layer of a Phoenix application. Every HTTP request passes through it. Typical order:

```elixir
defmodule MyAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :my_app

  # 1. WebSocket/LiveView socket — must be before parsers
  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  # 2. Plugs that NEED raw body access — BEFORE Plug.Parsers
  plug MyLib.WebhookPlug, at: "/webhook/stripe", ...

  # 3. Static file serving
  plug Plug.Static, at: "/", from: :my_app, gzip: false, only: ~w(assets fonts images favicon.ico robots.txt)

  # 4. Request logging
  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  # 5. Body parsing — CONSUMES the raw body
  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason

  # 6. Session / CSRF
  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options

  # 7. Router — path-based routing begins here
  plug MyAppWeb.Router
end
```

**Convention for raw-body plugs:** Must be placed before `Plug.Parsers`. After Parsers, `Plug.Conn.read_body/2` returns `{:ok, "", conn}` — the body stream has been consumed.

### What goes in `router.ex`

Router handles path-based routing after `endpoint.ex` pipelines. Conventions:
- Authentication plugs (as pipeline steps)
- CORS handling
- API format negotiation
- Route-specific logic

### The Critical Ordering Rule

```
endpoint.ex: WebhookPlug → Plug.Parsers → Router
                 ^               ^
                 |               |
         raw body available  body consumed
```

Any plug that calls `Plug.Conn.read_body/2` must be placed before `Plug.Parsers`. There is no workaround except the `CacheBodyReader` pattern, which reads the body inside the parser itself and stores it before discarding the stream.

---

## Summary: Design Decision Matrix for LatticeStripe

| Factor | Endpoint + `at:` option | Router `forward` | CacheBodyReader + controller |
|--------|------------------------|------------------|------------------------------|
| Raw body access | Yes (native) | No | Yes (via assigns) |
| Path matching | Plug does it | Router does it | Router does it |
| User config complexity | 1 location (endpoint.ex) | 2+ locations | 2 locations |
| Phoenix pipelines apply | No | Yes | Yes |
| Per-request overhead | On every request (path check) | Only matching paths | Body stored for all requests |
| Self-contained | Yes | No (needs forward) | No (needs CacheBodyReader) |
| Used by | stripity_stripe | Absinthe.Plug | elixir_plaid, modern pattern |

**Recommendation for LatticeStripe WebhookPlug:**

The `endpoint.ex` + `at:` option pattern (Strategy A) is the right choice for a webhook signature verification plug because:
1. Raw body access is the entire point — the plug exists to read the body before parsers consume it
2. stripity_stripe already established this convention in the Elixir ecosystem — users know it
3. The `at:` option keeps configuration in one place
4. The implementation is clean: `String.split(at, "/", trim: true)` + pattern match in `call/2`

The path matching implementation should follow stripity_stripe's exact pattern: structural pattern matching using the same variable name in both `%Conn{path_info: path_info}` and `%{path_info: path_info}` in `call/2`.
