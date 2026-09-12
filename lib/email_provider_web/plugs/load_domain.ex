defmodule EmailProviderWeb.Plugs.LoadDomain do
  @moduledoc """
  Resolve the `:domain` path segment to a domain the caller owns.

  An unknown domain and someone else's domain both come back 404. Answering 403
  for a domain that exists but is not yours would turn this endpoint into a way
  to enumerate other customers' domains.
  """

  import Plug.Conn

  alias EmailProvider.Domains

  def init(opts), do: opts

  def call(%{params: %{"domain" => name}, assigns: %{current_user: user}} = conn, _opts) do
    case Domains.get_user_domain(user, name) do
      nil ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(404, Jason.encode!(%{message: "domain not found"}))
        |> halt()

      domain ->
        assign(conn, :domain, domain)
    end
  end

  def call(conn, _opts) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(400, Jason.encode!(%{message: "domain is required"}))
    |> halt()
  end
end
