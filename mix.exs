defmodule Exth.MixProject do
  use Mix.Project

  def project do
    [
      app: :exth,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      name: "Exth",
      source_url: "https://github.com/joaop21/exth",
      # homepage_url: "http://YOUR_PROJECT_HOMEPAGE",
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Exth.Application, []}
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:jason, "~> 1.4"},
      {:mint, "~> 1.7", only: :dev},
      {:tesla, "~> 1.14"}
    ]
  end

  defp docs do
    [
      # The main page in the docs
      main: "readme",
      # logo: "path/to/logo.png",
      extras: ["README.md", "LICENSE"]
    ]
  end
end
