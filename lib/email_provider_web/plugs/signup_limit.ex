defmodule EmailProviderWeb.Plugs.SignupLimit do
  @moduledoc """
  Caps how many accounts one address can open.

  This is the load-bearing limit of the whole service. Everything else an
  abuser might want — domains, sending volume — is already capped per account,
  so the way around those caps is simply to open more accounts. An agent
  self-signup endpoint with no limit here is a spam engine with extra steps.

  Deliberately generous per hour, because a developer building against this
  will legitimately create several accounts while getting it working, and an
  agent retrying a failed signup should not be locked out. The daily cap is
  what actually stops bulk registration.
  """

  import Plug.Conn

  alias EmailProvider.RateLimit

  def init(opts), do: Keyword.get(opts, :on_limit, :json)

  def call(conn, on_limit) do
    ip = client_ip(conn)

    with :ok <- RateLimit.hit({:signup_hour, ip}, per_hour(), 3_600),
         :ok <- RateLimit.hit({:signup_day, ip}, per_day(), 86_400) do
      conn
    else
      {:error, retry_after} -> refuse(conn, on_limit, retry_after)
    end
  end

  @doc """
  The address a request actually came from.

  Public because the MCP endpoint needs the same answer, and it reaches this
  through the JSON-RPC body rather than through a plug.
  """
  # Behind nginx every request appears to come from 127.0.0.1, so the forwarded
  # header is the only thing carrying the real address. It is client-supplied
  # and therefore forgeable, but nginx overwrites it with the connecting
  # address, so the value we trust is the last one — the one nginx appended.
  def client_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [value | _] ->
        value |> String.split(",") |> List.last() |> String.trim()

      [] ->
        conn.remote_ip |> :inet.ntoa() |> to_string()
    end
  end

  defp refuse(conn, :html, retry_after) do
    minutes = max(div(retry_after, 60), 1)

    conn
    |> Phoenix.Controller.put_flash(
      :error,
      "Too many accounts have been created from this network. Try again in #{minutes} minutes."
    )
    |> Phoenix.Controller.redirect(to: "/signup")
    |> halt()
  end

  defp refuse(conn, _json, retry_after) do
    conn
    |> put_resp_header("retry-after", Integer.to_string(retry_after))
    |> put_resp_content_type("application/json")
    |> send_resp(
      429,
      Jason.encode!(%{
        message:
          "Too many accounts created from this address. Try again in #{retry_after} seconds. " <>
            "One account can hold several domains, so you probably do not need another.",
        retry_after_seconds: retry_after
      })
    )
    |> halt()
  end

  defp config, do: Application.get_env(:email_provider, __MODULE__, [])
  defp per_hour, do: Keyword.get(config(), :per_hour, 5)
  defp per_day, do: Keyword.get(config(), :per_day, 20)
end
