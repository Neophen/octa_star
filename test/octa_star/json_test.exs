defmodule OctaStar.JSONTest do
  use ExUnit.Case, async: true

  alias OctaStar.JSON

  test "encodes Elixir nil as JSON null" do
    assert JSON.encode!(%{"remove" => nil}) == ~s({"remove":null})
  end

  test "decodes JSON null as Elixir nil" do
    assert JSON.decode!(~s({"remove":null,"items":[1,null]})) == %{
             "remove" => nil,
             "items" => [1, nil]
           }
  end

  test "returns errors for invalid JSON" do
    assert {:error, _reason} = JSON.decode("{")
  end
end
