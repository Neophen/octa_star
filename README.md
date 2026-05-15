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

If you send form-encoded Datastar requests and keep the CSRF token in a signal named
`csrf`, add the rename plug before Phoenix's CSRF protection:

```elixir
plug OctaStar.Plug.RenameCsrfParam
plug :protect_from_forgery
```

Then use the form action helpers from a Phoenix controller:

```elixir
<form data-on:submit={post_form("submit", "signup-form")}>
```

## Core Functions

The main facade exposes:

```elixir
OctaStar.start(conn)
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
