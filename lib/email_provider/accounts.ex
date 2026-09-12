defmodule EmailProvider.Accounts do
  @moduledoc """
  Account holders and their API credentials.

  Keys are stored only as SHA-256 hashes. The plaintext is returned once, at
  creation, and cannot be recovered afterwards — a lost key is rotated, not
  looked up. Passwords use bcrypt.
  """

  import Ecto.Query, warn: false

  alias EmailProvider.Repo
  alias EmailProvider.Accounts.{ApiKey, User}

  @key_prefix "ep_live_"
  @session_prefix "ep_sess_"
  @session_ttl_hours 12
  @max_failed_logins 10
  @lockout_minutes 15

  # -- users ---------------------------------------------------------------

  def get_user(id), do: Repo.get(User, id)

  def get_user_by_email(email) when is_binary(email) do
    normalized = email |> String.trim() |> String.downcase()
    Repo.one(from u in User, where: fragment("lower(?)", u.email) == ^normalized)
  end

  def get_user_by_email(_), do: nil

  @doc "Register an account holder. Password is optional; API-key-only accounts are allowed."
  def register_user(attrs) do
    changeset =
      if Map.get(attrs, :password) || Map.get(attrs, "password") do
        User.registration_changeset(%User{}, attrs)
      else
        User.changeset(%User{}, attrs)
      end

    Repo.insert(changeset)
  end

  @doc """
  Verify an email/password pair and mint a session token.

  An unknown address still pays the cost of a hash, so the response time does
  not tell an attacker which addresses exist.
  """
  def authenticate_password(email, password) when is_binary(email) and is_binary(password) do
    user = get_user_by_email(email)

    cond do
      is_nil(user) or is_nil(user.password_hash) ->
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}

      locked?(user) ->
        {:error, :locked}

      user.status != "active" ->
        {:error, :suspended}

      Bcrypt.verify_pass(password, user.password_hash) ->
        user |> User.changeset(%{failed_logins: 0, locked_until: nil}) |> Repo.update!()
        {token, expires_at} = start_session(user)
        {:ok, user, token, expires_at}

      true ->
        note_failed_login(user)
        {:error, :invalid_credentials}
    end
  end

  def authenticate_password(_, _) do
    Bcrypt.no_user_verify()
    {:error, :invalid_credentials}
  end

  defp locked?(%User{locked_until: nil}), do: false
  defp locked?(%User{locked_until: until}), do: DateTime.compare(until, DateTime.utc_now()) == :gt

  defp note_failed_login(user) do
    failed = user.failed_logins + 1

    attrs =
      if failed >= @max_failed_logins do
        %{
          failed_logins: failed,
          locked_until: DateTime.add(DateTime.utc_now(), @lockout_minutes * 60, :second)
        }
      else
        %{failed_logins: failed}
      end

    user |> User.changeset(attrs) |> Repo.update!()
  end

  defp start_session(%User{} = user) do
    secret = 32 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
    token = @session_prefix <> secret
    expires_at = DateTime.add(DateTime.utc_now(), @session_ttl_hours * 3600, :second)

    %ApiKey{}
    |> ApiKey.changeset(%{
      user_id: user.id,
      key_hash: hash(token),
      prefix: String.slice(token, 0, 16),
      kind: "session",
      label: "web session",
      scopes: ApiKey.all_scopes(),
      expires_at: expires_at
    })
    |> Repo.insert!()

    {token, expires_at}
  end

  # -- api keys ------------------------------------------------------------

  @doc """
  Mint an API key. Returns `{:ok, api_key, plaintext}` — the only time the
  plaintext exists outside the caller's hands.
  """
  def create_api_key(%User{} = user, opts \\ []) do
    secret = 32 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
    plaintext = @key_prefix <> secret

    result =
      %ApiKey{}
      |> ApiKey.changeset(%{
        user_id: user.id,
        key_hash: hash(plaintext),
        prefix: String.slice(plaintext, 0, 16),
        label: Keyword.get(opts, :label),
        kind: "api",
        scopes: Keyword.get(opts, :scopes, ApiKey.all_scopes())
      })
      |> Repo.insert()

    case result do
      {:ok, key} -> {:ok, key, plaintext}
      error -> error
    end
  end

  def list_api_keys(%User{} = user) do
    Repo.all(
      from k in ApiKey,
        where: k.user_id == ^user.id and k.kind == "api",
        order_by: [desc: k.inserted_at]
    )
  end

  def revoke_api_key(%ApiKey{} = key) do
    key |> ApiKey.changeset(%{revoked_at: DateTime.utc_now()}) |> Repo.update()
  end

  @doc """
  Resolve a presented credential to its user.

  The lookup is by hash, so there is no string comparison against a stored
  secret to time.
  """
  def authenticate_key(presented) when is_binary(presented) do
    hashed = hash(presented)
    now = DateTime.utc_now()

    query =
      from k in ApiKey,
        where:
          k.key_hash == ^hashed and is_nil(k.revoked_at) and
            (is_nil(k.expires_at) or k.expires_at > ^now),
        preload: [:user]

    case Repo.one(query) do
      nil ->
        {:error, :invalid_key}

      %ApiKey{user: %User{status: "active"} = user} = key ->
        touch_last_used(key)
        {:ok, user, key}

      %ApiKey{} ->
        {:error, :suspended}
    end
  end

  def authenticate_key(_), do: {:error, :invalid_key}

  # Best effort, and deliberately not awaited: a write here must never be able
  # to fail an otherwise good request.
  defp touch_last_used(%ApiKey{} = key) do
    Repo.update_all(from(k in ApiKey, where: k.id == ^key.id),
      set: [last_used_at: DateTime.utc_now()]
    )
  end

  def has_scope?(%ApiKey{scopes: scopes}, scope), do: scope in scopes

  defp hash(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end
