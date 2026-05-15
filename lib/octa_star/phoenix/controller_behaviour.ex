defmodule OctaStar.Phoenix.ControllerBehaviour do
  @moduledoc """
  Behaviour for OctaStar-enabled Phoenix controllers.

  It mirrors the lightweight controller model from Octafest:

  * `show/2` may return an unsent conn.
  * `html/1` renders the controller's HTML view/component.
  * `handle_event/3` handles Datastar events after the SSE response has started.
  """

  @callback show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  @callback html(map()) :: term()
  @callback handle_event(Plug.Conn.t(), String.t(), map()) :: Plug.Conn.t()

  @optional_callbacks show: 2, html: 1, handle_event: 3
end
