defmodule Mix.Tasks.StarView.Setup.WebModule.Docs do
  @moduledoc false

  def short_doc(), do: "Adds a StarView section to the Phoenix web module"
  def example(), do: "mix star_view.setup.web_module"
  def long_doc(), do: "#{short_doc()}"
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.StarView.Setup.WebModule do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"
    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :star_view,
        adds_deps: [],
        installs: [],
        example: __MODULE__.Docs.example(),
        only: nil,
        positional: [],
        composes: [],
        schema: [],
        defaults: [],
        aliases: [],
        required: []
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      web_module = Igniter.Libs.Phoenix.web_module(igniter)
      endpoint_module = Module.concat(web_module, Endpoint)

      {phoenix?, igniter} = Igniter.Project.Module.module_exists(igniter, endpoint_module)

      if phoenix? do
        patch_web_module(igniter, web_module)
      else
        Igniter.add_warning(igniter, "No Phoenix endpoint found. Skipping web module patch.")
      end
    end

    defp patch_web_module(igniter, web_module) do
      result =
        Igniter.Project.Module.find_and_update_module!(igniter, web_module, fn zipper ->
          case Igniter.Code.Function.move_to_def(zipper, :star_view, 0) do
            {:ok, _zipper} ->
              {:ok, zipper}

            _ ->
              {:ok, add_star_view_section(zipper, web_module)}
          end
        end)

      Igniter.add_notice(
        result,
        "Patched #{inspect(web_module)} with a `star_view` section."
      )
    rescue
      _ ->
        Igniter.add_warning(igniter, "Could not find web module #{inspect(web_module)} to patch.")
    end

    defp add_star_view_section(zipper, web_module) do
      case Igniter.Code.Function.move_to_def(zipper, :controller, 0) do
        {:ok, controller_zipper} ->
          Igniter.Code.Common.add_code(
            controller_zipper,
            star_view_section(web_module),
            placement: :after
          )

        :error ->
          Igniter.Code.Common.add_code(zipper, star_view_section(web_module), placement: :after)
      end
    end

    defp star_view_section(web_module) do
      gettext_backend = Module.concat(web_module, Gettext)

      """
      def star_view do
        quote do
          use Phoenix.Controller, formats: [:html, :json]
          use StarView
          use Phoenix.Component

          use Gettext, backend: #{inspect(gettext_backend)}

          import Phoenix.Component, except: [assign: 3]
          import Plug.Conn

          unquote(verified_routes())
        end
      end
      """
    end
  end
else
  defmodule Mix.Tasks.StarView.Setup.WebModule do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"
    @moduledoc __MODULE__.Docs.long_doc()
    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("Requires igniter.")
      exit({:shutdown, 1})
    end
  end
end
