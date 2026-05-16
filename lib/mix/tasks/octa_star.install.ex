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

    # Try both naming conventions: AppWeb (Phoenix default) and App.Web (Igniter default)
    {phoenix?, web_module, endpoint_module, igniter} =
      detect_phoenix_modules(igniter, app_name)

    igniter
    |> maybe_add_stream_registry(stream_dedup?)
    |> maybe_setup_https(https?, app_name, endpoint_module, phoenix?)
    |> maybe_patch_web_module(phoenix?, web_module)
    |> maybe_generate_example(example?, web_module, phoenix?)
    |> maybe_patch_router(example?, web_module, phoenix?)
    |> maybe_print_post_install(phoenix?)
  end

  defp detect_phoenix_modules(igniter, app_name) do
    app_atom = if is_atom(app_name), do: app_name, else: String.to_atom(app_name)
    app_str = Atom.to_string(app_atom) |> Macro.camelize()

    # Try Phoenix convention first (AppWeb)
    web_phoenix = Module.concat([app_str <> "Web"])
    endpoint_phoenix = Module.concat([app_str <> "Web.Endpoint"])

    # Check if the endpoint file exists on disk
    cwd = File.cwd!()
    endpoint_file = Path.expand("lib/#{Macro.underscore(app_str)}_web/endpoint.ex")
    file_exists = File.exists?(endpoint_file)

    # Debug output
    IO.puts("[OctaStar] CWD: #{cwd}")
    IO.puts("[OctaStar] App: #{app_str}, Endpoint file: #{endpoint_file}, Exists: #{file_exists}")

    if file_exists do
      {true, web_phoenix, endpoint_phoenix, igniter}
    else
      # Try Igniter convention (App.Web)
      web_igniter = Igniter.Project.Module.module_name(igniter, "Web")
      endpoint_igniter = Igniter.Project.Module.module_name(igniter, "Web.Endpoint")

      case Igniter.Project.Module.module_exists(igniter, endpoint_igniter) do
        {true, igniter} -> {true, web_igniter, endpoint_igniter, igniter}
        {false, igniter} -> {false, web_phoenix, endpoint_phoenix, igniter}
      end
    end
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
      ~s"""
      [
        port: 4001,
        cipher_suite: :strong,
        keyfile: "priv/cert/selfsigned_key.pem",
        certfile: "priv/cert/selfsigned.pem"
      ]
      """,
      type: :literal
    )
    |> Igniter.add_notice("""
    HTTPS configured for dev on port 4001.

    Run: mix phx.gen.cert
    Then: mix phx.server
    """)
  end

  defp maybe_patch_web_module(igniter, false, _web_module), do: igniter

  defp maybe_patch_web_module(igniter, true, web_module) do
    case Igniter.Project.Module.find_module(igniter, web_module) do
      {:ok, source, _zipper} ->
        # Check if use OctaStar, :controller is already present
        if String.contains?(source, "use OctaStar, :controller") or
             String.contains?(source, "use OctaStar, :controller") do
          igniter
        else
          # Use Sourceror to patch the controller block
          patched =
            source
            |> Sourceror.parse_string!()
            |> Sourceror.Zipper.zip()
            |> insert_octa_star_controller()
            |> Sourceror.Zipper.root()
            |> Macro.to_string()
            |> Sourceror.to_string()

          if patched != source do
            {_path, igniter} = Igniter.Project.Module.find_module!(igniter, web_module)

            Igniter.add_notice(igniter, """
            Patched #{inspect(web_module)} with `use OctaStar, :controller`.

            If the patch didn't apply correctly, add it manually:

                def controller do
                  quote do
                    use Phoenix.Controller, formats: [:html, :json]
                    use OctaStar, :controller
                    ...
                  end
                end
            """)
          else
            Igniter.add_notice(igniter, """
            Could not automatically patch #{inspect(web_module)}.

            Please add `use OctaStar, :controller` to your controller definition:

                def controller do
                  quote do
                    use Phoenix.Controller, formats: [:html, :json]
                    use OctaStar, :controller
                    ...
                  end
                end
            """)
          end
        end

      _ ->
        Igniter.add_warning(igniter, "Could not find web module #{inspect(web_module)} to patch.")
    end
  end

  defp insert_octa_star_controller(zipper) do
    # Find the controller def and insert use OctaStar after Phoenix.Controller or Phoenix.Component
    zipper
    |> Sourceror.Zipper.down()
    |> find_and_insert()
  end

  defp find_and_insert(nil), do: nil

  defp find_and_insert(zipper) do
    case Sourceror.Zipper.node(zipper) do
      {:def, _, [{:controller, _, _}, [do: {:quote, _, quote_body}]]} ->
        # Found the controller def with quote block
        insert_into_quote(zipper, quote_body)

      {:def, _, [{:controller, _, _}, _]} ->
        # Descend into the controller def
        case Sourceror.Zipper.down(zipper) do
          nil -> Sourceror.Zipper.right(zipper) |> find_and_insert()
          down -> find_and_insert(down)
        end

      {:quote, _, quote_body} ->
        insert_into_quote(zipper, quote_body)

      _ ->
        # Continue searching
        case Sourceror.Zipper.right(zipper) do
          nil -> Sourceror.Zipper.next(zipper) |> find_and_insert()
          right -> find_and_insert(right)
        end
    end
  end

  defp insert_into_quote(zipper, quote_body) do
    # Find the position after use Phoenix.Controller or use Phoenix.Component
    new_body = insert_after_phoenix_use(quote_body)

    if new_body != quote_body do
      # Replace the quote body
      new_node =
        case Sourceror.Zipper.node(zipper) do
          {:def, _, [{:controller, _, _}, [do: {:quote, _, _}]]} ->
            {:def, [], [{:controller, [], []}, [do: {:quote, [], new_body}]]}

          {:quote, _, _} ->
            {:quote, [], new_body}

          _ ->
            Sourceror.Zipper.node(zipper)
        end

      Sourceror.Zipper.replace(zipper, new_node)
    else
      zipper
    end
  end

  defp insert_after_phoenix_use(body) do
    insert_octa_star = {:use, [], [{:__aliases__, [], [:OctaStar]}, :controller]}

    case body do
      [do: block] ->
        new_block = insert_after_phoenix_use_block(block)
        if new_block != block, do: [do: new_block], else: body

      block when is_list(block) ->
        insert_after_phoenix_use_block(block)

      _ ->
        body
    end
  end

  defp insert_after_phoenix_use_block(block) when is_list(block) do
    insert_octa_star = {:use, [], [{:__aliases__, [], [:OctaStar]}, :controller]}

    block
    |> Enum.reduce({[], false}, fn node, {acc, inserted?} ->
      new_acc = acc ++ [node]

      if inserted? do
        {new_acc, true}
      else
        case node do
          {:use, _, [{:__aliases__, _, [:Phoenix, :Controller]}, _]} ->
            {new_acc ++ [insert_octa_star], true}

          {:use, _, [{:__aliases__, _, [:Phoenix, :Component]}, _]} ->
            {new_acc ++ [insert_octa_star], true}

          {:import, _, [{:__aliases__, _, [:Plug, :Conn]}]} ->
            {new_acc ++ [insert_octa_star], true}

          _ ->
            {new_acc, false}
        end
      end
    end)
    |> case do
      {result, true} -> result
      {result, false} -> result ++ [insert_octa_star]
    end
  end

  defp insert_after_phoenix_use_block(block), do: block

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
  end

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

  defp maybe_patch_router(igniter, _example?, _web_module, false), do: igniter

  defp maybe_patch_router(igniter, example?, web_module, true) do
    {igniter, router} =
      Igniter.Libs.Phoenix.select_router(
        igniter,
        "Which Phoenix router should OctaStar add routes to?"
      )

    if router do
      do_patch_router(igniter, example?, web_module, router)
    else
      Igniter.add_warning(igniter, "No Phoenix router found. Skipping route setup.")
    end
  end

  defp do_patch_router(igniter, example?, web_module, router) do
    {_, source, _zipper} = Igniter.Project.Module.find_module!(igniter, router)

    # Check if the Datastar dispatch route is already present
    already_has_ds_route? =
      String.contains?(source, "post") and
        String.contains?(source, "/ds/:module/:event")

    if already_has_ds_route? do
      # Route exists, but we may still need to add the demo route
      if example? do
        controller = Module.concat([web_module, OctaStarDemoController])

        # Check if demo route already exists
        already_has_demo? =
          String.contains?(source, "/octa-star-demo")

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
