defmodule OctaStar.SignalsTest do
  use ExUnit.Case, async: true
  import Plug.Test

  alias OctaStar.Signals

  test "formats a signal patch" do
    assert Signals.format_patch(%{"count" => 1}, only_if_missing: true) ==
             """
             event: datastar-patch-signals
             data: onlyIfMissing true
             data: signals {"count":1}

             """
  end

  test "formats raw multiline signal JSON" do
    assert Signals.format_patch_raw("{\n  \"count\": 1\n}") ==
             """
             event: datastar-patch-signals
             data: signals {
             data: signals   "count": 1
             data: signals }

             """
  end

  test "formats signal removals as JSON null patches" do
    assert Signals.format_remove(["user.name", "user.email"]) ==
             """
             event: datastar-patch-signals
             data: signals {"user":{"email":null,"name":null}}

             """
  end

  test "reads GET signals from datastar query parameter" do
    conn = conn(:get, "/?datastar=%7B%22count%22%3A1%2C%22gone%22%3Anull%7D")

    assert Signals.read(conn) == {:ok, %{"count" => 1, "gone" => nil}}
  end

  test "reads raw JSON body for non-GET requests" do
    conn = conn(:post, "/", ~s({"count":1}))

    assert Signals.read(conn) == {:ok, %{"count" => 1}}
  end

  test "returns errors for invalid signal JSON" do
    conn = conn(:post, "/", "{")

    assert {:error, _reason} = Signals.read(conn)
  end

  test "rejects non-map signal payloads" do
    conn = conn(:get, "/?datastar=%5B1%5D")

    assert Signals.read(conn) == {:error, {:invalid_signals, [1]}}
  end
end
