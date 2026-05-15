defmodule OctaStar.StarView do
  @moduledoc """
  Behaviour for OctaStar-enabled Phoenix controllers.

  Use `use OctaStar, :controller` in your `AppWeb.controller/0` macro, then
  implement callbacks with `@impl StarView`:

  ## Lifecycle

  1. `show/2` — Sets up initial signals and assigns for the page load.
  2. `html/1` — Renders the HEEx template. Use `init_signals/1` to emit the
     `data-signals` attribute for the initial client state.
  3. `handle_event/3` — Called by `OctaStar.Phoenix.Dispatch` when a Datastar
     action fires. The dispatcher starts the SSE response before this callback
     and flushes tracked signals afterwards.

  ## Example

      @impl StarView
      def show(conn, _params) do
        conn
        |> signal(:count, 0)
        |> signal(:step, 1)
      end

      @impl StarView
      def html(assigns) do
        ~H\"\"\"
        <div data-signals={init_signals(@conn)}>
          <button data-on:click={post("increment")}>+</button>
          <span data-text="$count">{@count}</span>
        </div>
        \"\"\"
      end

      @impl StarView
      def handle_event(conn, "increment", signals) do
        signal(conn, :count, Map.get(signals, "count", 0) + 1)
      end
  """

  @callback show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  @callback html(map()) :: term()
  @callback handle_event(Plug.Conn.t(), String.t(), map()) :: Plug.Conn.t()

  @optional_callbacks show: 2, html: 1, handle_event: 3
end
