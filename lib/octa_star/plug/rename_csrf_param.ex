defmodule OctaStar.Plug.RenameCsrfParam do
  @moduledoc """
  Copies a Datastar CSRF signal into `_csrf_token` for `Plug.CSRFProtection`.

  Add it before `:protect_from_forgery` when using Datastar form mode:

      plug OctaStar.Plug.RenameCsrfParam
      plug :protect_from_forgery
  """

  @behaviour Plug

  @impl Plug
  def init(opts), do: %{from: Keyword.get(opts, :from, "csrf")}

  @impl Plug
  def call(conn, %{from: from}) do
    case conn.params do
      %{"_csrf_token" => _token} ->
        conn

      %{^from => token} ->
        %{conn | body_params: Map.put(conn.body_params, "_csrf_token", token)}

      _ ->
        conn
    end
  end
end
