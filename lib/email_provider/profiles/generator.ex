defmodule EmailProvider.Profiles.Generator do
  @moduledoc """
  Turns a profile's inputs into its description.

  Two adapters. `OpenAI` writes the paragraph with a model. `Structured` builds
  it from the facts directly, with no model and no network, and is what runs
  when no key is configured — so the feature works out of the box and the test
  suite exercises the real path rather than a mock.

  The adapter is chosen by config, never by the caller.
  """

  @type inputs :: %{
          account: map(),
          enrichment: map() | nil,
          signals: map()
        }

  @callback describe(inputs(), pos_integer()) :: {:ok, String.t()} | {:error, term()}

  @doc "Write the description, returning `{:ok, text, adapter_name}`."
  @spec describe(inputs(), pos_integer()) :: {:ok, String.t(), String.t()} | {:error, term()}
  def describe(inputs, target_words \\ 200) do
    adapter = adapter()

    case adapter.describe(inputs, target_words) do
      {:ok, text} -> {:ok, trim_to_words(text, target_words), name_of(adapter)}
      {:error, reason} -> {:error, reason}
    end
  end

  def adapter do
    case Application.get_env(:email_provider, __MODULE__, [])[:adapter] do
      :openai -> __MODULE__.OpenAI
      :structured -> __MODULE__.Structured
      module when is_atom(module) and not is_nil(module) -> module
      # No explicit choice: use the model only if there is a key to use it with.
      _ -> if openai_key(), do: __MODULE__.OpenAI, else: __MODULE__.Structured
    end
  end

  def config, do: Application.get_env(:email_provider, __MODULE__, [])

  def openai_key do
    config()[:api_key] ||
      Application.get_env(:email_provider, EmailProvider.Moderation, [])[:api_key]
  end

  defp name_of(__MODULE__.OpenAI), do: "openai"
  defp name_of(__MODULE__.Structured), do: "structured"
  defp name_of(module), do: inspect(module)

  @doc """
  Cut a description to at most `max` words.

  Trims at a sentence boundary when there is one in the last fifth of the text,
  so a description ends on a full stop rather than mid-clause.
  """
  def trim_to_words(text, max) do
    words = String.split(text, ~r/\s+/, trim: true)

    if length(words) <= max do
      String.trim(text)
    else
      cut = words |> Enum.take(max) |> Enum.join(" ")

      case Regex.run(~r/^(.*[.!?])\s/s, cut <> " ") do
        [_, upto] -> if word_count(upto) >= max * 0.8, do: upto, else: cut
        nil -> cut
      end
    end
  end

  def word_count(nil), do: 0
  def word_count(text), do: text |> String.split(~r/\s+/, trim: true) |> length()

  defmodule OpenAI do
    @moduledoc "Writes the description with a chat model."
    @behaviour EmailProvider.Profiles.Generator

    require Logger

    alias EmailProvider.Profiles.Generator

    @impl true
    def describe(inputs, target_words) do
      key = Generator.openai_key()

      if is_nil(key) do
        {:error, :no_api_key}
      else
        request(inputs, target_words, key)
      end
    end

    defp request(inputs, target_words, key) do
      opts =
        [
          method: :post,
          url: base_url() <> "/v1/chat/completions",
          headers: [{"authorization", "Bearer " <> key}],
          json: %{
            model: model(),
            temperature: 0.2,
            max_tokens: round(target_words * 2),
            messages: [
              %{role: "system", content: system_prompt(target_words)},
              %{role: "user", content: Jason.encode!(inputs)}
            ]
          },
          receive_timeout: timeout(),
          retry: :transient,
          max_retries: 2
        ]
        |> maybe_stub()

      case Req.request(opts) do
        {:ok,
         %Req.Response{
           status: s,
           body: %{"choices" => [%{"message" => %{"content" => text}} | _]}
         }}
        when s in 200..299 ->
          {:ok, String.trim(text)}

        {:ok, %Req.Response{status: s, body: body}} when s in 200..299 ->
          {:error, {:unexpected_body, body}}

        {:ok, %Req.Response{status: status, body: body}} ->
          Logger.warning("profile generation returned #{status}: #{inspect(body)}")
          {:error, {:http, status}}

        {:error, reason} ->
          {:error, {:transport, reason}}
      end
    end

    defp maybe_stub(opts) do
      case Generator.config()[:plug] do
        nil -> opts
        plug -> Keyword.merge(opts, plug: plug, retry: false)
      end
    end

    # The instruction to stay on the evidence is not politeness. A description
    # that invents a job title reads exactly like one that knows a job title,
    # and whoever relies on it downstream cannot tell the difference.
    defp system_prompt(target_words) do
      """
      You write concise profiles of a customer of an email service, for that
      service's own records.

      You are given three things: the account's own details, an enrichment
      record from a business contact database, and a digest of the account's
      mail activity (who they correspond with, subject lines, volume, cadence).

      Write a single dense paragraph of about #{target_words} words. Requirements:

      - Use only what is in the input. Do not invent employers, titles,
        seniority, locations or relationships. If the enrichment record is
        absent or empty, describe what the mail activity alone supports.
      - Attribute uncertain material: "appears to", "the enrichment record
        gives", "subject lines suggest".
      - Prefer specifics over adjectives. Counts, domains, roles, cadence and
        named organisations are useful; "dynamic professional" is not.
      - Do not infer or comment on race, religion, health, sexuality, political
        affiliation, or any other protected characteristic, even where the
        input hints at one.
      - Output the paragraph only. No heading, no preamble, no bullet points.
      """
    end

    defp cfg, do: EmailProvider.Profiles.Generator.config()
    defp base_url, do: Keyword.get(cfg(), :base_url, "https://api.openai.com")
    defp model, do: Keyword.get(cfg(), :model, "gpt-4o-mini")
    defp timeout, do: Keyword.get(cfg(), :timeout, 30_000)
  end

  defmodule Structured do
    @moduledoc """
    Builds the description from the facts, with no model involved.

    It says what the data supports and stops. Where the model adapter would pad
    a thin record out to a full paragraph, this one returns a short description
    and an honest word count, because filler in a profile is worse than a gap.
    """
    @behaviour EmailProvider.Profiles.Generator

    @impl true
    def describe(%{account: account, enrichment: enrichment, signals: signals}, _target_words) do
      sentences =
        [
          identity(account, enrichment),
          role(enrichment),
          location(enrichment),
          volume(signals),
          cadence(signals),
          correspondents(signals),
          themes(signals),
          domains(signals)
        ]
        |> Enum.reject(&is_nil/1)

      case sentences do
        [] -> {:ok, "No activity or enrichment data recorded for this account yet."}
        list -> {:ok, Enum.join(list, " ")}
      end
    end

    defp identity(account, enrichment) do
      name = get(enrichment, "full_name") || account[:name] || "This account holder"
      "#{name} holds the account #{account[:email]}."
    end

    defp role(nil), do: nil

    defp role(enrichment) do
      position = get(enrichment, "position")
      company = get(enrichment, "company_name")
      seniority = get(enrichment, "seniority")
      department = get(enrichment, "department")

      cond do
        position && company ->
          "The enrichment record gives their position as #{position} at #{company}" <>
            if(seniority, do: ", at #{seniority} level.", else: ".")

        company ->
          "The enrichment record associates them with #{company}."

        position ->
          "The enrichment record gives their position as #{position}."

        department ->
          "The enrichment record places them in #{department}."

        true ->
          nil
      end
    end

    defp location(nil), do: nil

    defp location(enrichment) do
      case get(enrichment, "location") do
        nil -> nil
        place -> "They are listed as based in #{place}."
      end
    end

    defp volume(%{total_messages: 0}), do: "No mail has passed through the account yet."

    defp volume(signals) do
      "The account has handled #{signals.total_messages} messages, " <>
        "#{signals.sent} outbound and #{signals.received} inbound."
    end

    defp cadence(%{total_messages: 0}), do: nil
    defp cadence(%{first_seen: nil}), do: nil

    defp cadence(signals) do
      "Activity runs from #{Date.to_string(signals.first_seen)} to " <>
        "#{Date.to_string(signals.last_seen)}, averaging " <>
        "#{signals.messages_per_active_day} a day on days it was used."
    end

    defp correspondents(%{top_correspondents: []}), do: nil

    defp correspondents(signals) do
      named =
        signals.top_correspondents
        |> Enum.take(4)
        |> Enum.map(fn %{address: a, messages: n} -> "#{a} (#{n})" end)
        |> Enum.join(", ")

      "Their most frequent correspondents are #{named}."
    end

    defp themes(%{recent_subjects: []}), do: nil

    defp themes(signals) do
      subjects =
        signals.recent_subjects |> Enum.take(5) |> Enum.map(&inspect/1) |> Enum.join(", ")

      "Recent subject lines include #{subjects}."
    end

    defp domains(%{sending_domains: []}), do: nil

    defp domains(signals) do
      "They send from #{Enum.join(signals.sending_domains, ", ")}."
    end

    defp get(nil, _key), do: nil

    defp get(map, key) do
      case Map.get(map, key) do
        value when is_binary(value) and value != "" -> value
        _ -> nil
      end
    end
  end
end
