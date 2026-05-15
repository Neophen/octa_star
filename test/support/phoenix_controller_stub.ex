defmodule Phoenix.Controller do
  @moduledoc false

  import Plug.Conn

  def put_view(conn, opts), do: put_private(conn, :phoenix_view, opts)
  def render(conn, :html), do: send_resp(conn, 200, "rendered")
end
