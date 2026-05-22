defmodule Mix.Tasks.StarView.ServerTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.StarView.Server

  test "opens the browser by default" do
    assert Server.phx_server_args([]) == ["--open"]
    assert Server.phx_server_args(["--no-compile"]) == ["--open", "--no-compile"]
  end

  test "does not duplicate open flag" do
    assert Server.phx_server_args(["--open", "--no-compile"]) == ["--open", "--no-compile"]
  end

  test "supports disabling browser opening" do
    assert Server.phx_server_args(["--no-open"]) == []
    assert Server.phx_server_args(["--no-open", "--no-compile"]) == ["--no-compile"]
  end
end
