defmodule Mix.Tasks.StarView.Setup.Datastar.Docs do
  @moduledoc false

  def short_doc(), do: "Configures StarView dev URL and HTTPS"
  def example(), do: "mix star_view.setup.datastar"
  def long_doc(), do: "#{short_doc()}"
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.StarView.Setup.Datastar do
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
        schema: [https: :boolean],
        defaults: [https: true],
        aliases: [],
        required: []
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      https? = Keyword.get(igniter.args.options, :https, true)
      app_name = Igniter.Project.Application.app_name(igniter)
      web_module = Igniter.Libs.Phoenix.web_module(igniter)
      endpoint_module = Module.concat(web_module, Endpoint)

      {phoenix?, igniter} = Igniter.Project.Module.module_exists(igniter, endpoint_module)

      igniter
      |> maybe_setup_https(https?, app_name, endpoint_module, phoenix?)
    end

    defp maybe_setup_https(igniter, false, _, _, _), do: igniter
    defp maybe_setup_https(igniter, _https?, _app_name, _endpoint, false), do: igniter

    defp maybe_setup_https(igniter, true, app_name, endpoint_module, true) do
      host = "#{app_name}.test"
      url = "https://#{host}"

      Igniter.Project.Config.configure(
        igniter,
        "dev.exs",
        app_name,
        [endpoint_module, :url],
        {:code,
         Sourceror.parse_string!("""
         [
           scheme: "https",
           host: "#{host}",
           port: 443
         ]
         """)}
      )
      |> Igniter.Project.Config.configure(
        "dev.exs",
        app_name,
        [endpoint_module, :https],
        {:code,
         Sourceror.parse_string!("""
         [
           port: 4001,
           cipher_suite: :strong,
           keyfile: "priv/cert/selfsigned_key.pem",
           certfile: "priv/cert/selfsigned.pem"
         ]
         """)}
      )
      |> Igniter.Project.Config.configure(
        "dev.exs",
        app_name,
        [:star_view, :dev_url],
        url
      )
      |> Igniter.add_notice("""
      StarView dev URL configured: #{url}

      HTTPS configured for dev on port 4001.

      Run: mix phx.gen.cert
      Then: mix star_view.dev
      """)
    end
  end
else
  defmodule Mix.Tasks.StarView.Setup.Datastar do
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
