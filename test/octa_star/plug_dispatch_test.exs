defmodule OctaStar.Plug.DispatchTest do
  use ExUnit.Case, async: true
  import Plug.Test

  alias OctaStar.Actions
  alias OctaStar.Plug.Dispatch
  alias OctaStar.TestAssertions
  alias OctaStar.TestHandlers.Counter

  test "dispatches to allowlisted modules and starts SSE" do
    encoded = Actions.encode_module(Counter)

    conn =
      :post
      |> conn("/ds/#{encoded}/increment", ~s({"count":1}))
      |> Map.put(:path_params, %{"module" => encoded, "event" => "increment"})
      |> Dispatch.call(Dispatch.init(modules: [Counter]))

    assert {200, headers, body} = TestAssertions.chunked_resp(conn)
    assert {"content-type", "text/event-stream; charset=utf-8"} in headers

    assert body ==
             """
             event: datastar-patch-signals
             data: signals {"count":2}

             """
  end

  test "rejects unknown modules" do
    conn =
      :post
      |> conn("/ds/unknown/increment", ~s({"count":1}))
      |> Map.put(:path_params, %{"module" => "unknown", "event" => "increment"})
      |> Dispatch.call(Dispatch.init(modules: [Counter]))

    assert {404, headers, "Not found"} = sent_resp(conn)
    assert {"content-type", "text/plain; charset=utf-8"} in headers
  end
end
