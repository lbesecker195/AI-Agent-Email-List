defmodule EmailProviderWeb.RouteController do
  use EmailProviderWeb, :controller

  alias EmailProviderWeb.Plugs.RequireScope

  plug RequireScope, "domains:read" when action in [:index, :show]
  plug RequireScope, "routes:write" when action in [:create, :update, :delete]

  alias EmailProvider.Routes
  alias EmailProviderWeb.Views

  def index(conn, _params) do
    items = Routes.list(conn.assigns.current_user)
    json(conn, %{total_count: length(items), items: Enum.map(items, &Views.route/1)})
  end

  def create(conn, params) do
    case Routes.create(conn.assigns.current_user, params) do
      {:ok, route} ->
        conn
        |> put_status(:created)
        |> json(%{message: "Route has been created", route: Views.route(route)})

      {:error, changeset} ->
        conn |> put_status(:bad_request) |> json(%{errors: Views.changeset_errors(changeset)})
    end
  end

  def show(conn, %{"id" => id}) do
    with_route(conn, id, &json(conn, %{route: Views.route(&1)}))
  end

  def update(conn, %{"id" => id} = params) do
    with_route(conn, id, fn route ->
      case Routes.update(route, params) do
        {:ok, route} ->
          json(conn, %{message: "Route has been updated", route: Views.route(route)})

        {:error, changeset} ->
          conn |> put_status(:bad_request) |> json(%{errors: Views.changeset_errors(changeset)})
      end
    end)
  end

  def delete(conn, %{"id" => id}) do
    with_route(conn, id, fn route ->
      {:ok, _} = Routes.delete(route)
      json(conn, %{message: "Route has been deleted"})
    end)
  end

  # Scoped to the calling user, so an id belonging to someone else is a 404
  # rather than a way to read or edit their routing.
  defp with_route(conn, id, fun) do
    case safe_get(conn.assigns.current_user, id) do
      nil -> conn |> put_status(:not_found) |> json(%{message: "route not found"})
      route -> fun.(route)
    end
  end

  defp safe_get(user, id) do
    Routes.get(user, id)
  rescue
    Ecto.Query.CastError -> nil
  end
end
