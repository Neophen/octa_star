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

    unquote(verified_routes())
  end
end
```

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
    <div data-signals={init_signals(@conn)}>
      <button data-on:click={post("increment")}>+</button>
      <span data-text="$count">{@count}</span>
    </div>
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
scope "/", MyAppWeb do
  pipe_through :browser

  get "/counter", CounterController, :mount
  post "/ds/:module/:event", Elixir.StarView.Dispatch, []
end
```

`StarView.Dispatch` decodes the target controller from the Datastar action,
verifies that it used `use StarView`, starts the SSE response, and calls
`handle_event/3`.
