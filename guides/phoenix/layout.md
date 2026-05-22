# StarView Layout

The Igniter installer generates a dedicated layout module for StarView
controllers:

```elixir
defmodule MyAppWeb.Components.StarView.Layout do
  use MyAppWeb, :html
  import StarView.Controller, only: [init_signals: 1]

  attr :conn, :map, required: true
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <main data-signals={init_signals(@conn)}>
      {render_slot(@inner_block)}
    </main>
    """
  end

  def render("root.html", assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta name="csrf-token" content={get_csrf_token()} />
        <script type="module" src="https://cdn.jsdelivr.net/gh/starfederation/datastar@v1.0.1/bundles/datastar.js" />
      </head>
      <body data-signals:csrf={"'#{get_csrf_token()}'"}>
        {@inner_content}
      </body>
    </html>
    """
  end
end
```

The `:star_view` web-module section aliases that module and sets it as the root
layout for StarView controllers:

```elixir
alias MyAppWeb.Components.StarView.Layout

plug :put_root_layout, html: {Layout, :root}
```

Use `Layout.app/1` at the top of each StarView controller render:

```elixir
@impl StarView
def render(assigns) do
  ~H"""
  <Layout.app conn={@conn}>
    <button data-on:click={post("increment")}>+</button>
    <span data-text="$count">{@count}</span>
  </Layout.app>
  """
end
```

`Layout.app/1` writes the initial signal payload with `init_signals/1`. The root
layout adds the CSRF token and Datastar script once for the full page.
