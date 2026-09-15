defmodule EmailProviderWeb.Plugs.ApiAuthLimitTest do
  # Not async: global limit config and a global counter table.
  use EmailProviderWeb.ConnCase, async: false

  import EmailProvider.Fixtures

  alias EmailProvider.RateLimit
  alias EmailProviderWeb.Plugs.ApiAuth

  setup do
    RateLimit.reset_all()
    Application.put_env(:email_provider, ApiAuth, requests_per_minute: 2, failures_per_minute: 2)

    on_exit(fn ->
      Application.put_env(:email_provider, ApiAuth,
        requests_per_minute: 1_000_000,
        failures_per_minute: 1_000_000
      )

      RateLimit.reset_all()
    end)

    user = user_fixture()
    {_key, plaintext} = api_key_fixture(user)
    %{user: user, key: plaintext}
  end

  defp authed(key), do: build_conn() |> put_req_header("authorization", "Bearer " <> key)

  test "a runaway client is paced, and told for how long", %{key: key} do
    assert json_response(get(authed(key), "/v3/domains"), 200)
    assert json_response(get(authed(key), "/v3/domains"), 200)

    conn = get(authed(key), "/v3/domains")
    body = json_response(conn, 429)

    assert body["message"] =~ "pace limit"
    assert get_resp_header(conn, "retry-after") != []
  end

  test "the pace limit is per account, not shared across the service", %{key: key} do
    get(authed(key), "/v3/domains")
    get(authed(key), "/v3/domains")
    assert json_response(get(authed(key), "/v3/domains"), 429)

    {_key, other} = api_key_fixture(user_fixture())
    assert json_response(get(authed(other), "/v3/domains"), 200)
  end

  test "guessing keys is limited by address" do
    for _ <- 1..2 do
      assert json_response(get(authed("ep_live_wrong"), "/v3/domains"), 401)
    end

    conn = get(authed("ep_live_wrong"), "/v3/domains")
    assert json_response(conn, 429)["message"] =~ "failed authentication"
  end

  test "a bad key does not spend a good account's allowance", %{key: key} do
    get(authed("ep_live_wrong"), "/v3/domains")
    get(authed("ep_live_wrong"), "/v3/domains")

    assert json_response(get(authed(key), "/v3/domains"), 200)
  end
end
