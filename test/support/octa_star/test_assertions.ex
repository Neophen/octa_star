defmodule OctaStar.TestAssertions do
  @moduledoc false

  def chunked_resp(%Plug.Conn{adapter: {Plug.Adapters.Test.Conn, state}} = conn) do
    {conn.status, conn.resp_headers, state.chunks || ""}
  end
end
