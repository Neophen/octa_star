defmodule OctaStar.FacadeTest do
  use ExUnit.Case, async: true

  import Plug.Test

  alias OctaStar.Signals.ReadError
  alias OctaStar.TestAssertions

  defp sse_body(conn) do
    {200, _headers, body} = TestAssertions.chunked_resp(conn)
    body
  end

  defp started_conn() do
    conn(:get, "/") |> OctaStar.start()
  end

  describe "read_signals/1 and read_signals!/1" do
    test "read_signals/1 returns a bare signal map" do
      conn = conn(:post, "/", ~s({"count":1}))

      assert OctaStar.read_signals(conn) == %{"count" => 1}
    end

    test "read_signals!/1 matches read_signals/1 on valid payloads" do
      conn = conn(:post, "/", ~s({"count":1}))

      assert OctaStar.read_signals!(conn) == OctaStar.read_signals(conn)
    end

    test "read_signals/1 raises ReadError on invalid JSON" do
      conn = conn(:post, "/", "not-json")

      assert_raise ReadError, fn -> OctaStar.read_signals(conn) end
    end
  end

  describe "start/1 and check_connection/1" do
    test "start/1 opens a chunked SSE response" do
      conn = started_conn()

      assert conn.state == :chunked

      {status, headers, _body} = TestAssertions.chunked_resp(conn)
      assert status == 200
      assert {"content-type", "text/event-stream; charset=utf-8"} in headers
    end

    test "check_connection/1 returns ok on a started connection" do
      conn = started_conn()

      assert {:ok, conn} = OctaStar.check_connection(conn)
      assert conn.state == :chunked
    end

    test "check_connection/1 returns error when SSE was not started" do
      conn = conn(:get, "/")

      assert {:error, ^conn} = OctaStar.check_connection(conn)
    end
  end

  describe "patch and remove helpers" do
    test "patch_signals/2 emits a signal patch event" do
      body =
        started_conn()
        |> OctaStar.patch_signals(%{count: 2})
        |> sse_body()

      assert body ==
               """
               event: datastar-patch-signals
               data: signals {"count":2}

               """
    end

    test "patch_signals_raw/2 emits pre-encoded JSON" do
      body =
        started_conn()
        |> OctaStar.patch_signals_raw(~s({"count":3}))
        |> sse_body()

      assert body ==
               """
               event: datastar-patch-signals
               data: signals {"count":3}

               """
    end

    test "patch_elements/2 emits an element patch event" do
      body =
        started_conn()
        |> OctaStar.patch_elements(~s(<motion.div id="x">1</motion.div>), selector: "#x")
        |> sse_body()

      assert body ==
               """
               event: datastar-patch-elements
               data: selector #x
               data: elements <motion.div id="x">1</motion.div>

               """
    end

    test "remove_elements/2 emits a remove patch" do
      body =
        started_conn()
        |> OctaStar.remove_elements("#flash")
        |> sse_body()

      assert body ==
               """
               event: datastar-patch-elements
               data: selector #flash
               data: mode remove

               """
    end

    test "remove_signals/2 emits null paths for removed signals" do
      body =
        started_conn()
        |> OctaStar.remove_signals(["user.email", "user.name"])
        |> sse_body()

      assert body ==
               """
               event: datastar-patch-signals
               data: signals {"user":{"email":null,"name":null}}

               """
    end
  end

  describe "script helpers" do
    test "execute_script/2 appends a script to body" do
      body =
        started_conn()
        |> OctaStar.execute_script("console.log('facade')")
        |> sse_body()

      assert body =~ "event: datastar-patch-elements\n"

      assert body =~
               "data: elements <script data-effect=\"el.remove()\">console.log('facade')</script>"
    end

    test "redirect/2 emits a location script" do
      body =
        started_conn()
        |> OctaStar.redirect("/dashboard")
        |> sse_body()

      assert body =~ ~s|window.location.href="/dashboard"|
    end

    test "console_log/2 emits a console call" do
      body =
        started_conn()
        |> OctaStar.console_log(%{debug: true})
        |> sse_body()

      assert body =~ "console.log("
      assert body =~ ~s|{"debug":true}|
    end
  end

  describe "send/3" do
    test "sends a raw SSE event through the facade" do
      body =
        started_conn()
        |> OctaStar.send("custom-event", ["line one", "line two"], event_id: "e1")
        |> sse_body()

      assert body ==
               """
               event: custom-event
               id: e1
               data: line one
               data: line two

               """
    end
  end
end
