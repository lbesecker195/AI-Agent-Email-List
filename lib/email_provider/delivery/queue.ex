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
  @default_batch 200
  # Kept under the database pool: each in-flight delivery holds a connection.
  @default_concurrency 10
  @default_dispatch_timeout 60_000
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
    |> dispatch_all()
    |> Enum.frequencies_by(fn
      {:ok, _} -> :ok
      {:error, _} -> :error
    end)
  end

  # Delivery is almost entirely waiting: DNS, a TCP connect, then an SMTP
  # conversation with a server on the other side of the internet. Done one at a
  # time the whole queue moves at the speed of the slowest recipient, and a
  # single server taking 30 seconds to answer stalls everything behind it.
  #
  # Concurrency is bounded rather than unbounded. Each in-flight delivery holds
  # a database connection, so the ceiling has to stay under the pool or
  # deliveries start queueing for a connection instead of a socket.
  defp dispatch_all([]), do: []

  defp dispatch_all(messages) do
    case max_concurrency() do
      n when n <= 1 ->
        Enum.map(messages, &dispatch/1)

      n ->
        messages
        |> Task.async_stream(&dispatch/1,
          max_concurrency: n,
          # Generous: this is a whole SMTP conversation, not a function call.
          timeout: dispatch_timeout(),
          on_timeout: :kill_task,
          ordered: false
        )
        |> Enum.map(fn
          {:ok, result} ->
            result

          # A killed task leaves its row claimed; the stale sweep returns it to
          # the queue rather than it being lost.
          {:exit, reason} ->
            Logger.warning("delivery task exited: #{inspect(reason)}")
            {:error, reason}
        end)
    end
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

  defp max_concurrency, do: config(:max_concurrency, @default_concurrency)
  defp dispatch_timeout, do: config(:dispatch_timeout, @default_dispatch_timeout)

  defp config(key, default) do
    Application.get_env(:email_provider, __MODULE__, []) |> Keyword.get(key, default)
  end
end
