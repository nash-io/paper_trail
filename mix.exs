defmodule PaperTrail.Mixfile do
  use Mix.Project

  def project do
    [
      app: :paper_trail,
      version: "0.10.12",
      elixir: "~> 1.15",
      description: description(),
      build_embedded: Mix.env() == :prod,
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
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp deps do
    [
      {:ecto, ">= 3.10.0"},
      {:ecto_sql, ">= 3.10.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
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
      name: :paper_trail_copy,
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Izel Nakri"],
      licenses: ["MIT License"],
      links: %{
        "GitHub" => "https://github.com/izelnakri/paper_trail",
        "Docs" => "https://hexdocs.pm/paper_trail/PaperTrail.html"
      }
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
