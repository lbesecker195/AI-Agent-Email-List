defmodule EmailProviderWeb.Views do
  @moduledoc """
  Shapes records for the API.

  Everything the API returns goes through here, so secrets have exactly one
  place to leak from and exactly one place to be stopped: private keys, key
  hashes and password hashes are never in one of these maps.
  """

  alias EmailProvider.{Domains, Warmup}

  def domain(domain, opts \\ []) do
    base = %{
      id: domain.id,
      name: domain.name,
      state: domain.state,
      created_at: domain.inserted_at,
      smtp_login: domain.smtp_login,
      dkim_selector: domain.dkim_selector,
      tracking: %{opens: domain.tracking_opens, clicks: domain.tracking_clicks},
      warmup: Warmup.status(domain),
      verification: %{
        spf: !is_nil(domain.spf_verified_at),
        dkim: !is_nil(domain.dkim_verified_at),
        mx: !is_nil(domain.mx_verified_at),
        last_checked_at: domain.last_checked_at
      }
    }

    if Keyword.get(opts, :with_records, true) do
      Map.put(base, :sending_dns_records, Domains.dns_records(domain))
    else
      base
    end
  end

  def message(message) do
    %{
      id: message.rfc_message_id,
      storage_key: message.storage_key,
      status: message.status,
      direction: message.direction,
      from: message.sender,
      to: message.recipients,
      cc: message.cc,
      subject: message.subject,
      tags: message.tags,
      folder: message.folder,
      test_mode: message.test_mode,
      scheduled_at: message.scheduled_at,
      sent_at: message.sent_at,
      delivered_at: message.delivered_at,
      failure_reason: message.failure_reason,
      attempts: message.attempts,
      moderation: %{
        screened: !is_nil(message.moderation_checked_at),
        flagged: message.moderation_flagged,
        categories: message.moderation_categories,
        action: message.moderation_action
      },
      created_at: message.inserted_at
    }
  end

  def stored_message(message) do
    message
    |> message()
    |> Map.merge(%{
      "body-plain": message.body_text,
      "body-html": message.body_html,
      headers: message.headers,
      "user-variables": message.variables
    })
  end

  def event(event) do
    %{
      id: event.id,
      event: event.type,
      recipient: event.recipient,
      tags: event.tags,
      timestamp: DateTime.to_unix(event.occurred_at),
      occurred_at: event.occurred_at,
      message_id: event.message_id,
      payload: event.payload
    }
  end

  def suppression(suppression) do
    %{
      address: suppression.address,
      type: suppression.type,
      reason: suppression.reason,
      code: suppression.error_code,
      tag: suppression.tag,
      created_at: suppression.inserted_at
    }
  end

  def template(template) do
    %{
      name: template.name,
      description: template.description,
      created_at: template.inserted_at,
      versions:
        template
        |> Map.get(:versions, [])
        |> case do
          versions when is_list(versions) -> Enum.map(versions, &template_version/1)
          _ -> []
        end
    }
  end

  def template_version(version) do
    %{
      tag: version.tag,
      subject: version.subject,
      template: version.body,
      engine: version.engine,
      active: version.active,
      comment: version.comment,
      created_at: version.inserted_at
    }
  end

  def route(route) do
    %{
      id: route.id,
      priority: route.priority,
      description: route.description,
      expression: route.expression,
      actions: route.actions,
      enabled: route.enabled,
      created_at: route.inserted_at
    }
  end

  def webhook(webhook) do
    %{
      id: webhook.id,
      event_type: webhook.event_type,
      urls: [webhook.url],
      enabled: webhook.enabled
    }
  end

  def profile(nil), do: nil

  def profile(profile) do
    %{
      description: profile.description,
      word_count: profile.word_count,
      version: profile.version,
      generator: profile.generator,
      messages_seen: profile.messages_seen,
      generated_at: profile.generated_at,
      enriched_at: profile.enriched_at,
      # What the description was written from, so it can be accounted for
      # rather than taken on faith.
      enrichment: profile.enrichment,
      signals: profile.signals,
      last_error: profile.last_error
    }
  end

  def api_key(key) do
    %{
      id: key.id,
      prefix: key.prefix,
      label: key.label,
      scopes: key.scopes,
      last_used_at: key.last_used_at,
      revoked_at: key.revoked_at,
      created_at: key.inserted_at
    }
  end

  def changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r/%\{(\w+)\}/, message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
