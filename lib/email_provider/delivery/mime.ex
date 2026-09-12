defmodule EmailProvider.Delivery.Mime do
  @moduledoc """
  Render a stored message into RFC 5322 bytes.

  Bodies go out base64 in 76-character lines. Quoted-printable would be more
  readable on the wire, but base64 is unambiguous for any byte sequence, and
  DKIM signs whatever we emit — an encoder that is merely *usually* right would
  produce signatures that are merely usually valid.
  """

  alias EmailProvider.Mail.Message

  @doc "Build the full RFC 5322 message, CRLF line endings throughout."
  @spec render(Message.t() | map(), keyword()) :: String.t()
  def render(message, opts \\ [])

  def render(%{mime_raw: raw}, _opts) when is_binary(raw) and raw != "" do
    normalize_newlines(raw)
  end

  def render(message, opts) do
    {headers, body} = parts(message, opts)

    header_block =
      headers
      |> Enum.map(fn {name, value} -> "#{name}: #{value}" end)
      |> Enum.join("\r\n")

    header_block <> "\r\n\r\n" <> body
  end

  @doc "The header list and body, kept separate so DKIM can sign each in its own way."
  def parts(message, opts \\ []) do
    text = Map.get(message, :body_text)
    html = Map.get(message, :body_html)

    {content_headers, body} = body_for(text, html)

    base = [
      {"From", Map.get(message, :sender)},
      {"To", join_addresses(Map.get(message, :recipients, []))},
      {"Subject", encode_subject(Map.get(message, :subject) || "")},
      {"Date", rfc2822_date(Keyword.get(opts, :date, DateTime.utc_now()))},
      {"Message-ID", Map.get(message, :rfc_message_id) || generate_message_id(message)},
      {"MIME-Version", "1.0"}
    ]

    cc = Map.get(message, :cc, [])
    base = if cc == [], do: base, else: base ++ [{"Cc", join_addresses(cc)}]

    # Bcc is deliberately absent: it is an envelope instruction, not a header.
    # Emitting it would disclose the blind recipients to everyone else.

    custom =
      message
      |> Map.get(:headers, %{})
      |> Enum.reject(fn {name, _v} -> String.downcase(name) in reserved_headers() end)
      |> Enum.map(fn {name, value} -> {name, to_string(value)} end)

    {base ++ content_headers ++ custom, body}
  end

  defp reserved_headers do
    ~w(from to cc bcc subject date message-id mime-version content-type
       content-transfer-encoding dkim-signature)
  end

  defp body_for(text, html)
       when is_binary(text) and is_binary(html) and text != "" and html != "" do
    boundary = "--=_ep_" <> (16 |> :crypto.strong_rand_bytes() |> Base.encode16(case: :lower))

    body =
      [
        "--" <> boundary,
        "Content-Type: text/plain; charset=utf-8",
        "Content-Transfer-Encoding: base64",
        "",
        base64_lines(text),
        "--" <> boundary,
        "Content-Type: text/html; charset=utf-8",
        "Content-Transfer-Encoding: base64",
        "",
        base64_lines(html),
        "--" <> boundary <> "--",
        ""
      ]
      |> Enum.join("\r\n")

    {[{"Content-Type", ~s(multipart/alternative; boundary="#{boundary}")}], body}
  end

  defp body_for(_text, html) when is_binary(html) and html != "" do
    {[
       {"Content-Type", "text/html; charset=utf-8"},
       {"Content-Transfer-Encoding", "base64"}
     ], base64_lines(html) <> "\r\n"}
  end

  defp body_for(text, _html) do
    {[
       {"Content-Type", "text/plain; charset=utf-8"},
       {"Content-Transfer-Encoding", "base64"}
     ], base64_lines(text || "") <> "\r\n"}
  end

  defp base64_lines(content) do
    content
    |> Base.encode64()
    |> wrap(76)
    |> Enum.join("\r\n")
  end

  defp wrap("", _width), do: [""]

  defp wrap(string, width) do
    string
    |> String.to_charlist()
    |> Enum.chunk_every(width)
    |> Enum.map(&to_string/1)
  end

  @doc "Encode a subject per RFC 2047 when it is not plain ASCII."
  def encode_subject(subject) do
    if ascii?(subject) do
      subject
    else
      "=?UTF-8?B?" <> Base.encode64(subject) <> "?="
    end
  end

  defp ascii?(string), do: String.to_charlist(string) |> Enum.all?(&(&1 in 32..126))

  def join_addresses(addresses) when is_list(addresses), do: Enum.join(addresses, ", ")
  def join_addresses(address) when is_binary(address), do: address
  def join_addresses(_), do: ""

  @doc "Generate a Message-ID scoped to the sending domain."
  def generate_message_id(message) do
    host =
      message
      |> Map.get(:sender, "")
      |> to_string()
      |> String.split("@")
      |> List.last()
      |> to_string()
      |> String.trim_trailing(">")

    host = if host == "", do: "localhost", else: host
    local = 16 |> :crypto.strong_rand_bytes() |> Base.encode16(case: :lower)
    "<#{local}@#{host}>"
  end

  @days ~w(Mon Tue Wed Thu Fri Sat Sun)
  @months ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)

  @doc "RFC 2822 date, always in +0000 since we work in UTC."
  def rfc2822_date(%DateTime{} = dt) do
    dow = Enum.at(@days, Date.day_of_week(DateTime.to_date(dt)) - 1)
    mon = Enum.at(@months, dt.month - 1)

    :io_lib.format(~c"~s, ~2..0B ~s ~4..0B ~2..0B:~2..0B:~2..0B +0000", [
      dow,
      dt.day,
      mon,
      dt.year,
      dt.hour,
      dt.minute,
      dt.second
    ])
    |> to_string()
  end

  defp normalize_newlines(raw) do
    raw |> String.replace("\r\n", "\n") |> String.replace("\n", "\r\n")
  end
end
