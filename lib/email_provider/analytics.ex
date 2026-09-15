defmodule EmailProvider.Analytics do
  @moduledoc """
  Usage reporting to SeriouslySimpleAnalytics.

  The question this exists to answer is adoption: which agent software has
  found this server, which tools it reaches for, and whether those calls
  succeed. Nothing here is about individual accounts.

  ## What is deliberately not sent

  Every parameter travels in a URL, and a URL is written into the logs of every
  proxy between here and there. So the things that would be most tempting to
  add are exactly the things that must not go:

    * **No account email addresses.** They belong to our customers, not to us,
      and a query string is the worst place a third party could hold one.
    * **No domain names, senders or recipients.** A customer's domain identifies
      that customer, and the recipient list is the contents of their mail.
    * **No request paths.** This is the subtle one: routes here look like
      `/v3/mail.customer.com/messages`, so the path *is* customer data. The
      controller and action are reported instead, which say the same thing about
      adoption and nothing at all about who.
    * **No API keys**, for the obvious reason.
    * **No location.** The service asks for city, county, state and nation, and
      is right that it cannot work them out from a connection. We cannot either:
      our callers are programs, often running somewhere other than whoever set
      them running. Inventing the fields would poison every report built on
      them, so they are omitted — a gap rather than a lie.

  What does go is the shape of the traffic: an event name, which of our own
  tools was called, whether it worked, how long it took, and the name the
  connecting client gave for itself during the MCP handshake.

  ## Failure

  Fire and forget. The ping runs in a task off the request path with a short
  timeout, is never retried, and never surfaces an error. Analytics that can
  slow down or fail a customer's send is worse than no analytics.

  Off unless `SSA_UID` is set, so a fresh checkout and the test suite report
  nothing.
  """

  @endpoint "https://seriouslysimpleanalytics.com/api/ping"
  @project "agent-email-list"

  # Our callers are machines, and a machine in a retry loop can generate
  # requests far faster than a person. Self-limited so a runaway agent cannot
  # turn into a flood aimed at somebody else's service. Counts are therefore
  # best-effort under load, which is the right trade: the shape of adoption
  # survives dropped pings, and a service knocked over by our telemetry does not.
  @max_pings_per_minute 120

  @doc """
  Report one event.

  `attrs` become query parameters. Values are stringified; nils are dropped.
  Returns `:ok` always — the caller is never given anything to handle.
  """
  def report(event, attrs \\ %{}) do
    case uid() do
      nil ->
        :ok

      uid ->
        if within_own_limit?() do
          send_async(uid, event, attrs)
        end

        :ok
    end
  end

  @doc """
  A stable id for one account, or nil.

  The account's own id, which is what the service means by "use something you
  already have". It turns "22 sessions" into "which callers, coming back", and
  because it is the same value the accounts table is keyed on, a report can be
  joined back to the account it describes — the difference between knowing how
  many agents are using this and knowing which one is hammering it.

  A UUID and nothing else. It is an opaque internal key, not a name or an
  address: it identifies an account to us, and to anyone else it is sixteen
  random bytes. The addresses, domains and mail attached to that account never
  go anywhere near a ping.

  Callers with no account — an agent that has found the server but not signed up
  — get `nil` rather than a fingerprint. They are genuinely unidentified, and
  inventing an identifier for them would be tracking a stranger rather than
  counting a customer.
  """
  def visitor_id(%{id: id}) when is_binary(id), do: id
  def visitor_id(_), do: nil

  @doc """
  A session id for one run.

  Three cases, in order of how well they describe a run:

    * the client sent an MCP session header — its conversation is the run;
    * we know the account — its calls within one half hour are the run, which is
      what stops a burst of API calls counting as a burst of sessions;
    * neither — a random value, so unrelated strangers are not merged into one.
  """
  def session_id(header, user \\ nil)

  def session_id(header, _user) when is_binary(header) and header != "" do
    # Hashed rather than passed through: a client's own session id is its
    # value to shape as it likes, and may well carry something meaningful to
    # it. The hash groups identically without forwarding whatever that was.
    digest("session", header)
  end

  def session_id(_header, %{id: id}) when is_binary(id) do
    # A tumbling half hour, matching the window the service groups by when no
    # sid is sent at all.
    bucket = div(System.system_time(:second), 1_800)
    digest("session", "#{id}:#{bucket}")
  end

  def session_id(_header, _user), do: random_sid()

  def random_sid, do: :crypto.strong_rand_bytes(12) |> Base.url_encode64(padding: false)

  # Keyed with the deployment secret so these identifiers are meaningless
  # outside this deployment and cannot be reversed by whoever holds the reports.
  defp digest(scope, value) do
    key = Application.get_env(:email_provider, EmailProviderWeb.Endpoint)[:secret_key_base] || ""

    :hmac
    |> :crypto.mac(:sha256, key, "#{scope}:#{value}")
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 16)
  end

  @doc "Whether reporting is switched on. Useful in tests and on the dashboard."
  def enabled?, do: uid() != nil

  @doc """
  The account id, or nil.

  Public because the browser tag needs it in the page. It is an account
  identifier, not a secret — it travels in every ping and in the HTML of every
  page — but it still only appears when one is configured, so a self-hosted copy
  reports nothing and renders no tag.
  """
  def account_id, do: uid()

  # -- internals -------------------------------------------------------------

  defp send_async(uid, event, attrs) do
    params =
      attrs
      |> Map.new(fn {k, v} -> {to_string(k), v} end)
      |> Map.reject(fn {_k, v} -> is_nil(v) or v == "" end)
      |> Map.merge(%{
        "uid" => uid,
        "type" => "ai",
        "project" => @project,
        "event" => to_string(event)
      })

    Task.Supervisor.start_child(
      EmailProvider.TaskSupervisor,
      fn -> ping(params) end,
      restart: :temporary
    )
  end

  defp ping(params) do
    opts =
      [
        url: @endpoint,
        params: params,
        method: :get,
        receive_timeout: 2_000,
        connect_options: [timeout: 2_000],
        retry: false
      ]
      |> maybe_stub()

    Req.request(opts)
  rescue
    # Telemetry must not be able to raise into a supervised task and fill the
    # logs with its own failures.
    _ -> :ok
  catch
    _, _ -> :ok
  end

  defp maybe_stub(opts) do
    case Keyword.get(config(), :plug) do
      nil -> opts
      plug -> Keyword.put(opts, :plug, plug)
    end
  end

  defp within_own_limit? do
    case EmailProvider.RateLimit.hit(:analytics_pings, @max_pings_per_minute, 60) do
      :ok -> true
      {:error, _retry_after} -> false
    end
  end

  defp config, do: Application.get_env(:email_provider, __MODULE__, [])

  # An empty env var is unset. This service has been bitten by the opposite
  # reading before, with SMTP_RELAY and OPENAI_API_KEY.
  defp uid do
    case Keyword.get(config(), :uid) do
      value when is_binary(value) and value != "" -> value
      _ -> nil
    end
  end
end
