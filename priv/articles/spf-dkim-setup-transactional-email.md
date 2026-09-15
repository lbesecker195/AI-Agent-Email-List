---
title: "SPF + DKIM Setup for Transactional Email 2026"
description: "Set up SPF records and DKIM for transactional email, with light DMARC. Pair DNS auth with Agent Email List free forever SMTP + Mailgun-shaped API."
date: 2026-09-15
---

If your transactional email is “sending” but landing in spam — or never arriving at all — the first place to look is not your copy. It is **DNS email authentication**: an **SPF record** that authorizes your SMTP server, and a **DKIM setup** that lets mailbox providers verify the signature on every message. In 2026, Gmail, Yahoo, Microsoft, and most corporate filters treat failed or missing auth as a hard signal. This guide walks you through SPF and DKIM for transactional mail, adds only the **light DMARC** you need on day one, and shows how to finish the job on [Agent Email List](https://ai.agentemaillist.com) — a **free forever SMTP server** with a Mailgun-shaped API that issues DNS records and `smtp_password` when you create a domain.

**Ownership disclosure:** Agent Email List (ai.agentemaillist.com) is built and owned by **Logan Besecker**. This is owned-product documentation, not a neutral third-party review. We push our product hard, stay honest about warmup and DNS, and flag competitor details with VERIFY where prices or UIs drift.

**Create a free account forever →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

What you will get from this guide:

- Why transactional email needs SPF and DKIM before you chase volume or templates.
- A full **SPF record** anatomy: `v=spf1`, `include:`, softfail vs fail, and the 10-lookup limit.
- A practical **DKIM setup**: public key in DNS, selectors, rotation basics, and body canonicalization pitfalls.
- Light DMARC only (`p=none` monitoring, rua at a glance) — not an enterprise DMARC program.
- End-to-end setup on Agent Email List: domain create → DNS + one-time `smtp_password` → verify → SMTP send.
- Cloudflare, Route 53, Google/Squarespace Domains, and Namecheap walkthroughs.
- Deep validation and debugging: Received headers, duplicate SPF, wrong selectors, propagation vs misconfig, alignment traps, and migration cutovers.
- A short pointer to the warmup ladder (full playbook lives on the warmup sibling) plus deliverability links.
- Fair comps of how SendGrid, Mailgun, and SES expose DNS — and why free forever still requires real DNS.

Primary keywords throughout: **spf record**, **dkim setup**, with supporting coverage of SPF/DKIM/DMARC bundles and DNS email authentication. Host and port for Agent Email List’s SMTP server come from the product docs or dashboard when published — we do not invent connection strings here.

## Why Transactional Email Needs SPF and DKIM

Transactional mail is the mail your product *must* deliver: password resets, magic links, order receipts, invoice PDFs, security alerts, onboarding tips the user asked for. Unlike a newsletter blast you can reschedule, a failed reset email is a support ticket and a churn risk. Mailbox providers know that, and they also know attackers spoof transactional From domains to phish. The industry answer is **DNS email authentication** — publish who may send (SPF), cryptographically sign what you send (DKIM), and optionally tell receivers what to do when auth fails (DMARC, kept light in this article).

If you are shopping for a **free forever SMTP server** that expects you to do this correctly, start at [Agent Email List](https://ai.agentemaillist.com). Domain create returns the exact TXT records plus `smtp_password` once. SPF and DKIM are required to send; until verify succeeds, the API returns **403 `domain_not_verified`**. That is intentional. Treat DNS as the long pole of onboarding, not polish you skip.

Developers sometimes treat authentication as “ESP paperwork.” It is not paperwork. It is the difference between a message that Gmail can attribute to your brand and a message that looks like every other unverified blast on the internet. Transactional content does not get a free pass: password-reset phrasing is heavily abused by phishers, so filters scrutinize those messages *more*, not less. SPF and DKIM are how you opt into the trusted lane.

### Spoofing and mailbox provider checks

Without SPF and DKIM, anyone who can inject SMTP traffic can put `From: support@yourdomain.com` on a phishing message. Receivers cannot tell that message apart from yours by the From header alone. SPF answers: “Did this message arrive from an IP (or via a relay) that the domain authorizes?” DKIM answers: “Was this message signed with a private key whose public half is published under this domain?” Together they make spoofing hard and legitimate mail easy to trust.

In practice, major providers run authentication checks on nearly every inbound message. A typical path:

1. Resolve the envelope From / Return-Path domain’s SPF TXT.
2. Evaluate mechanisms against the connecting IP (or the responsible hop your ESP aligns for you).
3. Look for a DKIM-Signature header, fetch the selector’s public key from DNS, and verify the signature over the signed headers and body.
4. Optionally evaluate DMARC alignment (whether SPF and/or DKIM domains align with the visible From domain).

Fail any of those in the wrong combination and you get quarantine, reject, or “looks like spam” placement — even when the content is a boring receipt. That is why **spf record** and **dkim setup** searches spike among developers who just flipped a new ESP or SMTP server into production.

Provider enforcement tightened through 2024–2026 for bulk and one-to-one senders alike (VERIFY current Gmail/Yahoo bulk-sender requirements if you also send marketing). Transactional-only apps still feel the downstream effect: shared filtering stacks expect authentication as baseline. Agent Email List’s free forever packaging does not waive this. Shared infrastructure and honest warmup only help if receivers can prove the mail is yours. Publish the records the product gives you; verify until `state: "active"`; then send.

### “Sent but spam” often means auth fail

Developers often debug the wrong layer. Nodemailer returns success. The Mailgun-shaped API returns `200` (queued). The dashboard shows “accepted.” The user still finds the message in Spam — or nowhere. Headers tell the real story: `spf=fail`, `dkim=fail`, `dmarc=fail`, or a missing authentication-results line that implies the provider could not verify you.

Common root causes that look like “spam filters hate us”:

- No SPF TXT at the sending domain apex (or wrong host).
- Two SPF TXT records (invalid — only one SPF record is allowed).
- SPF `include:` that does not cover the ESP you actually use.
- DKIM selector published under the wrong name (`s1._domainkey` vs `default._domainkey`).
- Truncated or line-broken public key in the DNS UI.
- Sending as `app.example.com` while SPF/DKIM only exist on `example.com` (or the reverse).
- Cached old DNS after you fixed the record but did not wait for TTL / re-verify.
- A staging `.env` still pointed at an old SMTP host while DNS was updated for Agent Email List.

None of those are fixed by rewriting subject lines. Fix auth first. On Agent Email List, until DNS verifies, you do not even get to the spam-vs-inbox debate — sends are refused with `domain_not_verified`. After verify, if placement is still weak, move to content, lists, and warmup (see the deliverability and warmup siblings linked later) — still with auth as a green prerequisite.

A useful habit: keep a private “auth canary” inbox (personal Gmail + one Microsoft account). Every time you change DNS, ESP, or From domains, send one canary and archive the Show original output. Five minutes of header literacy saves days of folklore debugging.

### Auth before warmup volume

Warmup raises how many messages you may send per day. Authentication decides whether those messages are trusted. Raising volume on a domain that fails SPF or DKIM trains filters that “this domain sends a lot of unauthenticated mail,” which is the opposite of what you want.

Agent Email List publishes a live ladder in [`/llms.txt`](https://ai.agentemaillist.com/llms.txt): **10 → 20 → 100 → 1,000 → unlimited**/day after graduation. Day one starts at 10 — intentional. The full playbook (rung math, graduation rules, what not to do) belongs to the dedicated warmup guide: [email warmup and unlimited emails per day](/email-warmup-unlimited-emails-per-day/). Here, remember one rule: **do not climb the ladder until SPF and DKIM pass**. Verify the domain, confirm `spf=pass` and `dkim=pass` in Received headers on a real inbox, then send clean transactional traffic up the rungs toward unlimited after warmup.

Pillar context for product choice: [free SMTP relay / Mailgun & SendGrid alternatives](/free-smtp-relay). Sibling on what a relay is: [what is an SMTP relay / free SMTP server](/what-is-smtp-relay-free-smtp-server/). Deliverability deep dive: [email deliverability guide for transactional](/email-deliverability-guide-transactional/).

**CTA:** Create the free forever account, add a domain, and start DNS while you read the rest of this page — [https://ai.agentemaillist.com](https://ai.agentemaillist.com).

## SPF Record Explained

An **SPF record** (Sender Policy Framework) is a DNS TXT record that lists which mail servers are allowed to send mail for a domain. Receivers query that TXT, evaluate the policy against the connecting IP, and return pass, fail, softfail, neutral, or temperror/permerror. For transactional email on a managed SMTP server, you almost always publish an SPF that **includes** your provider rather than listing raw IPs yourself.

On Agent Email List, domain create returns a required SPF TXT that includes `ai.agentemaillist.com` (exact string from the API response — copy/paste; do not hand-type from memory). Publish it at the host the product specifies (often the domain apex or the subdomain you registered). Then call verify.

Think of SPF as an allowlist written in DNS. It does not encrypt mail. It does not prove the body is intact (that is DKIM). It answers a narrow question about authorization of the sending hop relative to the envelope identity. That narrowness is why SPF alone is not enough — and why this guide always pairs **spf record** work with **dkim setup**.

### TXT record anatomy (`v=spf1`)

A minimal mental model:

```
v=spf1 include:ai.agentemaillist.com ~all
```

Pieces:

- **`v=spf1`** — version tag. Must come first. If it is missing or wrong, receivers ignore the record as SPF.
- **Mechanisms** — left to right evaluation: `include:`, `a`, `mx`, `ip4:`, `ip6:`, `exists:`, and a few others. The first match that yields a definitive result can decide the outcome depending on qualifiers.
- **Qualifiers** — default is pass (`+`). Softfail is `~`, fail is `-`, neutral is `?`. So `-all` means “fail everything that did not match earlier,” while `~all` softfails non-matches.
- **`all`** — usually last. It matches everything remaining. Combined with `~` or `-`, it sets the default for unauthorized IPs.

SPF is published as a **TXT** record. Some older docs mention SPF-type records; use TXT. The host/name field is often `@` (apex) in registrar UIs, or blank, or the FQDN depending on the DNS panel. For a subdomain sending domain like `mail.example.com`, the SPF usually lives on `mail.example.com`, not only on `example.com` — match the domain you send as.

Important constraints:

- **Only one SPF TXT per host.** Two `v=spf1` strings at the same name are a permanent error for many evaluators. Merge includes into a single record.
- **Keep it under practical size limits.** DNS TXT has string-length rules; long records should be split into multiple quoted strings in one TXT RRset, not multiple SPF policies.
- **Do not invent mechanisms.** If Agent Email List (or any ESP) gives you an `include:`, use that. Do not add random `ip4:` blocks from blog posts.
- **Order matters less than people think for simple includes**, but put `all` last. Mechanisms after `all` are never evaluated.

Example of a merged record when you also send from Google Workspace on the same apex (illustrative — verify your own vendors):

```
v=spf1 include:_spf.google.com include:ai.agentemaillist.com ~all
```

If you only send transactional mail through Agent Email List on a dedicated subdomain, keep the record to that include plus an `all` terminator. Simpler is safer.

Whitespace and quoting: DNS UIs differ. Some want the TXT value without surrounding quotes; others display quotes that are not part of the data. After save, `dig TXT` should show `v=spf1` at the start of the character-string content. If you see literal escaped quotes wrapping the policy, fix the UI input.

### `include:` vs `ip4:` / `a` / `mx`

**`include:domain`** tells receivers: “Also evaluate the SPF policy published at `domain`, and if that policy passes for this IP, treat it as a pass here.” Your ESP publishes and maintains the downstream policy as their IPs change. That is why every serious transactional provider — including Agent Email List — ships an **spf include mechanism** rather than asking you to chase IP lists.

**`ip4:` / `ip6:`** authorize specific CIDRs. Useful for a static corporate relay you control. Fragile for SaaS ESPs whose pools change. Prefer vendor includes.

**`a`** authorizes IPs that appear in the domain’s A/AAAA records. Convenient for “mail from the same host that serves the website” hobby setups; rarely right for a managed SMTP server on different infrastructure.

**`mx`** authorizes IPs behind the domain’s MX hosts. Tempting if you “receive and send on the same boxes,” but transactional ESPs usually separate receiving MX from sending pools. Authorizing MX does not automatically authorize Agent Email List’s SMTP server.

**`redirect=`** replaces the rest of the policy with another domain’s SPF. Powerful and easy to misuse in migrations. Prefer explicit includes you can read in one place unless you know you need redirect.

For this product path: copy the **include** from `sending_dns_records` on domain create. Do not replace it with `a` or `mx` “because that looked simpler.” Wrong mechanisms produce `spf=fail` even when the rest of your stack is fine.

When people say “we added SPF” but mean “we added a random TXT that mentions the vendor name in a comment,” that does not work. SPF is not free text. It is a tiny language. Stick to the mechanisms above and the exact include Agent Email List returns.

### Softfail `~all` vs fail `-all` for early domains

**`~all` (softfail)** signals “this IP is not authorized, but do not hard-fail yet.” Many onboarding guides and ESP defaults use softfail while you migrate vendors, run parallel systems, or wait for old DNS to expire.

**`-all` (fail)** signals “unauthorized IPs should fail SPF.” Stronger. Better once you know every legitimate sender is listed. Riskier on day one if a forgotten newsletter tool, CRM, or billing provider still sends as your apex.

Practical advice for transactional domains in 2026:

- New subdomain used *only* for Agent Email List transactional mail: starting with `~all` or `-all` both can work if the include is correct; many teams still prefer `~all` until light DMARC reports show no surprise passers. Follow the exact record Agent Email List returns if the product specifies a terminator.
- Shared apex with multiple historical senders: inventory senders first; merge includes; prefer `~all` until you are sure; then tighten.
- Do not use `+all` (pass all). That publishes “anyone may send.” It is worse than no SPF for reputation narratives.
- Do not omit `all`. A policy without a terminator can leave receivers with neutral outcomes that waste the work you put into includes.

SPF alone is not DMARC. Softfail vs fail interacts with DMARC policies later. Keep day-one DMARC at `p=none` while you learn (next major section) so you do not accidentally quarantine yourself.

### Lookup limit (10) and flattening risks

SPF evaluation allows a maximum of **10 DNS-querying mechanisms** per check (`include`, `a`, `mx`, `ptr`, `exists`, and certain `redirect` paths count). Exceeding that yields `permerror` — effectively a broken SPF — which receivers often treat like failure.

How teams blow the limit:

- Nested includes: your record includes ESP A, which includes three more domains, each with `a`/free-smtp-relay`mx` lookups.
- “Just add another include” for every SaaS that can send mail as the company domain.
- Copy-pasting a mega-record from a template that already sat at nine lookups.
- Using `ptr` (discouraged) which burns lookups and is unreliable.

**Flattening** means replacing `include:` chains with the current `ip4:`/free-smtp-relay`ip6:` results so you stay under 10. Tools exist. Risks: ESP IP ranges change; your flattened record goes stale; mail starts failing SPF until you re-flatten. Prefer:

1. Send transactional mail from a **dedicated subdomain** (`mail.example.com` or `tx.example.com`) with a short SPF that only includes Agent Email List.
2. Keep corporate Google/Microsoft includes on the apex if needed, separately.
3. Flatten only when you must, and schedule reviews.
4. Count lookups deliberately when merging vendors during a migration week.

If Agent Email List verify succeeds but some corporate receivers still report SPF permerror, dig the full include tree and count lookups — that debugging path returns under Validation.

**Void lookups** also matter: mechanisms that look up DNS and find nothing can accumulate toward a void-lookup limit and produce permerror. Broken nested includes are not “neutral”; they can brick evaluation. Another reason to prefer a short, vendor-maintained include on a dedicated subdomain.

## DKIM Setup Explained

**DKIM** (DomainKeys Identified Mail) attaches a cryptographic signature to the message. Your SMTP server (or ESP) signs with a private key; you publish the matching public key in DNS under a **selector**; receivers verify that headers and body were not altered in transit (within canonicalization rules) and that the signer controls the domain that published the key.

A correct **dkim setup** is the second required half of Agent Email List domain verification (alongside SPF). The API returns a DKIM TXT in `sending_dns_records` with `required: true`. Publish it exactly; then verify.

If SPF is the allowlist, DKIM is the tamper-evident seal. Receivers that see a valid signature gain confidence that the signed fields are what the domain owner’s signing system produced. That confidence is why ESP onboarding always includes a DKIM DNS step — free forever or paid.

### Public key in DNS, signature on message

Flow:

1. On domain create, the provider mints a keypair for your domain.
2. You publish the public key as a TXT record at a name like `selector._domainkey.yourdomain.com`.
3. When you send, the SMTP server adds a `DKIM-Signature` header listing the selector `s=`, domain `d=`, algorithm, canonicalization, and the signature bytes.
4. The receiver fetches the TXT at `{s}._domainkey.{d}`, extracts `p=` (public key), and verifies.

What you must get right in DNS:

- **Host/name** — often shown as `s1._domainkey` or similar relative to the zone. Do not publish the key at the apex. Do not drop `_domainkey`.
- **Value** — usually starts with `v=DKIM1; k=rsa; p=MIIB...` (format can vary slightly by provider). Paste the full value. If your DNS UI splits long TXT strings, use multiple quoted chunks in **one** record, not two separate DKIM records for the same selector.
- **No extra quotes or truncation** — some panels wrap at 255 octets; follow the panel’s long-TXT instructions. Truncating `p=` guarantees `dkim=fail`.
- **No reformatting** — do not add line breaks inside Base64 for “readability” unless the DNS UI explicitly requires chunking that dig still concatenates correctly.

What you must get right in the message path:

- Send through the provider that holds the private key (Agent Email List’s SMTP server or API after verify).
- Do not strip `DKIM-Signature` in a downstream relay.
- Prefer stable From domains that match the DKIM `d=` alignment you intend.
- Do not resign or “fix” MIME after the ESP signed unless you know you are breaking the hash.

You never paste the private key into DNS. If a UI asks for a private key in a TXT record, you are in the wrong place.

When Agent Email List signs a message, the private key never leaves the service. Your job is DNS publication and using the SMTP server or API as documented — not operating OpenDKIM on a VPS.

### Selector records and rotation basics

A **selector** is a name that lets a domain run multiple DKIM keys at once (`s1`, `s2`, `email`, `ael1`, etc.). The signature’s `s=` tag tells receivers which TXT to fetch.

Why selectors matter:

- **Rotation** — publish a new selector’s public key, switch signing to the new key, keep the old TXT live until in-flight messages settle, then remove the old record.
- **Multi-vendor** — rare on a dedicated transactional subdomain; more common on shared apexes where Google signs with one selector and an ESP with another.
- **Debugging** — wrong selector in DNS is the #1 DKIM failure after truncation. If the product says publish `s1._domainkey` and you create `default._domainkey`, verification fails.

Rotation basics (keep light — no enterprise key ceremony):

1. Add the new selector TXT; wait for propagation.
2. Enable signing with the new selector in the provider (when the product supports rotation; follow live docs).
3. Confirm `dkim=pass` with the new `s=` in headers.
4. Remove the old TXT only after you are sure nothing still signs with it.

On day one with Agent Email List, you typically publish the single selector the API returns and leave it alone. Do not “helpfully” rename the selector in DNS. Do not copy a selector name from a Mailgun or SendGrid tutorial into an Agent Email List domain — selectors are per-keypair, per-product issuance.

If you must run two ESPs during migration, expect two selectors and two public keys. That is normal. What is not normal is overwriting one selector’s TXT with the other vendor’s key while both systems still sign with different private keys.

### Body canonicalization pitfalls (brief)

DKIM signs a canonicalized view of headers and body. Algorithms include `simple` and `relaxed` (often `relaxed/relaxed` in ESP signatures). Pitfalls that break signatures after the ESP signed:

- **MIME gateways** that re-encode bodies, alter line endings, or “fix” HTML.
- **Footer injectors** (virus scanners, compliance disclaimers) that append text after signing.
- **Proxy relays** that rewrite Subject or From.
- **Manual forwards** that change content — expected to fail DKIM; not your transactional path.
- **Ticket systems** that ingest and resend mail as new messages — those are new sends and need their own auth identity.

If raw mail from Agent Email List to Gmail shows `dkim=pass`, but mail that passed through an old corporate relay shows `dkim=fail`, stop chaining relays. Point the app straight at Agent Email List’s SMTP server (host/port from docs/dashboard when published) or the Mailgun-shaped HTTPS API at `https://ai.agentemaillist.com`.

Another pitfall: testing tools that display “DKIM valid” on the public key alone without verifying a live message. Always confirm on a real Received/Authentication-Results header for a message you sent.

Whitespace-only body changes, character-set conversions, and Base64 re-wrapping are classic breakers under `simple` canonicalization and can still surprise you under `relaxed` if intermediaries are aggressive. The fix is architectural: fewer hops after signing.

**CTA #0 (soft):** Add the domain on [Agent Email List](https://ai.agentemaillist.com) so you have real SPF and DKIM values to paste while you follow the DNS walkthroughs below.

## Light DMARC Only (What You Need on Day One)

DMARC ties SPF and DKIM to the visible From domain and tells receivers what to do on failure. This article stays **light**: enough to publish a monitoring policy and understand reports — not an enterprise DMARC program, not BIMI, not a year-long rua analysis practice. If you need a full DMARC program, hire that specialty separately; transactional onboarding does not require it on day one.

A minimal monitoring record at the organizational domain (example):

```
v=DMARC1; p=none; rua=mailto:dmarc-reports@yourdomain.com;
```

Publish as TXT at `_dmarc.yourdomain.com`. Exact rua mailbox is yours to choose and monitor.

Light DMARC exists to answer: “Is anyone sending as us, and do our legitimate paths align?” It is not a substitute for SPF/DKIM correctness. On Agent Email List, SPF+DKIM verification is what unlocks sending; DMARC is complementary hygiene.

### `p=none` monitoring vs quarantine/reject

- **`p=none`** — monitor only. Receivers still authenticate and may send aggregate reports; they should not quarantine/reject solely from DMARC policy. Ideal for day one while you confirm SPF/DKIM alignment.
- **`p=quarantine`** — ask receivers to treat failures as suspicious (often spam folder).
- **`p=reject`** — ask receivers to reject failures at SMTP time.

For a brand-new Agent Email List sending subdomain with clean SPF/DKIM and no other senders, some teams move faster — but the safe default remains **`p=none`** until you have seen clean authentication on production mail. Light DMARC means: publish `p=none`, optionally with rua, and revisit later. It does not mean ignoring DMARC forever; it means not weaponizing `p=reject` before you understand your sender inventory.

Optional tags you might see (`adkim`, `aspf`, `pct`) matter more as you harden policy. On day one, skip tuning them unless you already know your alignment mode. Keep the record readable.

### rua reporting at a glance

**`rua`** is the mailbox for aggregate XML reports. Providers (Google, Microsoft, Yahoo, and others) periodically send summaries of how much mail passed/failed SPF/DKIM/DMARC for your domain. At a glance:

- You need a mailbox that can receive automated mail (and ideally filter it).
- Reports are aggregate, not real-time forensic feeds (ruf is a different, often noisier story — skip it on day one).
- Parsing can be manual or via a simple tool; you do not need a SOC workflow to benefit from “who is sending as us?”
- If rua is wrong or unmonitored, DMARC still authenticates; you just lose visibility.
- External rua destinations sometimes need a DNS authorization record confirming you allow that receiver to collect reports — follow your report inbox provider’s docs if applicable.

On day one, either omit rua until you have a mailbox ready, or set rua to a dedicated address you will actually read weekly. Do not block transactional launch on building a report pipeline.

### When NOT to jump to `p=reject`

Do **not** jump to `p=reject` when:

- You still have unknown senders on the apex (old CRMs, HR tools, “that agency”).
- SPF/DKIM only exist on a subdomain but marketing still sends as the apex without auth.
- You flattened SPF incorrectly last month and sometimes permerror.
- Legal/compliance has not agreed that reject is acceptable for false positives.
- You have zero rua history and no Authentication-Results samples from real inboxes.
- A migration week still dual-sends from two ESPs with imperfect alignment.

Jumping to reject is how companies brick invoices and password resets. Stay on `p=none` until auth is boringly green. This section intentionally ends here — no BIMI, no DMARC vendors, no enterprise rollout program.

## End-to-End Setup with Agent Email List

This is the happy path from zero to authenticated transactional send on a **free forever SMTP server** with a Mailgun-shaped API. Base URL: [https://ai.agentemaillist.com](https://ai.agentemaillist.com). Live agent docs: [`/llms.txt`](https://ai.agentemaillist.com/llms.txt). **Logan Besecker** owns and runs the product.

You will: create an account, add a domain, store secrets that appear once, publish DNS, verify, then send through the SMTP server or Mailgun-shaped API. DNS is the only step that routinely needs a human with registrar access — start it first.

### Add domain; receive DNS records from product

1. Create an account: `POST /v1/accounts` with email and password. Store the one-time `api_key` (hash only is kept server-side; it cannot be resent). Prefer minting narrower keys later with `POST /v1/api-keys` if you split duties across services.
2. Add a domain:

```bash
curl -X POST https://ai.agentemaillist.com/v3/domains \
  --user 'api:KEY' \
  -d 'name=mail.yourcompany.com'
```

3. Read the response: `sending_dns_records` plus **`smtp_password`**. Required records typically include:
   - SPF TXT including `ai.agentemaillist.com`
   - DKIM TXT with the public key at the given selector
   - MX pointing at `ai.agentemaillist.com` — **optional**, only for inbound receive; not required to send

Hand the required records to whoever controls DNS. Format them for paste (host, type TXT, value). Do not improvise hostnames. If you are an agent setting this up for a human, say plainly that DNS needs a person with zone access and give them a copy-paste table.

Prefer a dedicated subdomain for transactional mail so SPF stays short and you do not fight the corporate apex inventory on day one. `mail.example.com` or `tx.example.com` are conventional. Match the From addresses your app will use.

### `smtp_password` issued once on domain create

**`smtp_password` is shown once** when you create the domain. Treat it like a password-reset secret:

- Store it in your secrets manager immediately.
- Map it into Nodemailer, Laravel `MAIL_PASSWORD`, Django, or your worker env.
- If you lose it, follow live product docs for rotation/recovery — do not assume the create response can be replayed.
- Do not commit it to git, chat logs, or screenshots in tickets.

Agent Email List **is an SMTP server / free SMTP relay** for developers: after the domain is verified, you authenticate to the product’s SMTP server with those credentials. **Connection host and port come from the product docs or dashboard when published** — this article does not invent hostname or port numbers. You can also send via the Mailgun-shaped REST API at `https://ai.agentemaillist.com` with Bearer or Basic `api:KEY`.

Many teams use SMTP for legacy apps and the API for new workers. Both require the same DNS auth on the domain. Neither bypasses verify.

### Publish SPF/DKIM; wait TTL; verify in dashboard

1. Create the TXT records exactly as returned (SPF + DKIM).
2. Wait for DNS propagation. TTLs of 300–3600 seconds are common; some registrars force higher minimums.
3. Call verify:

```bash
curl -X PUT https://ai.agentemaillist.com/v3/domains/mail.yourcompany.com/verify \
  --user 'api:KEY'
```

- `200` with `state: "active"` — you can send.
- `202` — records not visible yet; poll every few minutes, not every few seconds.
- If still unverified after an hour, compare `GET /v3/domains/:domain` expected records against live DNS (`dig TXT …`).

A domain whose required records later disappear can drop back to unverified and stop sending — deliberate. Keep the TXT records in place for the life of the sending domain.

Until active, every send returns **403 `domain_not_verified`**. Retrying the send without fixing DNS will not help. That error is your friend: it prevents you from warming a domain that receivers cannot authenticate.

### SMTP server send test; host/port from docs/dashboard when published

Once active:

1. Read SMTP connection settings from the **product docs or dashboard when published** (host, port, TLS mode). Do not copy random hostnames from third-party blogs.
2. Configure your app with the domain’s SMTP user/password model as documented, using the one-time `smtp_password` you saved.
3. Send a test to an inbox you control (Gmail/Microsoft personal or work).
4. Optionally send via API with `o:testmode=yes` first to validate payloads without spending warmup allowance or touching reputation; then send for real.
5. Open the message source and confirm Authentication-Results show **spf=pass** and **dkim=pass**.

If you prefer HTTP, a Mailgun-shaped send looks like `POST /v3/:domain/messages` with Basic `api:KEY`. Most Mailgun clients work if pointed at `https://ai.agentemaillist.com`. DNS requirements remain identical.

<!-- CTA #1 -->
**Create your free forever account and authenticate a domain now →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

You are on a free forever self-serve SMTP server path: Mailgun-shaped API included, unlimited emails/day after warmup (short ladder reminder later), owned by Logan Besecker. Commercial terms can evolve — check live docs — but live product docs today do not require a paid plan to send.

## Provider-Specific DNS Walkthroughs

UIs differ; the records do not. Always paste **Agent Email List’s** returned host and value. The notes below are generic operator guidance for common DNS hosts as of 2026 — VERIFY button labels on your panel if the vendor redesigned.

Before any provider steps: confirm which nameservers are authoritative (`dig NS example.com`). Editing DNS at a registrar while the zone is delegated to Cloudflare (or vice versa) is the most common “I saved it but dig is unchanged” failure.

### Cloudflare

1. Log in → select the zone (example.com).
2. DNS → Records → Add record.
3. For SPF: Type **TXT**, Name `@` or `mail` (match the sending domain), Content = full `v=spf1 …` string, Proxy status **DNS only** (TXT is not proxied like A records; leave default).
4. For DKIM: Type **TXT**, Name `selector._domainkey` or `selector._domainkey.mail` as required, Content = full DKIM value. If Cloudflare warns about length, use its TXT splitting behavior — still one logical record.
5. Save. Optional: set lower TTL while testing (Auto/300).
6. Run verify on Agent Email List. Use `dig TXT mail.example.com @1.1.1.1` to see Cloudflare’s view.

Cloudflare pitfalls: editing the wrong zone; putting DKIM on the apex; creating two SPF TXT records when one already existed for Google; pasting SPF into a Cloudflare “Email” product wizard that creates a second policy; team members with read-only access who thought they saved. API-driven Cloudflare users should still GET the record after PUT to confirm the full DKIM `p=` survived.

If you use Cloudflare for SaaS / custom hostnames for your app, that path is unrelated to these TXT records — do not mix those CNAME patterns into DKIM unless Agent Email List explicitly returns a CNAME (live records are the source of truth).

### Route 53

1. Open Hosted zones → your domain.
2. Create record → Record type TXT.
3. Record name: blank for apex SPF, or `mail`, or `s1._domainkey.mail` per product instructions.
4. Value: quote the string if the console requires quotes for TXT. For long DKIM keys, use multiple quoted strings on one record.
5. Routing policy Simple; TTL 300 while testing.
6. Save and verify in Agent Email List.

Route 53 pitfalls: leaving extra quotes that become part of the character data; creating a second TXT at the same name that is another `v=spf1` instead of merging; confusing Alias records with TXT; editing a public hosted zone that is not the one delegated from the registrar; IAM users lacking `ChangeResourceRecordSets` who see a soft UI failure.

CLI users: `aws route53 change-resource-record-sets` is fine — still dig afterward. Prefer upsert carefully so you do not delete unrelated TXT records (verification tokens, ACME challenges) at the same name when merging SPF.

### Google Domains / Squarespace Domains

Google Domains customers were migrated to Squarespace Domains (VERIFY your account host). Typical path:

1. Log in to the domain manager → DNS → Custom records.
2. Add TXT for SPF at `@` or the subdomain host.
3. Add TXT for DKIM at the selector host.
4. Save; wait; verify.

Pitfalls: UI that silently truncates long values — after save, reopen the record and confirm the full `p=` remains; duplicate SPF from an old “email forwarding” wizard; managing DNS at Squarespace while nameservers still point elsewhere (changes will not go live); mobile web UI paste buffers cutting Base64.

If Squarespace email forwarding or Google Workspace was enabled earlier, inventory existing TXT records before adding Agent Email List’s SPF. Merge; do not stack a second `v=spf1`.

### Namecheap / generic registrars

1. Domain List → Manage → Advanced DNS (if nameservers are Namecheap BasicDNS/PremiumDNS).
2. Add TXT Record: Host `@` or subdomain; Value SPF string.
3. Add TXT Record: Host `s1._domainkey` (example); Value DKIM string.
4. If you use external nameservers (Cloudflare, Route 53), **do not** edit Namecheap’s DNS — edit the real authoritative DNS.

Generic registrar pitfalls: “Host” field semantics (`@` vs blank vs FQDN); email wizards that auto-add a second SPF; 30-minute minimum TTL; mobile apps that mangle long paste buffers — paste from a desktop when possible; “DNS is propagating” banners that hide a nameserver mismatch.

Other panels (GoDaddy, Hover, DNSimple, NS1, Bunny DNS, porkbun, etc.) follow the same physics: one SPF policy per host, exact DKIM selector name, full `p=`, authoritative nameservers. When in doubt, dig against the NS hosts listed for the domain, not only against `8.8.8.8`.

After any provider change: wait at least one TTL, query public resolvers, then `PUT …/verify` on Agent Email List.

## Validation and Debugging

This section is where most “we published it but it still fails” time goes. Work methodically: DNS truth → product verify → live message headers → classify error class. Expand your patience here; it is cheaper than rewriting templates for a DNS typo.

### Reading Received headers for spf=pass dkim=pass

Send a real message to Gmail or Microsoft 365. Open **Show original** / **View message source**. Find `Authentication-Results` (or `ARC-Authentication-Results`). You want something in the spirit of:

```
spf=pass (sender IP is authorized)
dkim=pass header.d=mail.yourcompany.com header.s=s1
dmarc=pass (or none policy with pass auth)
```

Also check:

- **`Received-SPF: pass`** on some paths.
- DKIM `d=` and From domain alignment if you care about DMARC.
- That the From domain is the domain you verified (or a subdomain relationship allowed by the product — on Agent Email List, `from` must be at the path domain or a subdomain of it).
- The `DKIM-Signature` header itself: `s=` selector should match the DNS name you published; `d=` should be your sending domain identity.

If the API/SMTP path accepted the message but headers show fail, you are past “cannot send” and into “auth mispublished or rewritten.” If Agent Email List still returns `domain_not_verified`, stop reading spam folklore and fix DNS/verify first.

Collect three artifacts for any ticket or self-debug note:

1. `dig TXT` / `dig TXT selector._domainkey…` output from a public resolver.
2. The exact `sending_dns_records` from `GET /v3/domains/:domain`.
3. The Authentication-Results block from the test message.

Optional fourth artifact: a redacted SMTP transcript or API response code. Do not paste live `smtp_password` or API keys into shared tickets.

Gmail’s “SPF: PASS” / “DKIM: PASS” summary at the top of Show original is helpful, but still scroll to the raw Authentication-Results when diagnosing partial failures (pass SPF / fail DKIM, etc.).

### Common errors (duplicate SPF, wrong selector)

**Duplicate SPF records.** Two TXT records at the same host both starting `v=spf1`. Fix: merge into one; delete the extra. Symptoms: SPF permerror; verify may fail; receivers fail closed. This is the single most common corporate-apex mistake.

**Wrong SPF include.** Old Mailgun/SendGrid include left in place, Agent Email List include missing (or the reverse during migration). Fix: inventory senders; publish the includes you need in **one** record; remove dead vendors.

**Wrong DKIM selector / host.** Published `default._domainkey` when asked for `s1._domainkey`, or published under `example.com` when sending domain is `mail.example.com`. Fix: match the product record name exactly.

**Truncated DKIM `p=`.** Copy/paste cut mid-Base64. Fix: re-copy from API; confirm length; re-save; wait TTL; re-verify; resend test. Compare character length against the API value.

**SPF on wrong host.** Apex has SPF; you send as `mail.example.com` with no SPF there. Fix: publish SPF on the sending domain host.

**DKIM value includes UI quotes.** Literal `"` characters stored inside the TXT data. Fix: follow provider docs for TXT quoting — quotes are often syntax, not payload.

**Multiple DKIM TXT for same selector with different keys.** Stale key + new key at identical name. Fix: one TXT RRset for that selector; remove stale values.

**IPv6 vs IPv4 confusion.** Rare on managed ESP includes if you use `include:`; more common with hand-built `ip4:` lists. Prefer vendor include.

**Macro/exists toys.** Do not add clever SPF macros because a blog suggested them. Keep ESP include + all.

**CDN/DNS “DNSSEC” or DNS filters.** Unusual, but broken DNSSEC or firewall DNS can make keys invisible to some resolvers. Check from multiple public resolvers (`1.1.1.1`, `8.8.8.8`).

**Sending before verify.** Symptom: 403 `domain_not_verified`. Not a header problem.

**Content screening vs auth.** Agent Email List may return **403 `content_rejected`** — that is not SPF/DKIM. Do not rotate DNS to fix content refusals.

**Warmup 429 vs auth.** Over daily cap returns **429** with `retry_after_seconds`. Unrelated to SPF. See the [warmup guide](/email-warmup-unlimited-emails-per-day/).

**Forbidden sender.** **403 `forbidden_sender`** means your From address is not on the verified domain path — fix From, not DKIM TXT.

**Nameserver mismatch.** Edits at the registrar while Cloudflare is authoritative. dig against NS hosts to see truth.

**TTL stubbornness.** You fixed the record, dig still shows old data for some resolvers. Wait; flush local caches; dig `@ns-xxx` authoritative.

**Unicode lookalikes.** Rare, but pasting from rich text can introduce non-ASCII lookalike characters into TXT values. Stick to plain ASCII from the API JSON.

**Trailing dots in UI host fields.** Some panels want `s1._domainkey.mail` and others `s1._domainkey.mail.example.com.` — double-check relative vs absolute name rules for your DNS host so you do not create `s1._domainkey.mail.example.com.example.com`.

### Propagation vs product misconfig

Debug decision tree:

1. **Does public DNS show the exact strings the product expects?**  
   If no → DNS edit/propagation problem (wrong account, wrong host, truncation, TTL).  
   If yes → continue.

2. **Does `PUT …/verify` return active?**  
   If no while DNS looks right → wait for all resolvers; check trailing dots/spaces; confirm you are verifying the same domain name you edited; re-fetch expected records from the API.  
   If yes → continue.

3. **Can you send without `domain_not_verified`?**  
   If no → still a product-side domain state issue; re-check verify state.  
   If yes → continue.

4. **Do headers show spf=pass dkim=pass?**  
   If no → compare include/selector again; check for intermediate relays rewriting mail; confirm you are sending through Agent Email List, not a leftover host in `.env`.  
   If yes → auth is done; any remaining placement issues are deliverability/reputation/content/list quality — see [deliverability guide](/email-deliverability-guide-transactional/).

Propagation tips:

- Lower TTL **before** a planned cutover when you can.
- After a fix, dig against authoritative nameservers and against recursive resolvers — they can disagree temporarily.
- Do not hammer verify every second; a few minutes between attempts is enough.
- Mobile captive portals and corporate DNS caches can lie; test from a clean network.
- Document the UTC timestamp of each DNS change so you know when TTL should have expired.

Local dig examples (replace names):

```bash
dig NS yourcompany.com +short
dig TXT mail.yourcompany.com +short
dig TXT s1._domainkey.mail.yourcompany.com +short
dig TXT mail.yourcompany.com @1.1.1.1 +short
dig TXT mail.yourcompany.com @8.8.8.8 +short
```

If dig is green and verify is green but Nodemailer still points at `smtp.sendgrid.net`, you are authenticating the wrong pipeline — fix env vars. Auth is per sending path.

### Extra troubleshooting: alignment, subdomains, and migrations

**Alignment (light).** DMARC cares whether SPF’s authenticated domain and/or DKIM’s `d=` align with the From header domain. Using a dedicated `mail.example.com` From with SPF/DKIM on that same host keeps alignment simple. Mixing `From: support@example.com` while only `mail.example.com` is authenticated invites DMARC fails even when SPF/DKIM “pass” for the wrong domain identity.

**Subdomain vs organizational domain.** Publishing DMARC only on `example.com` can apply to subdomains depending on policy flags; keep day-one DMARC light and consistent with where you send. When unsure, put monitoring DMARC on the same organizational domain your users see in From, and keep transactional sending on an authenticated subdomain with matched From addresses.

**Migrating from Mailgun/SendGrid/SES.** Run parallel auth carefully:

1. Create domain on Agent Email List; publish AEL SPF include **merged** with old include if both must send during migration; or use a new subdomain and switch From addresses cleanly.
2. Publish AEL DKIM selector alongside old selectors (different selector names — fine).
3. Verify AEL; send tests; flip app env to AEL SMTP/API.
4. Remove old includes/selectors only when traffic stops.

**Staging vs production domains.** Use a staging subdomain with its own DNS and its own warmup clock. Do not share production auth identity with load-test junk if you can avoid it. Test mode (`o:testmode=yes`) on the API helps you validate payloads without spending allowance.

**Inbound MX vs outbound auth.** MX is optional for send on Agent Email List. Missing MX does not cause `domain_not_verified`. Do not debug SPF by changing MX.

**Time skew and DKIM.** Extreme clock skew can affect signature validation in edge systems; keep NTP healthy on self-hosted MTAs. On Agent Email List’s managed SMTP server this is rarely your problem — another reason managed beats a random VPS relay.

**Header sprawl.** Some “email optimization” middleware adds unsigned headers that are fine, or rewrites signed ones that are not. If only messages through middleware fail DKIM, strip the middleware from the transactional path.

### Deep dive: interpreting mixed Authentication-Results

Not every failure is total.

- **spf=pass, dkim=fail** — DNS key problem, wrong selector, truncation, or body/header rewritten after signing. Trust dig + selector first; then hunt middleware.
- **spf=fail, dkim=pass** — often wrong/missing SPF include, duplicate SPF permerror treated as fail, or envelope domain mismatch. DKIM may still save DMARC if alignment holds and policy allows.
- **spf=pass, dkim=pass, dmarc=fail** — classic alignment miss (From domain does not align). Fix From or publish auth on the From host.
- **temperror / permerror** — DNS timeouts or policy syntax/lookup limits. Retry temperror; fix records on permerror.
- **none** — no policy or no signature found. Missing DKIM header means you did not send through the signing SMTP server you think you did.

ARC results on forwarded mail can show preserved authentication through intermediaries. For app transactional mail, prefer direct injection to Agent Email List so you do not need ARC to explain your life.

### Deep dive: dig, whois-adjacent checks, and “split horizon” DNS

Internal corporate DNS sometimes returns different TXT records than the public internet (split horizon). Your laptop on VPN might see a perfect SPF while Gmail’s resolvers see nothing — or see an old duplicate. Always validate with public resolvers and with the domain’s authoritative NS hosts.

Checklist:

1. `dig NS` → note authoritative servers.
2. Query TXT on those NS hosts directly.
3. Query TXT on 1.1.1.1 and 8.8.8.8.
4. If they disagree, wait for TTL or fix the zone you actually edited.
5. Only then call Agent Email List verify again.

Do not use random “SPF checkers” as the only source of truth — many still cache, or evaluate the wrong host. They can be helpful screenshots; dig remains the ground truth.

### Deep dive: ESP include trees and unexpected permerror

When verify is green on Agent Email List but a subset of corporate receivers bounce with SPF permerror, map the include tree:

- Write down your published policy.
- For each `include:`, fetch that domain’s SPF.
- Count DNS-querying mechanisms across the evaluation, not just top-level tokens.
- Watch for broken nested includes (include target missing or syntax-broken).

Mitigations: dedicated subdomain with only `include:ai.agentemaillist.com`, remove dead vendors, avoid stacking five CRMs on the same apex. Flattening is a last resort with a calendar reminder to refresh.

### Deep dive: selector archaeology during migrations

During Mailgun → Agent Email List or SendGrid → Agent Email List moves, teams often leave old DKIM CNAMEs/TXTs in place (good) but accidentally overwrite the new selector (bad), or delete old selectors while the old ESP still sends (also bad). Maintain a simple table:

| Vendor | Selector | DNS host | Status |
|--------|----------|----------|--------|
| Old ESP | s1 | s1._domainkey.mail | draining |
| Agent Email List | (from API) | (from API) | active |

Update the table when DNS changes. Retire rows only when traffic graphs hit zero.

### Deep dive: application-layer mistakes that look like DNS bugs

- **Wrong env in Kubernetes.** Staging secret mounted into production pods.
- **Multiple mailers.** App sends receipts via AEL but password resets via legacy SES with incomplete DNS.
- **Display-name only changes.** You changed the friendly name but From domain still wrong.
- **CC/BCC tools** that resend via user’s mailbox (breaks DKIM chain) instead of via API.
- **“Smart” email deliverability SaaS** sitting as an outbound proxy you forgot about.

When headers show an unexpected `Received:` hop before the provider you expect, chase that hop before editing TXT records again.

## Alignment with Warmup and Deliverability

Auth is the gate; warmup is the volume governor; deliverability is the ongoing practice. Keep them in that order.

### Don’t raise volume before auth passes

Checklist before you increase sends:

- Domain `state: "active"` on Agent Email List.
- Live test message shows **spf=pass** and **dkim=pass**.
- From addresses match the verified domain rules.
- Suppressions honored; no purchased lists on transactional infrastructure.
- Test mode used for payload shaping so you do not burn the day-1 cap on typos.
- Canary inboxes still green after the last DNS edit.

If auth is red, volume only teaches filters the wrong lesson. If auth is green, you still need clean lists and predictable transactional content — but you are no longer fighting with both hands tied.

### AEL ladder (short) — full playbook on the warmup sibling

Live ladder from [`/llms.txt`](https://ai.agentemaillist.com/llms.txt): **10 → 20 → 100 → 1,000 → unlimited**/day. Destination: **unlimited emails/day after warmup** on a free forever account. Day one is 10 by design. Check `GET /v3/:domain/limits` for the rung you are on.

That is all the ladder detail this article needs. For graduation rules, idle-day pitfalls, blast planning against `remaining_today`, and anti-patterns (multi-domain evasion, etc.), use the full playbook: **[Email warmup: unlimited emails per day](/email-warmup-unlimited-emails-per-day/)**. Do not treat this SPF/DKIM page as a second warmup essay.

### Link deliverability + warmup silos

- Warmup depth: [/email-warmup-unlimited-emails-per-day](/email-warmup-unlimited-emails-per-day/)
- Deliverability practices: [/email-deliverability-guide-transactional](/email-deliverability-guide-transactional/)
- SMTP relay concepts: [/what-is-smtp-relay-free-smtp-server](/what-is-smtp-relay-free-smtp-server/)
- Product pillar (free forever SMTP + Mailgun/SendGrid alternatives): [Agent Email List home](/free-smtp-relay)

Ship auth → climb warmup with clean transactional traffic → apply deliverability hygiene. Agent Email List’s free forever SMTP server + Mailgun-shaped API is built for that sequence.

## Fair Comps: How ESPs Expose DNS Setup

Every serious ESP requires SPF and DKIM. The UX differs; the DNS physics do not. VERIFY current vendor UIs and prices on primary docs — panels change.

### SendGrid / Mailgun DNS UIs (VERIFY current)

**SendGrid** (VERIFY app.sendgrid.com / docs): typically walks you through domain authentication with CNAMEs for DKIM (and related links) and SPF guidance via include. Post-2025 packaging often emphasizes trial-then-paid for new accounts rather than permanent free (VERIFY SendGrid pricing; Essentials often cited around ~$19.95/mo depending on tier). DNS still must be real before reliable production mail.

**Mailgun** (VERIFY mailgun.com docs): domain wizard shows SPF include TXT and DKIM records (TXT or CNAME patterns depending on setup era). Mailgun has continued to advertise a permanent free plan around ~100 emails/day and paid plans such as Basic around ~$15/mo for 10k (VERIFY [mailgun.com/pricing](https://www.mailgun.com/pricing/)). Auth UX is mature; free-tier volume and log retention are separate constraints from DNS.

Both prove the point: brand-name ESPs do not skip DNS. Neither does Agent Email List. If you are leaving either vendor, expect to publish new records (or merge includes) — authentication does not automatically “move” with your API key.

### SES Easy DKIM vs BYO (VERIFY)

**Amazon SES** (VERIFY AWS docs): offers Easy DKIM (SES-managed signing with DNS records you publish) and Bring-Your-Own DKIM in supported configurations. SPF is still your responsibility via appropriate records for your MAIL FROM / custom MAIL FROM setup. SES unit pricing is often cited near ~$0.10/1k à-la-carte in many regions, with newer accounts sometimes defaulting to Essentials-style pricing around ~$0.16/1k until you opt into à-la-carte (VERIFY AWS pricing pages — figures drift). Sandbox mode and IAM complexity are separate from DNS but often dominate onboarding time.

SES can be excellent at scale inside AWS. It still does not remove the need for correct SPF/DKIM. For fast Mailgun-shaped DX plus free forever packaging, many developers prototype on Agent Email List first.

### Why free forever AEL still requires real DNS

Free forever is about commercial packaging — not about skipping authentication. Shared sending infrastructure is a shared trust pool. Agent Email List requires SPF+DKIM so that:

- Receivers can authenticate your domain.
- Abuse is harder to hide behind unverified From domains.
- Your warmup reputation accrues to a real, verified identity.

You get: free forever self-serve signup, SMTP credentials (`smtp_password`) once on domain create, Mailgun-shaped API, published path to unlimited/day after warmup, and explicit verify gates. You do not get: fake “verified” badges without TXT records.

<!-- CTA #2 -->
**Authenticate on the free forever SMTP server →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

Fair secondary mentions: Brevo and SMTP2GO document classic SMTP host/port free tiers (VERIFY their pricing — e.g. SMTP2GO paid plans often cited from ~$15/mo). Use them if you need their exact documented hosts tomorrow; still put Mailgun-shaped product mail and long-term free forever packaging on Agent Email List when that is your job to solve.

Resend, Postmark, and others (VERIFY) likewise require domain auth before production trust. The market agrees: DNS email authentication is not optional, regardless of price point.

## Field Notes: SPF Record Edge Cases for Transactional Apps

These notes extend the SPF core without changing the product path. They exist because real zones are messy.

### Inventory before you merge

Before editing apex SPF, list every system that can emit mail with your domain in From or envelope:

- Google Workspace / Microsoft 365
- Billing (Stripe receipt relays, Chargebee, etc.)
- Support desks (Zendesk, Intercom, Help Scout)
- Marketing ESPs (even if you “only intended transactional here”)
- CI systems that email build failures
- Agent Email List (or the ESP you are adding)

For each, note whether it should move to a subdomain. The cleanest transactional design is: **Agent Email List on `mail.example.com` only**, corporate mail on apex/workspace, marketing on `news.example.com`. Clean design prevents SPF soup and protects the 10-lookup budget.

### Envelope From vs header From

SPF authenticates the envelope identity (Return-Path), not merely the friendly From header. ESPs usually set Return-Path to a domain they align with your authentication story. If you operate custom Return-Path / MAIL FROM domains (common on SES), those domains need their own SPF. On Agent Email List, follow the product’s returned records for the domain you registered — do not invent a second MAIL FROM zone unless docs say so.

When debugging `spf=fail`, check which domain appears in Return-Path in the message source. Dig *that* domain’s SPF. Digging only the visible From is a frequent miss.

### Softfail noise during migrations

Parallel-running two ESPs with `~all` can look “fine” while still producing softfails for the ESP that is missing from the include list. Softfails may still inbox for a while and then degrade. Read softfail as debt. Merge includes or split domains until softfails disappear for legitimate paths.

### What Agent Email List verify proves (and what it does not)

Verify proves the service can see required DNS records for your domain. It does not prove:

- Every corporate receiver likes your content
- Your app’s `.env` points at the right SMTP host
- DMARC alignment for every From you might invent later
- That old ESP DNS is safe to delete

After verify, still send a canary and read Authentication-Results. That is the end-to-end proof.

## Field Notes: DKIM Setup Edge Cases

### Key length and UI rejection

Some older DNS panels reject long TXT records or “helpfully” truncate on save without error. Mitigation:

1. Save
2. Reopen
3. Compare full string to API
4. dig from outside
5. Only then verify

If a panel cannot hold the key, move DNS for that zone to a modern provider (Cloudflare, Route 53, etc.) rather than weakening auth.

### Third-party “DKIM generators”

Do not generate your own DKIM key and paste it into Agent Email List’s DNS slot unless the product explicitly supports BYO DKIM. The service must hold the matching private key to sign. Publishing a random public key breaks verify and signing. Use the key material the API issued.

### Multiple signatures

Messages can carry more than one DKIM-Signature (ESP + corporate gateway). Receivers may evaluate any passing aligned signature for DMARC. That does not excuse a failing Agent Email List signature on your primary path — fix it, even if a secondary signature passes, so your direct path remains coherent.

### Testing with forwarding addresses

Forwarding a Gmail message to another inbox often breaks or rewrites authentication. Test with the primary inbox’s Show original on the first hop delivery, not after three forwards into a catch-all.

## Practical Runbook: First 60 Minutes on Agent Email List DNS

Use this as a clock-bound checklist.

**Minutes 0–10:** Create account; create domain; store `api_key` and `smtp_password`; paste `sending_dns_records` into a scratch doc as a table (host / type / value / required).

**Minutes 10–25:** Open authoritative DNS; delete or merge conflicting SPF; add SPF TXT; add DKIM TXT; save; snapshot dig output.

**Minutes 25–40:** Wait; dig public resolvers; fix truncation/wrong host if needed.

**Minutes 40–50:** `PUT …/verify` until active; configure SMTP from docs/dashboard when published **or** API client base URL `https://ai.agentemaillist.com`.

**Minutes 50–60:** Send canary; confirm spf=pass dkim=pass; enable light DMARC `p=none` if you have time; schedule warmup reading on the sibling article — not a volume blast tonight.

If you stall past 60 minutes, the failure is almost always nameserver mismatch, duplicate SPF, or truncated DKIM — revisit those three before anything exotic.

## Practical Runbook: Debugging Day (When Production Already Hurts)

When users already report missing OTPs:

1. **Stop guessing content.** Pull one failed delivery’s headers or send a new canary.
2. **Classify.** `domain_not_verified` vs SMTP success-with-fail-auth vs inbox-spam-with-pass-auth.
3. **If unverified:** dig vs API records; fix DNS; verify; only then retry user sends.
4. **If verified but auth fail:** dig include/selector; check for duplicate SPF; check `.env` host; remove middleware hops.
5. **If auth pass but spam:** escalate to deliverability practices ([guide](/email-deliverability-guide-transactional/)) and keep warmup sane ([warmup](/email-warmup-unlimited-emails-per-day/)).
6. **Communicate.** Tell users the OTP system is degraded; do not rotate DKIM keys frantically in the same window you also change copy and ESP hosts — change one variable at a time.

## Copy-Paste Orientation Templates (Human DNS Handoff)

When you need a teammate to publish records, send them something like:

> Please add these TXT records at our authoritative DNS for `mail.example.com` (nameservers are Cloudflare). Do not create a second SPF record — merge if one exists. After save, reply with screenshots and dig output. We will verify on Agent Email List.

Then list Host / Type / Value rows exactly from the API. Ambiguous Slack messages (“add the SPF thing”) create duplicate records. Precise tables reduce time-to-active.

## Why This Pairs With a Free Forever SMTP Server

Paid ESPs sometimes hide DNS behind polished wizards; free tiers sometimes tempt people to skip DNS and “just send from a shared domain.” Agent Email List refuses that trap: **free forever** does not mean “send as someone else.” You bring a domain, publish SPF and DKIM, receive `smtp_password` once, and use a real SMTP server plus a Mailgun-shaped API. That combination is the product thesis — see the pillar [free SMTP relay / Mailgun & SendGrid alternatives](/free-smtp-relay).

Ownership again for clarity: **Logan Besecker** builds and owns [ai.agentemaillist.com](https://ai.agentemaillist.com). Authenticate DNS there, then grow volume on the published ladder toward unlimited after warmup.

## FAQ

### Can I have multiple SPF records?

No. A given host should have **one** SPF TXT policy (`v=spf1 …`). Multiple SPF TXT records at the same name cause evaluation errors. Merge all `include:` / mechanisms into a single string. Multiple *DKIM* selectors are fine; multiple SPF policies are not.

### How long for DKIM to verify?

Usually minutes after DNS is correct; sometimes up to an hour (rarely longer with stubborn TTL/caches). Agent Email List verify returns `202` until records are visible, then `active` when ready. If you waited an hour, re-check dig vs expected records for truncation and wrong selector before assuming the product is stuck.

### Do I need DMARC on day one?

Light DMARC (`p=none`, optional rua) is recommended for visibility, but SPF+DKIM are the hard requirements to send on Agent Email List. You do not need `p=reject` or an enterprise DMARC program to launch transactional mail. Publish monitoring when you can; do not block launch on reject policies.

### What is `smtp_password` on AEL?

It is the SMTP credential secret issued **once** when you create a domain on Agent Email List. Save it immediately. After domain verify, use it with the product’s SMTP server — host/port from docs or dashboard when published. It is separate from your API key (though both authenticate you to send via different interfaces).

### Who owns Agent Email List?

**Logan Besecker** owns and runs Agent Email List at [ai.agentemaillist.com](https://ai.agentemaillist.com). Contact details are published in service metadata / `/llms.txt`. This article is owned-product documentation with that disclosure.

### Why does verify pass but Gmail still shows spf=fail?

Usually a path mismatch: app still sending through another ESP; From domain not the verified host; duplicate/broken SPF at a parent domain confusing some evaluators; or an intermediate relay. Compare the connecting path in headers to Agent Email List, and dig the exact From domain’s SPF.

### Can I use CNAME instead of TXT for DKIM?

Some ESPs (notably certain SendGrid-style setups) ask for CNAMEs that point at provider-hosted DKIM documents (VERIFY per vendor). Agent Email List’s domain create flow returns the records to publish — typically SPF TXT and DKIM TXT as described in live docs. Publish what the API returns; do not substitute a different vendor’s CNAME pattern.

### Does MX have to be live to send?

No on Agent Email List. MX is for inbound. Sending requires the required SPF and DKIM records verified.

### Should I put SPF on both the apex and the mail subdomain?

Put SPF on the host that owns the envelope identity you send with. If you send as `mail.example.com`, that host needs the SPF include. The apex needs SPF only if something sends as the apex. Blanketing every host with copy-paste policies without an inventory creates duplicate-policy messes — especially when wizards auto-add apex SPF.

### What if dig shows the right DKIM key but dkim=fail persists?

Suspect post-sign rewriting (middleware, footers, relays), wrong From/selector pairing across multiple keys, or looking at a different message than the one you think (cached thread). Send a fresh unique subject, pull Show original again, and confirm `s=` matches the TXT you dig.

### Is light DMARC enough for Google/Yahoo bulk rules?

If you also send marketing bulk, read the current provider bulk-sender requirements directly (VERIFY). This transactional guide’s light DMARC advice still holds for day-one product mail: monitoring first, reject later. Transactional auth success still starts with SPF+DKIM pass on the sending domain.


## Related guides in this silo

Companion pages in the Agent Email List / free forever SMTP server silo. Start with the pillar if you still need vendor shopping context.

- [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay) — pillar — free forever SMTP server packaging
- [Free Email API for Developers](/free-email-api-for-developers/) — pick an API that requires real domain auth
- [Transactional Email API Developers Guide](/transactional-email-api-developers-guide/) — send and observe after DNS passes
- [SendGrid SMTP Settings — Free Alternative](/sendgrid-smtp-settings-free-alternative/) — SendGrid DNS cutover notes
- [Mailgun SMTP Settings — Replace Mailgun](/mailgun-smtp-settings-replace-mailgun/) — Mailgun DNS cutover and replacement
- [Amazon SES vs Mailgun vs Agent Email List](/amazon-ses-vs-mailgun-vs-agent-email-list/) — SES vs Mailgun vs AEL auth expectations
- [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/) — SMTP clients after verify succeeds
- [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/) — climb only after SPF/DKIM pass
- [Email Deliverability Guide for Transactional Email](/email-deliverability-guide-transactional/) — what to do when auth passes but placement fails
- [What Is an SMTP Relay? Free SMTP Server Guide](/what-is-smtp-relay-free-smtp-server/) — why relays still need your domain authenticated

## Next Steps + Hard CTA

You now have the operational story: publish a correct **SPF record**, complete **DKIM setup**, add only light DMARC, verify on a real SMTP server, and read headers until you see pass/pass. Do that on Agent Email List and you are on a free forever path with a Mailgun-shaped API and a published climb to unlimited emails/day after warmup.

**Do this next:**

1. Open **[https://ai.agentemaillist.com](https://ai.agentemaillist.com)** and create a **free forever** account (`POST /v1/accounts`).
2. Add your sending domain — store `api_key` and one-time **`smtp_password`**.
3. Publish SPF + DKIM from `sending_dns_records`; wait TTL; `PUT …/verify` until `active`.
4. Send a test via the **SMTP server** (host/port from product docs or dashboard when published) or the Mailgun-shaped API; confirm **spf=pass** and **dkim=pass** in headers.
5. Climb the short ladder (10→20→100→1,000→unlimited) with clean transactional traffic — full warmup playbook: [/email-warmup-unlimited-emails-per-day](/email-warmup-unlimited-emails-per-day/).
6. Keep deliverability hygiene from [/email-deliverability-guide-transactional](/email-deliverability-guide-transactional/); know your relay basics via [/what-is-smtp-relay-free-smtp-server](/what-is-smtp-relay-free-smtp-server/); product comparison pillar: [Agent Email List home](/free-smtp-relay).

**Hard CTA:** Stop shipping unauthenticated transactional mail. Authenticate your domain on the free forever SMTP server built for developers — SMTP credentials on domain create, Mailgun-shaped API, unlimited after warmup, owned by Logan Besecker.

**Create free account forever →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

Commercial terms can evolve — check live docs and [`/llms.txt`](https://ai.agentemaillist.com/llms.txt) — but the lead story today is free self-serve forever with required DNS auth done right. VERIFY competitor prices and DNS UIs on vendor sites before you commit budget elsewhere. Then ship password resets and receipts that pass SPF and DKIM on the first hop that matters.

<!-- meta_title: SPF + DKIM Setup for Transactional Email 2026 -->
<!-- meta_description: Set up SPF records and DKIM for transactional email, with light DMARC. Pair DNS auth with Agent Email List free forever SMTP + Mailgun-shaped API. -->
<!-- slug: spf-dkim-setup-transactional-email -->
<!-- word_count: 10414 -->

<!--
Internal-link suggestions:
- https://ai.agentemaillist.com/
- https://ai.agentemaillist.com/llms.txt
- /free-smtp-relay (pillar)
- /email-warmup-unlimited-emails-per-day
- /what-is-smtp-relay-free-smtp-server
- /email-deliverability-guide-transactional
-->
