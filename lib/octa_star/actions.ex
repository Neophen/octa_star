defmodule OctaStar.Actions do
  @moduledoc """
  Datastar action expression helpers.

  These helpers generate strings for `data-on:*` attributes:

      <button data-on:click={OctaStar.Actions.post(MyAppWeb.CounterController, "increment")}>
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
  Generates a form-encoded Datastar action expression.
  """
  @spec form(:post | :put | :patch, module(), String.t(), String.t() | nil, keyword()) ::
          String.t()
  def form(verb, module, event, form_id \\ nil, opts \\ [])
      when verb in [:post, :put, :patch] and is_atom(module) and is_binary(event) do
    path = dispatch_path(module, event, opts)
    selector = if form_id, do: ", selector: '#{dom_id(form_id)}'", else: ""
    csrf_signal = Keyword.get(opts, :csrf_signal, "$csrf")

    "@#{verb}('#{path}', {contentType: 'form', headers: {'x-csrf-token': #{csrf_signal}}#{selector}})"
  end

  @doc """
  Encodes an Elixir module name for URL path usage.
  """
  @spec encode_module(module()) :: String.t()
  def encode_module(module) when is_atom(module) do
    module
    |> Module.split()
    |> Enum.map(&Macro.underscore/1)
    |> Enum.join("-")
  end

  @doc """
  Decodes a URL-safe module name into an existing Elixir module.
  """
  @spec decode_module(String.t()) :: {:ok, module()} | :error
  def decode_module(encoded) when is_binary(encoded) do
    module =
      encoded
      |> String.split("-")
      |> Enum.map(&Macro.camelize/1)
      |> Enum.join(".")

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
    module_expr = Keyword.get(opts, :module, "$_octa_star_module")
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
