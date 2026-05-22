# Development Server

The Igniter installer configures Phoenix development HTTPS and stores the
browser URL in application config:

```elixir
config :my_app, MyAppWeb.Endpoint,
  url: [scheme: "https", host: "my_app.test", port: 4001],
  https: [
    port: 4001,
    cipher_suite: :strong,
    keyfile: "priv/cert/selfsigned_key.pem",
    certfile: "priv/cert/selfsigned.pem"
  ]

config :star_view, dev_url: "https://my_app.test:4001"
```

The installer also queues:

```bash
mix phx.gen.cert my_app.test localhost
```

That gives the generated Phoenix certificate a subject alternative name for the
local `.test` host used by `mix dev`.

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
