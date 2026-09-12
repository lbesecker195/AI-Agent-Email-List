defmodule EmailProvider.ConfigHelpersTest do
  @moduledoc """
  Config is evaluated before `lib/` compiles, so the helper lives in `config/`
  and is loaded here the same way the config files load it.
  """
  use ExUnit.Case, async: false

  Code.require_file("../config/config_helpers.exs", __DIR__)

  alias EmailProvider.ConfigHelpers

  # System.put_env leaks across tests, so every variable this touches is put
  # back exactly as it was found.
  defp with_env(vars, fun) do
    keys = Map.keys(vars)
    previous = Map.new(keys, &{&1, System.get_env(&1)})

    Enum.each(vars, fn
      {key, nil} -> System.delete_env(key)
      {key, value} -> System.put_env(key, value)
    end)

    try do
      fun.()
    after
      Enum.each(previous, fn
        {key, nil} -> System.delete_env(key)
        {key, value} -> System.put_env(key, value)
      end)
    end
  end

  describe "the .env file" do
    test "parses the usual shapes" do
      parsed =
        ConfigHelpers.parse_dotenv("""
        # a comment
        PLAIN=value

        QUOTED="with spaces"
        SINGLE='also quoted'
        export EXPORTED=yes
        URL=ecto://u:p@host/db?x=1
        EMPTY=
          INDENTED=trimmed
        not a pair
        """)

      assert parsed[:PLAIN] == nil
      map = Map.new(parsed)

      assert map["PLAIN"] == "value"
      assert map["QUOTED"] == "with spaces"
      assert map["SINGLE"] == "also quoted"
      assert map["EXPORTED"] == "yes"
      # An = inside a value is part of the value, not another separator.
      assert map["URL"] == "ecto://u:p@host/db?x=1"
      assert map["EMPTY"] == ""
      assert map["INDENTED"] == "trimmed"
      refute Map.has_key?(map, "not a pair")
      refute Map.has_key?(map, "# a comment")
    end

    test "sets what is missing" do
      path = Path.join(System.tmp_dir!(), "env_#{System.unique_integer([:positive])}")
      File.write!(path, "EP_TEST_FRESH=from_file\n")
      on_exit(fn -> File.rm(path) end)

      with_env(%{"EP_TEST_FRESH" => nil}, fn ->
        ConfigHelpers.load_dotenv!(path)
        assert System.get_env("EP_TEST_FRESH") == "from_file"
        System.delete_env("EP_TEST_FRESH")
      end)
    end

    test "never overrides a real environment variable" do
      path = Path.join(System.tmp_dir!(), "env_#{System.unique_integer([:positive])}")
      File.write!(path, "EP_TEST_SET=from_file\n")
      on_exit(fn -> File.rm(path) end)

      # `DATABASE_URL=... mix test` has to keep meaning what it looks like.
      with_env(%{"EP_TEST_SET" => "from_environment"}, fn ->
        ConfigHelpers.load_dotenv!(path)
        assert System.get_env("EP_TEST_SET") == "from_environment"
      end)
    end

    test "a missing file is not an error" do
      assert ConfigHelpers.load_dotenv!("/nonexistent/.env") == :ok
    end
  end

  describe "DATABASE_URL" do
    test "wins over everything else" do
      with_env(%{"DATABASE_URL" => "ecto://u:p@db.example/other", "PGUSER" => "ignored"}, fn ->
        assert ConfigHelpers.repo_connection("mine") == [url: "ecto://u:p@db.example/other"]
      end)
    end

    test "an empty value is treated as unset" do
      with_env(%{"DATABASE_URL" => "", "PGUSER" => "someone", "PGPASSWORD" => nil}, fn ->
        config = ConfigHelpers.repo_connection("mine")
        assert config[:username] == "someone"
        assert config[:database] == "mine"
      end)
    end
  end

  describe "the database name" do
    test "is never taken from the ambient environment" do
      # PGDATABASE may already be exported on a shared box for another service.
      # Honouring it would point ecto.migrate at that service's database and
      # create this application's tables inside it.
      with_env(%{"DATABASE_URL" => nil, "PGDATABASE" => "someone_elses_production"}, fn ->
        assert ConfigHelpers.repo_connection("email_provider_dev")[:database] ==
                 "email_provider_dev"
      end)
    end
  end

  describe "the username guess" do
    test "prefers PGUSER" do
      with_env(%{"DATABASE_URL" => nil, "PGUSER" => "mailer", "USER" => "root"}, fn ->
        assert ConfigHelpers.repo_connection("db")[:username] == "mailer"
      end)
    end

    test "falls back to the OS user" do
      with_env(%{"DATABASE_URL" => nil, "PGUSER" => nil, "USER" => "logan"}, fn ->
        assert ConfigHelpers.repo_connection("db")[:username] == "logan"
      end)
    end

    test "never guesses root" do
      # There is rarely a Postgres role called root, and the resulting
      # "password authentication failed for user root" reads like a credentials
      # problem when nothing had said which credentials to use.
      with_env(%{"DATABASE_URL" => nil, "PGUSER" => nil, "USER" => "root"}, fn ->
        assert ConfigHelpers.repo_connection("db")[:username] == "postgres"
      end)
    end

    test "falls back to postgres when there is no OS user at all" do
      with_env(%{"DATABASE_URL" => nil, "PGUSER" => nil, "USER" => nil}, fn ->
        assert ConfigHelpers.repo_connection("db")[:username] == "postgres"
      end)
    end
  end

  describe "host and port" do
    test "default to localhost:5432" do
      with_env(%{"DATABASE_URL" => nil, "PGHOST" => nil, "PGPORT" => nil}, fn ->
        config = ConfigHelpers.repo_connection("db")
        assert config[:hostname] == "localhost"
        assert config[:port] == 5432
      end)
    end

    test "come from PGHOST and PGPORT when set" do
      with_env(%{"DATABASE_URL" => nil, "PGHOST" => "db.internal", "PGPORT" => "6432"}, fn ->
        config = ConfigHelpers.repo_connection("db")
        assert config[:hostname] == "db.internal"
        assert config[:port] == 6432
      end)
    end

    test "an empty PGPORT does not crash the boot" do
      with_env(%{"DATABASE_URL" => nil, "PGPORT" => ""}, fn ->
        assert ConfigHelpers.repo_connection("db")[:port] == 5432
      end)
    end
  end
end
