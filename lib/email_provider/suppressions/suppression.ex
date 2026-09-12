defmodule EmailProvider.Suppressions.Suppression do
  @moduledoc """
  A recipient we must not mail again on this domain: a hard bounce, an
  unsubscribe, or a spam complaint. Checked before every send.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @types ~w(bounce unsubscribe complaint)

  schema "suppressions" do
    field :type, :string
    field :address, :string
    field :reason, :string
    field :error_code, :string
    # "*" means every tag. An unsubscribe can be scoped to one campaign tag.
    field :tag, :string, default: "*"

    belongs_to :domain, EmailProvider.Domains.Domain

    timestamps()
  end

  def types, do: @types

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:domain_id, :type, :address, :reason, :error_code, :tag])
    |> validate_required([:domain_id, :type, :address])
    |> update_change(:address, &(&1 |> String.trim() |> String.downcase()))
    |> validate_inclusion(:type, @types)
    |> unique_constraint([:domain_id, :type, :address, :tag])
  end
end
