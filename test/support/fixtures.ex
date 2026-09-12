defmodule EmailProvider.Fixtures do
  @moduledoc "Builders for the records most tests need."

  alias EmailProvider.{Accounts, Domains, Repo}
  alias EmailProvider.Domains.Domain

  def unique_email, do: "user#{System.unique_integer([:positive])}@example.test"

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      Accounts.register_user(
        Map.merge(
          %{email: unique_email(), name: "Test User", password: "correct horse battery"},
          attrs
        )
      )

    user
  end

  def api_key_fixture(user, opts \\ []) do
    {:ok, key, plaintext} = Accounts.create_api_key(user, opts)
    {key, plaintext}
  end

  @doc """
  A domain. `verified: true` marks its DNS as checked without touching the
  network — DNS is exercised in its own tests, not in every send test.
  """
  def domain_fixture(user, attrs \\ %{}) do
    name = Map.get(attrs, :name, "d#{System.unique_integer([:positive])}.example.test")
    {:ok, domain, _smtp_password} = Domains.create_domain(user, %{"name" => name})

    if Map.get(attrs, :verified, true) do
      now = DateTime.utc_now()

      domain
      |> Domain.changeset(%{
        state: "active",
        spf_verified_at: now,
        dkim_verified_at: now,
        last_checked_at: now
      })
      |> Repo.update!()
    else
      domain
    end
  end

  @doc "Set a domain's warmup counters directly, to test a rung without sending."
  def set_warmup(domain, attrs) do
    domain |> Domain.changeset(attrs) |> Repo.update!()
  end

  @doc """
  Give a domain a sending history: `days` past days at `per_day` messages each.

  `per_day` matters to the ladder, not just `days`: a `:stage_volume` rung
  starts counting from whatever the domain had already sent when it arrived, so
  a domain that maxed out its first rung starts the next one further along than
  one that trickled.
  """
  def record_sending_days(domain, days, per_day \\ 1) when is_integer(days) do
    today = Date.utc_today()

    for offset <- 1..days//1 do
      Repo.insert!(%EmailProvider.Warmup.SendingStat{
        domain_id: domain.id,
        day: Date.add(today, -offset),
        sent_count: per_day
      })
    end

    domain
  end

  def send_params(domain, overrides \\ %{}) do
    Map.merge(
      %{
        "from" => "sender@#{domain.name}",
        "to" => "recipient@elsewhere.test",
        "subject" => "Hello",
        "text" => "A perfectly ordinary message."
      },
      overrides
    )
  end
end
