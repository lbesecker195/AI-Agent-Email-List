defmodule EmailProviderWeb.EventController do
  use EmailProviderWeb, :controller

  plug EmailProviderWeb.Plugs.RequireScope, "events:read"

  alias EmailProvider.Mail
  alias EmailProviderWeb.Views

  @doc "GET /v3/:domain/events"
  def index(conn, params) do
    events = Mail.list_events(conn.assigns.domain, params)
    json(conn, %{items: Enum.map(events, &Views.event/1)})
  end
end
