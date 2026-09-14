defmodule EmailProviderWeb.AdminController do
  use EmailProviderWeb, :controller

  alias EmailProvider.Admin

  @doc """
  GET /admin

  The dashboard shell, served without a token. It carries no figures of its own
  and fetches them separately, so landing on this URL uninvited shows an empty
  page rather than a count of anything.
  """
  def index(conn, _params) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, EmailProviderWeb.AdminHTML.index())
  end

  @doc """
  GET /admin/stats

  Every figure, behind the admin token. This is the endpoint that needs
  guarding, and it is the one the page calls.
  """
  def stats(conn, _params), do: json(conn, Admin.overview())
end
