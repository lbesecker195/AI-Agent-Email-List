defmodule EmailProviderWeb.Router do
  use EmailProviderWeb, :router

  alias EmailProviderWeb.Plugs.{ApiAuth, LoadDomain}

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Authenticated, but not yet scoped to a domain.
  pipeline :authed do
    plug ApiAuth
  end

  pipeline :domain_scoped do
    plug ApiAuth
    plug LoadDomain
  end

  # The suppression endpoints are one controller; the type comes from here so
  # the three lists cannot drift apart.
  defp put_suppression_type(conn, type), do: Plug.Conn.put_private(conn, :suppression_type, type)

  pipeline :bounces do
    plug :put_suppression_type, "bounce"
  end

  pipeline :unsubscribes do
    plug :put_suppression_type, "unsubscribe"
  end

  pipeline :complaints do
    plug :put_suppression_type, "complaint"
  end

  # -- accounts ------------------------------------------------------------

  scope "/v1", EmailProviderWeb do
    pipe_through :api

    post "/accounts", AccountController, :create
    post "/accounts/login", AccountController, :login
  end

  scope "/v1", EmailProviderWeb do
    pipe_through [:api, :authed]

    get "/profile", ProfileController, :show
    post "/profile/refresh", ProfileController, :refresh
    get "/profile/signals", ProfileController, :signals

    get "/api-keys", AccountController, :index_keys
    post "/api-keys", AccountController, :create_key
    delete "/api-keys/:id", AccountController, :delete_key
  end

  scope "/v1/inbound", EmailProviderWeb do
    pipe_through [:api, :domain_scoped]

    post "/:domain", InboundController, :create
    get "/:domain/spam", InboundController, :spam
  end

  # -- address validation --------------------------------------------------

  scope "/v4", EmailProviderWeb do
    pipe_through [:api, :authed]

    get "/address/validate", ValidateController, :validate
  end

  # -- domains -------------------------------------------------------------
  #
  # These come before the "/v3/:domain/..." block: "domains" would otherwise be
  # captured as a domain name.

  scope "/v3/domains", EmailProviderWeb do
    pipe_through [:api, :authed]

    get "/", DomainController, :index
    post "/", DomainController, :create
  end

  scope "/v3/domains", EmailProviderWeb do
    pipe_through [:api, :domain_scoped]

    get "/:domain", DomainController, :show
    put "/:domain", DomainController, :update
    delete "/:domain", DomainController, :delete
    put "/:domain/verify", DomainController, :verify

    get "/:domain/messages/:key", MessageController, :show

    get "/:domain/webhooks", WebhookController, :index
    post "/:domain/webhooks", WebhookController, :create
    get "/:domain/webhooks/:id", WebhookController, :show
    delete "/:domain/webhooks/:id", WebhookController, :delete
  end

  # -- routes (account-wide, not per domain) -------------------------------

  scope "/v3/routes", EmailProviderWeb do
    pipe_through [:api, :authed]

    get "/", RouteController, :index
    post "/", RouteController, :create
    get "/:id", RouteController, :show
    put "/:id", RouteController, :update
    delete "/:id", RouteController, :delete
  end

  # -- per-domain sending and reporting ------------------------------------

  scope "/v3", EmailProviderWeb do
    pipe_through [:api, :domain_scoped]

    post "/:domain/messages", MessageController, :create
    post "/:domain/messages.mime", MessageController, :create_mime
    get "/:domain/messages", MessageController, :index

    get "/:domain/events", EventController, :index
    get "/:domain/stats/total", StatsController, :total
    get "/:domain/tags", StatsController, :tags
    get "/:domain/limits", StatsController, :limits

    get "/:domain/templates", TemplateController, :index
    post "/:domain/templates", TemplateController, :create
    get "/:domain/templates/:name", TemplateController, :show
    post "/:domain/templates/:name/versions", TemplateController, :create_version
    delete "/:domain/templates/:name", TemplateController, :delete
  end

  scope "/v3", EmailProviderWeb do
    pipe_through [:api, :domain_scoped, :bounces]

    get "/:domain/bounces", SuppressionController, :index
    post "/:domain/bounces", SuppressionController, :create
    get "/:domain/bounces/:address", SuppressionController, :show
    delete "/:domain/bounces/:address", SuppressionController, :delete
  end

  scope "/v3", EmailProviderWeb do
    pipe_through [:api, :domain_scoped, :unsubscribes]

    get "/:domain/unsubscribes", SuppressionController, :index
    post "/:domain/unsubscribes", SuppressionController, :create
    get "/:domain/unsubscribes/:address", SuppressionController, :show
    delete "/:domain/unsubscribes/:address", SuppressionController, :delete
  end

  scope "/v3", EmailProviderWeb do
    pipe_through [:api, :domain_scoped, :complaints]

    get "/:domain/complaints", SuppressionController, :index
    post "/:domain/complaints", SuppressionController, :create
    get "/:domain/complaints/:address", SuppressionController, :show
    delete "/:domain/complaints/:address", SuppressionController, :delete
  end

  scope "/", EmailProviderWeb do
    pipe_through :api

    get "/health", HealthController, :show

    # Agent-facing description of this API. Unauthenticated on purpose: an
    # agent has to be able to read how to get a key before it has one.
    get "/llms.txt", PageController, :llms
  end
end
