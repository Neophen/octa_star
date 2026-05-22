defmodule Mix.Tasks.StarView.Server do
  @shortdoc "Starts Phoenix and opens the configured StarView dev URL"

  @moduledoc """
  Starts `mix phx.server` with browser opening enabled.

  `mix star_view.server` is equivalent to:

      mix phx.server --open

  The StarView installer configures the URL as `https://<otp_app>.test:4001`
  in `config/dev.exs`.

  ## Options

    * `--no-open` - start the Phoenix server without opening the browser.

  Other arguments are forwarded to `mix phx.server`.
  """

  use Mix.Task

  @impl Mix.Task
  def run(argv) do
    argv
    |> phx_server_args()
    |> run_phx_server()
  end

  @doc false
  def phx_server_args(argv) do
    {no_open?, argv} = Enum.split_with(argv, &(&1 == "--no-open"))

    cond do
      no_open? != [] ->
        argv

      "--open" in argv ->
        argv

      true ->
        ["--open" | argv]
    end
  end

  defp run_phx_server(argv) do
    if Mix.Task.get("phx.server") do
      Mix.Task.run("phx.server", argv)
    else
      Mix.raise("The task `star_view.server` requires Phoenix and the `phx.server` mix task.")
    end
  end
end
