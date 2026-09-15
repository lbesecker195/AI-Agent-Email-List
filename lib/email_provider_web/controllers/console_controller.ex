defmodule EmailProviderWeb.ConsoleController do
  @moduledoc """
  The signed-in pages: domains, sending, messages and API keys.

  Each action calls the same context functions the JSON API does, so there is
  one implementation of adding a domain or sending a message rather than a web
  one and an API one that drift apart.
  """
  use EmailProviderWeb, :controller

  alias EmailProvider.{Accounts, Domains, Mail, Warmup}
  alias EmailProviderWeb.Plugs.BrowserAuth

  plug :put_view, html: EmailProviderWeb.ConsoleHTML
  plug :require_user

  # `plug BrowserAuth, :require_user` would pass :require_user as options to
  # call/2 and never run the check, which is exactly what it did: every page
  # loaded with no user and blew up in the context instead of redirecting.
  defp require_user(conn, opts), do: BrowserAuth.require_user(conn, opts)

  # -- domains -------------------------------------------------------------

  def domains(conn, _params) do
    domains =
      conn.assigns.current_user
      |> Domains.list_domains()
      |> Enum.map(&%{name: &1.name, state: &1.state, warmup: Warmup.status(&1)})

    render(conn, :domains, domains: domains)
  end

  def create_domain(conn, params) do
    case Domains.create_domain(conn.assigns.current_user, %{"name" => params["name"] || ""}) do
      {:ok, domain, smtp_password} ->
        conn
        |> put_flash(
          :info,
          "Added #{domain.name}. SMTP password, shown once: #{smtp_password}"
        )
        |> redirect(to: "/domains/#{domain.name}")

      {:error, :domain_limit, message} ->
        conn |> put_flash(:error, message) |> redirect(to: "/domains")

      {:error, changeset} ->
        conn
        |> put_flash(:error, first_error(changeset, "That domain could not be added."))
        |> redirect(to: "/domains")
    end
  end

  def domain(conn, %{"name" => name}) do
    case Domains.get_user_domain(conn.assigns.current_user, name) do
      nil ->
        conn |> put_flash(:error, "No such domain.") |> redirect(to: "/domains")

      domain ->
        render(conn, :domain,
          domain: domain,
          records: Domains.dns_records(domain),
          warmup: Warmup.status(domain)
        )
    end
  end

  def verify_domain(conn, %{"name" => name}) do
    case Domains.get_user_domain(conn.assigns.current_user, name) do
      nil ->
        conn |> put_flash(:error, "No such domain.") |> redirect(to: "/domains")

      domain ->
        {:ok, checked} = Domains.verify_domain(domain)

        conn
        |> flash_for_verify(checked)
        |> redirect(to: "/domains/#{checked.name}")
    end
  end

  defp flash_for_verify(conn, %{state: "active"} = domain) do
    put_flash(conn, :info, "#{domain.name} is verified and can send.")
  end

  defp flash_for_verify(conn, domain) do
    missing =
      [
        is_nil(domain.spf_verified_at) && "SPF",
        is_nil(domain.dkim_verified_at) && "DKIM"
      ]
      |> Enum.filter(& &1)
      |> Enum.join(" and ")

    put_flash(conn, :error, "Still waiting on the #{missing} record. DNS can take hours.")
  end

  # -- sending -------------------------------------------------------------

  def send_form(conn, params) do
    render(conn, :send, sendable: sendable(conn), params: params)
  end

  def send_message(conn, params) do
    user = conn.assigns.current_user

    with %{} = domain <- Domains.get_user_domain(user, params["domain"] || ""),
         {:ok, messages} <- Mail.send_message(user, domain, send_params(params)) do
      conn
      |> put_flash(:info, sent_message(params, messages))
      |> redirect(to: "/messages")
    else
      nil ->
        conn
        |> put_flash(:error, "Choose a domain you own.")
        |> render(:send, sendable: sendable(conn), params: params)

      {:error, _reason, details} ->
        conn
        |> put_flash(:error, explain(details))
        |> render(:send, sendable: sendable(conn), params: params)
    end
  end

  defp send_params(params) do
    base = %{
      "from" => params["from"],
      "to" => params["to"],
      "subject" => params["subject"],
      "text" => params["text"]
    }

    if params["test_mode"] == "yes", do: Map.put(base, "o:testmode", "yes"), else: base
  end

  defp sent_message(%{"test_mode" => "yes"}, _messages),
    do: "Accepted in test mode. Nothing was sent, and no daily allowance was used."

  defp sent_message(_params, messages),
    do: "Queued #{length(messages)} message(s). Delivery outcome appears below."

  # The API answers with a shape; a person needs a sentence.
  defp explain(reason) when is_binary(reason), do: reason
  defp explain(%{message: message}), do: message

  defp explain(%{daily_limit: limit, remaining_today: left}),
    do: "Daily limit reached: #{limit} a day, #{left} left. It resets at midnight UTC."

  defp explain(other), do: inspect(other)

  defp sendable(conn) do
    conn.assigns.current_user
    |> Domains.list_domains()
    |> Enum.filter(&Domains.sendable?/1)
    |> Enum.map(&%{name: &1.name})
  end

  # -- messages ------------------------------------------------------------

  def messages(conn, _params) do
    messages =
      conn.assigns.current_user
      |> Domains.list_domains()
      |> Enum.flat_map(&Mail.list_messages(&1, limit: 25))
      |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
      |> Enum.take(50)

    render(conn, :messages, messages: messages)
  end

  # -- account -------------------------------------------------------------

  def account(conn, _params) do
    # Shown once, then taken out of the session so a reload does not repeat it.
    new_key = get_session(conn, :new_api_key)

    conn
    |> put_session(:new_api_key, nil)
    |> render(:account, keys: Accounts.list_api_keys(conn.assigns.current_user), new_key: new_key)
  end

  def create_key(conn, params) do
    label = if params["label"] in [nil, ""], do: nil, else: params["label"]

    {:ok, _key, plaintext} = Accounts.create_api_key(conn.assigns.current_user, label: label)

    conn
    |> put_session(:new_api_key, plaintext)
    |> redirect(to: "/account")
  end

  def revoke_key(conn, %{"id" => id}) do
    conn.assigns.current_user
    |> Accounts.list_api_keys()
    |> Enum.find(&(&1.id == id))
    |> case do
      nil ->
        put_flash(conn, :error, "No such key.")

      key ->
        with {:ok, _} <- Accounts.revoke_api_key(key), do: put_flash(conn, :info, "Key revoked.")
    end
    |> redirect(to: "/account")
  end

  defp first_error(changeset, fallback) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {message, _opts} -> message end)
    |> Enum.flat_map(fn {field, messages} ->
      Enum.map(messages, &"#{field |> to_string() |> String.capitalize()} #{&1}")
    end)
    |> List.first()
    |> Kernel.||(fallback)
  end
end
