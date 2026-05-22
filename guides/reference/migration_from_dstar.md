# Migration from Dstar

StarView started as a Phoenix-oriented layer around the same Datastar SSE
workflow. These are the common Dstar-to-StarView name changes.

| Dstar | StarView |
| --- | --- |
| `Dstar` | `StarView` |
| `Dstar.Utility.StreamRegistry` | `StarView.StreamRegistry` |
| `$_dstar_module` | `$_star_view_module` |
| `Dstar.read_signals/1` | `StarView.read_signals/1` |
| Manual `Dstar.start/1` | Handled by `StarView.Dispatch` |
| Manual signal patching | Handled by `signal/3` |
