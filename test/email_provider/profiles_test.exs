defmodule EmailProvider.ProfilesTest do
  use EmailProvider.DataCase, async: false

  import EmailProvider.Fixtures

  alias EmailProvider.{Mail, Profiles}
  alias EmailProvider.Profiles.Generator

  setup do
    user = user_fixture(%{name: "Ada Lovelace"})
    domain = domain_fixture(user)
    %{user: user, domain: domain}
  end

  defp stub_enrichment(body) do
    previous = Application.get_env(:email_provider, EmailProvider.Enrichment.CSuiteFinder, [])

    Application.put_env(:email_provider, EmailProvider.Enrichment.CSuiteFinder,
      enabled: true,
      api_key: "test-key",
      plug: fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(body))
      end
    )

    on_exit(fn ->
      Application.put_env(:email_provider, EmailProvider.Enrichment.CSuiteFinder, previous)
    end)
  end

  defp stub_generator(opts) do
    previous = Application.get_env(:email_provider, Generator, [])
    Application.put_env(:email_provider, Generator, opts)
    on_exit(fn -> Application.put_env(:email_provider, Generator, previous) end)
  end

  describe "updating on every message" do
    test "a description is written on the first send", %{user: user, domain: domain} do
      assert is_nil(Profiles.get(user))

      {:ok, [_message]} = Mail.send_message(user, domain, send_params(domain))

      profile = Profiles.get(user)
      assert profile.description =~ "Ada Lovelace"
      assert profile.version == 1
      assert profile.generated_at
    end

    test "it is rewritten on each subsequent message", %{user: user, domain: domain} do
      {:ok, _} =
        Mail.send_message(user, domain, send_params(domain, %{"to" => "a@elsewhere.test"}))

      assert Profiles.get(user).version == 1

      {:ok, _} =
        Mail.send_message(user, domain, send_params(domain, %{"to" => "b@elsewhere.test"}))

      assert Profiles.get(user).version == 2

      {:ok, _} =
        Mail.send_message(user, domain, send_params(domain, %{"to" => "c@elsewhere.test"}))

      profile = Profiles.get(user)
      assert profile.version == 3
      assert profile.messages_seen == 3
    end

    test "an inbound message updates it too", %{user: user, domain: domain} do
      {:ok, _} =
        Mail.receive_message(domain, %{
          sender: "colleague@partner.test",
          recipients: ["ada@#{domain.name}"],
          subject: "Quarterly numbers",
          text: "Attached."
        })

      profile = Profiles.get(user)
      assert profile.version == 1
      assert profile.description =~ "1 inbound"
    end

    test "the description keeps up with what the mail is doing", %{user: user, domain: domain} do
      for n <- 1..3 do
        Mail.send_message(
          user,
          domain,
          send_params(domain, %{"to" => "team@partner.test", "subject" => "Update #{n}"})
        )
      end

      profile = Profiles.get(user)

      assert profile.description =~ "3 messages"
      assert profile.description =~ "team@partner.test"
      assert profile.description =~ domain.name
    end

    test "a minimum interval coalesces refreshes on a busy account", %{user: user, domain: domain} do
      previous = Application.get_env(:email_provider, Profiles, [])

      Application.put_env(:email_provider, Profiles,
        enabled: true,
        async: false,
        min_interval_seconds: 3600
      )

      on_exit(fn -> Application.put_env(:email_provider, Profiles, previous) end)

      for n <- 1..4 do
        Mail.send_message(user, domain, send_params(domain, %{"to" => "r#{n}@elsewhere.test"}))
      end

      profile = Profiles.get(user)

      # Written once, but every message is still counted so the next rewrite
      # knows how much it missed.
      assert profile.version == 1
      assert profile.messages_seen == 4
    end

    test "it can be switched off entirely", %{user: user, domain: domain} do
      previous = Application.get_env(:email_provider, Profiles, [])
      Application.put_env(:email_provider, Profiles, enabled: false)
      on_exit(fn -> Application.put_env(:email_provider, Profiles, previous) end)

      {:ok, _} = Mail.send_message(user, domain, send_params(domain))
      assert is_nil(Profiles.get(user))
    end
  end

  describe "enrichment" do
    test "CSuiteFinder facts appear in the description", %{user: user, domain: domain} do
      stub_enrichment(%{
        "found" => true,
        "full_name" => "Ada Lovelace",
        "position" => "Chief Technology Officer",
        "company_name" => "Analytical Engines Ltd",
        "seniority" => "c_suite",
        "location" => "London, UK"
      })

      {:ok, _} = Mail.send_message(user, domain, send_params(domain))

      profile = Profiles.get(user)

      assert profile.description =~ "Chief Technology Officer"
      assert profile.description =~ "Analytical Engines Ltd"
      assert profile.description =~ "London, UK"
      assert profile.enrichment["position"] == "Chief Technology Officer"
      assert profile.enriched_at
    end

    test "a 'found: false' answer is an absence of facts, not an error", %{
      user: user,
      domain: domain
    } do
      stub_enrichment(%{"found" => false})

      {:ok, _} = Mail.send_message(user, domain, send_params(domain))

      profile = Profiles.get(user)
      assert profile.enrichment == %{}
      assert is_nil(profile.last_error)
      # Still described, from mail activity alone.
      assert profile.description =~ "Ada Lovelace"
    end

    test "an enrichment outage does not stop the description being written", %{
      user: user,
      domain: domain
    } do
      previous = Application.get_env(:email_provider, EmailProvider.Enrichment.CSuiteFinder, [])

      Application.put_env(:email_provider, EmailProvider.Enrichment.CSuiteFinder,
        enabled: true,
        api_key: "test-key",
        plug: fn conn -> Plug.Conn.resp(conn, 503, "unavailable") end
      )

      on_exit(fn ->
        Application.put_env(:email_provider, EmailProvider.Enrichment.CSuiteFinder, previous)
      end)

      {:ok, _} = Mail.send_message(user, domain, send_params(domain))

      profile = Profiles.get(user)
      assert profile.description
      assert profile.version == 1
    end

    test "an existing record is not re-bought on every message", %{user: user, domain: domain} do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      previous = Application.get_env(:email_provider, EmailProvider.Enrichment.CSuiteFinder, [])

      Application.put_env(:email_provider, EmailProvider.Enrichment.CSuiteFinder,
        enabled: true,
        api_key: "test-key",
        plug: fn conn ->
          Agent.update(counter, &(&1 + 1))

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"found" => true, "full_name" => "Ada Lovelace"}))
        end
      )

      on_exit(fn ->
        Application.put_env(:email_provider, EmailProvider.Enrichment.CSuiteFinder, previous)
      end)

      for n <- 1..3 do
        Mail.send_message(user, domain, send_params(domain, %{"to" => "r#{n}@elsewhere.test"}))
      end

      # Three rewrites, one lookup: the provider bills per result.
      assert Profiles.get(user).version == 3
      assert Agent.get(counter, & &1) == 1
    end
  end

  describe "the generated text" do
    test "a model-written description is stored and capped at the target length", %{
      user: user,
      domain: domain
    } do
      long = Enum.map_join(1..400, " ", fn n -> "word#{n}" end)

      stub_generator(
        adapter: :openai,
        api_key: "test-key",
        plug: fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{"choices" => [%{"message" => %{"content" => long}}]})
          )
        end
      )

      {:ok, _} = Mail.send_message(user, domain, send_params(domain))

      profile = Profiles.get(user)
      assert profile.generator == "openai"
      assert profile.word_count <= Profiles.target_words()
      assert profile.word_count > 100
    end

    test "a model failure leaves the previous description in place", %{user: user, domain: domain} do
      {:ok, _} =
        Mail.send_message(user, domain, send_params(domain, %{"to" => "first@elsewhere.test"}))

      first = Profiles.get(user)
      assert first.description

      stub_generator(
        adapter: :openai,
        api_key: "test-key",
        plug: fn conn -> Plug.Conn.resp(conn, 500, "model is down") end
      )

      {:ok, _} =
        Mail.send_message(user, domain, send_params(domain, %{"to" => "second@elsewhere.test"}))

      after_failure = Profiles.get(user)
      assert after_failure.description == first.description
      assert after_failure.version == first.version
      assert after_failure.last_error =~ "500"
    end

    test "trimming ends on a sentence where it can" do
      text = String.duplicate("This is a sentence. ", 50)
      trimmed = Generator.trim_to_words(text, 20)

      assert String.ends_with?(trimmed, ".")
      assert Generator.word_count(trimmed) <= 20
    end

    test "a short description is left alone" do
      assert Generator.trim_to_words("Just a few words.", 200) == "Just a few words."
    end
  end

  describe "signals" do
    test "count both directions and name the correspondents", %{user: user, domain: domain} do
      Mail.send_message(user, domain, send_params(domain, %{"to" => "a@partner.test"}))
      Mail.send_message(user, domain, send_params(domain, %{"to" => "a@partner.test"}))
      Mail.send_message(user, domain, send_params(domain, %{"to" => "b@partner.test"}))

      Mail.receive_message(domain, %{
        sender: "c@partner.test",
        recipients: ["ada@#{domain.name}"],
        subject: "Re: hello",
        text: "hi"
      })

      signals = Profiles.signals(user)

      assert signals.total_messages == 4
      assert signals.sent == 3
      assert signals.received == 1
      assert signals.sending_domains == [domain.name]

      top = Enum.find(signals.top_correspondents, &(&1.address == "a@partner.test"))
      assert top.messages == 2
    end

    test "body excerpts are capped", %{user: user, domain: domain} do
      long = String.duplicate("x", 5_000)
      Mail.send_message(user, domain, send_params(domain, %{"text" => long}))

      [excerpt] = Profiles.signals(user).excerpts
      assert byte_size(excerpt) < 500
    end

    test "an account with no mail has an empty digest", %{user: user} do
      signals = Profiles.signals(user)

      assert signals.total_messages == 0
      assert signals.top_correspondents == []
      assert signals.messages_per_active_day == 0
    end
  end
end
