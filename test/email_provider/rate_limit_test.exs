defmodule EmailProvider.RateLimitTest do
  # Not async: the counter table is global, and these tests fill it deliberately.
  use ExUnit.Case, async: false

  alias EmailProvider.RateLimit

  setup do
    RateLimit.reset_all()
    :ok
  end

  test "allows up to the limit and then refuses" do
    key = {:test, :allow}

    for _ <- 1..3, do: assert(RateLimit.hit(key, 3, 60) == :ok)
    assert {:error, retry_after} = RateLimit.hit(key, 3, 60)
    assert retry_after > 0 and retry_after <= 60
  end

  test "a refused hit is not itself counted, so the window still drains" do
    key = {:test, :no_compounding}

    RateLimit.hit(key, 1, 60)
    RateLimit.hit(key, 1, 60)
    RateLimit.hit(key, 1, 60)

    # Were refusals counted, an abuser hammering a limit would extend it.
    assert RateLimit.count(key, 60) == 1
  end

  test "keys do not interfere with each other" do
    assert RateLimit.hit({:test, "a"}, 1, 60) == :ok
    assert RateLimit.hit({:test, "b"}, 1, 60) == :ok
  end

  test "events outside the window no longer count" do
    key = {:test, :window}
    # One event a minute ago, with a window of one second.
    assert RateLimit.hit(key, 1, 1) == :ok
    Process.sleep(1_100)
    assert RateLimit.hit(key, 1, 1) == :ok
  end

  test "reset forgets a key" do
    key = {:test, :reset}
    RateLimit.hit(key, 1, 60)
    assert {:error, _} = RateLimit.hit(key, 1, 60)
    RateLimit.reset(key)
    assert RateLimit.hit(key, 1, 60) == :ok
  end
end
