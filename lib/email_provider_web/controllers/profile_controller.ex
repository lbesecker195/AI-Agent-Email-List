defmodule EmailProviderWeb.ProfileController do
  use EmailProviderWeb, :controller

  alias EmailProvider.Profiles
  alias EmailProviderWeb.Views

  plug EmailProviderWeb.Plugs.RequireScope, "messages:read"

  @doc """
  GET /v1/profile

  The calling account's own description. Scoped to the caller: there is no
  endpoint here that returns somebody else's.
  """
  def show(conn, _params) do
    case Profiles.get(conn.assigns.current_user) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{message: "no description has been written for this account yet"})

      profile ->
        json(conn, %{profile: Views.profile(profile)})
    end
  end

  @doc """
  POST /v1/profile/refresh

  Rewrite now rather than waiting for the next message. Runs inline so the
  caller gets the new description in the response.
  """
  def refresh(conn, _params) do
    case Profiles.refresh(conn.assigns.current_user) do
      {:ok, profile} ->
        json(conn, %{profile: Views.profile(profile)})

      {:error, reason} ->
        conn
        |> put_status(:bad_gateway)
        |> json(%{
          message: "could not write the description",
          reason: inspect(reason),
          profile: conn.assigns.current_user |> Profiles.get() |> Views.profile()
        })
    end
  end

  @doc "GET /v1/profile/signals — the material the description is written from."
  def signals(conn, _params) do
    json(conn, %{signals: Profiles.signals(conn.assigns.current_user)})
  end
end
