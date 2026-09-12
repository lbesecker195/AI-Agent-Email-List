defmodule EmailProvider.Accounts.ApiKey do
  @moduledoc """
  An API credential. Stored as a SHA-256 hash of the plaintext plus a short
  prefix; the plaintext is returned once at creation and never again.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @scopes ~w(messages:send messages:read domains:read domains:write events:read
             suppressions:read suppressions:write templates:write routes:write webhooks:write)

  schema "api_keys" do
    field :key_hash, :string
    field :prefix, :string
    field :label, :string
    field :kind, :string, default: "api"
    field :scopes, {:array, :string}, default: ["messages:send"]
    field :expires_at, :utc_datetime_usec
    field :revoked_at, :utc_datetime_usec
    field :last_used_at, :utc_datetime_usec

    belongs_to :user, EmailProvider.Accounts.User

    timestamps()
  end

  def all_scopes, do: @scopes

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [
      :user_id,
      :key_hash,
      :prefix,
      :label,
      :kind,
      :scopes,
      :expires_at,
      :revoked_at,
      :last_used_at
    ])
    |> validate_required([:user_id, :key_hash, :prefix])
    |> validate_inclusion(:kind, ~w(api session))
    |> validate_subset(:scopes, @scopes)
    |> unique_constraint(:key_hash)
  end
end
