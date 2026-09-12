defmodule EmailProvider.Webhooks.Webhook do
  @moduledoc "A callback URL for one event type on one domain."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "webhooks" do
    field :event_type, :string
    field :url, :string
    field :signing_key, :string, redact: true
    field :enabled, :boolean, default: true

    belongs_to :domain, EmailProvider.Domains.Domain

    timestamps()
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:domain_id, :event_type, :url, :signing_key, :enabled])
    |> validate_required([:domain_id, :event_type, :url, :signing_key])
    |> validate_inclusion(:event_type, EmailProvider.Mail.Event.types())
    |> validate_format(:url, ~r{^https?://}, message: "must be an http(s) URL")
    |> unique_constraint([:domain_id, :event_type])
  end
end
