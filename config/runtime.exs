import Config

# Load .env here as well as in config.exs, because in a release config.exs was
# evaluated when the release was built and this file is the one that runs on the
# machine.
#
# Written out inline rather than calling config/config_helpers.exs: a release
# ships this file and nothing else from config/, so requiring a sibling here
# fails at boot with `enoent` on a path inside the release. Production normally
# takes its settings from the systemd EnvironmentFile, so this matters only when
# somebody runs the release by hand — which is exactly when a confusing boot
# crash is least welcome.
case File.read(Path.join(File.cwd!(), ".env")) do
  {:error, _} ->
    # No file is the normal case in production, where systemd supplies the
    # environment. Not an error.
    :ok

  {:ok, contents} ->
    for line <- String.split(contents, ["\n", "\r\n"]),
        line = String.trim(line),
        line != "",
        not String.starts_with?(line, "#"),
        [key, value] <- [String.split(String.replace_prefix(line, "export ", ""), "=", parts: 2)],
        key = String.trim(key),
        key != "" do
      value = String.trim(value)

      unquoted =
        cond do
          String.length(value) > 1 and String.starts_with?(value, "\"") and
              String.ends_with?(value, "\"") ->
            String.slice(value, 1..-2//1)

          String.length(value) > 1 and String.starts_with?(value, "'") and
              String.ends_with?(value, "'") ->
            String.slice(value, 1..-2//1)

          true ->
            value
        end

      # The real environment wins. A file is a default, not an override.
      if is_nil(System.get_env(key)), do: System.put_env(key, unquoted)
    end
end

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/email_provider start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :email_provider, EmailProviderWeb.Endpoint, server: true
end

# Port 4000 is taken on the machines this runs on (and 4001-4003 are spoken
# for by other services), so the default is 4005. `PORT` overrides it.
config :email_provider, EmailProviderWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4005"))]

# Runtime configuration from the environment. Skipped under test, which pins
# these in config/test.exs — a stray environment variable on a developer's
# machine must not be able to point the suite at a live relay or a paid API.
if config_env() != :test do
  # -- Content screening -----------------------------------------------------
  config :email_provider, EmailProvider.Moderation,
    enabled: System.get_env("MODERATION_ENABLED", "true") == "true",
    api_key: System.get_env("OPENAI_API_KEY"),
    model: System.get_env("MODERATION_MODEL", "omni-moderation-latest"),
    on_error: if(System.get_env("MODERATION_ON_ERROR") == "block", do: :block, else: :allow)

  # -- Outbound --------------------------------------------------------------
  #
  # Three ways out, in order of how much was configured. A smarthost if one is
  # named, otherwise direct delivery to each recipient's MX if it is turned on,
  # otherwise the local file writer, which is the safe default: nothing leaves
  # the machine until somebody says it should.
  cond do
    System.get_env("SMTP_RELAY") ->
      config :email_provider, EmailProvider.Delivery.Sender,
        adapter: :smtp,
        relay: System.fetch_env!("SMTP_RELAY"),
        port: String.to_integer(System.get_env("SMTP_PORT", "587")),
        username: System.get_env("SMTP_USERNAME"),
        password: System.get_env("SMTP_PASSWORD"),
        tls: :always

    System.get_env("DIRECT_DELIVERY") == "true" ->
      config :email_provider, EmailProvider.Delivery.Sender,
        adapter: EmailProvider.Delivery.Sender.DirectMX,
        helo_name: System.get_env("SMTP_HOSTNAME", "ai.agentemaillist.com"),
        direct_port: String.to_integer(System.get_env("DIRECT_SMTP_PORT", "25")),
        timeout: String.to_integer(System.get_env("DIRECT_SMTP_TIMEOUT_MS", "30000"))

    true ->
      :ok
  end

  # -- Account profiles ------------------------------------------------------
  config :email_provider, EmailProvider.Profiles,
    enabled: System.get_env("PROFILES_ENABLED", "true") == "true",
    async: true,
    min_interval_seconds: String.to_integer(System.get_env("PROFILE_MIN_INTERVAL_SECONDS", "0"))

  config :email_provider, EmailProvider.Profiles.Generator,
    api_key: System.get_env("OPENAI_API_KEY"),
    model: System.get_env("PROFILE_MODEL", "gpt-4o-mini")

  config :email_provider, EmailProvider.Enrichment.CSuiteFinder,
    enabled: true,
    api_key: System.get_env("CSUITEFINDER_API_KEY"),
    base_url: System.get_env("CSUITEFINDER_BASE_URL", "https://csuitefinder.com")

  # -- What customers publish in DNS ----------------------------------------
  config :email_provider, EmailProvider.Domains,
    spf_host: System.get_env("SPF_HOST", "ai.agentemaillist.com"),
    mx_host: System.get_env("MX_HOST", "ai.agentemaillist.com")

  # -- Receiving and submission ----------------------------------------------
  config :email_provider, EmailProvider.SMTP.Listener,
    hostname: System.get_env("SMTP_HOSTNAME", "ai.agentemaillist.com"),
    receiving: [
      enabled: System.get_env("SMTP_RECEIVE_ENABLED", "false") == "true",
      port: String.to_integer(System.get_env("SMTP_RECEIVE_PORT", "25")),
      acceptors: String.to_integer(System.get_env("SMTP_ACCEPTORS", "10")),
      max_connections: String.to_integer(System.get_env("SMTP_MAX_CONNECTIONS", "200"))
    ],
    submission: [
      enabled: System.get_env("SMTP_SUBMISSION_ENABLED", "false") == "true",
      port: String.to_integer(System.get_env("SMTP_SUBMISSION_PORT", "587")),
      acceptors: String.to_integer(System.get_env("SMTP_ACCEPTORS", "5")),
      max_connections: String.to_integer(System.get_env("SMTP_MAX_CONNECTIONS", "100"))
    ]

  config :email_provider, EmailProvider.Delivery.Queue,
    enabled: System.get_env("DELIVERY_ENABLED", "true") == "true",
    interval: String.to_integer(System.get_env("DELIVERY_INTERVAL_MS", "5000")),
    batch_size: String.to_integer(System.get_env("DELIVERY_BATCH_SIZE", "200")),
    max_concurrency: String.to_integer(System.get_env("DELIVERY_CONCURRENCY", "10"))
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :email_provider, EmailProvider.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "ai.agentemaillist.com"

  bind_ip =
    case System.get_env("BIND_IP") do
      nil ->
        {127, 0, 0, 1}

      "" ->
        {127, 0, 0, 1}

      value ->
        value
        |> String.to_charlist()
        |> :inet.parse_address()
        |> case do
          {:ok, address} -> address
          {:error, _} -> raise "BIND_IP is not a valid IP address: #{inspect(value)}"
        end
    end

  config :email_provider, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  # llms.txt normally reports whatever host the agent actually reached, which is
  # right in nearly every case. Set this to pin it to one canonical URL, for
  # instance when several names point at the same service.
  if url = System.get_env("PUBLIC_BASE_URL") do
    config :email_provider, :public_base_url, url
  end

  config :email_provider, EmailProviderWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Loopback by default, because nginx sits in front and there is no reason
      # for the application port to be reachable from the internet directly.
      # Set BIND_IP=0.0.0.0 to expose it, which is only useful before a reverse
      # proxy is in place.
      ip: bind_ip
    ],
    secret_key_base: secret_key_base

  # Redirecting plaintext to HTTPS is right once TLS exists and a trap before
  # then: nginx on port 80 sets X-Forwarded-Proto: http, the app redirects to a
  # scheme nothing is listening on, and the result looks like a broken
  # application rather than a missing certificate. So this is opt-in. Turn it on
  # after certbot has issued, not before.
  if System.get_env("FORCE_SSL") == "true" do
    config :email_provider, EmailProviderWeb.Endpoint,
      force_ssl: [rewrite_on: [:x_forwarded_proto], hsts: true]
  end

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :email_provider, EmailProviderWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://plug.hexdocs.pm/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :email_provider, EmailProviderWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :email_provider, EmailProvider.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://swoosh.hexdocs.pm/Swoosh.html#module-installation for details.
end
