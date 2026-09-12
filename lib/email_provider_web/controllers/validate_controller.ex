defmodule EmailProviderWeb.ValidateController do
  use EmailProviderWeb, :controller

  alias EmailProvider.Domains
  alias EmailProvider.Mail.Params

  @doc """
  GET /v4/address/validate?address=...

  Syntax, then a live MX lookup on the domain. We do not probe the recipient's
  server with a partial SMTP conversation: it is what makes address validation
  accurate, and it is also indistinguishable from the reconnaissance step of a
  directory harvest. Callers get syntax and deliverable-domain, not
  deliverable-mailbox.
  """
  def validate(conn, %{"address" => address}) do
    valid_syntax = Params.valid_address?(address)
    bare = EmailProvider.Suppressions.extract_address(address)
    domain = bare |> String.split("@") |> List.last()

    mx = if valid_syntax, do: Domains.mx_records(domain), else: []

    risk =
      cond do
        not valid_syntax -> "unknown"
        mx == [] -> "high"
        disposable?(domain) -> "medium"
        true -> "low"
      end

    json(conn, %{
      address: bare,
      is_valid: valid_syntax and mx != [],
      is_disposable_address: disposable?(domain),
      mx_found: mx != [],
      risk: risk,
      reason: reasons(valid_syntax, mx)
    })
  end

  def validate(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{message: "'address' parameter is required"})
  end

  defp reasons(false, _mx), do: ["malformed address"]
  defp reasons(true, []), do: ["domain has no MX records"]
  defp reasons(true, _mx), do: []

  # A starter list. In production this wants a maintained feed rather than a
  # literal, which is why it is one function to replace.
  @disposable ~w(mailinator.com guerrillamail.com 10minutemail.com trashmail.com
                 yopmail.com temp-mail.org throwawaymail.com)
  defp disposable?(domain), do: String.downcase(to_string(domain)) in @disposable
end
