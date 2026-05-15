defmodule OctaStar.JSON do
  @moduledoc """
  Tiny wrapper around Erlang/OTP's native `:json` module.

  Erlang represents JSON `null` as the atom `:null`, while Elixir callers expect
  `nil`. This module converts `nil` to `:null` before encoding and converts
  decoded `:null` values back to `nil`.
  """

  @doc """
  Encodes an Elixir term as JSON.
  """
  @spec encode!(term()) :: String.t()
  def encode!(term) do
    ensure_native_json!()

    term
    |> to_json_term()
    |> :json.encode()
    |> IO.iodata_to_binary()
  end

  @doc """
  Decodes JSON into Elixir terms.
  """
  @spec decode(String.t()) :: {:ok, term()} | {:error, term()}
  def decode(json) when is_binary(json) do
    ensure_native_json!()

    try do
      {:ok, json |> :json.decode() |> from_json_term()}
    catch
      kind, reason ->
        {:error, {kind, reason}}
    end
  end

  @doc """
  Decodes JSON into Elixir terms, raising on invalid JSON.
  """
  @spec decode!(String.t()) :: term()
  def decode!(json) when is_binary(json) do
    case decode(json) do
      {:ok, value} -> value
      {:error, reason} -> raise ArgumentError, "invalid JSON: #{inspect(reason)}"
    end
  end

  @doc false
  def ensure_native_json! do
    unless Code.ensure_loaded?(:json) and function_exported?(:json, :encode, 1) do
      raise RuntimeError,
            "OctaStar requires Erlang/OTP 27 or later because it uses the native :json module"
    end
  end

  defp to_json_term(nil), do: :null
  defp to_json_term(%_{} = struct), do: struct |> Map.from_struct() |> to_json_term()

  defp to_json_term(%{} = map) do
    Map.new(map, fn {key, value} -> {key, to_json_term(value)} end)
  end

  defp to_json_term(list) when is_list(list), do: Enum.map(list, &to_json_term/1)
  defp to_json_term(tuple) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> to_json_term()
  defp to_json_term(value), do: value

  defp from_json_term(:null), do: nil

  defp from_json_term(%{} = map) do
    Map.new(map, fn {key, value} -> {key, from_json_term(value)} end)
  end

  defp from_json_term(list) when is_list(list), do: Enum.map(list, &from_json_term/1)
  defp from_json_term(value), do: value
end
