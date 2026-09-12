defmodule EmailProviderWeb.HealthController do
  use EmailProviderWeb, :controller

  @doc "Unauthenticated liveness check. Reports nothing a stranger should not see."
  def show(conn, _params) do
    json(conn, %{status: "ok", time: DateTime.utc_now()})
  end
end
