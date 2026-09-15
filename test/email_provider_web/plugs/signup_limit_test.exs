defmodule EmailProviderWeb.Plugs.SignupLimitTest do
  # Not async: these set the limit globally and fill a global counter table.
  use EmailProviderWeb.ConnCase, async: false

  import EmailProvider.Fixtures

  alias EmailProvider.RateLimit
  alias EmailProviderWeb.Plugs.SignupLimit

  setup do
    RateLimit.reset_all()
    Application.put_env(:email_provider, SignupLimit, per_hour: 2, per_day: 3)

    on_exit(fn ->
      Application.put_env(:email_provider, SignupLimit, per_hour: 1_000_000, per_day: 1_000_000)
      RateLimit.reset_all()
    end)

    :ok
  end

  defp signup(conn) do
    post(conn, "/v1/accounts", %{
      email: unique_email(),
      password: "correct horse battery",
      name: "Agent"
    })
  end

  test "lets the first few through and then refuses with a retry-after", %{conn: conn} do
    assert json_response(signup(conn), 201)
    assert json_response(signup(build_conn()), 201)

    refused = signup(build_conn())
    body = json_response(refused, 429)

    assert body["message"] =~ "Too many accounts"
    assert body["retry_after_seconds"] > 0
    # An agent that is told to wait but not how long will simply hammer.
    assert get_resp_header(refused, "retry-after") != []
  end

  test "counts by address, so a different one is unaffected", %{conn: conn} do
    signup(conn)
    signup(build_conn())
    assert json_response(signup(build_conn()), 429)

    elsewhere = build_conn() |> put_req_header("x-forwarded-for", "203.0.113.9")
    assert json_response(signup(elsewhere), 201)
  end

  test "trusts the address nginx appended, not one the client prepended", %{conn: _conn} do
    # A client can put anything at the front of x-forwarded-for. nginx appends
    # the real peer, so only the last value means anything.
    for _ <- 1..2 do
      build_conn()
      |> put_req_header("x-forwarded-for", "1.1.1.1, 198.51.100.7")
      |> signup()
    end

    spoofed =
      build_conn()
      |> put_req_header("x-forwarded-for", "9.9.9.9, 198.51.100.7")
      |> signup()

    assert json_response(spoofed, 429)
  end

  test "the MCP signup tool shares the same budget", %{conn: conn} do
    # Two doors into one room. An agent that finds both should not get two
    # allowances.
    signup(conn)
    signup(build_conn())

    result =
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> post("/mcp", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "tools/call",
        "params" => %{
          "name" => "create_account",
          "arguments" => %{"email" => unique_email(), "password" => "correct horse battery"}
        }
      })
      |> json_response(200)
      |> Map.fetch!("result")

    assert result["isError"]
    assert hd(result["content"])["text"] =~ "Too many accounts"
  end

  test "the browser signup is redirected rather than handed JSON", %{conn: conn} do
    signup(conn)
    signup(build_conn())

    conn =
      build_conn()
      |> Phoenix.ConnTest.init_test_session(%{})
      |> post("/signup", %{"email" => unique_email(), "password" => "correct horse battery"})

    assert redirected_to(conn) == "/signup"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Too many accounts"
  end
end
