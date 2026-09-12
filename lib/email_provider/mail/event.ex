defmodule EmailProvider.Mail.Event do
  @moduledoc """
  An append-only record of something that happened to a message. This is what
  the events API serves and what webhooks replay.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @types ~w(accepted rejected delivered failed opened clicked complained
            unsubscribed stored received)

  schema "events" do
    field :type, :string
    field :recipient, :string
    field :tags, {:array, :string}, default: []
    field :payload, :map, default: %{}
    field :occurred_at, :utc_datetime_usec

    belongs_to :message, EmailProvider.Mail.Message
    belongs_to :domain, EmailProvider.Domains.Domain

    timestamps()
  end

  def types, do: @types

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:message_id, :domain_id, :type, :recipient, :tags, :payload, :occurred_at])
    |> validate_required([:domain_id, :type, :occurred_at])
    |> validate_inclusion(:type, @types)
  end
end
