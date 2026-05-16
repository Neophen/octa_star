defmodule OctaStar.SDKTestPlug do
  @moduledoc false

  import Plug.Conn

  def init(opts), do: opts

  def call(%Plug.Conn{request_path: "/test"} = conn, _opts) do
    case OctaStar.read_signals(conn) do
      %{"events" => events} ->
        Enum.reduce(events, OctaStar.start(conn), fn event, conn ->
          dispatch_event(conn, event)
        end)

      _ ->
        conn |> put_resp_content_type("text/plain") |> send_resp(400, "missing events")
    end
  rescue
    error in OctaStar.Signals.ReadError ->
      conn |> put_resp_content_type("text/plain") |> send_resp(400, Exception.message(error))
  end

  def call(conn, _opts), do: send_resp(conn, 404, "not found")

  defp dispatch_event(conn, %{"type" => "patchElements"} = event) do
    OctaStar.patch_elements(conn, Map.get(event, "elements"), event_opts(event, :elements))
  end

  defp dispatch_event(conn, %{"type" => "patchSignals"} = event) do
    opts = event_opts(event, :signals)

    case event do
      %{"signals-raw" => signals} -> OctaStar.patch_signals_raw(conn, signals, opts)
      %{"signals" => signals} -> OctaStar.patch_signals(conn, signals, opts)
    end
  end

  defp dispatch_event(conn, %{"type" => "executeScript"} = event) do
    OctaStar.execute_script(conn, Map.fetch!(event, "script"), event_opts(event, :script))
  end

  defp event_opts(event, type) do
    []
    |> put_if(:event_id, Map.get(event, "eventId"))
    |> put_if(:retry_duration, Map.get(event, "retryDuration"))
    |> put_element_opts(event, type)
    |> put_signal_opts(event, type)
    |> put_script_opts(event, type)
  end

  defp put_element_opts(opts, event, :elements) do
    opts
    |> put_if(:selector, Map.get(event, "selector"))
    |> put_if(:mode, Map.get(event, "mode"))
    |> put_if(:namespace, Map.get(event, "namespace"))
    |> put_if(:use_view_transition, Map.get(event, "useViewTransition"))
  end

  defp put_element_opts(opts, _event, _type), do: opts

  defp put_signal_opts(opts, event, :signals),
    do: put_if(opts, :only_if_missing, Map.get(event, "onlyIfMissing"))

  defp put_signal_opts(opts, _event, _type), do: opts

  defp put_script_opts(opts, event, :script) do
    opts
    |> put_if(:auto_remove, Map.get(event, "autoRemove"))
    |> put_if(:attributes, Map.get(event, "attributes"))
  end

  defp put_script_opts(opts, _event, _type), do: opts

  defp put_if(opts, _key, nil), do: opts
  defp put_if(opts, key, value), do: Keyword.put(opts, key, value)
end
