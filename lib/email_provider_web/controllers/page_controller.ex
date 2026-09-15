defmodule EmailProviderWeb.PageController do
  use EmailProviderWeb, :controller

  require EEx

  alias EmailProvider.{Domains, Warmup}

  @llms_template Path.join(:code.priv_dir(:email_provider), "templates/llms.txt.eex")
  @external_resource @llms_template

  EEx.function_from_file(:defp, :render_llms, @llms_template, [:assigns])

  @contact "me@LoganBesecker.com"

  @doc """
  GET /

  Content-negotiated, because two very different callers arrive here. A person
  following the domain gets a page describing the service; anything asking for
  JSON gets a descriptor it can parse. Returning a bare 404 at the root of a
  service, which is what an API-only app does by default, tells neither of them
  anything.
  """
  def index(conn, _params) do
    if wants_html?(conn) do
      conn
      |> put_resp_content_type("text/html")
      |> send_resp(200, EmailProviderWeb.PageHTML.index(base_url(conn), @contact))
    else
      json(conn, %{
        service: "Agent Email List",
        description: "Email sending and receiving API. Mailgun-shaped.",
        documentation: base_url(conn) <> "/llms.txt",
        health: base_url(conn) <> "/health",
        source: "https://github.com/lbesecker195/AI-Agent-Email-List",
        contact: @contact,
        start_here: %{
          method: "POST",
          url: base_url(conn) <> "/v1/accounts",
          params: %{email: "you@company.com", password: "a sufficiently long password"}
        }
      })
    end
  end

  # Browsers ask for text/html explicitly. Everything else — curl with no
  # headers, an HTTP library, an agent — gets JSON, which is the safer default
  # for a service whose every other endpoint speaks it.
  defp wants_html?(conn) do
    conn
    |> Plug.Conn.get_req_header("accept")
    |> Enum.any?(&String.contains?(&1, "text/html"))
  end

  @doc """
  GET /app

  Kept as a redirect. It used to be a single-page dashboard, which the
  server-rendered console replaced; two things doing the same job is worse than
  one, and an old link should still land somewhere sensible.
  """
  def app(conn, _params), do: redirect(conn, to: "/domains")

  @doc """
  GET /:slug — one article.

  Everything is rendered at compile time, so this action only assembles the
  metadata that depends on the request: the canonical URL has to name the host
  the reader actually reached, or two hostnames pointing here would compete with
  each other in search results for the same page.
  """
  def article(conn, %{"slug" => slug}) do
    case EmailProviderWeb.Articles.get(slug) do
      nil ->
        conn
        |> put_status(:not_found)
        |> put_resp_content_type("application/json")
        |> send_resp(404, Jason.encode!(%{message: "not found"}))

      article ->
        canonical = base_url(conn) <> "/" <> article.slug

        conn
        |> put_view(html: EmailProviderWeb.ConsoleHTML)
        |> render(:article,
          article: article,
          canonical: canonical,
          published_on: pretty_date(article.published),
          # 200 words a minute is the usual reading estimate for prose.
          reading_minutes: max(div(article.words, 200), 1),
          structured_data: structured_data(article, canonical)
        )
    end
  end

  defp pretty_date(iso) do
    case Date.from_iso8601(iso) do
      {:ok, date} -> Calendar.strftime(date, "%d %B %Y")
      _ -> iso
    end
  end

  # Schema.org Article, so a search engine has the headline, date and author
  # without having to infer them from the markup.
  defp structured_data(article, canonical) do
    Jason.encode!(
      %{
        "@context" => "https://schema.org",
        "@type" => "Article",
        "headline" => article.title,
        "description" => article.description,
        "datePublished" => article.published,
        "dateModified" => article.published,
        "author" => %{"@type" => "Person", "name" => "Logan Besecker"},
        "publisher" => %{"@type" => "Organization", "name" => "Agent Email List"},
        "mainEntityOfPage" => %{"@type" => "WebPage", "@id" => canonical},
        "wordCount" => article.words,
        "about" => article.keyword
      },
      # Escapes < > and & as \u sequences, so no value can close the script tag
      # early and start writing markup of its own.
      escape: :html_safe
    )
  end

  @doc """
  GET /.well-known/mcp-registry-auth

  Proves to the MCP registry that whoever publishes under this domain's
  namespace controls the domain. The value is a public key, so serving it
  openly is the entire point; the private half never leaves the operator.
  """
  def mcp_registry_auth(conn, _params) do
    case Application.get_env(:email_provider, :mcp_registry_public_key) do
      key when is_binary(key) and key != "" ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, "v=MCPv1; k=ed25519; p=" <> key)

      _ ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(404, "No MCP registry key is configured for this deployment.")
    end
  end

  @doc """
  GET /sitemap.xml

  Only the pages worth indexing. The console is behind a session and the API is
  not prose, so neither belongs here.
  """
  def sitemap(conn, _params) do
    base = base_url(conn)

    urls =
      [
        %{loc: base <> "/", priority: "1.0"},
        %{loc: base <> "/llms.txt", priority: "0.5"}
      ] ++
        Enum.map(EmailProviderWeb.Articles.all(), fn article ->
          %{loc: base <> "/" <> article.slug, priority: "0.9", lastmod: article.published}
        end)

    body =
      [
        ~s(<?xml version="1.0" encoding="UTF-8"?>),
        ~s(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">),
        Enum.map(urls, fn url ->
          [
            "<url><loc>",
            url.loc,
            "</loc>",
            if(url[:lastmod], do: "<lastmod>#{url.lastmod}</lastmod>", else: ""),
            "<priority>",
            url.priority,
            "</priority></url>"
          ]
        end),
        "</urlset>"
      ]
      |> IO.iodata_to_binary()

    conn |> put_resp_content_type("application/xml") |> send_resp(200, body)
  end

  @doc """
  GET /llms.txt

  The agent-facing description of this API.

  The sending ladder in it is read from the running configuration rather than
  written down, so the limits an agent plans around are the limits it will
  actually meet. A quickstart that is wrong about the cap is worse than no
  quickstart: the agent finds out at message eleven, halfway through a job.

  Served as text/plain so it reads the same in a terminal and a browser.
  """
  def llms(conn, _params) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, render_llms(assigns(conn)))
  end

  defp assigns(conn) do
    %{
      base_url: base_url(conn),
      ladder: ladder(),
      first_cap: first_cap(),
      spf_host: Domains.spf_host(),
      mx_host: Domains.mx_host(),
      profile_words: EmailProvider.Profiles.target_words()
    }
  end

  defp base_url(conn) do
    case Application.get_env(:email_provider, :public_base_url) do
      url when is_binary(url) -> String.trim_trailing(url, "/")
      _ -> "#{conn.scheme}://#{conn.host}#{port_suffix(conn)}"
    end
  end

  defp port_suffix(%{scheme: :http, port: 80}), do: ""
  defp port_suffix(%{scheme: :https, port: 443}), do: ""
  defp port_suffix(%{port: port}), do: ":#{port}"

  # The ladder as rows, so the template stays presentation and the meaning of
  # each rung is decided in one place.
  defp ladder do
    Warmup.stages()
    |> Enum.with_index(1)
    |> Enum.map(fn {stage, index} ->
      %{
        index: index,
        cap: format_cap(stage.daily_limit),
        rule: describe(stage.until)
      }
    end)
  end

  defp first_cap do
    case Warmup.stages() do
      [%{daily_limit: limit} | _] -> format_cap(limit)
      _ -> "unknown"
    end
  end

  defp format_cap(:unlimited), do: "unlimited"
  defp format_cap(n) when is_integer(n), do: delimit(n)

  defp describe(:never), do: "nothing; this is the last rung"
  defp describe({:sending_days, n}), do: "after sending on #{n} separate days"

  defp describe({:stage_volume, n}),
    do: "after #{delimit(n)} more messages sent while on this rung"

  defp describe({:lifetime_sent, n}), do: "at #{delimit(n)} messages lifetime"

  defp delimit(n) do
    n
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end
end
