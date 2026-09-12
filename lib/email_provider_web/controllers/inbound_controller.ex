defmodule EmailProviderWeb.InboundController do
  use EmailProviderWeb, :controller

  plug EmailProviderWeb.Plugs.RequireScope, "messages:read"

  alias EmailProvider.Mail
  alias EmailProvider.Delivery.Inbound
  alias EmailProviderWeb.Views

  @doc """
  POST /v1/inbound/:domain

  Where the MTA hands us a received message. Authenticated with the same API
  credentials as everything else and scoped to a domain the caller owns, so
  this cannot be used to inject mail into another customer's mailbox.
  """
  def create(conn, %{"message" => raw}) when is_binary(raw) do
    parsed = Inbound.parse(raw)

    {:ok, message} =
      Mail.receive_message(conn.assigns.domain, %{
        sender: parsed.from,
        recipients: recipients(parsed, conn.assigns.domain),
        cc: parsed.cc,
        subject: parsed.subject,
        text: parsed.text,
        html: parsed.html,
        message_id: parsed.message_id,
        headers: parsed.headers,
        raw: parsed.raw
      })

    conn |> put_status(:created) |> json(%{message: "received", item: Views.message(message)})
  end

  def create(conn, params) do
    # Also accept already-parsed fields, which is what most MTA forwarders send.
    if params["sender"] || params["from"] do
      {:ok, message} =
        Mail.receive_message(conn.assigns.domain, %{
          sender: params["sender"] || params["from"],
          recipients: EmailProvider.Mail.Params.addresses(params["recipient"] || params["to"]),
          subject: params["subject"],
          text: params["body-plain"] || params["text"],
          html: params["body-html"] || params["html"],
          message_id: params["message-id"],
          headers: %{}
        })

      conn |> put_status(:created) |> json(%{message: "received", item: Views.message(message)})
    else
      conn
      |> put_status(:bad_request)
      |> json(%{message: "send raw MIME as 'message', or parsed fields including 'sender'"})
    end
  end

  # Prefer the recipients that actually belong to this domain; a message can be
  # addressed to several places and only some of them are ours.
  defp recipients(parsed, domain) do
    ours =
      Enum.filter(parsed.to ++ parsed.cc, fn address ->
        address
        |> EmailProvider.Suppressions.extract_address()
        |> String.downcase()
        |> String.ends_with?("@" <> domain.name)
      end)

    if ours == [], do: parsed.to, else: ours
  end

  @doc "GET /v1/inbound/:domain/spam — what screening filed away."
  def spam(conn, _params) do
    messages = Mail.list_messages(conn.assigns.domain, folder: "spam", direction: "inbound")
    json(conn, %{items: Enum.map(messages, &Views.message/1)})
  end
end
