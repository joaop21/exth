defmodule Exth.MixProject do
  use Mix.Project

  @version "0.2.1"
  @source_url "https://github.com/joaop21/exth"

  def project do
    [
      app: :exth,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      consolidate_protocols: Mix.env() != :test,
      dialyzer: dialyzer(),

      # Package
      version: @version,
      description: description(),
      package: package(),

      # Docs
      name: "Exth",
      source_url: @source_url,
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
      {:mint, "~> 1.7", optional: true, only: :dev},
      # HTTP
      {:tesla, "~> 1.14"},

      # ex_check
      {:ex_check, "~> 0.16.0", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev], runtime: false}
    ]
  end

  defp description do
    """
    Exth is an Elixir client for interacting with EVM-compatible blockchain nodes
    via JSON-RPC. It provides a robust interface for making Ethereum RPC calls.
    """
  end

  defp package do
    [
      maintainers: ["João Silva"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      # The main page in the docs
      main: "readme",
      extras: [
        "README.md": [title: "Overview"],
        LICENSE: [title: "License"],
        "CHANGELOG.md": [title: "Changelog"]
      ],
      nest_modules_by_prefix: [
        Exth.Provider,
        Exth.Rpc,
        Exth.Transport
      ]
    ]
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/project.plt"}
    ]
  end
end
