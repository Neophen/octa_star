defmodule StarView.Actions do
  @moduledoc """
  Datastar action expression helpers.

  These helpers generate strings for `data-on:*` attributes:

      <button data-on:click={StarView.Actions.post(MyAppWeb.CounterController, "increment")}>
  """

  @verbs ~w(get post put patch delete)a

  for verb <- @verbs do
    verb_string = Atom.to_string(verb)

    @doc """
    Generates a `@#{verb_string}(...)` Datastar action expression.
    """
    def unquote(verb)(module_or_event, event_or_opts \\ [])

    def unquote(verb)(module, event) when is_atom(module) and is_binary(event) do
      action(unquote(verb_string), module, event, [])
    end

    def unquote(verb)(event, opts) when is_binary(event) and is_list(opts) do
      dynamic_action(unquote(verb_string), event, opts)
    end

    def unquote(verb)(module, event, opts)
        when is_atom(module) and is_binary(event) and is_list(opts) do
      action(unquote(verb_string), module, event, opts)
    end
  end

  @doc """
  Encodes an Elixir module name for URL path usage.
  """
  @spec encode_module(module()) :: String.t()
  def encode_module(module) when is_atom(module) do
    module
    |> Module.split()
    |> Enum.map_join("-", &Macro.underscore/1)
  end

  @doc """
  Decodes a URL-safe module name into an existing Elixir module.
  """
  @spec decode_module(String.t()) :: {:ok, module()} | :error
  def decode_module(encoded) when is_binary(encoded) do
    module =
      encoded
      |> String.split("-")
      |> Enum.map_join(".", &Macro.camelize/1)

    {:ok, String.to_existing_atom("Elixir." <> module)}
  rescue
    ArgumentError -> :error
  end

  @doc false
  def dom_id("#" <> _ = id), do: id
  def dom_id(id) when is_binary(id), do: "#" <> id

  defp action(verb, module, event, opts) do
    "@#{verb}('#{dispatch_path(module, event, opts)}')"
  end

  defp dynamic_action(verb, event, opts) do
    module_expr = Keyword.get(opts, :module, "$_star_view_module")
    prefix = opts |> Keyword.get(:prefix, "") |> normalize_prefix()

    path_expr =
      if String.starts_with?(module_expr, "$") do
        "'#{prefix}/ds/' + #{module_expr} + '/#{event}'"
      else
        "'#{prefix}/ds/#{module_expr}/#{event}'"
      end

    "@#{verb}(#{path_expr})"
  end

  defp dispatch_path(module, event, opts) do
    prefix = opts |> Keyword.get(:prefix, "") |> normalize_prefix()
    "#{prefix}/ds/#{encode_module(module)}/#{event}"
  end

  defp normalize_prefix(nil), do: ""
  defp normalize_prefix(""), do: ""
  defp normalize_prefix("/" <> _ = prefix), do: String.trim_trailing(prefix, "/")
  defp normalize_prefix(prefix), do: "/" <> String.trim_trailing(prefix, "/")
end
