defmodule EmailProvider.Mail.Message do
  @moduledoc "One email, outbound or inbound, with its delivery and moderation state."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @statuses ~w(queued scheduled sent delivered failed rejected received)

  schema "messages" do
    field :direction, :string
    field :storage_key, :string
    field :rfc_message_id, :string

    field :sender, :string
    field :recipients, {:array, :string}, default: []
    field :cc, {:array, :string}, default: []
    field :bcc, {:array, :string}, default: []
    field :subject, :string
    field :body_text, :string
    field :body_html, :string
    field :mime_raw, :string

    field :headers, :map, default: %{}
    field :variables, :map, default: %{}
    field :tags, {:array, :string}, default: []

    field :template_name, :string
    field :template_version, :string

    field :status, :string, default: "queued"
    field :folder, :string
    field :test_mode, :boolean, default: false

    field :scheduled_at, :utc_datetime_usec
    field :sent_at, :utc_datetime_usec
    field :delivered_at, :utc_datetime_usec
    field :failure_reason, :string
    field :attempts, :integer, default: 0

    field :moderation_checked_at, :utc_datetime_usec
    field :moderation_flagged, :boolean, default: false
    field :moderation_categories, {:array, :string}, default: []
    field :moderation_scores, :map, default: %{}
    field :moderation_action, :string

    field :tracking_opens, :boolean, default: false
    field :tracking_clicks, :boolean, default: false

    belongs_to :user, EmailProvider.Accounts.User
    belongs_to :domain, EmailProvider.Domains.Domain
    has_many :events, EmailProvider.Mail.Event

    timestamps()
  end

  def statuses, do: @statuses

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [
      :user_id,
      :domain_id,
      :direction,
      :storage_key,
      :rfc_message_id,
      :sender,
      :recipients,
      :cc,
      :bcc,
      :subject,
      :body_text,
      :body_html,
      :mime_raw,
      :headers,
      :variables,
      :tags,
      :template_name,
      :template_version,
      :status,
      :folder,
      :test_mode,
      :scheduled_at,
      :sent_at,
      :delivered_at,
      :failure_reason,
      :attempts,
      :moderation_checked_at,
      :moderation_flagged,
      :moderation_categories,
      :moderation_scores,
      :moderation_action,
      :tracking_opens,
      :tracking_clicks
    ])
    |> validate_required([:domain_id, :direction, :storage_key, :sender])
    |> validate_inclusion(:direction, ~w(outbound inbound))
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:folder, ~w(inbox spam), allow_nil: true)
    |> unique_constraint(:storage_key)
  end
end
