# Phase 50 — Pattern Map

**Mapped:** 2026-05-27

## PATTERN MAPPING COMPLETE

## Tax.Settings (singleton)

| Target | Role | Analog | Excerpt |
|--------|------|--------|---------|
| `lib/lattice_stripe/tax/settings.ex` | singleton resource | `lib/lattice_stripe/balance.ex` | `retrieve/2` → `GET /v1/balance`, no id param |
| `settings.ex` update | singleton POST | *(new)* | `update/3` → `POST /v1/tax/settings` mirroring retrieve path |
| `test/.../settings_test.exs` | module surface guard | `test/lattice_stripe/balance_test.exs` | `refute function_exported?(..., :list, ...)` block |
| nested `Defaults` etc. | bounded structs | `lib/lattice_stripe/tax/calculation.ex` | `@known_fields` + `from_map/1` + `extra` |

**Balance retrieve pattern:**

```elixir
def retrieve(%Client{} = client, opts \\ []) do
  %Request{method: :get, path: "/v1/balance", params: %{}, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end
```

**Settings differs:** add symmetric `update/3` with `method: :post`, `path: "/v1/tax/settings"`, `params: params`.

## Tax.Registration (CRUDL)

| Target | Role | Analog | Excerpt |
|--------|------|--------|---------|
| `lib/lattice_stripe/tax/registration.ex` | CRUDL resource | `lib/lattice_stripe/credit_note.ex` | `create/3`, `retrieve/3`, `update/4`, `list/3`, `stream!/3` |
| `country_options` decode | map depth cap | `lib/lattice_stripe/account/settings.ex` | sub-objects stay plain maps |
| `test/.../registration_test.exs` | per-verb Mox | `test/lattice_stripe/credit_note_test.exs` | assert method + path suffix per describe |

**CreditNote list/stream:**

```elixir
def list(%Client{} = client, params \\ %{}, opts \\ []) do
  %Request{method: :get, path: "/v1/credit_notes", params: params, opts: opts}
  ...
end

def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
  list(client, params, opts) |> List.stream!()
end
```

## ObjectTypes

| Target | Analog |
|--------|--------|
| `"tax.settings" => Tax.Settings` | Phase 49 `"tax.calculation"` entry in `object_types.ex` |
| dispatch test | `object_types_test.exs` calculation case |
