defmodule EmailProviderWeb.MCPControllerTest do
  use EmailProviderWeb.ConnCase, async: true

  import EmailProvider.Fixtures

  alias EmailProvider.Accounts
  alias EmailProviderWeb.MCP.Tools

  defp rpc(conn, method, params \\ nil, key \\ nil) do
    body = %{"jsonrpc" => "2.0", "id" => 1, "method" => method}
    body = if params, do: Map.put(body, "params", params), else: body

    conn
    |> put_req_header("content-type", "application/json")
    |> then(fn c -> if key, do: put_req_header(c, "authorization", "Bearer " <> key), else: c end)
    |> post("/mcp", body)
  end

  defp call_tool(conn, name, args, key \\ nil) do
    result =
      conn
      |> rpc("tools/call", %{"name" => name, "arguments" => args}, key)
      |> json_response(200)
      |> Map.fetch!("result")

    {result["isError"], hd(result["content"])["text"]}
  end

  describe "the handshake" do
    test "initialize answers with a version and the tools capability", %{conn: conn} do
      result =
        conn
        |> rpc("initialize", %{"protocolVersion" => "2025-06-18", "capabilities" => %{}})
        |> json_response(200)
        |> Map.fetch!("result")

      assert result["protocolVersion"] == "2025-06-18"
      assert result["serverInfo"]["name"] == "agent-email-list"
      assert result["capabilities"]["tools"]
      # The instructions are the first thing an agent reads, so they have to say
      # how to get a key without a human.
      assert result["instructions"] =~ "create_account"
    end

    test "an older protocol version an agent asks for is honoured", %{conn: conn} do
      result =
        conn
        |> rpc("initialize", %{"protocolVersion" => "2024-11-05"})
        |> json_response(200)
        |> Map.fetch!("result")

      assert result["protocolVersion"] == "2024-11-05"
    end

    test "an unknown version falls back rather than failing", %{conn: conn} do
      result =
        conn
        |> rpc("initialize", %{"protocolVersion" => "1999-01-01"})
        |> json_response(200)
        |> Map.fetch!("result")

      assert result["protocolVersion"] == "2025-06-18"
    end

    test "a notification gets no body at all", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/mcp", %{"jsonrpc" => "2.0", "method" => "notifications/initialized"})

      assert response(conn, 202) == ""
    end
  end

  describe "tools/list" do
    test "describes every tool with a schema", %{conn: conn} do
      tools =
        conn |> rpc("tools/list") |> json_response(200) |> get_in(["result", "tools"])

      assert length(tools) == length(Tools.list())

      for tool <- tools do
        assert is_binary(tool["name"])
        assert String.length(tool["description"]) > 40, "#{tool["name"]} needs a real description"
        assert tool["inputSchema"]["type"] == "object"
      end

      names = Enum.map(tools, & &1["name"])
      assert "create_account" in names
      assert "send_email" in names
    end

    test "needs no credentials, so an agent can see what is here first", %{conn: conn} do
      assert conn |> rpc("tools/list") |> json_response(200) |> Map.has_key?("result")
    end
  end

  describe "creating an account from nothing" do
    test "works with no credentials and returns a usable key", %{conn: conn} do
      email = unique_email()

      {error?, text} =
        call_tool(conn, "create_account", %{"email" => email, "password" => "a long enough one"})

      refute error?
      assert text =~ "ep_live_"
      assert Accounts.get_user_by_email(email)

      # The key it just handed out has to actually work.
      key = Regex.run(~r/ep_live_\S+/, text) |> hd()
      {error?, _text} = call_tool(build_conn(), "list_domains", %{}, key)
      refute error?
    end

    test "reports a bad password rather than half-creating an account", %{conn: conn} do
      email = unique_email()
      {error?, text} = call_tool(conn, "create_account", %{"email" => email, "password" => "x"})

      assert error?
      assert text =~ "password"
      assert is_nil(Accounts.get_user_by_email(email))
    end
  end

  describe "tools that need a key" do
    test "say how to get one instead of just refusing", %{conn: conn} do
      {error?, text} = call_tool(conn, "list_domains", %{})

      assert error?
      # A bare 401 tells an agent nothing it can act on.
      assert text =~ "create_account"
      assert text =~ "Bearer"
    end

    test "reject a key that is not real", %{conn: conn} do
      {error?, _text} = call_tool(conn, "list_domains", %{}, "ep_live_nonsense")
      assert error?
    end
  end

  describe "the send path" do
    setup do
      user = user_fixture()
      {_key, plaintext} = api_key_fixture(user)
      %{user: user, key: plaintext, domain: domain_fixture(user)}
    end

    test "sends, and says that queued is not delivered", %{conn: conn, key: key, domain: domain} do
      {error?, text} =
        call_tool(
          conn,
          "send_email",
          %{
            "domain" => domain.name,
            "from" => "me@#{domain.name}",
            "to" => "someone@elsewhere.test",
            "subject" => "Hi",
            "text" => "Body"
          },
          key
        )

      refute error?
      assert text =~ "Queued"
      assert text =~ "get_delivery_events"
    end

    test "test mode spends no allowance", %{conn: conn, key: key, domain: domain} do
      call_tool(
        conn,
        "send_email",
        %{
          "domain" => domain.name,
          "from" => "me@#{domain.name}",
          "to" => "someone@elsewhere.test",
          "text" => "Body",
          "test_mode" => true
        },
        key
      )

      assert EmailProvider.Warmup.sent_today(domain) == 0
    end

    test "an unverified domain explains what to do next", %{conn: conn, key: key, user: user} do
      unverified = domain_fixture(user, %{verified: false})

      {error?, text} =
        call_tool(
          conn,
          "send_email",
          %{
            "domain" => unverified.name,
            "from" => "me@#{unverified.name}",
            "to" => "someone@elsewhere.test",
            "text" => "Body"
          },
          key
        )

      assert error?
      assert text =~ "verify_domain"
    end

    test "the daily cap says when to retry rather than inviting a loop",
         %{conn: conn, key: key, domain: domain} do
      for n <- 1..10 do
        call_tool(
          conn,
          "send_email",
          %{
            "domain" => domain.name,
            "from" => "me@#{domain.name}",
            "to" => "r#{n}@elsewhere.test",
            "text" => "Body"
          },
          key
        )
      end

      {error?, text} =
        call_tool(
          conn,
          "send_email",
          %{
            "domain" => domain.name,
            "from" => "me@#{domain.name}",
            "to" => "over@elsewhere.test",
            "text" => "Body"
          },
          key
        )

      assert error?
      assert text =~ "Daily limit reached"
      assert text =~ "Do not retry before then"
    end

    test "one account cannot send from another's domain", %{conn: conn, key: key} do
      other = domain_fixture(user_fixture())

      {error?, text} =
        call_tool(
          conn,
          "send_email",
          %{
            "domain" => other.name,
            "from" => "me@#{other.name}",
            "to" => "someone@elsewhere.test",
            "text" => "Body"
          },
          key
        )

      assert error?
      assert text =~ "No domain called"
    end
  end

  describe "protocol errors" do
    test "an unknown method is -32601", %{conn: conn} do
      error = conn |> rpc("no/such/method") |> json_response(200) |> Map.fetch!("error")
      assert error["code"] == -32601
    end

    test "an unknown tool is a params error, not a crash", %{conn: conn} do
      error =
        conn
        |> rpc("tools/call", %{"name" => "nope", "arguments" => %{}})
        |> json_response(200)
        |> Map.fetch!("error")

      assert error["code"] == -32602
    end

    test "a request with no method is rejected", %{conn: conn} do
      error =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/mcp", %{"jsonrpc" => "2.0", "id" => 1})
        |> json_response(200)
        |> Map.fetch!("error")

      assert error["code"] == -32600
    end
  end

  describe "GET /mcp" do
    test "explains itself to somebody who pasted the URL into a browser", %{conn: conn} do
      body = conn |> get("/mcp") |> json_response(200)

      assert body["transport"] =~ "POST"
      assert "create_account" in body["tools"]
      assert body["authentication"] =~ "create_account"
    end
  end
end
