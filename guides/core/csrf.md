# CSRF

Most Datastar interactions do not need HTML forms. If you do use forms, put the
CSRF token in a `csrf` signal and rename it before Phoenix's CSRF protection
runs.

```elixir
plug StarView.Plug.RenameCsrfParam
plug :protect_from_forgery
```

`StarView.Plug.RenameCsrfParam` copies the Datastar signal value into the
request parameter Phoenix expects for CSRF validation.
