# Overview

StarView is an Elixir SDK for [Datastar](https://data-star.dev) Server-Sent
Events. It works with Plug and Phoenix, and uses Erlang's built-in `:json`
module.

## The Problem

Building Datastar apps in Elixir can mean a lot of repeated wiring. You start
SSE responses, track which values need to reach the browser, render updated
HTML, and keep event handlers mapped to the modules that own them.

StarView keeps that flow close to normal Phoenix controller code.

## What StarView Adds

`signal/3` sets a connection assign and exposes the same value as a Datastar
signal. Function components can read the assign, while the browser receives the
signal during the initial render or immediately during an SSE event.

```elixir
def handle_event("increment", signals, conn) do
  conn
  |> assign(:computed_value, expensive_calculation(signals))
  |> signal(:count, signals["count"] + 1)
  |> patch_element(&history_item/1, to: "history-list", mode: :append)
end
```

## Dispatch Flow

The Phoenix dispatcher starts the SSE response before your handler runs. Your
controller handles the event and returns the updated connection:

```elixir
@impl StarView
def handle_event("increment", signals, conn) do
  signal(conn, :count, Map.get(signals, "count", 0) + 1)
end
```

Any controller that uses `use StarView` is automatically dispatchable through
`StarView.Dispatch`, so you do not maintain an allow-list for Phoenix
controllers.

## Next Steps

Start with the installation guide, then add the Phoenix web module section and
routes. Once the app is running, the core guides cover `patch_signals/3`,
`patch_element/3`, and optional per-tab stream deduplication.
