defmodule EmailProvider.Accounts.User do
  @moduledoc "An account holder. Owns domains, API keys and messages."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "users" do
    field :email, :string
    field :name, :string
    field :password_hash, :string
    field :status, :string, default: "active"
    field :failed_logins, :integer, default: 0
    field :locked_until, :utc_datetime_usec

    field :password, :string, virtual: true, redact: true

    has_many :api_keys, EmailProvider.Accounts.ApiKey
    has_many :domains, EmailProvider.Domains.Domain

    timestamps()
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:email, :name, :status, :failed_logins, :locked_until])
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
    |> update_change(:email, &(&1 |> String.trim() |> String.downcase()))
    |> validate_inclusion(:status, ~w(active suspended))
    |> unique_constraint(:email, name: :users_email_lower_index)
  end

  def registration_changeset(struct, attrs) do
    struct
    |> changeset(attrs)
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 200)
    |> put_password_hash()
  end

  defp put_password_hash(changeset) do
    case get_change(changeset, :password) do
      nil -> changeset
      password -> put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
    end
  end
end
