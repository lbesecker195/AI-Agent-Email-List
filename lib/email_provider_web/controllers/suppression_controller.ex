defmodule EmailProviderWeb.SuppressionController do
  use EmailProviderWeb, :controller

  alias EmailProviderWeb.Plugs.RequireScope

  plug RequireScope, "suppressions:read" when action in [:index, :show]
  plug RequireScope, "suppressions:write" when action in [:create, :delete]

  alias EmailProvider.Suppressions
  alias EmailProviderWeb.Views

  # One controller serves bounces, unsubscribes and complaints; the router
  # supplies which via the :type option, so the three lists cannot drift apart.
  def index(conn, params) do
    type = type!(conn)
    limit = params |> Map.get("limit", "100") |> String.to_integer() |> min(1000)
    items = Suppressions.list(conn.assigns.domain, type, limit: limit)
    json(conn, %{total_count: length(items), items: Enum.map(items, &Views.suppression/1)})
  end

  def show(conn, %{"address" => address}) do
    case Suppressions.get(conn.assigns.domain, type!(conn), address) do
      nil -> conn |> put_status(:not_found) |> json(%{message: "address not found"})
      suppression -> json(conn, Views.suppression(suppression))
    end
  end

  def create(conn, params) do
    address = params["address"]

    attrs = %{
      reason: params["reason"] || params["error"],
      error_code: params["code"],
      tag: params["tag"] || "*"
    }

    case Suppressions.add(conn.assigns.domain, type!(conn), address, attrs) do
      {:ok, suppression} ->
        conn
        |> put_status(:ok)
        |> json(%{message: "address has been added", item: Views.suppression(suppression)})

      {:error, changeset} ->
        conn |> put_status(:bad_request) |> json(%{errors: Views.changeset_errors(changeset)})
    end
  end

  def delete(conn, %{"address" => address}) do
    case Suppressions.remove(conn.assigns.domain, type!(conn), address) do
      {:ok, _} ->
        json(conn, %{message: "address has been removed", address: address})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{message: "address not found"})
    end
  end

  defp type!(conn), do: conn.private.suppression_type
end
