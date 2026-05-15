defmodule Mix.Tasks.OctaStar.Install do
  @shortdoc "Installs OctaStar into your project"

  @moduledoc """
  Installs OctaStar and optionally sets up recommended configurations.

  ## Options

    * `--no-stream-dedup` — Skip adding `OctaStar.Utility.StreamRegistry` to your supervision tree.
    * `--no-https` — Skip HTTPS dev configuration (Phoenix only).
    * `--no-example` — Skip generating the sample controller/handler.

  ## Examples

      mix igniter.install octa_star
      mix igniter.install octa_star --no-stream-dedup
      mix igniter.install octa_star --no-https --no-example
  """

  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :octa_star,
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
      example: "mix igniter.install octa_star"
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

    app_name = Igniter.Project.Application.app_name(igniter)
    web_module = Igniter.Project.Module.module_name(igniter, "Web")
    endpoint_module = Igniter.Project.Module.module_name(igniter, "Web.Endpoint")

    {phoenix?, igniter} = Igniter.Project.Module.module_exists(igniter, endpoint_module)

    igniter
    |> maybe_add_stream_registry(stream_dedup?)
    |> maybe_setup_https(https?, app_name, endpoint_module, phoenix?)
    |> maybe_generate_example(example?, web_module, phoenix?)
    |> maybe_print_post_install(phoenix?)
  end

  defp maybe_add_stream_registry(igniter, false), do: igniter

  defp maybe_add_stream_registry(igniter, true) do
    Igniter.Project.Application.add_new_child(
      igniter,
      OctaStar.Utility.StreamRegistry,
      after: [Phoenix.PubSub]
    )
  end

  defp maybe_setup_https(igniter, false, _, _, _), do: igniter
  defp maybe_setup_https(igniter, _https?, _app_name, _endpoint, false), do: igniter

  defp maybe_setup_https(igniter, true, app_name, endpoint_module, true) do
    Igniter.Project.Config.configure(
      igniter,
      "dev.exs",
      app_name,
      [endpoint_module, :https],
      [
        port: 4001,
        cipher_suite: :strong,
        keyfile: "priv/cert/selfsigned_key.pem",
        certfile: "priv/cert/selfsigned.pem"
      ]
    )
    |> Igniter.add_notice("""
    HTTPS has been configured for dev on port 4001.

    Run the following to generate self-signed certificates:

        mix phx.gen.cert

    Then start your app with:

        mix phx.server
    """)
  end

  defp maybe_generate_example(igniter, false, _web_module, _phoenix?), do: igniter

  defp maybe_generate_example(igniter, true, web_module, false) do
    module = Module.concat([web_module, OctaStarDemo])

    Igniter.Project.Module.create_module(
      igniter,
      module,
      """
      @moduledoc "Example Datastar handler using OctaStar with Plug."

      def handle_event(conn, "increment", signals) do
        count = Map.get(signals, "count", 0) + 1
        OctaStar.patch_signals(conn, %{count: count})
      end
      """
    )
    |> Igniter.add_notice("""
    Example Plug handler generated at #{Igniter.Project.Module.proper_location(igniter, module)}.

    Wire it into your router:

        post "/ds/octa-star-demo/:event", OctaStar.Plug.Dispatch,
          modules: [#{inspect(module)}]
    """)
  end

  defp maybe_generate_example(igniter, true, web_module, true) do
    controller = Module.concat([web_module, OctaStarDemoController])

    Igniter.Project.Module.create_module(
      igniter,
      controller,
      """
      @moduledoc "Example Phoenix controller demonstrating OctaStar with Datastar."

      use #{inspect(web_module)}, :controller

      @impl StarView
      def show(conn, _params) do
        conn
        |> signal(:count, 0)
        |> signal(:tabId, generate_tab_id())
      end

      @impl StarView
      def html(assigns) do
        ~H\"\"\"
        <div data-signals={init_signals(@conn)}>
          <button data-on:click={post("increment")}>+</button>
          <span data-text="$count">{@count}</span>
        </div>
        \"\"\"
      end

      @impl StarView
      def handle_event(conn, "increment", signals) do
        signal(conn, :count, Map.get(signals, "count", 0) + 1)
      end

      defp generate_tab_id do
        16
        |> :crypto.strong_rand_bytes()
        |> Base.encode16(case: :lower)
      end
      """
    )
    |> Igniter.add_notice("""
    Example Phoenix controller generated at #{Igniter.Project.Module.proper_location(igniter, controller)}.

    Add the following routes to your router:

        scope "/", #{inspect(web_module)} do
          pipe_through :browser

          get  "/octa-star-demo", #{inspect(controller)}, :show
          post "/ds/:module/:event", OctaStar.Phoenix.Dispatch, []
        end
    """)
  end

  defp maybe_print_post_install(igniter, true) do
    Igniter.add_notice(igniter, """
    OctaStar has been installed!

    Remember to add the `OctaStar` controller helper to your web module:

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
    OctaStar has been installed!

    Wire the dispatch plug into your router:

        post "/ds/:module/:event", OctaStar.Plug.Dispatch,
          modules: [MyApp.HandlerModule]
    """)
  end
end
