defmodule EmailProvider.SMTP.Listener do
  @moduledoc """
  Starts and owns the SMTP listeners.

  Two of them, doing different jobs on different ports:

    * **receiving**, port 25 by default, open to the internet and accepting mail
      only for domains we host. No authentication, because the internet cannot
      authenticate to us, and therefore no relaying.

    * **submission**, port 587 by default, where a customer's own software hands
      us mail to send onward. Authentication required, and an authenticated
      session may send anywhere.

  Each listener is a ranch acceptor pool, the same model Cowboy uses: a pool of
  acceptors, one process per connection. `acceptors` sizes the pool and
  `max_connections` caps concurrent sessions.

  ## Why a GenServer rather than ranch child specs

  `:gen_smtp_server.start/3` registers the listener under ranch's own
  supervisor, so the pid it returns is not ours to supervise. Using
  `child_spec/3` instead would put it in our tree, but then a listener that
  cannot bind takes the whole application down with it — and port 25 needs root
  or `CAP_NET_BIND_SERVICE`, so that failure is routine rather than
  exceptional. This process starts each listener, logs the ones that will not
  start, and keeps the rest. A provider that cannot receive today should still
  serve its API and keep sending.
  """

  use GenServer
  require Logger

  alias EmailProvider.SMTP.Server

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Which listeners came up, as `%{receiving: :ok | {:error, reason}}`."
  def status, do: GenServer.call(__MODULE__, :status)

  @impl true
  def init(_opts) do
    Process.flag(:trap_exit, true)

    started =
      [receiving: receiving_config(), submission: submission_config()]
      |> Enum.filter(fn {_name, config} -> Keyword.get(config, :enabled, false) end)
      |> Map.new(fn {name, config} -> {name, start_listener(name, config)} end)

    {:ok, %{listeners: started}}
  end

  @impl true
  def handle_call(:status, _from, state), do: {:reply, state.listeners, state}

  @impl true
  def terminate(_reason, state) do
    Enum.each(state.listeners, fn
      {_name, {:ok, ref}} -> :gen_smtp_server.stop(ref)
      _ -> :ok
    end)
  end

  defp start_listener(name, config) do
    ref = Keyword.fetch!(config, :ref)
    port = Keyword.fetch!(config, :port)

    case :gen_smtp_server.start(ref, Server, options(config)) do
      {:ok, _pid} ->
        Logger.info("SMTP #{name} listening on port #{port} as #{hostname()}")
        {:ok, ref}

      {:error, reason} ->
        Logger.error("SMTP #{name} could not start on port #{port}: #{explain(reason)}")
        {:error, reason}
    end
  catch
    # A bad option makes gen_smtp raise rather than return, and a listener that
    # will not start is not a reason for the application not to.
    kind, reason ->
      Logger.error(
        "SMTP #{name} could not start on port #{Keyword.get(config, :port)}: " <>
          inspect({kind, reason})
      )

      {:error, reason}
  end

  defp options(config) do
    max_connections = Keyword.get(config, :max_connections, 200)

    [
      domain: String.to_charlist(hostname()),
      address: Keyword.get(config, :address, {0, 0, 0, 0}),
      port: Keyword.fetch!(config, :port),
      protocol: :tcp,
      ranch_opts: %{
        num_acceptors: Keyword.get(config, :acceptors, 10),
        max_connections: max_connections
      },
      sessionoptions: [
        callbackoptions: [
          submission: Keyword.get(config, :submission, false),
          max_message_size: Keyword.get(config, :max_message_size, 26_214_400),
          max_sessions: max_connections
        ]
      ]
    ]
  end

  defp explain({:shutdown, {:failed_to_start_child, _, reason}}), do: explain(reason)

  defp explain(:eacces),
    do: "permission denied. Ports below 1024 need root or CAP_NET_BIND_SERVICE."

  defp explain(:eaddrinuse),
    do: "the port is already in use, most likely by another mail server."

  defp explain({:already_started, _pid}), do: "it is already running."

  defp explain(reason), do: inspect(reason)

  @doc "The name this server gives in its banner and its own HELO."
  def hostname do
    Keyword.get(config(), :hostname) || EmailProvider.Domains.mx_host()
  end

  def receiving_config do
    config()
    |> Keyword.get(:receiving, [])
    |> Keyword.put_new(:ref, :email_provider_smtp_in)
    |> Keyword.put_new(:port, 25)
    |> Keyword.put(:submission, false)
  end

  def submission_config do
    config()
    |> Keyword.get(:submission, [])
    |> Keyword.put_new(:ref, :email_provider_smtp_submission)
    |> Keyword.put_new(:port, 587)
    |> Keyword.put(:submission, true)
  end

  defp config, do: Application.get_env(:email_provider, __MODULE__, [])
end
