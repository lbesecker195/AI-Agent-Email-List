defmodule EmailProvider.Mail do
  @moduledoc """
  The send and receive pipeline.

  Outbound, in order:

    1. parse and validate the request
    2. refuse unless the domain is DNS-verified
    3. expand a template, if one was named
    4. screen the content (a flagged message is recorded and refused, never sent)
    5. drop recipients on the suppression list
    6. reserve warmup capacity for the recipients that remain
    7. persist, and let the queue pick it up

  Screening comes before reservation on purpose: a message we are going to
  refuse should not spend any of the domain's daily allowance.

  Inbound is the same screening with a gentler consequence — a flagged message
  is filed in spam rather than refused, because a false positive on incoming
  mail loses somebody a real message.
  """

  import Ecto.Query, warn: false

  alias EmailProvider.{
    Domains,
    Moderation,
    Profiles,
    Repo,
    Routes,
    Suppressions,
    Templates,
    Warmup,
    Webhooks
  }

  alias EmailProvider.Accounts.User
  alias EmailProvider.Delivery.{Dkim, Mime, Sender}
  alias EmailProvider.Domains.Domain
  alias EmailProvider.Mail.{Event, Message, Params}

  @max_attempts 5

  # -- sending -------------------------------------------------------------

  @doc """
  Accept a send request.

  Returns `{:ok, [message]}` on acceptance, or `{:error, reason, details}`.
  Acceptance means queued, not delivered — delivery outcome arrives as events.
  """
  @spec send_message(User.t(), Domain.t(), map()) ::
          {:ok, [Message.t()]} | {:error, atom(), term()}
  def send_message(%User{} = user, %Domain{} = domain, raw_params) do
    with {:ok, params} <- parse(raw_params),
         :ok <- check_sendable(domain),
         :ok <- check_from_domain(params, domain),
         :ok <- check_reputation(user),
         {:ok, params} <- apply_template(domain, params),
         {:ok, params, verdict} <- screen_outbound(user, domain, params),
         {:ok, params, suppressed} <- drop_suppressed(domain, params),
         {:ok, reservation} <- reserve_capacity(domain, params) do
      messages = persist(user, domain, params, verdict)

      Enum.each(messages, fn message ->
        record_event(message, "accepted", %{
          recipients: message.recipients,
          suppressed:
            Enum.map(suppressed, fn {address, s} -> %{address: address, reason: s.type} end),
          warmup: reservation
        })
      end)

      # Rewrite the account holder's description. Off the request path: this can
      # call an enrichment provider and a model, and neither belongs in the
      # latency of a send.
      Enum.each(messages, &Profiles.note_message/1)

      {:ok, messages}
    end
  end

  defp parse(raw_params) do
    case Params.parse(raw_params) do
      {:ok, params} -> {:ok, params}
      {:error, reason} -> {:error, :bad_request, reason}
    end
  end

  defp check_sendable(%Domain{} = domain) do
    if Domains.sendable?(domain) do
      :ok
    else
      {:error, :domain_not_verified,
       %{
         domain: domain.name,
         state: domain.state,
         message: "domain is not verified; publish its DNS records and call verify",
         required_records: Domains.dns_records(domain) |> Enum.filter(& &1.required)
       }}
    end
  end

  # The envelope sender must belong to the domain the key is sending for.
  # Without this check any authenticated customer could send as any other.
  defp check_from_domain(%Params{from: from}, %Domain{name: name}) do
    address = Suppressions.extract_address(from)

    case String.split(address, "@") do
      [_local, host] ->
        host = String.downcase(host)

        if host == name or String.ends_with?(host, "." <> name) do
          :ok
        else
          {:error, :forbidden_sender,
           %{message: "'from' must be an address at #{name}", got: address}}
        end

      _ ->
        {:error, :bad_request, "'from' is not a valid address"}
    end
  end

  defp apply_template(_domain, %Params{template: nil} = params), do: {:ok, params}
  defp apply_template(_domain, %Params{template: ""} = params), do: {:ok, params}

  defp apply_template(domain, %Params{template: name} = params) do
    with %Templates.Template{} = template <- Templates.get(domain, name),
         %{} = version <- Templates.version(template, params.template_version) do
      vars = Map.merge(params.variables, params.template_variables)

      {:ok,
       %{
         params
         | html: Templates.render(version.body, vars),
           subject: params.subject || Templates.render(version.subject, vars)
       }}
    else
      nil -> {:error, :not_found, %{message: "template '#{name}' not found for this domain"}}
    end
  end

  # An account that keeps being refused is narrowed and eventually suspended.
  # Separate from the warmup ladder, which caps a domain rather than a sender.
  defp check_reputation(user) do
    case EmailProvider.Reputation.check_sending(user) do
      :ok -> :ok
      {:error, message} -> {:error, :sender_throttled, %{message: message}}
    end
  end

  defp screen_outbound(user, domain, %Params{} = params) do
    verdict =
      [params.subject, params.text, strip_html(params.html)]
      |> Moderation.check()

    case Moderation.decide(verdict, :outbound) do
      {:allow, verdict} ->
        {:ok, params, verdict}

      {:block, verdict} ->
        record_refusal(user, domain, params, verdict)

        {:error, :content_rejected,
         %{
           message: "message content was refused by content screening",
           categories: verdict.categories,
           screened: verdict.screened,
           verdict: verdict
         }}
    end
  end

  # A refused message is still recorded, with status "rejected" and never
  # queued. Two things depend on it: the operator dashboard could not previously
  # count refusals at all, and repeated refusals are the cheapest abuse signal
  # this service has, because screening is already being paid for.
  defp record_refusal(user, domain, %Params{} = params, verdict) do
    %Message{}
    |> Message.changeset(%{
      user_id: user.id,
      domain_id: domain.id,
      direction: "outbound",
      storage_key: storage_key(),
      sender: params.from,
      recipients: params.to,
      cc: params.cc,
      bcc: params.bcc,
      subject: params.subject,
      body_text: params.text,
      body_html: params.html,
      tags: params.tags,
      status: "rejected",
      moderation_checked_at: verdict.checked_at,
      moderation_flagged: verdict.flagged,
      moderation_categories: verdict.categories,
      moderation_scores: verdict.scores,
      moderation_action: "blocked"
    })
    |> Repo.insert()
    |> case do
      {:ok, message} ->
        record_event(message, "rejected", %{
          categories: verdict.categories,
          reason: "content screening"
        })

      {:error, _changeset} ->
        :ok
    end
  end

  defp drop_suppressed(domain, %Params{} = params) do
    {allowed, suppressed} = Suppressions.partition(domain, params.to, params.tags)

    if allowed == [] do
      {:error, :all_recipients_suppressed,
       %{
         message: "every recipient is on this domain's suppression list",
         suppressed:
           Enum.map(suppressed, fn {address, s} ->
             %{address: address, type: s.type, reason: s.reason}
           end)
       }}
    else
      {:ok, %{params | to: allowed}, suppressed}
    end
  end

  # Test-mode messages never reach the wire, so they cannot affect reputation
  # and do not consume warmup allowance.
  defp reserve_capacity(_domain, %Params{test_mode: true}), do: {:ok, %{test_mode: true}}

  defp reserve_capacity(domain, %Params{} = params) do
    count = length(params.to) + length(params.cc) + length(params.bcc)

    case Warmup.reserve(domain, count) do
      {:ok, reservation} ->
        {:ok, reservation}

      {:error, {:rate_limited, details}} ->
        {:error, :rate_limited, details}
    end
  end

  defp persist(user, domain, %Params{} = params, verdict) do
    status = status_for(params)

    if map_size(params.recipient_variables) > 0 do
      # Per-recipient variables mean per-recipient messages: each one gets its
      # own body, its own Message-ID and its own event stream.
      Enum.map(params.to, fn recipient ->
        address = Suppressions.extract_address(recipient)
        vars = Map.get(params.recipient_variables, address, %{})

        insert_message(user, domain, params, verdict, status,
          recipients: [recipient],
          subject: substitute(params.subject, vars),
          text: substitute(params.text, vars),
          html: substitute(params.html, vars),
          variables: Map.merge(params.variables, %{"recipient" => vars})
        )
      end)
    else
      [
        insert_message(user, domain, params, verdict, status,
          recipients: params.to,
          subject: params.subject,
          text: params.text,
          html: params.html,
          variables: params.variables
        )
      ]
    end
  end

  defp status_for(%Params{test_mode: true}), do: "sent"
  defp status_for(%Params{delivery_time: nil}), do: "queued"
  defp status_for(%Params{}), do: "scheduled"

  defp insert_message(user, domain, params, verdict, status, fields) do
    recipients = Keyword.fetch!(fields, :recipients)

    %Message{}
    |> Message.changeset(%{
      user_id: user.id,
      domain_id: domain.id,
      direction: "outbound",
      storage_key: storage_key(),
      rfc_message_id: Mime.generate_message_id(%{sender: params.from}),
      sender: params.from,
      recipients: recipients,
      cc: params.cc,
      bcc: params.bcc,
      subject: Keyword.get(fields, :subject),
      body_text: Keyword.get(fields, :text),
      body_html: Keyword.get(fields, :html),
      headers: params.headers,
      variables: Keyword.get(fields, :variables, %{}),
      tags: params.tags,
      template_name: params.template,
      template_version: params.template_version,
      status: status,
      test_mode: params.test_mode,
      scheduled_at: params.delivery_time,
      sent_at: if(params.test_mode, do: DateTime.utc_now()),
      moderation_checked_at: verdict.checked_at,
      moderation_flagged: verdict.flagged,
      moderation_categories: verdict.categories,
      moderation_scores: verdict.scores,
      moderation_action: if(verdict.screened, do: "allowed", else: "not_screened"),
      tracking_opens: resolve_tracking(params.tracking_opens, domain.tracking_opens),
      tracking_clicks: resolve_tracking(params.tracking_clicks, domain.tracking_clicks)
    })
    |> Repo.insert!()
  end

  defp resolve_tracking(nil, domain_default), do: domain_default
  defp resolve_tracking(explicit, _domain_default), do: explicit

  defp substitute(nil, _vars), do: nil

  # `%recipient.name%` is Mailgun's per-recipient placeholder syntax.
  defp substitute(body, vars) do
    Regex.replace(~r/%recipient\.([a-zA-Z0-9_-]+)%/, body, fn whole, key ->
      case Map.fetch(vars, key) do
        {:ok, value} -> to_string(value)
        :error -> whole
      end
    end)
  end

  defp storage_key do
    24 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end

  # -- delivery ------------------------------------------------------------

  @doc """
  Deliver a message the queue has already claimed.

  Only the queue should call this: it assumes the row's status has already been
  moved to `sent` under a guard, which is what stops two nodes sending the same
  message twice.
  """
  def deliver_claimed(%Message{} = message) do
    # Re-read rather than trusting the struct the caller holds. It was loaded
    # before the claim, so its in-memory status is still "queued"; writing
    # "queued" back onto it through a changeset would diff to no change at all
    # and silently leave the row claimed forever.
    message = Message |> Repo.get!(message.id) |> Repo.preload(:domain)
    envelope_to = Enum.uniq(message.recipients ++ message.cc ++ message.bcc)
    from = Suppressions.extract_address(message.sender)

    raw =
      message
      |> Mime.render()
      |> Dkim.sign(message.domain)

    case Sender.deliver(raw, from, Enum.map(envelope_to, &Suppressions.extract_address/1)) do
      {:ok, info} ->
        message
        |> Message.changeset(%{status: "sent", delivered_at: DateTime.utc_now()})
        |> Repo.update!()

        record_event(message, "delivered", %{
          recipients: envelope_to,
          receipt: Map.get(info, :receipt)
        })

        {:ok, message}

      {:error, reason} ->
        handle_failure(message, reason)
    end
  end

  defp handle_failure(%Message{} = message, reason) do
    description = inspect(reason)
    permanent? = permanent_failure?(description) or message.attempts >= @max_attempts

    if permanent? do
      message
      |> Message.changeset(%{status: "failed", failure_reason: description})
      |> Repo.update!()

      # A message that never went out should not have spent warmup allowance.
      Warmup.release(
        message.domain,
        length(message.recipients) + length(message.cc) + length(message.bcc)
      )

      record_event(message, "failed", %{
        severity: "permanent",
        reason: description,
        attempts: message.attempts
      })

      # A hard bounce suppresses the address; that is the whole point of
      # keeping the list.
      if bounce?(description) do
        Enum.each(message.recipients, fn recipient ->
          Suppressions.add(message.domain, "bounce", Suppressions.extract_address(recipient), %{
            reason: description
          })
        end)
      end

      {:error, reason}
    else
      message
      |> Message.changeset(%{status: "queued", failure_reason: description})
      |> Repo.update!()

      record_event(message, "failed", %{
        severity: "temporary",
        reason: description,
        attempts: message.attempts
      })

      {:error, reason}
    end
  end

  # A 5xx is the server telling us not to try again. A 4xx is worth a retry.
  defp permanent_failure?(description), do: Regex.match?(~r/\b5\d\d\b/, description)

  defp bounce?(description) do
    Regex.match?(
      ~r/\b(550|551|553|554)\b|no such user|user unknown|mailbox unavailable/i,
      description
    )
  end

  # -- receiving -----------------------------------------------------------

  @doc """
  Accept an inbound message for a domain.

  Flagged content is filed in spam rather than refused. Routes run after
  filing, and only for messages that landed in the inbox — forwarding spam to a
  customer's webhook helps nobody.
  """
  def receive_message(%Domain{} = domain, attrs) do
    verdict =
      [attrs[:subject], attrs[:text], strip_html(attrs[:html])]
      |> Moderation.check()

    {decision, verdict} = Moderation.decide(verdict, :inbound)
    folder = if decision == :spam, do: "spam", else: "inbox"

    message =
      %Message{}
      |> Message.changeset(%{
        user_id: domain.user_id,
        domain_id: domain.id,
        direction: "inbound",
        storage_key: storage_key(),
        rfc_message_id: attrs[:message_id],
        sender: attrs[:sender] || attrs[:from],
        recipients: List.wrap(attrs[:recipients] || attrs[:to]),
        cc: List.wrap(attrs[:cc]),
        subject: attrs[:subject],
        body_text: attrs[:text],
        body_html: attrs[:html],
        mime_raw: attrs[:raw],
        headers: attrs[:headers] || %{},
        status: "received",
        folder: folder,
        moderation_checked_at: verdict.checked_at,
        moderation_flagged: verdict.flagged,
        moderation_categories: verdict.categories,
        moderation_scores: verdict.scores,
        moderation_action: inbound_action(decision, verdict)
      })
      |> Repo.insert!()

    record_event(message, "received", %{folder: folder, flagged: verdict.flagged})

    if folder == "inbox" do
      Routes.run(domain, message)
    end

    Profiles.note_message(message)

    {:ok, message}
  end

  # "Allowed" must mean screened and found clean. A message we could not screen
  # is a third state, not a pass.
  defp inbound_action(:spam, _verdict), do: "filed_spam"
  defp inbound_action(_decision, %{screened: true}), do: "allowed"
  defp inbound_action(_decision, _verdict), do: "not_screened"

  # -- events and queries --------------------------------------------------

  @doc "Append an event and fire the matching webhook."
  def record_event(%Message{} = message, type, payload \\ %{}) do
    event =
      %Event{}
      |> Event.changeset(%{
        message_id: message.id,
        domain_id: message.domain_id,
        type: type,
        recipient: List.first(message.recipients),
        tags: message.tags,
        payload: payload,
        occurred_at: DateTime.utc_now()
      })
      |> Repo.insert!()

    Webhooks.notify(event, %{
      message: %{
        headers: %{
          "message-id": message.rfc_message_id,
          to: message.recipients,
          from: message.sender,
          subject: message.subject
        },
        storage: %{key: message.storage_key}
      },
      tags: message.tags,
      "user-variables": message.variables,
      timestamp: DateTime.to_unix(event.occurred_at)
    })

    event
  end

  def get_message(%Domain{id: id}, storage_key) do
    Repo.one(from m in Message, where: m.domain_id == ^id and m.storage_key == ^storage_key)
  end

  @doc """
  One message by id, scoped to the account that owns it, with its domain and
  delivery events preloaded.

  For the console detail page rather than the REST API: the API is scoped to a
  domain already (the URL carries it), but a person clicking a row in their
  unified inbox has not chosen a domain, so this checks ownership on the
  message itself instead. Returns nil for a message that does not exist or
  belongs to somebody else — the two cases are indistinguishable on purpose.
  """
  def get_user_message(%EmailProvider.Accounts.User{id: user_id}, id) do
    case Ecto.UUID.cast(id) do
      {:ok, id} ->
        Repo.one(
          from m in Message,
            where: m.id == ^id and m.user_id == ^user_id,
            preload: [
              :domain,
              events: ^from(e in EmailProvider.Mail.Event, order_by: e.occurred_at)
            ]
        )

      :error ->
        nil
    end
  end

  @doc "Events for a domain, newest first, with the filters the events API exposes."
  def list_events(%Domain{id: id}, filters \\ %{}) do
    limit = filters |> Map.get("limit", "100") |> to_string() |> String.to_integer() |> min(300)

    from(e in Event, where: e.domain_id == ^id, order_by: [desc: e.occurred_at], limit: ^limit)
    |> filter_by(:type, filters["event"])
    |> filter_by(:recipient, filters["recipient"])
    |> filter_by_tag(filters["tag"])
    |> filter_since(filters["begin"])
    |> Repo.all()
  end

  defp filter_by(query, _field, nil), do: query
  defp filter_by(query, :type, value), do: from(e in query, where: e.type == ^value)
  defp filter_by(query, :recipient, value), do: from(e in query, where: e.recipient == ^value)

  defp filter_by_tag(query, nil), do: query
  defp filter_by_tag(query, tag), do: from(e in query, where: ^tag in e.tags)

  defp filter_since(query, nil), do: query

  defp filter_since(query, value) do
    case Params.parse_datetime(value) do
      {:ok, datetime} -> from(e in query, where: e.occurred_at >= ^datetime)
      :error -> query
    end
  end

  @doc "Aggregate counts per event type for a domain."
  def stats(%Domain{id: id}) do
    from(e in Event, where: e.domain_id == ^id, group_by: e.type, select: {e.type, count(e.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc "Distinct tags in use on a domain, with how many messages carry each."
  def tags(%Domain{id: id}) do
    from(m in Message,
      where: m.domain_id == ^id,
      select: {fragment("unnest(?)", m.tags), count(m.id)},
      group_by: fragment("unnest(?)", m.tags)
    )
    |> Repo.all()
    |> Enum.map(fn {tag, count} -> %{tag: tag, messages: count} end)
    |> Enum.sort_by(& &1.tag)
  end

  def list_messages(%Domain{id: id}, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    folder = Keyword.get(opts, :folder)
    direction = Keyword.get(opts, :direction)

    from(m in Message, where: m.domain_id == ^id, order_by: [desc: m.inserted_at], limit: ^limit)
    |> then(fn q -> if folder, do: from(m in q, where: m.folder == ^folder), else: q end)
    |> then(fn q -> if direction, do: from(m in q, where: m.direction == ^direction), else: q end)
    |> Repo.all()
  end

  @doc "Crude tag-stripper, used only to give the screener readable text."
  def strip_html(nil), do: nil

  def strip_html(html) when is_binary(html) do
    html
    |> String.replace(~r/<(script|style)\b[^>]*>.*?<\/\1>/is, " ")
    |> String.replace(~r/<[^>]+>/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end
end
