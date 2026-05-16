defmodule OctaStar.MixProject do
  use Mix.Project

  @version "0.2.0"
  @datastar_url "https://data-star.dev"

  def project() do
    [
      app: :octa_star,
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
      licenses: ["MIT"],
      links: %{"Datastar" => @datastar_url},
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE .formatter.exs)
    ]
  end

  defp docs() do
    [
      main: "readme",
      extras: ["README.md"],
      groups_for_modules: [
        Core: [
          OctaStar,
          OctaStar.ServerSentEventGenerator,
          OctaStar.Elements,
          OctaStar.Signals,
          OctaStar.Scripts,
          OctaStar.Actions,
          OctaStar.JSON,
          OctaStar.Utility.StreamRegistry
        ],
        Plugs: [
          OctaStar.Plug.Dispatch,
          OctaStar.Plug.RenameCsrfParam
        ],
        Phoenix: [
          OctaStar.StarView,
          OctaStar.Phoenix.Controller,
          OctaStar.Phoenix.Dispatch
        ]
      ]
    ]
  end
end
