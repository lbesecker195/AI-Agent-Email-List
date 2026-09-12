defmodule EmailProvider.Delivery.Dkim do
  @moduledoc """
  DKIM signing, RSA-SHA256, relaxed/relaxed canonicalization (RFC 6376).

  Relaxed canonicalization on both halves is what makes the signature survive
  the ordinary indignities of transit: a relay that re-wraps a folded header or
  changes trailing whitespace will not break it, where simple canonicalization
  would.

  The signature covers a fixed header set. Signing a header a message does not
  have would produce a signature no verifier can check, so absent headers are
  dropped from `h=` rather than signed as empty.
  """

  alias EmailProvider.Domains.Domain

  @signed_headers ~w(from to cc subject date message-id mime-version
                     content-type content-transfer-encoding)

  @doc """
  Sign a rendered message, returning it with a `DKIM-Signature` header prepended.
  """
  @spec sign(String.t(), Domain.t(), keyword()) :: String.t()
  def sign(raw_message, %Domain{} = domain, opts \\ []) do
    {header_block, body} = split(raw_message)
    headers = parse_headers(header_block)

    present =
      Enum.filter(@signed_headers, fn name ->
        Enum.any?(headers, fn {n, _v} -> String.downcase(n) == name end)
      end)

    body_hash =
      body
      |> canonicalize_body()
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode64()

    timestamp = Keyword.get(opts, :timestamp, System.system_time(:second))

    # Built without b=, signed, then the same header is re-emitted with the
    # signature filled in. The value of b= is excluded from its own input.
    unsigned =
      dkim_header_value(domain, present, body_hash, timestamp) <> "b="

    signing_input =
      (present
       |> Enum.map(&canonical_header(&1, headers))
       |> Enum.join()) <>
        canonicalize_header_line("dkim-signature", unsigned)

    signature =
      signing_input
      |> :public_key.sign(:sha256, EmailProvider.Domains.private_key(domain))
      |> Base.encode64()

    "DKIM-Signature: " <> unsigned <> signature <> "\r\n" <> raw_message
  end

  defp dkim_header_value(domain, present, body_hash, timestamp) do
    "v=1; a=rsa-sha256; c=relaxed/relaxed; d=#{domain.name}; " <>
      "s=#{domain.dkim_selector}; t=#{timestamp}; " <>
      "h=#{Enum.join(present, ":")}; bh=#{body_hash}; "
  end

  @doc "Split a raw message into its header block and body at the first blank line."
  def split(raw) do
    case String.split(raw, "\r\n\r\n", parts: 2) do
      [headers, body] -> {headers, body}
      [headers] -> {headers, ""}
    end
  end

  @doc """
  Parse a header block into `{name, value}`, unfolding continuation lines.
  """
  def parse_headers(block) do
    block
    |> String.split("\r\n")
    |> Enum.reduce([], fn line, acc ->
      cond do
        # A line starting with whitespace continues the previous header.
        String.match?(line, ~r/^[ \t]/) and acc != [] ->
          [{name, value} | rest] = acc
          [{name, value <> " " <> String.trim(line)} | rest]

        String.contains?(line, ":") ->
          [name, value] = String.split(line, ":", parts: 2)
          # Whitespace on either side of the colon is not part of either the
          # name or the value; "B : Y" and "B:Y" are the same header.
          [{String.trim(name), String.trim(value)} | acc]

        true ->
          acc
      end
    end)
    |> Enum.reverse()
  end

  # Take the *last* occurrence, which is what RFC 6376 specifies when a header
  # appears more than once.
  defp canonical_header(name, headers) do
    headers
    |> Enum.filter(fn {n, _v} -> String.downcase(n) == name end)
    |> List.last()
    |> case do
      nil -> ""
      {_n, value} -> canonicalize_header_line(name, value) <> "\r\n"
    end
  end

  defp canonicalize_header_line(name, value) do
    collapsed =
      value
      |> String.replace(~r/\r\n/, "")
      |> String.replace(~r/[ \t]+/, " ")
      |> String.trim_trailing()

    String.downcase(name) <> ":" <> collapsed
  end

  @doc """
  Relaxed body canonicalization: collapse intra-line whitespace, drop trailing
  whitespace, drop trailing empty lines, and end with exactly one CRLF.
  """
  def canonicalize_body(body) do
    lines =
      body
      |> String.replace("\r\n", "\n")
      |> String.split("\n")
      |> Enum.map(fn line ->
        line |> String.replace(~r/[ \t]+/, " ") |> String.trim_trailing()
      end)
      |> Enum.reverse()
      |> Enum.drop_while(&(&1 == ""))
      |> Enum.reverse()

    case lines do
      [] -> ""
      _ -> Enum.join(lines, "\r\n") <> "\r\n"
    end
  end
end
