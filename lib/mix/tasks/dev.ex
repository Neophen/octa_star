defmodule Mix.Tasks.Dev do
  @shortdoc "Starts StarView development server"

  @moduledoc """
  Delegates to `mix star_view.server`.
  """

  use Mix.Task

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("star_view.server", argv)
  end
end
