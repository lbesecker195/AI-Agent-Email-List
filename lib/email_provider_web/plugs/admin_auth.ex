defmodule EmailProviderWeb.Plugs.AdminAuth do
  @moduledoc """
  Guards the admin dashboard with a single shared token.

  Three deliberate choices, matching the CSuiteFinder deployment on the same
  machine so there is one pattern to remember rather than two.

  The token is compared with a constant-time equality check, so the comparison
  cannot be used as an oracle to recover it a byte at a time.

  If no token is configured the dashboard is **closed**, not open. The failure
  mode of a missing environment variable has to be "nobody can see the figures",
  never "everybody can".

  And the token may arrive as `Authorization: Bearer`, `X-Admin-Token`, or a
  `token` query parameter. The last exists so the page can be opened from a
  browser address bar; it is also the one that ends up in shell history and
  proxy logs, so the dashboard itself uses the header.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case configured_token() do
      nil ->
        refuse(conn, 503, "Admin dashboard is disabled. Set ADMIN_TOKEN to enable it.")

      expected ->
        if valid?(conn, expected) do
          conn
        else
          refuse(conn, 401, "Invalid or missing admin token.")
        end
    end
  end

  defp valid?(conn, expected) do
    case presented(conn) do
      nil -> false
      token -> Plug.Crypto.secure_compare(token, expected)
    end
  end

  defp presented(conn) do
    header =
      case get_req_header(conn, "authorization") do
        ["Bearer " <> token | _] -> String.trim(token)
        ["bearer " <> token | _] -> String.trim(token)
        _ -> nil
      end

    header || List.first(get_req_header(conn, "x-admin-token")) || query_token(conn)
  end

  defp query_token(conn) do
    conn = fetch_query_params(conn)

    case conn.query_params["token"] do
      value when is_binary(value) and value != "" -> String.trim(value)
      _ -> nil
    end
  end

  # A blank ADMIN_TOKEN is no token. Otherwise an env file carrying
  # `ADMIN_TOKEN=` would open the dashboard to anyone who sent an empty string.
  defp configured_token do
    case Application.get_env(:email_provider, :admin_token) do
      value when is_binary(value) -> if String.trim(value) == "", do: nil, else: value
      _ -> nil
    end
  end

  defp refuse(conn, status, message) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(%{message: message}))
    |> halt()
  end
end
