import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :email_provider,
       EmailProvider.Repo,
       [
         pool: Ecto.Adapters.SQL.Sandbox,
         pool_size: System.schedulers_online() * 2
       ] ++
         EmailProvider.ConfigHelpers.repo_connection(
           "email_provider_test#{System.get_env("MIX_TEST_PARTITION")}"
         )

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :email_provider, EmailProviderWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "TQXmVqMtwibcGGl+XNLSt5jKriYg8ZfWju7eevDDyL0PAC0wiWlkdWJ/2P9U8/iB",
  server: false

# In test we don't send emails
config :email_provider, EmailProvider.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Never reach the network in test: no live moderation or spam-filter call, no
# dispatch loop waking up underneath a test, and a sender that writes to a
# temp directory.
#
# Explicit `enabled: false` rather than relying on the key being unset: a
# developer's shell (or CI secrets) may well export a real ANTHROPIC_API_KEY
# or OPENAI_API_KEY for other tools, and without this the test suite would
# make live, billed calls to both APIs on every message sent or received.
config :email_provider, EmailProvider.Moderation, enabled: false
config :email_provider, EmailProvider.SpamFilter, enabled: false

config :email_provider, EmailProvider.Delivery.Queue, enabled: false, max_concurrency: 1

config :email_provider, EmailProvider.SMTP.Listener,
  hostname: "mx.test.local",
  receiving: [enabled: false],
  submission: [enabled: false]

config :email_provider, EmailProvider.Delivery.Sender,
  adapter: :local,
  dir: Path.join(System.tmp_dir!(), "email_provider_test_mail")

config :email_provider, EmailProvider.Domains,
  spf_host: "mail.test.local",
  mx_host: "mx.test.local"

# Profiles run inline in test so an assertion does not race a task, and the
# deterministic generator is pinned so no test can reach a model.
config :email_provider, EmailProvider.Profiles,
  enabled: true,
  async: false,
  min_interval_seconds: 0

config :email_provider, EmailProvider.Profiles.Generator, adapter: :structured

config :email_provider, EmailProvider.Enrichment.CSuiteFinder, enabled: false

# The limiter's table is global while tests are not, so the address-keyed limits
# are lifted here rather than made to interleave. The tests that exercise them
# set their own figures and reset the table themselves.
config :email_provider, EmailProviderWeb.Plugs.SignupLimit,
  per_hour: 1_000_000,
  per_day: 1_000_000

config :email_provider, EmailProviderWeb.Plugs.ApiAuth,
  requests_per_minute: 1_000_000,
  failures_per_minute: 1_000_000

# No reporting from the suite. The tests that exercise it set their own uid and
# a plug that answers in-process.
config :email_provider, EmailProvider.Analytics, uid: nil
