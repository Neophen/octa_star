defmodule OctaStar.TestHandlers.Counter do
  @moduledoc false

  def handle_event(conn, "increment", signals) do
    count = Map.get(signals, "count", 0)
    OctaStar.patch_signals(conn, %{count: count + 1})
  end

  def handle_event(conn, "replace", _signals) do
    OctaStar.patch_elements(conn, ~s(<div id="target">Updated</div>))
  end
end

defmodule OctaStar.TestPhoenixBase do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      def action(conn, _opts), do: conn
      defoverridable action: 2
    end
  end
end

defmodule OctaStar.TestHandlers.PageController do
  @moduledoc false

  use OctaStar.TestPhoenixBase
  use OctaStar.Phoenix.Controller

  @impl StarView
  def mount(_params, conn), do: conn

  @impl StarView
  def render(assigns), do: assigns

  @impl StarView
  def handle_event("set_count", signals, conn) do
    signal(conn, :count, Map.get(signals, "count", 0))
  end
end
