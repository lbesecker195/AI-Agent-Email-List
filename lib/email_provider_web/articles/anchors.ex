defmodule EmailProviderWeb.Articles.Anchors do
  @moduledoc """
  Give every `<h2>` an id, and collect them into a contents list.

  Two reasons, and neither is decoration. A reader who wants one answer out of
  twelve thousand words needs to jump to it, and someone answering a question in
  a thread needs to link to that answer rather than to the whole page.

  Runs at compile time on our own rendered output.
  """

  @doc """
  Returns `{html_with_ids, sections}` where each section is `%{id:, text:}`.
  """
  def apply(html) do
    Regex.scan(~r{<h2>(.*?)</h2>}s, html)
    |> Enum.map_reduce(%{}, fn [whole, inner], seen ->
      text = strip_tags(inner)
      {id, seen} = unique_id(slugify(text), seen)

      replacement =
        ~s(<h2 id="#{id}"><a class="anchor" href="##{id}" aria-label="Link to this section">#) <>
          ~s(</a>#{inner}</h2>)

      {{whole, replacement, %{id: id, text: text}}, seen}
    end)
    |> then(fn {replacements, _seen} ->
      html =
        Enum.reduce(replacements, html, fn {whole, replacement, _section}, acc ->
          String.replace(acc, whole, replacement, global: false)
        end)

      {html, Enum.map(replacements, fn {_w, _r, section} -> section end)}
    end)
  end

  defp strip_tags(html), do: html |> String.replace(~r/<[^>]+>/, "") |> String.trim()

  defp slugify(text) do
    text
    |> String.downcase()
    # Curly quotes and dashes come from the smart-punctuation pass and would
    # otherwise each become their own hyphen.
    |> String.replace(~r/[\x{2018}\x{2019}\x{201C}\x{201D}\x{2013}\x{2014}]/u, "")
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
    |> String.slice(0, 60)
    |> String.trim("-")
  end

  # Two sections can share a heading. An id that appears twice makes the second
  # link unreachable, so the duplicate gets a suffix.
  defp unique_id(base, seen) do
    base = if base == "", do: "section", else: base

    case Map.get(seen, base) do
      nil -> {base, Map.put(seen, base, 1)}
      n -> {"#{base}-#{n + 1}", Map.put(seen, base, n + 1)}
    end
  end
end
