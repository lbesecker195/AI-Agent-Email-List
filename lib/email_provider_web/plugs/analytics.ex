defmodule EmailProviderWeb.Plugs.Analytics do
  @moduledoc """
  Report REST API usage.

  The MCP side is instrumented at its dispatch point, which catches every tool
  in one place. The REST API has no such point — it has a router — so this sits
  in the pipeline instead and reports from `register_before_send`, which is
  late enough to know both which action ran and what it answered.

  **The path is never reported.** Routes here are shaped
  `/v3/mail.customer.com/messages`, so the path carries a customer's domain.
  The controller and action say everything adoption reporting needs and nothing
  about whose account it was.
  """

  import Plug.Conn

  alias EmailProvider.Analytics

  def init(opts), do: opts

  def call(conn, _opts) do
    if Analytics.enabled?() do
      started = System.monotonic_time(:millisecond)

      register_before_send(conn, fn sent ->
        # Read at send time, not on the way in: this plug runs before the one
        # that authenticates, so the account is only known by the time the
        # response is going out. Doing it here is what lets a caller's requests
        # group into one session instead of one session each.
        user = sent.assigns[:current_user]

        Analytics.report(:api_called,
          sid: Analytics.session_id(nil, user),
          visitor: Analytics.visitor_id(user),
          controller: short_name(sent.private[:phoenix_controller]),
          action: sent.private[:phoenix_action],
          status: sent.status,
          outcome: outcome(sent.status),
          latency_ms: System.monotonic_time(:millisecond) - started,
          transport: "rest"
        )

        sent
      end)
    else
      conn
    end
  end

  # "MessageController", not the full module path — shorter in a URL and the
  # prefix is the same on every one of them.
  defp short_name(nil), do: nil

  defp short_name(module) do
    module |> Module.split() |> List.last()
  end

  defp outcome(status) when status in 200..399, do: "success"
  defp outcome(status) when status in 400..499, do: "refused"
  defp outcome(_status), do: "error"
end
