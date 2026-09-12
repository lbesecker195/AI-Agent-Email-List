defmodule EmailProvider.Delivery.DkimTest do
  use EmailProvider.DataCase, async: true

  import EmailProvider.Fixtures

  alias EmailProvider.Delivery.{Dkim, Mime}

  describe "relaxed canonicalization" do
    # The worked example in RFC 6376 section 3.4.5.
    test "body matches the RFC 6376 example" do
      body = " C \r\nD \t E\r\n\r\n\r\n"
      assert Dkim.canonicalize_body(body) == " C\r\nD E\r\n"
    end

    test "an empty body canonicalizes to nothing at all" do
      assert Dkim.canonicalize_body("") == ""
      assert Dkim.canonicalize_body("\r\n\r\n") == ""
    end

    test "every run of whitespace in a line collapses to one space" do
      # RFC 6376 reduces *all* WSP sequences within a line, leading runs
      # included, then drops what is left at the end of the line.
      assert Dkim.canonicalize_body("  hello   world   \r\n") == " hello world\r\n"
    end

    test "folded headers are unfolded and whitespace around the colon is dropped" do
      block = "A: X\r\nB : Y\t\r\n\tZ  "

      assert Dkim.parse_headers(block) == [{"A", "X"}, {"B", "Y Z"}]
    end
  end

  describe "signing" do
    setup do
      domain = domain_fixture(user_fixture())
      %{domain: domain}
    end

    test "produces a header with the tags a verifier needs", %{domain: domain} do
      raw =
        Mime.render(%{
          sender: "a@#{domain.name}",
          recipients: ["b@elsewhere.test"],
          subject: "Hi",
          body_text: "Hello"
        })

      signed = Dkim.sign(raw, domain)

      assert signed =~ "DKIM-Signature: v=1; a=rsa-sha256; c=relaxed/relaxed;"
      assert signed =~ "d=#{domain.name};"
      assert signed =~ "s=#{domain.dkim_selector};"
      assert signed =~ ~r/bh=[A-Za-z0-9+\/=]+;/
      assert signed =~ ~r/b=[A-Za-z0-9+\/=]+/
    end

    test "the body hash is the hash of the canonicalized body", %{domain: domain} do
      raw =
        Mime.render(%{
          sender: "a@#{domain.name}",
          recipients: ["b@elsewhere.test"],
          subject: "Hi",
          body_text: "Hello"
        })

      signed = Dkim.sign(raw, domain)

      {_headers, body} = Dkim.split(raw)
      expected = :crypto.hash(:sha256, Dkim.canonicalize_body(body)) |> Base.encode64()

      assert [_, found] = Regex.run(~r/bh=([A-Za-z0-9+\/=]+);/, signed)
      assert found == expected
    end

    test "the signature verifies against the domain's published public key", %{domain: domain} do
      raw =
        Mime.render(%{
          sender: "a@#{domain.name}",
          recipients: ["b@elsewhere.test"],
          subject: "Hi",
          body_text: "Hello"
        })

      signed = Dkim.sign(raw, domain)

      # Rebuild exactly what a verifier would: the signed headers, then the
      # DKIM-Signature header itself with everything after b= removed.
      [dkim_line | _] = String.split(signed, "\r\n", parts: 2)
      "DKIM-Signature: " <> dkim_value = dkim_line

      [_, signature_b64] = Regex.run(~r/b=([A-Za-z0-9+\/=]+)$/, dkim_value)
      {:ok, signature} = Base.decode64(signature_b64)

      unsigned_value = String.replace(dkim_value, signature_b64, "")
      [_, signed_header_names] = Regex.run(~r/h=([^;]+);/, dkim_value)

      headers = Dkim.parse_headers(elem(Dkim.split(raw), 0))

      signing_input =
        (signed_header_names
         |> String.split(":")
         |> Enum.map(fn name ->
           {_n, value} = Enum.find(headers, fn {n, _v} -> String.downcase(n) == name end)
           name <> ":" <> String.replace(value, ~r/[ \t]+/, " ") <> "\r\n"
         end)
         |> Enum.join()) <> "dkim-signature:" <> unsigned_value

      public_key = public_key_of(domain)

      assert :public_key.verify(signing_input, :sha256, signature, public_key)
    end

    test "a tampered body invalidates the signature", %{domain: domain} do
      raw =
        Mime.render(%{
          sender: "a@#{domain.name}",
          recipients: ["b@elsewhere.test"],
          subject: "Hi",
          body_text: "Hello"
        })

      signed = Dkim.sign(raw, domain)

      {_headers, body} = Dkim.split(signed)
      [_, claimed_bh] = Regex.run(~r/bh=([A-Za-z0-9+\/=]+);/, signed)

      tampered = String.replace(body, "SGVsbG8=", Base.encode64("Goodbye"))
      actual = :crypto.hash(:sha256, Dkim.canonicalize_body(tampered)) |> Base.encode64()

      refute actual == claimed_bh
    end

    test "only headers the message actually has are listed in h=", %{domain: domain} do
      # No Cc on this message, so cc must not appear in the signed header list.
      raw =
        Mime.render(%{
          sender: "a@#{domain.name}",
          recipients: ["b@elsewhere.test"],
          subject: "Hi",
          body_text: "Hello"
        })

      signed = Dkim.sign(raw, domain)

      [_, header_list] = Regex.run(~r/h=([^;]+);/, signed)
      names = String.split(header_list, ":")

      assert "from" in names
      assert "subject" in names
      refute "cc" in names
    end
  end

  defp public_key_of(domain) do
    der = Base.decode64!(domain.dkim_public_der_b64)
    :public_key.der_decode(:SubjectPublicKeyInfo, der) |> spki_to_rsa()
  end

  defp spki_to_rsa({:SubjectPublicKeyInfo, _alg, key_der}) do
    :public_key.der_decode(:RSAPublicKey, key_der)
  end

  defp spki_to_rsa(other) do
    # Newer OTP returns the decoded key directly.
    other
  end
end
