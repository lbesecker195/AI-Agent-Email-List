defmodule EmailProviderWeb.AccountController do
  use EmailProviderWeb, :controller

  alias EmailProvider.Accounts
  alias EmailProvider.Analytics
  alias EmailProviderWeb.Views

  @doc "POST /v1/accounts — open an account."
  def create(conn, params) do
    case Accounts.register_user(%{
           email: params["email"],
           name: params["name"],
           password: params["password"]
         }) do
      {:ok, user} ->
        {:ok, _key, plaintext} = Accounts.create_api_key(user, label: "initial key")

        # Counted alongside the MCP signups so the two routes in are
        # comparable. The account is not described, only that there is one more.
        Analytics.report(:account_created,
          sid: Analytics.session_id(nil, user),
          visitor: Analytics.visitor_id(user),
          transport: "rest"
        )

        conn
        |> put_status(:created)
        |> json(%{
          message: "account created",
          account: %{id: user.id, email: user.email, name: user.name},
          # The only time this value exists outside the caller's hands.
          api_key: plaintext
        })

      {:error, changeset} ->
        conn |> put_status(:bad_request) |> json(%{errors: Views.changeset_errors(changeset)})
    end
  end

  @doc "POST /v1/accounts/login — exchange a password for a short-lived token."
  def login(conn, params) do
    case Accounts.authenticate_password(params["email"], params["password"]) do
      {:ok, user, token, expires_at} ->
        json(conn, %{
          token: token,
          expires_at: expires_at,
          account: %{id: user.id, email: user.email, name: user.name}
        })

      {:error, :locked} ->
        conn
        |> put_status(:too_many_requests)
        |> json(%{message: "too many failed attempts; try again later"})

      {:error, _reason} ->
        conn |> put_status(:unauthorized) |> json(%{message: "invalid credentials"})
    end
  end

  @doc "GET /v1/api-keys"
  def index_keys(conn, _params) do
    keys = Accounts.list_api_keys(conn.assigns.current_user)
    json(conn, %{items: Enum.map(keys, &Views.api_key/1)})
  end

  @doc "POST /v1/api-keys"
  def create_key(conn, params) do
    scopes =
      case params["scopes"] do
        list when is_list(list) -> list
        string when is_binary(string) -> String.split(string, ",", trim: true)
        _ -> EmailProvider.Accounts.ApiKey.all_scopes()
      end

    case Accounts.create_api_key(conn.assigns.current_user,
           label: params["label"],
           scopes: scopes
         ) do
      {:ok, key, plaintext} ->
        conn
        |> put_status(:created)
        |> json(%{
          key: Views.api_key(key),
          api_key: plaintext,
          message: "store this key now; it is not recoverable"
        })

      {:error, changeset} ->
        conn |> put_status(:bad_request) |> json(%{errors: Views.changeset_errors(changeset)})
    end
  end

  @doc "DELETE /v1/api-keys/:id"
  def delete_key(conn, %{"id" => id}) do
    keys = Accounts.list_api_keys(conn.assigns.current_user)

    case Enum.find(keys, &(&1.id == id)) do
      nil ->
        conn |> put_status(:not_found) |> json(%{message: "key not found"})

      key ->
        {:ok, key} = Accounts.revoke_api_key(key)
        json(conn, %{message: "key revoked", key: Views.api_key(key)})
    end
  end
end
