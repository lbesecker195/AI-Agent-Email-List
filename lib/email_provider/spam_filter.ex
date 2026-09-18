defmodule EmailProvider.SpamFilter do
  @moduledoc """
  Spam classification through the Claude API, alongside (not instead of)
  `EmailProvider.Moderation`.

  The two catch different things. OpenAI's moderation endpoint flags harmful
  content — hate, violence, sexual content, self-harm. It has no notion of
  "spam": a bulk newsletter nobody asked for, a phishing attempt, or a
  cryptocurrency scam all score as clean there, because none of them are
  hateful or violent. This module is what actually answers "is this spam", by
  asking a model to read the message and decide.

  Same two consequences as moderation, and the same reasoning behind them:

    * outbound — a flagged message is refused at the API and never reaches the
      wire.
    * inbound — a flagged message is still delivered, but filed in spam
      rather than the inbox, because dropping incoming mail outright loses a
      real message to every false positive.

  `EmailProvider.Mail` runs both screeners and combines their verdicts: either
  one flagging a message is enough to act on it, with both verdicts' categories
  and scores kept rather than one overwriting the other.

  Claude Haiku is the model by default, not a larger one: this runs on every
  message, so it needs to be the cheapest model that can still read a short
  email and tell a sales pitch from a phishing attempt from an ordinary reply.

  ## When Claude is unreachable

  Set by `:on_error`, same default as moderation: `:allow`. A third-party
  outage should not take the whole service down with it. The message is still
  recorded as unscreened, so a backfill can find it later. Set `:block` if a
  missed screening is worse for you than a refused send.
  """

  require Logger

  @endpoint "/v1/messages"
  @model "claude-haiku-4-5-20251001"
  @anthropic_version "2023-06-01"
  # Spam is judged mostly by the opening and any links — a long message is
  # screened on the first few thousand characters, which is where that signal
  # sits, and this keeps the per-message cost predictable.
  @max_input_bytes 8_000

  @tool_name "classify_spam"
  @categories ~w(none bulk_unsolicited phishing scam malware_link adult other)

  @type verdict :: %{
          flagged: boolean(),
          categories: [String.t()],
          scores: map(),
          checked_at: DateTime.t() | nil,
          screened: boolean()
        }

  @doc """
  Classify the text of a message.

  Accepts the parts to consider (subject, text body, a stripped HTML body) and
  judges them as one message, the same call shape as `Moderation.check/1`.
  """
  @spec check([String.t() | nil]) :: {:ok, verdict()} | {:error, term()}
  def check(parts) when is_list(parts) do
    parts
    |> Enum.reject(&(is_nil(&1) or &1 == ""))
    |> Enum.join("\n\n")
    |> check_text()
  end

  @spec check_text(String.t()) :: {:ok, verdict()} | {:error, term()}
  def check_text(""), do: {:ok, clean()}

  def check_text(text) when is_binary(text) do
    cond do
      not enabled?() ->
        {:ok, unscreened()}

      is_nil(api_key()) ->
        Logger.warning("spam filter is enabled but ANTHROPIC_API_KEY is unset; not screening")
        {:ok, unscreened()}

      true ->
        request(truncate(text))
    end
  end

  defp request(text) do
    req_opts =
      [
        method: :post,
        url: base_url() <> @endpoint,
        headers: [
          {"x-api-key", api_key()},
          {"anthropic-version", @anthropic_version},
          {"content-type", "application/json"}
        ],
        json: %{
          model: model(),
          max_tokens: 200,
          system: system_prompt(),
          messages: [%{role: "user", content: text}],
          tools: [tool_spec()],
          tool_choice: %{type: "tool", name: @tool_name}
        },
        receive_timeout: timeout(),
        retry: :transient,
        max_retries: 2
      ]
      |> maybe_stub()

    case Req.request(req_opts) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, interpret(body)}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.warning("spam filter returned #{status}: #{inspect(body)}")
        {:error, {:http, status}}

      {:error, reason} ->
        Logger.warning("spam filter transport failure: #{inspect(reason)}")
        {:error, {:transport, reason}}
    end
  end

  # Forcing the tool call, rather than asking for prose and parsing it, is
  # what makes this safe to run unattended: there is no "mostly JSON" response
  # to recover from, and no risk of the model explaining itself instead of
  # answering.
  defp tool_spec do
    %{
      name: @tool_name,
      description: "Report whether an email is spam.",
      input_schema: %{
        type: "object",
        properties: %{
          is_spam: %{
            type: "boolean",
            description:
              "true if this is spam: unsolicited bulk mail, a phishing attempt, a " <>
                "scam, a malware link, or advertising the recipient did not ask for. " <>
                "false for an ordinary personal or transactional message, even an " <>
                "unwelcome one (a complaint, a breakup, bad news) — spam is about " <>
                "who is sending and why, not tone."
          },
          category: %{type: "string", enum: @categories},
          confidence: %{
            type: "number",
            description: "0 (guessing) to 1 (certain) confidence in is_spam."
          }
        },
        required: ~w(is_spam category confidence)
      }
    }
  end

  defp system_prompt do
    """
    You classify a single email for a mail service's spam filter. You are given
    its subject and body as the user message. Decide only whether it is spam, and
    report your answer by calling the classify_spam tool — do not write prose.
    """
  end

  # Tests point this at a Plug instead of the network, so the code under test
  # is the same code that runs in production.
  defp maybe_stub(req_opts) do
    case config()[:plug] do
      nil -> req_opts
      plug -> Keyword.merge(req_opts, plug: plug, retry: false)
    end
  end

  defp interpret(%{"content" => content}) when is_list(content) do
    content
    |> Enum.find(&(&1["type"] == "tool_use" and &1["name"] == @tool_name))
    |> case do
      %{"input" => %{"is_spam" => is_spam} = input} ->
        category = normalize_category(input["category"])
        confidence = input["confidence"]

        %{
          flagged: is_spam == true,
          categories: if(is_spam == true, do: [category], else: []),
          scores: if(is_number(confidence), do: %{"spam" => confidence}, else: %{}),
          checked_at: DateTime.utc_now(),
          screened: true
        }

      _ ->
        Logger.warning(
          "unexpected spam-filter payload: no classify_spam call in #{inspect(content)}"
        )

        unscreened()
    end
  end

  defp interpret(other) do
    Logger.warning("unexpected spam-filter payload: #{inspect(other)}")
    unscreened()
  end

  defp normalize_category(category) when category in @categories, do: category
  defp normalize_category(_other), do: "other"

  @doc """
  Turn a verdict (or a failure) into the action to take, honouring `:on_error`.

  Same shape and semantics as `Moderation.decide/2` — returns `:allow`,
  `:block` (outbound) or `:spam` (inbound) — so `Mail` can combine the two
  screeners' decisions without caring which one fired.
  """
  @spec decide({:ok, verdict()} | {:error, term()}, :outbound | :inbound) ::
          {:allow | :block | :spam, verdict()}
  def decide({:ok, %{flagged: true} = verdict}, :outbound), do: {:block, verdict}
  def decide({:ok, %{flagged: true} = verdict}, :inbound), do: {:spam, verdict}
  def decide({:ok, verdict}, _direction), do: {:allow, verdict}

  def decide({:error, _reason}, direction) do
    verdict = unscreened()

    case on_error() do
      :block when direction == :outbound -> {:block, verdict}
      :block -> {:spam, verdict}
      _allow -> {:allow, verdict}
    end
  end

  defp clean do
    %{flagged: false, categories: [], scores: %{}, checked_at: DateTime.utc_now(), screened: true}
  end

  # Not screened is not the same as screened and found clean. It carries no
  # check time, so nothing downstream can mistake one for the other.
  defp unscreened do
    %{flagged: false, categories: [], scores: %{}, checked_at: nil, screened: false}
  end

  defp truncate(text) when byte_size(text) <= @max_input_bytes, do: text
  defp truncate(text), do: binary_part(text, 0, @max_input_bytes)

  defp config, do: Application.get_env(:email_provider, __MODULE__, [])
  defp enabled?, do: Keyword.get(config(), :enabled, true)
  # An empty string is not a key. Environment files routinely carry
  # `ANTHROPIC_API_KEY=` with nothing after it, and treating that as present
  # means a doomed request with an empty bearer token on every single message.
  defp api_key do
    case Keyword.get(config(), :api_key) do
      nil -> nil
      "" -> nil
      value when is_binary(value) -> if String.trim(value) == "", do: nil, else: value
      value -> value
    end
  end

  defp base_url, do: Keyword.get(config(), :base_url, "https://api.anthropic.com")
  defp model, do: Keyword.get(config(), :model, @model)
  defp timeout, do: Keyword.get(config(), :timeout, 10_000)
  defp on_error, do: Keyword.get(config(), :on_error, :allow)
end
