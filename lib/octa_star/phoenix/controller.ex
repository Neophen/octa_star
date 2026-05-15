defmodule OctaStar.Phoenix.Controller do
  @moduledoc """
  Phoenix controller helpers for OctaStar.

  Use this from your web module after `use Phoenix.Controller` has been applied:

      def controller do
        quote do
          use Phoenix.Controller, formats: [:html, :json]
          use OctaStar.Phoenix.Controller
        end
      end
  """

  import Plug.Conn

  @signals_key :octa_star_signals_keys_and_opts

  defmacro __using__(opts \\ []) do
    auto_render? = Keyword.get(opts, :auto_render, true)

    quote bind_quoted: [auto_render?: auto_render?] do
      import OctaStar.Phoenix.Controller

      @behaviour OctaStar.Phoenix.ControllerBehaviour

      @doc false
      def __octa_star_handler__, do: true

      def render_html(conn) do
        conn
        |> Phoenix.Controller.put_view(html: __MODULE__)
        |> Phoenix.Controller.render(:html)
      end

      def get(name_or_opts \\ []), do: OctaStar.Actions.get(__MODULE__, name_or_opts)
      def get(event_name, opts), do: OctaStar.Actions.get(__MODULE__, event_name, opts)

      def post(name_or_opts \\ []), do: OctaStar.Actions.post(__MODULE__, name_or_opts)
      def post(event_name, opts), do: OctaStar.Actions.post(__MODULE__, event_name, opts)

      def put(name_or_opts \\ []), do: OctaStar.Actions.put(__MODULE__, name_or_opts)
      def put(event_name, opts), do: OctaStar.Actions.put(__MODULE__, event_name, opts)

      def patch(name_or_opts \\ []), do: OctaStar.Actions.patch(__MODULE__, name_or_opts)
      def patch(event_name, opts), do: OctaStar.Actions.patch(__MODULE__, event_name, opts)

      def delete(name_or_opts \\ []), do: OctaStar.Actions.delete(__MODULE__, name_or_opts)
      def delete(event_name, opts), do: OctaStar.Actions.delete(__MODULE__, event_name, opts)

      if auto_render? do
        def action(conn, opts) do
          conn = super(conn, opts)
          OctaStar.Phoenix.Controller.__maybe_auto_render__(__MODULE__, conn)
        end
      end

      defoverridable action: 2, render_html: 1
    end
  end

  @doc """
  Assigns a value and tracks it as a Datastar signal.
  """
  @spec signal(Plug.Conn.t(), atom(), term(), keyword()) :: Plug.Conn.t()
  def signal(%Plug.Conn{} = conn, key, value, opts \\ []) when is_atom(key) do
    conn
    |> assign(key, value)
    |> put_signal_key(key, opts)
  end

  @doc """
  Patches a rendered component or HTML value against current assigns.
  """
  @spec patch_element(Plug.Conn.t(), (map() -> term()) | term(), keyword()) :: Plug.Conn.t()
  def patch_element(%Plug.Conn{} = conn, component_or_html, opts \\ []) do
    opts =
      case Keyword.pop(opts, :to) do
        {nil, opts} -> opts
        {to, opts} -> Keyword.put(opts, :selector, dom_id(to))
      end

    html =
      if is_function(component_or_html, 1) do
        component_or_html.(conn.assigns)
      else
        component_or_html
      end

    OctaStar.patch_elements(conn, html, opts)
  end

  @doc """
  Flushes tracked signals as Datastar signal patch events.
  """
  @spec flush_signals(Plug.Conn.t()) :: Plug.Conn.t()
  def flush_signals(%Plug.Conn{} = conn) do
    case extract_signals(conn) do
      [] ->
        conn

      signals ->
        Enum.reduce(signals, conn, fn {key, value, opts}, conn ->
          OctaStar.patch_signals(conn, %{key => value}, opts)
        end)
    end
  end

  @doc """
  Returns the tracked signal map as JSON for `data-signals`.
  """
  @spec init_signals(Plug.Conn.t()) :: String.t() | nil
  def init_signals(%Plug.Conn{} = conn) do
    case extract_signals(conn) do
      [] ->
        nil

      signals ->
        signals
        |> Enum.map(fn {key, value, _opts} -> {key, value} end)
        |> Map.new()
        |> OctaStar.JSON.encode!()
    end
  end

  @doc """
  Extracts tracked signal keys, values, and per-signal options.
  """
  @spec extract_signals(Plug.Conn.t()) :: [{atom(), term(), keyword()}]
  def extract_signals(%Plug.Conn{} = conn) do
    conn.private
    |> Map.get(@signals_key, [])
    |> Enum.reverse()
    |> Enum.map(fn {key, opts} -> {key, conn.assigns[key], opts} end)
  end

  @doc false
  def __maybe_auto_render__(module, %Plug.Conn{state: :unset, halted: false} = conn) do
    if function_exported?(module, :html, 1) do
      conn
      |> then(&apply(:"Elixir.Phoenix.Controller", :put_view, [&1, [html: module]]))
      |> then(&apply(:"Elixir.Phoenix.Controller", :render, [&1, :html]))
    else
      conn
    end
  end

  def __maybe_auto_render__(_module, conn), do: conn

  @doc false
  def dom_id("#" <> _ = id), do: id
  def dom_id(id) when is_binary(id), do: "#" <> id

  defp put_signal_key(%Plug.Conn{} = conn, key, opts) do
    put_private(conn, @signals_key, [{key, opts} | Map.get(conn.private, @signals_key, [])])
  end
end
