defmodule Mix.Tasks.StarView.DevTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.StarView.Dev

  test "opens the browser by default" do
    assert Dev.phx_server_args([]) == ["--open"]
    assert Dev.phx_server_args(["--no-compile"]) == ["--open", "--no-compile"]
  end

  test "does not duplicate open flag" do
    assert Dev.phx_server_args(["--open", "--no-compile"]) == ["--open", "--no-compile"]
  end

  test "supports disabling browser opening" do
    assert Dev.phx_server_args(["--no-open"]) == []
    assert Dev.phx_server_args(["--no-open", "--no-compile"]) == ["--no-compile"]
  end
end
