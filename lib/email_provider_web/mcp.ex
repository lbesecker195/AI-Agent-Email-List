defmodule EmailProviderWeb.MCP do
  @moduledoc """
  Model Context Protocol server, spoken as JSON-RPC 2.0 over HTTP.

  One endpoint, `POST /mcp`. An agent sends `initialize`, then `tools/list`, and
  then `tools/call` for whatever it decided to do.

  ## Two kinds of failure, deliberately kept apart

  A malformed request is a JSON-RPC error: the agent asked for something that is
  not a method, or sent something that is not a request. A tool that ran and
  refused is a *successful* response carrying `isError: true`, because the agent
  needs to read "that domain is not verified yet" and act on it. Returning a
  protocol error there would tell it the server is broken rather than that it
  needs to publish a DNS record.

  ## Version negotiation

  The client names a protocol version. We echo back one we support, preferring
  what it asked for, because an agent built against an older revision should
  still work rather than being told to upgrade.
  """

  require Logger

  alias EmailProviderWeb.MCP.Tools

  @supported_versions ["2025-06-18", "2025-03-26", "2024-11-05"]
  @latest_version "2025-06-18"

  @server_info %{name: "agent-email-list", version: "0.1.0"}

  @doc """
  Handle one decoded JSON-RPC message.

  Returns `{:reply, map}` for a request, or `:noreply` for a notification, which
  by the spec gets no response body at all.
  """
  def handle(%{"method" => method} = message, context) do
    id = Map.get(message, "id")
    params = Map.get(message, "params") || %{}

    cond do
      # No id means a notification: the client is telling us something and does
      # not expect an answer.
      is_nil(id) ->
        Logger.debug("MCP notification: #{method}")
        :noreply

      true ->
        {:reply, dispatch(method, params, id, context)}
    end
  end

  def handle(_malformed, _context) do
    {:reply, error(nil, -32600, "Not a JSON-RPC request: a method is required.")}
  end

  defp dispatch("initialize", params, id, _context) do
    version =
      case params["protocolVersion"] do
        v when v in @supported_versions -> v
        _ -> @latest_version
      end

    result(id, %{
      protocolVersion: version,
      capabilities: %{tools: %{listChanged: false}},
      serverInfo: @server_info,
      instructions: """
      Email sending and receiving for agents. Free, and you can open an account
      yourself: call create_account first, which needs no credentials, then send
      the API key it returns as `Authorization: Bearer <key>` on every later
      call.

      The usual path is create_account, add_domain, publish the DNS records it
      gives you, verify_domain, then send_email. Use test_mode on the first send
      to check the request shape without spending the daily allowance.
      """
    })
  end

  defp dispatch("tools/list", _params, id, _context) do
    result(id, %{tools: Tools.list()})
  end

  defp dispatch("tools/call", params, id, context) do
    name = params["name"]
    args = params["arguments"] || %{}

    cond do
      is_nil(name) ->
        error(id, -32602, "tools/call needs a name.")

      not Tools.known?(name) ->
        error(id, -32602, "No tool named #{name}.")

      not Tools.public?(name) and is_nil(context.user) ->
        # Not a protocol error: the agent can fix this, and saying how is more
        # useful than refusing at the transport layer.
        tool_result(
          id,
          "This tool needs an API key. Send it as `Authorization: Bearer <key>`. " <>
            "If you do not have one, call create_account, which needs no credentials.",
          true
        )

      true ->
        case Tools.call(name, args, context.user) do
          {:ok, text} -> tool_result(id, text, false)
          {:error, text} -> tool_result(id, text, true)
        end
    end
  rescue
    exception ->
      Logger.error("MCP tool #{params["name"]} crashed: #{Exception.message(exception)}")
      tool_result(id, "That tool failed unexpectedly. The failure has been logged.", true)
  end

  # Advertised as unsupported rather than left to 'method not found', so a
  # client that probes for them gets an empty list and moves on.
  defp dispatch("resources/list", _params, id, _context), do: result(id, %{resources: []})
  defp dispatch("prompts/list", _params, id, _context), do: result(id, %{prompts: []})
  defp dispatch("ping", _params, id, _context), do: result(id, %{})

  defp dispatch(method, _params, id, _context) do
    error(id, -32601, "Unknown method: #{method}")
  end

  defp result(id, result), do: %{jsonrpc: "2.0", id: id, result: result}

  defp tool_result(id, text, is_error?) do
    result(id, %{content: [%{type: "text", text: text}], isError: is_error?})
  end

  defp error(id, code, message) do
    %{jsonrpc: "2.0", id: id, error: %{code: code, message: message}}
  end

  @doc "The protocol version this server prefers."
  def latest_version, do: @latest_version

  @doc "Server name and version, as returned by initialize."
  def server_info, do: @server_info
end
