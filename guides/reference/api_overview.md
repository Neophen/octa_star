# API Overview

The full API is documented in the module reference. These are the primary
entry points.

```elixir
StarView.start(conn)
StarView.start_stream(conn, user_id)
StarView.check_connection(conn)

StarView.patch_elements(conn, html, selector: "#target", mode: :replace)
StarView.remove_elements(conn, "#target")

StarView.patch_signals(conn, %{count: 1})
StarView.patch_signals_raw(conn, ~s({"count":1}))
StarView.remove_signals(conn, ["user.email"])

StarView.execute_script(conn, "console.log('done')")
StarView.redirect(conn, "/next")
StarView.console_log(conn, "debug")
StarView.read_signals(conn)
```

For Phoenix controller helpers, see `StarView.Controller` and
`StarView.Dispatch`.
