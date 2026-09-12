defmodule EmailProvider.Delivery.Sender.DirectMX do
  @moduledoc """
  Deliver straight to the recipient's mail servers, with no smarthost.

  This is what makes the service a mail provider rather than a client of one.
  Recipients are grouped by domain, each domain's MX records are looked up and
  tried in preference order, and the message is handed over in one SMTP
  conversation per domain.

  ## TLS here is deliberately weaker than to a smarthost

  `Sender.SMTP` talks to a smarthost you chose, so it demands STARTTLS and
  verifies the certificate: a smarthost that stops offering TLS should fail the
  send rather than quietly downgrade.

  This module talks to the whole internet, where that policy would mean not
  delivering mail. A large share of receiving MTAs present self-signed or
  hostname-mismatched certificates, and there is no prior agreement to check
  them against. So TLS is opportunistic and unverified, which is what every
  other MTA does and what RFC 7435 calls opportunistic security: encrypted
  against a passive observer, not proof against an active one. Turning
  verification on here would not make delivery safer, it would make it fail.

  ## Retries and multiple recipients

  A message to several domains is several conversations, and a failure in one
  fails the message. The queue then retries the whole message, which re-sends
  to the domains that already accepted it. For precise retry semantics send one
  recipient per message, which is what `recipient-variables` already produces.
  """

  @behaviour EmailProvider.Delivery.Sender

  require Logger

  alias EmailProvider.Delivery.Sender

  @dns_timeout 5_000

  @impl true
  def deliver(raw, from, to) do
    to
    |> Enum.group_by(&domain_of/1)
    |> Enum.reduce({:ok, %{receipts: [], delivered: []}}, fn {domain, recipients}, acc ->
      case {acc, deliver_to_domain(raw, from, domain, recipients)} do
        {{:ok, info}, {:ok, receipt}} ->
          {:ok,
           %{
             info
             | receipts: info.receipts ++ [receipt],
               delivered: info.delivered ++ recipients
           }}

        {{:ok, _info}, {:error, reason}} ->
          {:error, "delivery to #{domain} failed: #{reason}"}

        # Already failed: keep the first reason, it is the one with context.
        {{:error, _} = failure, _} ->
          failure
      end
    end)
    |> case do
      {:ok, info} -> {:ok, Map.put(info, :receipt, Enum.join(info.receipts, "; "))}
      error -> error
    end
  end

  defp deliver_to_domain(raw, from, domain, recipients) do
    case mail_exchangers(domain) do
      [] ->
        # No MX and no A record is a permanent condition, so say so with a 5xx
        # the queue will recognise rather than retrying for days.
        {:error, "550 no MX or A record for #{domain}"}

      hosts ->
        try_hosts(hosts, raw, from, recipients, domain, nil)
    end
  end

  # Walk the MX list in preference order. A 5xx is the destination's final
  # answer and ends the attempt; anything else is worth trying the next host
  # for, because it is usually this one being unreachable rather than the mail
  # being unwanted.
  defp try_hosts([], _raw, _from, _recipients, domain, last_error) do
    {:error, last_error || "451 no reachable mail server for #{domain}"}
  end

  defp try_hosts([host | rest], raw, from, recipients, domain, _last_error) do
    case send_via(host, raw, from, recipients) do
      {:ok, receipt} ->
        {:ok, receipt}

      {:error, reason} ->
        if permanent?(reason) do
          {:error, reason}
        else
          Logger.info("#{domain}: #{host} did not accept (#{reason}), trying next")
          try_hosts(rest, raw, from, recipients, domain, reason)
        end
    end
  end

  defp send_via(host, raw, from, recipients) do
    envelope = {
      String.to_charlist(from),
      Enum.map(recipients, &String.to_charlist/1),
      raw
    }

    opts = [
      relay: host,
      port: port(),
      hostname: String.to_charlist(helo_name()),
      # Opportunistic and unverified: see the moduledoc.
      tls: :if_available,
      tls_options: [verify: :verify_none],
      retries: 0,
      timeout: timeout()
    ]

    case :gen_smtp_client.send_blocking(envelope, opts) do
      receipt when is_binary(receipt) -> {:ok, String.trim(to_string(receipt))}
      {:error, type, message} -> {:error, "#{type}: #{inspect(message)}"}
      {:error, reason} -> {:error, inspect(reason)}
    end
  catch
    kind, reason ->
      {:error, "#{inspect(kind)}: #{inspect(reason)}"}
  end

  defp permanent?(reason), do: Regex.match?(~r/\b5\d\d\b/, to_string(reason))

  @doc """
  The mail servers for a domain, most preferred first.

  Falls back to the domain's own address records when it publishes no MX, which
  RFC 5321 requires: a domain with an A record and no MX accepts mail at that
  address.
  """
  def mail_exchangers(domain) when is_binary(domain) do
    case resolver() do
      nil -> resolve(domain)
      fun when is_function(fun, 1) -> fun.(domain)
    end
  end

  # Tests point this at a function instead of DNS, so the delivery path under
  # test is the real one rather than a mock of it.
  defp resolver, do: Keyword.get(config(), :mx_resolver)

  defp resolve(domain) do
    case mx_lookup(domain) do
      [] -> if has_address?(domain), do: [domain], else: []
      records -> records |> Enum.sort_by(&elem(&1, 0)) |> Enum.map(&elem(&1, 1))
    end
  end

  defp mx_lookup(domain) do
    case :inet_res.lookup(String.to_charlist(domain), :in, :mx, timeout: @dns_timeout) do
      records when is_list(records) ->
        Enum.map(records, fn {preference, host} -> {preference, to_string(host)} end)

      _ ->
        []
    end
  catch
    _kind, _reason -> []
  end

  defp has_address?(domain) do
    charlist = String.to_charlist(domain)

    :inet_res.lookup(charlist, :in, :a, timeout: @dns_timeout) != [] or
      :inet_res.lookup(charlist, :in, :aaaa, timeout: @dns_timeout) != []
  catch
    _kind, _reason -> false
  end

  defp domain_of(address) do
    address |> to_string() |> String.split("@") |> List.last() |> String.downcase()
  end

  defp config, do: Sender.config()

  @doc """
  The name given in HELO.

  Receiving servers check that this resolves and often that it matches the
  connecting address, so it has to be a real host, not the machine's local
  hostname.
  """
  def helo_name do
    Keyword.get(config(), :helo_name) || EmailProvider.Domains.mx_host()
  end

  defp port, do: Keyword.get(config(), :direct_port, 25)
  defp timeout, do: Keyword.get(config(), :timeout, 30_000)
end
