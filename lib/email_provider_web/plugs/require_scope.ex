defmodule EmailProviderWeb.Plugs.RequireScope do
  @moduledoc """
  Refuse a request whose API key does not carry the required scope.

  Declared per action in the controller rather than in the router pipeline, so
  a scope sits next to the code it guards and a new action cannot inherit a
  neighbour's permissions by accident.
  """

  import Plug.Conn

  alias EmailProvider.Accounts

  def init(scope) when is_binary(scope), do: scope

  def call(%{assigns: %{current_key: key}} = conn, scope) do
    if Accounts.has_scope?(key, scope) do
      conn
    else
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(403, Jason.encode!(%{message: "this API key is not authorized for #{scope}"}))
      |> halt()
    end
  end

  # No key on the connection means the auth plug did not run. Fail closed.
  def call(conn, _scope) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{message: "invalid credentials"}))
    |> halt()
  end
end
