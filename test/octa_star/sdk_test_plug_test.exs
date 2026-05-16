defmodule OctaStar.SDKTestPlugTest do
  use ExUnit.Case, async: true

  import Plug.Test

  alias OctaStar.TestAssertions

  test "implements the official SDK /test endpoint shape" do
    body =
      OctaStar.JSON.encode!(%{
        events: [
          %{
            type: "patchElements",
            elements: ~s(<div id="target">Hello</div>),
            eventId: "event1",
            retryDuration: 2000
          },
          %{type: "patchSignals", signals: %{count: 1}}
        ]
      })

    conn =
      :post
      |> conn("/test", body)
      |> OctaStar.SDKTestPlug.call([])

    assert {200, _headers, response} = TestAssertions.chunked_resp(conn)

    assert response ==
             """
             event: datastar-patch-elements
             id: event1
             retry: 2000
             data: elements <div id="target">Hello</div>

             event: datastar-patch-signals
             data: signals {"count":1}

             """
  end
end
