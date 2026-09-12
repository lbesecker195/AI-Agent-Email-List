defmodule EmailProvider.ConfigHelpers do
  @moduledoc """
  Shared helpers for dev and test configuration.

  Kept out of `lib/` because config is evaluated before the application is
  compiled, and loaded with `Code.require_file/2` from each config file that
  needs it.
  """

  @doc """
  Work out how to reach Postgres, in order of how much the operator told us.

  `DATABASE_URL` wins, because it is the one form that works on every machine
  and is what a deployment already has. Then the standard `PG*` variables. Only
  then a guess, and the guess is careful about one case in particular: it will
  not try the OS user when that user is `root`.

  On a server you are often root, there is rarely a Postgres role called root,
  and the error you get back — "password authentication failed for user root" —
  reads like a credentials problem when it is really nobody having said which
  credentials to use.
  """
  def repo_connection(database) do
    case System.get_env("DATABASE_URL") do
      url when is_binary(url) and url != "" ->
        [url: url]

      _ ->
        [
          username: username(),
          password: System.get_env("PGPASSWORD") || "",
          hostname: System.get_env("PGHOST") || "localhost",
          port: port(),
          # Deliberately NOT read from PGDATABASE.
          #
          # Host, user and password are credentials and are safe to pick up
          # from the environment. The database name is not a credential, it is
          # which application's data this is. PGDATABASE is a standard libpq
          # variable that may already be exported on a shared box for some
          # other service, and honouring it here would point `mix ecto.migrate`
          # at that service's database and create this app's tables inside it.
          #
          # To use a different database, name it in DATABASE_URL, which is an
          # explicit choice rather than an ambient one.
          database: database
        ]
    end
  end

  @doc """
  How many database connections to open.

  Ecto's default of 10 is sized for a laptop where this is the only thing
  running. On a shared box it is ten of somebody else's `max_connections`, and
  a Postgres that runs out answers every client with "sorry, too many clients
  already" — including the applications that were already there. Five is
  plenty for development; `POOL_SIZE` raises it where the capacity exists.
  """
  def pool_size(default \\ 5) do
    case System.get_env("POOL_SIZE") do
      nil -> default
      "" -> default
      value -> String.to_integer(value)
    end
  end

  defp username do
    case System.get_env("PGUSER") || System.get_env("USER") do
      nil -> "postgres"
      "root" -> "postgres"
      user -> user
    end
  end

  defp port do
    case System.get_env("PGPORT") do
      nil -> 5432
      "" -> 5432
      value -> String.to_integer(value)
    end
  end
end
