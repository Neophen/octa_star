defmodule Mix.Tasks.OctaStar.Setup.DemoController.Docs do
  @moduledoc false

  def short_doc, do: "Generates an example OctaStar demo controller with Datastar"
  def example, do: "mix octa_star.setup.demo_controller"
  def long_doc, do: "#{short_doc()}"
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.OctaStar.Setup.DemoController do
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
        schema: [router: :string],
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

      igniter
      |> maybe_generate_example(web_module, phoenix?)
      |> maybe_patch_router(web_module, phoenix?)
    end

    defp maybe_generate_example(igniter, web_module, false) do
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
    end

    defp maybe_generate_example(igniter, web_module, true) do
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

    defp maybe_patch_router(igniter, _web_module, false), do: igniter

    defp maybe_patch_router(igniter, web_module, true) do
      {igniter, router} =
        Igniter.Libs.Phoenix.select_router(
          igniter,
          "Which Phoenix router should OctaStar add routes to?"
        )

      if router do
        do_patch_router(igniter, web_module, router)
      else
        Igniter.add_warning(igniter, "No Phoenix router found. Skipping route setup.")
      end
    end

    defp do_patch_router(igniter, web_module, router) do
      {_, source, _zipper} = Igniter.Project.Module.find_module!(igniter, router)
      source_str = Rewrite.Source.get(source, :content)

      already_has_ds_route? = String.contains?(source_str, ~s("/ds/:module/:event"))

      if already_has_ds_route? do
        controller = Module.concat([web_module, OctaStarDemoController])
        already_has_demo? = String.contains?(source_str, "/octa-star-demo")

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
        controller = Module.concat([web_module, OctaStarDemoController])

        route_contents = """
        get "/octa-star-demo", #{inspect(controller)}, :show
        post "/ds/:module/:event", OctaStar.Phoenix.Dispatch, []
        """

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
  end
else
  defmodule Mix.Tasks.OctaStar.Setup.DemoController do
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
