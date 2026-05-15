defmodule OctaStar.ServerSentEventGeneratorTest do
  use ExUnit.Case, async: true

  alias OctaStar.ServerSentEventGenerator

  test "formats events in SDK order and omits default retry" do
    assert ServerSentEventGenerator.format_event(
             "datastar-patch-signals",
             ["signals {\"count\":1}"],
             event_id: "event1",
             retry_duration: 1000
           ) ==
             """
             event: datastar-patch-signals
             id: event1
             data: signals {"count":1}

             """
  end

  test "includes non-default retry duration" do
    assert ServerSentEventGenerator.format_event(
             "datastar-patch-elements",
             ["elements <div></div>"],
             retry_duration: 2000
           ) ==
             """
             event: datastar-patch-elements
             retry: 2000
             data: elements <div></div>

             """
  end
end
