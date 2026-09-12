defmodule EmailProvider.Delivery.QueueTest do
  use EmailProvider.DataCase, async: false

  import EmailProvider.Fixtures

  alias EmailProvider.{Mail, Repo, Suppressions, Warmup}
  alias EmailProvider.Delivery.{Queue, Sender}
  alias EmailProvider.Mail.Message
  alias EmailProvider.TestSenders

  setup do
    # The queue is a named process started by the application; let it use this
    # test's sandbox connection.
    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), Process.whereis(Queue))

    user = user_fixture()
    domain = domain_fixture(user)
    %{user: user, domain: domain}
  end

  defp with_sender(module, fun) do
    previous = Application.get_env(:email_provider, Sender, [])
    Application.put_env(:email_provider, Sender, adapter: module)

    try do
      fun.()
    after
      Application.put_env(:email_provider, Sender, previous)
    end
  end

  describe "dispatching" do
    test "delivers a queued message and records the event", %{user: user, domain: domain} do
      {:ok, _} = TestSenders.Recording.start_link()

      with_sender(TestSenders.Recording, fn ->
        {:ok, [message]} = Mail.send_message(user, domain, send_params(domain))
        Queue.tick_now()

        assert %{status: "sent", delivered_at: delivered} = Repo.get!(Message, message.id)
        assert delivered

        types = domain |> Mail.list_events() |> Enum.map(& &1.type) |> Enum.sort()
        assert types == ["accepted", "delivered"]
      end)
    end

    test "what reaches the wire is signed and complete", %{user: user, domain: domain} do
      {:ok, _} = TestSenders.Recording.start_link()

      with_sender(TestSenders.Recording, fn ->
        {:ok, [_message]} =
          Mail.send_message(user, domain, send_params(domain, %{"subject" => "On the wire"}))

        Queue.tick_now()

        assert [%{raw: raw, from: from, to: to}] = TestSenders.Recording.sent()

        assert from == "sender@#{domain.name}"
        assert to == ["recipient@elsewhere.test"]
        assert raw =~ "DKIM-Signature: v=1; a=rsa-sha256;"
        assert raw =~ "d=#{domain.name};"
        assert raw =~ "Subject: On the wire"
        assert raw =~ "Message-ID: <"
      end)
    end

    test "bcc is never written into the headers", %{user: user, domain: domain} do
      {:ok, _} = TestSenders.Recording.start_link()

      with_sender(TestSenders.Recording, fn ->
        params = send_params(domain, %{"bcc" => "hidden@elsewhere.test"})
        {:ok, _} = Mail.send_message(user, domain, params)
        Queue.tick_now()

        assert [%{raw: raw, to: to}] = TestSenders.Recording.sent()

        # On the envelope, so it is delivered...
        assert "hidden@elsewhere.test" in to
        # ...but not in the document, so the other recipients never see it.
        {headers, _body} = EmailProvider.Delivery.Dkim.split(raw)
        refute headers =~ "hidden@elsewhere.test"
      end)
    end

    test "a message is not sent twice, even if the queue runs again", %{
      user: user,
      domain: domain
    } do
      {:ok, _} = TestSenders.Recording.start_link()

      with_sender(TestSenders.Recording, fn ->
        {:ok, _} = Mail.send_message(user, domain, send_params(domain))

        Queue.tick_now()
        Queue.tick_now()
        Queue.tick_now()

        assert length(TestSenders.Recording.sent()) == 1
      end)
    end

    test "a scheduled message waits for its time", %{user: user, domain: domain} do
      {:ok, _} = TestSenders.Recording.start_link()

      with_sender(TestSenders.Recording, fn ->
        at = DateTime.utc_now() |> DateTime.add(3600, :second)
        params = send_params(domain, %{"o:deliverytime" => DateTime.to_iso8601(at)})
        {:ok, [message]} = Mail.send_message(user, domain, params)

        Queue.tick_now()
        assert TestSenders.Recording.sent() == []
        assert Repo.get!(Message, message.id).status == "scheduled"

        # Bring its time forward and it goes.
        Repo.update_all(Message,
          set: [scheduled_at: DateTime.add(DateTime.utc_now(), -60, :second)]
        )

        Queue.tick_now()

        assert length(TestSenders.Recording.sent()) == 1
      end)
    end
  end

  describe "failure handling" do
    test "a 5xx fails the message, suppresses the address and refunds the allowance",
         %{user: user, domain: domain} do
      with_sender(TestSenders.Permanent, fn ->
        {:ok, [message]} = Mail.send_message(user, domain, send_params(domain))
        assert Warmup.sent_today(domain) == 1

        Queue.tick_now()

        assert %{status: "failed", failure_reason: reason} = Repo.get!(Message, message.id)
        assert reason =~ "550"

        # The send never happened, so it should not have cost warmup headroom.
        assert Warmup.sent_today(domain) == 0

        # A hard bounce goes on the suppression list without being asked.
        assert %{type: "bounce"} = Suppressions.get(domain, "bounce", "recipient@elsewhere.test")
      end)
    end

    test "a 4xx goes back on the queue rather than failing", %{user: user, domain: domain} do
      with_sender(TestSenders.Temporary, fn ->
        {:ok, [message]} = Mail.send_message(user, domain, send_params(domain))

        Queue.tick_now()

        assert %{status: "queued", attempts: 1} = Repo.get!(Message, message.id)
        assert is_nil(Suppressions.get(domain, "bounce", "recipient@elsewhere.test"))
      end)
    end

    test "a message that keeps deferring eventually gives up", %{user: user, domain: domain} do
      with_sender(TestSenders.Temporary, fn ->
        {:ok, [message]} = Mail.send_message(user, domain, send_params(domain))

        for _ <- 1..5, do: Queue.tick_now()

        assert %{status: "failed", attempts: attempts} = Repo.get!(Message, message.id)
        assert attempts >= 5
      end)
    end

    test "a test-mode message is never dispatched", %{user: user, domain: domain} do
      {:ok, _} = TestSenders.Recording.start_link()

      with_sender(TestSenders.Recording, fn ->
        {:ok, _} = Mail.send_message(user, domain, send_params(domain, %{"o:testmode" => "yes"}))
        Queue.tick_now()

        assert TestSenders.Recording.sent() == []
      end)
    end
  end
end
