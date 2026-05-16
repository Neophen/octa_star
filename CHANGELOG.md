# Changelog

## v0.2.0

### Changed

- `mix igniter.install octa_star` delegates to composable setup subtasks
  instead of duplicating logic, removing ~270 lines of duplicated code.

## v0.1.2

### Fixed

- `mix igniter.install octa_star` now correctly detects Phoenix projects and
  applies all patches (web module, HTTPS config, routes, demo controller).

### Changed

- Installer split into composable subtasks
  (`octa_star.setup.streaming`, `octa_star.setup.datastar`,
  `octa_star.setup.web_module`, `octa_star.setup.demo_controller`) for
  better modularity and independent invocation.

## Unreleased

### Added

- `OctaStar.Utility.StreamRegistry` for opt-in per-tab SSE stream deduplication
  (ported from [dstar](https://github.com/RicoTrevisan/dstar), MIT).
- `OctaStar.start_stream/2` and `OctaStar.check_connection/1` on the facade.

### Changed

- `OctaStar.read_signals/1` now returns a bare signal map (like dstar); plugs
  should use `OctaStar.Signals.read/1` for `{:ok, map()} | {:error, term()}`.
- Removed `OctaStar.Actions.form/4` and Phoenix `post_form/put_form/patch_form`
  helpers in favor of the `csrf` signal + `OctaStar.Plug.RenameCsrfParam` flow.
