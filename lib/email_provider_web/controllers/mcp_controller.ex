defmodule EmailProviderWeb.MCPController do
  @moduledoc """
  The MCP endpoint.

  Authentication is optional here rather than enforced by a plug, because
  `create_account` has to work for an agent that has no key yet. A key, when one
  is sent, is resolved once and handed to the tool layer, which decides per tool
  whether it was needed.
  """
  use EmailProviderWeb, :controller

  require Logger

  alias EmailProvider.Accounts
  alias EmailProvider.Analytics
  alias EmailProviderWeb.MCP

  @doc "POST /mcp"
  def rpc(conn, _params) do
    user = current_user(conn)

    context = %{
      user: user,
      client_ip: EmailProviderWeb.Plugs.SignupLimit.client_ip(conn),
      sid: session_id(conn, user),
      visitor: Analytics.visitor_id(user)
    }

    case conn.body_params do
      # A batch. Notifications in it produce nothing, so a batch of only
      # notifications correctly answers with no body.
      messages when is_list(messages) ->
        replies =
          messages
          |> Enum.map(&MCP.handle(&1, context))
          |> Enum.flat_map(fn
            {:reply, reply} -> [reply]
            :noreply -> []
          end)

        if replies == [], do: send_resp(conn, 202, ""), else: json(conn, replies)

      message when is_map(message) ->
        case MCP.handle(message, context) do
          {:reply, reply} -> json(conn, reply)
          :noreply -> send_resp(conn, 202, "")
        end

      _ ->
        json(conn, %{
          jsonrpc: "2.0",
          id: nil,
          error: %{code: -32700, message: "Could not parse that as JSON-RPC."}
        })
    end
  end

  @doc """
  GET /mcp

  Two different callers arrive here and they want opposite things.

  A Streamable HTTP client issues GET to open a server-initiated event stream.
  This server has nothing to push, and the transport spec says to answer 405 in
  exactly that case. Handing such a client a JSON description instead would look
  like a stream that immediately produced garbage.

  A person pasting the URL into a browser wants to know what this is. They get
  the description.
  """
  def describe(conn, params) do
    if wants_event_stream?(conn) do
      conn
      |> put_resp_header("allow", "POST")
      |> put_resp_content_type("application/json")
      |> send_resp(
        405,
        Jason.encode!(%{
          jsonrpc: "2.0",
          id: nil,
          error: %{
            code: -32600,
            message:
              "This server does not offer a server-initiated stream. POST JSON-RPC here instead."
          }
        })
      )
    else
      describe_for_humans(conn, params)
    end
  end

  defp wants_event_stream?(conn) do
    conn
    |> get_req_header("accept")
    |> Enum.any?(&String.contains?(&1, "text/event-stream"))
  end

  defp describe_for_humans(conn, _params) do
    Analytics.report(:server_described, sid: session_id(conn, nil), transport: "mcp")

    json(conn, %{
      protocol: "Model Context Protocol",
      transport: "JSON-RPC 2.0 over HTTP POST to this URL",
      protocolVersion: MCP.latest_version(),
      server: MCP.server_info(),
      authentication:
        "Authorization: Bearer <api key>. Not needed for create_account, which is how " <>
          "an agent with no credentials gets one.",
      documentation: "#{base_url(conn)}/llms.txt",
      tools: Enum.map(EmailProviderWeb.MCP.Tools.list(), & &1.name)
    })
  end

  # This transport is stateless, so a run is a request unless the client sent a
  # session header — in which case its whole conversation groups as one.
  defp session_id(conn, user) do
    conn
    |> get_req_header("mcp-session-id")
    |> List.first()
    |> Analytics.session_id(user)
  end

  defp current_user(conn) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, user, _key} <- Accounts.authenticate_key(String.trim(token)) do
      user
    else
      _ -> nil
    end
  end

  defp base_url(conn) do
    case Application.get_env(:email_provider, :public_base_url) do
      url when is_binary(url) -> String.trim_trailing(url, "/")
      _ -> "#{conn.scheme}://#{conn.host}"
    end
  end
end
