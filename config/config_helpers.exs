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
          database: System.get_env("PGDATABASE") || database
        ]
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
