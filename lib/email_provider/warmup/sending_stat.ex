defmodule EmailProvider.Warmup.SendingStat do
  @moduledoc "Per-domain, per-day sent counter. The warmup ladder reads this."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "sending_stats" do
    field :day, :date
    field :sent_count, :integer, default: 0

    belongs_to :domain, EmailProvider.Domains.Domain

    timestamps()
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:domain_id, :day, :sent_count])
    |> validate_required([:domain_id, :day])
    |> unique_constraint([:domain_id, :day])
  end
end
