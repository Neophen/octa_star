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
               port: 4001
             ],
             https: [
               port: 4001,
               cipher_suite: :strong,
               keyfile: "priv/cert/selfsigned_key.pem",
               certfile: "priv/cert/selfsigned.pem"
             ]
           """

    assert content =~ ~s(star_view: [dev_url: "https://octafest.test:4001"])

    assert Enum.any?(
             igniter.notices,
             &String.contains?(&1, "StarView dev URL configured: https://octafest.test:4001")
           )

    assert_has_delayed_task(igniter, "phx.gen.cert", ["octafest.test", "localhost"])
  end

  test "generates the Phoenix search controller example" do
    igniter =
      phx_test_project(app_name: :octafest)
      |> Igniter.compose_task("star_view.install", ["--no-stream-dedup"])

    content = file_content(igniter, "lib/octafest_web/controllers/search_controller.ex")

    assert content =~ "defmodule OctafestWeb.SearchController do"
    assert content =~ "use OctafestWeb, :star_view"
    assert content =~ "def mount(conn, _params) do"

    web_module = file_content(igniter, "lib/octafest_web.ex")

    assert web_module =~ "def star_view do"
    assert web_module =~ "use Phoenix.Controller, formats: [:html, :json]"
    assert web_module =~ "use StarView"
    assert web_module =~ "use Phoenix.Component"
    assert web_module =~ "use Gettext, backend: OctafestWeb.Gettext"
    assert web_module =~ "import Phoenix.Component, except: [assign: 3]"
    assert web_module =~ "unquote(verified_routes())"
    assert web_module =~ ~r/def controller do.*def star_view do.*def live_view do/s

    router = file_content(igniter, "lib/octafest_web/router.ex")
    assert router =~ ~s|get("/search", SearchController, :mount)|
    assert router =~ ~s|post("/ds/:module/:event", Elixir.StarView.Dispatch, [])|
    refute router =~ "OctafestWeb.OctafestWeb.SearchController"
    refute router =~ "OctafestWeb.StarView.Dispatch"
  end

  defp file_content(igniter, path) do
    igniter.rewrite
    |> Rewrite.source!(path)
    |> Rewrite.Source.get(:content)
  end
end
