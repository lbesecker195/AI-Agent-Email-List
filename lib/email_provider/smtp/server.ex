defmodule EmailProvider.SMTP.Server do
  @moduledoc """
  The SMTP server that receives mail for hosted domains.

  Runs on ranch, the same acceptor pool Cowboy uses, so concurrency is a pool
  of acceptors handing each connection to its own process rather than anything
  this module has to arrange.

  ## Not being an open relay

  This is the property that matters most, and it lives in `handle_RCPT/2`.

  An SMTP server that accepts a recipient at a domain it does not host has
  agreed to carry that mail onward for whoever asked. Spammers find such a
  server within hours, and the address it runs on is blacklisted for months
  afterwards. So on port 25 exactly one rule applies: the recipient's domain
  must be one we host and it must be active. Everything else gets 550.

  Submission is the deliberate exception. On the submission port a session that
  has authenticated as a domain's own SMTP user may send anywhere, because it
  has proved it is that customer. Relaying is refused until then, and the
  submission port should never be 25.
  """

  @behaviour :gen_smtp_server_session

  require Logger

  alias EmailProvider.{Domains, Mail}
  alias EmailProvider.Delivery.Inbound

  defmodule State do
    @moduledoc false
    defstruct peer: nil,
              options: [],
              # Set once a session authenticates, and the only thing that
              # permits relaying.
              authenticated_domain: nil,
              submission?: false,
              from: nil,
              recipients: []
  end

  @impl true
  def init(hostname, session_count, peer, options) do
    if session_count > max_sessions(options) do
      Logger.warning("SMTP: refusing connection from #{format_peer(peer)}, too many sessions")
      {:stop, :normal, ["421 ", hostname, " too many connections, try later\r\n"]}
    else
      banner = [hostname, " ESMTP EmailProvider"]
      {:ok, banner, %State{peer: peer, options: options, submission?: submission?(options)}}
    end
  end

  @impl true
  def handle_HELO(_hostname, state), do: {:ok, max_message_size(state.options), state}

  @impl true
  def handle_EHLO(_hostname, extensions, state) do
    # gen_smtp hands these over as {charlist, charlist} pairs, which is a
    # proplist rather than a keyword list.
    extensions =
      extensions
      |> put_extension(~c"SIZE", ~c"#{max_message_size(state.options)}")
      |> then(fn ext ->
        # Only advertise AUTH on the submission port. Offering it on 25 invites
        # credential stuffing against every customer's SMTP password.
        if state.submission?, do: put_extension(ext, ~c"AUTH", ~c"PLAIN LOGIN"), else: ext
      end)

    {:ok, extensions, state}
  end

  defp put_extension(extensions, key, value) do
    List.keystore(extensions, key, 0, {key, value})
  end

  @impl true
  def handle_STARTTLS(state), do: state

  @impl true
  def handle_AUTH(type, username, credential, state) when type in [:login, :plain] do
    with true <- state.submission?,
         %{} = domain <- Domains.get_domain_by_smtp_login(to_string(username)),
         true <- Domains.valid_smtp_password?(domain, password_of(credential)) do
      Logger.info("SMTP: #{format_peer(state.peer)} authenticated as #{domain.name}")
      {:ok, %{state | authenticated_domain: domain}}
    else
      _ ->
        # Deliberately slow and uninformative. This is the one place on the
        # network where a customer's password can be guessed.
        Process.sleep(auth_failure_delay())

        Logger.warning(
          "SMTP: failed auth for #{inspect(username)} from #{format_peer(state.peer)}"
        )

        :error
    end
  end

  def handle_AUTH(_type, _username, _credential, _state), do: :error

  defp password_of({_username, password}), do: to_string(password)
  defp password_of(password), do: to_string(password)

  @impl true
  def handle_MAIL(from, state) do
    {:ok, %{state | from: to_string(from), recipients: []}}
  end

  @impl true
  def handle_MAIL_extension(_extension, state), do: {:ok, state}

  @doc """
  Decide whether we will take responsibility for a recipient.

  Accepted when the recipient is at a domain we host and that domain is active,
  or when the session has authenticated and is therefore submitting rather than
  relaying. Refused otherwise, which is what keeps this from being an open
  relay.
  """
  @impl true
  def handle_RCPT(to, state) do
    address = to |> to_string() |> String.downcase()
    domain = address |> String.split("@") |> List.last()

    cond do
      state.authenticated_domain ->
        {:ok, %{state | recipients: state.recipients ++ [address]}}

      hosted_and_active?(domain) ->
        {:ok, %{state | recipients: state.recipients ++ [address]}}

      hosted?(domain) ->
        {:error, "450 4.7.1 <#{address}>: domain is not verified yet, try later", state}

      true ->
        Logger.info("SMTP: refused relay to #{address} from #{format_peer(state.peer)}")
        {:error, "550 5.7.1 <#{address}>: relay not permitted", state}
    end
  end

  defp hosted?(nil), do: false
  defp hosted?(domain), do: not is_nil(Domains.get_domain_by_name(domain))

  defp hosted_and_active?(nil), do: false

  defp hosted_and_active?(domain) do
    case Domains.get_domain_by_name(domain) do
      nil -> false
      found -> Domains.sendable?(found)
    end
  end

  @impl true
  def handle_RCPT_extension(_extension, state), do: {:ok, state}

  @impl true
  def handle_DATA(_from, _to, data, state) when byte_size(data) == 0 do
    {:error, "552 5.3.4 message is empty", state}
  end

  def handle_DATA(from, to, data, state) do
    if byte_size(data) > max_message_size(state.options) do
      {:error, "552 5.3.4 message exceeds the size limit", state}
    else
      accept(from, to, data, state)
    end
  end

  defp accept(from, to, data, state) do
    parsed = Inbound.parse(data)
    from = to_string(from)
    recipients = Enum.map(to, &String.downcase(to_string(&1)))

    # One stored message per hosted domain in the recipient list. A message to
    # two of our customers is two deliveries, not one shared row.
    results =
      recipients
      |> Enum.group_by(&(&1 |> String.split("@") |> List.last()))
      |> Enum.map(fn {domain_name, addresses} ->
        store(domain_name, addresses, from, parsed, data, state)
      end)

    cond do
      Enum.all?(results, &match?({:ok, _}, &1)) ->
        receipt = results |> Enum.map(fn {:ok, key} -> key end) |> Enum.join(" ")
        {:ok, "250 2.0.0 accepted as #{receipt}", reset(state)}

      Enum.any?(results, &match?({:ok, _}, &1)) ->
        # Some stored, some not. A 4xx would have the sender resend to
        # everybody, duplicating what already landed, so this is a 250 with the
        # failure logged for us rather than for them.
        Logger.error("SMTP: partial acceptance from #{from}: #{inspect(results)}")
        {:ok, "250 2.0.0 accepted", reset(state)}

      true ->
        Logger.error("SMTP: could not store message from #{from}: #{inspect(results)}")
        {:error, "451 4.3.0 could not store the message, try later", reset(state)}
    end
  end

  defp store(domain_name, addresses, from, parsed, raw, state) do
    case Domains.get_domain_by_name(domain_name) do
      nil ->
        # Only reachable on the submission port, where the session has
        # authenticated and is sending outward rather than to us.
        if state.authenticated_domain do
          submit(addresses, from, parsed, raw, state)
        else
          {:error, {:not_hosted, domain_name}}
        end

      domain ->
        {:ok, message} =
          Mail.receive_message(domain, %{
            sender: from,
            recipients: addresses,
            cc: parsed.cc,
            subject: parsed.subject,
            text: parsed.text,
            html: parsed.html,
            message_id: parsed.message_id,
            headers: parsed.headers,
            raw: parsed.raw
          })

        {:ok, message.storage_key}
    end
  rescue
    error ->
      Logger.error("SMTP: storing for #{domain_name} failed: #{Exception.message(error)}")
      {:error, {:exception, domain_name}}
  end

  # Submission: an authenticated customer handing us mail to send onward. It
  # goes through the same pipeline as the REST API, so screening, the
  # suppression list and the warmup ladder all apply exactly as they would to
  # a POST /v3/:domain/messages.
  defp submit(addresses, from, parsed, _raw, state) do
    domain = state.authenticated_domain
    user = EmailProvider.Accounts.get_user(domain.user_id)

    params = %{
      "from" => from,
      "to" => Enum.join(addresses, ","),
      "subject" => parsed.subject,
      "text" => parsed.text,
      "html" => parsed.html
    }

    case Mail.send_message(user, domain, params) do
      {:ok, [message | _]} -> {:ok, message.storage_key}
      {:error, reason, details} -> {:error, {reason, details}}
    end
  end

  defp reset(state), do: %{state | from: nil, recipients: []}

  @impl true
  def handle_RSET(state), do: reset(state)

  @impl true
  def handle_VRFY(_address, state) do
    # VRFY confirms whether an address exists, which is a directory harvest
    # with a friendly name. RFC 5321 explicitly allows refusing it.
    {:error, "252 2.5.2 cannot verify, will attempt delivery", state}
  end

  @impl true
  def handle_other(verb, _args, state), do: {["500 5.5.1 unrecognised command: ", verb], state}

  @impl true
  def handle_info(_info, state), do: {:noreply, state}

  @impl true
  def handle_error(_class, _details, state), do: {:ok, state}

  @impl true
  def terminate(reason, state), do: {:ok, reason, state}

  @impl true
  def code_change(_old, state, _extra), do: {:ok, state}

  # -- options -------------------------------------------------------------

  defp submission?(options), do: Keyword.get(options, :submission, false)
  defp max_message_size(options), do: Keyword.get(options, :max_message_size, 26_214_400)
  defp max_sessions(options), do: Keyword.get(options, :max_sessions, 200)
  defp auth_failure_delay, do: 1_000

  defp format_peer({a, b, c, d}), do: "#{a}.#{b}.#{c}.#{d}"
  defp format_peer(other), do: inspect(other)
end
