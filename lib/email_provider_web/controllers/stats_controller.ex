defmodule EmailProviderWeb.StatsController do
  use EmailProviderWeb, :controller

  plug EmailProviderWeb.Plugs.RequireScope, "events:read"

  alias EmailProvider.{Mail, Warmup}

  @doc "GET /v3/:domain/stats/total"
  def total(conn, _params) do
    json(conn, %{domain: conn.assigns.domain.name, totals: Mail.stats(conn.assigns.domain)})
  end

  @doc "GET /v3/:domain/tags"
  def tags(conn, _params), do: json(conn, %{items: Mail.tags(conn.assigns.domain)})

  @doc """
  GET /v3/:domain/limits

  What the domain may send right now, which rung of the warmup ladder it is on,
  and what graduates it.
  """
  def limits(conn, _params) do
    json(conn, %{domain: conn.assigns.domain.name, limits: Warmup.status(conn.assigns.domain)})
  end
end
