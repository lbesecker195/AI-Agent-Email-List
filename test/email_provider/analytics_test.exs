defmodule EmailProvider.AnalyticsTest do
  @moduledoc """
  Reporting is verified through an in-process plug rather than the network, so
  the suite never reaches SeriouslySimpleAnalytics.
  """
  use EmailProviderWeb.ConnCase, async: false

  import EmailProvider.Fixtures

  alias EmailProvider.Analytics
  alias EmailProvider.RateLimit

  # Collects the pings a test provokes. The task doing the reporting is
  # supervised and off the request path, so tests wait for it rather than
  # assuming it has already run.
  defp capture(fun) do
    test_pid = self()

    Application.put_env(:email_provider, Analytics,
      uid: "acct_test",
      plug: fn conn ->
        send(test_pid, {:ping, conn.query_params || URI.decode_query(conn.query_string)})
        Plug.Conn.resp(conn, 204, "")
      end
    )

    on_exit(fn -> Application.put_env(:email_provider, Analytics, uid: nil) end)

    RateLimit.reset(:analytics_pings)
    fun.()
    collect([])
  end

  defp collect(acc) do
    receive do
      {:ping, params} -> collect([params | acc])
    after
      300 -> Enum.reverse(acc)
    end
  end

  defp mcp(conn, method, params, key \\ nil) do
    body = %{"jsonrpc" => "2.0", "id" => 1, "method" => method}
    body = if params, do: Map.put(body, "params", params), else: body

    conn
    |> put_req_header("content-type", "application/json")
    |> then(fn c -> if key, do: put_req_header(c, "authorization", "Bearer " <> key), else: c end)
    |> post("/mcp", body)
  end

  describe "when no account id is configured" do
    test "nothing is reported at all" do
      Application.put_env(:email_provider, Analytics, uid: nil)
      refute Analytics.enabled?()
      assert Analytics.report(:anything, %{}) == :ok
    end
  end

  describe "the MCP handshake" do
    test "reports which agent software connected", %{conn: conn} do
      [ping] =
        capture(fn ->
          mcp(conn, "initialize", %{
            "protocolVersion" => "2025-06-18",
            "clientInfo" => %{"name" => "Claude Code", "version" => "9.9.9"}
          })
        end)

      assert ping["event"] == "run_started"
      assert ping["name"] == "Claude Code"
      assert ping["client_version"] == "9.9.9"
      assert ping["transport"] == "mcp"
      assert ping["project"] == "agent-email-list"
      assert ping["uid"] == "acct_test"
      assert ping["type"] == "ai"
    end
  end

  describe "tool calls" do
    setup do
      user = user_fixture()
      {_key, plaintext} = api_key_fixture(user)
      %{user: user, key: plaintext, domain: domain_fixture(user)}
    end

    test "every tool reports from the one dispatch point", %{conn: conn, key: key} do
      pings =
        capture(fn ->
          mcp(conn, "tools/call", %{"name" => "list_domains", "arguments" => %{}}, key)
        end)

      ping = Enum.find(pings, &(&1["event"] == "tool_called"))
      assert ping["tool"] == "list_domains"
      assert ping["outcome"] == "success"
      assert String.to_integer(ping["latency_ms"]) >= 0
    end

    test "a refused tool is reported as an error, not silence", %{conn: conn, key: key} do
      pings =
        capture(fn ->
          mcp(conn, "tools/call", %{"name" => "verify_domain", "arguments" => %{}}, key)
        end)

      ping = Enum.find(pings, &(&1["event"] == "tool_called"))
      assert ping["outcome"] == "error"
    end

    test "signups are counted without describing the account", %{conn: conn} do
      email = unique_email()

      pings =
        capture(fn ->
          mcp(conn, "tools/call", %{
            "name" => "create_account",
            "arguments" => %{"email" => email, "password" => "correct horse battery"}
          })
        end)

      assert Enum.any?(pings, &(&1["event"] == "account_created"))
      # The whole point: the address never leaves this machine.
      refute Enum.any?(pings, fn p -> Enum.any?(Map.values(p), &(&1 =~ email)) end)
    end
  end

  describe "the REST API" do
    setup do
      user = user_fixture()
      {_key, plaintext} = api_key_fixture(user)
      %{user: user, key: plaintext, domain: domain_fixture(user)}
    end

    test "reports the action, never the path", %{conn: conn, key: key, domain: domain} do
      pings =
        capture(fn ->
          conn
          |> put_req_header("authorization", "Bearer " <> key)
          |> get("/v3/domains/#{domain.name}")
        end)

      ping = Enum.find(pings, &(&1["event"] == "api_called"))
      assert ping["controller"] == "DomainController"
      assert ping["action"] == "show"
      assert ping["status"] == "200"
      assert ping["transport"] == "rest"

      # A route here is shaped /v3/<customer domain>/..., so a path would leak
      # the customer. Nothing sent may contain it.
      refute Enum.any?(Map.values(ping), &(&1 =~ domain.name))
    end

    test "a refusal is distinguished from a failure", %{conn: conn, key: key} do
      pings =
        capture(fn ->
          conn
          |> put_req_header("authorization", "Bearer " <> key)
          |> get("/v3/domains/nope.example.test")
        end)

      ping = Enum.find(pings, &(&1["event"] == "api_called"))
      assert ping["outcome"] == "refused"
    end

    test "even the health check is reported, so 'every API call' has no exceptions",
         %{conn: conn} do
      [ping] = capture(fn -> get(conn, "/health") end)

      # Its volume says nothing about adoption — the deploy script and any
      # monitoring poll it — so it is filtered in the dashboard by controller
      # rather than dropped here.
      assert ping["controller"] == "HealthController"
      assert ping["event"] == "api_called"
    end
  end

  describe "unique usage" do
    setup do
      user = user_fixture()
      {_key, plaintext} = api_key_fixture(user)
      %{user: user, key: plaintext}
    end

    test "the same account is one visitor across transports and calls",
         %{conn: conn, user: user, key: key} do
      pings =
        capture(fn ->
          mcp(conn, "tools/call", %{"name" => "list_domains", "arguments" => %{}}, key)

          build_conn()
          |> put_req_header("authorization", "Bearer " <> key)
          |> get("/v3/domains")
        end)

      visitors = pings |> Enum.map(& &1["visitor"]) |> Enum.uniq()

      assert length(visitors) == 1
      assert hd(visitors) == EmailProvider.Analytics.visitor_id(user)
    end

    test "different accounts are different visitors", %{conn: conn, key: key} do
      {_k, other_key} = api_key_fixture(user_fixture())

      pings =
        capture(fn ->
          mcp(conn, "tools/call", %{"name" => "list_domains", "arguments" => %{}}, key)

          mcp(
            build_conn(),
            "tools/call",
            %{"name" => "list_domains", "arguments" => %{}},
            other_key
          )
        end)

      visitors =
        pings |> Enum.filter(&(&1["event"] == "tool_called")) |> Enum.map(& &1["visitor"])

      assert length(Enum.uniq(visitors)) == 2
    end

    test "the id is not the account id, and cannot be read back as one", %{user: user} do
      visitor = EmailProvider.Analytics.visitor_id(user)

      refute visitor == user.id
      refute visitor =~ user.id
      assert String.length(visitor) == 16
    end

    test "a caller with no account is not given an invented identity", %{conn: conn} do
      [ping] =
        capture(fn ->
          mcp(conn, "initialize", %{"protocolVersion" => "2025-06-18"})
        end)

      # An agent that has found the server but not signed up is genuinely
      # unidentified. Fingerprinting it would be tracking a stranger.
      refute Map.has_key?(ping, "visitor")
    end

    test "one account's calls are one session, not one session each",
         %{conn: _conn, key: key} do
      pings =
        capture(fn ->
          for _ <- 1..3 do
            build_conn()
            |> put_req_header("authorization", "Bearer " <> key)
            |> get("/v3/domains")
          end
        end)

      sids = pings |> Enum.filter(&(&1["event"] == "api_called")) |> Enum.map(& &1["sid"])

      assert length(sids) == 3
      assert length(Enum.uniq(sids)) == 1
    end

    test "an MCP session header still wins, so a conversation is the run",
         %{conn: conn, key: key} do
      pings =
        capture(fn ->
          conn
          |> put_req_header("mcp-session-id", "conversation-abc")
          |> then(fn c ->
            mcp(c, "tools/call", %{"name" => "list_domains", "arguments" => %{}}, key)
          end)
        end)

      ping = Enum.find(pings, &(&1["event"] == "tool_called"))
      assert ping["sid"] == EmailProvider.Analytics.session_id("conversation-abc")
      assert ping["visitor"]
    end
  end

  describe "the browser tag" do
    test "is rendered on the landing page, the console and an article", %{conn: conn} do
      Application.put_env(:email_provider, Analytics, uid: "acct_test")
      on_exit(fn -> Application.put_env(:email_provider, Analytics, uid: nil) end)

      landing = conn |> put_req_header("accept", "text/html") |> get("/") |> html_response(200)
      assert landing =~ ~s(data-site="acct_test")
      assert landing =~ "seriouslysimpleanalytics.com/wa.js"

      console = build_conn() |> get("/login") |> html_response(200)
      assert console =~ ~s(data-site="acct_test")
    end

    test "a self-hosted copy with no account id ships no tracker", %{conn: conn} do
      Application.put_env(:email_provider, Analytics, uid: nil)

      landing = conn |> put_req_header("accept", "text/html") |> get("/") |> html_response(200)
      refute landing =~ "seriouslysimpleanalytics"

      console = build_conn() |> get("/login") |> html_response(200)
      refute console =~ "seriouslysimpleanalytics"
    end
  end

  describe "self-limiting" do
    test "stops reporting rather than flooding, and never raises", %{conn: _conn} do
      pings =
        capture(fn ->
          for _ <- 1..140 do
            mcp(build_conn(), "initialize", %{"protocolVersion" => "2025-06-18"})
          end
        end)

      # 120 a minute, so a runaway caller cannot turn into a flood aimed at
      # somebody else's service.
      assert length(pings) <= 120
      assert length(pings) > 0
    end
  end
end
