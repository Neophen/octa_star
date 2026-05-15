defmodule OctaStar.Phoenix.Dispatch do
  @moduledoc """
  Marker-based Datastar dispatch for Phoenix controllers.

  A controller is dispatchable when it uses `OctaStar.Phoenix.Controller`, which
  injects `__octa_star_handler__/0`.
  """

  @behaviour Plug

  import Plug.Conn

  alias OctaStar.Actions
  alias OctaStar.Phoenix.Controller
  alias OctaStar.Signals

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    conn = fetch_query_params(conn)
    module_param = conn.path_params["module"] || conn.params["module"]
    event = conn.path_params["event"] || conn.params["event"]

    with {:ok, module} <- decode_handler(module_param),
         {:ok, signals} <- Signals.read(conn) do
      conn
      |> OctaStar.start()
      |> module.handle_event(event, signals)
      |> Controller.flush_signals()
    else
      {:error, reason} ->
        send_error(conn, 400, "Invalid Datastar signals: #{inspect(reason)}")

      _ ->
        send_error(conn, 404, "Not found")
    end
  end

  defp decode_handler(nil), do: :error

  defp decode_handler(encoded) do
    with {:ok, module} <- Actions.decode_module(encoded),
         true <- handler?(module) do
      {:ok, module}
    else
      _ -> :error
    end
  end

  defp handler?(module) do
    Code.ensure_loaded?(module) and
      function_exported?(module, :__octa_star_handler__, 0) and
      function_exported?(module, :handle_event, 3)
  end

  defp send_error(conn, status, body) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(status, body)
  end
end
