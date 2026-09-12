defmodule EmailProvider.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      EmailProviderWeb.Telemetry,
      EmailProvider.Repo,
      {DNSCluster, query: Application.get_env(:email_provider, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: EmailProvider.PubSub},
      # Webhook callbacks and route forwards run here, so a customer's slow
      # endpoint cannot hold up a send.
      {Task.Supervisor, name: EmailProvider.TaskSupervisor},
      # Polls the messages table and dispatches what is due.
      EmailProvider.Delivery.Queue,
      # Receives mail. Listeners that cannot bind are logged and skipped, so a
      # machine without permission for port 25 still serves the API and sends.
      EmailProvider.SMTP.Listener,
      # Start to serve requests, typically the last entry
      EmailProviderWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: EmailProvider.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    EmailProviderWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
