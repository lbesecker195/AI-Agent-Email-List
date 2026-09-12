defmodule EmailProvider.Mail.Params do
  @moduledoc """
  Parse the Mailgun-shaped send parameters into something typed.

  The wire format is form-encoded and prefix-namespaced: `o:` for options,
  `h:` for headers to emit, `v:` for custom variables that ride along with the
  message and come back on its events, `t:` for template arguments. Repeated
  keys (several `to`, several `o:tag`) arrive as lists or as comma-separated
  strings depending on the client, so both are accepted.
  """

  @type t :: %__MODULE__{}

  defstruct from: nil,
            to: [],
            cc: [],
            bcc: [],
            subject: nil,
            text: nil,
            html: nil,
            tags: [],
            headers: %{},
            variables: %{},
            recipient_variables: %{},
            template: nil,
            template_version: nil,
            template_variables: %{},
            test_mode: false,
            delivery_time: nil,
            tracking_opens: nil,
            tracking_clicks: nil

  @doc "Build from the raw params map. Returns `{:ok, params}` or `{:error, reason}`."
  @spec parse(map()) :: {:ok, t()} | {:error, String.t()}
  def parse(raw) when is_map(raw) do
    params = %__MODULE__{
      from: first(raw["from"]),
      to: addresses(raw["to"]),
      cc: addresses(raw["cc"]),
      bcc: addresses(raw["bcc"]),
      subject: first(raw["subject"]),
      text: first(raw["text"]),
      html: first(raw["html"]),
      tags: list(raw["o:tag"]),
      headers: prefixed(raw, "h:"),
      variables: prefixed_json(raw, "v:"),
      recipient_variables: json_map(raw["recipient-variables"]),
      template: first(raw["template"]),
      template_version: first(raw["t:version"]),
      template_variables: json_map(raw["t:variables"]),
      test_mode: yes?(raw["o:testmode"]),
      tracking_opens: tri_state(raw["o:tracking-opens"] || raw["o:tracking"]),
      tracking_clicks: tri_state(raw["o:tracking-clicks"] || raw["o:tracking"])
    }

    with {:ok, params} <- validate_from(params),
         {:ok, params} <- validate_to(params),
         {:ok, params} <- validate_body(params),
         {:ok, params} <- parse_delivery_time(params, raw["o:deliverytime"]) do
      {:ok, params}
    end
  end

  defp validate_from(%{from: nil}), do: {:error, "'from' parameter is missing"}
  defp validate_from(%{from: ""}), do: {:error, "'from' parameter is missing"}

  defp validate_from(%{from: from} = params) do
    if valid_address?(from), do: {:ok, params}, else: {:error, "'from' is not a valid address"}
  end

  defp validate_to(%{to: []}), do: {:error, "'to' parameter is missing"}

  defp validate_to(%{to: to} = params) do
    case Enum.reject(to, &valid_address?/1) do
      [] -> {:ok, params}
      bad -> {:error, "invalid recipient(s): #{Enum.join(bad, ", ")}"}
    end
  end

  # A template supplies the body, so a message with one needs no text or html.
  defp validate_body(%{template: t} = params) when is_binary(t) and t != "", do: {:ok, params}

  defp validate_body(%{text: nil, html: nil}),
    do: {:error, "need at least one of 'text', 'html' or 'template'"}

  defp validate_body(%{text: "", html: nil}),
    do: {:error, "need at least one of 'text', 'html' or 'template'"}

  defp validate_body(params), do: {:ok, params}

  defp parse_delivery_time(params, nil), do: {:ok, params}
  defp parse_delivery_time(params, ""), do: {:ok, params}

  defp parse_delivery_time(params, value) do
    case parse_datetime(first(value)) do
      {:ok, datetime} ->
        max_days = 3
        limit = DateTime.add(DateTime.utc_now(), max_days * 86_400, :second)

        if DateTime.compare(datetime, limit) == :gt do
          {:error, "'o:deliverytime' may be at most #{max_days} days out"}
        else
          {:ok, %{params | delivery_time: datetime}}
        end

      :error ->
        {:error, "'o:deliverytime' must be an RFC 2822 or ISO 8601 timestamp"}
    end
  end

  @doc "Accept RFC 2822 (what Mailgun documents) or ISO 8601 (what people send)."
  def parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      _ -> parse_rfc2822(value)
    end
  end

  def parse_datetime(_), do: :error

  @months %{
    "jan" => 1,
    "feb" => 2,
    "mar" => 3,
    "apr" => 4,
    "may" => 5,
    "jun" => 6,
    "jul" => 7,
    "aug" => 8,
    "sep" => 9,
    "oct" => 10,
    "nov" => 11,
    "dec" => 12
  }

  defp parse_rfc2822(value) do
    regex =
      ~r/^(?:\w{3},\s*)?(\d{1,2})\s+(\w{3})\s+(\d{4})\s+(\d{2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{4}|GMT|UTC)?/i

    case Regex.run(regex, String.trim(value)) do
      nil ->
        :error

      captures ->
        [day, month, year, hour, minute] = Enum.slice(captures, 1, 5)
        second = Enum.at(captures, 6, "") |> blank_to("0")
        offset = Enum.at(captures, 7, "") |> blank_to("+0000")

        with {:ok, month} <- Map.fetch(@months, String.downcase(month)),
             {:ok, naive} <-
               NaiveDateTime.new(
                 String.to_integer(year),
                 month,
                 String.to_integer(day),
                 String.to_integer(hour),
                 String.to_integer(minute),
                 String.to_integer(second)
               ) do
          {:ok,
           naive
           |> DateTime.from_naive!("Etc/UTC")
           |> DateTime.add(-offset_seconds(offset), :second)}
        else
          _ -> :error
        end
    end
  end

  defp blank_to("", default), do: default
  defp blank_to(nil, default), do: default
  defp blank_to(value, _default), do: value

  defp offset_seconds(offset) when offset in ["GMT", "UTC", "gmt", "utc"], do: 0

  defp offset_seconds(<<sign::binary-1, hh::binary-2, mm::binary-2>>) do
    seconds = String.to_integer(hh) * 3600 + String.to_integer(mm) * 60
    if sign == "-", do: -seconds, else: seconds
  end

  defp offset_seconds(_), do: 0

  # -- coercion helpers ----------------------------------------------------

  def first(value) when is_list(value), do: List.first(value)
  def first(value), do: value

  @doc "Split a recipient field that may be a list, or comma-separated, or both."
  def addresses(nil), do: []

  def addresses(value) when is_list(value), do: Enum.flat_map(value, &addresses/1)

  def addresses(value) when is_binary(value) do
    value
    |> split_outside_quotes()
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  def addresses(_), do: []

  # `"Doe, Jane" <jane@example.com>` contains a comma that is not a separator.
  defp split_outside_quotes(value) do
    {parts, current, _in_quotes} =
      value
      |> String.graphemes()
      |> Enum.reduce({[], "", false}, fn
        "\"", {parts, current, in_quotes} -> {parts, current <> "\"", not in_quotes}
        ",", {parts, current, false} -> {parts ++ [current], "", false}
        char, {parts, current, in_quotes} -> {parts, current <> char, in_quotes}
      end)

    parts ++ [current]
  end

  def list(nil), do: []
  def list(value) when is_list(value), do: Enum.map(value, &to_string/1)

  def list(value) when is_binary(value),
    do: String.split(value, ",", trim: true) |> Enum.map(&String.trim/1)

  def list(_), do: []

  def yes?(value) do
    first(value) |> to_string() |> String.downcase() |> Kernel.in(["yes", "true", "1"])
  end

  @doc "`nil` means 'inherit the domain default' — distinct from an explicit no."
  def tri_state(nil), do: nil

  def tri_state(value) do
    case first(value) |> to_string() |> String.downcase() do
      v when v in ["yes", "true", "1"] -> true
      v when v in ["no", "false", "0"] -> false
      "htmlonly" -> true
      _ -> nil
    end
  end

  defp prefixed(raw, prefix) do
    for {key, value} <- raw, String.starts_with?(key, prefix), into: %{} do
      {String.replace_prefix(key, prefix, ""), to_string(first(value))}
    end
  end

  # A `v:` value is documented as JSON but is very often a bare string.
  defp prefixed_json(raw, prefix) do
    for {key, value} <- raw, String.starts_with?(key, prefix), into: %{} do
      name = String.replace_prefix(key, prefix, "")
      raw_value = first(value)

      decoded =
        case Jason.decode(to_string(raw_value)) do
          {:ok, decoded} -> decoded
          {:error, _} -> raw_value
        end

      {name, decoded}
    end
  end

  def json_map(nil), do: %{}

  def json_map(value) do
    case value |> first() |> to_string() |> Jason.decode() do
      {:ok, map} when is_map(map) -> map
      _ -> %{}
    end
  end

  @doc "Loose address check: something, an @, a dotted host. Deliverability is DNS's job."
  def valid_address?(value) when is_binary(value) do
    address = EmailProvider.Suppressions.extract_address(value)

    Regex.match?(
      ~r/^[^\s@<>]+@[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+$/,
      address
    )
  end

  def valid_address?(_), do: false
end
