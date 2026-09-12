defmodule EmailProvider.Suppressions do
  @moduledoc """
  Addresses this domain must not mail again: hard bounces, unsubscribes and
  spam complaints.

  Checked before every send. Continuing to mail an address that bounced hard or
  complained is the fastest way to lose a sending reputation, so the list is
  enforced by the send path rather than left to the caller to consult.
  """

  import Ecto.Query, warn: false

  alias EmailProvider.Repo
  alias EmailProvider.Domains.Domain
  alias EmailProvider.Suppressions.Suppression

  def list(%Domain{id: id}, type, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)

    Repo.all(
      from s in Suppression,
        where: s.domain_id == ^id and s.type == ^type,
        order_by: [desc: s.inserted_at],
        limit: ^limit
    )
  end

  def get(%Domain{id: id}, type, address) do
    normalized = address |> String.trim() |> String.downcase()

    Repo.one(
      from s in Suppression,
        where: s.domain_id == ^id and s.type == ^type and s.address == ^normalized,
        limit: 1
    )
  end

  def add(%Domain{id: id}, type, address, attrs \\ %{}) do
    params =
      attrs
      |> Map.merge(%{domain_id: id, type: type, address: address})

    %Suppression{}
    |> Suppression.changeset(params)
    |> Repo.insert(
      on_conflict: {:replace, [:reason, :error_code, :updated_at]},
      conflict_target: [:domain_id, :type, :address, :tag]
    )
  end

  def remove(%Domain{} = domain, type, address) do
    case get(domain, type, address) do
      nil -> {:error, :not_found}
      suppression -> Repo.delete(suppression)
    end
  end

  @doc """
  Split recipients into those we may mail and those we may not.

  Returns `{allowed, [{address, suppression}, ...]}`. A suppression scoped to a
  tag only bites when the message carries that tag.
  """
  def partition(%Domain{id: id}, recipients, tags \\ []) do
    normalized = Enum.map(recipients, &{&1, &1 |> extract_address() |> String.downcase()})
    addresses = Enum.map(normalized, &elem(&1, 1))

    suppressions =
      Repo.all(from s in Suppression, where: s.domain_id == ^id and s.address in ^addresses)

    Enum.reduce(normalized, {[], []}, fn {original, address}, {ok, blocked} ->
      case Enum.find(suppressions, &applies?(&1, address, tags)) do
        nil -> {ok ++ [original], blocked}
        suppression -> {ok, blocked ++ [{original, suppression}]}
      end
    end)
  end

  defp applies?(%Suppression{address: a, tag: "*"}, address, _tags), do: a == address

  defp applies?(%Suppression{address: a, tag: tag}, address, tags),
    do: a == address and tag in tags

  @doc ~S"""
  Pull the bare address out of a `"Name <addr@example.com>"` header value.
  """
  def extract_address(value) when is_binary(value) do
    case Regex.run(~r/<([^>]+)>/, value) do
      [_, address] -> String.trim(address)
      nil -> String.trim(value)
    end
  end
end
