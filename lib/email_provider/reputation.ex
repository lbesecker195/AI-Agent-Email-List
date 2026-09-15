defmodule EmailProvider.Reputation do
  @moduledoc """
  How much an account is trusted, and what that buys it.

  The tension in a free service an agent can open by itself is that the same
  property making it useful makes it attractive to abuse. The answer here is not
  to be stingy with everyone; it is to be generous in proportion to what an
  account has actually shown.

  ## The tiers

    * `:new` — signed up, nothing else. Can add a few domains and little else.
      Costs nothing to reach, so it is worth nothing.
    * `:committed` — has registered a domain. Someone chose a name and intends
      to publish DNS for it.
    * `:proven` — has a verified domain. They control DNS for a real domain,
      which is the first thing in this whole flow that a throwaway cannot fake
      at scale. This is where the limits open up.

  ## Screening as a reputation signal

  Every outbound message already goes through content screening. Until now a
  refusal vanished: the send returned an error and nothing was written down, so
  an account could be refused a thousand times and look identical to one that
  had never been refused.

  Refusals are now recorded, and repeated ones narrow an account and eventually
  suspend it. This is the cheapest abuse signal available, because the work of
  detecting it is already being done for another reason.
  """

  import Ecto.Query, warn: false

  alias EmailProvider.Repo
  alias EmailProvider.Accounts.User
  alias EmailProvider.Domains.Domain
  alias EmailProvider.Mail.Message

  @doc "What tier an account is in."
  def tier(%User{id: id}) do
    states =
      Repo.all(from d in Domain, where: d.user_id == ^id, select: d.state)

    cond do
      Enum.any?(states, &(&1 == "active")) -> :proven
      states != [] -> :committed
      true -> :new
    end
  end

  @doc """
  How many domains this account may hold.

  Generous once a domain is verified, because by then the account has done
  something a bulk abuser will not: proved control of real DNS.
  """
  def domain_limit(user) do
    case tier(user) do
      :new -> config(:domains_new, 3)
      :committed -> config(:domains_committed, 10)
      :proven -> config(:domains_proven, 50)
    end
  end

  @doc "Whether this account may add another domain."
  def can_add_domain?(%User{id: id} = user) do
    count = Repo.one(from d in Domain, where: d.user_id == ^id, select: count(d.id))
    limit = domain_limit(user)

    if count < limit do
      :ok
    else
      {:error,
       "This account is at its limit of #{limit} domains. Verifying a domain you already " <>
         "have raises the limit."}
    end
  end

  @doc """
  Whether this account is currently allowed to send at all.

  Separate from the warmup ladder, which caps how much a *domain* sends. This
  caps what a *sender* may do after repeatedly trying to push content that
  screening refused.
  """
  def check_sending(%User{} = user) do
    refusals = recent_refusals(user)

    cond do
      refusals >= config(:refusals_before_suspension, 25) ->
        suspend(user, refusals)

        {:error,
         "This account has been suspended after #{refusals} messages were refused by content " <>
           "screening in the last 24 hours. Contact the operator if this is wrong."}

      refusals >= config(:refusals_before_throttle, 8) ->
        {:error,
         "Sending is paused on this account: #{refusals} messages were refused by content " <>
           "screening in the last 24 hours. It resumes automatically once those age out. " <>
           "Do not keep retrying refused content."}

      true ->
        :ok
    end
  end

  @doc "Refused messages for this account in the last day."
  def recent_refusals(%User{id: id}) do
    since = DateTime.add(DateTime.utc_now(), -86_400, :second)

    Repo.one(
      from m in Message,
        where:
          m.user_id == ^id and m.status == "rejected" and m.moderation_flagged == true and
            m.inserted_at >= ^since,
        select: count(m.id)
    ) || 0
  end

  # Suspending flips the account's status, which the API key lookup and the
  # browser session both already check, so it takes effect on the next request
  # rather than at the end of some session.
  defp suspend(%User{} = user, refusals) do
    user
    |> User.changeset(%{status: "suspended"})
    |> Repo.update()

    require Logger
    Logger.warning("suspended #{user.email}: #{refusals} screening refusals in 24h")
  end

  @doc "Everything about an account's standing, for the API and the dashboard."
  def summary(user) do
    tier = tier(user)

    %{
      tier: tier,
      domain_limit: domain_limit(user),
      refusals_last_24h: recent_refusals(user),
      sending_allowed: check_sending(user) == :ok
    }
  end

  defp config(key, default) do
    Application.get_env(:email_provider, __MODULE__, []) |> Keyword.get(key, default)
  end
end
