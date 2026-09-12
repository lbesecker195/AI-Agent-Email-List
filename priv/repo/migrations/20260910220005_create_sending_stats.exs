defmodule EmailProvider.Repo.Migrations.CreateSendingStats do
  use Ecto.Migration

  def change do
    # One row per domain per day. The warmup ladder reads two things from this
    # table: how many days a domain has actually sent on (which is what "day N
    # of warmup" means — a domain idle for a week has not warmed for a week),
    # and how many it has sent today.
    create table(:sending_stats, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :domain_id, references(:domains, type: :binary_id, on_delete: :delete_all), null: false
      add :day, :date, null: false
      add :sent_count, :integer, null: false, default: 0

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:sending_stats, [:domain_id, :day])
  end
end
