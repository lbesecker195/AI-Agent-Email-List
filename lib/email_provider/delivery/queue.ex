defmodule EmailProvider.Delivery.Queue do
  @moduledoc """
  Polls the messages table and dispatches what is due.

  The queue is the messages table itself rather than a separate broker. That
  costs a poll every few seconds and buys exactly-one-owner semantics for free:
  a claim is an UPDATE guarded by the current status, so two nodes racing for
  the same message cannot both win, and a node that dies mid-send leaves a row
  that the stale-claim sweep returns to the queue.
  """

  use GenServer
  require Logger

  import Ecto.Query

  alias EmailProvider.{Mail, Repo}
  alias EmailProvider.Mail.Message

  @default_interval 5_000
  @default_batch 50
  # A message claimed but not resolved within this long is assumed orphaned by
  # a crashed node and is retried.
  @stale_claim_minutes 15
  @max_attempts 5

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Run one pass immediately. Tests call this instead of waiting for the timer."
  def tick_now, do: GenServer.call(__MODULE__, :tick, 30_000)

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval, config(:interval, @default_interval))

    if Keyword.get(opts, :enabled, config(:enabled, true)) do
      {:ok, schedule(%{interval: interval, enabled: true})}
    else
      {:ok, %{interval: interval, enabled: false}}
    end
  end

  @impl true
  def handle_call(:tick, _from, state) do
    {:reply, run_once(), state}
  end

  @impl true
  def handle_info(:tick, state) do
    run_once()
    {:noreply, schedule(state)}
  end

  def handle_info(_other, state), do: {:noreply, state}

  defp schedule(%{enabled: true, interval: interval} = state) do
    Process.send_after(self(), :tick, interval)
    state
  end

  defp schedule(state), do: state

  defp run_once do
    requeue_stale()

    due()
    |> Enum.map(&dispatch/1)
    |> Enum.frequencies_by(fn
      {:ok, _} -> :ok
      {:error, _} -> :error
    end)
  end

  defp due do
    now = DateTime.utc_now()
    batch = config(:batch_size, @default_batch)

    Repo.all(
      from m in Message,
        where:
          m.direction == "outbound" and
            (m.status == "queued" or (m.status == "scheduled" and m.scheduled_at <= ^now)),
        order_by: [asc: m.inserted_at],
        limit: ^batch,
        preload: [:domain]
    )
  end

  # The claim and the guard are one statement: `status` must still be what we
  # read it as, or the update matches nothing and someone else has it.
  defp claim(%Message{} = message) do
    {count, _} =
      Repo.update_all(
        from(m in Message,
          where: m.id == ^message.id and m.status in ["queued", "scheduled"]
        ),
        set: [status: "sent", sent_at: DateTime.utc_now()],
        inc: [attempts: 1]
      )

    count == 1
  end

  defp dispatch(%Message{} = message) do
    if claim(message) do
      Mail.deliver_claimed(message)
    else
      {:ok, :claimed_elsewhere}
    end
  end

  defp requeue_stale do
    cutoff = DateTime.add(DateTime.utc_now(), -@stale_claim_minutes * 60, :second)

    # Give up rather than loop forever on a message that keeps killing its node.
    Repo.update_all(
      from(m in Message,
        where:
          m.status == "sent" and is_nil(m.delivered_at) and m.sent_at < ^cutoff and
            m.attempts >= @max_attempts
      ),
      set: [status: "failed", failure_reason: "exceeded #{@max_attempts} delivery attempts"]
    )

    {count, _} =
      Repo.update_all(
        from(m in Message,
          where:
            m.status == "sent" and is_nil(m.delivered_at) and m.sent_at < ^cutoff and
              m.attempts < @max_attempts
        ),
        set: [status: "queued"]
      )

    if count > 0, do: Logger.warning("requeued #{count} stale message(s)")
    count
  end

  defp config(key, default) do
    Application.get_env(:email_provider, __MODULE__, []) |> Keyword.get(key, default)
  end
end
