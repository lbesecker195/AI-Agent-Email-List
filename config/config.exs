# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Credentials and other settings for this machine, if there is a .env here.
# Loaded first so every config file below sees them. A real environment
# variable always wins over the file. See config/config_helpers.exs.
Code.require_file("config_helpers.exs", __DIR__)
EmailProvider.ConfigHelpers.load_dotenv!()

config :email_provider,
  ecto_repos: [EmailProvider.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configure the endpoint
config :email_provider, EmailProviderWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: EmailProviderWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: EmailProvider.PubSub,
  live_view: [signing_salt: "zx+ingLi"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :email_provider, EmailProvider.Mailer, adapter: Swoosh.Adapters.Local

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Public half of the key that proves domain ownership to the MCP registry.
# Public by definition: it is served at /.well-known/mcp-registry-auth. The
# private half lives only with the operator.
config :email_provider,
       :mcp_registry_public_key,
       "6ftFeaKhoTxsxhftOWq320TSptPPeGP5XFEyTnoCgfA="

# -- Warmup ------------------------------------------------------------------
#
# Each stage names a daily cap and the condition that graduates it. The first
# stage whose condition is not yet met is the one in force.
#
# `{:sending_days, n}` counts days the domain actually sent on, not days since
# it was created.
#
# `{:stage_volume, n}` counts messages sent *while on that rung*. Each rung's
# number is its own allowance, so a domain leaves the 20/day rung after 1,000
# messages at 20/day and then leaves the 100/day rung after a further 1,000.
# Use `{:lifetime_sent, n}` instead for a rung that should graduate at an
# absolute lifetime total.
config :email_provider, EmailProvider.Warmup,
  stages: [
    %{daily_limit: 10, until: {:sending_days, 5}},
    %{daily_limit: 20, until: {:stage_volume, 1_000}},
    %{daily_limit: 100, until: {:stage_volume, 1_000}},
    %{daily_limit: 1_000, until: {:stage_volume, 10_000}},
    %{daily_limit: :unlimited, until: :never}
  ]

# -- Content screening -------------------------------------------------------
#
# OpenAI's moderation endpoint is free to call. `on_error: :allow` means a
# moderation outage does not stop the service; messages that went unscreened
# are recorded as such. Set `:block` to fail closed instead.
config :email_provider, EmailProvider.Moderation,
  enabled: true,
  model: "omni-moderation-latest",
  on_error: :allow

# Spam — a second, independent screener alongside the one above. See
# EmailProvider.SpamFilter's moduledoc for why moderation alone does not
# catch it.
config :email_provider, EmailProvider.SpamFilter,
  enabled: true,
  model: "claude-haiku-4-5-20251001",
  on_error: :allow

# -- Account profiles ---------------------------------------------------------
#
# A rolling ~200 word description of each account holder, rewritten from their
# mail activity plus a CSuiteFinder enrichment lookup.
#
# `min_interval_seconds: 0` means one rewrite per message, which is what was
# asked for and, with the model adapter, one model call per message. Raise it
# to coalesce refreshes for busy accounts.
config :email_provider, EmailProvider.Profiles,
  enabled: true,
  async: true,
  min_interval_seconds: 0

# Adapter is inferred when unset: the model if there is a key for it, the
# deterministic builder otherwise.
config :email_provider, EmailProvider.Profiles.Generator, model: "gpt-4o-mini"

config :email_provider, EmailProvider.Enrichment.CSuiteFinder,
  enabled: true,
  base_url: "https://csuitefinder.com"

# -- Delivery ----------------------------------------------------------------
config :email_provider, EmailProvider.Delivery.Sender, adapter: :local, dir: "priv/local_mail"

config :email_provider, EmailProvider.Delivery.Queue,
  enabled: true,
  interval: 5_000,
  batch_size: 50

# The hostnames customers are told to publish in SPF and MX.
# One hostname for all three roles because ai.agentemaillist.com is the name
# that resolves to the box today. Separate mail./mx. names are conventional and
# only an A record away; change these and the DNS together, not one of them.
config :email_provider, EmailProvider.Domains,
  spf_host: "ai.agentemaillist.com",
  mx_host: "ai.agentemaillist.com"

# -- Limits ------------------------------------------------------------------
#
# The shape of all of these: generous enough that nobody building something real
# ever meets them, tight enough that the cheap version of abuse does.
#
# What actually stops a spammer here is not any single number below. It is that
# sending requires a verified domain, so mail cannot leave this service until
# somebody has published DNS they control; that every outbound message is
# screened; and that refusals are now counted against the account that caused
# them. These are the limits on everything that happens before that point.

# How many accounts one address may open. The hourly figure is loose on purpose
# — a developer wiring this up will make several while getting it working, and
# an agent that failed and retried should not be locked out. The daily one is
# the limit that means anything.
config :email_provider, EmailProviderWeb.Plugs.SignupLimit, per_hour: 5, per_day: 20

# A pace limit, not a volume limit: how much an account may *send* is settled
# elsewhere. 600/min is roughly ten calls a second, far above any real use and
# far below what it takes to hurt the box.
config :email_provider, EmailProviderWeb.Plugs.ApiAuth,
  requests_per_minute: 600,
  failures_per_minute: 30

# Domains per account, by tier, and how much screening an account may fail
# before it stops sending. A verified domain is the expensive thing to fake, so
# it is what the generosity is attached to.
config :email_provider, EmailProvider.Reputation,
  domains_unverified: 3,
  domains_verified: 50,
  refusals_before_throttle: 8,
  refusals_before_suspension: 25

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
