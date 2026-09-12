defmodule EmailProvider.Delivery.DirectMXTest do
  use EmailProvider.DataCase, async: false

  import EmailProvider.Fixtures

  alias EmailProvider.{Mail, Repo}
  alias EmailProvider.Delivery.Sender
  alias EmailProvider.Delivery.Sender.DirectMX

  defp with_sender_config(config, fun) do
    previous = Application.get_env(:email_provider, Sender, [])
    Application.put_env(:email_provider, Sender, config)

    try do
      fun.()
    after
      Application.put_env(:email_provider, Sender, previous)
    end
  end

  describe "finding mail servers" do
    test "a domain that does not resolve has none" do
      assert DirectMX.mail_exchangers("nothing-here.invalid") == []
    end

    test "the resolver can be pointed somewhere else for testing" do
      with_sender_config([mx_resolver: fn _domain -> ["mx1.test", "mx2.test"] end], fn ->
        assert DirectMX.mail_exchangers("anything.test") == ["mx1.test", "mx2.test"]
      end)
    end
  end

  describe "delivering" do
    test "no mail server is a permanent failure, not something to retry forever" do
      with_sender_config([mx_resolver: fn _ -> [] end], fn ->
        assert {:error, reason} = DirectMX.deliver("body", "a@ours.test", ["b@nowhere.invalid"])

        # 5xx so the queue gives up rather than retrying a domain that does not
        # accept mail at all.
        assert reason =~ "550"
        assert reason =~ "nowhere.invalid"
      end)
    end

    test "falls through to the next mail server when the first is unreachable" do
      {:ok, server} = start_smtp_server()

      with_sender_config(
        [
          # A host that will refuse the connection, then the real one.
          mx_resolver: fn _ -> ["127.0.0.1", "127.0.0.1"] end,
          direct_port: server.port,
          helo_name: "mx.test.local"
        ],
        fn ->
          assert {:ok, info} =
                   DirectMX.deliver(
                     message_for(server.domain),
                     "sender@ours.test",
                     ["inbox@#{server.domain.name}"]
                   )

          assert info.receipt != ""
        end
      )
    end

    test "delivers over a real socket into a real server" do
      {:ok, server} = start_smtp_server()

      with_sender_config(
        [
          mx_resolver: fn _ -> ["127.0.0.1"] end,
          direct_port: server.port,
          helo_name: "mx.test.local"
        ],
        fn ->
          assert {:ok, info} =
                   DirectMX.deliver(
                     message_for(server.domain),
                     "sender@ours.test",
                     ["inbox@#{server.domain.name}"]
                   )

          assert info.delivered == ["inbox@#{server.domain.name}"]
        end
      )

      # It came out the other end and went through the inbound pipeline.
      assert [message] = Mail.list_messages(server.domain, direction: "inbound")
      assert message.subject == "Sent by DirectMX"
      assert message.folder == "inbox"
    end

    test "a refused recipient fails the delivery rather than reporting success" do
      {:ok, server} = start_smtp_server()

      with_sender_config(
        [
          mx_resolver: fn _ -> ["127.0.0.1"] end,
          direct_port: server.port,
          helo_name: "mx.test.local"
        ],
        fn ->
          # The receiving server hosts server.domain, not this one, so it will
          # refuse to relay.
          assert {:error, reason} =
                   DirectMX.deliver("Subject: x\r\n\r\nbody\r\n", "sender@ours.test", [
                     "victim@not-hosted.test"
                   ])

          assert reason =~ "not-hosted.test"
        end
      )
    end

    test "groups recipients so one domain is one conversation" do
      {:ok, server} = start_smtp_server()
      second = domain_fixture(user_fixture())

      with_sender_config(
        [
          mx_resolver: fn _ -> ["127.0.0.1"] end,
          direct_port: server.port,
          helo_name: "mx.test.local"
        ],
        fn ->
          assert {:ok, info} =
                   DirectMX.deliver(
                     message_for(server.domain),
                     "sender@ours.test",
                     ["a@#{server.domain.name}", "b@#{server.domain.name}", "c@#{second.name}"]
                   )

          # Two domains, so two receipts, not three.
          assert length(info.receipts) == 2
        end
      )
    end
  end

  # A real listener on a high port, with a hosted domain it will accept mail for.
  defp start_smtp_server do
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    domain = domain_fixture(user_fixture())

    port = 20_000 + :rand.uniform(9_000)
    ref = :"direct_mx_test_#{System.unique_integer([:positive])}"

    {:ok, _pid} =
      :gen_smtp_server.start(ref, EmailProvider.SMTP.Server,
        domain: ~c"mx.test.local",
        address: {127, 0, 0, 1},
        port: port,
        protocol: :tcp,
        sessionoptions: [callbackoptions: [submission: false]]
      )

    on_exit(fn ->
      Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual)
      :gen_smtp_server.stop(ref)
    end)

    {:ok, %{port: port, ref: ref, domain: domain}}
  end

  defp message_for(domain) do
    """
    From: sender@ours.test\r
    To: inbox@#{domain.name}\r
    Subject: Sent by DirectMX\r
    Content-Type: text/plain; charset=utf-8\r
    \r
    Straight to the MX.\r
    """
  end
end
