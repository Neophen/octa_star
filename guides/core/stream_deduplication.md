# Per-Tab Stream Deduplication

When a user navigates away, an old SSE process can remain alive until the next
keepalive. StarView can close the old stream when a new stream starts from the
same browser tab.

Add the registry to your supervision tree:

```elixir
children = [
  StarView.StreamRegistry,
  # ...
]
```

Set a `tabId` signal in your layout:

```heex
<div data-signals={~s({"tabId": "#{Ecto.UUID.generate()}"})}>
```

Start streams with:

```elixir
conn = StarView.start_stream(conn, current_user.id)
```

If no `tabId` is present, StarView falls back to a regular SSE stream with no
deduplication.
