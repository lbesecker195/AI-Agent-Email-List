defmodule EmailProvider.ReputationTest do
  use EmailProvider.DataCase, async: true

  import EmailProvider.Fixtures

  alias EmailProvider.Mail.Message
  alias EmailProvider.Repo
  alias EmailProvider.Reputation

  defp refusal(user, domain, opts \\ []) do
    at = Keyword.get(opts, :at, DateTime.utc_now())

    %Message{}
    |> Message.changeset(%{
      user_id: user.id,
      domain_id: domain.id,
      direction: "outbound",
      storage_key: "test-#{System.unique_integer([:positive])}",
      sender: "me@#{domain.name}",
      recipients: ["someone@elsewhere.test"],
      status: "rejected",
      moderation_flagged: true,
      moderation_action: "blocked"
    })
    |> Repo.insert!()
    |> Ecto.Changeset.change(inserted_at: DateTime.truncate(at, :microsecond))
    |> Repo.update!()
  end

  describe "tiers" do
    test "an account with nothing is new" do
      assert Reputation.tier(user_fixture()) == :new
    end

    test "registering a domain is commitment, verifying one is proof" do
      user = user_fixture()

      unverified = domain_fixture(user, %{verified: false})
      assert Reputation.tier(user) == :committed

      _verified = domain_fixture(user)
      assert Reputation.tier(user) == :proven

      # And the account that only ever registered is still only committed.
      assert unverified.state != "active"
    end
  end

  describe "the domain limit" do
    test "verifying opens it up; merely registering does not" do
      user = user_fixture()
      assert Reputation.domain_limit(user) == 3

      # The limit caps registrations, so a registration must not raise it —
      # otherwise the lower figure gates nothing at all.
      domain_fixture(user, %{verified: false})
      assert Reputation.domain_limit(user) == 3

      domain_fixture(user)
      assert Reputation.domain_limit(user) == 50
    end

    test "refuses past the limit, and says how to raise it" do
      user = user_fixture()

      for _ <- 1..3, do: domain_fixture(user, %{verified: false})

      assert {:error, message} = Reputation.can_add_domain?(user)
      assert message =~ "limit of 3 domains"
      assert message =~ "verify_domain"
      assert message =~ "50"
    end
  end

  describe "screening refusals" do
    setup do
      user = user_fixture()
      %{user: user, domain: domain_fixture(user)}
    end

    test "a clean account may send", %{user: user} do
      assert Reputation.check_sending(user) == :ok
    end

    test "enough refusals in a day pause sending", %{user: user, domain: domain} do
      for _ <- 1..8, do: refusal(user, domain)

      assert {:error, message} = Reputation.check_sending(user)
      assert message =~ "paused"
      assert message =~ "Do not keep retrying"
    end

    test "old refusals do not count", %{user: user, domain: domain} do
      old = DateTime.add(DateTime.utc_now(), -2, :day)
      for _ <- 1..20, do: refusal(user, domain, at: old)

      assert Reputation.recent_refusals(user) == 0
      assert Reputation.check_sending(user) == :ok
    end

    test "persistent refusals suspend the account", %{user: user, domain: domain} do
      for _ <- 1..25, do: refusal(user, domain)

      assert {:error, message} = Reputation.check_sending(user)
      assert message =~ "suspended"
      assert Repo.reload!(user).status == "suspended"
    end

    test "a message refused for other reasons is not held against anyone",
         %{user: user, domain: domain} do
      # status "rejected" without the screening flag: a bounce, not abuse.
      %Message{}
      |> Message.changeset(%{
        user_id: user.id,
        domain_id: domain.id,
        direction: "outbound",
        storage_key: "bounce-1",
        sender: "me@#{domain.name}",
        recipients: ["someone@elsewhere.test"],
        status: "rejected",
        moderation_flagged: false
      })
      |> Repo.insert!()

      assert Reputation.recent_refusals(user) == 0
    end
  end

  test "the summary reports everything a dashboard needs" do
    user = user_fixture()
    summary = Reputation.summary(user)

    assert summary.tier == :new
    assert summary.domain_limit == 3
    assert summary.refusals_last_24h == 0
    assert summary.sending_allowed
  end
end
