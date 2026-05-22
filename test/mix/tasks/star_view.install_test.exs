defmodule Mix.Tasks.StarView.InstallTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  test "composes setup subtasks when options are enabled" do
    igniter =
      test_project()
      |> Igniter.compose_task("star_view.install", [])

    assert Enum.any?(igniter.notices, &String.contains?(&1, "dispatch plug"))
  end

  test "configures Phoenix endpoint URL and StarView dev URL" do
    igniter =
      phx_test_project(app_name: :octafest)
      |> Igniter.compose_task("star_view.install", ["--no-stream-dedup", "--no-example"])

    content = file_content(igniter, "config/dev.exs")

    assert content =~ """
             url: [
               scheme: "https",
               host: "octafest.test",
               port: 443
             ],
             https: [
               port: 4001,
               cipher_suite: :strong,
               keyfile: "priv/cert/selfsigned_key.pem",
               certfile: "priv/cert/selfsigned.pem"
             ]
           """

    assert content =~ ~s(star_view: [dev_url: "https://octafest.test"])

    assert Enum.any?(
             igniter.notices,
             &String.contains?(&1, "StarView dev URL configured: https://octafest.test")
           )
  end

  defp file_content(igniter, path) do
    igniter.rewrite
    |> Rewrite.source!(path)
    |> Rewrite.Source.get(:content)
  end
end
