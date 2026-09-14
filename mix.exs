defmodule EmailProvider.MixProject do
  use Mix.Project

  def project do
    [
      app: :email_provider,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      description: description(),
      package: package(),
      source_url: "https://github.com/lbesecker195/AI-Agent-Email-List",
      listeners: [Phoenix.CodeReloader]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {EmailProvider.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  defp description do
    "An email sending and receiving service: accounts, customer domains with " <>
      "their own DKIM keys, a Mailgun-shaped REST API, automatic sending warmup, " <>
      "and content screening in both directions."
  end

  defp package do
    [
      maintainers: ["Logan Besecker <me@LoganBesecker.com>", "<lbesecker195@gmail.com>"],
      links: %{
        "GitHub" => "https://github.com/lbesecker195/AI-Agent-Email-List",
        "Service" => "https://ai.agentemaillist.com",
        "Agent docs" => "https://ai.agentemaillist.com/llms.txt"
      }
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.8.13"},
      {:phoenix_ecto, "~> 4.5"},
      # HEEx templates for the browser console. Worth a dependency for the
      # automatic escaping alone: these pages render addresses, domain names and
      # subject lines, all of which are attacker-controlled.
      {:phoenix_html, "~> 4.1"},
      # For Phoenix.Component and the ~H sigil. No LiveView pages here and no
      # socket: these are plain server-rendered forms. The dependency is what
      # HEEx itself lives in.
      {:phoenix_live_view, "~> 1.0"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:swoosh, "~> 1.16"},
      {:req, "~> 0.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},
      # Password hashing for the account holder's own login.
      {:bcrypt_elixir, "~> 3.0"},
      # SMTP client for outbound relay, and :mimemail for parsing inbound MIME.
      {:gen_smtp, "~> 1.2"},
      # Charset conversion for inbound MIME. Without it gen_smtp's mimemail
      # silently drops every byte above 127, which would quietly mangle any
      # message that is not plain ASCII.
      {:iconv, "~> 1.0"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      # For a box that is running other things. `setup` boots the whole
      # application to execute seeds.exs, which opens a connection pool and
      # starts the delivery queue; this does neither, and skips seeds, which is
      # empty anyway. Pair it with bin/setup-server to cap the build's memory.
      "setup.server": ["deps.get", "ecto.create --quiet", "ecto.migrate"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end
