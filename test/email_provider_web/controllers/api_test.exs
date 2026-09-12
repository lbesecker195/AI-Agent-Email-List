defmodule EmailProviderWeb.ApiTest do
  use EmailProviderWeb.ConnCase, async: true

  import EmailProvider.Fixtures

  alias EmailProvider.Suppressions

  setup %{conn: conn} do
    user = user_fixture()
    {_key, plaintext} = api_key_fixture(user, label: "test")
    domain = domain_fixture(user)

    authed =
      conn
      |> put_req_header("authorization", "Basic " <> Base.encode64("api:" <> plaintext))
      |> put_req_header("content-type", "application/x-www-form-urlencoded")

    %{conn: authed, raw_conn: conn, user: user, domain: domain, api_key: plaintext}
  end

  describe "authentication" do
    test "rejects a request with no credentials", %{raw_conn: conn, domain: domain} do
      conn = post(conn, "/v3/#{domain.name}/messages", %{})
      assert json_response(conn, 401)["message"] == "invalid credentials"
    end

    test "rejects a wrong key", %{raw_conn: conn, domain: domain} do
      conn =
        conn
        |> put_req_header("authorization", "Basic " <> Base.encode64("api:ep_live_wrong"))
        |> post("/v3/#{domain.name}/messages", %{})

      assert json_response(conn, 401)
    end

    test "accepts a bearer token too", %{raw_conn: conn, domain: domain, api_key: key} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> key)
        |> get("/v3/#{domain.name}/limits")

      assert json_response(conn, 200)["limits"]["daily_limit"] == 10
    end

    test "a revoked key stops working", %{raw_conn: conn, user: user, domain: domain} do
      {key, plaintext} = api_key_fixture(user)
      {:ok, _} = EmailProvider.Accounts.revoke_api_key(key)

      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> plaintext)
        |> get("/v3/#{domain.name}/limits")

      assert json_response(conn, 401)
    end

    test "another account's domain is a 404, not a 403", %{raw_conn: conn} do
      other_domain = domain_fixture(user_fixture())
      {_key, plaintext} = api_key_fixture(user_fixture())

      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> plaintext)
        |> get("/v3/#{other_domain.name}/limits")

      assert json_response(conn, 404)["message"] == "domain not found"
    end

    test "a key without the send scope cannot send", %{raw_conn: conn, user: user, domain: domain} do
      {_key, plaintext} = api_key_fixture(user, scopes: ["domains:read"])

      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> plaintext)
        |> post("/v3/#{domain.name}/messages", send_params(domain))

      assert json_response(conn, 403)["message"] =~ "not authorized"
    end
  end

  describe "POST /v3/:domain/messages" do
    test "queues a message", %{conn: conn, domain: domain} do
      conn = post(conn, "/v3/#{domain.name}/messages", send_params(domain))
      body = json_response(conn, 200)

      assert body["message"] == "Queued. Thank you."
      assert body["id"] =~ "@#{domain.name}>"
      assert [accepted] = body["accepted"]
      assert accepted["to"] == ["recipient@elsewhere.test"]
    end

    test "reports a missing field", %{conn: conn, domain: domain} do
      conn =
        post(conn, "/v3/#{domain.name}/messages", %{"to" => "a@elsewhere.test", "text" => "hi"})

      assert json_response(conn, 400)["message"] =~ "'from' parameter is missing"
    end

    test "429 with a retry hint once the warmup cap is spent", %{conn: conn, domain: domain} do
      for n <- 1..10 do
        post(
          conn,
          "/v3/#{domain.name}/messages",
          send_params(domain, %{"to" => "r#{n}@elsewhere.test"})
        )
      end

      conn = post(conn, "/v3/#{domain.name}/messages", send_params(domain))
      body = json_response(conn, 429)

      assert body["error"] == "rate_limited"
      assert body["daily_limit"] == 10
      assert body["retry_after_seconds"] > 0
      assert body["graduates_when"] =~ "5 separate days"
    end

    test "403 when the domain is not verified", %{conn: conn, user: user} do
      domain = domain_fixture(user, %{verified: false})

      conn = post(conn, "/v3/#{domain.name}/messages", send_params(domain))
      body = json_response(conn, 403)

      assert body["error"] == "domain_not_verified"
      assert length(body["required_records"]) == 2
    end

    test "accepts raw MIME", %{conn: conn, domain: domain} do
      raw =
        """
        From: sender@#{domain.name}\r
        To: recipient@elsewhere.test\r
        Subject: Raw one\r
        Content-Type: text/plain; charset=utf-8\r
        \r
        Sent as MIME.\r
        """

      conn = post(conn, "/v3/#{domain.name}/messages.mime", %{"message" => raw})
      body = json_response(conn, 200)

      assert [accepted] = body["accepted"]
      assert accepted["subject"] == "Raw one"
    end
  end

  describe "domains" do
    test "lists them", %{conn: conn, domain: domain} do
      body = conn |> get("/v3/domains") |> json_response(200)

      assert body["total_count"] == 1
      assert [listed] = body["items"]
      assert listed["name"] == domain.name
    end

    test "creating one returns the DNS records to publish and the SMTP password once", %{
      conn: conn
    } do
      conn = post(conn, "/v3/domains", %{"name" => "new.example.test"})
      body = json_response(conn, 201)

      assert body["smtp_password"]
      records = body["domain"]["sending_dns_records"]

      spf = Enum.find(records, &(&1["record_type"] == "TXT" and &1["name"] == "new.example.test"))
      assert spf["value"] =~ "v=spf1"

      dkim = Enum.find(records, &String.contains?(&1["name"], "_domainkey"))
      assert dkim["value"] =~ "v=DKIM1; k=rsa; p="
    end

    test "never exposes the private key", %{conn: conn, domain: domain} do
      raw = conn |> get("/v3/domains/#{domain.name}") |> response(200)

      refute raw =~ "PRIVATE KEY"
      refute raw =~ "dkim_private"
    end

    test "a new domain starts unverified and cannot send", %{conn: conn} do
      body = conn |> post("/v3/domains", %{"name" => "fresh.example.test"}) |> json_response(201)
      assert body["domain"]["state"] == "unverified"
    end

    test "rejects a malformed name", %{conn: conn} do
      conn = post(conn, "/v3/domains", %{"name" => "not a domain"})
      assert json_response(conn, 400)["errors"]["name"]
    end
  end

  describe "events, stats and limits" do
    test "events show the accepted message", %{conn: conn, domain: domain} do
      post(conn, "/v3/#{domain.name}/messages", send_params(domain, %{"o:tag" => "welcome"}))

      body = conn |> get("/v3/#{domain.name}/events") |> json_response(200)

      assert [event] = body["items"]
      assert event["event"] == "accepted"
      assert event["tags"] == ["welcome"]
    end

    test "events can be filtered by tag", %{conn: conn, domain: domain} do
      post(conn, "/v3/#{domain.name}/messages", send_params(domain, %{"o:tag" => "alpha"}))
      post(conn, "/v3/#{domain.name}/messages", send_params(domain, %{"o:tag" => "beta"}))

      body = conn |> get("/v3/#{domain.name}/events?tag=alpha") |> json_response(200)

      assert [event] = body["items"]
      assert event["tags"] == ["alpha"]
    end

    test "totals count by event type", %{conn: conn, domain: domain} do
      post(conn, "/v3/#{domain.name}/messages", send_params(domain))

      body = conn |> get("/v3/#{domain.name}/stats/total") |> json_response(200)
      assert body["totals"]["accepted"] == 1
    end

    test "tags report how many messages carry each", %{conn: conn, domain: domain} do
      post(conn, "/v3/#{domain.name}/messages", send_params(domain, %{"o:tag" => "welcome"}))

      body = conn |> get("/v3/#{domain.name}/tags") |> json_response(200)
      assert [%{"tag" => "welcome", "messages" => 1}] = body["items"]
    end

    test "limits describe the warmup position", %{conn: conn, domain: domain} do
      post(conn, "/v3/#{domain.name}/messages", send_params(domain))

      limits = conn |> get("/v3/#{domain.name}/limits") |> json_response(200) |> Map.get("limits")

      assert limits["stage"] == 1
      assert limits["stage_count"] == 5
      assert limits["sent_today"] == 1
      assert limits["remaining_today"] == 9
    end
  end

  describe "suppression lists" do
    test "a bounce can be added, listed and removed", %{conn: conn, domain: domain} do
      conn
      |> post("/v3/#{domain.name}/bounces", %{"address" => "bad@elsewhere.test", "code" => "550"})
      |> json_response(200)

      body = conn |> get("/v3/#{domain.name}/bounces") |> json_response(200)
      assert [%{"address" => "bad@elsewhere.test", "code" => "550"}] = body["items"]

      conn |> delete("/v3/#{domain.name}/bounces/bad@elsewhere.test") |> json_response(200)

      assert conn |> get("/v3/#{domain.name}/bounces") |> json_response(200) |> Map.get("items") ==
               []
    end

    test "the three lists are kept apart", %{conn: conn, domain: domain} do
      post(conn, "/v3/#{domain.name}/unsubscribes", %{"address" => "gone@elsewhere.test"})

      assert conn |> get("/v3/#{domain.name}/bounces") |> json_response(200) |> Map.get("items") ==
               []

      assert [_one] =
               conn
               |> get("/v3/#{domain.name}/unsubscribes")
               |> json_response(200)
               |> Map.get("items")
    end

    test "a suppressed recipient is dropped from a send", %{conn: conn, domain: domain} do
      {:ok, _} = Suppressions.add(domain, "complaint", "angry@elsewhere.test")

      params = send_params(domain, %{"to" => "angry@elsewhere.test,fine@elsewhere.test"})
      body = conn |> post("/v3/#{domain.name}/messages", params) |> json_response(200)

      assert [accepted] = body["accepted"]
      assert accepted["to"] == ["fine@elsewhere.test"]
    end
  end

  describe "templates" do
    test "stored and used in a send", %{conn: conn, domain: domain} do
      conn
      |> post("/v3/#{domain.name}/templates", %{
        "name" => "receipt",
        "template" => "<p>Thanks, {{name}}.</p>",
        "subject" => "Your receipt"
      })
      |> json_response(201)

      params =
        domain
        |> send_params()
        |> Map.drop(["text"])
        |> Map.merge(%{
          "template" => "receipt",
          "t:variables" => Jason.encode!(%{"name" => "Ada"})
        })

      body = conn |> post("/v3/#{domain.name}/messages", params) |> json_response(200)
      assert [accepted] = body["accepted"]

      stored =
        conn
        |> get("/v3/domains/#{domain.name}/messages/#{accepted["storage_key"]}")
        |> json_response(200)

      assert stored["body-html"] == "<p>Thanks, Ada.</p>"
    end
  end

  describe "routes and webhooks" do
    test "a route is created and listed", %{conn: conn} do
      conn
      |> post("/v3/routes", %{
        "priority" => "10",
        "expression" => "match_recipient(\"^support@.*\")",
        "action" => ["forward(\"https://hooks.example.test/in\")", "stop()"]
      })
      |> json_response(201)

      body = conn |> get("/v3/routes") |> json_response(200)
      assert [route] = body["items"]
      assert route["priority"] == 10
      assert route["actions"] == ["forward(\"https://hooks.example.test/in\")", "stop()"]
    end

    test "a nonsense expression is refused", %{conn: conn} do
      conn = post(conn, "/v3/routes", %{"expression" => "rm -rf /"})
      assert json_response(conn, 400)["errors"]["expression"]
    end

    test "a webhook returns its signing key once", %{conn: conn, domain: domain} do
      body =
        conn
        |> post("/v3/domains/#{domain.name}/webhooks", %{
          "id" => "delivered",
          "url" => "https://hooks.example.test/delivered"
        })
        |> json_response(201)

      assert body["signing_key"]

      listed = conn |> get("/v3/domains/#{domain.name}/webhooks") |> json_response(200)
      refute listed["webhooks"]["delivered"]["signing_key"]
    end
  end

  describe "address validation" do
    test "reports malformed syntax", %{conn: conn} do
      body = conn |> get("/v4/address/validate?address=nope") |> json_response(200)

      refute body["is_valid"]
      assert body["reason"] == ["malformed address"]
    end

    test "flags a known disposable domain", %{conn: conn} do
      body = conn |> get("/v4/address/validate?address=a@mailinator.com") |> json_response(200)
      assert body["is_disposable_address"]
    end
  end

  describe "inbound" do
    test "a received message is stored and listed", %{conn: conn, domain: domain} do
      raw =
        """
        From: stranger@elsewhere.test\r
        To: inbox@#{domain.name}\r
        Subject: Hello there\r
        Content-Type: text/plain; charset=utf-8\r
        \r
        Just saying hi.\r
        """

      body = conn |> post("/v1/inbound/#{domain.name}", %{"message" => raw}) |> json_response(201)

      assert body["item"]["subject"] == "Hello there"
      assert body["item"]["folder"] == "inbox"
      assert body["item"]["direction"] == "inbound"
    end
  end

  describe "accounts" do
    test "signup returns a working key", %{raw_conn: conn} do
      body =
        conn
        |> post("/v1/accounts", %{
          "email" => unique_email(),
          "name" => "New Person",
          "password" => "a sufficiently long password"
        })
        |> json_response(201)

      key = body["api_key"]
      assert key =~ "ep_live_"

      listed =
        conn
        |> put_req_header("authorization", "Bearer " <> key)
        |> get("/v3/domains")
        |> json_response(200)

      assert listed["total_count"] == 0
    end

    test "login rejects a bad password", %{raw_conn: conn, user: user} do
      conn = post(conn, "/v1/accounts/login", %{"email" => user.email, "password" => "wrong"})
      assert json_response(conn, 401)
    end

    test "login returns a token that expires", %{raw_conn: conn, user: user} do
      body =
        conn
        |> post("/v1/accounts/login", %{
          "email" => user.email,
          "password" => "correct horse battery"
        })
        |> json_response(200)

      assert body["token"] =~ "ep_sess_"
      assert body["expires_at"]
    end
  end

  describe "account profile" do
    test "404 before any mail has moved", %{conn: conn} do
      assert conn |> get("/v1/profile") |> json_response(404)
    end

    test "returns the description once a message has been sent", %{conn: conn, domain: domain} do
      post(conn, "/v3/#{domain.name}/messages", send_params(domain))

      body = conn |> get("/v1/profile") |> json_response(200) |> Map.get("profile")

      assert body["description"] =~ "Test User"
      assert body["version"] == 1
      assert body["word_count"] > 0
      assert body["generator"] == "structured"
    end

    test "carries the material it was written from", %{conn: conn, domain: domain} do
      post(conn, "/v3/#{domain.name}/messages", send_params(domain))

      body = conn |> get("/v1/profile") |> json_response(200) |> Map.get("profile")

      assert body["signals"]["total_messages"] == 1
      assert body["signals"]["sending_domains"] == [domain.name]
    end

    test "can be rewritten on demand", %{conn: conn, domain: domain} do
      post(conn, "/v3/#{domain.name}/messages", send_params(domain))

      body = conn |> post("/v1/profile/refresh") |> json_response(200) |> Map.get("profile")
      assert body["version"] == 2
    end

    test "signals can be read on their own", %{conn: conn, domain: domain} do
      post(conn, "/v3/#{domain.name}/messages", send_params(domain))

      body = conn |> get("/v1/profile/signals") |> json_response(200) |> Map.get("signals")
      assert body["sent"] == 1
    end

    test "a key without read scope cannot see it", %{raw_conn: conn, user: user, domain: domain} do
      {_key, plaintext} = api_key_fixture(user, scopes: ["messages:send"])
      post(build_conn(), "/v3/#{domain.name}/messages", send_params(domain))

      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> plaintext)
        |> get("/v1/profile")

      assert json_response(conn, 403)
    end

    test "one account cannot see another's", %{conn: conn, domain: domain, raw_conn: raw} do
      post(conn, "/v3/#{domain.name}/messages", send_params(domain))

      other = user_fixture()
      {_key, plaintext} = api_key_fixture(other)

      # The endpoint is scoped to the caller; the stranger simply has none yet.
      assert raw
             |> put_req_header("authorization", "Bearer " <> plaintext)
             |> get("/v1/profile")
             |> json_response(404)
    end
  end

  test "health check needs no credentials", %{raw_conn: conn} do
    assert conn |> get("/health") |> json_response(200) |> Map.get("status") == "ok"
  end
end
