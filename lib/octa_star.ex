defmodule OctaStar do
  @moduledoc """
  Elixir SDK helpers for Datastar.

  The facade functions in this module delegate to small protocol modules while
  keeping a pipeline-friendly Plug API:

      conn
      |> OctaStar.start()
      |> OctaStar.patch_signals(%{count: 1})
      |> OctaStar.patch_elements(~s(<div id="count">1</div>))
  """

  @doc """
  Provides Phoenix controller helpers.

  Use `use OctaStar, :controller` in your `AppWeb.controller/0` macro
  instead of `use OctaStar.Phoenix.Controller` directly:

      def controller do
        quote do
          use Phoenix.Controller, formats: [:html]
          use OctaStar, :controller
        end
      end
  """
  defmacro __using__(:controller) do
    quote do
      use OctaStar.Phoenix.Controller
    end
  end

  @doc """
  Starts a Server-Sent Events response on a Plug connection.
  """
  @spec start(Plug.Conn.t()) :: Plug.Conn.t()
  defdelegate start(conn), to: OctaStar.ServerSentEventGenerator

  @doc """
  Sends a raw Datastar SSE event and returns the updated connection.
  """
  @spec send(Plug.Conn.t(), String.t(), [String.t()] | String.t(), keyword()) :: Plug.Conn.t()
  defdelegate send(conn, event_type, data_lines, opts \\ []),
    to: OctaStar.ServerSentEventGenerator,
    as: :send!

  @doc """
  Starts an SSE stream with per-tab deduplication.

  Requires `OctaStar.Utility.StreamRegistry` in your supervision tree
  and a `tabId` signal in your root layout. See
  `OctaStar.Utility.StreamRegistry` for setup.
  """
  @spec start_stream(Plug.Conn.t(), term()) :: Plug.Conn.t()
  defdelegate start_stream(conn, scope_key), to: OctaStar.Utility.StreamRegistry

  @doc """
  Checks whether a chunked SSE connection still accepts writes.
  """
  @spec check_connection(Plug.Conn.t()) :: {:ok, Plug.Conn.t()} | {:error, Plug.Conn.t()}
  defdelegate check_connection(conn), to: OctaStar.ServerSentEventGenerator

  @doc """
  Reads Datastar signals from a Plug connection.

  Returns a signal map. Raises `OctaStar.Signals.ReadError` when the
  payload cannot be decoded. Plugs that need `{:ok, map()} | {:error, term()}`
  should call `OctaStar.Signals.read/1` instead.
  """
  @spec read_signals(Plug.Conn.t()) :: map()
  def read_signals(conn), do: OctaStar.Signals.read!(conn)

  @doc """
  Reads Datastar signals from a Plug connection, raising on invalid JSON.
  """
  @spec read_signals!(Plug.Conn.t()) :: map()
  defdelegate read_signals!(conn), to: OctaStar.Signals, as: :read!

  @doc """
  Patches one or more complete HTML elements into the DOM.
  """
  @spec patch_elements(Plug.Conn.t(), iodata() | tuple() | nil, keyword()) :: Plug.Conn.t()
  defdelegate patch_elements(conn, elements, opts \\ []), to: OctaStar.Elements, as: :patch

  @doc """
  Removes elements from the DOM by CSS selector.
  """
  @spec remove_elements(Plug.Conn.t(), String.t(), keyword()) :: Plug.Conn.t()
  defdelegate remove_elements(conn, selector, opts \\ []), to: OctaStar.Elements, as: :remove

  @doc """
  Patches client-side Datastar signals using RFC 7386 JSON Merge Patch semantics.
  """
  @spec patch_signals(Plug.Conn.t(), map(), keyword()) :: Plug.Conn.t()
  defdelegate patch_signals(conn, signals, opts \\ []), to: OctaStar.Signals, as: :patch

  @doc """
  Patches client-side Datastar signals from a pre-encoded JSON string.
  """
  @spec patch_signals_raw(Plug.Conn.t(), String.t(), keyword()) :: Plug.Conn.t()
  defdelegate patch_signals_raw(conn, signals_json, opts \\ []),
    to: OctaStar.Signals,
    as: :patch_raw

  @doc """
  Removes signals by setting one or more dot-notated signal paths to `null`.
  """
  @spec remove_signals(Plug.Conn.t(), String.t() | [String.t()], keyword()) :: Plug.Conn.t()
  defdelegate remove_signals(conn, paths, opts \\ []), to: OctaStar.Signals

  @doc """
  Executes JavaScript in the browser by appending a script element.
  """
  @spec execute_script(Plug.Conn.t(), String.t(), keyword()) :: Plug.Conn.t()
  defdelegate execute_script(conn, script, opts \\ []), to: OctaStar.Scripts, as: :execute

  @doc """
  Redirects the browser by executing a tiny client-side script.
  """
  @spec redirect(Plug.Conn.t(), String.t(), keyword()) :: Plug.Conn.t()
  defdelegate redirect(conn, url, opts \\ []), to: OctaStar.Scripts

  @doc """
  Logs a value to the browser console.
  """
  @spec console_log(Plug.Conn.t(), term(), keyword()) :: Plug.Conn.t()
  defdelegate console_log(conn, message, opts \\ []), to: OctaStar.Scripts
end
