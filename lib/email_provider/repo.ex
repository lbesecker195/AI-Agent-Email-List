defmodule EmailProvider.Repo do
  use Ecto.Repo,
    otp_app: :email_provider,
    adapter: Ecto.Adapters.Postgres
end
