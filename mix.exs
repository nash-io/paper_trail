defmodule PaperTrail.Mixfile do
  use Mix.Project

  def project do
    [
      app: :paper_trail,
      version: "0.12.0",
      elixir: "~> 1.15",
      source_url: "https://github.com/nash-io/paper_trail",
      description: description(),
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      deps: deps(),
      dialyzer: [
        plt_core_path: "priv/plts/",
        plt_add_apps: [:mix, :ecto_sql]
      ]
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [
      extra_applications: [:logger, :ecto, :ecto_sql, :runtime_tools]
    ]
  end

  defp deps do
    [
      {:ecto, ">= 3.10.0"},
      {:ecto_sql, ">= 3.10.0"},
      {:ex_doc, "~> 0.31"},
      {:postgrex, ">= 0.0.0", only: [:dev, :test]},
      {:jason, ">= 1.2.0", only: [:dev, :test]},
      {:dialyxir, "~> 1.0", runtime: false, only: [:dev, :test]}
    ]
  end

  defp description do
    """
    Track and record all the changes in your database. Revert back to anytime in history.
    """
  end

  defp package do
    [
      name: :paper_trail_nash,
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Rafael Scheffer"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/nash-io/paper_trail",
        "Docs" => "https://hexdocs.pm/paper_trail_nash/PaperTrail.html"
      }
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
