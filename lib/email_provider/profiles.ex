defmodule EmailProvider.Profiles do
  @moduledoc """
  A rolling ~200 word description of each account holder, rewritten as their
  mail moves.

  Two inputs: a CSuiteFinder enrichment record for the account's own address,
  and a digest of what the account's mail has been doing — who it corresponds
  with, how much, how often, and what the subject lines say.

  ## When it runs

  On every message, outbound and inbound, as specified. The work happens in a
  task off the send path, so a slow enrichment call or a slow model cannot add
  latency to an API request or hold up a delivery. Set `:min_interval_seconds`
  to coalesce refreshes for a busy account; it defaults to 0, which is one
  refresh per message and, with the model adapter, one model call per message.
  That is the expensive setting. It is the one that was asked for, and it is a
  single config line to change.

  Failures are recorded on the row and never propagated. A profile that could
  not be rewritten keeps the description it had.
  """

  import Ecto.Query, warn: false
  require Logger

  alias EmailProvider.Repo
  alias EmailProvider.Accounts.User
  alias EmailProvider.Enrichment.CSuiteFinder
  alias EmailProvider.Mail.Message
  alias EmailProvider.Profiles.{Generator, Profile}

  @target_words 200
  @enrichment_ttl_days 30
  @max_correspondents 8
  @max_subjects 12
  @max_excerpts 6
  @excerpt_bytes 400

  # -- reading -------------------------------------------------------------

  def get(%User{id: id}), do: Repo.one(from p in Profile, where: p.user_id == ^id)

  def get_or_create(%User{id: id} = user) do
    case get(user) do
      nil -> %Profile{} |> Profile.changeset(%{user_id: id}) |> Repo.insert!()
      profile -> profile
    end
  end

  # -- the hook ------------------------------------------------------------

  @doc """
  Note that a message happened and rewrite the description.

  Called from the send and receive paths. It must never raise there, and it
  must never block there.
  """
  def note_message(%Message{user_id: nil}), do: :ok

  def note_message(%Message{} = message) do
    if enabled?() do
      run(fn -> refresh_for_message(message) end)
    else
      :ok
    end
  end

  def note_message(_), do: :ok

  defp run(fun) do
    if async?() do
      Task.Supervisor.start_child(EmailProvider.TaskSupervisor, fn -> safely(fun) end)
      :ok
    else
      safely(fun)
    end
  end

  defp safely(fun) do
    fun.()
  rescue
    error ->
      Logger.error("profile refresh crashed: #{Exception.message(error)}")
      :error
  catch
    kind, reason ->
      Logger.error("profile refresh crashed: #{inspect(kind)} #{inspect(reason)}")
      :error
  end

  defp refresh_for_message(%Message{user_id: user_id} = message) do
    case Repo.get(User, user_id) do
      nil ->
        :ok

      user ->
        profile = get_or_create(user)

        if due?(profile) do
          refresh(user, last_message: message)
        else
          # Still count it, so the next refresh knows how much it missed.
          profile
          |> Profile.changeset(%{
            messages_seen: profile.messages_seen + 1,
            last_message_id: message.id
          })
          |> Repo.update!()

          :skipped
        end
    end
  end

  defp due?(%Profile{generated_at: nil}), do: true

  defp due?(%Profile{generated_at: at}) do
    DateTime.diff(DateTime.utc_now(), at, :second) >= min_interval()
  end

  # -- refreshing ----------------------------------------------------------

  @doc """
  Rewrite an account holder's description now.

  Returns `{:ok, profile}` or `{:error, reason}`. On failure the previous
  description is left in place and the reason is recorded on the row.
  """
  def refresh(%User{} = user, opts \\ []) do
    profile = get_or_create(user)
    signals = signals(user)
    {enrichment, enriched_at} = enrichment_for(user, profile)

    inputs = %{
      account: %{email: user.email, name: user.name, since: user.inserted_at},
      enrichment: enrichment,
      signals: signals
    }

    last_message = Keyword.get(opts, :last_message)

    case Generator.describe(inputs, @target_words) do
      {:ok, description, generator} ->
        {:ok,
         profile
         |> Profile.changeset(%{
           description: description,
           word_count: Generator.word_count(description),
           enrichment: enrichment || %{},
           enriched_at: enriched_at,
           signals: stringify(signals),
           messages_seen: profile.messages_seen + 1,
           last_message_id: last_message && last_message.id,
           generator: generator,
           version: profile.version + 1,
           last_error: nil,
           generated_at: DateTime.utc_now()
         })
         |> Repo.update!()}

      {:error, reason} ->
        Logger.warning("could not write profile for #{user.email}: #{inspect(reason)}")

        profile
        |> Profile.changeset(%{
          messages_seen: profile.messages_seen + 1,
          last_message_id: last_message && last_message.id,
          last_error: inspect(reason)
        })
        |> Repo.update!()

        {:error, reason}
    end
  end

  # Cached until it goes stale: the provider bills per result, and a person's
  # job title does not change between two emails.
  defp enrichment_for(%User{email: email}, %Profile{} = profile) do
    if fresh_enrichment?(profile) do
      {profile.enrichment, profile.enriched_at}
    else
      case CSuiteFinder.person(email) do
        {:ok, :not_found} -> {%{}, DateTime.utc_now()}
        {:ok, record} -> {record, DateTime.utc_now()}
        # An outage is not a fact about the person. Keep what we had.
        {:error, _reason} -> {profile.enrichment, profile.enriched_at}
      end
    end
  end

  defp fresh_enrichment?(%Profile{enriched_at: nil}), do: false

  defp fresh_enrichment?(%Profile{enriched_at: at}) do
    DateTime.diff(DateTime.utc_now(), at, :second) < @enrichment_ttl_days * 86_400
  end

  # -- signals -------------------------------------------------------------

  @doc "The digest of mail activity a description is written from."
  def signals(%User{id: uid}) do
    totals = totals(uid)

    %{
      total_messages: totals.total,
      sent: totals.sent,
      received: totals.received,
      first_seen: totals.first_seen,
      last_seen: totals.last_seen,
      active_days: totals.active_days,
      messages_per_active_day: per_day(totals),
      top_correspondents: top_correspondents(uid),
      recent_subjects: recent_subjects(uid),
      sending_domains: sending_domains(uid),
      tags: tags(uid),
      excerpts: excerpts(uid)
    }
  end

  defp totals(uid) do
    row =
      Repo.one(
        from m in Message,
          where: m.user_id == ^uid,
          select: %{
            total: count(m.id),
            sent: filter(count(m.id), m.direction == "outbound"),
            received: filter(count(m.id), m.direction == "inbound"),
            first_seen: min(m.inserted_at),
            last_seen: max(m.inserted_at),
            active_days: fragment("count(distinct date(?))", m.inserted_at)
          }
      ) || %{}

    %{
      total: row[:total] || 0,
      sent: row[:sent] || 0,
      received: row[:received] || 0,
      first_seen: row[:first_seen] && DateTime.to_date(row[:first_seen]),
      last_seen: row[:last_seen] && DateTime.to_date(row[:last_seen]),
      active_days: row[:active_days] || 0
    }
  end

  defp per_day(%{total: 0}), do: 0
  defp per_day(%{active_days: 0}), do: 0
  defp per_day(%{total: total, active_days: days}), do: Float.round(total / days, 1)

  # Who the account actually talks to: recipients of what it sent, senders of
  # what it received, counted together.
  defp top_correspondents(uid) do
    outbound =
      from m in Message,
        where: m.user_id == ^uid and m.direction == "outbound",
        select: %{address: fragment("unnest(?)", m.recipients)}

    inbound =
      from m in Message,
        where: m.user_id == ^uid and m.direction == "inbound" and not is_nil(m.sender),
        select: %{address: m.sender}

    combined = union_all(outbound, ^inbound)

    from(c in subquery(combined),
      group_by: c.address,
      order_by: [desc: count(c.address)],
      limit: @max_correspondents,
      select: %{address: c.address, messages: count(c.address)}
    )
    |> Repo.all()
  end

  defp recent_subjects(uid) do
    Repo.all(
      from m in Message,
        where: m.user_id == ^uid and not is_nil(m.subject) and m.subject != "",
        order_by: [desc: m.inserted_at],
        limit: @max_subjects,
        select: m.subject
    )
  end

  defp sending_domains(uid) do
    Repo.all(
      from m in Message,
        join: d in assoc(m, :domain),
        where: m.user_id == ^uid,
        group_by: d.name,
        order_by: [desc: count(m.id)],
        select: d.name
    )
  end

  defp tags(uid) do
    Repo.all(
      from m in Message,
        where: m.user_id == ^uid,
        select: fragment("distinct unnest(?)", m.tags)
    )
  end

  # Body text is capped hard and only the most recent few are taken. A
  # description needs a sense of what the mail is about, not the mail.
  defp excerpts(uid) do
    Repo.all(
      from m in Message,
        where: m.user_id == ^uid and not is_nil(m.body_text) and m.body_text != "",
        order_by: [desc: m.inserted_at],
        limit: @max_excerpts,
        select: m.body_text
    )
    |> Enum.map(&truncate/1)
  end

  defp truncate(text) when byte_size(text) <= @excerpt_bytes, do: text
  defp truncate(text), do: binary_part(text, 0, @excerpt_bytes) <> "…"

  # Stored as jsonb, so struct keys have to become strings on the way in.
  defp stringify(value), do: value |> Jason.encode!() |> Jason.decode!()

  defp config, do: Application.get_env(:email_provider, __MODULE__, [])
  def enabled?, do: Keyword.get(config(), :enabled, true)
  defp async?, do: Keyword.get(config(), :async, true)
  defp min_interval, do: Keyword.get(config(), :min_interval_seconds, 0)
  def target_words, do: @target_words
end
