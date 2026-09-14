defmodule EmailProvider.Admin do
  @moduledoc """
  Service-wide counts for the operator's dashboard.

  Every figure here spans all accounts, which is the whole point and also the
  reason this module is only ever reached through the admin token. Nothing in
  here is scoped to a customer.

  Counts are gathered with aggregate queries using `FILTER`, so each group is a
  single pass over the table rather than one query per number. The tables that
  grow without limit are `messages` and `events`, and both are indexed on
  `(domain_id, inserted_at)`; when a full count of those starts to hurt, the
  answer is a periodically refreshed summary table rather than a slower query.
  """

  import Ecto.Query, warn: false

  alias EmailProvider.Repo
  alias EmailProvider.Accounts.{ApiKey, User}
  alias EmailProvider.Domains.Domain
  alias EmailProvider.Mail.{Event, Message}
  alias EmailProvider.Profiles.Profile
  alias EmailProvider.Suppressions.Suppression

  @doc "Everything the dashboard shows, in one call."
  def overview do
    %{
      generated_at: DateTime.utc_now(),
      accounts: accounts(),
      domains: domains(),
      messages: messages(),
      suppressions: suppressions(),
      moderation: moderation(),
      warmup: warmup(),
      events: events(),
      busiest_domains: busiest_domains(),
      recent_accounts: recent_accounts()
    }
  end

  defp ago(days), do: DateTime.add(DateTime.utc_now(), -days * 86_400, :second)
  defp hours_ago(hours), do: DateTime.add(DateTime.utc_now(), -hours * 3600, :second)

  def accounts do
    week = ago(7)
    month = ago(30)

    Repo.one(
      from u in User,
        select: %{
          total: count(u.id),
          active: filter(count(u.id), u.status == "active"),
          suspended: filter(count(u.id), u.status == "suspended"),
          new_this_week: filter(count(u.id), u.inserted_at >= ^week),
          new_this_month: filter(count(u.id), u.inserted_at >= ^month)
        }
    )
    |> Map.put(:api_keys, Repo.one(from k in ApiKey, where: k.kind == "api", select: count(k.id)))
    |> Map.put(
      :with_profiles,
      Repo.one(from p in Profile, where: p.version > 0, select: count(p.id))
    )
  end

  def domains do
    week = ago(7)

    Repo.one(
      from d in Domain,
        select: %{
          total: count(d.id),
          active: filter(count(d.id), d.state == "active"),
          unverified: filter(count(d.id), d.state == "unverified"),
          disabled: filter(count(d.id), d.state == "disabled"),
          new_this_week: filter(count(d.id), d.inserted_at >= ^week),
          # A domain that has sent at least once, which is a better measure of
          # adoption than one that was merely added.
          has_sent: filter(count(d.id), d.lifetime_sent > 0)
        }
    )
  end

  def messages do
    day = hours_ago(24)
    week = ago(7)

    Repo.one(
      from m in Message,
        select: %{
          total: count(m.id),
          outbound: filter(count(m.id), m.direction == "outbound"),
          inbound: filter(count(m.id), m.direction == "inbound"),
          queued: filter(count(m.id), m.status == "queued"),
          scheduled: filter(count(m.id), m.status == "scheduled"),
          sent: filter(count(m.id), m.status == "sent"),
          delivered: filter(count(m.id), not is_nil(m.delivered_at)),
          failed: filter(count(m.id), m.status == "failed"),
          test_mode: filter(count(m.id), m.test_mode == true),
          last_24h: filter(count(m.id), m.inserted_at >= ^day),
          last_7d: filter(count(m.id), m.inserted_at >= ^week),
          inbox: filter(count(m.id), m.folder == "inbox"),
          spam: filter(count(m.id), m.folder == "spam")
        }
    )
  end

  def suppressions do
    Repo.one(
      from s in Suppression,
        select: %{
          total: count(s.id),
          bounces: filter(count(s.id), s.type == "bounce"),
          unsubscribes: filter(count(s.id), s.type == "unsubscribe"),
          complaints: filter(count(s.id), s.type == "complaint")
        }
    )
  end

  @doc """
  What content screening has done.

  Note what is missing: outbound messages refused by screening are not counted,
  because they are never stored. `Mail.send_message/3` returns the refusal before
  it persists anything, so a blocked message leaves no row and no event. That
  makes "how much are we refusing" unanswerable, which for a moderation
  dashboard is the most interesting question of the lot.
  """
  def moderation do
    Repo.one(
      from m in Message,
        select: %{
          screened: filter(count(m.id), not is_nil(m.moderation_checked_at)),
          unscreened: filter(count(m.id), is_nil(m.moderation_checked_at)),
          flagged: filter(count(m.id), m.moderation_flagged == true),
          filed_spam: filter(count(m.id), m.moderation_action == "filed_spam")
        }
    )
    |> Map.put(:outbound_refusals_recorded, false)
  end

  @doc "How domains are spread across the warmup ladder."
  def warmup do
    Repo.all(from d in Domain, where: d.state == "active")
    |> Enum.group_by(fn domain ->
      {index, stage} = EmailProvider.Warmup.current_stage(domain)
      {index, stage.daily_limit}
    end)
    |> Enum.map(fn {{index, limit}, domains} ->
      %{
        stage: index,
        daily_limit: if(limit == :unlimited, do: "unlimited", else: limit),
        domains: length(domains)
      }
    end)
    |> Enum.sort_by(& &1.stage)
  end

  def events do
    from(e in Event, group_by: e.type, select: {e.type, count(e.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc "The domains moving the most mail, which is where any problem will show first."
  def busiest_domains(limit \\ 10) do
    Repo.all(
      from d in Domain,
        left_join: m in Message,
        on: m.domain_id == d.id,
        group_by: [d.id, d.name, d.state, d.lifetime_sent],
        order_by: [desc: count(m.id)],
        limit: ^limit,
        select: %{
          name: d.name,
          state: d.state,
          lifetime_sent: d.lifetime_sent,
          messages: count(m.id),
          inbound: filter(count(m.id), m.direction == "inbound")
        }
    )
  end

  @doc "Newest accounts, with what they have actually done."
  def recent_accounts(limit \\ 15) do
    Repo.all(
      from u in User,
        left_join: d in Domain,
        on: d.user_id == u.id,
        group_by: [u.id, u.email, u.status, u.inserted_at],
        order_by: [desc: u.inserted_at],
        limit: ^limit,
        select: %{
          email: u.email,
          status: u.status,
          joined: u.inserted_at,
          domains: count(d.id)
        }
    )
  end
end
