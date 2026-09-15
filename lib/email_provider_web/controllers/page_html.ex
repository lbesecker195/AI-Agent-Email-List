defmodule EmailProviderWeb.PageHTML do
  @moduledoc """
  The one HTML page this service has.

  Written as a string rather than a template because the application was
  generated with `--no-html` and carries no view layer: adding Phoenix.HTML,
  a layout and a templating engine to render a single static page would be more
  moving parts than the page is worth.
  """

  @doc "The landing page. `base_url` is whatever host the visitor actually reached."
  def index(base_url, contact) do
    """
    <!doctype html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Agent Email List — email sending API</title>
    #{EmailProviderWeb.AnalyticsTag.script_string()}
    <meta name="description" content="Send email from your own domain over a REST API. Mailgun-shaped, with automatic sending warmup and content screening.">
    <style>
      :root {
        color-scheme: light dark;
        --bg: #fbfbfa; --fg: #1a1a18; --muted: #6b6b66;
        --line: #e4e4e0; --accent: #1a5c3a; --code-bg: #f2f2ef;
      }
      @media (prefers-color-scheme: dark) {
        :root {
          --bg: #16161a; --fg: #e8e8e4; --muted: #9a9a94;
          --line: #2c2c32; --accent: #7bc79a; --code-bg: #1e1e24;
        }
      }
      * { box-sizing: border-box; }
      body {
        margin: 0; background: var(--bg); color: var(--fg);
        font: 16px/1.65 ui-sans-serif, -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
        -webkit-font-smoothing: antialiased;
      }
      main { max-width: 43rem; margin: 0 auto; padding: 4rem 1.5rem 6rem; }
      h1 { font-size: 1.6rem; letter-spacing: -0.02em; margin: 0 0 0.4rem; }
      .tag { color: var(--muted); margin: 0 0 2.5rem; font-size: 1.05rem; }
      h2 { font-size: 0.82rem; text-transform: uppercase; letter-spacing: 0.08em;
           color: var(--muted); margin: 2.75rem 0 0.85rem; font-weight: 600; }
      p { margin: 0 0 1rem; }
      a { color: var(--accent); text-decoration-thickness: 1px; text-underline-offset: 2px; }
      pre {
        background: var(--code-bg); border: 1px solid var(--line); border-radius: 6px;
        padding: 0.9rem 1rem; overflow-x: auto; margin: 0 0 1rem;
        font: 13px/1.6 ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
      }
      ul { margin: 0; padding: 0; list-style: none; }
      li { padding: 0.6rem 0; border-top: 1px solid var(--line); }
      li:last-child { border-bottom: 1px solid var(--line); }
      li code { font: 13px ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; }
      li span { color: var(--muted); display: block; font-size: 0.9rem; }
      footer { margin-top: 3.5rem; padding-top: 1.25rem; border-top: 1px solid var(--line);
               color: var(--muted); font-size: 0.9rem; }
    </style>
    </head>
    <body>
    <main>
      <h1>Agent Email List</h1>
      <p class="tag">Send email from your own domain over a REST API. Mailgun-shaped,
      so most Mailgun clients work against it unchanged.</p>

      <h2>Start</h2>
      <p><a href="/signup"><strong>Create an account</strong></a> — then add a domain,
      publish the DNS records it hands back, verify, and send. Free.
      Already have one? <a href="/login">Sign in</a>.</p>
      <p>Or from a terminal, which gets you the same API key:</p>
      <pre><code>curl -X POST #{base_url}/v1/accounts \\
      -d 'email=you@company.com' \\
      -d 'password=a sufficiently long password'</code></pre>

      <h2>Read</h2>
      <ul>
        <li><a href="/free-smtp-relay">Free SMTP Relay: Mailgun and SendGrid alternatives</a>
          <span>Which free SMTP services still have a usable free tier in 2026,
          what changed when SendGrid ended its permanent free plan, and how to
          migrate off Mailgun without rewriting your integration.</span></li>
      </ul>

      <h2>Reference</h2>
      <ul>
        <li><a href="/mcp"><code>/mcp</code></a>
          <span>A Model Context Protocol server. Add it to an agent and the whole
          service arrives as tools. <code>create_account</code> needs no credentials,
          so an agent can open its own account without a human.</span></li>
        <li><a href="/llms.txt"><code>/llms.txt</code></a>
          <span>The full API description, written for AI agents. No key needed.
          Its sending limits are read from the running service, so they are the
          limits you will actually meet.</span></li>
        <li><a href="/health"><code>/health</code></a>
          <span>Liveness check.</span></li>
        <li><a href="https://github.com/lbesecker195/AI-Agent-Email-List">Source</a>
          <span>Elixir and Phoenix. DKIM signing, automatic sending warmup and
          content screening in both directions.</span></li>
      </ul>

      <h2>Two things worth knowing before you build</h2>
      <p>A domain has to be verified in DNS before it can send, which needs
      someone with registrar access. And a newly verified domain starts at a low
      daily cap and climbs as it proves itself, because a domain that opens at
      volume gets filtered. Both are explained in
      <a href="/llms.txt"><code>/llms.txt</code></a>.</p>

      <footer>
        Maintained by Logan Besecker &middot;
        <a href="mailto:#{contact}">#{contact}</a>
      </footer>
    </main>
    </body>
    </html>
    """
  end
end
