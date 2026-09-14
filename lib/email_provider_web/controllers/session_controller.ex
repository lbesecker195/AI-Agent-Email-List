defmodule EmailProviderWeb.SessionController do
  use EmailProviderWeb, :controller

  # Both render pages that live in ConsoleHTML; without this Phoenix looks for a
  # view module named after the controller, which does not exist.
  plug :put_view, html: EmailProviderWeb.ConsoleHTML

  alias EmailProvider.Accounts
  alias EmailProviderWeb.Plugs.BrowserAuth

  def new(conn, _params) do
    if conn.assigns[:current_user] do
      redirect(conn, to: "/domains")
    else
      render(conn, :login, email: "")
    end
  end

  def create(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_password(email, password) do
      {:ok, user, _token, _expires} ->
        {conn, return_to} = BrowserAuth.sign_in(conn, user)
        redirect(conn, to: return_to || "/domains")

      {:error, :locked} ->
        conn
        |> put_flash(:error, "Too many failed attempts. Try again in a few minutes.")
        |> render(:login, email: email)

      {:error, _reason} ->
        # One message for a wrong password and an unknown address alike, so this
        # form cannot be used to find out which addresses have accounts.
        conn
        |> put_flash(:error, "That email and password do not match.")
        |> render(:login, email: email)
    end
  end

  def create(conn, _params) do
    conn |> put_flash(:error, "Enter an email address and password.") |> render(:login, email: "")
  end

  def delete(conn, _params) do
    conn
    |> BrowserAuth.sign_out()
    |> put_flash(:info, "Signed out.")
    |> redirect(to: "/")
  end
end
