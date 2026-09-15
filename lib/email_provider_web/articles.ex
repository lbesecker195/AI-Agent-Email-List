defmodule EmailProviderWeb.Articles do
  @moduledoc """
  Articles, rendered from `priv/articles` at compile time.

  Compile time rather than per request, because the content only changes when
  the code does. A 12,000 word document is not something to re-parse on every
  visit, and there is no markdown parser in the request path at all this way.
  `@external_resource` makes editing a file trigger a recompile.

  Raw HTML in the source is dropped rather than passed through. These files are
  written by hand today, but the moment one is not, "we only render trusted
  markdown" stops being true, and a renderer that escapes by default is the only
  version of this that stays safe.
  """

  @articles_dir Path.join(:code.priv_dir(:email_provider), "articles")

  # Slug, and the SEO metadata that cannot be lifted from the file.
  #
  # The frontmatter title is written for a human scanning a list. A <title> has
  # about 60 characters before Google truncates it, so the two are not the same
  # string and pretending otherwise loses the keyword off the end.
  @definitions [
    %{
      slug: "free-smtp-relay",
      file: "free-smtp-relay.md",
      title: "Free SMTP Relay: Mailgun & SendGrid Alternatives (2026)",
      heading: "Free SMTP Relay: the Mailgun and SendGrid alternatives worth using",
      # Around 155 characters. Past that Google truncates and the last clause is
      # wasted, so the keyword goes near the front.
      description:
        "A free SMTP relay with no trial cliff. Unlimited sending after warmup, " <>
          "a Mailgun-shaped API, SMTP credentials on domain create. Compared with " <>
          "six alternatives.",
      keyword: "free SMTP relay",
      published: "2026-09-14"
    }
  ]

  for %{file: file} <- @definitions do
    @external_resource Path.join(@articles_dir, file)
  end

  @rendered Enum.map(@definitions, fn definition ->
              raw = File.read!(Path.join(@articles_dir, definition.file))

              # Strip YAML frontmatter. Its title and description are superseded
              # by the ones above, which are written to a length search engines
              # will actually show.
              body =
                case String.split(raw, ~r/^---\s*$/m, parts: 3) do
                  ["", _frontmatter, rest] -> String.trim_leading(rest)
                  _ -> raw
                end

              html =
                MDEx.to_html!(body,
                  extension: [
                    table: true,
                    autolink: true,
                    strikethrough: true,
                    tasklist: true,
                    footnotes: true
                  ],
                  render: [unsafe: false],
                  parse: [smart: true]
                )

              # Section headings become anchors so the contents list can link to
              # them, and so a reader can share a link to one answer rather than
              # to twelve thousand words.
              {html, sections} = EmailProviderWeb.Articles.Anchors.apply(html)

              definition
              |> Map.put(:html, html)
              |> Map.put(:sections, sections)
              |> Map.put(:words, body |> String.split(~r/\s+/, trim: true) |> length())
            end)

  @doc "Every article, newest first."
  def all, do: @rendered

  @doc "One article by slug, or nil."
  def get(slug), do: Enum.find(@rendered, &(&1.slug == slug))

  @doc "Slugs, for the sitemap."
  def slugs, do: Enum.map(@rendered, & &1.slug)
end
