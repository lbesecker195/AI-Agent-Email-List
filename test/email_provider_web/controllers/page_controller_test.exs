defmodule EmailProviderWeb.PageControllerTest do
  use EmailProviderWeb.ConnCase, async: true

  alias EmailProvider.Warmup

  describe "GET /" do
    test "a browser gets a page, not a 404", %{conn: conn} do
      body =
        conn
        |> put_req_header("accept", "text/html,application/xhtml+xml,*/*;q=0.8")
        |> get("/")
        |> html_response(200)

      assert body =~ "Agent Email List"
      assert body =~ "/llms.txt"
      assert body =~ "me@LoganBesecker.com"
    end

    test "anything else gets JSON it can parse", %{conn: conn} do
      body = conn |> get("/") |> json_response(200)

      assert body["service"] == "Agent Email List"
      assert body["documentation"] =~ "/llms.txt"
      assert body["start_here"]["url"] =~ "/v1/accounts"
    end

    test "both point at the host the caller actually reached", %{conn: conn} do
      assert conn |> get("/") |> json_response(200) |> Map.get("health") ==
               "http://www.example.com/health"
    end

    test "a strict text/html request is still served", %{conn: conn} do
      # Real browsers send */* as well, which the json-only pipeline accepts by
      # accident. A client that asks for html and nothing else must not get a 406.
      body =
        conn
        |> put_req_header("accept", "text/html")
        |> get("/")
        |> html_response(200)

      assert body =~ "Agent Email List"
    end

    test "needs no credentials", %{conn: conn} do
      assert conn |> get("/") |> json_response(200)
    end
  end

  describe "GET /llms.txt" do
    test "is readable without a key", %{conn: conn} do
      conn = get(conn, "/llms.txt")

      assert response(conn, 200)
      assert response_content_type(conn, :txt) =~ "text/plain"
    end

    test "renders fully, with nothing left unsubstituted", %{conn: conn} do
      body = conn |> get("/llms.txt") |> response(200)

      refute body =~ "<%"
      refute body =~ "%>"
      refute body =~ "@base_url"
    end

    test "points at the host the agent actually reached", %{conn: conn} do
      body = conn |> get("/llms.txt") |> response(200)

      assert body =~ "Base URL: http://www.example.com"
      assert body =~ "curl -X POST http://www.example.com/v1/accounts"
    end

    test "the ladder it publishes is the ladder the service enforces", %{conn: conn} do
      body = conn |> get("/llms.txt") |> response(200)

      # The point of generating this file rather than writing it: an agent that
      # plans a bulk send against these numbers must meet these numbers.
      for {stage, index} <- Enum.with_index(Warmup.stages(), 1) do
        cap =
          case stage.daily_limit do
            :unlimited -> "unlimited"
            n -> delimit(n)
          end

        assert body =~ "| #{index} | #{cap} |",
               "rung #{index} (#{cap}/day) is missing from llms.txt"
      end
    end

    test "a changed ladder changes the file", %{conn: conn} do
      previous = Application.get_env(:email_provider, Warmup, [])

      Application.put_env(:email_provider, Warmup,
        stages: [
          %{daily_limit: 7, until: {:sending_days, 3}},
          %{daily_limit: :unlimited, until: :never}
        ]
      )

      on_exit(fn -> Application.put_env(:email_provider, Warmup, previous) end)

      body = conn |> get("/llms.txt") |> response(200)

      assert body =~ "| 1 | 7 | after sending on 3 separate days |"
      assert body =~ "still starts at 7 messages a day"
      refute body =~ "| 1 | 10 |"
    end

    test "names the DNS hosts a customer has to publish", %{conn: conn} do
      body = conn |> get("/llms.txt") |> response(200)

      assert body =~ EmailProvider.Domains.spf_host()
      assert body =~ EmailProvider.Domains.mx_host()
    end

    test "tells an agent the things that will stop its first send", %{conn: conn} do
      body = conn |> get("/llms.txt") |> response(200)

      assert body =~ "domain_not_verified"
      assert body =~ "content_rejected"
      assert body =~ "forbidden_sender"
      assert body =~ "retry_after_seconds"
      assert body =~ "o:testmode=yes"
    end

    test "every endpoint it advertises is really routed", %{conn: conn} do
      body = conn |> get("/llms.txt") |> response(200)

      routes =
        Phoenix.Router.routes(EmailProviderWeb.Router)
        |> Enum.map(&{&1.verb, &1.path})

      advertised =
        Regex.scan(
          ~r/^- `((?:GET|POST|PUT|DELETE)(?:\|(?:GET|POST|PUT|DELETE))*) ([^`]+)`/m,
          body
        )

      assert advertised != []

      for [_line, verbs, path] <- advertised,
          verb <- String.split(verbs, "|") do
        method = verb |> String.downcase() |> String.to_atom()

        assert {method, normalize(path)} in routes,
               "llms.txt advertises #{verb} #{path}, which is not routed"
      end
    end
  end

  # llms.txt documents query parameters and writes `<list>` where the router
  # writes one concrete list; compare route shapes, not spellings.
  defp normalize(path) do
    path
    |> String.split("?")
    |> hd()
    |> String.replace("/<list>", "/bounces")
  end

  defp delimit(n) do
    n
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  test "robots.txt points agents at llms.txt", %{conn: conn} do
    body = conn |> get("/robots.txt") |> response(200)
    assert body =~ "/llms.txt"
  end
end
