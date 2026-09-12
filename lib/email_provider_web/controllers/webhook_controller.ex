defmodule EmailProviderWeb.WebhookController do
  use EmailProviderWeb, :controller

  alias EmailProviderWeb.Plugs.RequireScope

  plug RequireScope, "domains:read" when action in [:index, :show]
  plug RequireScope, "webhooks:write" when action in [:create, :delete]

  alias EmailProvider.Webhooks
  alias EmailProviderWeb.Views

  def index(conn, _params) do
    items = Webhooks.list(conn.assigns.domain)
    json(conn, %{webhooks: Map.new(items, &{&1.event_type, Views.webhook(&1)})})
  end

  def create(conn, params) do
    event_type = params["id"] || params["event_type"]
    url = params["url"]

    case Webhooks.upsert(conn.assigns.domain, event_type, url) do
      {:ok, webhook} ->
        conn
        |> put_status(:created)
        |> json(%{
          message: "Webhook has been created",
          webhook: Views.webhook(webhook),
          # Returned once; the receiver needs it to verify our HMAC.
          signing_key: webhook.signing_key
        })

      {:error, changeset} ->
        conn |> put_status(:bad_request) |> json(%{errors: Views.changeset_errors(changeset)})
    end
  end

  def show(conn, %{"id" => event_type}) do
    case Webhooks.get(conn.assigns.domain, event_type) do
      nil -> conn |> put_status(:not_found) |> json(%{message: "webhook not found"})
      webhook -> json(conn, %{webhook: Views.webhook(webhook)})
    end
  end

  def delete(conn, %{"id" => event_type}) do
    case Webhooks.get(conn.assigns.domain, event_type) do
      nil ->
        conn |> put_status(:not_found) |> json(%{message: "webhook not found"})

      webhook ->
        {:ok, _} = Webhooks.delete(webhook)
        json(conn, %{message: "Webhook has been deleted"})
    end
  end
end
