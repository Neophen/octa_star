# Development Server

The Igniter installer configures Phoenix development HTTPS and stores the
browser URL in application config:

```elixir
config :my_app, MyAppWeb.Endpoint,
  url: [scheme: "https", host: "my-app.test", port: 4001],
  https: [
    port: 4001,
    cipher_suite: :strong,
    keyfile: "priv/cert/selfsigned_key.pem",
    certfile: "priv/cert/selfsigned.pem"
  ]

config :my_app, star_view: [dev_url: "https://my-app.test:4001"]
```

The installer also queues certificate generation:

```bash
mix phx.gen.cert my-app.test localhost
```

That gives the generated Phoenix certificate a subject alternative name for the
local `.test` host used by `mix dev`. The host is derived from the OTP app name
with underscores converted to hyphens because DNS hostnames cannot contain
underscores.

The installer then offers to run:

```bash
mix star_view.trust --host my-app.test
```

That optional task asks for confirmation, then adds `my-app.test` to
`/etc/hosts` and trusts `priv/cert/selfsigned.pem`. It requires sudo
privileges, so your terminal may prompt for your password. Automatic
certificate trust is currently implemented for macOS.

If you skip the installer prompt, run it later:

```bash
mix star_view.trust
```

Restart `mix dev` if it was already running, and restart your browser after
changing certificate trust.

## Starting Phoenix

Run:

```bash
mix dev
```

`mix dev` delegates to:

```bash
mix star_view.server
```

`mix star_view.server` starts `mix phx.server --open`, so Phoenix opens the
configured endpoint URL. Pass `--no-open` when you want to start the server
without opening a browser:

```bash
mix star_view.server --no-open
```
