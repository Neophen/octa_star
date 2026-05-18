# LiveView vs OctaStar

This guide compares Phoenix LiveView and OctaStar side-by-side using the same
active search example. Both implementations feature debounced input, optimistic
client-side filtering, and minimal server round-trips.

## The Example

A search input that filters a list of framework names as the user types, with
instant client-side feedback and server-side filtering as the source of truth.

## Code Comparison

### OctaStar Controller

```elixir
defmodule AppWeb.SearchController do
  use AppWeb, :controller

  @items ["Elixir", "Phoenix", "LiveView", "Datastar", "SSE", "Plug", "Ecto", "Ash", "HEEx", "Tailwind"]

  @impl StarView
  def mount(conn, _params) do
    conn
    |> signal(:query, "")
    |> signal(:results, @items)
  end

  @impl StarView
  def render(assigns) do
    ~H\"""
    <div class="max-w-xl mx-auto p-6" data-signals={init_signals(@conn)}>
      <h1 class="text-2xl font-bold mb-4">Active Search</h1>
      <.search_form />
      <.item_list results={@results} />
      <.no_results query={@query} />
    </div>
    \"""
  end

  def search_form(assigns) do
    ~H\"""
    <div class="mb-4 flex gap-2">
      <input
        type="text"
        class="input grow"
        placeholder="Search frameworks..."
        data-bind:query
        data-on:input__debounce.200ms={post("search")}
      />
      <button class="btn" data-on:click={post("reset")}>
        Reset
      </button>
    </div>
    \"""
  end

  attr :query, :string, default: nil

  def no_results(assigns) do
    ~H\"""
    <div data-show={query_results("=== 0")}>
      <p class="text-gray-500">
        No results found for "<span data-text="$query">{@query}</span>"
      </p>
    </div>
    \"""
  end

  attr :results, :list, default: []

  def item_list(assigns) do
    ~H\"""
    <ul id="item-list" class="grid gap-2" data-show={query_results("> 0")}>
      <.item :for={item <- @results} item={item} />
    </ul>
    \"""
  end

  attr :item, :string, required: true

  def item(assigns) do
    ~H\"""
    <li class="border p-4" data-show={starts_with?("'#{@item}'")}>
      {@item}
    </li>
    \"""
  end

  @impl StarView
  def handle_event("search", %{"query" => query} = signals, conn) do
    conn
    |> signal(:results, get_items(query))
    |> maybe_patch_list(signals)
  end

  def handle_event("reset", signals, conn) do
    conn
    |> signal(:query, "")
    |> signal(:results, @items)
    |> maybe_patch_list(signals)
  end

  defp get_items(""), do: @items

  defp get_items(query) do
    search_query = String.trim(String.downcase(query))
    Enum.filter(@items, &String.contains?(&1 |> String.downcase(), search_query))
  end

  defp maybe_patch_list(%{assigns: %{results: x}} = conn, %{"results" => x}), do: conn
  defp maybe_patch_list(conn, _signals), do: patch_element(conn, &item_list/1)

  defp starts_with?(item) do
    "\#{item}.trim().toLowerCase().startsWith($query.trim().toLowerCase())"
  end

  defp query_results(condition) do
    "$results.filter(x => \#{starts_with?("x")}).length \#{condition}"
  end
end
```

### LiveView Equivalent

```elixir
defmodule AppWeb.SearchLive do
  use AppWeb, :live_view

  alias Phoenix.LiveView.ColocatedHook

  @items ["Elixir", "Phoenix", "LiveView", "Datastar", "SSE", "Plug", "Ecto", "Ash", "HEEx", "Tailwind"]

  @impl LiveView
  def mount(_params, _session, socket) do
    socket
    |> assign(:query, "")
    |> assign(:results, @items)
    |> ok()
  end

  @impl LiveView
  def render(assigns) do
    ~H\"""
    <div id="active-search" class="max-w-xl mx-auto p-6" phx-hook=".ActiveSearch">
      <h1 class="text-2xl font-bold mb-4">Active Search</h1>
      <.search_form query={@query} />
      <.item_list results={@results} />
      <.no_results query={@query} has_results?={@results != []} />
    </div>
    <.active_search_script />
    \"""
  end

  attr :query, :string, default: nil

  def search_form(assigns) do
    ~H\"""
    <form phx-change="search" class="mb-4 flex gap-2">
      <input
        type="text"
        class="input grow"
        placeholder="Search frameworks..."
        name="query"
        value={@query}
        phx-debounce="200"
        data-search-input
      />
      <button type="button" class="btn" phx-click="reset">
        Reset
      </button>
    </form>
    \"""
  end

  attr :query, :string, default: nil
  attr :has_results?, :boolean, default: false

  def no_results(assigns) do
    ~H\"""
    <div class="space-y-2" data-search-empty hidden={@query == "" || @has_results?}>
      <p class="text-gray-500">
        No results found for "<span data-search-empty-query>{@query}</span>"
      </p>
    </div>
    \"""
  end

  attr :results, :list, default: []

  def item_list(assigns) do
    ~H\"""
    <ul class="grid gap-2" data-search-results hidden={@results == []}>
      <.item :for={item <- @results} item={item} />
    </ul>
    \"""
  end

  attr :item, :string, required: true

  def item(assigns) do
    ~H\"""
    <li class="border p-4" data-search-item={@item}>
      {@item}
    </li>
    \"""
  end

  @impl LiveView
  def handle_event("search", %{"query" => query}, socket) do
    socket
    |> assign(:query, query)
    |> assign(:results, get_items(query))
    |> noreply()
  end

  def handle_event("reset", _params, socket) do
    socket
    |> assign(:query, "")
    |> assign(:results, @items)
    |> noreply()
  end

  defp get_items(""), do: @items

  defp get_items(query) do
    search_query = String.trim(String.downcase(query))
    Enum.filter(@items, &String.contains?(&1 |> String.downcase(), search_query))
  end

  def active_search_script(assigns) do
    ~H\"""
    <script :type={ColocatedHook} name=".ActiveSearch">
      export default {
        mounted() {
          this.onInput = event => {
            if (event.target.matches("[data-search-input]")) {
              this.applyFilter()
            }
          }
          this.el.addEventListener("input", this.onInput, {passive: true})
          this.applyFilter()
        },
        updated() { this.applyFilter() },
        destroyed() { this.el.removeEventListener("input", this.onInput) },
        applyFilter() {
          const input = this.el.querySelector("[data-search-input]")
          const query = (input?.value || "").trim().toLowerCase()
          let visibleCount = 0

          this.el.querySelectorAll("[data-search-item]").forEach(item => {
            const value = (item.dataset.searchItem || "").trim().toLowerCase()
            const isVisible = query === "" || value.startsWith(query)
            item.hidden = !isVisible
            if (isVisible) { visibleCount += 1 }
          })

          const results = this.el.querySelector("[data-search-results]")
          const noResults = this.el.querySelector("[data-search-empty]")
          const noResultsQuery = this.el.querySelector("[data-search-empty-query]")

          if (results) { results.hidden = visibleCount === 0 }
          if (noResults) { noResults.hidden = query === "" || visibleCount > 0 }
          if (noResultsQuery) { noResultsQuery.textContent = input?.value || "" }
        }
      }
    </script>
    \"""
  end
end
```

## Key Differences

### 1. Client-Side Filtering

**OctaStar** uses Datastar's `data-show` with JavaScript expressions evaluated
in the browser. The filtering logic lives in small helper functions:

```elixir
defp starts_with?(item) do
  "#{item}.trim().toLowerCase().startsWith($query.trim().toLowerCase())"
end

defp query_results(condition) do
  "$results.filter(x => #{starts_with?("x")}).length #{condition}"
end
```

These expressions run instantly on every keystroke without any server round-trip.

**LiveView** requires a colocated JavaScript hook (~60 lines) that manually
queries the DOM, computes visibility, and toggles `hidden` attributes. The hook
must handle `mounted`, `updated`, and `destroyed` lifecycle events.

### 2. Signal Binding

**OctaStar** uses `data-bind:query` to automatically sync the input value to the
`$query` signal. The `data-text="$query"` attribute on the "no results" span
updates the displayed query text client-side without server involvement.

**LiveView** requires `name="query"`, `value={@query}`, and `phx-change="search"`
on the form, plus manual DOM queries in the hook to read the input value and
update the "no results" text content for optimistic updates.

### 3. Change Detection

**OctaStar** uses explicit change detection in `maybe_patch_list/2`:

```elixir
defp maybe_patch_list(%{assigns: %{results: x}} = conn, %{"results" => x}), do: conn
defp maybe_patch_list(conn, _signals), do: patch_element(conn, &item_list/1)
```

If the results haven't changed, no patch is sent. This is manual but gives you
full control over what gets sent over the wire.

**LiveView** does automatic change tracking — it diffs the render tree and only
sends changed DOM patches. This is convenient but adds overhead for computing
the diff on every render.

### 4. Transport

Both approaches support real-time server push — Phoenix PubSub works with either
protocol, and the BEAM VM handles WebSocket infrastructure and connection
management out of the box. The difference is in how each protocol shapes your
application architecture.

**OctaStar** uses SSE (Server-Sent Events) for server-to-client streaming and
standard HTTP requests for client-to-server events. Datastar can subscribe to
Phoenix PubSub topics to push real-time updates over the SSE stream, keeping
the connection alive with heartbeat events.

**LiveView** uses WebSockets for everything — events, uploads, and PubSub
broadcasts. The single bidirectional connection handles all communication,
but this means things that are naturally HTTP (like setting session cookies)
require fallback endpoints outside the LiveView.

#### SSE (OctaStar)

| Pros | Cons |
|------|------|
| Standard HTTP — works through all proxies, CDNs, firewalls | One-way only — client needs separate HTTP requests to send data |
| Automatic reconnection built into the protocol spec | Limited to text data (UTF-8) |
| Cookies work naturally — every client request is a regular HTTP call | Browser connection limits (~6 per domain) |
| Easy to debug with browser dev tools or `curl` | Client must initiate the SSE connection |
| Simple mental model — stream down, POST up | No native binary data support |
| Stateless server — no per-view process holding assigns in memory | |

#### WebSockets (LiveView)

| Pros | Cons |
|------|------|
| Bidirectional on a single connection | Can't set HTTP cookies over WebSocket — requires fallback HTTP endpoints for auth/session |
| Lower latency for rapid back-and-forth | Each LiveView holds a GenServer process in memory with full assigns state |
| Single connection handles everything (events, uploads, pubsub) | Some corporate proxies/firewalls may block or interfere |
| Binary data support | Connection lifecycle is more complex (handshake, frames, close codes) |
| | Server memory grows with each open view — assigns, diffs, and process state are retained |
| | Session management requires separate HTTP routes or token-based auth |

In practice, both need logic to decide when to push updates — Datastar requires
subscribing to PubSub topics and sending heartbeat events, while LiveView
requires `push_event/3` or assign changes that trigger renders. Neither has a
clear advantage for real-time capability; the choice comes down to whether you
prefer the simplicity and statelessness of HTTP (SSE) or the bidirectionality
of WebSockets.

### 5. Event Payloads

**OctaStar** sends and receives JSON signal maps. Client state arrives as a
plain map you work with directly:

```elixir
def handle_event("search", %{"query" => query} = signals, conn) do
  conn
  |> signal(:results, get_items(query))
  |> maybe_patch_list(signals)
end
```

No form parsing, no name/value collisions, no CSRF tokens to manage. Signals
are typed JSON — strings, numbers, booleans, lists, maps — and you access them
with `Map.get/2` or pattern matching.

**LiveView** receives form-encoded payloads through `phx-change` and `phx-submit`.
For simple inputs this works fine, but complex forms with nested data, dynamic
fields, or file uploads require careful naming conventions and manual parsing:

```elixir
def handle_event("search", %{"query" => query}, socket) do
  socket
  |> assign(:query, query)
  |> assign(:results, get_items(query))
  |> noreply()
end
```

HTML forms were designed in the 1990s for document submission, not interactive
applications. Datastar sidesteps this entirely by treating state as JSON signals
rather than form fields.

### 6. Architecture

| Aspect | OctaStar | LiveView |
|--------|----------|----------|
| Transport | SSE (server) + HTTP (client) | WebSocket (everything) |
| Client state | Datastar signals (`$query`, `$results`) | Socket assigns |
| Optimistic UI | `data-show`, `data-text`, `data-bind` | JS hooks + DOM manipulation |
| Change tracking | Manual (`maybe_patch_list`) | Automatic (render diff) |
| Connection model | Stateless requests + SSE stream | Persistent process per view |
| Real-time | PubSub over SSE stream | PubSub over WebSocket |
| Cookies | Native (HTTP requests) | Requires fallback endpoints |

## When to Choose Which

### Choose OctaStar when

- You prefer the simplicity of HTTP over WebSockets
- You need cookies to work naturally without fallback endpoints
- You want explicit control over what gets sent to the client
- You want optimistic UI with minimal JavaScript
- You prefer JSON signal maps over form-encoded payloads
- You're building on top of existing Phoenix controllers

### Choose LiveView when

- You want automatic change tracking without manual diff logic
- You need the full LiveView ecosystem (components, uploads, streams)
- You prefer a single bidirectional connection for all communication
