<p align="center">
  <img src="https://raw.githubusercontent.com/Neophen/octa_star/main/assets/logo.png" alt="OctaStar logo" width="128" />
</p>

# OctaStar - Unofficial helpers for DataStar and Phoenix

<p align="center">
  <a href="https://hexdocs.pm/octa_star">
    <img src="https://img.shields.io/github/v/release/Neophen/octa_star?color=lawn-green" alt="Version" />
  </a>
  <a href="https://hex.pm/packages/octa_star">
    <img src="https://img.shields.io/hexpm/dw/octa_star?style=flat&label=downloads&color=blue" alt="Downloads" />
  </a>
  <a href="https://github.com/Neophen/octa_star/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/Neophen/octa_star" alt="License" />
  </a>
</p>

OctaStar is an Elixir SDK for [Datastar](https://data-star.dev) Server-Sent Events.
It works with Plug and Phoenix, and uses Erlang's built-in `:json` module
so you don't need a JSON dependency.

**Requires Erlang/OTP 27+.**

## The Problem

Building Datastar apps in Elixir means a lot of boilerplate. You manually start
SSE connections, track which values to send to the browser, and remember to
flush them at the end. It's easy to forget a step.

OctaStar removes that.

## What Makes It Different

**`signal/3` does two things at once.**

It sets a connection assign (so your function components can read it) **and**
tracks it to send to the browser automatically.

```elixir
def handle_event(conn, "increment", signals) do
  conn
  # Server-only: function components can read @computed_value, browser never sees it
  |> assign(:computed_value, expensive_calculation(signals))

  # Both: function components can read @count, browser gets it too
  |> signal(:count, signals["count"] + 1)

  # Render a function component and patch it into the DOM
  |> patch_element(&history_item/1, to: "history-list", mode: :append)
end
```

**No manual start/flush.**

The dispatch plug starts the SSE response before your handler runs and flushes
tracked signals after. You never call `OctaStar.start/1` or remember to send
patches.

**Auto-registration.**

Any controller that `use OctaStar, :controller` is automatically dispatchable.
No allow-list in your router to maintain.

## Installation

### Quick (Igniter)

```bash
mix igniter.install octa_star
```

This adds the dependency, puts `StreamRegistry` in your supervision tree,
configures HTTPS in dev, patches your router with the dispatch route, and
generates a sample controller.

Skip parts you don't want:

```bash
mix igniter.install octa_star --no-stream-dedup --no-https --no-example
```

### Manual

```elixir
def deps do
  [
    {:octa_star, "~> 0.1.0"}
  ]
end
```

Add `OctaStar.Utility.StreamRegistry` to your supervision tree if you want
per-tab stream deduplication.

Add the dispatch route to your router:

```elixir
scope "/" do
  pipe_through :browser
  post "/ds/:module/:event", OctaStar.Phoenix.Dispatch, []
end
```

## Phoenix Setup

**1. Add `use OctaStar, :controller` to your web module:**

```elixir
def controller do
  quote do
    use Phoenix.Controller, formats: [:html]
    use OctaStar, :controller
  end
end
```

**2. Write a controller:**

```elixir
defmodule MyAppWeb.CounterController do
  use MyAppWeb, :controller

  # Called on page load. Set up initial signals here.
  @impl StarView
  def show(conn, _params) do
    conn
    |> signal(:count, 0)
  end

  # Render the initial HTML. Use init_signals/1 to send starting values to the browser.
  @impl StarView
  def html(assigns) do
    ~H"""
    <div data-signals={init_signals(@conn)}>
      <button data-on:click={post("increment")}>+</button>
      <span data-text="$count">{@count}</span>
    </div>
    """
  end

  # Called when the user clicks the button. Return the updated conn.
  @impl StarView
  def handle_event(conn, "increment", signals) do
    signal(conn, :count, Map.get(signals, "count", 0) + 1)
  end
end
```

That's it. The dispatcher handles SSE start, calls your handler, and flushes
any signals you tracked.

## `assign` vs `signal`

| Function | Function components see it | Browser sees it |
|---|---|---|
| `assign(conn, :key, value)` | Yes | No |
| `signal(conn, :key, value)` | Yes | Yes (auto-flushed) |

Use `assign` for server-only data you pass to components. Use `signal` for
anything the browser needs to react to.

## Patching Function Components

`patch_element/3` renders a function component against current assigns and sends
the HTML to the browser:

```elixir
def handle_event(conn, "add_item", _signals) do
  conn
  |> assign(:items, ["Ada", "Grace"])
  |> patch_element(&list/1, to: "people", mode: :replace)
end
```

Pass a function of arity 1 and it receives the assigns map. Pass raw HTML and
it sends that directly.

## Per-Tab Stream Deduplication

When a user navigates away, the old SSE process can stick around until the next
keepalive. That wastes connections. OctaStar can kill the old stream when a new
one starts from the same tab.

Add this to your supervision tree:

```elixir
children = [
  OctaStar.Utility.StreamRegistry,
  # ...
]
```

Set a `tabId` signal in your layout:

```heex
<div data-signals={~s({"tabId": "#{Ecto.UUID.generate()}"})}>
```

Start streams with:

```elixir
conn = OctaStar.start_stream(conn, current_user.id)
```

If no `tabId` is present, it falls back to a regular stream with no deduplication.

## CSRF (Forms)

You usually don't need forms with Datastar. If you do, put the CSRF token in a
`csrf` signal and add this plug before your CSRF protection:

```elixir
plug OctaStar.Plug.RenameCsrfParam
plug :protect_from_forgery
```

## Migration from Dstar

| Dstar | OctaStar |
|---|---|
| `Dstar` | `OctaStar` |
| `Dstar.Utility.StreamRegistry` | `OctaStar.Utility.StreamRegistry` |
| `$_dstar_module` | `$_octa_star_module` |
| `Dstar.read_signals/1` | `OctaStar.read_signals/1` |
| Manual `Dstar.start/1` | Handled by dispatch plug |
| Manual flush | Handled by dispatch plug |

## Full API

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
OctaStar.console_log(conn, "debug")
OctaStar.read_signals(conn)
```
