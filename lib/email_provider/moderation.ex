defmodule EmailProvider.Moderation do
  @moduledoc """
  Content screening through OpenAI's moderation endpoint, which is free to call.

  Two callers, two consequences:

    * outbound — a flagged message is refused at the API with a 403 and never
      reaches the wire.
    * inbound — a flagged message is still delivered, but filed in spam rather
      than the inbox. Dropping someone's incoming mail outright loses real
      messages to false positives; filing it does not.

  ## When the moderation service is unreachable

  Set by `:on_error`. The default is `:allow`: a third-party outage should not
  take the whole service down with it. The message is still recorded as
  unscreened, so a backfill can find it later. Set `:block` if a missed
  screening is worse for you than a refused send.
  """

  require Logger

  @endpoint "/v1/moderations"
  @model "omni-moderation-latest"
  # Moderation inputs are capped; a long newsletter is screened on its opening,
  # which is where policy-violating content overwhelmingly sits.
  @max_input_bytes 40_000

  @type verdict :: %{
          flagged: boolean(),
          categories: [String.t()],
          scores: map(),
          checked_at: DateTime.t() | nil,
          screened: boolean()
        }

  @doc """
  Screen the text of a message.

  Accepts the parts to consider (subject, text body, a stripped HTML body) and
  screens them as one input.
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
        Logger.warning("moderation is enabled but OPENAI_API_KEY is unset; not screening")
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
          {"authorization", "Bearer " <> api_key()},
          {"content-type", "application/json"}
        ],
        json: %{model: model(), input: text},
        receive_timeout: timeout(),
        retry: :transient,
        max_retries: 2
      ]
      |> maybe_stub()

    case Req.request(req_opts) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, interpret(body)}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.warning("moderation returned #{status}: #{inspect(body)}")
        {:error, {:http, status}}

      {:error, reason} ->
        Logger.warning("moderation transport failure: #{inspect(reason)}")
        {:error, {:transport, reason}}
    end
  end

  # Tests point this at a Plug instead of the network, so the code under test
  # is the same code that runs in production.
  defp maybe_stub(req_opts) do
    case config()[:plug] do
      nil -> req_opts
      plug -> Keyword.merge(req_opts, plug: plug, retry: false)
    end
  end

  defp interpret(%{"results" => [result | _]}) do
    categories =
      result
      |> Map.get("categories", %{})
      |> Enum.filter(fn {_name, hit} -> hit == true end)
      |> Enum.map(&elem(&1, 0))
      |> Enum.sort()

    %{
      flagged: Map.get(result, "flagged", false) == true,
      categories: categories,
      scores: Map.get(result, "category_scores", %{}),
      checked_at: DateTime.utc_now(),
      screened: true
    }
  end

  defp interpret(other) do
    Logger.warning("unexpected moderation payload: #{inspect(other)}")
    unscreened()
  end

  @doc """
  Turn a verdict (or a failure) into the action to take, honouring `:on_error`.

  Returns `:allow`, `:block` (outbound) or `:spam` (inbound).
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
  # `OPENAI_API_KEY=` with nothing after it, and treating that as present means
  # a doomed request with an empty bearer token on every single message.
  defp api_key do
    case Keyword.get(config(), :api_key) do
      nil -> nil
      "" -> nil
      value when is_binary(value) -> if String.trim(value) == "", do: nil, else: value
      value -> value
    end
  end

  defp base_url, do: Keyword.get(config(), :base_url, "https://api.openai.com")
  defp model, do: Keyword.get(config(), :model, @model)
  defp timeout, do: Keyword.get(config(), :timeout, 10_000)
  defp on_error, do: Keyword.get(config(), :on_error, :allow)
end
