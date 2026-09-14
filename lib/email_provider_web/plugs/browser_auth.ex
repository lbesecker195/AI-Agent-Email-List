defmodule EmailProviderWeb.Plugs.BrowserAuth do
  @moduledoc """
  Signed-in state for the browser console.

  The session holds a user id and nothing else. Not an API key: a cookie is sent
  on every request to this origin and lives on disk in the browser, and a key
  put there would be a long-lived fully-scoped credential in both places.
  Looking the user up per request also means a suspended account stops working
  immediately rather than at the end of its session.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [put_flash: 3, redirect: 2]

  alias EmailProvider.Accounts

  def init(opts), do: opts

  @doc "Attach the signed-in user, if there is one. Never redirects."
  def call(conn, _opts), do: assign(conn, :current_user, current_user(conn))

  defp current_user(conn) do
    with id when is_binary(id) <- get_session(conn, :user_id),
         %{status: "active"} = user <- Accounts.get_user(id) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Require a signed-in user, used as a plug in controllers that need one.

  Remembers where they were going, so signing in returns them there instead of
  dropping them on a generic page.
  """
  def require_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_session(:return_to, conn.request_path)
      |> put_flash(:error, "Sign in to continue.")
      |> redirect(to: "/login")
      |> halt()
    end
  end

  @doc "Start a session. Renews the session id so a fixated one cannot be reused."
  def sign_in(conn, user) do
    return_to = get_session(conn, :return_to)

    conn
    |> configure_session(renew: true)
    |> put_session(:user_id, user.id)
    |> put_session(:return_to, nil)
    |> then(&{&1, return_to})
  end

  def sign_out(conn), do: configure_session(conn, drop: true)
end
