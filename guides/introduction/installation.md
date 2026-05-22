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
- Configures HTTPS and `https://<hyphenated-otp-app>.test:4001` as the dev URL.
- Generates a dev certificate for `<hyphenated-otp-app>.test` and `localhost`.
- Provides `mix star_view.trust` to add the local host entry and trust the
  self-signed HTTPS certificate.
- Patches your router with `/search` and `/ds/:module/:event` routes.
- Generates a sample search controller.
- Provides `mix dev`, which delegates to `mix star_view.server`.

The trust step is optional and requires sudo privileges. It lets your browser
open `https://<hyphenated-otp-app>.test:4001` without certificate errors. Run it
directly after install:

```bash
mix star_view.trust
```

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
    {:star_view, "~> 0.3.14"}
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
