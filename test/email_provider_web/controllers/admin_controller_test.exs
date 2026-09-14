defmodule EmailProviderWeb.AdminControllerTest do
  use EmailProviderWeb.ConnCase, async: false

  import EmailProvider.Fixtures

  alias EmailProvider.{Mail, Suppressions}

  @token "test-admin-token-aaaaaaaaaaaa"

  defp with_token(token, fun) do
    previous = Application.get_env(:email_provider, :admin_token)
    Application.put_env(:email_provider, :admin_token, token)

    try do
      fun.()
    after
      Application.put_env(:email_provider, :admin_token, previous)
    end
  end

  describe "the gate" do
    test "closed when no token is configured", %{conn: conn} do
      # The failure mode of a missing environment variable must be "nobody can
      # see the figures", never "everybody can".
      with_token(nil, fn ->
        assert conn |> get("/admin/stats") |> json_response(503) |> Map.get("message") =~
                 "disabled"
      end)
    end

    test "closed when the configured token is blank", %{conn: conn} do
      with_token("", fn ->
        assert conn |> get("/admin/stats") |> json_response(503)
      end)
    end

    test "refuses a missing token", %{conn: conn} do
      with_token(@token, fn -> assert conn |> get("/admin/stats") |> json_response(401) end)
    end

    test "refuses a wrong token", %{conn: conn} do
      with_token(@token, fn ->
        assert conn
               |> put_req_header("x-admin-token", "not-the-token")
               |> get("/admin/stats")
               |> json_response(401)
      end)
    end

    test "accepts the token three ways", %{conn: conn} do
      with_token(@token, fn ->
        assert conn
               |> put_req_header("x-admin-token", @token)
               |> get("/admin/stats")
               |> json_response(200)

        assert build_conn()
               |> put_req_header("authorization", "Bearer " <> @token)
               |> get("/admin/stats")
               |> json_response(200)

        # The query form exists so the page can be opened from an address bar.
        assert build_conn() |> get("/admin/stats?token=#{@token}") |> json_response(200)
      end)
    end

    test "the page itself is public but carries no figures", %{conn: conn} do
      user = user_fixture()
      domain = domain_fixture(user)
      Mail.send_message(user, domain, send_params(domain))

      body = conn |> get("/admin") |> html_response(200)

      assert body =~ "Admin token"
      # Nothing about this account should be in the HTML a stranger receives.
      refute body =~ user.email
      refute body =~ domain.name
    end
  end

  describe "the figures" do
    setup do
      user = user_fixture()
      domain = domain_fixture(user)

      Mail.send_message(user, domain, send_params(domain, %{"to" => "a@elsewhere.test"}))
      Mail.send_message(user, domain, send_params(domain, %{"to" => "b@elsewhere.test"}))

      Mail.receive_message(domain, %{
        sender: "someone@partner.test",
        recipients: ["inbox@#{domain.name}"],
        subject: "Inbound",
        text: "hello"
      })

      {:ok, _} = Suppressions.add(domain, "bounce", "dead@elsewhere.test", %{reason: "550"})
      {:ok, _} = Suppressions.add(domain, "unsubscribe", "gone@elsewhere.test")

      %{user: user, domain: domain}
    end

    test "count what the operator asked for", %{conn: conn, user: user, domain: domain} do
      body =
        with_token(@token, fn ->
          conn
          |> put_req_header("x-admin-token", @token)
          |> get("/admin/stats")
          |> json_response(200)
        end)

      assert body["accounts"]["total"] >= 1
      assert body["accounts"]["new_this_week"] >= 1
      assert body["domains"]["total"] >= 1
      assert body["domains"]["active"] >= 1

      assert body["messages"]["outbound"] >= 2
      assert body["messages"]["inbound"] >= 1
      assert body["messages"]["last_24h"] >= 3

      assert body["suppressions"]["bounces"] >= 1
      assert body["suppressions"]["unsubscribes"] >= 1

      assert body["events"]["accepted"] >= 2
      assert body["events"]["received"] >= 1

      assert Enum.any?(body["busiest_domains"], &(&1["name"] == domain.name))
      assert Enum.any?(body["recent_accounts"], &(&1["email"] == user.email))
    end

    test "say plainly that refused outbound is not counted", %{conn: conn} do
      body =
        with_token(@token, fn ->
          conn
          |> put_req_header("x-admin-token", @token)
          |> get("/admin/stats")
          |> json_response(200)
        end)

      # A moderation dashboard that quietly omits its most interesting number is
      # worse than one that admits the gap.
      assert body["moderation"]["outbound_refusals_recorded"] == false
    end

    test "place verified domains on the warmup ladder", %{conn: conn} do
      body =
        with_token(@token, fn ->
          conn
          |> put_req_header("x-admin-token", @token)
          |> get("/admin/stats")
          |> json_response(200)
        end)

      assert [%{"stage" => 1, "daily_limit" => 10, "domains" => n} | _] = body["warmup"]
      assert n >= 1
    end
  end
end
