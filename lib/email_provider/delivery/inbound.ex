defmodule EmailProvider.Delivery.Inbound do
  @moduledoc """
  Parse a raw RFC 5322 document into the fields the rest of the system uses.

  Built on `:mimemail` from gen_smtp, which handles the parts that are tedious
  to get right: transfer encodings, nested multiparts, and RFC 2047 encoded
  words in headers.

  Parsing is wrapped: a malformed message is a normal event on an inbound
  stream, not an exception. When the parse fails we keep the raw bytes and
  recover what we can with a plain header scan, so a broken message is still
  visible to the recipient instead of vanishing.
  """

  require Logger

  @type parsed :: %{
          from: String.t() | nil,
          to: [String.t()],
          cc: [String.t()],
          subject: String.t() | nil,
          text: String.t() | nil,
          html: String.t() | nil,
          message_id: String.t() | nil,
          headers: map(),
          raw: String.t()
        }

  @spec parse(String.t()) :: parsed()
  def parse(raw) when is_binary(raw) do
    normalized = normalize(raw)

    # Headers are read from the raw block rather than from mimemail, which
    # replaces every non-ASCII byte in a header with "?". That is defensible by
    # RFC 5322 — headers are supposed to be ASCII with anything else in an
    # encoded word — but plenty of real senders put raw UTF-8 in a Subject, and
    # turning "Hola señor" into "Hola se??or" loses data we were handed intact.
    header_map = raw_header_map(normalized)

    try do
      {type, subtype, _headers, _params, body} = :mimemail.decode(normalized)

      %{
        from: header_map["from"],
        to: addresses(header_map["to"]),
        cc: addresses(header_map["cc"]),
        subject: header_map["subject"],
        text: extract(type, subtype, body, "plain"),
        html: extract(type, subtype, body, "html"),
        message_id: header_map["message-id"],
        headers: header_map,
        raw: normalized
      }
    catch
      kind, reason ->
        Logger.warning("MIME parse failed (#{inspect(kind)}): #{inspect(reason)}; falling back")
        fallback(normalized)
    end
  end

  defp normalize(raw) do
    raw |> String.replace("\r\n", "\n") |> String.replace("\n", "\r\n")
  end

  defp raw_header_map(raw) do
    {header_block, _body} =
      case String.split(raw, "\r\n\r\n", parts: 2) do
        [headers, body] -> {headers, body}
        [headers] -> {headers, ""}
      end

    header_block
    |> EmailProvider.Delivery.Dkim.parse_headers()
    |> Map.new(fn {name, value} -> {String.downcase(name), decode_header(value)} end)
  end

  @doc """
  Decode an RFC 2047 header value.

  `=?UTF-8?B?...?=` and `=?ISO-8859-1?Q?...?=` become plain text. Whitespace
  between two adjacent encoded words is dropped, as the RFC requires, so a long
  subject split across several words reassembles without gaps appearing inside
  its own characters. Anything that is not an encoded word is passed through
  unchanged.
  """
  @spec decode_header(String.t()) :: String.t()
  def decode_header(value) when is_binary(value) do
    ~r/=\?([A-Za-z0-9_\-]+)\?([BbQq])\?([^?]*)\?=(\s+)?/
    |> Regex.replace(value, fn _whole, charset, encoding, text, trailing ->
      case decode_word(charset, encoding, text) do
        {:ok, decoded} -> decoded <> keep_gap(trailing, value, text)
        :error -> "=?" <> charset <> "?" <> encoding <> "?" <> text <> "?=" <> to_string(trailing)
      end
    end)
  end

  def decode_header(value), do: value

  # Whitespace that separates two encoded words is not part of the text; any
  # other trailing whitespace is.
  defp keep_gap(nil, _value, _text), do: ""
  defp keep_gap("", _value, _text), do: ""

  defp keep_gap(trailing, value, text) do
    case Regex.run(~r/\?=(\s+)=\?/, value) do
      nil -> trailing
      _ -> if followed_by_encoded_word?(value, text), do: "", else: trailing
    end
  end

  defp followed_by_encoded_word?(value, text) do
    case String.split(value, text <> "?=", parts: 2) do
      [_before, rest] -> Regex.match?(~r/^\s*=\?/, rest)
      _ -> false
    end
  end

  defp decode_word(charset, encoding, text) do
    with {:ok, bytes} <- decode_payload(encoding, text),
         {:ok, converted} <- to_utf8(charset, bytes) do
      {:ok, converted}
    end
  end

  defp decode_payload(enc, text) when enc in ["B", "b"] do
    case Base.decode64(text, padding: false) do
      {:ok, bytes} -> {:ok, bytes}
      :error -> Base.decode64(text)
    end
  end

  defp decode_payload(enc, text) when enc in ["Q", "q"] do
    decoded =
      text
      |> String.replace("_", " ")
      |> then(fn s ->
        Regex.replace(~r/=([0-9A-Fa-f]{2})/, s, fn _w, hex ->
          <<String.to_integer(hex, 16)>>
        end)
      end)

    {:ok, decoded}
  end

  defp to_utf8(charset, bytes) do
    normalized = String.downcase(charset)

    if normalized in ["utf-8", "utf8", "us-ascii", "ascii"] do
      {:ok, bytes}
    else
      try do
        {:ok, :iconv.convert(charset, "utf-8//IGNORE", bytes)}
      catch
        _kind, _reason -> {:ok, filter_ascii(bytes)}
      end
    end
  end

  defp filter_ascii(bytes), do: for(<<b <- bytes>>, b < 128, into: "", do: <<b>>)

  # Walk the tree for the first part of the wanted subtype.
  defp extract("text", subtype, body, want) when is_binary(body) do
    if subtype == want, do: to_string(body), else: nil
  end

  defp extract("multipart", _subtype, parts, want) when is_list(parts) do
    Enum.find_value(parts, fn {type, subtype, _headers, _params, body} ->
      extract(to_string(type), to_string(subtype), body, want)
    end)
  end

  defp extract(_type, _subtype, _body, _want), do: nil

  # Last resort: split headers from body and read the few fields we need.
  defp fallback(raw) do
    {header_block, body} =
      case String.split(raw, "\r\n\r\n", parts: 2) do
        [headers, body] -> {headers, body}
        [headers] -> {headers, ""}
      end

    header_map =
      header_block
      |> EmailProvider.Delivery.Dkim.parse_headers()
      |> Map.new(fn {name, value} -> {String.downcase(name), decode_header(value)} end)

    %{
      from: header_map["from"],
      to: addresses(header_map["to"]),
      cc: addresses(header_map["cc"]),
      subject: header_map["subject"],
      text: body,
      html: nil,
      message_id: header_map["message-id"],
      headers: header_map,
      raw: raw
    }
  end

  defp addresses(nil), do: []
  defp addresses(value), do: EmailProvider.Mail.Params.addresses(value)
end
