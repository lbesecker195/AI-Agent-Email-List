defmodule EmailProviderWeb.DomainController do
  use EmailProviderWeb, :controller

  alias EmailProviderWeb.Plugs.RequireScope

  plug RequireScope, "domains:read" when action in [:index, :show]
  plug RequireScope, "domains:write" when action in [:create, :update, :delete, :verify]

  alias EmailProvider.Domains
  alias EmailProviderWeb.Views

  @doc "GET /v3/domains"
  def index(conn, _params) do
    domains = Domains.list_domains(conn.assigns.current_user)

    json(conn, %{
      total_count: length(domains),
      items: Enum.map(domains, &Views.domain(&1, with_records: false))
    })
  end

  @doc "POST /v3/domains"
  def create(conn, params) do
    case Domains.create_domain(conn.assigns.current_user, params) do
      {:ok, domain, smtp_password} ->
        conn
        |> put_status(:created)
        |> json(%{
          message: "Domain has been created",
          domain: Views.domain(domain),
          # Shown once. We store only a hash of it.
          smtp_password: smtp_password,
          next_step:
            "Publish the records in sending_dns_records, then PUT /v3/domains/#{domain.name}/verify"
        })

      {:error, :domain_limit, message} ->
        conn |> put_status(:forbidden) |> json(%{message: message})

      {:error, changeset} ->
        conn |> put_status(:bad_request) |> json(%{errors: Views.changeset_errors(changeset)})
    end
  end

  @doc "GET /v3/domains/:domain"
  def show(conn, _params), do: json(conn, %{domain: Views.domain(conn.assigns.domain)})

  @doc "PUT /v3/domains/:domain"
  def update(conn, params) do
    case Domains.update_domain(conn.assigns.domain, params) do
      {:ok, domain} ->
        json(conn, %{domain: Views.domain(domain)})

      {:error, changeset} ->
        conn |> put_status(:bad_request) |> json(%{errors: Views.changeset_errors(changeset)})
    end
  end

  @doc "DELETE /v3/domains/:domain"
  def delete(conn, _params) do
    {:ok, _} = Domains.delete_domain(conn.assigns.domain)
    json(conn, %{message: "domain has been deleted"})
  end

  @doc """
  PUT /v3/domains/:domain/verify

  Re-reads DNS now rather than trusting a cached result: the caller has almost
  always just changed a record and wants to know whether it took.
  """
  def verify(conn, _params) do
    {:ok, domain} = Domains.verify_domain(conn.assigns.domain)

    status = if domain.state == "active", do: :ok, else: :accepted

    conn
    |> put_status(status)
    |> json(%{
      domain: Views.domain(domain),
      message:
        if(domain.state == "active",
          do: "Domain DNS records have been verified",
          else: "Domain is missing required DNS records"
        )
    })
  end
end
