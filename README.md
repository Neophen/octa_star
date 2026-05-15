# OctaStar

OctaStar is an Elixir SDK for [Datastar](https://data-star.dev) Server-Sent Events.
It targets Plug and Phoenix applications, follows the Datastar SDK event contract, and
uses Erlang/OTP's native `:json` implementation instead of adding a JSON dependency.

## Requirements

OctaStar requires Erlang/OTP 27 or later because it relies on the native `:json`
module. The package itself depends on Plug at runtime; Phoenix is optional and only
needed when using the Phoenix controller helpers.

## Installation

```elixir
def deps do
  [
    {:octa_star, "~> 0.1.0"}
  ]
end
```

## Plain Plug

```elixir
defmodule MyApp.CounterEvents do
  def handle_event(conn, "increment", signals) do
    count = Map.get(signals, "count", 0) + 1

    conn
    |> OctaStar.patch_signals(%{count: count})
    |> OctaStar.patch_elements(~s(<div id="count">#{count}</div>))
  end
end
```

```elixir
post "/ds/:module/:event",
  OctaStar.Plug.Dispatch,
  modules: [MyApp.CounterEvents]
```

`OctaStar.Plug.Dispatch` starts the SSE response before calling `handle_event/3`.

## Phoenix Controllers

Add the helper after your normal Phoenix controller setup:

```elixir
def controller do
  quote do
    use Phoenix.Controller, formats: [:html]
    use OctaStar.Phoenix.Controller
  end
end
```

Route Datastar events through the marker-based dispatcher:

```elixir
scope "/" do
  pipe_through :browser

  post "/ds/:module/:event", OctaStar.Phoenix.Dispatch, []
end
```

Controller example:

```elixir
defmodule MyAppWeb.CounterController do
  use MyAppWeb, :controller

  @impl OctaStar.Phoenix.ControllerBehaviour
  def show(conn, _params) do
    conn
    |> signal(:count, 0)
    |> assign(:step, 1)
  end

  @impl OctaStar.Phoenix.ControllerBehaviour
  def html(assigns) do
    ~H"""
    <div data-signals={init_signals(@conn)}>
      <button data-on:click={post("increment")}>+</button>
      <span data-text="$count">{@count}</span>
    </div>
    """
  end

  @impl OctaStar.Phoenix.ControllerBehaviour
  def handle_event(conn, "increment", signals) do
    signal(conn, :count, Map.get(signals, "count", 0) + 1)
  end
end
```

`OctaStar.Phoenix.Dispatch` starts the SSE response, calls `handle_event/3`, then
flushes any values tracked with `signal/3`.

## Inline Component Patching

`patch_element/3` renders a function component against the current connection assigns:

```elixir
def handle_event(conn, "replace_list", _signals) do
  conn
  |> assign(:items, ["Ada", "Grace"])
  |> patch_element(&list/1, to: "people", mode: :replace)
end
```

## CSRF With Datastar Form Mode

If you send form-encoded Datastar requests, keep the CSRF token in a client signal
named `csrf` and send it in the `x-csrf-token` header from your action. Add the
rename plug before Phoenix's CSRF protection so `Plug.CSRFProtection` sees
`_csrf_token`:

```elixir
plug OctaStar.Plug.RenameCsrfParam
plug :protect_from_forgery
```

Example form submit (form-encoded body; CSRF header from the `csrf` signal):

```heex
<form id="signup-form"
      data-signals={~s({"csrf":"#{Plug.CSRFProtection.get_csrf_token()}"})}
      data-on:submit={~s(@post('/ds/my_app_web-page_controller/submit', {contentType: 'form', headers: {'x-csrf-token': $csrf}, selector: '#signup-form'}))}>
```

## Per-Tab Stream Deduplication

OctaStar does not start `OctaStar.Utility.StreamRegistry` for you. Add it to your
application supervision tree when you want per-tab SSE deduplication:

```elixir
children = [
  OctaStar.Utility.StreamRegistry,
  # ...
]
```

Set a `tabId` signal in your root layout (no `_` prefix — Datastar keeps those
client-only), then start streams with:

```elixir
conn = OctaStar.start_stream(conn, current_user.id)
```

Without `tabId`, `start_stream/2` falls back to `start/1` with no deduplication.

## OctaStar vs dstar

OctaStar is a standalone package (no Hex dependency on dstar) with the same
Datastar SSE ergonomics: Plug-first, native `:json` on OTP 27+, and optional
Phoenix controller helpers.

| dstar | OctaStar |
| --- | --- |
| `Dstar` | `OctaStar` |
| `Dstar.Utility.StreamRegistry` | `OctaStar.Utility.StreamRegistry` |
| `$_dstar_module` | `$_octa_star_module` |
| `Dstar.read_signals/1` → map | `OctaStar.read_signals/1` → map |
| Auto registry (dstar app) | Opt-in registry in your app |

**Migration from dstar:** rename modules (`Dstar` → `OctaStar`, etc.), replace
`$_dstar_module` with `$_octa_star_module`, add `OctaStar.Utility.StreamRegistry`
to your supervision tree if you use `start_stream/2`, and swap form helpers for
a `csrf` signal plus `OctaStar.Plug.RenameCsrfParam` as shown above.

## Core Functions

The main facade exposes:

```elixir
OctaStar.start(conn)
OctaStar.start_stream(conn, user_id)
OctaStar.check_connection(conn)
OctaStar.patch_elements(conn, html, selector: "#target", mode: :replace)
OctaStar.remove_elements(conn, "#target")
OctaStar.patch_signals(conn, %{count: 1})
OctaStar.patch_signals_raw(conn, ~s({"count":1}))
OctaStar.remove_signals(conn, ["user.email"])
OctaStar.execute_script(conn, "console.log('done')")
OctaStar.redirect(conn, "/next")
OctaStar.console_log(conn, %{debug: true})
OctaStar.read_signals(conn)
```
