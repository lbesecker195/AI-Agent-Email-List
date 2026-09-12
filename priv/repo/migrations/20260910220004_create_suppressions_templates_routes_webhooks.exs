defmodule EmailProvider.Repo.Migrations.CreateSuppressionsTemplatesRoutesWebhooks do
  use Ecto.Migration

  def change do
    create table(:suppressions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :domain_id, references(:domains, type: :binary_id, on_delete: :delete_all), null: false
      # bounce | unsubscribe | complaint
      add :type, :string, null: false
      add :address, :string, null: false
      add :reason, :text
      add :error_code, :string
      add :tag, :string, null: false, default: "*"

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:suppressions, [:domain_id, :type, :address, :tag])
    create index(:suppressions, [:domain_id, :type])

    create table(:templates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :domain_id, references(:domains, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :description, :text

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:templates, [:domain_id, :name])

    create table(:template_versions, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :template_id, references(:templates, type: :binary_id, on_delete: :delete_all),
        null: false

      add :tag, :string, null: false, default: "initial"
      add :subject, :text
      add :body, :text, null: false
      add :engine, :string, null: false, default: "handlebars"
      add :active, :boolean, null: false, default: true
      add :comment, :text

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:template_versions, [:template_id, :tag])

    create table(:routes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :priority, :integer, null: false, default: 0
      add :description, :text
      # e.g. match_recipient(".*@example.com") — evaluated in order of priority
      add :expression, :text, null: false
      # e.g. ["forward(\"https://hooks.example.com/mg\")", "store()", "stop()"]
      add :actions, {:array, :string}, null: false, default: []
      add :enabled, :boolean, null: false, default: true

      timestamps(type: :utc_datetime_usec)
    end

    create index(:routes, [:user_id, :priority])

    create table(:webhooks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :domain_id, references(:domains, type: :binary_id, on_delete: :delete_all), null: false
      add :event_type, :string, null: false
      add :url, :text, null: false
      # Shared secret for the HMAC the receiver checks. Per-domain, not global,
      # so one customer's leaked secret cannot forge another's callbacks.
      add :signing_key, :string, null: false
      add :enabled, :boolean, null: false, default: true

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:webhooks, [:domain_id, :event_type])
  end
end
