defmodule EmailProvider.Repo.Migrations.CreateUserProfiles do
  use Ecto.Migration

  def change do
    create table(:user_profiles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      # The rolling description itself, plus the material it was written from.
      add :description, :text
      add :word_count, :integer, null: false, default: 0

      # Cached CSuiteFinder response. Kept whole so a later change to what we
      # extract does not require re-buying the lookup.
      add :enrichment, :map, null: false, default: %{}
      add :enriched_at, :utc_datetime_usec

      # The digest of mail activity the description was generated from. Stored
      # so a description can be explained after the fact rather than being an
      # unattributable paragraph.
      add :signals, :map, null: false, default: %{}

      add :messages_seen, :integer, null: false, default: 0
      add :last_message_id, references(:messages, type: :binary_id, on_delete: :nilify_all)
      add :generator, :string
      add :version, :integer, null: false, default: 0
      add :last_error, :text
      add :generated_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:user_profiles, [:user_id])
  end
end
