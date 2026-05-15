defmodule OctaStar.StarView do
  @moduledoc """
  Behaviour for OctaStar-enabled Phoenix controllers.

  Use `use OctaStar.Phoenix.Controller` in your controller, then implement
  callbacks with `@impl StarView`:

      @impl StarView
      def show(conn, _params), do: signal(conn, :count, 0)

      @impl StarView
      def html(assigns), do: ~H"..."

      @impl StarView
      def handle_event(conn, "increment", signals), do: ...
  """

  @callback show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  @callback html(map()) :: term()
  @callback handle_event(Plug.Conn.t(), String.t(), map()) :: Plug.Conn.t()

  @optional_callbacks show: 2, html: 1, handle_event: 3
end
