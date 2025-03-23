defmodule Exth.MixProject do
  use Mix.Project

  def project do
    [
      app: :exth,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:jason, "~> 1.4"},
      {:mint, "~> 1.7", only: :dev},
      {:tesla, "~> 1.14"}
    ]
  end
end
