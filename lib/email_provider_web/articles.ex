defmodule EmailProviderWeb.Articles do
  @moduledoc """
  Articles, rendered from `priv/articles/*.md` at compile time.

  Every `*.md` file in that directory becomes a page. Metadata comes from the
  YAML frontmatter (title, description, date, optional slug / heading /
  keyword / list_title). The slug defaults to the filename without `.md`.

  Compile time rather than per request, because the content only changes when
  the code does. A 12,000 word document is not something to re-parse on every
  visit, and there is no markdown parser in the request path at all this way.
  `@external_resource` makes editing a file trigger a recompile. Adding a brand
  new file may still need `mix compile --force` once, because Mix only watches
  the paths that existed when this module last compiled.

  Raw HTML in the source is dropped rather than passed through. These files are
  written by hand today, but the moment one is not, "we only render trusted
  markdown" stops being true, and a renderer that escapes by default is the only
  version of this that stays safe.
  """

  defmodule Loader do
    @moduledoc false

    def load(dir, files) do
      files
      |> Enum.map(&load_one(dir, &1))
      |> Enum.sort_by(& &1.published, :desc)
    end

    defp load_one(dir, file) do
      path = Path.join(dir, file)
      raw = File.read!(path)
      {meta, body} = split_frontmatter(raw)

      slug =
        meta
        |> Map.get("slug")
        |> blank_to_nil()
        |> Kernel.||(Path.rootname(file))

      title =
        meta
        |> Map.get("title")
        |> blank_to_nil()
        |> Kernel.||(slug_to_title(slug))

      heading =
        meta
        |> Map.get("heading")
        |> blank_to_nil()
        |> Kernel.||(title)

      description =
        meta
        |> Map.get("description")
        |> blank_to_nil()
        |> Kernel.||("")

      list_title =
        meta
        |> Map.get("list_title")
        |> blank_to_nil()
        |> Kernel.||(heading)

      keyword =
        meta
        |> Map.get("keyword")
        |> blank_to_nil()
        |> Kernel.||(slug |> slug_to_title() |> String.downcase())

      published =
        meta
        |> Map.get("date")
        |> blank_to_nil()
        |> Kernel.||(Map.get(meta, "published"))
        |> blank_to_nil()
        |> Kernel.||("1970-01-01")

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

      %{
        slug: slug,
        file: file,
        title: title,
        heading: heading,
        list_title: list_title,
        description: description,
        keyword: keyword,
        published: published,
        html: html,
        sections: sections,
        words: body |> String.split(~r/\s+/, trim: true) |> length()
      }
    end

    defp split_frontmatter(raw) do
      case String.split(raw, ~r/^---\s*$/m, parts: 3) do
        ["", frontmatter, rest] ->
          {parse_frontmatter(frontmatter), String.trim_leading(rest)}

        _ ->
          {%{}, raw}
      end
    end

    # Enough YAML for `key: value` and `key: "quoted value"` lines. Nested
    # structures are not expected in these article files, and pulling in a YAML
    # library for four string fields would be more moving parts than the files
    # are worth.
    defp parse_frontmatter(text) do
      text
      |> String.split("\n")
      |> Enum.reduce(%{}, fn line, acc ->
        case Regex.run(~r/^([A-Za-z0-9_]+):\s*(.*)$/, line) do
          [_, key, value] ->
            Map.put(acc, key, unquote_yaml(String.trim(value)))

          _ ->
            acc
        end
      end)
    end

    defp unquote_yaml(<<?", rest::binary>>) do
      rest
      |> String.trim_trailing("\"")
      |> String.replace("\\\"", "\"")
    end

    defp unquote_yaml(<<?', rest::binary>>) do
      rest
      |> String.trim_trailing("'")
      |> String.replace("\\'", "'")
    end

    defp unquote_yaml(value), do: value

    defp blank_to_nil(nil), do: nil
    defp blank_to_nil(""), do: nil
    defp blank_to_nil(value) when is_binary(value), do: value

    defp slug_to_title(slug) do
      slug
      |> String.replace("-", " ")
      |> String.split()
      |> Enum.map_join(" ", &String.capitalize/1)
    end
  end

  @articles_dir Path.join(:code.priv_dir(:email_provider), "articles")

  @md_files (
    case File.ls(@articles_dir) do
      {:ok, entries} ->
        entries
        |> Enum.filter(&String.ends_with?(&1, ".md"))
        # Outline drafts live alongside finished copy in the SEO workspace;
        # they should never ship as public pages.
        |> Enum.reject(&String.contains?(&1, "outline"))
        |> Enum.sort()

      {:error, _} ->
        []
    end
  )

  for file <- @md_files do
    @external_resource Path.join(@articles_dir, file)
  end

  @rendered Loader.load(@articles_dir, @md_files)

  @doc "Every article, newest first."
  def all, do: @rendered

  @doc "One article by slug, or nil."
  def get(slug), do: Enum.find(@rendered, &(&1.slug == slug))

  @doc "Slugs, for the sitemap."
  def slugs, do: Enum.map(@rendered, & &1.slug)
end
