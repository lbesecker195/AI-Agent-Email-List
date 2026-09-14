defmodule EmailProviderWeb.RegistrationController do
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
      render(conn, :signup, email: "", name: "")
    end
  end

  def create(conn, params) do
    email = params["email"] || ""
    name = params["name"] || ""

    case Accounts.register_user(%{email: email, name: name, password: params["password"]}) do
      {:ok, user} ->
        # A key is minted here rather than on the account page, so somebody who
        # came to build against the API leaves with what they came for.
        {:ok, _key, plaintext} = Accounts.create_api_key(user, label: "first key")
        {conn, _return_to} = BrowserAuth.sign_in(conn, user)

        conn
        |> put_session(:new_api_key, plaintext)
        |> put_flash(:info, "Account created. Add a domain to start sending.")
        |> redirect(to: "/account")

      {:error, changeset} ->
        conn
        |> put_flash(:error, error_message(changeset))
        |> render(:signup, email: email, name: name)
    end
  end

  defp error_message(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {message, opts} ->
      Regex.replace(~r/%\{(\w+)\}/, message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map(fn {field, messages} ->
      "#{field |> to_string() |> String.capitalize()} #{Enum.join(messages, ", ")}"
    end)
    |> Enum.join(". ")
  end
end
