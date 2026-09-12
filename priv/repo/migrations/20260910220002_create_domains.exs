defmodule EmailProvider.Repo.Migrations.CreateDomains do
  use Ecto.Migration

  def change do
    create table(:domains, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      # unverified -> active. A domain only sends once its DNS checks out.
      add :state, :string, null: false, default: "unverified"

      # DKIM keypair, generated when the domain is added. The private key never
      # leaves this row; the public half is what the operator publishes in DNS.
      add :dkim_selector, :string, null: false
      add :dkim_private_pem, :text, null: false
      add :dkim_public_der_b64, :text, null: false

      add :spf_verified_at, :utc_datetime_usec
      add :dkim_verified_at, :utc_datetime_usec
      add :mx_verified_at, :utc_datetime_usec
      add :last_checked_at, :utc_datetime_usec

      add :tracking_opens, :boolean, null: false, default: false
      add :tracking_clicks, :boolean, null: false, default: false

      add :smtp_login, :string
      add :smtp_password_hash, :string

      # Warmup state. `lifetime_sent` is the counter the ladder reads; it only
      # ever goes up, and test-mode sends do not touch it.
      add :warmup_enabled, :boolean, null: false, default: true
      add :lifetime_sent, :bigint, null: false, default: 0
      add :first_sent_on, :date

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:domains, ["lower(name)"], name: :domains_name_lower_index)
    create index(:domains, [:user_id])
  end
end
