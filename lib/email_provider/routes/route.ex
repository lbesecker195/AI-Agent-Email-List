defmodule EmailProvider.Routes.Route do
  @moduledoc """
  An inbound routing rule: a match expression and the actions to run when it
  matches. Evaluated highest priority first, stopping at `stop()`.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "routes" do
    field :priority, :integer, default: 0
    field :description, :string
    field :expression, :string
    field :actions, {:array, :string}, default: []
    field :enabled, :boolean, default: true

    belongs_to :user, EmailProvider.Accounts.User

    timestamps()
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:user_id, :priority, :description, :expression, :actions, :enabled])
    |> validate_required([:user_id, :expression])
    |> validate_change(:expression, &validate_expression/2)
    |> validate_change(:actions, &validate_actions/2)
  end

  defp validate_expression(:expression, expr) do
    if Regex.match?(~r/^\s*(match_recipient|match_header|catch_all)\s*\(/, expr) do
      []
    else
      [expression: "must be match_recipient(...), match_header(...) or catch_all()"]
    end
  end

  defp validate_actions(:actions, actions) do
    bad = Enum.reject(actions, &Regex.match?(~r/^\s*(forward|store|stop)\s*\(/, &1))
    if bad == [], do: [], else: [actions: "unsupported action(s): #{Enum.join(bad, ", ")}"]
  end
end
