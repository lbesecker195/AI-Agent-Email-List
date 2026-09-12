defmodule EmailProvider.Repo.Migrations.CreateUsersAndApiKeys do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :name, :string
      add :password_hash, :string
      add :status, :string, null: false, default: "active"
      add :failed_logins, :integer, null: false, default: 0
      add :locked_until, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:users, ["lower(email)"], name: :users_email_lower_index)

    create table(:api_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      # Only ever the hash. The plaintext is shown once, at creation, and then
      # we cannot recover it — a lost key is rotated, not looked up.
      add :key_hash, :string, null: false
      add :prefix, :string, null: false
      add :label, :string
      add :kind, :string, null: false, default: "api"
      add :scopes, {:array, :string}, null: false, default: ["messages:send"]
      add :expires_at, :utc_datetime_usec
      add :revoked_at, :utc_datetime_usec
      add :last_used_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:api_keys, [:key_hash])
    create index(:api_keys, [:user_id])
  end
end
