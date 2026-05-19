defmodule Mix.Tasks.StarView.Setup.Streaming.Docs do
  @moduledoc false

  def short_doc(), do: "Adds StarView stream registry to the supervision tree"
  def example(), do: "mix star_view.setup.streaming"
  def long_doc(), do: "#{short_doc()}"
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.StarView.Setup.Streaming do
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
      Igniter.Project.Application.add_new_child(
        igniter,
        StarView.StreamRegistry,
        after: [Phoenix.PubSub]
      )
    end
  end
else
  defmodule Mix.Tasks.StarView.Setup.Streaming do
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
