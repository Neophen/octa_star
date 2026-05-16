defmodule Mix.Tasks.OctaStar.Install.Docs do
  @moduledoc false

  @spec short_doc() :: String.t()
  def short_doc do
    "Installs OctaStar into your project"
  end

  @spec example() :: String.t()
  def example do
    "mix igniter.install octa_star"
  end

  @spec long_doc() :: String.t()
  def long_doc do
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
          "octa_star.setup.demo_controller"
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

      app_name = Igniter.Project.Application.app_name(igniter)
      web_module = Igniter.Libs.Phoenix.web_module(igniter)
      endpoint_module = Module.concat(web_module, Endpoint)

      {igniter, router} =
        Igniter.Libs.Phoenix.select_router(igniter, "Which Phoenix router should OctaStar add routes to?")

      phoenix? = router != nil

      igniter
      |> maybe_add_stream_registry(stream_dedup?)
      |> maybe_setup_https(https?, app_name, endpoint_module, phoenix?)
      |> maybe_patch_web_module(phoenix?, web_module)
      |> maybe_generate_example(example?, web_module, phoenix?)
      |> maybe_patch_router(example?, web_module, phoenix?, router)
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
      |> Igniter.add_notice("""
      HTTPS configured for dev on port 4001.

      Run: mix phx.gen.cert
      Then: mix phx.server
      """)
    end

    defp maybe_patch_web_module(igniter, false, _web_module), do: igniter

    defp maybe_patch_web_module(igniter, true, web_module) do
      try do
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
                  {:ok, new_zipper} -> {:ok, new_zipper}
                  :error -> {:warning, "Could not automatically patch #{inspect(web_module)}. Add `use OctaStar, :controller` to your controller definition manually."}
                end
            end
          end)

        Igniter.add_notice(result, "Patched #{inspect(web_module)} with `use OctaStar, :controller`.")
      rescue
        _ ->
          Igniter.add_warning(igniter, "Could not find web module #{inspect(web_module)} to patch.")
      end
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
                    Igniter.Code.Common.add_code(target_zipper, "use OctaStar, :controller", placement: :after)

                  {:ok, new_zipper}

                _ ->
                  new_zipper =
                    Igniter.Code.Common.add_code(body_zipper, "use OctaStar, :controller", placement: :after)

                  {:ok, new_zipper}
              end

            _ ->
              :error
          end

        _ ->
          :error
      end
    end

    defp maybe_generate_example(igniter, false, _web_module, _phoenix?), do: igniter
    defp maybe_generate_example(igniter, true, _web_module, false), do: igniter

    defp maybe_generate_example(igniter, true, web_module, true) do
      controller = Module.concat([web_module, OctaStarDemoController])

      Igniter.Project.Module.create_module(
        igniter,
        controller,
        ~s'''
        @moduledoc """
        Example Phoenix controller demonstrating OctaStar with Datastar.

        Features:
          - Active search with debounced input
          - Signal-driven UI updates
          - Element patching
        """

        use #{inspect(web_module)}, :controller

        @items [
          "Elixir", "Phoenix", "LiveView", "Datastar", "SSE",
          "Plug", "Ecto", "Ash", "HEEx", "Tailwind"
        ]

        @impl StarView
        def show(conn, _params) do
          conn
          |> signal(:query, "")
          |> signal(:results, [])
          |> signal(:tabId, generate_tab_id())
        end

        @impl StarView
        def html(assigns) do
          ~H"""
          <div class="max-w-xl mx-auto p-6" data-signals={init_signals(@conn)}>
            <h1 class="text-2xl font-bold mb-4">Active Search Demo</h1>

            <div class="mb-4">
              <input
                type="text"
                class="w-full px-3 py-2 border rounded-lg"
                placeholder="Search frameworks..."
                value={@query}
                data-on:input={post("search", debounce: 200)}
                data-bind:value="$query"
              />
            </div>

            <div id="results" class="space-y-2">
              <%= if @results == [] and @query != "" do %>
                <p class="text-gray-500">No results found for "<%= @query %>"</p>
              <%= else %>
                <%= for item <- @results do %>
                  <div class="p-3 bg-gray-50 rounded border">
                    <%= item %>
                  </div>
                <% end %>
              <% end %>
            </div>

            <div class="mt-4 flex gap-2">
              <button
                class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
                data-on:click={post("reset")}
              >
                Reset
              </button>
              <button
                class="px-4 py-2 bg-green-500 text-white rounded hover:bg-green-600"
                data-on:click={post("load_all")}
              >
                Load All
              </button>
            </div>
          </div>
          """
        end

        @impl StarView
        def handle_event(conn, "search", signals) do
          query = Map.get(signals, "query", "") |> String.downcase()

          results =
            if query == "" do
              []
            else
              Enum.filter(@items, &String.contains?(&1 |> String.downcase(), query))
            end

          conn
          |> signal(:query, Map.get(signals, "query", ""))
          |> signal(:results, results)
        end

        @impl StarView
        def handle_event(conn, "reset", _signals) do
          conn
          |> signal(:query, "")
          |> signal(:results, [])
        end

        @impl StarView
        def handle_event(conn, "load_all", _signals) do
          conn
          |> signal(:query, "")
          |> signal(:results, @items)
        end

        defp generate_tab_id do
          16
          |> :crypto.strong_rand_bytes()
          |> Base.encode16(case: :lower)
        end
        '''
      )
    end

    defp maybe_patch_router(igniter, _example?, _web_module, false, _router), do: igniter

    defp maybe_patch_router(igniter, example?, web_module, true, router) do
      if router do
        do_patch_router(igniter, example?, web_module, router)
      else
        Igniter.add_warning(igniter, "No Phoenix router found. Skipping route setup.")
      end
    end

    defp do_patch_router(igniter, example?, web_module, router) do
      {_, source, _zipper} = Igniter.Project.Module.find_module!(igniter, router)

      source_str = Rewrite.Source.get(source, :content)

      already_has_ds_route? =
        String.contains?(source_str, ~s("/ds/:module/:event"))

      if already_has_ds_route? do
        if example? do
          controller = Module.concat([web_module, OctaStarDemoController])

          already_has_demo? =
            String.contains?(source_str, "/octa-star-demo")

          if already_has_demo? do
            igniter
          else
            Igniter.Libs.Phoenix.append_to_scope(
              igniter,
              "/",
              "get \"/octa-star-demo\", #{inspect(controller)}, :show\n",
              with_pipelines: [:browser],
              arg2: web_module,
              router: router
            )
          end
        else
          igniter
        end
      else
        route_contents =
          if example? do
            controller = Module.concat([web_module, OctaStarDemoController])

            """
            get "/octa-star-demo", #{inspect(controller)}, :show
            post "/ds/:module/:event", OctaStar.Phoenix.Dispatch, []
            """
          else
            """
            post "/ds/:module/:event", OctaStar.Phoenix.Dispatch, []
            """
          end

        Igniter.Libs.Phoenix.append_to_scope(
          igniter,
          "/",
          route_contents,
          with_pipelines: [:browser],
          arg2: web_module,
          router: router
        )
      end
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
