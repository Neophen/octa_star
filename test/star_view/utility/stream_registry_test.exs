defmodule StarView.StreamRegistryTest do
  use ExUnit.Case, async: false

  import Plug.Test

  alias StarView.StreamRegistry

  setup do
    {:ok, _} = start_supervised({Registry, keys: :unique, name: StreamRegistry})
    :ok
  end

  test "replace_and_register kills the previous holder for the same key" do
    test_pid = self()

    spawn(fn ->
      StreamRegistry.replace_and_register({:user, "tab-1"})
      send(test_pid, {:first, self()})
      Process.sleep(:infinity)
    end)

    assert_receive {:first, first_pid}

    spawn(fn ->
      StreamRegistry.replace_and_register({:user, "tab-1"})
      send(test_pid, {:second, self()})
      Process.sleep(:infinity)
    end)

    assert_receive {:second, second_pid}
    refute first_pid == second_pid

    refute Process.alive?(first_pid)
    assert [{^second_pid, nil}] = Registry.lookup(StreamRegistry, {:user, "tab-1"})
  end

  test "start_stream without tabId skips registration" do
    conn =
      :get
      |> conn("/")
      |> StreamRegistry.start_stream(:user_1)

    assert conn.state == :chunked
    assert Registry.lookup(StreamRegistry, {:user_1, "no-tab"}) == []
  end

  test "start_stream with tabId registers under scope and tab" do
    tab_id = "abc-tab"
    query = URI.encode_query(%{"datastar" => ~s({"tabId":"#{tab_id}"})})

    conn =
      :get
      |> conn("/?#{query}")
      |> StreamRegistry.start_stream(:user_1)

    assert conn.state == :chunked
    assert [{pid, nil}] = Registry.lookup(StreamRegistry, {:user_1, tab_id})
    assert pid == self()
  end
end
