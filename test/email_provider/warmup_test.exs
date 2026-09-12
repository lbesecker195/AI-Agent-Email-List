defmodule EmailProvider.WarmupTest do
  use EmailProvider.DataCase, async: true

  import EmailProvider.Fixtures

  alias EmailProvider.Warmup

  describe "the ladder" do
    test "a brand new domain starts on stage 1 at 10 a day" do
      domain = domain_fixture(user_fixture())

      assert {1, _stage} = Warmup.current_stage(domain)
      assert Warmup.daily_limit(domain) == 10
    end

    test "stays on stage 1 until it has sent on five separate days" do
      domain = user_fixture() |> domain_fixture() |> record_sending_days(4)

      assert {1, _} = Warmup.current_stage(domain)
      assert Warmup.daily_limit(domain) == 10
    end

    test "graduates to 20 a day on the fifth sending day" do
      domain = user_fixture() |> domain_fixture() |> record_sending_days(5)

      assert {2, _} = Warmup.current_stage(domain)
      assert Warmup.daily_limit(domain) == 20
    end

    test "idle days do not count as warmup" do
      domain = user_fixture() |> domain_fixture()

      # Created well in the past, but has never sent.
      set_warmup(domain, %{first_sent_on: Date.add(Date.utc_today(), -60)})

      assert Warmup.sending_days(domain) == 0
      assert Warmup.daily_limit(domain) == 10
    end

    # A domain that maxes out rung 1 sends 5 days x 10 = 50 messages, so rung 2
    # runs from 50 to 1,050, rung 3 from 1,050 to 2,050, rung 4 from 2,050 to
    # 12,050. Each rung's number is its own, not a running lifetime total.
    defp warmed(lifetime_sent) do
      user_fixture()
      |> domain_fixture()
      |> record_sending_days(5, 10)
      |> set_warmup(%{lifetime_sent: lifetime_sent})
    end

    test "stays on 20 a day until it has sent a thousand on that rung" do
      assert {2, _} = Warmup.current_stage(warmed(1_049))
      assert Warmup.daily_limit(warmed(1_049)) == 20
    end

    test "climbs to 100 a day after a thousand messages on the 20-a-day rung" do
      assert {3, _} = Warmup.current_stage(warmed(1_050))
      assert Warmup.daily_limit(warmed(1_050)) == 100
    end

    test "the 100-a-day rung needs a further thousand, not a thousand in total" do
      # The literal reading of "100/day until they hit 1000" would graduate here.
      # It does not: this rung wants its own 1,000 on top of the previous one.
      assert Warmup.daily_limit(warmed(1_500)) == 100
      assert Warmup.daily_limit(warmed(2_049)) == 100
      assert Warmup.daily_limit(warmed(2_050)) == 1_000
    end

    test "the 1000-a-day rung needs a further ten thousand" do
      assert {4, _} = Warmup.current_stage(warmed(2_050))
      assert Warmup.daily_limit(warmed(12_049)) == 1_000
    end

    test "is uncapped once every rung is behind it" do
      assert {5, _} = Warmup.current_stage(warmed(12_050))
      assert Warmup.daily_limit(warmed(12_050)) == :unlimited
    end

    test "a domain that trickled through rung 1 reaches rung 3 sooner" do
      # Five days at one a day is five messages, so rung 2 runs 5 -> 1,005.
      trickled =
        user_fixture()
        |> domain_fixture()
        |> record_sending_days(5, 1)
        |> set_warmup(%{lifetime_sent: 1_005})

      assert Warmup.daily_limit(trickled) == 100
      # The same lifetime total is still rung 2 for a domain that sent harder.
      assert Warmup.daily_limit(warmed(1_005)) == 20
    end

    test "reports progress through the current rung, not a lifetime total" do
      status = Warmup.status(warmed(1_300))

      assert status.stage == 3
      assert status.sent_this_stage == 250
      assert status.stage_target == 1_000
      assert status.remaining_this_stage == 750
      assert status.graduates_at_lifetime_total == 2_050
    end

    test "warmup can be switched off for a domain" do
      domain = user_fixture() |> domain_fixture() |> set_warmup(%{warmup_enabled: false})
      assert Warmup.daily_limit(domain) == :unlimited
    end
  end

  describe "reserving capacity" do
    test "allows sends up to the cap and refuses the one after" do
      domain = domain_fixture(user_fixture())

      for _ <- 1..10, do: assert({:ok, _} = Warmup.reserve(domain, 1))

      domain = reload(domain)
      assert {:error, {:rate_limited, details}} = Warmup.reserve(domain, 1)
      assert details.daily_limit == 10
      assert details.sent_today == 10
      assert details.remaining_today == 0
    end

    test "refuses a batch bigger than the whole day's allowance without spending any of it" do
      domain = domain_fixture(user_fixture())

      assert {:error, {:rate_limited, _}} = Warmup.reserve(domain, 11)
      assert Warmup.sent_today(domain) == 0
    end

    test "a batch counts once per recipient" do
      domain = domain_fixture(user_fixture())

      assert {:ok, %{remaining: 6}} = Warmup.reserve(domain, 4)
      assert Warmup.sent_today(domain) == 4
    end

    test "a reservation is refused even when the caller's view of the counter is stale" do
      domain = domain_fixture(user_fixture())

      # Another caller spends the whole day's allowance after `domain` was read.
      {:ok, _} = Warmup.reserve(domain, 10)

      # The in-process check cannot catch this: 1 is well under a limit of 10.
      # Only the guard inside the upsert sees that the total would overrun.
      assert {:error, {:rate_limited, details}} = Warmup.reserve(domain, 1)
      assert details.sent_today == 10
      assert Warmup.sent_today(domain) == 10
    end

    test "many processes reserving at once cannot exceed the cap between them" do
      domain = domain_fixture(user_fixture())
      parent = self()

      tasks =
        for _ <- 1..20 do
          Task.async(fn ->
            Ecto.Adapters.SQL.Sandbox.allow(EmailProvider.Repo, parent, self())
            Warmup.reserve(domain, 1)
          end)
        end

      results = Task.await_many(tasks, 15_000)

      assert Enum.count(results, &match?({:ok, _}, &1)) == 10
      assert Warmup.sent_today(domain) == 10
      assert reload(domain).lifetime_sent == 10
    end

    test "releasing gives back both the daily and the lifetime count" do
      domain = domain_fixture(user_fixture())

      {:ok, _} = Warmup.reserve(domain, 3)
      assert Warmup.sent_today(domain) == 3
      assert reload(domain).lifetime_sent == 3

      :ok = Warmup.release(domain, 2)
      assert Warmup.sent_today(domain) == 1
      assert reload(domain).lifetime_sent == 1
    end

    test "the first send stamps the domain's first sending day" do
      domain = domain_fixture(user_fixture())
      assert is_nil(domain.first_sent_on)

      {:ok, _} = Warmup.reserve(domain, 1)
      assert reload(domain).first_sent_on == Date.utc_today()
    end
  end

  describe "status" do
    test "reports the rung, the headroom and what graduates it" do
      domain = domain_fixture(user_fixture())
      {:ok, _} = Warmup.reserve(domain, 3)

      status = Warmup.status(reload(domain))

      assert status.stage == 1
      assert status.daily_limit == 10
      assert status.sent_today == 3
      assert status.remaining_today == 7
      assert status.graduates_when =~ "5 separate days"
    end
  end

  defp reload(domain), do: EmailProvider.Repo.get!(EmailProvider.Domains.Domain, domain.id)
end
