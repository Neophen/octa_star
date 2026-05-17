defmodule Mix.Tasks.OctaStar.Install.Docs do
  @moduledoc false

  @spec short_doc() :: String.t()
  def short_doc() do
    "Installs OctaStar into your project"
  end

  @spec example() :: String.t()
  def example() do
    "mix igniter.install octa_star"
  end

  @spec long_doc() :: String.t()
  def long_doc() do
    """
    #{short_doc()}

    Installs OctaStar and optionally sets up recommended configurations.

    ## Example

    ```sh
    #{example()}
    ```

    ## Options

    * `--no-stream-dedup` — Skip adding `OctaStar.Utility.StreamRegistry` to your supervision tree.
    * `--no-https` — Skip HTTPS dev configuration (Phoenix only).
    * `--no-example` — Skip generating the sample controller/handler.
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.OctaStar.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :octa_star,
        adds_deps: [],
        installs: [],
        example: __MODULE__.Docs.example(),
        only: nil,
        positional: [],
        composes: [
          "octa_star.setup.streaming",
          "octa_star.setup.datastar",
          "octa_star.setup.web_module",
          "octa_star.setup.search_controller"
        ],
        schema: [
          stream_dedup: :boolean,
          https: :boolean,
          example: :boolean
        ],
        defaults: [
          stream_dedup: true,
          https: true,
          example: true
        ],
        aliases: [],
        required: []
      }
    end

    @impl Igniter.Mix.Task
    def installer?(), do: true

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      options = igniter.args.options
      stream_dedup? = Keyword.get(options, :stream_dedup, true)
      https? = Keyword.get(options, :https, true)
      example? = Keyword.get(options, :example, true)

      {igniter, router} =
        Igniter.Libs.Phoenix.select_router(
          igniter,
          "Which Phoenix router should OctaStar add routes to?"
        )

      phoenix? = router != nil

      igniter
      |> maybe_compose_streaming(stream_dedup?)
      |> maybe_compose_datastar(https?)
      |> maybe_compose_web_module(phoenix?)
      |> maybe_compose_search_controller(example?)
      |> maybe_print_post_install(phoenix?)
    end

    defp maybe_compose_streaming(igniter, false), do: igniter

    defp maybe_compose_streaming(igniter, true) do
      Igniter.compose_task(igniter, "octa_star.setup.streaming")
    end

    defp maybe_compose_datastar(igniter, false), do: igniter

    defp maybe_compose_datastar(igniter, true) do
      Igniter.compose_task(igniter, "octa_star.setup.datastar")
    end

    defp maybe_compose_web_module(igniter, false), do: igniter

    defp maybe_compose_web_module(igniter, true) do
      Igniter.compose_task(igniter, "octa_star.setup.web_module")
    end

    defp maybe_compose_search_controller(igniter, false), do: igniter

    defp maybe_compose_search_controller(igniter, true) do
      Igniter.compose_task(igniter, "octa_star.setup.search_controller")
    end

    defp maybe_print_post_install(igniter, true) do
      Igniter.add_notice(igniter, """
      OctaStar installed!

      Routes have been added to your router automatically.

      Your web module has been patched with `use OctaStar, :controller`.
      If the patch failed, add it manually:

          def controller do
            quote do
              use Phoenix.Controller, formats: [:html]
              use OctaStar, :controller
            end
          end
      """)
    end

    defp maybe_print_post_install(igniter, false) do
      Igniter.add_notice(igniter, """
      OctaStar installed!

      Wire the dispatch plug into your router:

          post "/ds/:module/:event", OctaStar.Plug.Dispatch,
            modules: [MyApp.HandlerModule]
      """)
    end
  end
else
  defmodule Mix.Tasks.OctaStar.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'octa_star.install' requires igniter. Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter/readme.html#installation
      """)

      exit({:shutdown, 1})
    end
  end
end
