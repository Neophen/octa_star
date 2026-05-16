defmodule OctaStar.Constants do
  @moduledoc false

  @datastar_key "datastar"

  @event_type_patch_elements "datastar-patch-elements"
  @event_type_patch_signals "datastar-patch-signals"

  @default_sse_retry_duration 1000
  @default_element_patch_mode :outer
  @default_namespace :html
  @default_elements_use_view_transitions false
  @default_patch_signals_only_if_missing false

  @element_patch_modes ~w(outer inner remove replace prepend append before after)a
  @namespaces ~w(html svg mathml)a

  @dataline_literals %{
    selector: "selector ",
    mode: "mode ",
    elements: "elements ",
    use_view_transition: "useViewTransition ",
    namespace: "namespace ",
    signals: "signals ",
    only_if_missing: "onlyIfMissing "
  }

  def datastar_key(), do: @datastar_key

  def event_type(:patch_elements), do: @event_type_patch_elements
  def event_type(:patch_signals), do: @event_type_patch_signals

  def default_sse_retry_duration(), do: @default_sse_retry_duration
  def default_element_patch_mode(), do: @default_element_patch_mode
  def default_namespace(), do: @default_namespace
  def default_elements_use_view_transitions(), do: @default_elements_use_view_transitions
  def default_patch_signals_only_if_missing(), do: @default_patch_signals_only_if_missing

  def element_patch_modes(), do: @element_patch_modes
  def namespaces(), do: @namespaces

  def dataline_literal(name), do: Map.fetch!(@dataline_literals, name)
end
