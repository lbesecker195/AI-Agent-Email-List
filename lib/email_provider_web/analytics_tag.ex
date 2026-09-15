defmodule EmailProviderWeb.AnalyticsTag do
  @moduledoc """
  The browser half of usage reporting.

  The server side counts what agents do against the API. This counts what people
  do on the pages — the landing page, the articles, the console — so both halves
  land in the same dashboard.

  Rendered from one place rather than pasted into each layout, because the page
  somebody adds next month is otherwise the one that is missing it. It renders
  nothing at all when no account id is configured, so a self-hosted copy of this
  service ships no tracker.
  """

  use Phoenix.Component

  alias EmailProvider.Analytics

  @src "https://seriouslysimpleanalytics.com/wa.js"

  @doc "The tag as a HEEx component, for the templates that are HEEx."
  def script(assigns) do
    assigns =
      assigns
      |> assign(:uid, Analytics.account_id())
      |> assign(:src, @src)

    ~H"""
    <script :if={@uid} src={@src} data-site={@uid} defer></script>
    """
  end

  @doc "The tag as a string, for the landing page, which is built as one."
  def script_string do
    case Analytics.account_id() do
      nil -> ""
      uid -> ~s(<script src="#{@src}" data-site="#{uid}" defer></script>)
    end
  end
end
