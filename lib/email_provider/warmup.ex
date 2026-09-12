defmodule EmailProvider.Warmup do
  @moduledoc """
  Automatic sending warmup, per domain.

  A new domain that opens at full volume gets filtered, so every domain climbs
  a ladder: a small daily cap at first, widening as the domain proves itself,
  and eventually uncapped.

  ## The ladder

  Stages are configured, not hard-coded, under `config :email_provider,
  #{inspect(__MODULE__)}, stages: [...]`. Each stage names a daily cap and the
  condition that graduates it:

      %{daily_limit: 10,        until: {:sending_days, 5}}
      %{daily_limit: 20,        until: {:stage_volume, 1_000}}
      %{daily_limit: 100,       until: {:stage_volume, 1_000}}
      %{daily_limit: 1_000,     until: {:stage_volume, 10_000}}
      %{daily_limit: :unlimited, until: :never}

  The first stage whose condition is *not* yet met is the current one.

  Two kinds of condition:

    * `{:sending_days, n}` — days the domain actually sent on, not days since
      it was created. A domain that sat idle for a week has not warmed up for a
      week, which is the whole point of the measure.

    * `{:stage_volume, n}` — messages sent *while on that rung*, not lifetime.
      Each rung's number is its own allowance: a domain leaves the 20/day rung
      after 1,000 messages at 20/day, then leaves the 100/day rung after a
      further 1,000. The absolute lifetime totals that fall out of the default
      ladder are roughly 1,050, then 2,050, then 12,050, depending on how much
      the domain sent during its first five days.

  `{:lifetime_sent, n}` is also accepted for a rung that should graduate at an
  absolute total rather than a per-rung one.

  ## Counting

  Reservation is a single atomic upsert. Two requests arriving together cannot
  both read "9 sent today" and both be allowed: the second one's update is
  refused by the same statement that would have applied it. Capacity is
  reserved before dispatch and released if the send never happens, so a crash
  between the two costs the domain a few sends rather than letting it overrun.

  Test-mode sends are neither reserved nor counted. They never touch the wire,
  so they cannot affect reputation.
  """

  import Ecto.Query, warn: false

  alias EmailProvider.Repo
  alias EmailProvider.Domains.Domain
  alias EmailProvider.Warmup.SendingStat

  @default_stages [
    %{daily_limit: 10, until: {:sending_days, 5}},
    %{daily_limit: 20, until: {:stage_volume, 1_000}},
    %{daily_limit: 100, until: {:stage_volume, 1_000}},
    %{daily_limit: 1_000, until: {:stage_volume, 10_000}},
    %{daily_limit: :unlimited, until: :never}
  ]

  @doc "The configured ladder."
  def stages do
    Application.get_env(:email_provider, __MODULE__, [])
    |> Keyword.get(:stages, @default_stages)
  end

  @doc """
  The stage a domain is currently on, as `{index, stage}` with index from 1.
  """
  def current_stage(%Domain{} = domain) do
    %{index: index, stage: stage} = resolve(domain)
    {index, stage}
  end

  @doc """
  Work out which rung a domain is on, and where that rung starts and ends.

  Returns `%{index:, stage:, floor:, ceiling:}` — `floor` is the lifetime total
  at which the current rung began and `ceiling` the total at which it ends
  (`:never` on the final rung). Because a `:stage_volume` rung measures what was
  sent *on that rung*, each rung's floor is the previous rung's ceiling, and the
  walk has to accumulate rather than compare against a fixed number.
  """
  def resolve(%Domain{} = domain) do
    facts = %{
      domain: domain,
      sending_days: sending_days(domain),
      lifetime_sent: domain.lifetime_sent
    }

    walk(stages(), 1, 0, facts)
  end

  # Last rung: nothing graduates it, whatever its condition says.
  defp walk([stage], index, floor, _facts) do
    %{index: index, stage: stage, floor: floor, ceiling: :never}
  end

  defp walk([stage | rest], index, floor, facts) do
    case ceiling_of(stage.until, floor, facts) do
      # Nothing graduates this rung, so the domain stays on it.
      :never ->
        %{index: index, stage: stage, floor: floor, ceiling: :never}

      {:days, needed} ->
        if facts.sending_days < needed do
          %{index: index, stage: stage, floor: floor, ceiling: {:sending_days, needed}}
        else
          # The next rung starts counting from whatever the domain had sent by
          # the end of its last qualifying day.
          walk(rest, index + 1, lifetime_after_sending_days(facts.domain, needed), facts)
        end

      ceiling when is_integer(ceiling) ->
        if facts.lifetime_sent < ceiling do
          %{index: index, stage: stage, floor: floor, ceiling: ceiling}
        else
          walk(rest, index + 1, ceiling, facts)
        end
    end
  end

  defp ceiling_of(:never, _floor, _facts), do: :never
  defp ceiling_of({:sending_days, n}, _floor, _facts), do: {:days, n}
  defp ceiling_of({:stage_volume, n}, floor, _facts), do: floor + n
  defp ceiling_of({:lifetime_sent, n}, _floor, _facts), do: n

  # What the domain had sent by the close of its nth sending day. Derived from
  # the daily rows rather than stored, so there is one source of truth and no
  # counter to drift.
  defp lifetime_after_sending_days(%Domain{id: id}, n) do
    first_days =
      from s in SendingStat,
        where: s.domain_id == ^id and s.sent_count > 0,
        order_by: [asc: s.day],
        limit: ^n,
        select: %{sent_count: s.sent_count}

    Repo.one(from s in subquery(first_days), select: coalesce(sum(s.sent_count), 0)) || 0
  end

  @doc "Today's cap for a domain. `:unlimited` once it has graduated."
  def daily_limit(%Domain{warmup_enabled: false}), do: :unlimited

  def daily_limit(%Domain{} = domain) do
    {_i, stage} = current_stage(domain)
    stage.daily_limit
  end

  @doc "How many distinct days this domain has actually sent on."
  def sending_days(%Domain{id: id}) do
    Repo.one(
      from s in SendingStat,
        where: s.domain_id == ^id and s.sent_count > 0,
        select: count(s.id)
    ) || 0
  end

  @doc "How many this domain has sent today."
  def sent_today(%Domain{id: id}, day \\ Date.utc_today()) do
    Repo.one(
      from s in SendingStat,
        where: s.domain_id == ^id and s.day == ^day,
        select: s.sent_count
    ) || 0
  end

  @doc """
  Reserve capacity for `count` recipients, atomically.

  Returns `{:ok, %{reserved: count, remaining: n}}`, or
  `{:error, {:rate_limited, details}}` when the domain is at its cap. On
  success the domain's lifetime counter has already moved.
  """
  def reserve(%Domain{} = domain, count) when is_integer(count) and count > 0 do
    if domain.warmup_enabled do
      do_reserve(domain, count, daily_limit(domain))
    else
      do_reserve(domain, count, :unlimited)
    end
  end

  defp do_reserve(domain, count, :unlimited) do
    bump(domain, count, nil)
    {:ok, %{reserved: count, remaining: :unlimited}}
  end

  defp do_reserve(domain, count, limit) when is_integer(limit) do
    used = sent_today(domain)

    cond do
      # A single batch larger than the whole day's allowance can never fit, and
      # the upsert below would not catch it on the insert path.
      count > limit ->
        {:error, {:rate_limited, rate_limit_details(domain, limit, used, count)}}

      true ->
        case bump(domain, count, limit) do
          {:ok, new_count} ->
            {:ok, %{reserved: count, remaining: limit - new_count}}

          :refused ->
            {:error,
             {:rate_limited, rate_limit_details(domain, limit, sent_today(domain), count)}}
        end
    end
  end

  # One statement. The `WHERE` on the conflict clause is what makes two
  # concurrent reservations safe: at most one of them can be the update that
  # keeps the total inside the cap.
  defp bump(%Domain{} = domain, count, limit) do
    day = Date.utc_today()

    {sql, params} =
      if is_integer(limit) do
        {"""
         INSERT INTO sending_stats (id, domain_id, day, sent_count, inserted_at, updated_at)
         VALUES ($1, $2, $3, $4, now(), now())
         ON CONFLICT (domain_id, day)
         DO UPDATE SET sent_count = sending_stats.sent_count + $4, updated_at = now()
         WHERE sending_stats.sent_count + $4 <= $5
         RETURNING sent_count
         """, [Ecto.UUID.bingenerate(), Ecto.UUID.dump!(domain.id), day, count, limit]}
      else
        {"""
         INSERT INTO sending_stats (id, domain_id, day, sent_count, inserted_at, updated_at)
         VALUES ($1, $2, $3, $4, now(), now())
         ON CONFLICT (domain_id, day)
         DO UPDATE SET sent_count = sending_stats.sent_count + $4, updated_at = now()
         RETURNING sent_count
         """, [Ecto.UUID.bingenerate(), Ecto.UUID.dump!(domain.id), day, count]}
      end

    case Repo.query!(sql, params) do
      %{rows: [[new_count]]} ->
        bump_lifetime(domain, count, day)
        {:ok, new_count}

      %{rows: []} ->
        :refused
    end
  end

  defp bump_lifetime(%Domain{id: id}, count, day) do
    Repo.update_all(
      from(d in Domain, where: d.id == ^id),
      inc: [lifetime_sent: count],
      set: [updated_at: DateTime.utc_now()]
    )

    # Stamp the first send date once, without clobbering it later.
    Repo.update_all(
      from(d in Domain, where: d.id == ^id and is_nil(d.first_sent_on)),
      set: [first_sent_on: day]
    )
  end

  @doc """
  Hand capacity back when a reserved send did not go out.

  The daily counter and the lifetime counter both come back down; the lifetime
  counter is what the ladder reads, and a message that never left should not
  advance a domain toward its next stage.
  """
  def release(%Domain{id: id}, count) when is_integer(count) and count > 0 do
    day = Date.utc_today()

    Repo.update_all(
      from(s in SendingStat,
        where: s.domain_id == ^id and s.day == ^day and s.sent_count >= ^count
      ),
      inc: [sent_count: -count]
    )

    Repo.update_all(
      from(d in Domain, where: d.id == ^id and d.lifetime_sent >= ^count),
      inc: [lifetime_sent: -count]
    )

    :ok
  end

  defp rate_limit_details(domain, limit, used, requested) do
    resolved = resolve(domain)

    %{
      stage: resolved.index,
      daily_limit: limit,
      sent_today: used,
      remaining_today: max(limit - used, 0),
      requested: requested,
      lifetime_sent: domain.lifetime_sent,
      sending_days: sending_days(domain),
      retry_after_seconds: seconds_until_utc_midnight()
    }
    |> Map.merge(progress(resolved, domain))
  end

  @doc "The shape the limits endpoint returns."
  def status(%Domain{} = domain) do
    resolved = resolve(domain)
    limit = daily_limit(domain)
    used = sent_today(domain)

    %{
      warmup_enabled: domain.warmup_enabled,
      stage: resolved.index,
      stage_count: length(stages()),
      daily_limit: if(limit == :unlimited, do: "unlimited", else: limit),
      sent_today: used,
      remaining_today: if(limit == :unlimited, do: "unlimited", else: max(limit - used, 0)),
      lifetime_sent: domain.lifetime_sent,
      sending_days: sending_days(domain),
      first_sent_on: domain.first_sent_on,
      resets_at: utc_midnight()
    }
    |> Map.merge(progress(resolved, domain))
  end

  @doc """
  How far through the current rung a domain is.

  Reported as progress on the rung rather than as a lifetime total, because
  that is how the ladder is configured and it is the number that answers "how
  much longer at this cap?".
  """
  def progress(%{ceiling: :never}, _domain) do
    %{
      sent_this_stage: nil,
      stage_target: nil,
      remaining_this_stage: nil,
      graduates_when: "never, this is the final rung"
    }
  end

  def progress(%{ceiling: {:sending_days, needed}} = resolved, domain) do
    days = sending_days(domain)

    %{
      sent_this_stage: max(domain.lifetime_sent - resolved.floor, 0),
      stage_target: nil,
      remaining_this_stage: nil,
      sending_days_remaining: max(needed - days, 0),
      graduates_when: "after sending on #{needed} separate days"
    }
  end

  def progress(%{ceiling: ceiling} = resolved, domain) when is_integer(ceiling) do
    target = ceiling - resolved.floor
    sent = max(domain.lifetime_sent - resolved.floor, 0)

    %{
      sent_this_stage: sent,
      stage_target: target,
      remaining_this_stage: max(target - sent, 0),
      graduates_at_lifetime_total: ceiling,
      graduates_when: "after #{target} messages on this rung (#{max(target - sent, 0)} to go)"
    }
  end

  defp utc_midnight do
    Date.utc_today() |> Date.add(1) |> DateTime.new!(~T[00:00:00], "Etc/UTC")
  end

  defp seconds_until_utc_midnight do
    DateTime.diff(utc_midnight(), DateTime.utc_now())
  end
end
