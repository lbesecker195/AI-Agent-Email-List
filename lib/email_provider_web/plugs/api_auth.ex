defmodule EmailProviderWeb.Plugs.ApiAuth do
  @moduledoc """
  Authenticate an API request.

  Two forms are accepted: HTTP Basic with the username `api` and the key as the
  password, which is what Mailgun clients send, and `Authorization: Bearer`,
  which is what everything else sends.

  A failure says only that the credential was rejected. Distinguishing "no such
  key" from "revoked key" from "suspended account" would tell someone probing
  us which of their guesses was a real key.

  ## Two limits, for two different problems

  Bad credentials are limited by address, because that is all a request without
  a valid key has. This is about guessing: without it, keys can be tried as
  fast as the box will answer.

  Good credentials are limited by account, generously. This one is not an abuse
  control — how much an account may *send* is settled by the warmup ladder and
  by `EmailProvider.Reputation`, both of which count from the database. It is
  here so that one agent stuck in a retry loop cannot take the service down for
  everyone else, which is a failure mode this service should expect: its whole
  audience is software that retries.
  """

  import Plug.Conn

  alias EmailProvider.Accounts
  alias EmailProvider.RateLimit
  alias EmailProviderWeb.Plugs.SignupLimit

  def init(opts), do: opts

  def call(conn, opts) do
    with {:ok, presented} <- extract(conn),
         {:ok, user, key} <- Accounts.authenticate_key(presented),
         :ok <- check_scope(key, Keyword.get(opts, :scope)),
         :ok <- RateLimit.hit({:api, user.id}, requests_per_minute(), 60) do
      conn
      |> assign(:current_user, user)
      |> assign(:current_key, key)
    else
      {:error, :forbidden_scope, scope} ->
        halt_with(conn, 403, "this API key is not authorized for #{scope}")

      {:error, retry_after} when is_integer(retry_after) ->
        conn
        |> put_resp_header("retry-after", Integer.to_string(retry_after))
        |> halt_with(
          429,
          "too many requests on this account: more than #{requests_per_minute()} in a minute. " <>
            "Retry in #{retry_after} seconds. This is a pace limit, not a sending limit — " <>
            "GET /v3/domains/<domain> reports how much you may still send today."
        )

      _ ->
        # Counted by address, since a rejected request has no account to
        # count against. Generous enough that a misconfigured client is not
        # locked out, tight enough that keys cannot be enumerated.
        case RateLimit.hit({:bad_key, SignupLimit.client_ip(conn)}, failures_per_minute(), 60) do
          :ok ->
            conn
            |> put_resp_header("www-authenticate", ~s(Basic realm="api"))
            |> halt_with(401, "invalid credentials")

          {:error, retry_after} ->
            conn
            |> put_resp_header("retry-after", Integer.to_string(retry_after))
            |> halt_with(429, "too many failed authentication attempts from this address")
        end
    end
  end

  defp config, do: Application.get_env(:email_provider, __MODULE__, [])
  defp requests_per_minute, do: Keyword.get(config(), :requests_per_minute, 600)
  defp failures_per_minute, do: Keyword.get(config(), :failures_per_minute, 30)

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
