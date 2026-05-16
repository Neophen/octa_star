defmodule Mix.Tasks.OctaStar.InstallTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  test "composes setup subtasks when options are enabled" do
    igniter =
      test_project()
      |> Igniter.compose_task("octa_star.install", [])

    assert Enum.any?(igniter.notices, &String.contains?(&1, "dispatch plug"))
  end
end
