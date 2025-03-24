defmodule Exth.MixProject do
  use Mix.Project

  def project do
    [
      app: :exth,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      consolidate_protocols: Mix.env() != :test,

      # Docs
      name: "Exth",
      source_url: "https://github.com/joaop21/exth",
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Exth.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

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
      extras: ["README.md", "LICENSE"],
      nest_modules_by_prefix: [
        Exth.Provider,
        Exth.Rpc,
        Exth.Transport
      ]
    ]
  end
end
