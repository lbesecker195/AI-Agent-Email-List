defmodule EmailProvider.MailTest do
  use EmailProvider.DataCase, async: false

  import EmailProvider.Fixtures

  alias EmailProvider.{Mail, Repo, Suppressions, Templates, Warmup}
  alias EmailProvider.Mail.Message

  setup do
    user = user_fixture()
    domain = domain_fixture(user)
    %{user: user, domain: domain}
  end

  # Point the moderation client at an in-process plug rather than the network.
  defp stub_moderation(flagged: flagged, categories: categories) do
    previous = Application.get_env(:email_provider, EmailProvider.Moderation, [])

    body = %{
      "results" => [
        %{
          "flagged" => flagged,
          "categories" => Map.new(categories, &{&1, true}),
          "category_scores" => Map.new(categories, &{&1, 0.99})
        }
      ]
    }

    Application.put_env(:email_provider, EmailProvider.Moderation,
      enabled: true,
      api_key: "test-key",
      plug: fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(body))
      end
    )

    on_exit(fn -> Application.put_env(:email_provider, EmailProvider.Moderation, previous) end)
  end

  describe "sending" do
    test "queues a valid message", %{user: user, domain: domain} do
      assert {:ok, [message]} = Mail.send_message(user, domain, send_params(domain))

      assert message.status == "queued"
      assert message.direction == "outbound"
      assert message.recipients == ["recipient@elsewhere.test"]
      assert message.rfc_message_id =~ "@#{domain.name}>"
    end

    test "records an accepted event", %{user: user, domain: domain} do
      {:ok, [message]} = Mail.send_message(user, domain, send_params(domain))

      assert [event] = Mail.list_events(domain)
      assert event.type == "accepted"
      assert event.message_id == message.id
    end

    test "refuses a domain that has not been verified", %{user: user} do
      domain = domain_fixture(user, %{verified: false})

      assert {:error, :domain_not_verified, details} =
               Mail.send_message(user, domain, send_params(domain))

      assert details.state == "unverified"
      assert length(details.required_records) == 2
    end

    test "refuses a from address on someone else's domain", %{user: user, domain: domain} do
      params = send_params(domain, %{"from" => "someone@not-yours.test"})

      assert {:error, :forbidden_sender, details} = Mail.send_message(user, domain, params)
      assert details.got == "someone@not-yours.test"
    end

    test "accepts a subdomain of the sending domain", %{user: user, domain: domain} do
      params = send_params(domain, %{"from" => "bot@news.#{domain.name}"})
      assert {:ok, [_message]} = Mail.send_message(user, domain, params)
    end

    test "requires a body", %{user: user, domain: domain} do
      params = domain |> send_params() |> Map.drop(["text"])
      assert {:error, :bad_request, reason} = Mail.send_message(user, domain, params)
      assert reason =~ "at least one of"
    end

    test "rejects a malformed recipient", %{user: user, domain: domain} do
      params = send_params(domain, %{"to" => "not-an-address"})
      assert {:error, :bad_request, reason} = Mail.send_message(user, domain, params)
      assert reason =~ "invalid recipient"
    end
  end

  describe "warmup enforcement" do
    test "refuses once the daily cap is spent", %{user: user, domain: domain} do
      for n <- 1..10 do
        assert {:ok, _} =
                 Mail.send_message(
                   user,
                   domain,
                   send_params(domain, %{"to" => "r#{n}@elsewhere.test"})
                 )
      end

      assert {:error, :rate_limited, details} =
               Mail.send_message(user, domain, send_params(domain))

      assert details.daily_limit == 10
      assert details.remaining_today == 0
      assert details.retry_after_seconds > 0
    end

    test "counts every recipient, not every request", %{user: user, domain: domain} do
      params =
        send_params(domain, %{"to" => "a@elsewhere.test,b@elsewhere.test,c@elsewhere.test"})

      assert {:ok, [_message]} = Mail.send_message(user, domain, params)
      assert Warmup.sent_today(domain) == 3
    end

    test "test mode does not spend the allowance", %{user: user, domain: domain} do
      params = send_params(domain, %{"o:testmode" => "yes"})

      assert {:ok, [message]} = Mail.send_message(user, domain, params)
      assert message.test_mode
      assert message.status == "sent"
      assert Warmup.sent_today(domain) == 0
    end
  end

  describe "content screening" do
    test "refuses flagged outbound content and does not spend allowance", %{
      user: user,
      domain: domain
    } do
      stub_moderation(flagged: true, categories: ["harassment/threatening"])

      assert {:error, :content_rejected, details} =
               Mail.send_message(user, domain, send_params(domain))

      assert "harassment/threatening" in details.categories
      assert Warmup.sent_today(domain) == 0
      assert Repo.aggregate(Message, :count) == 0
    end

    test "lets clean content through and records that it was screened", %{
      user: user,
      domain: domain
    } do
      stub_moderation(flagged: false, categories: [])

      assert {:ok, [message]} = Mail.send_message(user, domain, send_params(domain))
      refute message.moderation_flagged
      assert message.moderation_action == "allowed"
      assert message.moderation_checked_at
    end

    test "an inbound flagged message is filed in spam, not dropped", %{domain: domain} do
      stub_moderation(flagged: true, categories: ["violence"])

      assert {:ok, message} =
               Mail.receive_message(domain, %{
                 sender: "stranger@elsewhere.test",
                 recipients: ["inbox@#{domain.name}"],
                 subject: "unpleasant",
                 text: "unpleasant things"
               })

      assert message.folder == "spam"
      assert message.moderation_action == "filed_spam"
      assert message.status == "received"
    end

    test "an inbound message that could not be screened is not reported as allowed", %{
      domain: domain
    } do
      previous = Application.get_env(:email_provider, EmailProvider.Moderation, [])
      Application.put_env(:email_provider, EmailProvider.Moderation, enabled: false)
      on_exit(fn -> Application.put_env(:email_provider, EmailProvider.Moderation, previous) end)

      assert {:ok, message} =
               Mail.receive_message(domain, %{
                 sender: "friend@elsewhere.test",
                 recipients: ["inbox@#{domain.name}"],
                 subject: "hello",
                 text: "hello there"
               })

      assert message.folder == "inbox"
      assert message.moderation_action == "not_screened"
      assert is_nil(message.moderation_checked_at)
    end

    test "a clean inbound message lands in the inbox", %{domain: domain} do
      stub_moderation(flagged: false, categories: [])

      assert {:ok, message} =
               Mail.receive_message(domain, %{
                 sender: "friend@elsewhere.test",
                 recipients: ["inbox@#{domain.name}"],
                 subject: "hello",
                 text: "hello there"
               })

      assert message.folder == "inbox"
    end

    test "a screening outage does not stop the send by default", %{user: user, domain: domain} do
      previous = Application.get_env(:email_provider, EmailProvider.Moderation, [])

      Application.put_env(:email_provider, EmailProvider.Moderation,
        enabled: true,
        api_key: "test-key",
        on_error: :allow,
        plug: fn conn -> Plug.Conn.resp(conn, 500, "upstream is down") end
      )

      on_exit(fn -> Application.put_env(:email_provider, EmailProvider.Moderation, previous) end)

      assert {:ok, [message]} = Mail.send_message(user, domain, send_params(domain))
      # Recorded as unscreened so it can be found later, not quietly marked clean.
      assert message.moderation_action == "not_screened"
    end

    test "it can be told to fail closed instead", %{user: user, domain: domain} do
      previous = Application.get_env(:email_provider, EmailProvider.Moderation, [])

      Application.put_env(:email_provider, EmailProvider.Moderation,
        enabled: true,
        api_key: "test-key",
        on_error: :block,
        plug: fn conn -> Plug.Conn.resp(conn, 500, "upstream is down") end
      )

      on_exit(fn -> Application.put_env(:email_provider, EmailProvider.Moderation, previous) end)

      assert {:error, :content_rejected, details} =
               Mail.send_message(user, domain, send_params(domain))

      refute details.screened
    end
  end

  describe "an empty moderation key" do
    test "is treated as no key, not as a key that fails", %{user: user, domain: domain} do
      previous = Application.get_env(:email_provider, EmailProvider.Moderation, [])

      # No plug: if this made a request at all, it would try the real network.
      Application.put_env(:email_provider, EmailProvider.Moderation, enabled: true, api_key: "")
      on_exit(fn -> Application.put_env(:email_provider, EmailProvider.Moderation, previous) end)

      assert {:ok, [message]} = Mail.send_message(user, domain, send_params(domain))
      assert message.moderation_action == "not_screened"
      assert is_nil(message.moderation_checked_at)
    end
  end

  describe "suppressions" do
    test "drops a suppressed recipient and sends to the rest", %{user: user, domain: domain} do
      {:ok, _} = Suppressions.add(domain, "bounce", "bad@elsewhere.test", %{reason: "550"})

      params = send_params(domain, %{"to" => "bad@elsewhere.test,good@elsewhere.test"})

      assert {:ok, [message]} = Mail.send_message(user, domain, params)
      assert message.recipients == ["good@elsewhere.test"]
      assert Warmup.sent_today(domain) == 1
    end

    test "refuses when every recipient is suppressed", %{user: user, domain: domain} do
      {:ok, _} = Suppressions.add(domain, "unsubscribe", "recipient@elsewhere.test")

      assert {:error, :all_recipients_suppressed, details} =
               Mail.send_message(user, domain, send_params(domain))

      assert [%{type: "unsubscribe"}] = details.suppressed
    end

    test "a tag-scoped unsubscribe only bites messages carrying that tag", %{
      user: user,
      domain: domain
    } do
      {:ok, _} =
        Suppressions.add(domain, "unsubscribe", "recipient@elsewhere.test", %{tag: "newsletter"})

      assert {:ok, [_]} =
               Mail.send_message(user, domain, send_params(domain, %{"o:tag" => "receipts"}))

      assert {:error, :all_recipients_suppressed, _} =
               Mail.send_message(user, domain, send_params(domain, %{"o:tag" => "newsletter"}))
    end
  end

  describe "templates, variables and scheduling" do
    test "renders a stored template", %{user: user, domain: domain} do
      {:ok, _template} =
        Templates.create(domain, %{
          "name" => "welcome",
          "template" => "<p>Hello {{name}}, welcome to {{product}}.</p>",
          "subject" => "Welcome, {{name}}"
        })

      params =
        domain
        |> send_params()
        |> Map.drop(["text", "subject"])
        |> Map.merge(%{
          "template" => "welcome",
          "t:variables" => Jason.encode!(%{"name" => "Ada", "product" => "HoneyTrap"})
        })

      assert {:ok, [message]} = Mail.send_message(user, domain, params)
      assert message.body_html == "<p>Hello Ada, welcome to HoneyTrap.</p>"
      assert message.subject == "Welcome, Ada"
    end

    test "an unknown template is a 404, not a blank message", %{user: user, domain: domain} do
      params = send_params(domain, %{"template" => "nope"})
      assert {:error, :not_found, details} = Mail.send_message(user, domain, params)
      assert details.message =~ "nope"
    end

    test "recipient variables produce one message per recipient", %{user: user, domain: domain} do
      params =
        send_params(domain, %{
          "to" => "a@elsewhere.test,b@elsewhere.test",
          "text" => "Hello %recipient.name%",
          "recipient-variables" =>
            Jason.encode!(%{
              "a@elsewhere.test" => %{"name" => "Ada"},
              "b@elsewhere.test" => %{"name" => "Bob"}
            })
        })

      assert {:ok, messages} = Mail.send_message(user, domain, params)
      assert length(messages) == 2
      assert Enum.map(messages, & &1.body_text) |> Enum.sort() == ["Hello Ada", "Hello Bob"]
      # Distinct Message-IDs: two messages, two identities on the wire.
      assert messages |> Enum.map(& &1.rfc_message_id) |> Enum.uniq() |> length() == 2
    end

    test "an unknown placeholder is left visible rather than blanked", %{
      user: user,
      domain: domain
    } do
      params =
        send_params(domain, %{
          "text" => "Hello %recipient.nickname%",
          "recipient-variables" =>
            Jason.encode!(%{"recipient@elsewhere.test" => %{"name" => "Ada"}})
        })

      assert {:ok, [message]} = Mail.send_message(user, domain, params)
      assert message.body_text == "Hello %recipient.nickname%"
    end

    test "schedules a message for later", %{user: user, domain: domain} do
      at = DateTime.utc_now() |> DateTime.add(3600, :second)
      params = send_params(domain, %{"o:deliverytime" => DateTime.to_iso8601(at)})

      assert {:ok, [message]} = Mail.send_message(user, domain, params)
      assert message.status == "scheduled"
      assert DateTime.diff(message.scheduled_at, at) |> abs() < 2
    end

    test "refuses a delivery time too far out", %{user: user, domain: domain} do
      at = DateTime.utc_now() |> DateTime.add(10 * 86_400, :second)
      params = send_params(domain, %{"o:deliverytime" => DateTime.to_iso8601(at)})

      assert {:error, :bad_request, reason} = Mail.send_message(user, domain, params)
      assert reason =~ "at most"
    end

    test "accepts an RFC 2822 delivery time", %{user: user, domain: domain} do
      params = send_params(domain, %{"o:deliverytime" => "Fri, 11 Sep 2026 18:00:00 +0000"})
      assert {:ok, [message]} = Mail.send_message(user, domain, params)
      assert message.scheduled_at.year == 2026
    end

    test "carries tags and custom headers and variables", %{user: user, domain: domain} do
      params =
        send_params(domain, %{
          "o:tag" => ["welcome", "onboarding"],
          "h:X-Campaign" => "spring",
          "v:customer_id" => "42"
        })

      assert {:ok, [message]} = Mail.send_message(user, domain, params)
      assert message.tags == ["welcome", "onboarding"]
      assert message.headers["X-Campaign"] == "spring"
      assert message.variables["customer_id"] == 42
    end
  end
end
