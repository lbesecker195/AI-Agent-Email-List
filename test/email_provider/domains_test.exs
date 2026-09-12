defmodule EmailProvider.DomainsTest do
  use EmailProvider.DataCase, async: true

  import EmailProvider.Fixtures

  alias EmailProvider.Domains

  describe "registration" do
    test "mints a DKIM keypair that actually signs and verifies" do
      user = user_fixture()

      {:ok, domain, _smtp_password} =
        Domains.create_domain(user, %{"name" => "keys.example.test"})

      private = Domains.private_key(domain)
      {:RSAPrivateKey, _v, modulus, exponent, _d, _p, _q, _e1, _e2, _c, _o} = private
      public = {:RSAPublicKey, modulus, exponent}

      signature = :public_key.sign("some message", :sha256, private)
      assert :public_key.verify("some message", :sha256, signature, public)
    end

    test "the published key is the base64 SubjectPublicKeyInfo DKIM expects" do
      domain = domain_fixture(user_fixture())

      # Every RSA SPKI starts with this prefix; a bare RSAPublicKey would not.
      assert String.starts_with?(domain.dkim_public_der_b64, "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A")
      assert {:ok, _der} = Base.decode64(domain.dkim_public_der_b64)
    end

    test "returns an SMTP password that is stored only as a hash" do
      user = user_fixture()
      {:ok, domain, password} = Domains.create_domain(user, %{"name" => "smtp.example.test"})

      assert is_binary(password)
      refute domain.smtp_password_hash == password
      assert Bcrypt.verify_pass(password, domain.smtp_password_hash)
    end

    test "normalizes the name and refuses nonsense" do
      user = user_fixture()

      {:ok, domain, _} = Domains.create_domain(user, %{"name" => "  MiXeD.Example.Test.  "})
      assert domain.name == "mixed.example.test"

      assert {:error, changeset} = Domains.create_domain(user, %{"name" => "not a domain"})
      assert %{name: [_ | _]} = errors_on(changeset)
    end

    test "the same domain cannot be registered twice" do
      user = user_fixture()
      {:ok, _domain, _} = Domains.create_domain(user, %{"name" => "dupe.example.test"})

      assert {:error, changeset} = Domains.create_domain(user, %{"name" => "DUPE.example.test"})
      assert %{name: [_ | _]} = errors_on(changeset)
    end
  end

  describe "the records a customer publishes" do
    test "names SPF, DKIM, MX and DMARC with the right hosts" do
      domain = domain_fixture(user_fixture(), %{verified: false})
      records = Domains.dns_records(domain)

      spf = Enum.find(records, &(&1.record_type == "TXT" and &1.name == domain.name))
      assert spf.value == "v=spf1 include:mail.test.local ~all"
      assert spf.required

      dkim = Enum.find(records, &String.contains?(&1.name, "_domainkey"))
      assert dkim.name == "#{domain.dkim_selector}._domainkey.#{domain.name}"
      assert dkim.value == "v=DKIM1; k=rsa; p=#{domain.dkim_public_der_b64}"
      assert dkim.required

      mx = Enum.find(records, &(&1.record_type == "MX"))
      assert mx.value == "10 mx.test.local"
      # Only needed to receive, so it must not hold up sending.
      refute mx.required

      dmarc = Enum.find(records, &String.starts_with?(&1.name, "_dmarc."))
      assert dmarc.value =~ "v=DMARC1"
      refute dmarc.required
    end

    test "records report their own verification state" do
      unverified = domain_fixture(user_fixture(), %{verified: false})
      assert Enum.all?(Domains.dns_records(unverified), &(&1.valid in ["unverified", "unknown"]))

      verified = domain_fixture(user_fixture(), %{verified: true})
      spf = Domains.dns_records(verified) |> Enum.find(&(&1.record_type == "TXT"))
      assert spf.valid == "valid"
    end
  end

  describe "verification" do
    test "a domain with no records in DNS does not become active" do
      domain = domain_fixture(user_fixture(), %{verified: false})

      # Nothing is published for a .test domain, so every lookup comes back empty.
      {:ok, checked} = Domains.verify_domain(domain)

      assert checked.state == "unverified"
      assert is_nil(checked.spf_verified_at)
      assert is_nil(checked.dkim_verified_at)
      assert checked.last_checked_at
      refute Domains.sendable?(checked)
    end

    test "a previously verified domain drops back when its records disappear" do
      domain = domain_fixture(user_fixture(), %{verified: true})
      assert Domains.sendable?(domain)

      {:ok, rechecked} = Domains.verify_domain(domain)

      assert rechecked.state == "unverified"
      refute Domains.sendable?(rechecked)
    end

    test "a domain an operator disabled stays disabled whatever DNS says" do
      domain = domain_fixture(user_fixture(), %{verified: true})
      {:ok, disabled} = Domains.update_domain(domain, %{"state" => "disabled"})

      {:ok, rechecked} = Domains.verify_domain(disabled)

      assert rechecked.state == "disabled"
      refute Domains.sendable?(rechecked)
    end

    test "a lookup for a domain that does not resolve returns empty, not an error" do
      assert Domains.txt_records("nothing-here.invalid") == []
      assert Domains.mx_records("nothing-here.invalid") == []
    end
  end

  describe "ownership" do
    test "one account cannot reach another account's domain by name" do
      owner = user_fixture()
      stranger = user_fixture()
      domain = domain_fixture(owner)

      assert Domains.get_user_domain(owner, domain.name)
      refute Domains.get_user_domain(stranger, domain.name)
    end
  end
end
