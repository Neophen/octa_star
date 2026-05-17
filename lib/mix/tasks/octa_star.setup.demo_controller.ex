defmodule Mix.Tasks.OctaStar.Setup.SearchController.Docs do
  @moduledoc false

  def short_doc(), do: "Generates an example OctaStar demo controller with Datastar"
  def example(), do: "mix octa_star.setup.search_controller"
  def long_doc(), do: "#{short_doc()}"
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.OctaStar.Setup.SearchController do
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
      controller = Module.concat([web_module, ActiveSearchController])

      Igniter.Project.Module.create_module(
        igniter,
        controller,
        ~s'''
        defmodule #{inspect(controller)} do
          @moduledoc """
          Example Phoenix controller demonstrating OctaStar with Datastar.

          Features:
            - Active search with debounced input
            - Element patching
          """

          use #{inspect(web_module)}, :controller

          @items [
            "Elixir",
            "Phoenix",
            "LiveView",
            "Datastar",
            "SSE",
            "Plug",
            "Ecto",
            "Ash",
            "HEEx",
            "Tailwind"
          ]

          @impl StarView
          def show(conn, _params) do
            conn
            |> signal(:query, "")
            |> assign(:results, @items)
          end

          @impl StarView
          def html(assigns) do
            ~H"""
            <div class="max-w-xl mx-auto p-6" data-signals={init_signals(@conn)}>
              <h1 class="text-2xl font-bold mb-4">Active Search</h1>

              <div class="mb-4 flex gap-2">
                <input
                  type="text"
                  class="input grow"
                  placeholder="Search frameworks..."
                  data-on:input__debounce.200ms={post("search")}
                  data-bind="query"
                />
                <button
                  class="btn"
                  data-on:click={post("reset")}
                >
                  Reset
                </button>
              </div>

              <.item_list results={@results} />
              <.no_results results={@results} query={@query} />
              <.explanation />
            </div>
            """
          end

          attr :results, :list, default: []
          attr :query, :string, default: nil

          def no_results(assigns) do
            ~H"""
            <div
              id="results"
              class="space-y-2 data-visible:block hidden"
              data-visible={@results == []  && @query != ""}
            >
              <p class="text-gray-500">No results found for "{@query}"</p>
            </div>
            """
          end

          attr :results, :list, default: []

          def item_list(assigns) do
            ~H"""
            <ul id="item-list" class="grid gap-2 data-hidden:hidden peer" data-hidden={@results == []}>
              <.item :for={item <- @results} item={item} />
            </ul>
            """
          end

          attr :item, :string, required: true

          def item(assigns) do
            ~H"""
            <li class="border p-4" data-show={show_by_query(@item)}>
              {@item}
            </li>
            """
          end

          def explanation(assigns) do
            ~H"""
            <div class="mt-6 p-4 bg-gray-50 rounded text-sm text-gray-700 space-y-2">
              <h2 class="font-semibold text-base">How This Works</h2>

              <p>
                This example actively searches a list of frameworks as the user types.
                The input field uses Datastar's <code class="bg-gray-200 px-1 rounded">data-on:input__debounce.200ms</code> modifier
                to issue a <code class="bg-gray-200 px-1 rounded">POST /search</code> request only after the user stops typing for 200ms,
                preventing excessive server calls on every keystroke.
              </p>

              <p>
                The <code class="bg-gray-200 px-1 rounded">data-bind="query"</code> attribute binds the input's value to the
                <code class="bg-gray-200 px-1 rounded">$query</code> signal. The <code class="bg-gray-200 px-1 rounded">data-signals={init_signals(@conn)}</code>
                on the container ensures the <code class="bg-gray-200 px-1 rounded">query</code> signal is initialized on the client
                if it doesn't already exist, allowing the binding to work without an explicit signal declaration.
              </p>

              <p>
                The server filters the items and uses <code class="bg-gray-200 px-1 rounded">patch_element/2</code> to surgically update
                only the <code class="bg-gray-200 px-1 rounded">#item-list</code> and <code class="bg-gray-200 px-1 rounded">#results</code>
                elements via SSE, rather than re-rendering the entire page. This is more efficient than full HTML replacement.
              </p>

              <p>
                Each list item uses <code class="bg-gray-200 px-1 rounded">data-show</code> with a JavaScript expression that checks
                if the item starts with the current query. This provides instant client-side filtering for items already in the DOM,
                while the server-side search handles the full dataset.
              </p>

              <p>
                The "No results" message uses <code class="bg-gray-200 px-1 rounded">data-visible</code> to toggle visibility based on
                whether the results are empty and a query exists. The <code class="bg-gray-200 px-1 rounded">data-visible:block</code>
                modifier specifies that <code class="bg-gray-200 px-1 rounded">display: block</code> should be applied when visible,
                overriding the default <code class="bg-gray-200 px-1 rounded">hidden</code> class.
              </p>
            </div>
            """
          end

          @impl StarView
          def handle_event(conn, "search", signals) do
            query = signals |> Map.get("query", "") |> String.downcase()

            results =
              if query == "" do
                # Up to you to decide if the query is empty should we reset the initial results
                @items
              else
                Enum.filter(@items, &String.contains?(&1 |> String.downcase(), query))
              end

            conn
            # We want the query to be updated but do not overwrite the signal input value
            # You could also use `|> assign(:query, query)` which allow the patch_element
            # to be updated with the query value
            |> signal(:query, Map.get(signals, "query", ""), only_if_missing: true)
            |> assign(:results, results)
            |> patch_element(&no_results/1)
            |> patch_element(&item_list/1)
          end

          @impl StarView
          def handle_event(conn, "reset", _signals) do
            conn
            |> signal(:query, "")
            |> assign(:results, @items)
            |> patch_element(&no_results/1)
            |> patch_element(&item_list/1)
          end

          defp show_by_query(item) do
            "'#\{item}'.toLowerCase().startsWith($query.toLocaleLowerCase())"
          end
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
        controller = Module.concat([web_module, ActiveSearchController])
        already_has_demo? = String.contains?(source_str, "/search")

        if already_has_demo? do
          igniter
        else
          Igniter.Libs.Phoenix.append_to_scope(
            igniter,
            "/",
            "get \"/search\", #{inspect(controller)}, :show\n",
            with_pipelines: [:browser],
            arg2: web_module,
            router: router
          )
        end
      else
        controller = Module.concat([web_module, ActiveSearchController])

        route_contents = """
        get "/search", #{inspect(controller)}, :show
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
  defmodule Mix.Tasks.OctaStar.Setup.SearchController do
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
