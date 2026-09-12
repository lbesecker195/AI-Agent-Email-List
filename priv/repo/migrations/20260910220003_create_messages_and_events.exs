defmodule EmailProvider.Repo.Migrations.CreateMessagesAndEvents do
  use Ecto.Migration

  def change do
    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :domain_id, references(:domains, type: :binary_id, on_delete: :delete_all), null: false

      add :direction, :string, null: false
      add :storage_key, :string, null: false
      add :rfc_message_id, :string

      add :sender, :string, null: false
      add :recipients, {:array, :string}, null: false, default: []
      add :cc, {:array, :string}, null: false, default: []
      add :bcc, {:array, :string}, null: false, default: []
      add :subject, :text
      add :body_text, :text
      add :body_html, :text
      add :mime_raw, :text

      add :headers, :map, null: false, default: %{}
      add :variables, :map, null: false, default: %{}
      add :tags, {:array, :string}, null: false, default: []

      add :template_name, :string
      add :template_version, :string

      add :status, :string, null: false, default: "queued"
      add :folder, :string
      add :test_mode, :boolean, null: false, default: false

      add :scheduled_at, :utc_datetime_usec
      add :sent_at, :utc_datetime_usec
      add :delivered_at, :utc_datetime_usec
      add :failure_reason, :text
      add :attempts, :integer, null: false, default: 0

      # Content moderation verdict, kept per message so a rejection can be
      # explained after the fact rather than just being a 403 in a log.
      add :moderation_checked_at, :utc_datetime_usec
      add :moderation_flagged, :boolean, null: false, default: false
      add :moderation_categories, {:array, :string}, null: false, default: []
      add :moderation_scores, :map, null: false, default: %{}
      add :moderation_action, :string

      add :tracking_opens, :boolean, null: false, default: false
      add :tracking_clicks, :boolean, null: false, default: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:messages, [:storage_key])
    create index(:messages, [:domain_id, :inserted_at])
    create index(:messages, [:domain_id, :status])
    create index(:messages, [:status, :scheduled_at])
    create index(:messages, [:tags], using: "GIN")

    create table(:events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :message_id, references(:messages, type: :binary_id, on_delete: :delete_all)
      add :domain_id, references(:domains, type: :binary_id, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :recipient, :string
      add :tags, {:array, :string}, null: false, default: []
      add :payload, :map, null: false, default: %{}
      add :occurred_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:events, [:domain_id, :occurred_at])
    create index(:events, [:domain_id, :type, :occurred_at])
    create index(:events, [:message_id])
  end
end
