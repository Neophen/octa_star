# Changelog

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
