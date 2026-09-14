defmodule EmailProviderWeb.ConsoleControllerTest do
  use EmailProviderWeb.ConnCase, async: true

  import EmailProvider.Fixtures

  alias EmailProvider.{Accounts, Domains}

  @password "a sufficiently long password"

  defp sign_in(conn, user) do
    Plug.Test.init_test_session(conn, user_id: user.id)
  end

  defp account(attrs \\ %{}) do
    user_fixture(Map.merge(%{password: @password}, attrs))
  end

  describe "signing up" do
    test "creates an account, signs in, and hands over a key", %{conn: conn} do
      email = unique_email()

      conn =
        post(conn, "/signup", %{"email" => email, "name" => "New", "password" => @password})

      assert redirected_to(conn) == "/account"
      assert %{email: ^email} = Accounts.get_user_by_email(email)

      # Somebody who came to build against the API should leave with a key
      # rather than having to find the page that mints one.
      body =
        conn
        |> recycle()
        |> sign_in(Accounts.get_user_by_email(email))
        |> get("/account")
        |> html_response(200)

      assert body =~ "ep_live_"
      assert body =~ "only time it is shown"
    end

    test "shows the key once and not again", %{conn: conn} do
      email = unique_email()
      conn = post(conn, "/signup", %{"email" => email, "password" => @password})
      user = Accounts.get_user_by_email(email)

      first = conn |> recycle() |> sign_in(user) |> get("/account") |> html_response(200)
      assert first =~ "ep_live_"

      # A reload must not repeat a secret that was described as shown once.
      second = build_conn() |> sign_in(user) |> get("/account") |> html_response(200)
      refute second =~ "only time it is shown"
    end

    test "reports a password that is too short", %{conn: conn} do
      email = unique_email()
      conn = post(conn, "/signup", %{"email" => email, "password" => "short"})

      # The form comes back with the problem named, rather than redirecting.
      assert html_response(conn, 200) =~ "Password"
      assert is_nil(Accounts.get_user_by_email(email))
    end

    test "reports an address that is already taken", %{conn: conn} do
      user = account()
      conn = post(conn, "/signup", %{"email" => user.email, "password" => @password})

      assert html_response(conn, 200) =~ "Email"
    end
  end

  describe "signing in" do
    test "works, and returns to where you were headed", %{conn: conn} do
      user = account()

      conn =
        conn
        |> get("/send")
        |> recycle()
        |> post("/login", %{"email" => user.email, "password" => @password})

      assert redirected_to(conn) == "/send"
    end

    test "does not say which half was wrong", %{conn: conn} do
      user = account()

      wrong_password = post(conn, "/login", %{"email" => user.email, "password" => "nope"})

      unknown_email =
        post(build_conn(), "/login", %{"email" => "nobody@nowhere.test", "password" => @password})

      # Distinguishing the two would turn this form into a way to find out which
      # addresses have accounts.
      assert html_response(wrong_password, 200) =~ "do not match"
      assert html_response(unknown_email, 200) =~ "do not match"
    end

    test "signing out ends the session", %{conn: conn} do
      user = account()
      conn = conn |> sign_in(user) |> post("/logout")

      assert redirected_to(conn) == "/"
      assert build_conn() |> get("/domains") |> redirected_to() == "/login"
    end
  end

  describe "pages that need an account" do
    test "redirect to login when signed out", %{conn: conn} do
      for path <- ["/domains", "/send", "/messages", "/account"] do
        assert conn |> get(path) |> redirected_to() == "/login",
               "#{path} should require signing in"
      end
    end

    test "a suspended account is signed out immediately", %{conn: conn} do
      user = account()

      user
      |> EmailProvider.Accounts.User.changeset(%{status: "suspended"})
      |> EmailProvider.Repo.update!()

      # The user is looked up per request rather than trusted from the cookie,
      # so suspension bites now rather than when the session expires.
      assert conn |> sign_in(user) |> get("/domains") |> redirected_to() == "/login"
    end
  end

  describe "domains" do
    setup %{conn: conn} do
      user = account()
      %{conn: sign_in(conn, user), user: user}
    end

    test "lists them and adds one", %{conn: conn, user: user} do
      assert get(conn, "/domains") |> html_response(200) =~ "No domains yet"

      created = post(conn, "/domains", %{"name" => "console-test.example.com"})
      assert redirected_to(created) == "/domains/console-test.example.com"

      # The SMTP password exists in the clear exactly once, and this is it.
      assert Phoenix.Flash.get(created.assigns.flash, :info) =~ "SMTP password"
      assert Domains.get_user_domain(user, "console-test.example.com")
    end

    test "reports a malformed name instead of a changeset", %{conn: conn} do
      conn = post(conn, "/domains", %{"name" => "not a domain"})

      assert redirected_to(conn) == "/domains"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "bare domain"
    end

    test "shows the records to publish and how far along it is", %{conn: conn, user: user} do
      domain = domain_fixture(user, %{verified: false})
      body = conn |> get("/domains/#{domain.name}") |> html_response(200)

      assert body =~ "v=spf1"
      assert body =~ "v=DKIM1"
      assert body =~ "SPF record published"
      assert body =~ "Not verified yet"
    end

    test "verifying says what is still missing", %{conn: conn, user: user} do
      domain = domain_fixture(user, %{verified: false})
      conn = post(conn, "/domains/#{domain.name}/verify")

      assert redirected_to(conn) == "/domains/#{domain.name}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "SPF and DKIM"
    end

    test "another account's domain is not reachable", %{conn: conn} do
      other = domain_fixture(account())

      conn = get(conn, "/domains/#{other.name}")
      assert redirected_to(conn) == "/domains"
    end
  end

  describe "sending" do
    setup %{conn: conn} do
      user = account()
      domain = domain_fixture(user)
      %{conn: sign_in(conn, user), user: user, domain: domain}
    end

    test "says so when there is nothing to send from", %{conn: conn} do
      user = account()
      body = build_conn() |> sign_in(user) |> get("/send") |> html_response(200)

      assert body =~ "No verified domain yet"
    end

    test "offers only verified domains", %{conn: conn, user: user, domain: domain} do
      unverified = domain_fixture(user, %{verified: false})
      body = conn |> get("/send") |> html_response(200)

      assert body =~ domain.name
      refute body =~ unverified.name
    end

    test "sends, and lands on the message list", %{conn: conn, domain: domain} do
      conn =
        post(conn, "/send", %{
          "domain" => domain.name,
          "from" => "me@#{domain.name}",
          "to" => "someone@elsewhere.test",
          "subject" => "Hello",
          "text" => "Body"
        })

      assert redirected_to(conn) == "/messages"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Queued"
    end

    test "test mode says plainly that nothing was sent", %{conn: conn, domain: domain} do
      conn =
        post(conn, "/send", %{
          "domain" => domain.name,
          "from" => "me@#{domain.name}",
          "to" => "someone@elsewhere.test",
          "text" => "Body",
          "test_mode" => "yes"
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Nothing was sent"
    end

    test "refuses a from address on someone else's domain, in plain words",
         %{conn: conn, domain: domain} do
      conn =
        post(conn, "/send", %{
          "domain" => domain.name,
          "from" => "spoofed@not-mine.test",
          "to" => "victim@elsewhere.test",
          "text" => "Body"
        })

      body = html_response(conn, 200)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "must be an address at #{domain.name}"

      # What was typed comes back, rather than an empty form.
      assert body =~ "victim@elsewhere.test"
    end

    test "cannot send from a domain belonging to someone else", %{conn: conn} do
      other = domain_fixture(account())

      conn =
        post(conn, "/send", %{
          "domain" => other.name,
          "from" => "me@#{other.name}",
          "to" => "someone@elsewhere.test",
          "text" => "Body"
        })

      assert html_response(conn, 200)
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "domain you own"
    end
  end

  describe "api keys" do
    setup %{conn: conn} do
      user = account()
      %{conn: sign_in(conn, user), user: user}
    end

    test "created and revoked from the page", %{conn: conn, user: user} do
      created = post(conn, "/account/keys", %{"label" => "for the script"})
      assert redirected_to(created) == "/account"

      [key] = Accounts.list_api_keys(user)
      assert key.label == "for the script"

      revoked = build_conn() |> sign_in(user) |> post("/account/keys/#{key.id}/revoke")
      assert redirected_to(revoked) == "/account"
      assert [%{revoked_at: revoked_at}] = Accounts.list_api_keys(user)
      assert revoked_at
    end

    test "cannot revoke a key belonging to someone else", %{conn: conn} do
      {other_key, _plaintext} = api_key_fixture(account())

      conn = post(conn, "/account/keys/#{other_key.id}/revoke")

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "No such key"
      assert %{revoked_at: nil} = EmailProvider.Repo.get!(Accounts.ApiKey, other_key.id)
    end
  end

  describe "forms" do
    test "every one of them carries a CSRF token", %{conn: conn} do
      user = account()
      domain = domain_fixture(user)
      authed = sign_in(conn, user)

      for path <- ["/login", "/signup"] do
        assert build_conn() |> get(path) |> html_response(200) =~ "_csrf_token",
               "#{path} has an unprotected form"
      end

      for path <- ["/domains", "/send", "/account", "/domains/#{domain.name}"] do
        assert authed |> recycle() |> sign_in(user) |> get(path) |> html_response(200) =~
                 "_csrf_token",
               "#{path} has an unprotected form"
      end
    end
  end
end
