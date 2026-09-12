defmodule EmailProvider.Profiles.Profile do
  @moduledoc """
  A rolling description of an account holder, rewritten as their mail moves.

  The row keeps the description and the material behind it: the enrichment
  response and the activity digest it was written from. A description nobody
  can account for is not one you can act on, correct, or defend.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "user_profiles" do
    field :description, :string
    field :word_count, :integer, default: 0
    field :enrichment, :map, default: %{}
    field :enriched_at, :utc_datetime_usec
    field :signals, :map, default: %{}
    field :messages_seen, :integer, default: 0
    field :generator, :string
    field :version, :integer, default: 0
    field :last_error, :string
    field :generated_at, :utc_datetime_usec

    belongs_to :user, EmailProvider.Accounts.User
    belongs_to :last_message, EmailProvider.Mail.Message

    timestamps()
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [
      :user_id,
      :description,
      :word_count,
      :enrichment,
      :enriched_at,
      :signals,
      :messages_seen,
      :last_message_id,
      :generator,
      :version,
      :last_error,
      :generated_at
    ])
    |> validate_required([:user_id])
    |> unique_constraint(:user_id)
  end
end
