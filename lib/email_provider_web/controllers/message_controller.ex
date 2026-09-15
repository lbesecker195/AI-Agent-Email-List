defmodule EmailProviderWeb.MessageController do
  use EmailProviderWeb, :controller

  alias EmailProviderWeb.Plugs.RequireScope

  plug RequireScope, "messages:send" when action in [:create, :create_mime]
  plug RequireScope, "messages:read" when action in [:show, :index]

  alias EmailProvider.Mail
  alias EmailProviderWeb.Views

  @doc "POST /v3/:domain/messages"
  def create(conn, params) do
    case Mail.send_message(conn.assigns.current_user, conn.assigns.domain, params) do
      {:ok, messages} ->
        conn
        |> put_status(:ok)
        |> json(%{
          id: messages |> List.first() |> Map.get(:rfc_message_id),
          message: acceptance_text(messages),
          accepted: Enum.map(messages, &Views.message/1)
        })

      {:error, reason, details} ->
        conn |> put_status(status_for(reason)) |> json(error_body(reason, details))
    end
  end

  @doc """
  POST /v3/:domain/messages.mime

  Takes a pre-built MIME document. It is still screened and still counted
  against warmup — a caller cannot get around either by assembling the message
  themselves.
  """
  def create_mime(conn, %{"message" => raw} = params) when is_binary(raw) do
    parsed = EmailProvider.Delivery.Inbound.parse(raw)

    merged =
      params
      |> Map.drop(["message"])
      |> Map.put_new("from", parsed.from)
      |> Map.put_new("to", params["to"] || parsed.to)
      |> Map.put_new("subject", parsed.subject)
      |> Map.put_new("text", parsed.text)
      |> Map.put_new("html", parsed.html)

    create(conn, merged)
  end

  def create_mime(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{message: "'message' (raw MIME) is required"})
  end

  @doc "GET /v3/domains/:domain/messages/:key"
  def show(conn, %{"key" => key}) do
    case Mail.get_message(conn.assigns.domain, key) do
      nil -> conn |> put_status(:not_found) |> json(%{message: "message not found"})
      message -> json(conn, Views.stored_message(message))
    end
  end

  @doc "GET /v3/:domain/messages — not a Mailgun endpoint; useful for the inbox."
  def index(conn, params) do
    messages =
      Mail.list_messages(conn.assigns.domain,
        folder: params["folder"],
        direction: params["direction"],
        limit: params |> Map.get("limit", "50") |> String.to_integer() |> min(200)
      )

    json(conn, %{items: Enum.map(messages, &Views.message/1)})
  end

  defp acceptance_text([%{status: "scheduled"} | _]), do: "Scheduled. Thank you."
  defp acceptance_text([%{test_mode: true} | _]), do: "Accepted in test mode. Not sent."
  defp acceptance_text(_), do: "Queued. Thank you."

  defp status_for(:bad_request), do: :bad_request
  defp status_for(:not_found), do: :not_found
  defp status_for(:forbidden_sender), do: :forbidden
  defp status_for(:content_rejected), do: :forbidden
  defp status_for(:domain_not_verified), do: :forbidden
  defp status_for(:all_recipients_suppressed), do: :bad_request
  defp status_for(:rate_limited), do: :too_many_requests
  # 429 rather than 403: it lifts on its own as the refusals age out, so the
  # right thing for a client to do is wait, not to change the request.
  defp status_for(:sender_throttled), do: :too_many_requests

  defp error_body(:bad_request, reason) when is_binary(reason), do: %{message: reason}

  defp error_body(reason, details) when is_map(details) do
    Map.merge(%{error: to_string(reason)}, details)
  end

  defp error_body(reason, details), do: %{error: to_string(reason), message: inspect(details)}
end
