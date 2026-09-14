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

  The sign-up and domain dashboard. Static: it drives the same public JSON API
  from the browser, so there is no second implementation of signup or domain
  handling on the server to keep in step with the first.
  """
  def app(conn, _params) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, EmailProviderWeb.AppHTML.app())
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
