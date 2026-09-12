defmodule EmailProvider.Templates.Template do
  @moduledoc "A named, versioned message body stored against a domain."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "templates" do
    field :name, :string
    field :description, :string

    belongs_to :domain, EmailProvider.Domains.Domain
    has_many :versions, EmailProvider.Templates.TemplateVersion

    timestamps()
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:domain_id, :name, :description])
    |> validate_required([:domain_id, :name])
    |> validate_format(:name, ~r/^[a-zA-Z0-9._-]+$/)
    |> unique_constraint([:domain_id, :name])
  end
end
