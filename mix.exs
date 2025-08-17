defmodule ExCache.MixProject do
  @moduledoc false
  use Mix.Project

  @name "ex_cache"
  @version "0.2.0"
  @repo_url "https://github.com/tt67wq/ex_cache"
  @description "A simple cache framework"

  def project do
    [
      app: :ex_cache,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      source_url: @repo_url,
      name: @name,
      package: package(),
      description: @description
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:styler, "~> 0.11", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.32", only: :dev, runtime: false},
      {:stream_data, "~> 1.0", only: [:test]}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @repo_url
      }
    ]
  end

  defp elixirc_paths(env) when env in ~w(test)a, do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
