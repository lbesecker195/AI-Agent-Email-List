defmodule EmailProvider.Webhooks do
  @moduledoc """
  Outbound event callbacks.

  Each payload is signed with the domain's own secret as
  `HMAC-SHA256(timestamp <> token, signing_key)`, the scheme Mailgun uses. The
  timestamp and token are in the payload so a receiver can reject replays
  without having to store every token forever.

  Delivery is fire-and-forget in a task: a customer's slow endpoint must not
  hold up our send loop.
  """

  import Ecto.Query, warn: false
  require Logger

  alias EmailProvider.Repo
  alias EmailProvider.Domains.Domain
  alias EmailProvider.Mail.Event
  alias EmailProvider.Webhooks.Webhook

  def list(%Domain{id: id}), do: Repo.all(from w in Webhook, where: w.domain_id == ^id)

  def get(%Domain{id: id}, event_type) do
    Repo.one(from w in Webhook, where: w.domain_id == ^id and w.event_type == ^event_type)
  end

  def upsert(%Domain{id: id}, event_type, url) do
    signing_key = 24 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)

    case get(%Domain{id: id}, event_type) do
      nil ->
        %Webhook{}
        |> Webhook.changeset(%{
          domain_id: id,
          event_type: event_type,
          url: url,
          signing_key: signing_key
        })
        |> Repo.insert()

      existing ->
        existing |> Webhook.changeset(%{url: url}) |> Repo.update()
    end
  end

  def delete(%Webhook{} = webhook), do: Repo.delete(webhook)

  @doc "Fire the callback for an event, if one is configured. Never raises."
  def notify(%Event{} = event, payload) do
    case get(%Domain{id: event.domain_id}, event.type) do
      %Webhook{enabled: true} = webhook -> deliver_async(webhook, event, payload)
      _ -> :noop
    end
  end

  defp deliver_async(webhook, event, payload) do
    Task.Supervisor.start_child(EmailProvider.TaskSupervisor, fn ->
      timestamp = System.system_time(:second) |> Integer.to_string()
      token = 16 |> :crypto.strong_rand_bytes() |> Base.encode16(case: :lower)

      signature =
        :hmac
        |> :crypto.mac(:sha256, webhook.signing_key, timestamp <> token)
        |> Base.encode16(case: :lower)

      body = %{
        signature: %{timestamp: timestamp, token: token, signature: signature},
        "event-data": Map.merge(payload, %{event: event.type, id: event.id})
      }

      case Req.post(webhook.url,
             json: body,
             receive_timeout: 10_000,
             retry: :transient,
             max_retries: 2
           ) do
        {:ok, %{status: status}} when status in 200..299 ->
          :ok

        {:ok, %{status: status}} ->
          Logger.warning("webhook #{webhook.url} returned #{status}")

        {:error, reason} ->
          Logger.warning("webhook #{webhook.url} failed: #{inspect(reason)}")
      end
    end)

    :ok
  end
end
