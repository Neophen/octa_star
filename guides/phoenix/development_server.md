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

The installer prints the trust command to run after install:

```bash
mix star_view.trust --host my-app.test
```

That task adds `my-app.test` to `/etc/hosts`, runs `mkcert -install`, and writes
the certificate files configured above:

- `priv/cert/selfsigned.pem`
- `priv/cert/selfsigned_key.pem`

Install `mkcert` first:

```bash
brew install mkcert nss
```

The host is derived from the OTP app name with underscores converted to hyphens
because DNS hostnames cannot contain underscores.

Run `mix star_view.trust --host my-app.test` before `mix dev` so Phoenix can
find the configured certificate files. The task may prompt for sudo privileges
when updating `/etc/hosts` or installing mkcert's local certificate authority.

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
