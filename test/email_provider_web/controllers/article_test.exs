defmodule EmailProviderWeb.ArticleTest do
  use EmailProviderWeb.ConnCase, async: true

  alias EmailProviderWeb.Articles

  describe "the article page" do
    test "serves at its keyword slug, without a key", %{conn: conn} do
      body = conn |> get("/free-smtp-relay") |> html_response(200)

      assert body =~ "Free SMTP Relay"
      assert body =~ "Mailgun"
    end

    test "carries the metadata a search engine reads", %{conn: conn} do
      body = conn |> get("/free-smtp-relay") |> html_response(200)

      assert body =~ "<title>Free SMTP Relay: Mailgun &amp; SendGrid Alternatives (2026)</title>"
      assert body =~ ~s(<meta name="description")
      assert body =~ ~s(rel="canonical" href="http://www.example.com/free-smtp-relay")
      assert body =~ ~s(property="og:type" content="article")
      assert body =~ ~s(application/ld+json)
      assert body =~ "Article"
    end

    test "the title and description fit what search results actually show", %{conn: _conn} do
      article = Articles.get("free-smtp-relay")

      # Past roughly these lengths the tail is truncated and wasted, which for a
      # title means losing the keyword off the end.
      assert String.length(article.title) <= 60
      assert String.length(article.description) <= 165
      assert article.title =~ "Free SMTP Relay"
      assert article.description =~ "free SMTP relay"
    end

    test "every section is anchored and listed in the contents", %{conn: conn} do
      body = conn |> get("/free-smtp-relay") |> html_response(200)
      article = Articles.get("free-smtp-relay")

      assert length(article.sections) == 14

      for section <- article.sections do
        assert body =~ ~s(id="#{section.id}"), "#{section.id} has no anchor"
        assert body =~ ~s(href="##{section.id}"), "#{section.id} is not in the contents"
      end
    end

    test "renders tables, which the comparison sections depend on", %{conn: conn} do
      body = conn |> get("/free-smtp-relay") |> html_response(200)
      assert length(Regex.scan(~r/<table>/, body)) >= 4
    end

    test "no raw script tag survives from the markdown", %{conn: conn} do
      # The renderer drops raw HTML. These files are hand-written today, and the
      # day one is not, this is the thing standing between a contributor and
      # stored XSS on the highest-traffic page on the site.
      body = conn |> get("/free-smtp-relay") |> html_response(200)
      article = Articles.get("free-smtp-relay")

      refute article.html =~ "<script"
      refute body =~ "<script>alert"
    end

    test "an unknown slug is a 404, not a blank article", %{conn: conn} do
      assert conn |> get("/no-such-article") |> response(404)
    end
  end

  describe "discovery" do
    test "the sitemap lists the article", %{conn: conn} do
      body = conn |> get("/sitemap.xml") |> response(200)

      assert body =~ "<loc>http://www.example.com/free-smtp-relay</loc>"
      assert body =~ "<lastmod>2026-09-14</lastmod>"
      assert body =~ "<loc>http://www.example.com/</loc>"
    end

    test "robots.txt points at the sitemap", %{conn: conn} do
      assert conn |> get("/robots.txt") |> response(200) =~ "Sitemap:"
    end

    test "the landing page links to it", %{conn: conn} do
      body = conn |> put_req_header("accept", "text/html") |> get("/") |> html_response(200)
      assert body =~ ~s(href="/free-smtp-relay")
    end

    test "adding the catch-all did not swallow the other routes", %{conn: conn} do
      # /:slug matches any single segment, so anything declared after it becomes
      # unreachable. /health did exactly that once.
      assert conn |> get("/health") |> json_response(200)
      assert build_conn() |> get("/llms.txt") |> response(200)
      assert build_conn() |> get("/sitemap.xml") |> response(200)
      assert build_conn() |> get("/admin") |> html_response(200)
      assert build_conn() |> get("/signup") |> html_response(200)
    end
  end
end
