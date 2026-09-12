defmodule EmailProvider.Templates do
  @moduledoc """
  Stored, versioned message bodies, and the substitution used to render them.

  The engine is deliberately not a general template language. It substitutes
  `{{name}}` and nothing else: no expressions, no includes, no loops. A stored
  template is attacker-controlled input in any multi-tenant service, and the
  smallest possible engine is the one with the smallest possible blast radius.
  """

  import Ecto.Query, warn: false

  alias EmailProvider.Repo
  alias EmailProvider.Domains.Domain
  alias EmailProvider.Templates.{Template, TemplateVersion}

  def list(%Domain{id: id}) do
    Repo.all(
      from t in Template, where: t.domain_id == ^id, order_by: [asc: t.name], preload: [:versions]
    )
  end

  def get(%Domain{id: id}, name) do
    Repo.one(
      from t in Template, where: t.domain_id == ^id and t.name == ^name, preload: [:versions]
    )
  end

  def create(%Domain{id: id}, attrs) do
    Repo.transaction(fn ->
      template =
        %Template{}
        |> Template.changeset(%{
          domain_id: id,
          name: attrs["name"],
          description: attrs["description"]
        })
        |> Repo.insert()

      case template do
        {:ok, template} ->
          if attrs["template"] do
            case create_version(template, attrs) do
              {:ok, _version} -> Repo.preload(template, :versions, force: true)
              {:error, changeset} -> Repo.rollback(changeset)
            end
          else
            Repo.preload(template, :versions)
          end

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  def create_version(%Template{} = template, attrs) do
    tag = attrs["tag"] || attrs["t:version"] || "initial"

    result =
      %TemplateVersion{}
      |> TemplateVersion.changeset(%{
        template_id: template.id,
        tag: tag,
        subject: attrs["subject"],
        body: attrs["template"],
        comment: attrs["comment"],
        active: true
      })
      |> Repo.insert()

    with {:ok, version} <- result do
      # Exactly one active version per template.
      Repo.update_all(
        from(v in TemplateVersion, where: v.template_id == ^template.id and v.id != ^version.id),
        set: [active: false]
      )

      {:ok, version}
    end
  end

  def delete(%Template{} = template), do: Repo.delete(template)

  @doc "The named version, or the active one when no tag is given."
  def version(%Template{versions: versions}, nil) when is_list(versions) do
    Enum.find(versions, & &1.active) || List.last(versions)
  end

  def version(%Template{versions: versions}, tag) when is_list(versions) do
    Enum.find(versions, &(&1.tag == tag))
  end

  @doc """
  Substitute `{{name}}` placeholders.

  Unknown names are left untouched rather than blanked, so a typo shows up in
  the delivered mail as `{{frist_name}}` instead of silently vanishing.
  """
  @spec render(String.t() | nil, map()) :: String.t() | nil
  def render(nil, _vars), do: nil

  def render(body, vars) when is_binary(body) and is_map(vars) do
    Regex.replace(~r/\{\{\s*([a-zA-Z0-9_.-]+)\s*\}\}/, body, fn whole, name ->
      case fetch_var(vars, name) do
        {:ok, value} -> to_string(value)
        :error -> whole
      end
    end)
  end

  defp fetch_var(vars, name) do
    case Map.fetch(vars, name) do
      {:ok, value} -> {:ok, value}
      :error -> Map.fetch(vars, String.to_atom(name))
    end
  rescue
    ArgumentError -> :error
  end
end
