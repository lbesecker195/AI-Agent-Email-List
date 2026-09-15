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
  alias EmailProviderWeb.MCP

  @doc "POST /mcp"
  def rpc(conn, _params) do
    context = %{user: current_user(conn)}

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

  Not part of the protocol, which is POST only. It exists because somebody will
  paste this URL into a browser, and an explanation is more use than a 404.
  """
  def describe(conn, _params) do
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
