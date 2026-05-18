defmodule StarView.StarView do
  @moduledoc """
  Behaviour for StarView-enabled Phoenix controllers.

  Use `use StarView, :controller` in your `AppWeb.controller/0` macro, then
  implement callbacks with `@impl StarView`:

  ## Lifecycle

  1. `mount/2` — Sets up initial signals and assigns for the page load.
  2. `render/1` — Renders the HEEx template. Use `init_signals/1` to emit the
     `data-signals` attribute for the initial client state.
  3. `handle_event/3` — Called by `StarView.Phoenix.Dispatch` when a Datastar
     action fires. The dispatcher starts the SSE response before this callback
     and flushes tracked signals afterwards.

  ## Example

      @impl StarView
      def mount(conn, _params) do
        conn
        |> signal(:count, 0)
        |> signal(:step, 1)
      end

      @impl StarView
      def render(assigns) do
        ~H\"""
        <div data-signals={init_signals(@conn)}>
          <button data-on:click={post("increment")}>+</button>
          <span data-text="$count">{@count}</span>
        </div>
        \"""
      end

      @impl StarView
      def handle_event("increment", signals, conn) do
        conn
        |> signal(:count, Map.get(signals, "count", 0) + 1)
      end
  """

  @callback mount(Plug.Conn.t(), map()) :: Plug.Conn.t()
  @callback render(map()) :: term()
  @callback handle_event(String.t(), map(), Plug.Conn.t()) :: Plug.Conn.t()

  @optional_callbacks handle_event: 3
end
