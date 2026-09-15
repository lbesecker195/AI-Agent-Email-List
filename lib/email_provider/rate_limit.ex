defmodule EmailProvider.RateLimit do
  @moduledoc """
  A sliding-window counter, in memory.

  Used for the things that have to be cheap to check on every request: how many
  accounts an address range has opened, how many calls a key is making. The
  durable limits — how many domains an account may have, how much it may send —
  are counted from the database instead, because those must survive a restart
  and a restart is not a way to earn more of them.

  This one is deliberately not durable. Losing the window on deploy costs an
  abuser nothing they could not have got by waiting, and the alternative is a
  database write on every request to make a counter that expires in an hour.

  Single node. If this ever runs on more than one, the window becomes per-node
  and the effective limit multiplies by the node count, so this is the module to
  replace first.
  """

  use GenServer

  @table :email_provider_rate_limit
  # Windows are swept rather than expired on read, so a key nobody asks about
  # again does not sit in the table forever.
  @sweep_every :timer.minutes(5)

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Count one event against `key` and say whether it is still within `limit`.

  Returns `:ok`, or `{:error, retry_after_seconds}`. The caller gets a real
  number of seconds so it can tell the client when to come back rather than
  leaving it to guess and hammer.
  """
  def hit(key, limit, window_seconds) do
    now = System.system_time(:second)
    cutoff = now - window_seconds

    timestamps =
      case :ets.lookup(@table, key) do
        [{^key, list}] -> Enum.filter(list, &(&1 > cutoff))
        [] -> []
      end

    if length(timestamps) >= limit do
      oldest = Enum.min(timestamps)
      {:error, max(oldest + window_seconds - now, 1)}
    else
      :ets.insert(@table, {key, [now | timestamps]})
      :ok
    end
  end

  @doc "How many events are in the window, without recording one."
  def count(key, window_seconds) do
    cutoff = System.system_time(:second) - window_seconds

    case :ets.lookup(@table, key) do
      [{^key, list}] -> Enum.count(list, &(&1 > cutoff))
      [] -> 0
    end
  end

  @doc "Forget a key. Used by tests, and by an operator lifting a limit by hand."
  def reset(key), do: :ets.delete(@table, key)

  def reset_all, do: :ets.delete_all_objects(@table)

  # -- server --------------------------------------------------------------

  @impl true
  def init(_opts) do
    # public + write_concurrency: every web request may write here, and routing
    # them all through this process would make it the bottleneck it exists to
    # prevent.
    :ets.new(@table, [
      :named_table,
      :public,
      :set,
      write_concurrency: true,
      read_concurrency: true
    ])

    schedule_sweep()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:sweep, state) do
    sweep()
    schedule_sweep()
    {:noreply, state}
  end

  def handle_info(_other, state), do: {:noreply, state}

  defp schedule_sweep, do: Process.send_after(self(), :sweep, @sweep_every)

  # Anything older than the longest window we use is dead weight.
  defp sweep do
    cutoff = System.system_time(:second) - 86_400

    :ets.foldl(
      fn {key, list}, acc ->
        case Enum.filter(list, &(&1 > cutoff)) do
          [] -> :ets.delete(@table, key)
          kept -> :ets.insert(@table, {key, kept})
        end

        acc
      end,
      :ok,
      @table
    )
  end
end
