# Phoenix Web Module

StarView controllers should use a dedicated `:star_view` section in your
Phoenix web module. Keep it near the existing `controller` section so
controller-style imports stay grouped together.

```elixir
def star_view do
  quote do
    use Phoenix.Controller, formats: [:html, :json]
    use StarView
    use Phoenix.Component

    use Gettext, backend: MyAppWeb.Gettext

    import Phoenix.Component, except: [assign: 3]
    import Plug.Conn

    alias MyAppWeb.Components.StarView.Layout

    plug :put_root_layout, false

    unquote(verified_routes())
  end
end
```

The installer also generates `MyAppWeb.Components.StarView.Layout`.
`put_root_layout/2` disables Phoenix's root layout for StarView controllers,
and `Layout.app/1` emits the full document plus the initial Datastar signals
for the page.

Then use that section from a controller:

```elixir
defmodule MyAppWeb.CounterController do
  use MyAppWeb, :star_view

  @impl StarView
  def mount(conn, _params) do
    signal(conn, :count, 0)
  end

  @impl StarView
  def render(assigns) do
    ~H"""
    <Layout.app conn={@conn}>
      <button data-on:click={post("increment")}>+</button>
      <span data-text="$count">{@count}</span>
    </Layout.app>
    """
  end

  @impl StarView
  def handle_event("increment", signals, conn) do
    signal(conn, :count, Map.get(signals, "count", 0) + 1)
  end
end
```

## Router

Add the dispatch route inside your browser pipeline:

```elixir
pipeline :browser do
  # ...
  plug StarView.Plug.RenameCsrfParam
  plug :protect_from_forgery
  # ...
end

scope "/", MyAppWeb do
  pipe_through :browser

  get "/counter", CounterController, :mount
  post "/ds/:module/:event", StarView.Dispatch, [], alias: false
end
```

`StarView.Dispatch` decodes the target controller from the Datastar action,
verifies that it used `use StarView`, starts the SSE response, and calls
`handle_event/3`. The `alias: false` route option keeps Phoenix from resolving
the dispatch plug as `MyAppWeb.StarView.Dispatch` inside the scoped router
block.
`StarView.Plug.RenameCsrfParam` must run before `:protect_from_forgery` so
Datastar's `csrf` signal is available as Phoenix's `_csrf_token` parameter.
