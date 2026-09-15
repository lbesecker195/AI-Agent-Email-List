defmodule EmailProviderWeb.Router do
  use EmailProviderWeb, :router

  alias EmailProviderWeb.Plugs.{ApiAuth, LoadDomain}

  # Usage reporting. In the pipeline rather than the endpoint so it covers the
  # API and nothing else: the console, the articles and the health check are
  # not adoption signals and would drown the ones that are.
  pipeline :analytics do
    plug EmailProviderWeb.Plugs.Analytics
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # The landing page and llms.txt answer to people and to programs, so they
  # cannot sit behind a json-only pipeline. A browser usually sends `*/*` too and
  # would scrape through by accident, but a client asking for exactly text/html
  # would get a 406 from the pipeline before reaching the controller.
  # Pages a person uses: a session cookie, CSRF protection on every form, and the
  # security headers a JSON API has no use for.
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug EmailProviderWeb.Plugs.BrowserAuth
    plug :put_root_layout, false
  end

  pipeline :public do
    plug :accepts, ["html", "json", "txt"]
  end

  # Guarded by a shared token rather than an API key: these figures span every
  # account, so no customer credential should ever open them.
  # No `accepts` filter. A Streamable HTTP client opens a stream with
  # `Accept: text/event-stream`, which a json-only pipeline rejects with 406
  # before the controller can answer the 405 the transport spec asks for.
  pipeline :mcp do
    plug :fetch_query_params
  end

  pipeline :admin do
    plug :accepts, ["json"]
    plug EmailProviderWeb.Plugs.AdminAuth
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

  # Signup is the one endpoint that hands out credentials to anyone, so it is
  # the one that has to be limited by address rather than by account.
  pipeline :signup do
    plug EmailProviderWeb.Plugs.SignupLimit
  end

  pipeline :signup_html do
    plug EmailProviderWeb.Plugs.SignupLimit, on_limit: :html
  end

  scope "/v1", EmailProviderWeb do
    pipe_through [:analytics, :api, :signup]

    post "/accounts", AccountController, :create
  end

  scope "/v1", EmailProviderWeb do
    pipe_through [:analytics, :api]

    post "/accounts/login", AccountController, :login
  end

  scope "/v1", EmailProviderWeb do
    pipe_through [:analytics, :api, :authed]

    get "/profile", ProfileController, :show
    post "/profile/refresh", ProfileController, :refresh
    get "/profile/signals", ProfileController, :signals

    get "/api-keys", AccountController, :index_keys
    post "/api-keys", AccountController, :create_key
    delete "/api-keys/:id", AccountController, :delete_key
  end

  scope "/v1/inbound", EmailProviderWeb do
    pipe_through [:analytics, :api, :domain_scoped]

    post "/:domain", InboundController, :create
    get "/:domain/spam", InboundController, :spam
  end

  # -- address validation --------------------------------------------------

  scope "/v4", EmailProviderWeb do
    pipe_through [:analytics, :api, :authed]

    get "/address/validate", ValidateController, :validate
  end

  # -- domains -------------------------------------------------------------
  #
  # These come before the "/v3/:domain/..." block: "domains" would otherwise be
  # captured as a domain name.

  scope "/v3/domains", EmailProviderWeb do
    pipe_through [:analytics, :api, :authed]

    get "/", DomainController, :index
    post "/", DomainController, :create
  end

  scope "/v3/domains", EmailProviderWeb do
    pipe_through [:analytics, :api, :domain_scoped]

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
    pipe_through [:analytics, :api, :authed]

    get "/", RouteController, :index
    post "/", RouteController, :create
    get "/:id", RouteController, :show
    put "/:id", RouteController, :update
    delete "/:id", RouteController, :delete
  end

  # -- per-domain sending and reporting ------------------------------------

  scope "/v3", EmailProviderWeb do
    pipe_through [:analytics, :api, :domain_scoped]

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
    pipe_through [:analytics, :api, :domain_scoped, :bounces]

    get "/:domain/bounces", SuppressionController, :index
    post "/:domain/bounces", SuppressionController, :create
    get "/:domain/bounces/:address", SuppressionController, :show
    delete "/:domain/bounces/:address", SuppressionController, :delete
  end

  scope "/v3", EmailProviderWeb do
    pipe_through [:analytics, :api, :domain_scoped, :unsubscribes]

    get "/:domain/unsubscribes", SuppressionController, :index
    post "/:domain/unsubscribes", SuppressionController, :create
    get "/:domain/unsubscribes/:address", SuppressionController, :show
    delete "/:domain/unsubscribes/:address", SuppressionController, :delete
  end

  scope "/v3", EmailProviderWeb do
    pipe_through [:analytics, :api, :domain_scoped, :complaints]

    get "/:domain/complaints", SuppressionController, :index
    post "/:domain/complaints", SuppressionController, :create
    get "/:domain/complaints/:address", SuppressionController, :show
    delete "/:domain/complaints/:address", SuppressionController, :delete
  end

  # The dashboard shell is public and empty; the figures behind it are not. That
  # split is deliberate: landing on /admin uninvited shows a token prompt rather
  # than a count of anything.
  scope "/admin", EmailProviderWeb do
    pipe_through :public

    get "/", AdminController, :index
  end

  scope "/admin", EmailProviderWeb do
    pipe_through :admin

    get "/stats", AdminController, :stats
  end

  # -- the browser console -------------------------------------------------

  scope "/", EmailProviderWeb do
    pipe_through [:browser, :signup_html]

    post "/signup", RegistrationController, :create
  end

  scope "/", EmailProviderWeb do
    pipe_through :browser

    get "/signup", RegistrationController, :new
    get "/login", SessionController, :new
    post "/login", SessionController, :create
    post "/logout", SessionController, :delete

    get "/domains", ConsoleController, :domains
    post "/domains", ConsoleController, :create_domain
    get "/domains/:name", ConsoleController, :domain
    post "/domains/:name/verify", ConsoleController, :verify_domain

    get "/send", ConsoleController, :send_form
    post "/send", ConsoleController, :send_message

    get "/messages", ConsoleController, :messages

    get "/account", ConsoleController, :account
    post "/account/keys", ConsoleController, :create_key
    post "/account/keys/:id/revoke", ConsoleController, :revoke_key
  end

  scope "/", EmailProviderWeb do
    pipe_through :public

    get "/", PageController, :index
    get "/app", PageController, :app

    # Agent-facing description of this API. Unauthenticated on purpose: an
    # agent has to be able to read how to get a key before it has one.
    get "/llms.txt", PageController, :llms
    get "/sitemap.xml", PageController, :sitemap
    get "/.well-known/mcp-registry-auth", PageController, :mcp_registry_auth
  end

  scope "/", EmailProviderWeb do
    pipe_through [:analytics, :api]

    # Reported like everything else, though it is the one endpoint whose volume
    # says nothing about adoption: the deploy script and any monitoring poll it.
    # Filter it out in the dashboard by controller, rather than here, so "every
    # API call is an event" stays true without exception.
    get "/health", HealthController, :show
  end

  # Model Context Protocol. Authentication is handled inside the controller
  # rather than by a plug, because create_account has to work for an agent that
  # has no key yet.
  scope "/", EmailProviderWeb do
    pipe_through :mcp

    post "/mcp", MCPController, :rpc
    get "/mcp", MCPController, :describe
  end

  # Articles live at the root so the slug is the keyword and nothing else.
  #
  # This must be the last route in the file. A bare ":slug" matches any single
  # segment, so anything declared below it is unreachable — which is exactly
  # what happened to /health the first time, and a 404 there would have taken
  # the deploy script's own health check down with it.
  scope "/", EmailProviderWeb do
    pipe_through :public

    get "/:slug", PageController, :article
  end
end
