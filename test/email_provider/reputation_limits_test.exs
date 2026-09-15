defmodule EmailProvider.ReputationLimitsTest do
  @moduledoc """
  The tier limits, enforced at the places that actually create domains.

  Not async, and in its own file, because these set the limits in application
  env. That is global: an async test doing it would change the limits underneath
  whatever else happened to be running.
  """
  use EmailProviderWeb.ConnCase, async: false

  import EmailProvider.Fixtures

  alias EmailProvider.Domains

  setup do
    Application.put_env(:email_provider, EmailProvider.Reputation,
      domains_new: 1,
      domains_committed: 1
    )

    on_exit(fn -> Application.delete_env(:email_provider, EmailProvider.Reputation) end)

    user = user_fixture()
    {_key, plaintext} = api_key_fixture(user)
    %{user: user, key: plaintext}
  end

  test "the context refuses past the limit", %{user: user} do
    assert {:ok, _domain, _password} =
             Domains.create_domain(user, %{"name" => "first.example.test"})

    assert {:error, :domain_limit, message} =
             Domains.create_domain(user, %{"name" => "second.example.test"})

    assert message =~ "limit"
  end

  test "the REST API answers 403 with the reason, not a validation error",
       %{user: user, key: key} do
    domain_fixture(user, %{verified: false})

    body =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> key)
      |> post("/v3/domains", %{"name" => "over.example.test"})
      |> json_response(403)

    assert body["message"] =~ "limit"
    assert body["message"] =~ "Verifying"
  end

  test "the MCP tool explains it in a sentence an agent can act on",
       %{user: user, key: key} do
    domain_fixture(user, %{verified: false})

    result =
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "Bearer " <> key)
      |> post("/mcp", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "tools/call",
        "params" => %{
          "name" => "add_domain",
          "arguments" => %{"name" => "over.example.test"}
        }
      })
      |> json_response(200)
      |> Map.fetch!("result")

    assert result["isError"]
    text = hd(result["content"])["text"]
    assert text =~ "limit"
    assert text =~ "Verifying"
  end

  test "the console says so in a flash rather than a blank failure",
       %{user: user} do
    domain_fixture(user, %{verified: false})

    conn =
      build_conn()
      |> Phoenix.ConnTest.init_test_session(%{user_id: user.id})
      |> post("/domains", %{"name" => "over.example.test"})

    assert redirected_to(conn) == "/domains"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "limit"
  end
end
