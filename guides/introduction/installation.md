# Installation

StarView can be installed with Igniter, or wired manually in a Phoenix project.

## Quick Install

```bash
mix igniter.install star_view
```

The installer sets up the recommended Phoenix development flow:

- Adds the dependency.
- Adds `StarView.StreamRegistry` to your supervision tree.
- Adds a dedicated `star_view` section to your web module after `controller`.
- Configures HTTPS and `https://<otp_app>.test:4001` as the dev URL.
- Generates a dev certificate for `<otp_app>.test` and `localhost`.
- Patches your router with `/search` and `/ds/:module/:event` routes.
- Generates a sample search controller.
- Provides `mix dev`, which delegates to `mix star_view.server`.

Skip parts you do not want:

```bash
mix igniter.install star_view --no-stream-dedup --no-https --no-example
```

| Option | What it does |
| --- | --- |
| `--no-stream-dedup` | Skips adding `StarView.StreamRegistry` to your supervision tree. |
| `--no-https` | Skips StarView dev URL and HTTPS configuration. |
| `--no-example` | Skips generating the sample controller/handler. |

## Manual Dependency

```elixir
def deps do
  [
    {:star_view, "~> 0.3.10"}
  ]
end
```

Add `StarView.StreamRegistry` to your supervision tree if you want per-tab
stream deduplication:

```elixir
children = [
  StarView.StreamRegistry,
  # ...
]
```

The remaining manual Phoenix setup is covered in the Phoenix setup guide.
