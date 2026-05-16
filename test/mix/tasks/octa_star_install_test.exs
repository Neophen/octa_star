defmodule Mix.Tasks.OctaStar.InstallTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  @tag :skip
  test "generates example controller for Phoenix projects" do
    phoenix_test_project()
    |> Igniter.compose_task("octa_star.install", ["--no-https", "--no-stream-dedup"])
    |> assert_creates("lib/test_web/octa_star_demo_controller.ex")
  end

  @tag :skip
  test "skips example generation when --no-example" do
    phoenix_test_project()
    |> Igniter.compose_task("octa_star.install", ["--no-https", "--no-stream-dedup", "--no-example"])
    |> refute_creates("lib/test_web/octa_star_demo_controller.ex")
  end

  @tag :skip
  test "adds dispatch route to router" do
    phoenix_test_project()
    |> Igniter.compose_task("octa_star.install", ["--no-https", "--no-stream-dedup"])
    |> assert_has_patch("lib/test_web/router.ex", """
    + |      post "/ds/:module/:event", OctaStar.Phoenix.Dispatch, []
    """)
  end

  @tag :skip
  test "configures HTTPS when enabled" do
    phoenix_test_project()
    |> Igniter.compose_task("octa_star.install", ["--no-stream-dedup"])
    |> assert_has_patch("config/dev.exs", """
    + |      https:
    """)
  end

  @tag :skip
  test "skips HTTPS when --no-https" do
    igniter =
      phoenix_test_project()
      |> Igniter.compose_task("octa_star.install", ["--no-https", "--no-stream-dedup"])

    assert_unchanged(igniter, "config/dev.exs")
  end

  defp phoenix_test_project do
    test_project(
      files: %{
        "lib/test_web.ex" => """
        defmodule TestWeb do
          def static_paths, do: ~w(assets fonts images)

          def router do
            quote do
              use Phoenix.Router
              import Plug.Conn
              import Phoenix.Controller
              import Phoenix.LiveView.Router
            end
          end

          def controller do
            quote do
              use Phoenix.Controller, formats: [:html, :json]
              use Phoenix.Component
              import Plug.Conn
            end
          end

          def live_view do
            quote do
              use Phoenix.LiveView
            end
          end

          def live_component do
            quote do
              use Phoenix.LiveComponent
            end
          end

          def html do
            quote do
              use Phoenix.Component
              import Phoenix.HTML
            end
          end

          defmacro __using__(which) when is_atom(which) do
            apply(__MODULE__, which, [])
          end
        end
        """,
        "lib/test_web/router.ex" => """
        defmodule TestWeb.Router do
          use TestWeb, :router

          pipeline :browser do
            plug :accepts, ["html"]
            plug :fetch_session
            plug :fetch_live_flash
            plug :put_root_layout, html: {TestWeb.Layouts, :root}
            plug :protect_from_forgery
            plug :put_secure_browser_headers
          end

          scope "/", TestWeb do
            pipe_through :browser
            get "/", PageController, :home
          end
        end
        """,
        "lib/test_web/endpoint.ex" => """
        defmodule TestWeb.Endpoint do
          use Phoenix.Endpoint, otp_app: :test

          socket "/live", Phoenix.LiveView.Socket
          plug TestWeb.Router
        end
        """,
        "config/dev.exs" => """
        import Config

        config :test, TestWeb.Endpoint,
          http: [ip: {127, 0, 0, 1}],
          check_origin: false,
          code_reloader: true,
          debug_errors: true,
          secret_key_base: "test_secret_key_base_32_characters_long"
        """,
        "lib/test/application.ex" => """
        defmodule Test.Application do
          use Application

          def start(_type, _args) do
            children = [
              TestWeb.Endpoint,
              {Phoenix.PubSub, name: Test.PubSub}
            ]

            opts = [strategy: :one_for_one, name: Test.Supervisor]
            Supervisor.start_link(children, opts)
          end
        end
        """
      }
    )
  end
end
