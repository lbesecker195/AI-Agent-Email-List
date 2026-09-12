defmodule EmailProvider.SMTP.ServerTest do
  @moduledoc """
  The session callbacks are exercised directly rather than over a socket. They
  are where every decision is made, and calling them is precise about which
  decision is being tested. One test at the bottom does go over a real socket,
  to prove the wiring between ranch, the session and the mail pipeline.
  """
  use EmailProvider.DataCase, async: false

  import EmailProvider.Fixtures

  alias EmailProvider.{Domains, Mail, Repo}
  alias EmailProvider.SMTP.Server
  alias EmailProvider.SMTP.Server.State

  setup do
    user = user_fixture()
    domain = domain_fixture(user)
    %{user: user, domain: domain, state: %State{peer: {203, 0, 113, 5}}}
  end

  defp submission_state, do: %State{peer: {203, 0, 113, 5}, submission?: true}

  describe "not being an open relay" do
    test "refuses a recipient at a domain we do not host", %{state: state} do
      assert {:error, response, _state} = Server.handle_RCPT("victim@somewhere-else.test", state)

      # 550 is the permanent refusal that stops a spammer retrying, and
      # 5.7.1 is the code that says "not allowed" rather than "no such user".
      assert response =~ "550 5.7.1"
      assert response =~ "relay not permitted"
    end

    test "refuses even when the sender claims to be one of ours", %{state: state, domain: domain} do
      # MAIL FROM is unauthenticated and trivially forged, so it must not buy
      # anything. Only the recipient decides whether we take the message.
      {:ok, state} = Server.handle_MAIL("anyone@#{domain.name}", state)

      assert {:error, response, _state} = Server.handle_RCPT("victim@somewhere-else.test", state)
      assert response =~ "550 5.7.1"
    end

    test "accepts a recipient at a hosted, verified domain", %{state: state, domain: domain} do
      assert {:ok, updated} = Server.handle_RCPT("anyone@#{domain.name}", state)
      assert updated.recipients == ["anyone@#{domain.name}"]
    end

    test "matches the domain case-insensitively", %{state: state, domain: domain} do
      assert {:ok, _} = Server.handle_RCPT("Anyone@#{String.upcase(domain.name)}", state)
    end

    test "defers rather than refuses for a hosted domain that is not verified yet", %{
      user: user,
      state: state
    } do
      unverified = domain_fixture(user, %{verified: false})

      # 4xx, so a legitimate sender retries once the customer finishes their
      # DNS rather than being told permanently to go away.
      assert {:error, response, _state} = Server.handle_RCPT("someone@#{unverified.name}", state)
      assert response =~ "450 4.7.1"
      assert response =~ "not verified"
    end

    test "an authenticated session may send onward, which is the whole point of submission", %{
      domain: domain
    } do
      state = %{submission_state() | authenticated_domain: domain}

      assert {:ok, updated} = Server.handle_RCPT("anyone@somewhere-else.test", state)
      assert updated.recipients == ["anyone@somewhere-else.test"]
    end
  end

  describe "authentication" do
    setup do
      user = user_fixture()

      {:ok, domain, password} =
        Domains.create_domain(user, %{"name" => "auth#{System.unique_integer([:positive])}.test"})

      %{auth_domain: domain, password: password}
    end

    test "accepts the domain's own credentials on the submission port", %{
      auth_domain: domain,
      password: password
    } do
      assert {:ok, state} =
               Server.handle_AUTH(:plain, domain.smtp_login, password, submission_state())

      assert state.authenticated_domain.id == domain.id
    end

    test "refuses a wrong password", %{auth_domain: domain} do
      assert :error = Server.handle_AUTH(:plain, domain.smtp_login, "wrong", submission_state())
    end

    test "refuses an unknown login" do
      assert :error = Server.handle_AUTH(:plain, "nobody@nowhere.test", "x", submission_state())
    end

    test "refuses on the receiving port even with correct credentials", %{
      auth_domain: domain,
      password: password,
      state: state
    } do
      # Port 25 is the internet's port. Allowing auth there turns every
      # customer's SMTP password into something guessable from anywhere.
      assert :error = Server.handle_AUTH(:plain, domain.smtp_login, password, state)
    end

    test "handles the login mechanism's {user, pass} credential shape", %{
      auth_domain: domain,
      password: password
    } do
      assert {:ok, _state} =
               Server.handle_AUTH(
                 :login,
                 domain.smtp_login,
                 {domain.smtp_login, password},
                 submission_state()
               )
    end
  end

  describe "EHLO" do
    test "does not advertise AUTH on the receiving port", %{state: state} do
      assert {:ok, extensions, _state} = Server.handle_EHLO("client.test", [], state)
      refute List.keyfind(extensions, ~c"AUTH", 0)
      assert List.keyfind(extensions, ~c"SIZE", 0)
    end

    test "advertises AUTH on the submission port" do
      assert {:ok, extensions, _state} = Server.handle_EHLO("client.test", [], submission_state())
      assert {_, mechanisms} = List.keyfind(extensions, ~c"AUTH", 0)
      assert to_string(mechanisms) =~ "PLAIN"
    end
  end

  describe "accepting a message" do
    test "stores it against the right domain", %{state: state, domain: domain} do
      raw = message_for(domain, "Hello over SMTP", "Body text here.")

      assert {:ok, response, _state} =
               Server.handle_DATA("sender@elsewhere.test", ["inbox@#{domain.name}"], raw, state)

      assert response =~ "250 2.0.0 accepted"

      assert [message] = Mail.list_messages(domain, direction: "inbound")
      assert message.subject == "Hello over SMTP"
      assert message.sender == "sender@elsewhere.test"
      assert message.folder == "inbox"
    end

    test "splits a message addressed to two hosted domains into two", %{state: state, user: user} do
      first = domain_fixture(user)
      second = domain_fixture(user)
      raw = message_for(first, "To both", "Body.")

      assert {:ok, _response, _state} =
               Server.handle_DATA(
                 "sender@elsewhere.test",
                 ["a@#{first.name}", "b@#{second.name}"],
                 raw,
                 state
               )

      assert length(Mail.list_messages(first, direction: "inbound")) == 1
      assert length(Mail.list_messages(second, direction: "inbound")) == 1
    end

    test "refuses an empty message", %{state: state, domain: domain} do
      assert {:error, response, _state} =
               Server.handle_DATA("s@elsewhere.test", ["a@#{domain.name}"], "", state)

      assert response =~ "552"
    end

    test "refuses one over the size limit", %{domain: domain} do
      state = %State{peer: {203, 0, 113, 5}, options: [max_message_size: 100]}
      raw = message_for(domain, "Too big", String.duplicate("x", 500))

      assert {:error, response, _state} =
               Server.handle_DATA("s@elsewhere.test", ["a@#{domain.name}"], raw, state)

      assert response =~ "552"
      assert response =~ "size limit"
    end

    test "clears the envelope afterwards so the next message starts clean", %{
      state: state,
      domain: domain
    } do
      {:ok, state} = Server.handle_MAIL("sender@elsewhere.test", state)
      {:ok, state} = Server.handle_RCPT("inbox@#{domain.name}", state)
      assert state.recipients != []

      raw = message_for(domain, "First", "Body.")

      assert {:ok, _response, state} =
               Server.handle_DATA("sender@elsewhere.test", ["inbox@#{domain.name}"], raw, state)

      assert state.from == nil
      assert state.recipients == []
    end
  end

  describe "other commands" do
    test "VRFY does not confirm whether an address exists", %{state: state} do
      # Answering it accurately is a directory harvest with a friendly name.
      assert {:error, response, _state} = Server.handle_VRFY("someone@anywhere.test", state)
      assert response =~ "252"
      assert response =~ "cannot verify"
    end

    test "an unknown verb gets a 500", %{state: state} do
      assert {response, _state} = Server.handle_other("WAT", "", state)
      assert IO.iodata_to_binary(response) =~ "500 5.5.1"
    end

    test "RSET clears the envelope", %{state: state, domain: domain} do
      {:ok, state} = Server.handle_MAIL("s@elsewhere.test", state)
      {:ok, state} = Server.handle_RCPT("a@#{domain.name}", state)

      state = Server.handle_RSET(state)
      assert state.from == nil
      assert state.recipients == []
    end

    test "refuses a connection once there are too many sessions" do
      assert {:stop, :normal, message} =
               Server.init(~c"mx.test.local", 500, {203, 0, 113, 5}, max_sessions: 10)

      assert IO.iodata_to_binary(message) =~ "421"
    end
  end

  describe "over a real socket" do
    test "a message delivered by an SMTP client lands in the inbox", %{user: user} do
      # The session runs in its own process, so it needs the sandbox connection.
      Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
      domain = domain_fixture(user)

      port = 20_000 + :rand.uniform(9_000)
      ref = :"smtp_test_#{System.unique_integer([:positive])}"

      {:ok, _pid} =
        :gen_smtp_server.start(ref, Server,
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

      raw = message_for(domain, "Delivered over TCP", "It really went over a socket.")

      result =
        :gen_smtp_client.send_blocking(
          {~c"sender@elsewhere.test", [~c"inbox@#{domain.name}"], raw},
          relay: ~c"127.0.0.1",
          port: port,
          tls: :never,
          hostname: ~c"client.test"
        )

      assert is_binary(result), "expected a receipt, got #{inspect(result)}"

      assert [message] = Mail.list_messages(domain, direction: "inbound")
      assert message.subject == "Delivered over TCP"
    end

    test "a relay attempt over a real socket is refused", %{user: user} do
      Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
      _domain = domain_fixture(user)

      port = 20_000 + :rand.uniform(9_000)
      ref = :"smtp_relay_test_#{System.unique_integer([:positive])}"

      {:ok, _pid} =
        :gen_smtp_server.start(ref, Server,
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

      result =
        :gen_smtp_client.send_blocking(
          {~c"spammer@elsewhere.test", [~c"victim@not-ours.test"],
           "Subject: relay\r\n\r\nhi\r\n"},
          relay: ~c"127.0.0.1",
          port: port,
          tls: :never,
          hostname: ~c"client.test"
        )

      # The client reports the server's refusal rather than a receipt.
      assert {:error, _type, _message} = result
    end
  end

  defp message_for(domain, subject, body) do
    """
    From: sender@elsewhere.test\r
    To: inbox@#{domain.name}\r
    Subject: #{subject}\r
    Content-Type: text/plain; charset=utf-8\r
    \r
    #{body}\r
    """
  end
end
