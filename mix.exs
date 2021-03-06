defmodule Ode.Mixfile do
  use Mix.Project

  def project do
    [app: :ode,
     version: "0.1.0",
     elixir: "~> 1.3",
     escript: [main_module: Ode],
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     elixirc_paths: elixirc_paths(Mix.env)
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "web", "test/support"]
  defp elixirc_paths(_), do: ["lib", "web"]

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger,
                    :httpoison,
                    :poison,
                    :postgrex,
                    :ecto,
                    :tzdata,
                    :ex_machina
                   ],
     mod: {Ode, []}
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:httpoison, "~> 0.9.0"},
      {:poison, "~> 1.0"},
      {:ecto, "~> 2.0.0"},
      {:postgrex, ">= 0.0.0"},
      {:timex, "~> 3.0"},
      {:tzdata, "~> 0.1.8", override: true},
      {:ex_machina, "~> 1.0"}
    ]
  end
end
