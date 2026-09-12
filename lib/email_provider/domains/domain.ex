defmodule EmailProvider.Domains.Domain do
  @moduledoc """
  A sending domain. Carries its own DKIM keypair and its own warmup counters,
  because reputation is per-domain: one customer's bad week must not spend
  another's headroom.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "domains" do
    field :name, :string
    field :state, :string, default: "unverified"

    field :dkim_selector, :string
    field :dkim_private_pem, :string, redact: true
    field :dkim_public_der_b64, :string

    field :spf_verified_at, :utc_datetime_usec
    field :dkim_verified_at, :utc_datetime_usec
    field :mx_verified_at, :utc_datetime_usec
    field :last_checked_at, :utc_datetime_usec

    field :tracking_opens, :boolean, default: false
    field :tracking_clicks, :boolean, default: false

    field :smtp_login, :string
    field :smtp_password_hash, :string, redact: true

    field :warmup_enabled, :boolean, default: true
    field :lifetime_sent, :integer, default: 0
    field :first_sent_on, :date

    belongs_to :user, EmailProvider.Accounts.User
    has_many :messages, EmailProvider.Mail.Message

    timestamps()
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [
      :user_id,
      :name,
      :state,
      :dkim_selector,
      :dkim_private_pem,
      :dkim_public_der_b64,
      :spf_verified_at,
      :dkim_verified_at,
      :mx_verified_at,
      :last_checked_at,
      :tracking_opens,
      :tracking_clicks,
      :smtp_login,
      :smtp_password_hash,
      :warmup_enabled,
      :lifetime_sent,
      :first_sent_on
    ])
    |> validate_required([
      :user_id,
      :name,
      :dkim_selector,
      :dkim_private_pem,
      :dkim_public_der_b64
    ])
    |> update_change(
      :name,
      &(&1 |> String.trim() |> String.downcase() |> String.trim_trailing("."))
    )
    |> validate_format(
      :name,
      ~r/^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$/,
      message: "must be a bare domain such as mail.example.com"
    )
    |> validate_inclusion(:state, ~w(unverified active disabled))
    |> unique_constraint(:name, name: :domains_name_lower_index)
  end

  @doc "True once every DNS record we require has been observed."
  def verified?(%__MODULE__{} = d),
    do: not is_nil(d.spf_verified_at) and not is_nil(d.dkim_verified_at)
end
