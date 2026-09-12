defmodule EmailProvider.Delivery.Sender do
  @moduledoc """
  Hands a signed message to the outside world.

  Two adapters. `:smtp` relays through a configured smarthost. `:local` writes
  the rendered message to disk and logs it, which is what dev and test use — a
  test suite that can accidentally mail a real person is a test suite nobody
  runs twice.

  The adapter is chosen by config, never by the caller, so there is no code
  path where a request can talk its way onto the wire in test.
  """

  require Logger

  @type result :: {:ok, map()} | {:error, term()}

  @callback deliver(raw :: String.t(), from :: String.t(), to :: [String.t()]) :: result()

  @spec deliver(String.t(), String.t(), [String.t()]) :: result()
  def deliver(raw, from, to) when is_binary(raw) and is_binary(from) and is_list(to) do
    adapter().deliver(raw, from, to)
  end

  def adapter do
    case Application.get_env(:email_provider, __MODULE__, [])[:adapter] do
      :smtp -> __MODULE__.SMTP
      :local -> __MODULE__.Local
      module when is_atom(module) and not is_nil(module) -> module
      _ -> __MODULE__.Local
    end
  end

  def config, do: Application.get_env(:email_provider, __MODULE__, [])

  defmodule SMTP do
    @moduledoc "Relay through a smarthost with gen_smtp."
    @behaviour EmailProvider.Delivery.Sender

    require Logger

    @impl true
    def deliver(raw, from, to) do
      opts = EmailProvider.Delivery.Sender.config()

      smtp_opts =
        [
          relay: Keyword.fetch!(opts, :relay),
          port: Keyword.get(opts, :port, 587),
          # `:always` rather than `:if_available`: a smarthost that silently
          # stops offering STARTTLS should fail the send, not downgrade it.
          tls: Keyword.get(opts, :tls, :always),
          tls_options: [
            verify: :verify_peer,
            cacerts: :public_key.cacerts_get(),
            depth: 3,
            server_name_indication: String.to_charlist(Keyword.fetch!(opts, :relay)),
            customize_hostname_check: [
              match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
            ]
          ],
          retries: Keyword.get(opts, :retries, 1)
        ]
        |> maybe_auth(opts)

      envelope = {String.to_charlist(from), Enum.map(to, &String.to_charlist/1), raw}

      case :gen_smtp_client.send_blocking(envelope, smtp_opts) do
        receipt when is_binary(receipt) ->
          {:ok, %{receipt: String.trim(to_string(receipt))}}

        {:error, type, message} ->
          {:error, {type, inspect(message)}}

        {:error, reason} ->
          {:error, reason}
      end
    catch
      kind, reason ->
        Logger.error("smtp delivery crashed: #{inspect(kind)} #{inspect(reason)}")
        {:error, {kind, reason}}
    end

    defp maybe_auth(smtp_opts, opts) do
      case {Keyword.get(opts, :username), Keyword.get(opts, :password)} do
        {nil, _} ->
          smtp_opts

        {_, nil} ->
          smtp_opts

        {user, pass} ->
          Keyword.merge(smtp_opts,
            auth: :always,
            username: String.to_charlist(user),
            password: String.to_charlist(pass)
          )
      end
    end
  end

  defmodule Local do
    @moduledoc """
    Writes each message to `priv/local_mail` and logs a one-line summary.
    Nothing leaves the machine.
    """
    @behaviour EmailProvider.Delivery.Sender

    require Logger

    @impl true
    def deliver(raw, from, to) do
      dir = Keyword.get(EmailProvider.Delivery.Sender.config(), :dir, "priv/local_mail")
      File.mkdir_p!(dir)

      name = "#{System.system_time(:millisecond)}-#{:rand.uniform(100_000)}.eml"
      path = Path.join(dir, name)
      File.write!(path, raw)

      Logger.info("local delivery: #{from} -> #{Enum.join(to, ", ")} (#{path})")
      {:ok, %{receipt: "local:#{name}", path: path}}
    end
  end
end
