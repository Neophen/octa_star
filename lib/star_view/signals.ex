defmodule StarView.Signals do
  @moduledoc """
  Datastar signal reading and `datastar-patch-signals` helpers.
  """

  alias Plug.Conn
  alias StarView.Constants
  alias StarView.JSON
  alias StarView.SSE

  defmodule ReadError do
    @moduledoc """
    Raised when Datastar signals cannot be decoded from the request body.
    """
    defexception [:reason]

    @impl Exception
    def message(%__MODULE__{reason: reason}),
      do: "failed to read Datastar signals: #{inspect(reason)}"
  end

  @event_type Constants.event_type(:patch_signals)
  @datastar_key Constants.datastar_key()
  @default_only_if_missing Constants.default_patch_signals_only_if_missing()

  @doc """
  Reads Datastar signals from a Plug connection.

  `GET` and `DELETE` requests read the `datastar` query parameter. Other
  methods read JSON from the request body unless a parser has already populated
  `conn.body_params`.
  """
  @spec read(Conn.t()) :: {:ok, map()} | {:error, term()}
  def read(%Conn{method: method} = conn) when method in ["GET", "DELETE"] do
    conn = Conn.fetch_query_params(conn)

    case Map.get(conn.query_params, @datastar_key) do
      nil -> {:ok, %{}}
      "" -> {:ok, %{}}
      json -> decode_map(json)
    end
  end

  def read(%Conn{body_params: %Conn.Unfetched{}} = conn) do
    case Conn.read_body(conn) do
      {:ok, "", _conn} -> {:ok, %{}}
      {:ok, body, _conn} -> decode_map(body)
      {:more, _partial, _conn} -> {:error, :body_too_large}
      {:error, reason} -> {:error, reason}
    end
  end

  def read(%Conn{body_params: body_params}) when is_map(body_params), do: {:ok, body_params}
  def read(%Conn{}), do: {:ok, %{}}

  @doc """
  Reads Datastar signals and raises on errors.
  """
  @spec read!(Conn.t()) :: map()
  def read!(%Conn{} = conn) do
    case read(conn) do
      {:ok, signals} -> signals
      {:error, reason} -> raise ReadError, reason: reason
    end
  end

  @doc """
  Sends a signal patch from a map.
  """
  @spec patch(Conn.t(), map(), keyword()) :: Conn.t()
  def patch(conn, signals, opts \\ []) when is_map(signals) do
    patch_raw(conn, JSON.encode!(signals), opts)
  end

  @doc """
  Sends a signal patch from a JSON string.
  """
  @spec patch_raw(Conn.t(), String.t(), keyword()) :: Conn.t()
  def patch_raw(conn, signals_json, opts \\ []) when is_binary(signals_json) do
    data_lines = data_lines(signals_json, opts)
    SSE.send!(conn, @event_type, data_lines, sse_opts(opts))
  end

  @doc """
  Removes one or more signals by setting dot-notated paths to `null`.
  """
  @spec remove_signals(Conn.t(), String.t() | [String.t()], keyword()) :: Conn.t()
  def remove_signals(conn, paths, opts \\ []) do
    patch(conn, paths_to_nil_map(List.wrap(paths)), opts)
  end

  @doc """
  Formats a signal patch without writing to a connection.
  """
  @spec format_patch(map(), keyword()) :: String.t()
  def format_patch(signals, opts \\ []) when is_map(signals) do
    format_patch_raw(JSON.encode!(signals), opts)
  end

  @doc """
  Formats a raw JSON signal patch without writing to a connection.
  """
  @spec format_patch_raw(String.t(), keyword()) :: String.t()
  def format_patch_raw(signals_json, opts \\ []) when is_binary(signals_json) do
    SSE.format_event(
      @event_type,
      data_lines(signals_json, opts),
      sse_opts(opts)
    )
  end

  @doc """
  Formats a signal removal without writing to a connection.
  """
  @spec format_remove(String.t() | [String.t()], keyword()) :: String.t()
  def format_remove(paths, opts \\ []) do
    paths
    |> List.wrap()
    |> paths_to_nil_map()
    |> format_patch(opts)
  end

  @doc false
  def data_lines(signals_json, opts \\ []) do
    only_if_missing = Keyword.get(opts, :only_if_missing, @default_only_if_missing)

    []
    |> maybe_add_only_if_missing(only_if_missing)
    |> add_signals(signals_json)
  end

  defp maybe_add_only_if_missing(lines, false), do: lines

  defp maybe_add_only_if_missing(lines, true) do
    lines ++ [Constants.dataline_literal(:only_if_missing) <> "true"]
  end

  defp add_signals(lines, signals_json) do
    lines ++
      (signals_json
       |> String.split("\n")
       |> Enum.map(&(Constants.dataline_literal(:signals) <> &1)))
  end

  defp paths_to_nil_map(paths) when is_list(paths) do
    Enum.reduce(paths, %{}, fn path, acc ->
      validate_path!(path)
      deep_merge(acc, path_to_nil_map(path))
    end)
  end

  defp path_to_nil_map(path) do
    path
    |> String.split(".")
    |> Enum.reverse()
    |> Enum.reduce(nil, fn segment, acc -> %{segment => acc} end)
  end

  defp deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _key, left_value, right_value ->
      if is_map(left_value) and is_map(right_value),
        do: deep_merge(left_value, right_value),
        else: right_value
    end)
  end

  defp validate_path!(path) when is_binary(path) do
    cond do
      path == "" ->
        raise ArgumentError, "signal path cannot be empty"

      String.starts_with?(path, ".") ->
        raise ArgumentError, "signal path cannot start with a dot: #{inspect(path)}"

      String.ends_with?(path, ".") ->
        raise ArgumentError, "signal path cannot end with a dot: #{inspect(path)}"

      String.contains?(path, "..") ->
        raise ArgumentError, "signal path cannot contain consecutive dots: #{inspect(path)}"

      true ->
        :ok
    end
  end

  defp validate_path!(path),
    do: raise(ArgumentError, "signal path must be a string, got: #{inspect(path)}")

  defp decode_map(json) when is_binary(json) do
    case JSON.decode(json) do
      {:ok, value} when is_map(value) -> {:ok, value}
      {:ok, value} -> {:error, {:invalid_signals, value}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp sse_opts(opts), do: Keyword.take(opts, [:event_id, :retry, :retry_duration])
end
