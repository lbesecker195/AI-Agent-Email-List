defmodule EmailProviderWeb.ConsoleHTML do
  @moduledoc """
  Every page a person sees.

  HEEx rather than strings, because these templates render addresses, domain
  names and subject lines. All of that came from a customer, and `~H` escapes it
  on the way out; string interpolation would put the burden on whoever edits the
  page next to remember.
  """
  use EmailProviderWeb, :html

  embed_templates "console_html/*"

  @doc """
  The shared chrome.

  The navigation only appears for a signed-in visitor, so the login and signup
  pages are not cluttered with links that would bounce them straight back.
  """
  attr :title, :string, required: true
  attr :current_user, :map, default: nil
  attr :active, :atom, default: nil
  attr :flash, :map, default: %{}
  slot :inner_block, required: true

  def layout(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>{@title} — Agent Email List</title>
        <link rel="stylesheet" href="/console.css" />
      </head>
      <body>
        <div class="topbar">
          <div class="topbar-inner">
            <a class="brand" href="/">Agent Email List</a>
            <nav :if={@current_user}>
              <a href="/domains" aria-current={@active == :domains && "page"}>Domains</a>
              <a href="/send" aria-current={@active == :send && "page"}>Send</a>
              <a href="/messages" aria-current={@active == :messages && "page"}>Messages</a>
              <a href="/account" aria-current={@active == :account && "page"}>Account</a>
            </nav>
            <nav :if={is_nil(@current_user)}>
              <a href="/llms.txt">API</a>
            </nav>
            <form :if={@current_user} action="/logout" method="post">
              <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
              <button class="link" type="submit">Sign out</button>
            </form>
            <a :if={is_nil(@current_user)} href="/login">Sign in</a>
          </div>
        </div>

        <main>
          <p :if={Phoenix.Flash.get(@flash, :error)} class="flash error">
            {Phoenix.Flash.get(@flash, :error)}
          </p>
          <p :if={Phoenix.Flash.get(@flash, :info)} class="flash info">
            {Phoenix.Flash.get(@flash, :info)}
          </p>
          {render_slot(@inner_block)}
        </main>

        <footer>
          A free alternative to Mailgun. Built on
          <a href="https://github.com/lbesecker195/AI-Agent-Email-List">open source</a>, and
          <a href="/llms.txt">documented for agents</a>.
        </footer>
      </body>
    </html>
    """
  end

  @doc "Where a domain has got to, as a checklist rather than a status word."
  attr :domain, :map, required: true

  def progress(assigns) do
    ~H"""
    <ol class="steps">
      <li class="done">Domain added</li>
      <li class={if @domain.spf_verified_at, do: "done"}>
        SPF record published
      </li>
      <li class={if @domain.dkim_verified_at, do: "done"}>
        DKIM record published
      </li>
      <li class={if @domain.state == "active", do: "done"}>
        Verified, and able to send
      </li>
    </ol>
    """
  end
end
