defmodule EmailProviderWeb.TemplateController do
  use EmailProviderWeb, :controller

  alias EmailProviderWeb.Plugs.RequireScope

  plug RequireScope, "domains:read" when action in [:index, :show]
  plug RequireScope, "templates:write" when action in [:create, :create_version, :delete]

  alias EmailProvider.Templates
  alias EmailProviderWeb.Views

  def index(conn, _params) do
    items = Templates.list(conn.assigns.domain)
    json(conn, %{items: Enum.map(items, &Views.template/1)})
  end

  def create(conn, params) do
    case Templates.create(conn.assigns.domain, params) do
      {:ok, template} ->
        conn
        |> put_status(:created)
        |> json(%{message: "template has been stored", template: Views.template(template)})

      {:error, changeset} ->
        conn |> put_status(:bad_request) |> json(%{errors: Views.changeset_errors(changeset)})
    end
  end

  def show(conn, %{"name" => name}) do
    case Templates.get(conn.assigns.domain, name) do
      nil -> conn |> put_status(:not_found) |> json(%{message: "template not found"})
      template -> json(conn, %{template: Views.template(template)})
    end
  end

  @doc "POST /v3/:domain/templates/:name/versions"
  def create_version(conn, %{"name" => name} = params) do
    with %Templates.Template{} = template <- Templates.get(conn.assigns.domain, name),
         {:ok, version} <- Templates.create_version(template, params) do
      conn
      |> put_status(:created)
      |> json(%{message: "new version stored", version: Views.template_version(version)})
    else
      nil ->
        conn |> put_status(:not_found) |> json(%{message: "template not found"})

      {:error, changeset} ->
        conn |> put_status(:bad_request) |> json(%{errors: Views.changeset_errors(changeset)})
    end
  end

  def delete(conn, %{"name" => name}) do
    case Templates.get(conn.assigns.domain, name) do
      nil ->
        conn |> put_status(:not_found) |> json(%{message: "template not found"})

      template ->
        {:ok, _} = Templates.delete(template)
        json(conn, %{message: "template has been deleted"})
    end
  end
end
