defmodule EmailProviderWeb.Plugs.ApiAuth do
  @moduledoc """
  Authenticate an API request.

  Two forms are accepted: HTTP Basic with the username `api` and the key as the
  password, which is what Mailgun clients send, and `Authorization: Bearer`,
  which is what everything else sends.

  A failure says only that the credential was rejected. Distinguishing "no such
  key" from "revoked key" from "suspended account" would tell someone probing
  us which of their guesses was a real key.
  """

  import Plug.Conn

  alias EmailProvider.Accounts

  def init(opts), do: opts

  def call(conn, opts) do
    with {:ok, presented} <- extract(conn),
         {:ok, user, key} <- Accounts.authenticate_key(presented),
         :ok <- check_scope(key, Keyword.get(opts, :scope)) do
      conn
      |> assign(:current_user, user)
      |> assign(:current_key, key)
    else
      {:error, :forbidden_scope, scope} ->
        halt_with(conn, 403, "this API key is not authorized for #{scope}")

      _ ->
        conn
        |> put_resp_header("www-authenticate", ~s(Basic realm="api"))
        |> halt_with(401, "invalid credentials")
    end
  end

  defp extract(conn) do
    case get_req_header(conn, "authorization") do
      ["Basic " <> encoded | _] -> decode_basic(encoded)
      ["Bearer " <> token | _] -> {:ok, String.trim(token)}
      _ -> {:error, :missing}
    end
  end

  defp decode_basic(encoded) do
    with {:ok, decoded} <- Base.decode64(String.trim(encoded)),
         [_user, key] <- String.split(decoded, ":", parts: 2) do
      {:ok, key}
    else
      _ -> {:error, :malformed}
    end
  end

  defp check_scope(_key, nil), do: :ok

  defp check_scope(key, scope) do
    if Accounts.has_scope?(key, scope), do: :ok, else: {:error, :forbidden_scope, scope}
  end

  defp halt_with(conn, status, message) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(%{message: message}))
    |> halt()
  end
end
