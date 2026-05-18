defmodule StarView.Phoenix.Dispatch do
  @moduledoc """
  Marker-based Datastar dispatch for Phoenix controllers.

  A controller is dispatchable when it uses `use StarView, :controller`, which
  injects `__star_view_handler__/0`.

  ## What this plug does

  1. Reads Datastar signals from the request body.
  2. Starts the SSE response (`StarView.start/1`).
  3. Calls `handle_event/3` on the target controller.
  4. Flushes any values tracked with `signal/3` as `datastar-signals` patches.

  This means your `handle_event/3` callbacks never need to call `StarView.start/1`
  or manually send signal patches — just use `signal/3` and `patch_element/3`.
  """

  @behaviour Plug

  import Plug.Conn

  alias StarView.Actions
  alias StarView.Phoenix.Controller
  alias StarView.Signals

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
      |> StarView.start()
      |> then(&module.handle_event(event, signals, &1))
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
      function_exported?(module, :__star_view_handler__, 0) and
      function_exported?(module, :handle_event, 3)
  end

  defp send_error(conn, status, body) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(status, body)
  end
end
