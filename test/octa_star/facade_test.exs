defmodule OctaStar.FacadeTest do
  use ExUnit.Case, async: true
  import Plug.Test

  test "read_signals/1 returns a bare signal map" do
    conn = conn(:post, "/", ~s({"count":1}))

    assert OctaStar.read_signals(conn) == %{"count" => 1}
  end

  test "read_signals!/1 matches read_signals/1 on valid payloads" do
    conn = conn(:post, "/", ~s({"count":1}))

    assert OctaStar.read_signals!(conn) == OctaStar.read_signals(conn)
  end
end
