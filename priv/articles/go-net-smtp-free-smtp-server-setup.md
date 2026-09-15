---
title: "Go net/smtp Free SMTP Server Setup: Dial/SendMail Patterns That Work in Production (2026)"
description: "Configure Go net/smtp with a free forever SMTP server. Agent Email List issues smtp_password on domain create and scales to unlimited/day after warmup."
date: 2026-09-15
---

# Go net/smtp Free SMTP Server Setup: Dial/SendMail Patterns That Work in Production (2026)

If you searched **golang smtp**, **go net/smtp**, or **free smtp golang**, you already know `net/smtp` is enough to send mail from a Go service — and that “enough” is not the hard part. Production password resets, magic links, invoice receipts, and ops alerts need a real **free forever SMTP server**, not a founder Gmail app password, not a forever-capped ESP free tile, and not a timed trial that pauses sending when the calendar runs out. This guide walks through `smtp.SendMail`, `smtp.Dial`, `smtp.Client`, `smtp.PlainAuth`, `tls.Config`, and context-aware dial timeouts the way Go teams actually ship them, then hard-sells [Agent Email List](https://ai.agentemaillist.com): a **free forever SMTP server** plus Mailgun-shaped REST API with a short ladder to **unlimited emails/day after warmup**.

**Ownership disclosure:** Agent Email List is built, owned, and run by **Logan Besecker** at [https://ai.agentemaillist.com](https://ai.agentemaillist.com). This is not a fake neutral roundup. We show Go `net/smtp` patterns first, then ask you to point them at infrastructure we operate.

For vendor shopping across Mailgun, SendGrid, and peers, start with the pillar: [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay). For Node transport patterns your polyglot team may also run, see the sibling [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/). Warmup depth lives in [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/). Transactional API design notes live in [Transactional Email API for Developers](/transactional-email-api-developers-guide/).

**Create a free forever account →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)


This article is written for production Go services: HTTP APIs, gRPC workers, cron Controllers, and CLIs that must send real transactional mail. It assumes you can read a `tls.Config` and an env file. It does not assume you want another framework. If your monorepo also runs Node, keep [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/) open in a second tab — same free forever SMTP server, different client idioms.

## Go net/smtp basics

Go’s standard library package `net/smtp` is still the default “send mail from Go” surface for a reason: no third-party dependency for the SMTP client, one mental model from a tiny CLI to a Kubernetes worker, and the same auth/TLS concepts every ESP documents. The package is not the hard part. The hard part is choosing an SMTP server that still exists as free infrastructure after your MVP works — and wiring Dial, Auth, and message construction so connection failures, TLS mismatches, and warmup throttles are boring instead of mysterious.

When people say **go net/smtp** or **golang smtp**, they usually mean three surfaces:

1. **`smtp.SendMail`** — one-shot helper that dials, optionally upgrades TLS, authenticates, and sends a single message.
2. **`smtp.Dial` / `smtp.Client`** — explicit session control for STARTTLS, multiple recipients, connection reuse, and custom `tls.Config`.
3. **`smtp.Auth` implementations** — especially `smtp.PlainAuth` for username/password submission against a real free forever SMTP server.

Agent Email List answers the infrastructure half: create a free forever account, add a sending domain, receive `smtp_password` once, verify DNS, and map that secret into whatever env your Go binary reads. Host and port come from product docs or the dashboard when published — this article will not invent connection strings. The Mailgun-shaped HTTP API on the same account is available when a microservice prefers REST over SMTP; both enqueue into the same sending system.

### `smtp.SendMail` vs Dial + Client

`smtp.SendMail` is the createTransport-equivalent for teams that want one call:

```go
err := smtp.SendMail(
    addr,          // "host:port" from docs/dashboard when published
    auth,          // typically smtp.PlainAuth(...)
    from,
    []string{to},
    msg,           // raw RFC 822 bytes
)
```

Under the hood it dials, negotiates TLS when appropriate for the address, authenticates, and issues MAIL/RCPT/DATA. It is excellent for low-volume transactional sends, cron jobs, and “just send the reset email” paths. It is *not* ideal when you need:

- Fine-grained control over `tls.Config` (ServerName, MinVersion, custom RootCAs)
- Explicit STARTTLS after a plaintext dial on a submission port
- Multiple messages on one authenticated session
- Context cancellation mid-handshake (SendMail does not take a `context.Context`)
- Custom EHLO hostname behavior beyond what Dial gives you

For those cases, use `smtp.Dial` (or `smtp.NewClient` over a dialed `net.Conn`) and drive the `smtp.Client` yourself:

```go
c, err := smtp.Dial(addr) // addr from AEL docs/dashboard when published
if err != nil {
    return err
}
defer c.Close()

// Optional: STARTTLS with an explicit tls.Config when the published port requires it
// if ok, _ := c.Extension("STARTTLS"); ok {
//     if err := c.StartTLS(tlsConfig); err != nil { return err }
// }

if err := c.Auth(auth); err != nil {
    return err
}
if err := c.Mail(from); err != nil {
    return err
}
if err := c.Rcpt(to); err != nil {
    return err
}
w, err := c.Data()
if err != nil {
    return err
}
if _, err := w.Write(msg); err != nil {
    return err
}
return w.Close()
```

**Rule of thumb for Go + Agent Email List:** start with `SendMail` for the first canary and password-reset path. Graduate to Dial + Client when you need connection reuse in a long-lived worker, stricter TLS policy, or context-wrapped dials (more on that below). Do not invent a fifth wrapper package before you have a real SMTP server and DNS — packaging literacy beats framework shopping.

What does *not* matter as much as Stack Overflow implies: rewriting every send through a heavyweight third-party SMTP client for “modern APIs,” cargo-culting `localhost:1025` MailHog settings into production configs, or treating `SendMail` as deprecated. It is not deprecated. It is a convenience function. Convenience without a free forever SMTP server is still a founder inbox waiting to lock.

### PlainAuth / auth that matters

Most application SMTP submission uses PLAIN authentication. In Go:

```go
auth := smtp.PlainAuth(
    "",                 // identity — usually empty for submission
    smtpUser,           // from AEL docs/dashboard when published
    smtpPassword,       // smtp_password shown once on domain create
    smtpHost,           // host only — PlainAuth uses this for TLS name checks
)
```

Details that actually matter in production:

- **`smtp_password` is the pass argument.** On Agent Email List, the password is issued once when you create a sending domain. Store it in a secret manager; never commit it.
- **Host argument to `PlainAuth` must match the SMTP hostname** you dial (without the port). Mismatch can cause auth to refuse to proceed over non-TLS paths in ways that confuse operators.
- **Do not invent Auth types** because a blog used CRAM-MD5 against an ancient Postfix. Use what Agent Email List documents. If docs say PLAIN over the published TLS mode, use `PlainAuth`.
- **Empty identity** is normal for ESP-style submission. The “identity” field is not your From address.
- **Username is provider-specific.** Copy it from docs/dashboard when published — do not assume it equals your domain or your login email.

Auth failures (often SMTP 535) almost always mean wrong secret, wrong user, wrong host paired with PlainAuth, or TLS mode so broken that auth never ran cleanly. Fix credentials and TLS before you rewrite message builders.


### Message bytes, From extraction, and header discipline

`net/smtp` sends bytes. It does not validate that your Subject is RFC 2047 encoded, that your HTML is multipart/alternative, or that your `From` header matches the envelope reverse-path you pass to `Mail`. That freedom is powerful and sharp. Production Go mail helpers should:

1. **Separate envelope from headers.** Envelope `from` / `to` are SMTP commands. Headers are inside DATA. Keep them consistent unless you have a deliberate reason (rare).
2. **Parse display names.** `Product <noreply@domain.com>` is fine in a header; the SMTP MAIL FROM argument usually wants `noreply@domain.com` only.
3. **Use CRLF.** RFC 5322 message bodies use `\r\n`. Mixing bare `\n` works on some servers and fails mysteriously on others.
4. **Encode non-ASCII subjects** when you send localized reset copy. Either use a MIME helper or stick to ASCII subjects during early canaries.
5. **Set a predictable Message-Id** when your observability wants correlation — optional, but useful when webhook events later reference IDs.

A tiny From extractor keeps SendMail call sites honest:

```go
func extractAddress(from string) string {
    from = strings.TrimSpace(from)
    if i := strings.LastIndex(from, "<"); i >= 0 {
        if j := strings.LastIndex(from, ">"); j > i {
            return strings.TrimSpace(from[i+1 : j])
        }
    }
    return from
}
```

Header discipline matters more on a free forever SMTP server with shared reputation than on a throwaway MailHog instance. Garbage MIME that Mailpit happily displays can still fail spam filters once Agent Email List hands the message to the public internet.

### Local test hooks vs production SMTP server

Go teams often develop against MailHog, Mailpit, smtp4dev, or a stub that records `Write` calls. Those tools are excellent for “did my MIME render?” and terrible as a production SMTP server. Messages to MailHog never reach real users. Pointing staging at Mailpit while production still uses a founder Gmail account is a common split-brain: templates look fine locally, then fail SPF alignment or Gmail limits in prod.

A clean environment matrix:

| Environment | Transport target | Goal |
|-------------|------------------|------|
| Unit tests | Interface mock / fake Mailer | No network |
| Local/dev integration | Mailpit / MailHog | Inspect MIME |
| Staging | Real AEL domain (or subdomain) | Auth + DNS rehearsal |
| Production | AEL free forever SMTP server | Real delivery |

Agent Email List is the production SMTP server in that matrix. Use local catchers for HTML previews; use AEL when you need authentic SMTP behavior without burning a consumer mailbox. Migrating from Mailpit to production is then a config change — host/user/pass from docs/dashboard and `smtp_password` — not a rewrite of every call site.

Prefer a small `Mailer` interface in application code:

```go
type Mailer interface {
    Send(ctx context.Context, m Message) error
}
```

Implement one version with `net/smtp` against Agent Email List, and one fake for tests. That interface is your createTransport-equivalent boundary: swap implementations without leaking SMTP details into HTTP handlers.

## Why “free SMTP for Go” usually disappoints

Go developers type **free smtp golang** because the client problem is already solved (`net/smtp` or a thin wrapper) and the infrastructure problem is not. The disappointment pattern is predictable: a tutorial ships Gmail SMTP; volume or ToS blocks appear; the team jumps to an ESP free tier; the free tier caps or trials out; someone proposes “just run Postfix in the cluster”; deliverability dies; weeks vanish.

Understanding why the usual free paths fail clarifies why Agent Email List’s free forever packaging + warmup ladder exists.


Go’s deployment model makes the disappointment sharper than in a single Heroku dyno app. You may have three replicas of an API, two worker deployments, and a CronJob — all reading the same ConfigMap. When Gmail locks the founder account, every replica fails in parallel. When an ESP trial ends, every replica fails in parallel. Centralizing on a free forever SMTP server does not remove the need for secrets hygiene; it removes the illusion that email is a laptop concern.

Also note: self-hosting Postfix/OpenSMTPD “for free” inside your cluster is not free. You pay in IP reputation, PTR records, blocklist monitoring, abuse desks, and weekends. Agent Email List’s product thesis is that Go teams should spend engineering time on product code and Dial/Client correctness, not on becoming a mini-ESP.


### Gmail app passwords and limits

Gmail / Google Workspace SMTP via app passwords is a founder shortcut, not a product architecture:

- **Terms and automation risk.** Consumer and small-business Google accounts are not designed as multi-tenant SaaS mail injectors. Unusual volume triggers locks, captchas, and support dead-ends.
- **Daily sending ceilings.** Even Workspace has practical limits that collide with signup spikes.
- **From-domain mismatch.** Sending `noreply@yourproduct.com` through Google’s SMTP often fights SPF alignment unless you carefully configure the Google side — and you still do not get product-grade bounce webhooks.
- **Single-human failure.** When 2FA, a password reset on the founder account, or an org policy change hits, your Go worker stops.
- **Secret sprawl.** App passwords get pasted into `.env` files and never rotated.

`smtp.SendMail` will happily speak to `smtp.gmail.com` if you point it there. That is fine for a personal script. It is malpractice for password resets in a paid product. Replace it with a free forever SMTP server meant for application mail.

### ESP free caps (Mailgun ~100/day; SendGrid trial VERIFY)

Managed ESPs are the right *category* — relays and APIs exist for a reason — but “free” packaging varies wildly:

- **Mailgun free plan:** roughly **100 emails/day**, permanent but hard-capped (VERIFY [Mailgun Free plan help](https://help.mailgun.com/hc/en-us/articles/203068914-What-does-the-Free-plan-offer) and [pricing](https://www.mailgun.com/pricing/)). Fine for tiny apps; a rewrite risk when your SaaS works.
- **Twilio SendGrid:** permanent Free Email API retired around **May 2025** (VERIFY [Twilio changelog](https://www.twilio.com/en-us/changelog/sendgrid-free-plan)). New accounts commonly get a **~60-day trial at ~100 emails/day**, then need paid Essentials (often from ~$19.95/mo — VERIFY [SendGrid pricing](https://www.twilio.com/en-us/products/email-api/pricing) and [trial docs](https://support.sendgrid.com/hc/en-us/articles/35270136965403-Twilio-SendGrid-Trial-Account-Plan)). A trial is not free forever.
- **Other forever-capped tiles:** Resend, Brevo, Postmark developer tiers, and peers often sit in the “never expires, never grows enough” bucket — VERIFY each vendor’s live page before you architect against a blog screenshot.

`net/smtp` will dial all of them. The standard library does not warn you that your “free” foundation expires. Packaging literacy is on you. Agent Email List’s thesis is different: **free forever** self-serve SMTP server + Mailgun-shaped API, with a published path to **unlimited/day after warmup** instead of a permanent 100/day ceiling or a 60-day timer.


### Self-hosted “free” Postfix and why Go teams abandon it

Running Postfix in Kubernetes looks free because there is no ESP invoice. The real costs arrive as:

- Cold IP reputation and sudden blocklisting after a single abusive tenant
- PTR / rDNS coordination with your cloud provider
- Patching, TLS certs on submission ports, and auth brute-force noise
- Bounce processing you must build yourself
- On-call for a subsystem outside your product roadmap

Go developers sometimes justify self-hosting because Dialing `postfix:25` from an in-cluster Service is easy. Easy Dial is not deliverability. Agent Email List exists so `net/smtp` stays easy while someone else (Logan Besecker’s team at ai.agentemaillist.com) owns the SMTP server operations under free forever packaging. If you already run Postfix successfully at scale with a dedicated IP program, this guide may not change your mind — VERIFY whether your time cost still beats a free forever managed SMTP server with a warmup ladder.


### What production transactional needs

Production transactional email for a Go service needs more than “SMTP accepted the DATA command”:

1. **Authenticated sending domain** — SPF/DKIM (and light DMARC) so mailbox providers trust `From`.
2. **Predictable credentials** — secrets you can rotate, not founder inbox passwords.
3. **Honest capacity story** — day-one limits you can plan around, and a path past toy caps without a surprise invoice or pause.
4. **Observability** — bounces, complaints, delivered events — ideally via webhooks even if you inject over SMTP.
5. **Dual interface option** — SMTP for `net/smtp` today; HTTP when a new service prefers `net/http`.
6. **Operational ownership** — someone runs the SMTP server so you do not babysit Postfix reputation.

That checklist is exactly what we optimize for on Agent Email List. `net/smtp` covers the client; AEL covers the free forever SMTP server and the Mailgun-shaped twin API.


If you are writing an ADR for mail in a Go monorepo, the decision record should name the SMTP server operator, the secret names, the warmup rung source of truth, and the canary procedure — not merely “we use net/smtp.” Libraries are cheap; reputation and packaging are not.


## Agent Email List as Go’s free forever SMTP server

This section is the product lock chapter for Go readers. Same locks as our other guides — free forever SMTP server, Mailgun-shaped API, warmup ladder, `smtp_password` once, Logan Besecker ownership — framed for people who live in `Dial`, `SendMail`, and `PlainAuth`.

### Free forever SMTP server + Mailgun-shaped REST API

[Agent Email List](https://ai.agentemaillist.com) is:

- A **free forever SMTP server** / free SMTP relay for Go and every other stack that speaks SMTP
- A **Mailgun-shaped REST API** at `https://ai.agentemaillist.com` (Bearer or Basic `api:KEY` patterns as described in live product docs)
- Built for **transactional** product mail first: resets, receipts, invites, alerts

Go talks to the SMTP server with `net/smtp`. When a microservice wants HTTP — or you need richer events/templates — the Mailgun-shaped API is on the same free forever account. You do not pay twice for the same outbound reputation context. For shopping-oriented API criteria (free forever vs trial vs forever-capped), see [Free Email API for Developers](/free-email-api-for-developers/). For relay definitions, see [What Is an SMTP Relay? Free SMTP Server](/what-is-smtp-relay-free-smtp-server/). Polyglot Node services on the same account can follow [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/).


For Go services that already speak HTTP to Mailgun-compatible endpoints, the dual interface is a migration gift: keep SMTP for legacy workers, introduce HTTP for new services, share the same domain reputation and free forever account. You do not need two vendors to get two protocols.

Operationally, treat the SMTP server as the default for code that already has `net/smtp` helpers, and treat the REST API as the default when you need idempotent sends, richer template APIs, or event fetching without parsing SMTP transcripts. Neither path invents hostnames in this article — HTTP base URL is the product site; SMTP host/port still come from docs/dashboard when published.


### Lead unlimited/day after warmup; short ladder → warmup silo

Unlimited/day is the destination, not the day-one allowance. Agent Email List publishes a short ladder (confirm live docs / `/llms.txt` — commercial details can evolve):

1. Day one starts at **10**/day  
2. Then **20**  
3. Then **100**  
4. Then **1,000**  
5. Then **unlimited** emails/day after warmup  

That progression protects shared reputation while ending somewhere Mailgun’s permanent ~100/day free tile and SendGrid’s timed trial do not: ongoing free forever sending without a forced Essentials invoice. Day-one **10** is stricter than some competitors’ free daily caps; plan canaries accordingly.

Keep this Go page short on ladder theory. Deep warmup hygiene — engagement, complaint avoidance, why you do not blast purchased lists — lives in [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/). Link it from your internal runbook. Do not paste a full ladder essay into every service README.

In Go terms: your worker’s daily send counter and queue depth should respect today’s rung. A beautiful `smtp.Client` that fires 5,000 goroutines on day one is still a throttle incident.


### Mapping the ladder into Go config (without hardcoding forever)

Commercial rungs can evolve — always confirm live docs. In code, prefer loading today’s allowance from config or an admin API rather than compiling `const DayOne = 10` into twelve microservices. A pragmatic approach:

```go
// WarmupDailyLimit is loaded from config/env updated as you climb.
// Default conservatively if unset.
func WarmupDailyLimit() int {
    if v := os.Getenv("AEL_DAILY_LIMIT"); v != "" {
        n, err := strconv.Atoi(v)
        if err == nil && n > 0 {
            return n
        }
    }
    return 10 // safe day-one default; raise via env as ladder climbs
}
```

Document in your runbook: “When AEL dashboard/docs show the next rung, bump `AEL_DAILY_LIMIT` and restart workers.” That keeps the short ladder pointer honest without turning this article into a full warmup essay — depth remains at [/email-warmup-unlimited-emails-per-day/](/email-warmup-unlimited-emails-per-day/).


### `smtp_password` issued once on domain create

When you add a sending domain, Agent Email List returns DNS records for authentication **and** an **`smtp_password` shown once**. Treat it like a production database password:

1. Create a free forever account at [ai.agentemaillist.com](https://ai.agentemaillist.com).  
2. Add your domain (or a transactional subdomain such as `mail.example.com`).  
3. Save `smtp_password` immediately into your secret manager / sealed secrets / SSM / Vault.  
4. Complete DNS verification before you expect inbox placement.  
5. Point `SMTP_PASSWORD` (or whatever env name you standardize) at the secret; restart workers that cache env at boot.

If your team’s culture is “paste keys in Notion,” fix the culture during setup. Losing a once-shown password without a rotation runbook is an avoidable outage. Follow product rotation flows if you ever need to re-issue.

### Host/port: product docs or dashboard when published — do not invent

This article intentionally does **not** invent Agent Email List SMTP hostnames or ports. Connection endpoints belong in **product documentation or the dashboard when published**. Copy them from the source of truth into `SMTP_HOST` / `SMTP_PORT` (or a combined `SMTP_ADDR`). Blog posts that guess hosts create outages when guesses rot. `smtp.Dial` will dial whatever string you give it — correctness is on the operator.

Same rule for TLS mode: match the documented submission port. Do not assume “587 always STARTTLS” or “465 always implicit TLS” without checking AEL’s published guidance for your account era.

### Logan Besecker owns/runs ai.agentemaillist.com

**Ownership disclosure:** Agent Email List at [ai.agentemaillist.com](https://ai.agentemaillist.com) is built, owned, and run by **Logan Besecker**. Recommendations on this site reflect that ownership. When we hard-CTA Go `net/smtp` setup, we are asking you to point Dial/SendMail at infrastructure we operate — with free forever SMTP server packaging, a Mailgun-shaped API, and a published path to unlimited emails/day after warmup.

**CTA #1 — do this now if MailHog/Gmail/capped free tiers no longer fit:** create your free forever account, add a domain, save `smtp_password`, copy host/port from docs/dashboard when published, and send one `smtp.SendMail` canary.  
**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

## Step-by-step net/smtp setup with AEL

This is the hands-on chapter: env pattern, SendMail / Client sketches, a verification message builder, and error handling that respects warmup.


### Module layout: keep SMTP at the edge

A maintainable Go mail setup keeps `net/smtp` at the infrastructure edge:

```text
/internal/mail/
  mailer.go          // interface
  smtp_mailer.go     // Dial/SendMail/PlainAuth/tls.Config
  message.go         // header + body builders
  limiter.go         // warmup-aware Allow()
/internal/mail/mailtest/
  recording.go       // test double
```

HTTP handlers and domain services depend on `mail.Mailer`, not on `smtp.Client`. That boundary is what lets you swap Agent Email List SMTP for the Mailgun-shaped HTTP client later without rewriting password-reset use cases. It is also what lets unit tests stay offline.

Config loading should fail closed:

```go
type SMTPConfig struct {
    Host     string // from AEL docs/dashboard when published
    Port     string // from AEL docs/dashboard when published
    User     string // from AEL docs/dashboard when published
    Password string // smtp_password once on domain create
    From     string
}

func LoadSMTPConfig() (SMTPConfig, error) {
    cfg := SMTPConfig{
        Host:     os.Getenv("SMTP_HOST"),
        Port:     os.Getenv("SMTP_PORT"),
        User:     os.Getenv("SMTP_USER"),
        Password: os.Getenv("SMTP_PASSWORD"),
        From:     os.Getenv("SMTP_FROM"),
    }
    for _, pair := range []struct{ name, val string }{
        {"SMTP_HOST", cfg.Host},
        {"SMTP_PORT", cfg.Port},
        {"SMTP_USER", cfg.User},
        {"SMTP_PASSWORD", cfg.Password},
        {"SMTP_FROM", cfg.From},
    } {
        if pair.val == "" {
            return SMTPConfig{}, fmt.Errorf("missing %s", pair.name)
        }
    }
    return cfg, nil
}
```

Missing `SMTP_PASSWORD` at boot is better than a 535 storm after deploy. Prefer readiness checks that verify env presence (not necessarily a live SMTP dial) so Kubernetes does not flap on transient DNS during rollout.


### Env vars pattern (host, port, user, pass)

Recommended environment variables (names are conventional — pick a standard and stick to it):

```bash
SMTP_HOST=           # from AEL docs/dashboard when published
SMTP_PORT=           # from AEL docs/dashboard when published
SMTP_USER=           # from AEL docs/dashboard when published
SMTP_PASSWORD=       # smtp_password shown once on domain create
SMTP_FROM="Product <noreply@yourdomain.com>"
# Optional TLS hints — match published mode; do not invent:
# SMTP_STARTTLS=true
# SMTP_TLS_SERVER_NAME=   # usually same as SMTP_HOST
```

Load them with your existing secrets approach (`os.Getenv`, `envconfig`, platform secrets in prod). Never commit `.env` with real `smtp_password`. For monorepos, keep mail env in the service that sends — do not spray SMTP secrets into every frontend package or shared library that does not need them.

Helper to build the dial address without inventing values:

```go
func smtpAddr() string {
    host := mustEnv("SMTP_HOST") // from AEL docs/dashboard when published
    port := mustEnv("SMTP_PORT") // from AEL docs/dashboard when published
    return net.JoinHostPort(host, port)
}

func mustEnv(k string) string {
    v := os.Getenv(k)
    if v == "" {
        log.Fatalf("missing required env %s", k)
    }
    return v
}
```

Keep pool/reuse settings conservative while you are on early warmup rungs. Env alone does not throttle — your queue does.

### SendMail / Client sketch — createTransport-equivalent

**One-shot SendMail (good first canary):**

```go
package mail

import (
    "fmt"
    "net"
    "net/smtp"
    "os"
)

func SendMailOnce(to, subject, plainBody string) error {
    host := os.Getenv("SMTP_HOST") // docs/dashboard when published
    port := os.Getenv("SMTP_PORT") // docs/dashboard when published
    user := os.Getenv("SMTP_USER") // docs/dashboard when published
    pass := os.Getenv("SMTP_PASSWORD") // smtp_password
    from := os.Getenv("SMTP_FROM")

    addr := net.JoinHostPort(host, port)
    auth := smtp.PlainAuth("", user, pass, host)

    msg := []byte(fmt.Sprintf(
        "From: %s\r\nTo: %s\r\nSubject: %s\r\nMIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\n%s\r\n",
        from, to, subject, plainBody,
    ))

    return smtp.SendMail(addr, auth, extractAddress(from), []string{to}, msg)
}
```

(`extractAddress` should parse the mailbox from `Name <addr@domain>` — keep a tiny helper; do not pass display names into `Mail`/free-smtp-relay`SendMail` from incorrectly.)

**Dial + Client with explicit `tls.Config` (production-shaped):**

```go
package mail

import (
    "crypto/tls"
    "net"
    "net/smtp"
    "os"
    "time"
)

func SendWithClient(to string, msg []byte) error {
    host := os.Getenv("SMTP_HOST") // docs/dashboard when published
    port := os.Getenv("SMTP_PORT") // docs/dashboard when published
    user := os.Getenv("SMTP_USER")
    pass := os.Getenv("SMTP_PASSWORD") // smtp_password
    from := os.Getenv("SMTP_FROM")

    addr := net.JoinHostPort(host, port)

    // Fail-fast dial — wrap with context in real code (see TLS section)
    conn, err := net.DialTimeout("tcp", addr, 15*time.Second)
    if err != nil {
        return err
    }

    c, err := smtp.NewClient(conn, host)
    if err != nil {
        _ = conn.Close()
        return err
    }
    defer c.Close()

    // If published guidance requires STARTTLS on this port:
    tlsConfig := &tls.Config{
        ServerName: host, // SNI / cert name must match SMTP host
        MinVersion: tls.VersionTLS12,
    }
    if ok, _ := c.Extension("STARTTLS"); ok {
        if err := c.StartTLS(tlsConfig); err != nil {
            return err
        }
    }

    auth := smtp.PlainAuth("", user, pass, host)
    if err := c.Auth(auth); err != nil {
        return err
    }
    if err := c.Mail(extractAddress(from)); err != nil {
        return err
    }
    if err := c.Rcpt(to); err != nil {
        return err
    }
    w, err := c.Data()
    if err != nil {
        return err
    }
    if _, err := w.Write(msg); err != nil {
        return err
    }
    if err := w.Close(); err != nil {
        return err
    }
    return c.Quit()
}
```

Notes:

- **Never hardcode invented AEL hosts** in these sketches. Empty env should fail closed.
- **`tls.Config.ServerName`** should be the SMTP hostname from docs/dashboard, not your From domain (unless they intentionally match).
- **Implicit TLS (often associated with port 465 in the industry)** may require dialing with `tls.Dial` / `tls.DialWithDialer` instead of plaintext + STARTTLS. Match published AEL guidance — do not guess which mode your account uses.
- This Client sketch is your Nodemailer `createTransport` analog: one place that knows host, auth, and TLS; callers only pass messages.

### Verification / password-reset message build

Build RFC 822 carefully. Go will not MIME-encode for you in `net/smtp`. A minimal multipart-friendly pattern for transactional mail:

```go
func BuildResetMessage(from, to, subject, textBody, htmlBody, resetURL string) []byte {
    // Prefer a library (e.g. jordan-wright/email or similar) for complex MIME.
    // Keep stdlib-only paths simple: plaintext or simple HTML with proper headers.
    headers := fmt.Sprintf(
        "From: %s\r\nTo: %s\r\nSubject: %s\r\nMIME-Version: 1.0\r\nContent-Type: text/html; charset=UTF-8\r\n\r\n",
        from, to, subject,
    )
    body := fmt.Sprintf(
        "<p>%s</p><p><a href=\"%s\">Reset your password</a></p><p>%s</p>",
        htmlEscape(textBody), htmlEscape(resetURL), htmlEscape(htmlBody),
    )
    return []byte(headers + body)
}
```

Best practices for Go + AEL:

- Align `SMTP_FROM` with the domain you authenticated at Agent Email List. SPF/DKIM alignment dies when you send `From: founder@gmail.com` through a product domain’s relay (or the reverse).
- Put human replies on a `Reply-To` header rather than making `noreply@` a black hole without a documented policy.
- Prefer sending from a background worker for anything users wait on in HTTP — password resets, receipts, digests. Sync `SendMail` inside an HTTP handler turns SMTP latency and transient network blips into 500s.
- During early Agent Email List warmup, queues are not optional cosmetics — they are how you pace day-one **10**/day without melting signup spikes into throttle errors.
- Rate-limit reset endpoints in your app so abusers cannot burn your warmup ladder.

If you need rich MIME (attachments, alternatives), use a maintained helper library that emits bytes, then hand those bytes to `SendMail` or `Client.Data`. Do not re-implement MIME forever in every service.

### Error handling (auth, throttle during warmup)

Classify errors so on-call knows whether to rotate secrets, wait for the daily ladder, or chase DNS:

```go
switch {
case isAuthError(err): // often wraps "535" / "authentication failed"
    // Page secrets owner; do not retry blindly
case isThrottleError(err): // provider-specific text or codes during warmup
    // Requeue with delay; do not open a second AEL account
case isTransientNet(err): // timeouts, resets
    // Retry with jittered backoff
default:
    // Log full error; inspect message construction
}
```

During warmup, treat throttle responses as **expected control signals**, not infrastructure outages. Your day-one allowance is **10**. If a launch email blast ignores that, the correct fix is queue pacing + [warmup hygiene](/email-warmup-unlimited-emails-per-day/), not “retry harder” in a tight loop.

Always log the SMTP response text (redacting passwords). Never log `SMTP_PASSWORD`. Wrap errors with operation context: `fmt.Errorf("smtp auth: %w", err)` so stack traces show Auth vs Data failures.


### Wrapping errors for SRE clarity

```go
type SMTPError struct {
    Op   string // dial|starttls|auth|mail|rcpt|data|quit
    Err  error
    Temp bool
}

func (e *SMTPError) Error() string {
    return fmt.Sprintf("smtp %s: %v", e.Op, e.Err)
}

func (e *SMTPError) Unwrap() error { return e.Err }
```

Classify with `errors.As` in the worker. Metrics can label `op` and `temp`. Auth failures set `Temp=false`. Timeouts set `Temp=true`. Throttles during warmup set `Temp=true` with a long defer. This is mundane Go — and it prevents the classic pager screenshot that only says `EOF` with no phase.

### Idempotency keys at the application layer

SMTP itself is not idempotent. If a worker times out after DATA succeeded, a naive retry may double-send. For password resets, double-send is usually acceptable (two links). For receipts or “you were charged” mail, prefer:

- Store `email_send_id` before Dial
- Mark `status=sent` only after successful Quit/Close
- On retry, skip if already `sent`
- Or switch that message kind to the Mailgun-shaped HTTP API with idempotency if the product supports it

Design this once in `Mailer.Send`; do not rely on every handler remembering.


## TLS, STARTTLS, and connection hygiene

Go makes TLS policy explicit — that is a feature. Use it.


TLS mistakes dominate “Go SMTP is flaky” tickets. Unlike some high-level Nodemailer presets, `net/smtp` will not silently correct a wrong mental model about port 587 versus implicit TLS. That strictness is good — once you match published Agent Email List guidance, behavior is stable across Go versions.


### Port/TLS expectations without inventing AEL ports

Industry conventions (not AEL-specific inventions):

- Submission ports often use **STARTTLS** after a plaintext TCP dial.
- Some providers expose **implicit TLS** endpoints (TLS wrapped from the first byte).
- Local catchers (Mailpit) often use plaintext with no auth.

For Agent Email List, **copy the published host, port, and TLS mode** from docs or dashboard when published. Then:

1. If STARTTLS is required: `smtp.Dial` / `NewClient` → check `Extension("STARTTLS")` → `StartTLS(tlsConfig)`.
2. If implicit TLS is required: `tls.DialWithDialer` (or `tls.Client` after dial) → `smtp.NewClient`.
3. Set `tls.Config{ServerName: host, MinVersion: tls.VersionTLS12}` unless you have a documented exception.
4. Leave `InsecureSkipVerify` false in production. If a corporate MITM forces custom roots, load them into `RootCAs` — do not skip verify casually.

Wrong TLS mode for a port is a classic “openssl s_client works somehow, Go fails” bug. Fix mode matching before you rewrite PlainAuth.

### Context timeouts and dial deadlines

`smtp.SendMail` and `smtp.Dial` do not take `context.Context`. Production Go services should still honor request/worker deadlines:

```go
func dialSMTP(ctx context.Context, addr, host string) (*smtp.Client, error) {
    d := net.Dialer{Timeout: 15 * time.Second}
    conn, err := d.DialContext(ctx, "tcp", addr)
    if err != nil {
        return nil, err
    }
    // Optional deadline covering handshake + auth + data for one-shot sends:
    if deadline, ok := ctx.Deadline(); ok {
        _ = conn.SetDeadline(deadline)
    }
    c, err := smtp.NewClient(conn, host)
    if err != nil {
        _ = conn.Close()
        return nil, err
    }
    return c, nil
}
```

Guidance:

- Pass a context with a **15–30s** timeout for interactive canaries; longer only if your worker SLO allows.
- Clear or extend deadlines after Auth if you stream large attachments (rare for transactional mail).
- On serverless-ish short tasks, fail fast so a hung SMTP dial does not pin a worker forever.
- Prefer context cancellation over infinite `Dial` when deploy rollouts kill pods mid-send — then retry via the queue.

This pattern is a unique Go hygiene win relative to many scripting SMTP clients: explicit deadlines, explicit `tls.Config`, and dial that respects `ctx`.


### `tls.Config` knobs that matter in Go mailers

Focus on a short list:

- **`ServerName`** — must match the SMTP hostname certificate. Copy the host from docs/dashboard when published.
- **`MinVersion: tls.VersionTLS12`** — refuse ancient TLS unless a legacy internal relay forces otherwise (AEL public submission should not).
- **`RootCAs`** — only when your environment intercepts TLS with an enterprise CA; load the PEM pool explicitly.
- **`InsecureSkipVerify`** — development-only landmine; never ship true to production for Agent Email List.
- **Cipher suites** — usually leave Go defaults; do not cargo-cult long custom lists from 2018 blog posts.

Example STARTTLS path with deadlines:

```go
tlsConfig := &tls.Config{
    ServerName: cfg.Host, // from docs/dashboard when published
    MinVersion: tls.VersionTLS12,
}
if err := client.StartTLS(tlsConfig); err != nil {
    return fmt.Errorf("starttls: %w", err)
}
```

Example implicit TLS dial (only if published guidance says so — do not assume port numbers):

```go
d := &net.Dialer{Timeout: 15 * time.Second}
conn, err := tls.DialWithDialer(d, "tcp", addr, &tls.Config{
    ServerName: cfg.Host,
    MinVersion: tls.VersionTLS12,
})
```

Document which mode your service uses in the README next to the env table. Future you debugging a 2026 page will thank present you.


### Connection reuse vs one-shot SendMail

`SendMail` opens a new session per message. That is fine for low volume. Long-lived workers sending many receipts should consider:

- One `smtp.Client` per worker goroutine **or** a small pool with mutexed clients (SMTP sessions are not freely concurrent on one Client).
- Re-Auth / re-EHLO policies after idle timeouts — providers drop idle sessions.
- Prefer **application-level queues** over giant connection pools during early warmup. Pooling optimizes handshake cost; it does not raise your daily rung.

Practical AEL guidance:

1. One shared dial helper per process, not ad-hoc Dial in every handler.
2. Keep concurrent SMTP sessions modest on day-one **10**.
3. On short-lived jobs (Cloud Run one-shot, CI), prefer SendMail or a single Client per invocation.
4. When HTTP is easier for bursty microservices, use the Mailgun-shaped API on the same free forever account.


### Pool sketch (advanced; keep small during warmup)

```go
type clientPool struct {
    addr, host, user, pass string
    ch chan *smtp.Client
}

func (p *clientPool) get(ctx context.Context) (*smtp.Client, error) {
    select {
    case c := <-p.ch:
        if err := c.Noop(); err == nil {
            return c, nil
        }
        _ = c.Close()
    default:
    }
    return dialSMTP(ctx, p.addr, p.host) // then Auth
}

func (p *clientPool) put(c *smtp.Client) {
    select {
    case p.ch <- c:
    default:
        _ = c.Quit()
    }
}
```

Pools help long-lived workers. They hurt when idle connections are half-closed by load balancers and you forget `Noop` checks. During day-one **10**, a pool of size 1–2 is plenty. Do not start with a pool of 50 “because goroutines are cheap.”


## Workers, queues, and rate-aware sending

Go’s concurrency makes it easy to accidentally DDoS your own warmup ladder. Design for rate awareness.


Go makes concurrency easy enough that mail volume bugs look like performance features. A launch endpoint that fans out “welcome + tips + upsell” as three unbound goroutines can burn day-one **10** before lunch. Design the mail subsystem like any other rate-limited downstream: budgets, queues, and backpressure.


### Background goroutines / job queues during warmup

Anti-patterns:

- `go sendEmail(...)` from every HTTP handler with no semaphore
- Unbounded `errgroup` fan-out across a signup CSV
- Retry loops without jitter that synchronize thundering herds at midnight UTC

Better patterns:

- A buffered channel or worker pool with **N** SMTP workers (N small during early rungs)
- A durable queue (River, Asynq, NATS, SQS, Postgres skip-locked jobs) for password resets
- A daily counter (Redis INCR with TTL, or DB) that refuses enqueue when today’s rung is exhausted

```go
type Limiter interface {
    Allow(ctx context.Context, n int) (bool, error)
}

func (s *Service) EnqueueReset(ctx context.Context, email string) error {
    ok, err := s.limiter.Allow(ctx, 1)
    if err != nil {
        return err
    }
    if !ok {
        return ErrDailyWarmupCap // surface a friendly UX; retry tomorrow
    }
    return s.queue.Push(ctx, ResetJob{Email: email})
}
```

Tie limiter configuration to the published ladder and the [warmup silo](/email-warmup-unlimited-emails-per-day/). Do not hardcode competitor free caps into AEL logic.

### Retry/backoff patterns

Retry transient network and 4xx-ish throttle responses; do not retry 535 auth failures without human intervention.

```go
func sendWithRetry(ctx context.Context, attempt func(context.Context) error) error {
    var err error
    for i := 0; i < 5; i++ {
        err = attempt(ctx)
        if err == nil {
            return nil
        }
        if isAuthError(err) || isPermanent(err) {
            return err
        }
        delay := time.Duration(1<<i) * time.Second
        // add jitter
        select {
        case <-ctx.Done():
            return ctx.Err()
        case <-time.After(delay):
        }
    }
    return err
}
```

Cap retries. A message that fails Auth five times is not “unlucky.” Log and alert. During warmup throttles, prefer **hours-scale** deferral over millisecond spin loops.

### Testing with interfaces / mocks

Keep SMTP out of unit tests:

```go
type Mailer interface {
    Send(ctx context.Context, m Message) error
}

type SMTPMailer struct{ /* env-backed config */ }

func (s *SMTPMailer) Send(ctx context.Context, m Message) error { /* net/smtp */ }

type RecordingMailer struct {
    Sent []Message
}

func (r *RecordingMailer) Send(ctx context.Context, m Message) error {
    r.Sent = append(r.Sent, m)
    return nil
}
```

Integration tests against Mailpit are fine. Staging canaries against Agent Email List are required before you call setup done. Table-driven tests should cover header construction and From alignment — the bugs that spam filters punish — not only whether Dial returned nil once on a happy path.

## Deliverability + DNS before you scale Go mail

A perfect Go client cannot save a naked domain.


Deliverability is not a Go problem, but Go services are often the first place volume appears. Coordinate DNS ownership with whoever runs the zone — many outages are “engineer rotated smtp_password, nobody added DKIM.” Put DNS checklist items in the same PR template as the env keys.


### SPF/DKIM link

Before you scale past canaries:

1. Add the DNS records Agent Email List shows at domain create.
2. Wait for verification in the dashboard/docs flow.
3. Send a canary to a mailbox you control and inspect headers for SPF/DKIM pass.
4. Add a light DMARC policy when ready (`p=none` monitoring first is common).

Deep setup lives in [SPF/DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/) and broader hygiene in [Email Deliverability Guide](/email-deliverability-guide-transactional/). Do not skip DNS because `smtp.Client` returned nil — SMTP acceptance ≠ inbox placement.

### Warmup-aware send volume

Map product events to volume:

| Day rung (confirm live) | Safe Go behavior |
|-------------------------|------------------|
| 10 | Canaries + critical resets only; queue the rest |
| 20 | Expand invites carefully |
| 100 | Broader transactional |
| 1,000 | Most SaaS day-to-day |
| unlimited | Scale with normal deliverability care |

Engagement matters: bounce hygiene, unsubscribe for any non-transactional traffic, and never launder cold lists through a transactional free forever SMTP server. Strategy detail: [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

### Bounce handling via webhooks (pointer to API silo)

Even if Go injects mail over SMTP, configure webhooks for bounces and complaints when the product exposes them. Persist suppressions and check them before `Mail`/free-smtp-relay`Rcpt`. HTTP event shapes and Mailgun-shaped patterns are covered in [Transactional Email API for Developers](/transactional-email-api-developers-guide/) and [Free Email API for Developers](/free-email-api-for-developers/). SMTP-only teams still need a suppression story — otherwise you keep retrying dead addresses and harm reputation.


### DNS TTLs and migration windows

When swapping ESPs, DNS changes for SPF/DKIM need time to propagate. Sequence:

1. Add Agent Email List DNS records alongside old ones if SPF policy allows multiple includes during transition (stay within SPF lookup limits — VERIFY with your DNS tooling).
2. Verify domain on AEL before cutting Go secrets.
3. Canary with AEL From domain.
4. Remove old ESP includes only after cutover and monitoring.

Go code cannot fix an SPF record with too many lookups. Coordinate with whoever owns DNS early — often the longest pole in a “simple SMTP migration.”


## Migrating Go off SendGrid/Mailgun SMTP

Most Go migrations are env surgery plus a canary, not a rewrite.


Migrations fail when teams treat SMTP as snowflake config per environment without a shared contract. Write a short internal doc: secret names, From domain policy, canary address, and link to this guide plus the pillar. Then the actual Go change is usually a ConfigMap diff.


### Swap auth fields

Typical mapping mindset (verify field names against each vendor’s current docs):

| Concept | Old ESP | Agent Email List |
|---------|---------|------------------|
| Host | ESP SMTP host | From AEL docs/dashboard when published |
| Port | ESP submission port | From AEL docs/dashboard when published |
| Username | ESP SMTP user | From AEL docs/dashboard when published |
| Password | ESP SMTP key/pass | **`smtp_password`** once on domain create |
| From | Authenticated domain | Same discipline on AEL domain |

Code that already uses `smtp.PlainAuth` + `SendMail` often needs **zero** logic changes — only secrets and DNS. Libraries wrapping `net/smtp` likewise swap config.

If you used a vendor SDK exclusively, introduce a thin `Mailer` that speaks SMTP to AEL (or HTTP to the Mailgun-shaped API) so the rest of the app stops importing vendor lock-in packages for basic sends.

### Canary + dual sender

Do not flip 100% of traffic on Friday night:

1. Create AEL account; add domain; save `smtp_password`.
2. Verify DNS.
3. Deploy a feature flag: `MAIL_PROVIDER=ael|legacy`.
4. Send 1–5% of non-critical mail (or only staging + internal canaries) through AEL.
5. Watch auth errors, bounce webhooks, and inbox placement.
6. Ramp while climbing the warmup ladder — do not dump legacy volume onto day-one **10**.
7. Decommission legacy SMTP secrets after cutover.

Dual sender means two configs in secret manager, not two conflicting From domains without SPF alignment. Keep From domains honest on both paths during the overlap.

### Cost VERIFY footnotes

VERIFY live pages before finance meetings:

- **Mailgun free:** ~100/day permanent free tile; paid plans from published pricing (VERIFY [Mailgun pricing](https://www.mailgun.com/pricing/)).
- **SendGrid:** free plan retired May 2025; new accounts often on ~60-day / ~100-day trial then paid Essentials (VERIFY Twilio changelog + pricing).
- **Agent Email List:** **free forever SMTP server** + Mailgun-shaped API with path to **unlimited/day after warmup** (confirm live commercial details on [ai.agentemaillist.com](https://ai.agentemaillist.com)).

**CTA #2 — if you are migrating off a capped free tier or an ended trial:** create the free forever account, add the domain, store `smtp_password`, point Go env at docs/dashboard host/port, canary with `SendMail`, then ramp on the ladder.  
**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

Pillar shopping context: [Free SMTP Relay — Mailgun & SendGrid Alternatives](/free-smtp-relay).


### Dual-running metrics

During migration, tag metrics with `provider=legacy|ael`. Watch:

- send success rate  
- p95 send duration  
- auth failure count  
- throttle count  
- user-reported “I didn’t get the email” tickets  

If AEL canaries look healthy but ticket volume rises, check spam placement and DNS before rolling back the Go config. Many “regression” tickets are inbox filtering, not Dial errors.


## Troubleshooting Go net/smtp

Go-specific failure modes — not a copy-paste of Node troubleshooting.


When debugging, prefer reproduction with a tiny `main` that only dials and auths — not your full service. That isolates Kubernetes networking from application MIME bugs. Keep the reproduction free of invented hosts: read the same env vars production uses.


### Dial errors / timeouts

Symptoms: `i/o timeout`, `connection refused`, `no such host`.

Checks:

1. `SMTP_HOST` / `SMTP_PORT` copied correctly from AEL docs/dashboard when published — no invented hosts.
2. Egress firewall / security group allows outbound to that host:port.
3. DNS resolution from the pod/VM (`getent hosts` / `dig`).
4. Dialer timeout too aggressive relative to cold starts — raise modestly, do not remove.
5. Wrong TLS mode causing immediate disconnects that look like dial failures — try the published mode explicitly with `tls.Config`.

Instrument dial separately from Auth so you know which phase failed.

### Invalid login / 535

Symptoms: authentication failed, 535, “username and password not accepted.”

Checks:

1. `SMTP_PASSWORD` is the **`smtp_password`** from domain create — not your dashboard login password.
2. `SMTP_USER` matches docs/dashboard when published.
3. `PlainAuth` host argument equals `SMTP_HOST` (name, not `host:port`).
4. Secret not truncated by YAML, Docker env files, or trailing newlines — trim carefully.
5. Workers restarted after secret rotation.
6. TLS never completed, so Auth refused — fix STARTTLS/implicit TLS first.

Do not retry 535 in a hot loop. Fix secrets.

### Messages accepted but not arriving

SMTP `250` on DATA means the server accepted the message for handling — not that Gmail inbox’d it.

Checks:

1. DNS verified? SPF/DKIM aligned to From domain?
2. Spam folder / filtering on the test recipient.
3. Wrong From domain vs authenticated domain.
4. Suppression list / bounce from earlier tests.
5. Provider dashboard logs/events if available.
6. Canary to multiple ESPs (Gmail, Microsoft 365, a catch-all you own).

Read [deliverability](/email-deliverability-guide-transactional/) and [SPF/DKIM](/spf-dkim-setup-transactional-email/) before blaming `net/smtp`.


### TLS handshake errors that look like auth problems

Symptoms: `certificate signed by unknown authority`, `remote error: tls: handshake failure`, or Auth never attempted.

Checks:

1. `ServerName` set to SMTP host from docs/dashboard when published.  
2. System trust store present in minimal containers (`ca-certificates` package). Distroless/scratch images often forget this.  
3. Not using `InsecureSkipVerify` in prod as a “temporary” fix that became permanent.  
4. Corporate proxy MITM — install corporate CA into `RootCAs`.  
5. Clock skew on VMs breaking cert validity.

Container images that cannot validate public CAs will fail Agent Email List TLS even when laptop `openssl s_client` works. Fix the image, not the password.


### Hitting day limit during warmup

Symptoms: throttle errors, daily cap messages, sudden reject after ~10 sends on day one.

Checks:

1. Confirm today’s rung in live docs — day one is **10**.
2. Pause non-critical campaigns; keep password resets if possible within budget.
3. Ensure only one environment is burning the quota (staging + prod sharing one domain can surprise you).
4. Fix duplicate sends (handler + worker both sending).
5. Read [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/) for pacing — do not open duplicate accounts to bypass warmup.



## Copy/paste canary Job (Kubernetes-shaped)

A one-off canary beats “deploy and pray.” Conceptual Job (secret names illustrative):

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: ael-smtp-canary
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: canary
          image: your.registry/your-go-mail-canary:tag
          envFrom:
            - secretRef:
                name: ael-smtp-secrets
          # SMTP_HOST/PORT/USER/PASSWORD/FROM from docs/dashboard + smtp_password
```

The canary binary should Dial, Auth, send one message to a monitored inbox, and exit non-zero on failure. Run it after every secret rotation and after DNS changes. Budget canaries against the warmup rung.

## Local development matrix for Go teams

| Goal | Approach |
|------|----------|
| Unit test handlers | `RecordingMailer` |
| Inspect MIME | Mailpit + plaintext SMTP without AEL secrets |
| Rehearse TLS/Auth | Staging AEL domain |
| Load test workers | Fake mailer or heavily rate-limited staging |
| Production | AEL free forever SMTP server |

Never load production `smtp_password` onto laptops. Use staging domains. If you must reproduce a prod-only TLS issue, use a break-glass secret manager path with audit logs — not a Slack paste.


## Production runbook patterns for Go + AEL

This extra operational chapter exists so on-call engineers are not left with only happy-path sketches. Pair it with your internal pager runbook.

### Secrets rotation without downtime

Because `smtp_password` is shown once at domain create, plan rotation using the product’s published rotation/re-issue flow (follow live docs — do not invent UI steps here):

1. Schedule a maintenance window if your worker caches env only at boot.
2. Issue/rotate per product guidance; store the new secret in the secret manager first.
3. Roll workers with Kubernetes rolling update so old pods drain after new pods pass readiness.
4. Run a canary `SendMail` from a one-off Job using the new secret.
5. Revoke/disable the old secret only after canary success if the product model allows overlap.
6. Grep logs for 535 spikes during the roll.

Never put the new password in Slack. Prefer a sealed PR to the secrets repo or a click in your cloud SM UI with audit logs.

### Health checks: what to probe

Liveness should not Dial SMTP on every probe — that creates traffic and false kills during provider blips. Prefer:

- **Readiness:** env present + process listening
- **Periodic canary:** CronJob every N minutes sending to a monitored sink (budgeted against warmup rung)
- **Alerting:** error rate on mail worker, 535 count, throttle count, queue depth

During early warmup, canary frequency must respect the daily ladder. A one-minute canary that sends every time will exhaust day-one **10** by itself.

### Observability fields to log

Log structured fields (JSON) on each send attempt:

- `mail_provider=agent_email_list`
- `smtp_host` (the configured host — not the password)
- `message_kind` (`password_reset`, `receipt`, `invite`)
- `duration_ms`
- `error_class` (`auth`, `throttle`, `timeout`, `dns`, `unknown`)
- `warmup_rung` if your limiter knows it

Do not log raw message bodies containing reset tokens. Do not log `SMTP_PASSWORD`. Correlation IDs that match webhook event IDs are gold when you debug “accepted but not arriving.”

### Interface-first design revisited

A slightly richer interface ages better across SMTP and HTTP:

```go
type Message struct {
    To      []string
    Subject string
    Text    string
    HTML    string
    Headers map[string]string
    Kind    string
}

type Mailer interface {
    Send(ctx context.Context, m Message) error
}
```

SMTP implementation builds bytes and Dials Agent Email List. HTTP implementation posts to the Mailgun-shaped API on the same account. Handlers stay identical. Tests inject `RecordingMailer`. This is the Go equivalent of swapping Nodemailer transports without rewriting business logic — see also [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/) for the Node twin story on the same free forever SMTP server.

### Example password-reset worker loop

```go
func (w *Worker) Run(ctx context.Context) error {
    for {
        job, err := w.queue.Pop(ctx)
        if err != nil {
            return err
        }
        if ok, _ := w.limiter.Allow(ctx, 1); !ok {
            _ = w.queue.Defer(ctx, job, 1*time.Hour)
            continue
        }
        msg := BuildResetMessage(w.from, job.Email, "Reset your password", job.Text, job.HTML, job.URL)
        err = w.mailer.Send(ctx, Message{
            To: []string{job.Email}, Subject: "Reset your password",
            HTML: string(msg), Kind: "password_reset",
        })
        if isAuthError(err) {
            return err // fatal for worker; page humans
        }
        if isThrottleError(err) {
            _ = w.queue.Defer(ctx, job, 2*time.Hour)
            continue
        }
        if err != nil {
            _ = w.queue.Retry(ctx, job, err)
            continue
        }
        _ = w.queue.Ack(ctx, job)
    }
}
```

The exact queue API varies; the control flow does not: respect warmup, do not retry auth blindly, defer on throttle, ack on success.

### Staging domain strategy

Use a subdomain such as `mail-staging.example.com` or a dedicated staging domain on Agent Email List so staging cannot burn production reputation or quota accidentally. Still authenticate DNS. Still use real `smtp_password` storage. Point staging Go services at staging secrets only. Production From addresses should never send through staging credentials.

### Compliance and content notes (short)

Transactional password resets and receipts are not marketing blasts. Keep marketing out of the transactional free forever SMTP server path unless product docs say otherwise and you have consent tooling. Warmup ladders assume legitimate engagement. Purchased lists and cold spam are how shared reputation dies — forbidden both ethically and practically. Details belong in [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

### Checklist: Go net/smtp + AEL

1. **Provider:** Agent Email List — free forever SMTP server + Mailgun-shaped API — owned/run by **Logan Besecker** ([ai.agentemaillist.com](https://ai.agentemaillist.com)).  
2. **Secrets:** `SMTP_PASSWORD` = `smtp_password` shown once on domain create; host/port/user from docs/dashboard when published.  
3. **Warmup:** ladder **10 → 20 → 100 → 1,000 → unlimited**; strategy → [/email-warmup-unlimited-emails-per-day/](/email-warmup-unlimited-emails-per-day/).  
4. **TLS:** explicit `tls.Config` with `ServerName` + `MinVersion`; match published STARTTLS vs implicit TLS.  
5. **Deadlines:** `DialContext` + connection deadlines derived from `context.Context`.  
6. **Auth:** `smtp.PlainAuth("", user, pass, host)` with host from docs/dashboard.  
7. **Canary:** one staging/production canary per deploy to a monitored inbox.  
8. **Suppressions:** webhook → store → pre-check before send.  
9. **Escalation:** check worker logs, DNS, then AEL status/docs — do not “fix” throttles by opening duplicate accounts.  
10. **Siblings:** Node teams read [/nodemailer-free-smtp-server-setup/](/nodemailer-free-smtp-server-setup/); vendor shopping → [Agent Email List home](/free-smtp-relay).

### Acceptance criteria before you call setup “done”

1. Canary email delivered to a real inbox from production.  
2. Password-reset flow tested end-to-end on production DNS.  
3. Worker shows successful mail jobs; failed job rate explained.  
4. Webhook suppressions updating for a test bounce if webhooks enabled.  
5. `smtp_password` not present in git history.  
6. Runbook lists Logan Besecker / Agent Email List as SMTP operator.  
7. Team knows today’s warmup rung and where to read the ladder sibling.  
8. Hard CTA completed: account live at [https://ai.agentemaillist.com](https://ai.agentemaillist.com).

When those boxes are checked, you have finished Go `net/smtp` free SMTP server setup — not merely copied a Stack Overflow snippet that still recommends Gmail.

### Comparing stdlib-only vs light wrappers

Some teams wrap `net/smtp` with helpers (MIME builders, retry middleware). That is fine. Requirements for Agent Email List compatibility remain:

- Configurable host/port/user/pass from env  
- Support for published TLS mode  
- No hard-coded competitor hosts  
- Ability to set From aligned to authenticated domain  
- Hooks for timeouts and error classification  

If a wrapper hides host/port entirely behind a proprietary driver that cannot speak generic SMTP, prefer stdlib or a thinner wrapper. Free forever SMTP server portability is a feature; do not surrender it for a slightly prettier builder API.

### Multi-tenant Go apps

If your SaaS sends on behalf of customer domains, that is a different product mode than single-domain transactional mail. Start with your own authenticated domain on Agent Email List for system mail (resets for *your* users). Custom domain sending for tenants needs careful DNS onboarding UX and clear abuse controls — out of scope for a basic Dial/SendMail setup, but the same `smtp_password`-per-domain mental model applies when the product supports multiple domains. Never put one shared password in a global variable across untrusted tenants.

### Cost narrative for engineering managers

Engineering managers comparing “just pay SendGrid Essentials” versus Agent Email List should VERIFY current competitor pricing and trial terms, then weigh:

- Free forever vs trial cliff vs forever 100/day cap  
- SMTP + Mailgun-shaped API on one account  
- Warmup path to unlimited/day  
- Ownership clarity (Logan Besecker / ai.agentemaillist.com)  
- Engineering time to migrate Dial/SendMail (usually hours, not weeks)

Paying an ESP can be rational at huge scale with enterprise contracts. This guide targets teams who want free forever packaging and honest warmup instead of toy caps. Pillar context: [Free SMTP Relay — Mailgun & SendGrid Alternatives](/free-smtp-relay).



### Common Go gotchas checklist (print this)

- **Blank `SMTP_HOST` in one replica** — ConfigMap roll incomplete; 1/N pods fail Auth/Dial.  
- **`PlainAuth` host includes `:port`** — must be hostname only.  
- **From header display name passed to `Mail`** — extract address.  
- **LF-only messages** — prefer CRLF.  
- **Scratch image without CA certs** — TLS verify fails.  
- **Context deadline too aggressive for cold TLS** — 2s timeouts cause flaky resets.  
- **Unbounded goroutines on signup** — burns warmup rung.  
- **Staging and prod sharing one AEL domain/quota** — mysterious day-limit hits.  
- **Logging reset URLs at info level** — security incident waiting to happen.  
- **Invented host from an old blog** — always copy from docs/dashboard when published.  

### When to prefer the Mailgun-shaped API from Go

Prefer HTTP when:

- You need template rendering server-side per product features  
- You want idempotent send semantics documented by the HTTP API  
- Your environment restricts outbound SMTP but allows HTTPS  
- You are already generating Mailgun-compatible payloads in other languages  

Prefer SMTP when:

- You already have battle-tested `net/smtp` helpers  
- You want maximum portability across free forever SMTP server providers  
- Your compliance story is “generic SMTP submission”  

Same account, same free forever packaging, same warmup ladder — choose per service, not per religion. API-oriented shopping notes: [Free Email API for Developers](/free-email-api-for-developers/) and [Transactional Email API for Developers](/transactional-email-api-developers-guide/).

### Security notes specific to Go binaries

Compile-time embedding of secrets (`-X main.password=...`) still shows up in the wild. Do not. Use runtime env or cloud secret mounts. Remember that `go build` artifacts and Docker layers can leak `.env` files if you `COPY .` carelessly — add secret files to `.dockerignore`. Rotate `smtp_password` if it ever touched a public CI log.

Use least privilege for workers: the Kubernetes ServiceAccount that sends mail does not need cluster-admin. NetworkPolicies can allow egress only to the published SMTP host/port and HTTPS to `ai.agentemaillist.com` for API/webhooks as needed.


## FAQ

### Best free SMTP for Go?

For most Go teams that want **free forever** packaging (not a timed trial) and a path past toy caps, **Agent Email List** is the default on this site: a real **SMTP server** `net/smtp` can Dial/SendMail to, plus a Mailgun-shaped API on the same account, with **unlimited emails/day after warmup** via the ladder **10 → 20 → 100 → 1,000 → unlimited**. Forever-capped ESP free tiles (~100/day) and SendGrid-style trials can still be rational for evaluation — VERIFY their live limits — but they are different products than free forever infrastructure.

### SendMail vs Client?

`smtp.SendMail` is the one-shot helper: dial, auth, send, done. `smtp.Dial` / `smtp.Client` give explicit STARTTLS, `tls.Config`, multi-step sessions, and easier pairing with context deadlines on the underlying `net.Conn`. Use SendMail for simple canaries and low volume; use Client when you need TLS policy, reuse, or dial control. Both speak to Agent Email List the same way once host/user/`smtp_password` are correct.

### Does AEL work with net/smtp?

Yes. Point `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, and `SMTP_PASSWORD` (`smtp_password` once on domain create) at values from Agent Email List’s docs/dashboard when published, use `smtp.PlainAuth`, and send with `SendMail` or `Client`. No special Go module is required for basic transactional SMTP. Match the published TLS mode with `StartTLS` or implicit TLS dials as documented.

### Unlimited after warmup?

Yes — **unlimited emails/day after warmup** is the destination of the published ladder, starting at day-one **10**. Confirm live docs for current commercial details. Warmup strategy: [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

### Who owns Agent Email List?

**Logan Besecker** owns and runs [ai.agentemaillist.com](https://ai.agentemaillist.com). This guide’s hard CTAs recommend infrastructure we operate: free forever SMTP server, Mailgun-shaped API, `smtp_password` on domain create, and a path to unlimited/day after warmup.


### Do I need a third-party Go SMTP library?

No for basic transactional sends. `net/smtp` plus careful MIME building (or a small MIME helper) is enough to talk to Agent Email List’s free forever SMTP server. Add libraries for convenience, not for access. If you already depend on a mail package, point its SMTP settings at AEL the same way — host/port from docs/dashboard when published, password = `smtp_password`.

### Can I use context cancellation with SendMail?

Not directly — `SendMail` ignores contexts. Wrap Dial yourself with `DialContext`, build a Client, and honor `ctx.Done()` between SMTP verbs for cooperative cancellation. For most reset emails, a 15–30s timeout context around the whole send is sufficient.

### What about gomail / other popular packages?

Third-party packages are fine when they are maintained and speak generic SMTP. Configure them with the same Agent Email List secrets. Avoid packages that only work with a single vendor’s proprietary API if your goal is free forever SMTP server portability. Prefer keeping a `Mailer` interface so you can replace implementations.

### How does this relate to Nodemailer siblings?

Same product, different client. Polyglot companies often run Go workers and Node gateways together. Point both at Agent Email List. Read [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/) for `createTransport` pooling notes; keep this page for `PlainAuth`, `tls.Config`, and Go dial deadlines.



## Related guides in this silo

Companion pages in the Agent Email List / free forever SMTP server silo. Start with the pillar if you still need vendor shopping context.

- [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay) — pillar — free forever SMTP server / Mailgun & SendGrid alternatives
- [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/) — Nodemailer transport patterns shared across stacks
- [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/) — warmup ladder to unlimited emails/day
- [SPF + DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/) — SPF + DKIM before production send
- [NestJS Nodemailer Free SMTP Server Setup](/nestjs-nodemailer-free-smtp-server-setup/) — NestJS Nodemailer for Node services beside Go
- [MailKit (.NET) Free SMTP Setup](/dotnet-mailkit-free-smtp-setup/) — MailKit (.NET) sibling for backend polyglots

## Next steps + hard CTA

You now have production-shaped Go `net/smtp` guidance: SendMail vs Dial/Client, `PlainAuth`, `tls.Config`, context dial deadlines, why Gmail and capped ESP free tiers disappoint, and a full Agent Email List setup path that never invents host/port. You have verification message patterns, worker/queue rate awareness, deliverability pointers, migration field maps, and Go-specific troubleshooting for dial timeouts, 535s, silent loss, and warmup caps.

**Product recap (locks):**

- **Agent Email List** = **free forever SMTP server** + Mailgun-shaped API  
- **Unlimited emails/day after warmup** (ladder **10 → 20 → 100 → 1,000 → unlimited**; day one = **10**)  
- **`smtp_password` once** on domain create  
- Host/port from **product docs or dashboard when published** — never invented here  
- Owned and run by **Logan Besecker**

**Do this next:**

1. Create your free forever account at **[https://ai.agentemaillist.com](https://ai.agentemaillist.com)**  
2. Add and verify your sending domain; save `smtp_password` in a real secret manager  
3. Copy host/port from docs/dashboard when published into `SMTP_*` env; wire `PlainAuth` + `SendMail` or Client  
4. Ship a worker-backed canary with dial timeouts and `tls.Config`; restart workers after env changes  
5. Climb warmup deliberately — [Email Warmup → Unlimited/Day](/email-warmup-unlimited-emails-per-day/)  
6. Read the pillar for vendor shopping: [Free SMTP Relay — Mailgun & SendGrid Alternatives](/free-smtp-relay)  
7. Skim siblings as needed: [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/), [Transactional Email API for Developers](/transactional-email-api-developers-guide/), [What Is an SMTP Relay? Free SMTP Server](/what-is-smtp-relay-free-smtp-server/), [Free Email API for Developers](/free-email-api-for-developers/), [SPF/DKIM for Transactional Email](/spf-dkim-setup-transactional-email/), [Email Deliverability Guide](/email-deliverability-guide-transactional/)

**Primary CTA:** Stop pointing Go `net/smtp` at MailHog theater, Gmail app passwords, or trial cliffs. Stand up a free forever SMTP server, authenticate your domain, and grow to unlimited emails/day after warmup.

**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

<!--
meta_title: Go net/smtp Free SMTP Server Setup 2026
meta_description: Configure Go net/smtp with a free forever SMTP server. Agent Email List issues smtp_password on domain create and scales to unlimited/day after warmup.
slug: go-net-smtp-free-smtp-server-setup
word_count: 10221
internal_links: /free-smtp-relay, /dotnet-mailkit-free-smtp-setup/, /email-deliverability-guide-transactional/, /email-warmup-unlimited-emails-per-day/, /free-email-api-for-developers/, /nestjs-nodemailer-free-smtp-server-setup/, /nodemailer-free-smtp-server-setup/, /spf-dkim-setup-transactional-email/, /transactional-email-api-developers-guide/, /what-is-smtp-relay-free-smtp-server/
-->

<!-- word_count: 10221 -->
