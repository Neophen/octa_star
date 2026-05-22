defmodule StarView.MixProject do
  use Mix.Project

  @version "0.3.7"
  @datastar_url "https://data-star.dev"

  def project() do
    [
      app: :star_view,
      version: @version,
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Elixir SDK for Datastar SSE events with Plug and Phoenix helpers.",
      package: package(),
      docs: docs()
    ]
  end

  def application() do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps() do
    [
      {:quokka, "~> 2.12", only: [:dev, :test], runtime: false},
      {:plug, "~> 1.14"},
      {:igniter, "~> 0.6", optional: true},
      {:phoenix, "~> 1.7", optional: true},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end

  defp package() do
    [
      name: "star_view",
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/Neophen/star_view",
        "Datastar" => @datastar_url
      },
      files: ~w(lib priv guides mix.exs README.md CHANGELOG.md LICENSE .formatter.exs)
    ]
  end

  defp docs() do
    [
      main: "readme",
      extras: ["README.md", "guides/comparison/liveview_vs_star_view.md"],
      groups_for_modules: [
        Core: [
          StarView,
          StarView.SSE,
          StarView.Elements,
          StarView.Signals,
          StarView.Scripts,
          StarView.Actions,
          StarView.JSON,
          StarView.StreamRegistry
        ],
        Plugs: [
          StarView.Plug.Dispatch,
          StarView.Plug.RenameCsrfParam
        ],
        Phoenix: [
          StarView.Controller,
          StarView.Dispatch
        ]
      ]
    ]
  end
end
