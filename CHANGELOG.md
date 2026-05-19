# Changelog

## v0.3.2

### Changed

- Improved the guide documentation.

## v0.3.1

### Changed

- `StarView.mount/2` signature is `(conn, params)` — conn first argument to
  work with Phoenix's default action dispatch (`get "/", SearchController`).
- Only `handle_event/3` is optional — `mount/2` and `render/1` are now required
  callbacks on `StarView`.
- SearchController demo template extracted to `priv/templates/search_controller.ex.eex`
  for easier maintenance. The generated controller now demonstrates smart change
  detection with `maybe_patch_list/2` and `data-text` for client-side signal display.

### Added

- `guides/comparison/liveview_vs_star_view.md` — side-by-side comparison of
  StarView vs LiveView using the same active search example, including transport
  trade-offs (SSE vs WebSocket) and event payload differences (JSON vs forms).

## v0.3.0

### Changed

- **Breaking:** Renamed `StarView` callbacks for clarity and consistency with LiveView:
  - `show/2` → `mount/2` (sets up initial signals and assigns)
  - `html/1` → `render/1` (renders the HEEx template)
  - `handle_event/3` argument order changed from `(conn, event, signals)` to
    `(event, signals, conn)` to match the Phoenix LiveView convention

## v0.2.1

### Changed

- Improved the Search demo example.

## v0.2.0

### Changed

- `mix igniter.install star_view` delegates to composable setup subtasks
  instead of duplicating logic, removing ~270 lines of duplicated code.

## v0.1.2

### Fixed

- `mix igniter.install star_view` now correctly detects Phoenix projects and
  applies all patches (web module, HTTPS config, routes, demo controller).

### Changed

- Installer split into composable setup subtasks
  (`star_view.setup.streaming`, `star_view.setup.datastar`,
  `star_view.setup.web_module`, `star_view.setup.search_controller`) for
  better modularity and independent invocation.

## Unreleased

### Added

- `StarView.StreamRegistry` for opt-in per-tab SSE stream deduplication
  (ported from [dstar](https://github.com/RicoTrevisan/dstar), MIT).
- `StarView.start_stream/2` and `StarView.check_connection/1` on the facade.

### Changed

- `StarView.read_signals/1` now returns a bare signal map (like dstar); plugs
  should use `StarView.Signals.read/1` for `{:ok, map()} | {:error, term()}`.
- Removed `StarView.Actions.form/4` and Phoenix `post_form/put_form/patch_form`
  helpers in favor of the `csrf` signal + `StarView.Plug.RenameCsrfParam` flow.
