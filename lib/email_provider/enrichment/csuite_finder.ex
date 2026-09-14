defmodule EmailProvider.Enrichment.CSuiteFinder do
  @moduledoc """
  Client for the CSuiteFinder enrichment API.

  Two calls are used here: `/csuitefinder/email/enrich` resolves an address to a
  person, and `/csuitefinder/company/info` resolves a domain to a company. Both
  are billed per result upstream, so responses are cached on the profile row and
  only refreshed when they go stale.

  Every failure is soft. Enrichment is one input to a description, not a
  precondition for having one: if the provider is down or the person is unknown,
  the description gets written from mail activity alone.
  """

  require Logger

  @person_path "/csuitefinder/email/enrich"
  @company_path "/csuitefinder/company/info"

  @doc """
  Look up a person by email address.

  Returns `{:ok, map}` with whatever the provider knew, `{:ok, :not_found}` when
  it knew nothing, or `{:error, reason}` when the call itself failed. A caller
  that cannot tell those apart will treat an outage as an absence of facts.
  """
  @spec person(String.t()) :: {:ok, map()} | {:ok, :not_found} | {:error, term()}
  def person(email) when is_binary(email), do: call(@person_path, %{email: email})

  @spec company(String.t()) :: {:ok, map()} | {:ok, :not_found} | {:error, term()}
  def company(domain) when is_binary(domain), do: call(@company_path, %{domain: domain})

  defp call(path, params) do
    cond do
      not enabled?() -> {:error, :disabled}
      is_nil(api_key()) -> {:error, :no_api_key}
      true -> request(path, params)
    end
  end

  defp request(path, params) do
    opts =
      [
        method: :post,
        url: base_url() <> path,
        headers: [{"authorization", "Bearer " <> api_key()}],
        json: params,
        receive_timeout: timeout(),
        retry: :transient,
        max_retries: 2
      ]
      |> maybe_stub()

    case Req.request(opts) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        interpret(body)

      {:ok, %Req.Response{status: 404}} ->
        {:ok, :not_found}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.warning("csuitefinder #{path} returned #{status}: #{inspect(body)}")
        {:error, {:http, status}}

      {:error, reason} ->
        Logger.warning("csuitefinder #{path} transport failure: #{inspect(reason)}")
        {:error, {:transport, reason}}
    end
  end

  defp maybe_stub(opts) do
    case config()[:plug] do
      nil -> opts
      plug -> Keyword.merge(opts, plug: plug, retry: false)
    end
  end

  # The API answers 200 with `found: false` when it simply does not know the
  # person, which is a different thing from an error.
  defp interpret(%{"found" => false}), do: {:ok, :not_found}
  defp interpret(body) when is_map(body), do: {:ok, body}
  defp interpret(other), do: {:error, {:unexpected_body, other}}

  defp config, do: Application.get_env(:email_provider, __MODULE__, [])
  defp enabled?, do: Keyword.get(config(), :enabled, true)
  # See EmailProvider.Moderation: an empty string is not a key.
  defp api_key do
    case Keyword.get(config(), :api_key) do
      nil -> nil
      value when is_binary(value) -> if String.trim(value) == "", do: nil, else: value
      value -> value
    end
  end

  defp base_url, do: Keyword.get(config(), :base_url, "https://csuitefinder.com")
  defp timeout, do: Keyword.get(config(), :timeout, 10_000)
end
