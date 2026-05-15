defmodule OctaStar.Plug.RenameCsrfParamTest do
  use ExUnit.Case, async: true
  import Plug.Test

  alias OctaStar.Plug.RenameCsrfParam

  defp call(conn, opts \\ []) do
    RenameCsrfParam.call(conn, RenameCsrfParam.init(opts))
  end

  test "copies csrf param into body_params _csrf_token" do
    conn =
      conn(:post, "/")
      |> Map.put(:params, %{"csrf" => "secret-token"})
      |> Map.put(:body_params, %{"other" => "value"})

    conn = call(conn)

    assert conn.body_params == %{"other" => "value", "_csrf_token" => "secret-token"}
  end

  test "passes through when _csrf_token is already in params" do
    conn =
      conn(:post, "/")
      |> Map.put(:params, %{"csrf" => "ignored", "_csrf_token" => "existing"})
      |> Map.put(:body_params, %{})

    conn = call(conn)

    assert conn.body_params == %{}
  end

  test "leaves conn unchanged when csrf param is absent" do
    conn =
      conn(:post, "/")
      |> Map.put(:params, %{"other" => "value"})
      |> Map.put(:body_params, %{"field" => "x"})

    conn = call(conn)

    assert conn.body_params == %{"field" => "x"}
  end

  test "supports a custom :from param name" do
    conn =
      conn(:post, "/")
      |> Map.put(:params, %{"my_csrf" => "custom-token"})
      |> Map.put(:body_params, %{})

    conn = call(conn, from: "my_csrf")

    assert conn.body_params == %{"_csrf_token" => "custom-token"}
  end
end
