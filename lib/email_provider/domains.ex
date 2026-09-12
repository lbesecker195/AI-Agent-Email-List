defmodule EmailProvider.Domains do
  @moduledoc """
  Custom sending domains: registration, the DNS records the customer must
  publish, and verification of those records.

  Adding a domain mints an RSA-2048 DKIM keypair. The private half stays in the
  row and is used to sign outbound mail; the public half is what the customer
  publishes. A domain stays `unverified` — and cannot send — until SPF and DKIM
  are both observed in DNS.
  """

  import Ecto.Query, warn: false
  require Logger

  alias EmailProvider.Repo
  alias EmailProvider.Accounts.User
  alias EmailProvider.Domains.Domain

  @dns_timeout 4_000

  def get_domain(id), do: Repo.get(Domain, id)

  def get_domain_by_name(name) when is_binary(name) do
    normalized = name |> String.trim() |> String.downcase()
    Repo.one(from d in Domain, where: fragment("lower(?)", d.name) == ^normalized)
  end

  def get_user_domain(%User{id: uid}, name) when is_binary(name) do
    normalized = name |> String.trim() |> String.downcase()

    Repo.one(
      from d in Domain,
        where: d.user_id == ^uid and fragment("lower(?)", d.name) == ^normalized
    )
  end

  def list_domains(%User{id: uid}) do
    Repo.all(from d in Domain, where: d.user_id == ^uid, order_by: [asc: d.name])
  end

  @doc "Register a domain and mint its DKIM keypair."
  def create_domain(%User{} = user, attrs) do
    {private_pem, public_b64} = generate_dkim_keypair()

    selector =
      Map.get(attrs, "dkim_selector") || Map.get(attrs, :dkim_selector) || default_selector()

    smtp_password = 24 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
    name = Map.get(attrs, "name") || Map.get(attrs, :name)

    params = %{
      user_id: user.id,
      name: name,
      dkim_selector: selector,
      dkim_private_pem: private_pem,
      dkim_public_der_b64: public_b64,
      smtp_login: if(is_binary(name), do: "postmaster@" <> String.downcase(name)),
      smtp_password_hash: Bcrypt.hash_pwd_salt(smtp_password),
      tracking_opens: truthy(attrs, "tracking_opens", false),
      tracking_clicks: truthy(attrs, "tracking_clicks", false),
      warmup_enabled: truthy(attrs, "warmup_enabled", true)
    }

    case %Domain{} |> Domain.changeset(params) |> Repo.insert() do
      # The SMTP password, like an API key, exists in the clear exactly once.
      {:ok, domain} -> {:ok, domain, smtp_password}
      error -> error
    end
  end

  def update_domain(%Domain{} = domain, attrs) do
    domain
    |> Domain.changeset(Map.take(attrs, ~w(tracking_opens tracking_clicks warmup_enabled state)))
    |> Repo.update()
  end

  def delete_domain(%Domain{} = domain), do: Repo.delete(domain)

  defp truthy(attrs, key, default) do
    case Map.get(attrs, key, Map.get(attrs, String.to_atom(key), default)) do
      v when is_boolean(v) -> v
      "true" -> true
      "yes" -> true
      "false" -> false
      "no" -> false
      _ -> default
    end
  end

  defp default_selector do
    "ep" <> (4 |> :crypto.strong_rand_bytes() |> Base.encode16(case: :lower))
  end

  # -- DKIM keys -----------------------------------------------------------

  @doc """
  Generate an RSA-2048 keypair, returning `{private_pem, public_der_base64}`.

  The public value is the base64 SubjectPublicKeyInfo that goes straight into
  the `p=` tag of the DKIM TXT record.
  """
  def generate_dkim_keypair do
    private = :public_key.generate_key({:rsa, 2048, 65_537})

    private_pem =
      [:public_key.pem_entry_encode(:RSAPrivateKey, private)]
      |> :public_key.pem_encode()

    {:RSAPrivateKey, _v, modulus, exponent, _d, _p, _q, _e1, _e2, _c, _o} = private
    public = {:RSAPublicKey, modulus, exponent}

    public_b64 =
      [:public_key.pem_entry_encode(:SubjectPublicKeyInfo, public)]
      |> :public_key.pem_encode()
      |> strip_pem()

    {private_pem, public_b64}
  end

  defp strip_pem(pem) do
    pem
    |> String.split("\n")
    |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "-----")))
    |> Enum.join()
  end

  @doc "Decode a stored private key PEM into the term `:public_key` signs with."
  def private_key(%Domain{dkim_private_pem: pem}) do
    [entry] = :public_key.pem_decode(pem)
    :public_key.pem_entry_decode(entry)
  end

  # -- the records a customer publishes ------------------------------------

  @doc """
  The DNS records required for this domain, in the shape the API returns them.

  SPF and DKIM are required to send. MX is only needed to receive, so it is
  reported but does not hold up verification.
  """
  def dns_records(%Domain{} = domain) do
    [
      %{
        record_type: "TXT",
        name: domain.name,
        value: "v=spf1 include:#{spf_host()} ~all",
        purpose: "sending",
        required: true,
        valid: state_of(domain.spf_verified_at)
      },
      %{
        record_type: "TXT",
        name: "#{domain.dkim_selector}._domainkey.#{domain.name}",
        value: "v=DKIM1; k=rsa; p=#{domain.dkim_public_der_b64}",
        purpose: "sending",
        required: true,
        valid: state_of(domain.dkim_verified_at)
      },
      %{
        record_type: "MX",
        name: domain.name,
        value: "10 #{mx_host()}",
        purpose: "receiving",
        required: false,
        valid: state_of(domain.mx_verified_at)
      },
      %{
        record_type: "TXT",
        name: "_dmarc.#{domain.name}",
        value: "v=DMARC1; p=none; rua=mailto:dmarc@#{domain.name}",
        purpose: "reporting",
        required: false,
        valid: "unknown"
      }
    ]
  end

  defp state_of(nil), do: "unverified"
  defp state_of(_), do: "valid"

  # -- verification --------------------------------------------------------

  @doc """
  Re-check DNS and update the domain.

  A domain goes `active` once SPF and DKIM both check out, and drops back to
  `unverified` if they stop checking out — a domain whose records were pulled
  should stop sending.
  """
  def verify_domain(%Domain{} = domain) do
    now = DateTime.utc_now()

    spf_ok = spf_present?(domain)
    dkim_ok = dkim_present?(domain)
    mx_ok = mx_present?(domain)

    attrs = %{
      spf_verified_at: stamp(spf_ok, domain.spf_verified_at, now),
      dkim_verified_at: stamp(dkim_ok, domain.dkim_verified_at, now),
      mx_verified_at: stamp(mx_ok, domain.mx_verified_at, now),
      last_checked_at: now,
      state: if(spf_ok and dkim_ok, do: "active", else: "unverified")
    }

    # A domain an operator disabled by hand stays disabled; DNS does not
    # re-enable it.
    attrs = if domain.state == "disabled", do: Map.put(attrs, :state, "disabled"), else: attrs

    domain |> Domain.changeset(attrs) |> Repo.update()
  end

  defp stamp(true, nil, now), do: now
  defp stamp(true, existing, _now), do: existing
  defp stamp(false, _existing, _now), do: nil

  defp spf_present?(%Domain{name: name}) do
    name
    |> txt_records()
    |> Enum.any?(fn txt ->
      String.starts_with?(String.downcase(txt), "v=spf1") and
        String.contains?(String.downcase(txt), String.downcase(spf_host()))
    end)
  end

  defp dkim_present?(%Domain{} = domain) do
    "#{domain.dkim_selector}._domainkey.#{domain.name}"
    |> txt_records()
    |> Enum.any?(fn txt ->
      # Compare the key material itself, not the whole record: operators
      # reorder tags and some DNS UIs re-wrap whitespace.
      normalized = String.replace(txt, ~r/\s+/, "")
      String.contains?(normalized, "p=" <> domain.dkim_public_der_b64)
    end)
  end

  defp mx_present?(%Domain{name: name}) do
    expected = mx_host() |> String.downcase() |> String.trim_trailing(".")

    name
    |> mx_records()
    |> Enum.any?(fn host ->
      host |> String.downcase() |> String.trim_trailing(".") == expected
    end)
  end

  @doc "Every TXT string published at `name`, with multi-chunk records joined."
  def txt_records(name) when is_binary(name) do
    case :inet_res.lookup(String.to_charlist(name), :in, :txt, timeout: @dns_timeout) do
      records when is_list(records) ->
        # A TXT record over 255 bytes arrives as several chunks that must be
        # concatenated before they mean anything — DKIM keys are always split.
        Enum.map(records, fn chunks -> chunks |> Enum.map(&to_string/1) |> Enum.join() end)

      _ ->
        []
    end
  catch
    _kind, reason ->
      Logger.warning("TXT lookup for #{name} failed: #{inspect(reason)}")
      []
  end

  def mx_records(name) when is_binary(name) do
    case :inet_res.lookup(String.to_charlist(name), :in, :mx, timeout: @dns_timeout) do
      records when is_list(records) -> Enum.map(records, fn {_pref, host} -> to_string(host) end)
      _ -> []
    end
  catch
    _kind, reason ->
      Logger.warning("MX lookup for #{name} failed: #{inspect(reason)}")
      []
  end

  @doc """
  Find a domain by its SMTP submission login.

  Logins are issued as `postmaster@<domain>`, so this is a lookup rather than
  a search.
  """
  def get_domain_by_smtp_login(login) when is_binary(login) do
    normalized = login |> String.trim() |> String.downcase()
    Repo.one(from d in Domain, where: fragment("lower(?)", d.smtp_login) == ^normalized)
  end

  def get_domain_by_smtp_login(_), do: nil

  @doc """
  Check a submitted SMTP password against the stored hash.

  A domain with no password set still pays the cost of a hash comparison, so
  the time taken does not say whether the login exists.
  """
  def valid_smtp_password?(%Domain{smtp_password_hash: nil}, _password) do
    Bcrypt.no_user_verify()
    false
  end

  def valid_smtp_password?(%Domain{smtp_password_hash: hash}, password)
      when is_binary(password) do
    Bcrypt.verify_pass(password, hash)
  end

  def valid_smtp_password?(_domain, _password) do
    Bcrypt.no_user_verify()
    false
  end

  @doc "True when this domain is allowed to send right now."
  def sendable?(%Domain{state: "active"}), do: true
  def sendable?(%Domain{}), do: false

  defp config, do: Application.get_env(:email_provider, __MODULE__, [])
  def spf_host, do: Keyword.get(config(), :spf_host, "mail.example.com")
  def mx_host, do: Keyword.get(config(), :mx_host, "mx.example.com")
end
