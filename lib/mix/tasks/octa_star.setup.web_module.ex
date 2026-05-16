defmodule Mix.Tasks.OctaStar.Setup.WebModule.Docs do
  @moduledoc false

  def short_doc(), do: "Patches the Phoenix web module with OctaStar controller support"
  def example(), do: "mix octa_star.setup.web_module"
  def long_doc(), do: "#{short_doc()}"
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.OctaStar.Setup.WebModule do
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
          case Igniter.Code.Common.move_to(zipper, fn z ->
                 Igniter.Code.Function.function_call?(z, :use, 2) and
                   Igniter.Code.Function.argument_equals?(z, 0, OctaStar) and
                   Igniter.Code.Function.argument_equals?(z, 1, :controller)
               end) do
            {:ok, _} ->
              {:ok, zipper}

            _ ->
              case patch_controller_block(zipper) do
                {:ok, new_zipper} ->
                  {:ok, new_zipper}

                :error ->
                  {:warning,
                   "Could not automatically patch #{inspect(web_module)}. Add `use OctaStar, :controller` to your controller definition manually."}
              end
          end
        end)

      Igniter.add_notice(
        result,
        "Patched #{inspect(web_module)} with `use OctaStar, :controller`."
      )
    rescue
      _ ->
        Igniter.add_warning(igniter, "Could not find web module #{inspect(web_module)} to patch.")
    end

    defp patch_controller_block(zipper) do
      case Igniter.Code.Function.move_to_def(zipper, :controller, 0) do
        {:ok, quote_zipper} ->
          case Igniter.Code.Common.move_to_do_block(quote_zipper) do
            {:ok, body_zipper} ->
              case Igniter.Code.Common.move_to(body_zipper, fn z ->
                     Igniter.Code.Function.function_call?(z, :use, 2) and
                       (Igniter.Code.Function.argument_equals?(z, 0, Phoenix.Controller) or
                          Igniter.Code.Function.argument_equals?(z, 0, Phoenix.Component))
                   end) do
                {:ok, target_zipper} ->
                  new_zipper =
                    Igniter.Code.Common.add_code(target_zipper, "use OctaStar, :controller",
                      placement: :after
                    )

                  {:ok, new_zipper}

                _ ->
                  new_zipper =
                    Igniter.Code.Common.add_code(body_zipper, "use OctaStar, :controller",
                      placement: :after
                    )

                  {:ok, new_zipper}
              end

            _ ->
              :error
          end

        _ ->
          :error
      end
    end
  end
else
  defmodule Mix.Tasks.OctaStar.Setup.WebModule do
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
