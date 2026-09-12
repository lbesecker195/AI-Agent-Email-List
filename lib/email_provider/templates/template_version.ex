defmodule EmailProvider.Templates.TemplateVersion do
  @moduledoc "One revision of a template. Exactly one version is active at a time."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "template_versions" do
    field :tag, :string, default: "initial"
    field :subject, :string
    field :body, :string
    field :engine, :string, default: "handlebars"
    field :active, :boolean, default: true
    field :comment, :string

    belongs_to :template, EmailProvider.Templates.Template

    timestamps()
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:template_id, :tag, :subject, :body, :engine, :active, :comment])
    |> validate_required([:template_id, :tag, :body])
    |> validate_inclusion(:engine, ~w(handlebars))
    |> unique_constraint([:template_id, :tag])
  end
end
