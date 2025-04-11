defmodule Examples.MixProject do
  use Mix.Project

  def project do
    [
      app: :examples,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Examples.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:exth, path: "../"},
      {:mint, "~> 1.7"}
    ]
  end
end
