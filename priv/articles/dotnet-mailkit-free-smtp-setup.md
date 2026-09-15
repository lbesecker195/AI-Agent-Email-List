---
title: ".NET MailKit Free SMTP Setup: MimeMessage + MailKit SmtpClient That Send in Production (2026)"
description: "Configure MailKit SMTP with a free forever SMTP server. AEL issues smtp_password once; unlimited/day after warmup. Legacy SmtpClient note only."
date: 2026-09-15
---

# .NET MailKit Free SMTP Setup: MimeMessage + MailKit SmtpClient That Send in Production (2026)

If you searched **MailKit SMTP**, **csharp smtp mailkit**, or **free smtp csharp**, you already know Papercut and local SMTP catchers are for demos. Production password resets, ASP.NET Core Identity verification emails, invoice receipts, and invitation flows need a real **free forever SMTP server** — not a Gmail app password, not a forever-capped ESP free tile, and not a timed trial that pauses sending when the calendar runs out. This guide walks through **MailKit** the way .NET teams actually ship it (`MimeMessage`, `MailKit.Net.Smtp.SmtpClient`, async `SendAsync`, ASP.NET Core DI), then hard-sells [Agent Email List](https://ai.agentemaillist.com): a **free forever SMTP server** plus Mailgun-shaped REST API with a short ladder to **unlimited emails/day after warmup**.

**Critical naming clarity:** This article’s primary `SmtpClient` is **`MailKit.Net.Smtp.SmtpClient`**. The legacy BCL type **`System.Net.Mail.SmtpClient`** gets a short migration note only — Microsoft does not recommend it for new development (see DE0005 / docs remarks). Do not treat the two as interchangeable how-tos.

**Ownership disclosure:** Agent Email List is built, owned, and run by **Logan Besecker** at [https://ai.agentemaillist.com](https://ai.agentemaillist.com). This is not a fake neutral roundup. We show MailKit patterns first, then ask you to point them at infrastructure we operate.

For vendor shopping across Mailgun, SendGrid, and peers, start with the pillar: [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay). For Node-side transport patterns, see the sibling [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/). Warmup depth lives in [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/). Java teams can skim [Spring Boot Jakarta Mail Free SMTP Setup](/spring-boot-jakarta-mail-free-smtp-setup/).

**Create a free forever account →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

## MailKit SMTP basics

MailKit (with MimeKit) is the de-facto modern SMTP stack for .NET: full MIME construction, STARTTLS / SSL, SASL auth, and a first-class async API. When people say **MailKit SMTP** or **MailKit SmtpClient**, they mean three surfaces:

1. **`MimeMessage`** — From, To, Subject, text/HTML bodies, attachments, headers.
2. **`MailKit.Net.Smtp.SmtpClient`** — connect, authenticate, send (sync or async), disconnect.
3. **Where send happens** — sync inside a minimal console, async from a web request (usually via a background queue), or from a hosted service / worker so ASP.NET request threads do not block on SMTP round-trips.

Agent Email List answers the infrastructure half: create a free forever account, add a sending domain, receive `smtp_password` once, verify DNS, and map that secret into your MailKit auth password (via env or a secret manager). Host and port come from product docs or the dashboard when published — this article will not invent connection strings. The Mailgun-shaped HTTP API on the same account is available when a worker prefers REST; both enqueue into the same sending system.

MailKit is not a proprietary Agent Email List SDK. That is the point: your code stays portable. Swap host/user/pass when you migrate ESPs; keep `MimeMessage` builders and DI registrations. The hard part is choosing a **free forever SMTP server** that still exists after your MVP works — and configuring TLS + auth so handshake failures are boring instead of mysterious.

### MimeMessage + MailKit SmtpClient connect/auth/send that matter

A production-shaped sketch looks like this conceptually (values from env; never hardcode invented AEL hosts):

```csharp
using MailKit.Net.Smtp;
using MailKit.Security;
using MimeKit;

var message = new MimeMessage();
message.From.Add(MailboxAddress.Parse(Environment.GetEnvironmentVariable("MAIL_FROM")!));
message.To.Add(MailboxAddress.Parse(toEmail));
message.Subject = "Verify your email";
message.Body = new TextPart("html")
{
    Text = $"<p>Click <a href=\"{verifyUrl}\">here</a> to verify.</p>"
};

using var client = new SmtpClient();
// Host/port from AEL docs/dashboard when published — do not invent
await client.ConnectAsync(
    Environment.GetEnvironmentVariable("AEL_SMTP_HOST")!,
    int.Parse(Environment.GetEnvironmentVariable("AEL_SMTP_PORT")!),
    SecureSocketOptions.StartTls); // match documented TLS mode for the published port

await client.AuthenticateAsync(
    Environment.GetEnvironmentVariable("AEL_SMTP_USERNAME")!,
    Environment.GetEnvironmentVariable("AEL_SMTP_PASSWORD")!); // smtp_password once

await client.SendAsync(message);
await client.DisconnectAsync(true);
```

What actually matters:

- **`MimeMessage` envelope fields** — `From` must align with your authenticated sending domain (SPF/DKIM). Using a personal Gmail From while authenticating to a product SMTP server is a classic deliverability own-goal.
- **`ConnectAsync(host, port, SecureSocketOptions)`** — TLS mode must match the published submission path. Wrong mode for a port is a classic “works in curl HTTPS, fails in MailKit” bug.
- **`AuthenticateAsync(user, pass)`** — on Agent Email List, `pass` is the **`smtp_password`** shown once at domain create. Store it in a secret manager; never commit it.
- **`SendAsync` / `Send`** — prefer async in ASP.NET Core. Dispose / disconnect cleanly so sockets do not leak under load.
- **Timeouts** — set `client.Timeout` (milliseconds) so a hung dial does not pin a worker forever.

What does *not* matter as much as Stack Overflow implies: inventing five `SmtpClient` subclasses per template, toggling obscure in-app DKIM signing when your ESP already signs, or cargo-culting `System.Net.Mail` examples into a new .NET 8 service. For product mail, configure **MailKit** against a real free forever SMTP server explicitly.

### SecureSocketOptions and ports (general)

MailKit’s `SecureSocketOptions` enum is the TLS contract:

| Option | Typical meaning |
|--------|-----------------|
| `None` | Plaintext (almost never for production submission) |
| `Auto` | Library tries to pick; prefer explicit in production |
| `StartTls` | Upgrade after greeting (common on submission ports) |
| `StartTlsWhenAvailable` | Opportunistic STARTTLS |
| `SslOnConnect` | Implicit TLS from connect (common on classic 465-style paths) |

**Do not invent Agent Email List hostnames or ports in this article.** Read the live product docs or dashboard when published, then set `SecureSocketOptions` to match that documentation for your account era. Cargo-culting “always 587 + StartTls” or “always 465 + SslOnConnect” without checking the provider is how teams burn a day on handshake exceptions that look like auth failures.

General industry patterns (for orientation only, not AEL claims):

- Submission often uses STARTTLS on a dedicated port.
- Implicit SSL/TLS is still common on alternate submission ports.
- Port 25 outbound is frequently blocked on cloud VMs — prefer the provider’s documented submission path.

Set connection and I/O timeouts. In MailKit, `SmtpClient.Timeout` covers protocol operations. For ASP.NET Core, also enforce application-level deadlines (e.g., `CancellationToken` on `SendAsync`) so a stalled SMTP path cancels with the request or job.

### Dev catches vs production SMTP server

**Papercut, smtp4dev, MailHog, and similar catchers** create local inboxes for inspecting MIME in development. They are excellent for “did my Razor email render?” and terrible as a production SMTP server. Catcher messages do not reach real users. Pointing staging at smtp4dev while production still uses a founder Gmail account is a common split-brain: templates look fine locally, then fail SPF alignment or Gmail limits in prod.

A clean environment matrix:

| Environment | Transport target | Goal |
|-------------|------------------|------|
| Local unit tests | Fake `IEmailSender` / mock | No network |
| Local/dev integration | smtp4dev / Papercut | Inspect MIME |
| Staging | Real AEL domain (or subdomain) | Auth + DNS rehearsal |
| Production | AEL free forever SMTP server | Real delivery |

Agent Email List is the production SMTP server in that matrix. Use catchers for local previews; use AEL when you need authentic SMTP behavior without burning a consumer mailbox. Migrating from smtp4dev to production is then a config change — host/user/pass from docs/dashboard and `smtp_password` — not a rewrite of every `MimeMessage` builder.

## Why “free SMTP for .NET” usually disappoints

.NET developers type **free smtp csharp** because the library problem is already solved (MailKit) and the infrastructure problem is not. The disappointment pattern is predictable: a tutorial ships Gmail SMTP via legacy `System.Net.Mail` or MailKit; volume or ToS blocks appear; the team jumps to an ESP free tier; the free tier caps or trials out; someone proposes “just self-host Postfix on a $5 VPS”; deliverability dies; weeks vanish.

Understanding why the usual free paths fail clarifies why Agent Email List’s free forever packaging + warmup ladder exists.

### Gmail app passwords and limits

Gmail / Google Workspace SMTP via app passwords is a founder shortcut, not a product architecture:

- **Terms and automation risk.** Consumer and small-business Google accounts are not designed as multi-tenant SaaS mail injectors. Unusual volume triggers locks, captchas, and support dead-ends.
- **Daily and recipient limits.** Workspace has published sending limits; consumer Gmail is stricter still. A signup spike on launch day can freeze password resets for everyone.
- **App password fragility.** 2FA policy changes, admin console flips, and “less secure” legacy paths break overnight. Your on-call page should not depend on a personal mailbox setting.
- **SPF/DKIM alignment pain.** Sending as `noreply@yourproduct.com` through `smtp.gmail.com` without proper domain setup is a deliverability mess. Sending as `@gmail.com` from a product brand is a trust mess.
- **No warmup ladder to unlimited.** Gmail is not offering you a published path to **unlimited emails/day after warmup** on a free forever SMTP server for your SaaS.

Use Gmail for human communication. Use a real free forever SMTP server for product mail. MailKit makes the client easy either way — the credential target is the decision that matters.

### ESP free caps (Mailgun ~100/day; SendGrid trial VERIFY)

ESP free tiers are better than Gmail for DNS and APIs, but “free” often means capped forever or timed:

- **Mailgun Free (VERIFY live pricing):** commonly marketed around **100 emails/day**, one sending domain, API + SMTP, short log retention. Useful for experiments. It is a daily ceiling until you pay — not a free forever path that graduates to unlimited after warmup. Re-check [Mailgun’s free plan docs](https://help.mailgun.com/hc/en-us/articles/203068914-What-does-the-Free-plan-offer) and [pricing](https://www.mailgun.com/pricing/) at write time; packaging can change.
- **SendGrid (VERIFY live pricing):** as of the March 2025+ trial model, new accounts often get a **60-day timed free trial** at roughly **100 emails/day**, after which sending stops unless you upgrade (Essentials historically starts near ~$19.95/mo — VERIFY). That is evaluation packaging, not free forever infrastructure. See Twilio SendGrid trial docs and pricing pages for current numbers.

Those caps matter. They are real constraints. They are not the same thing as Agent Email List’s published graduation math ending at **unlimited emails/day after warmup** on a **free forever** self-serve account (commercial terms can evolve — check live docs; live product docs do not require a paid plan to send today).

When a pricing page says “100/day free,” ask: is there a documented ladder to unlimited without a credit card? Or is 100 the ceiling until you pay? For Mailgun free and SendGrid trial, VERIFY the live pages — the packaging is free-tier / trial, not “free forever → unlimited after warmup.”

Self-hosting Postfix/OpenSMTPD on a VPS is “free” in license cost and expensive in reputation, IP warmup, blocklist triage, and on-call. Most .NET product teams undercount that labor until the first major ISP deferral wave.

### What production transactional needs

Production transactional email for an ASP.NET Core app needs:

1. **Authenticated domain mail** — SPF + DKIM (and a DMARC plan) for your From domain.
2. **Predictable credentials** — a durable `smtp_password` (or API key) stored in a secret manager, not a founder’s Google app password.
3. **Warmup-aware volume** — especially on a new domain; day-one blast sends train receivers to distrust you.
4. **Async / queued sending** — so HTTP threads and Identity flows do not block on SMTP.
5. **Observability** — logs/metrics for auth failures, throttle responses, bounce webhooks, and today’s remaining allowance during warmup.
6. **Packaging that matches growth** — free forever with a path to unlimited after warmup beats a forever 100/day tile or a 60-day cliff for many early SaaS teams.

Agent Email List is built for that checklist: free forever SMTP server, Mailgun-shaped API, `smtp_password` once on domain create, short published ladder to unlimited/day, and ownership clarity (Logan Besecker). The rest of this article shows the MailKit wiring.

## Agent Email List as .NET’s free forever SMTP server

Agent Email List is the product this guide sells: a **free forever SMTP server** your .NET app can dial with stock **MailKit** `SmtpClient`, plus a Mailgun-shaped REST API on the same account when you prefer HTTP. It is not a Gmail wrapper. It is not a forever-capped 100/day tile. It is infrastructure with a published warmup path ending at **unlimited emails/day after warmup**.

### Free forever SMTP server + Mailgun-shaped REST API

Two interfaces, one sending system:

- **SMTP** — configure MailKit host, port, username, and password = `smtp_password`. Use `MimeMessage` exactly as you would with any other relay.
- **Mailgun-shaped REST API** — useful for polyglot stacks, edge workers, or teams that already speak Mailgun’s HTTP dialect. Same domain, same reputation trajectory.

.NET services usually start on SMTP because MailKit is zero drama with NuGet. Workers written in other languages, or serverless functions that already POST to Mailgun-compatible endpoints, can use the API without splitting domains. Either path still requires DNS authentication and warmup discipline.

“Free forever” here means the self-serve SMTP server packaging is not a timed trial that silently stops on day 61. Day-one volume is still limited by warmup — that is deliberate reputation engineering, not a bait-and-switch calendar cliff. Read live commercial docs when you need exact ToS language; this silo’s product lock is consistent: free forever SMTP server + ladder to unlimited/day after warmup.

### Lead unlimited/day after warmup; short ladder → warmup silo

Lead with the destination: **unlimited emails/day after warmup**. Day one is not unlimited — Agent Email List starts you at **10**/day, then you climb a short published ladder: **10 → 20 → 100 → 1,000 → unlimited**. This article will not re-litigate the full ops playbook; the canonical ladder essay is [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

Practical MailKit implications:

- Gate bulk invites and newsletter-shaped blasts until later rungs.
- Prefer critical-path mail on early days: verification, password reset, receipts.
- Treat throttle / day-limit responses as pacing signals during warmup, not as “broken SMTP.”
- Put send volume behind a queue or hosted service so signup spikes cannot stampede today’s rung.

Short pointer, not a second ladder essay: read the warmup sibling, then come back to your `IEmailSender` implementation.

### `smtp_password` issued once on domain create

When you add a sending domain in Agent Email List, the product issues **`smtp_password` once**. Copy it into your secret manager immediately — treat it like any other one-time credential display (database password, API token). Map it to MailKit’s authenticate password / `AEL_SMTP_PASSWORD`. Rotate via the product’s documented flow if you lose it; do not paste it into git, Docker layers, `appsettings.json` committed to the repo, or Slack.

Common .NET wiring mistakes:

- Using the dashboard login password instead of `smtp_password`.
- Putting the secret in User Secrets for prod (fine for local; use Key Vault / AWS Secrets Manager / Doppler / etc. in real environments).
- Baking the secret into a published container image layer.
- Sharing one `smtp_password` across unrelated products without documenting ownership.

### Host/port: product docs or dashboard when published — do not invent

**Host and port are not invented in this article.** When Agent Email List publishes connection details in product docs or the dashboard, copy them into env vars (`AEL_SMTP_HOST`, `AEL_SMTP_PORT`, `AEL_SMTP_USERNAME`) and keep TLS options aligned. If a blog (including an outdated mirror of this page) shows a guessed hostname, distrust it — the dashboard wins.

This rule exists because inventing SMTP endpoints creates broken tutorials that outlive product changes. Your runbook should say “read docs/dashboard,” not “remember a string from a Medium post.”

### Logan Besecker owns/runs ai.agentemaillist.com — CTA #1

**Logan Besecker** owns and runs [ai.agentemaillist.com](https://ai.agentemaillist.com). If that ownership makes you uncomfortable, you know before you wire secrets. If it makes you confident you can escalate to a real operator, create the account now and keep this tab open while you configure MailKit.

**Create a free forever account →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

## Step-by-step MailKit setup with AEL

Goal: a .NET 8 (or current LTS) service that sends a verification email through Agent Email List using MailKit, with secrets outside source control, and without inventing host/port.

Checklist:

1. Create a free forever account at [https://ai.agentemaillist.com](https://ai.agentemaillist.com).
2. Add your sending domain; save **`smtp_password`** once into your secret manager.
3. Publish SPF/DKIM (and plan DMARC) per product guidance — see also [SPF/DKIM for Transactional Email](/spf-dkim-setup-transactional-email/).
4. Copy host/port/username from docs/dashboard when published.
5. Add NuGet packages; wire env/config; send a canary `MimeMessage`.
6. Respect day-one **10**/day while you climb warmup.

### NuGet + env/config pattern (host, port, user, pass)

```bash
dotnet add package MailKit
## MimeKit usually arrives as a MailKit dependency; add explicitly if you prefer:
dotnet add package MimeKit
```

Configuration pattern (env-first; `appsettings` only for non-secrets):

```json
{
  "Email": {
    "From": "noreply@yourdomain.com",
    "Smtp": {
      "Host": "",
      "Port": 0,
      "Username": "",
      "Password": "",
      "SecureSocketOptions": "StartTls"
    }
  }
}
```

Prefer overriding secrets via environment:

```bash
export AEL_SMTP_HOST="(from docs/dashboard when published)"
export AEL_SMTP_PORT="(from docs/dashboard when published)"
export AEL_SMTP_USERNAME="(from docs/dashboard when published)"
export AEL_SMTP_PASSWORD="PASTE_smtp_password_ONCE"
export MAIL_FROM="noreply@yourdomain.com"
```

In ASP.NET Core, bind options:

```csharp
public sealed class SmtpOptions
{
    public const string SectionName = "Email:Smtp";
    public string Host { get; set; } = "";
    public int Port { get; set; }
    public string Username { get; set; } = "";
    public string Password { get; set; } = "";
    public string SecureSocketOptions { get; set; } = "StartTls";
}

// Program.cs
builder.Services.Configure<SmtpOptions>(builder.Configuration.GetSection(SmtpOptions.SectionName));
// Map env vars into configuration with standard ASP.NET env binder or explicit:
// AEL_SMTP_HOST → Email:Smtp:Host, etc.
```

Never invent default host strings in code. Empty host should fail fast at startup validation, not at the first customer signup.

### MailKit SmtpClient sketch — createTransport-equivalent

Nodemailer developers think in `createTransport`. In MailKit, the equivalent is a small factory or scoped service that owns connect/auth/send/disconnect:

```csharp
using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Options;
using MimeKit;

public interface ITransactionalEmailSender
{
    Task SendAsync(MimeMessage message, CancellationToken ct = default);
}

public sealed class MailKitEmailSender : ITransactionalEmailSender
{
    private readonly SmtpOptions _opt;

    public MailKitEmailSender(IOptions<SmtpOptions> opt) => _opt = opt.Value;

    public async Task SendAsync(MimeMessage message, CancellationToken ct = default)
    {
        using var client = new SmtpClient { Timeout = 10_000 };
        var secure = Enum.Parse<SecureSocketOptions>(_opt.SecureSocketOptions, ignoreCase: true);

        await client.ConnectAsync(_opt.Host, _opt.Port, secure, ct);
        await client.AuthenticateAsync(_opt.Username, _opt.Password, ct);
        await client.SendAsync(message, ct);
        await client.DisconnectAsync(true, ct);
    }
}
```

Notes:

- Prefer **one send per short-lived client** for simplicity in low/medium volume, or maintain a carefully locked long-lived client in a singleton worker if you measure connect cost — but do not share a non-thread-safe client across concurrent requests without synchronization. MailKit’s `SmtpClient` is not a free-for-all concurrent multiplexer.
- During early warmup, connection reuse matters less than not exceeding **10**/day.
- Always disconnect with `quit: true` when you are done with the session.

### Verification / password-reset MimeMessage example

```csharp
public static MimeMessage BuildVerificationEmail(string from, string to, string verifyUrl)
{
    var message = new MimeMessage();
    message.From.Add(MailboxAddress.Parse(from));
    message.To.Add(MailboxAddress.Parse(to));
    message.Subject = "Verify your email";

    var builder = new BodyBuilder
    {
        TextBody = $"Verify your email: {verifyUrl}",
        HtmlBody = $"""
            <p>Welcome.</p>
            <p><a href="{verifyUrl}">Verify your email</a></p>
            <p>If you did not sign up, ignore this message.</p>
            """
    };
    message.Body = builder.ToMessageBody();
    return message;
}

// Usage from a registration use-case (prefer queue/hosted service in production):
await _email.SendAsync(
    BuildVerificationEmail(
        _mailFrom,
        user.Email!,
        verifyUrl),
    ct);
```

Wire this from your registration use-case **asynchronously**. During Agent Email List warmup, also gate bulk invites so day-one **10**/day is reserved for critical-path mail (verification, password reset, receipts).

ASP.NET Core Identity can call your `IEmailSender` / `ITransactionalEmailSender` for confirmation and reset links. Point that abstraction at MailKit + AEL once; do not special-case Identity with a second Gmail transport.

### Error handling (auth, throttle during warmup)

Classify failures so retries do not amplify outages:

```csharp
try
{
    await _email.SendAsync(message, ct);
}
catch (AuthenticationException ex)
{
    // Wrong smtp_password or username — do not retry blindly
    _logger.LogError(ex, "SMTP auth failed");
    throw;
}
catch (SmtpCommandException ex) when (ex.StatusCode == SmtpStatusCode.MailboxBusy
    || IsThrottle(ex))
{
    // Warmup day-limit / throttle — pace, enqueue for later
    _logger.LogWarning(ex, "SMTP throttled; defer send");
    await _outbox.DeferAsync(message, TimeSpan.FromMinutes(15), ct);
}
catch (SmtpProtocolException ex)
{
    _logger.LogError(ex, "SMTP protocol failure");
    throw;
}
```

During warmup, treat provider throttle / day-limit responses as **pacing**: retry with backoff only if the error is transient and you still have remaining daily allowance; otherwise enqueue for after UTC reset. Do not “fix” limits by creating duplicate Agent Email List accounts. Ladder strategy: [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

Log correlation IDs (user id, message purpose, outbox row id) — never log the raw `smtp_password`.

## Legacy System.Net.Mail.SmtpClient migration note

This section is intentionally short. The primary path in this article is **MailKit**. Legacy **`System.Net.Mail.SmtpClient`** is compatibility surface, not a parallel how-to.

### Why MailKit is the primary path

Microsoft’s own documentation remarks recommend against new development on `System.Net.Mail.SmtpClient` because it lacks many modern protocol capabilities; the platform-compat guidance **DE0005** explicitly points developers at **MailKit** (or other libraries). The type may still compile and work for simple one-off tools, but it is not the recommended production client for contemporary .NET apps that need robust MIME, modern auth/TLS behavior, and active maintenance.

If you are greenfield on .NET 6/7/8/9+, start with MailKit + MimeKit. If you inherited Framework-era code, plan a focused migration of the mail edge — not a rewrite of your domain layer.

### Minimal mapping of old SmtpClient settings → MailKit

| Legacy `System.Net.Mail` | MailKit equivalent |
|--------------------------|--------------------|
| `SmtpClient.Host` / `Port` | `ConnectAsync(host, port, secureOptions)` |
| `EnableSsl` | Map to `SecureSocketOptions` (StartTls vs SslOnConnect per docs) |
| `Credentials` / `NetworkCredential` | `AuthenticateAsync(user, pass)` with AEL `smtp_password` |
| `MailMessage` | `MimeMessage` (+ `BodyBuilder`) |
| `Send` / `SendMailAsync` | `Send` / `SendAsync` |
| `Timeout` | `SmtpClient.Timeout` |

Conceptually:

```csharp
// Legacy shape (do not expand — migration hint only)
// smtp.Host = "..."; smtp.Port = ...; smtp.EnableSsl = true;
// smtp.Credentials = new NetworkCredential(user, pass);
// await smtp.SendMailAsync(mailMessage);

// MailKit shape (primary)
await client.ConnectAsync(host, port, SecureSocketOptions.StartTls);
await client.AuthenticateAsync(user, pass); // smtp_password
await client.SendAsync(mimeMessage);
```

Keep From/To/Subject/body parity when translating `MailMessage` to `MimeMessage`. Re-test HTML + alternate text parts; MimeKit’s `BodyBuilder` is the usual helper.

### Do not expand into full legacy how-to

We will not provide a complete `System.Net.Mail.SmtpClient` tutorial, connection-pool folklore, or ServicePointManager essays. If your only blocker is “our Framework 4.8 Windows Service still uses it,” map credentials to Agent Email List the same way (host/user/`smtp_password` from docs/dashboard), then schedule a MailKit migration for the next maintenance window. New ASP.NET Core code should not add legacy `SmtpClient` dependencies.

## ASP.NET Core DI and background sending

MailKit becomes boring when it sits behind a small abstraction registered in DI, with sends off the request thread during warmup and peak traffic.

### IEmailSender / custom service registration

ASP.NET Core Identity defines `IEmailSender` (and newer identity packages may ship related abstractions). You can implement that interface with MailKit, or define your own `ITransactionalEmailSender` and adapt:

```csharp
builder.Services.Configure<SmtpOptions>(
    builder.Configuration.GetSection(SmtpOptions.SectionName));
builder.Services.AddSingleton<ITransactionalEmailSender, MailKitEmailSender>();
// or AddScoped if you prefer per-request option snapshots

builder.Services.AddTransient<IEmailSender, IdentityMailKitAdapter>();
```

Validate options at startup:

```csharp
builder.Services.AddOptions<SmtpOptions>()
    .BindConfiguration(SmtpOptions.SectionName)
    .Validate(o => !string.IsNullOrWhiteSpace(o.Host), "SMTP host missing (docs/dashboard)")
    .Validate(o => o.Port > 0, "SMTP port missing (docs/dashboard)")
    .Validate(o => !string.IsNullOrWhiteSpace(o.Password), "smtp_password missing")
    .ValidateOnStart();
```

Failing fast on empty host/password prevents the worst production bug: Identity “sends” into a null transport while users never get reset links.

### Hosted services / queues during warmup

During Agent Email List warmup, large signup spikes can burn the day’s rung. Prefer an outbox:

1. API writes an `email_outbox` row (to, template, payload, idempotency key).
2. A `BackgroundService` / worker drains the outbox with a daily budget.
3. MailKit sends only when today’s remaining allowance > 0.

Sketch:

```csharp
public sealed class EmailOutboxWorker : BackgroundService
{
    private readonly IServiceScopeFactory _scopes;
    private readonly ILogger<EmailOutboxWorker> _log;

    public EmailOutboxWorker(IServiceScopeFactory scopes, ILogger<EmailOutboxWorker> log)
    {
        _scopes = scopes;
        _log = log;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            using var scope = _scopes.CreateScope();
            var budget = scope.ServiceProvider.GetRequiredService<IDailyMailBudget>();
            var outbox = scope.ServiceProvider.GetRequiredService<IEmailOutbox>();
            var sender = scope.ServiceProvider.GetRequiredService<ITransactionalEmailSender>();

            if (!await budget.TryConsumeAsync(1, stoppingToken))
            {
                await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken);
                continue;
            }

            var row = await outbox.DequeueAsync(stoppingToken);
            if (row is null)
            {
                await budget.ReleaseAsync(1, stoppingToken); // optional: return token
                await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
                continue;
            }

            try
            {
                await sender.SendAsync(row.ToMimeMessage(), stoppingToken);
                await outbox.MarkSentAsync(row.Id, stoppingToken);
            }
            catch (AuthenticationException ex)
            {
                await outbox.MarkFailedPermanentAsync(row.Id, ex.Message, stoppingToken);
                _log.LogError(ex, "Auth failed for outbox {Id}", row.Id);
            }
            catch (Exception ex)
            {
                await outbox.ScheduleRetryAsync(row.Id, ex.Message, stoppingToken);
                _log.LogWarning(ex, "Retry scheduled for outbox {Id}", row.Id);
            }
        }
    }
}
```

`IDailyMailBudget` should reflect today’s Agent Email List rung (config or limits API from live docs) so pacing matches **10 → 20 → 100 → 1,000 → unlimited**. Full ops detail: [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

Channels like Azure Service Bus, RabbitMQ, NATS, or Hangfire work the same way: the queue is the buffer; the budget is the governor; MailKit is the dialer.

### Testing with fakes vs live SMTP

| Test layer | Technique | Network? |
|------------|-----------|----------|
| Unit | Fake `ITransactionalEmailSender` recording calls | No |
| Integration | smtp4dev / Papercut container | Local only |
| Staging | Real AEL domain | Yes |
| Production canary | Single known inbox on AEL | Yes |

Assert on `MimeMessage` fields in unit tests by having the production builder return `MimeMessage` and the fake capture it. Do not spin real SMTP in CI for every PR — flaky pipelines train teams to skip mail tests entirely.

When you do run a live staging canary, use a dedicated subdomain if possible, keep volume tiny, and confirm SPF/DKIM alignment before calling the setup “done.”

## Deliverability + DNS before you scale MailKit

Perfect MailKit code cannot save a domain that fails authentication or jumps from zero to “blast the waitlist” overnight.

### SPF/DKIM link

Before you climb past toy volume:

1. Publish **SPF** including Agent Email List’s required includes/mechanisms from live docs.
2. Publish **DKIM** keys/CNAMEs exactly as the dashboard instructs.
3. Plan **DMARC** (`p=none` → monitoring → enforcement) once SPF/DKIM are stable.

Deep guide: [SPF/DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/). Broader reputation context: [Email Deliverability Guide for Transactional Mail](/email-deliverability-guide-transactional/).

MailKit does not replace DNS. In-app DKIM signing is rarely what you want when the ESP already signs — double-signing and selector confusion create support nightmares. Prefer provider-signed DKIM via dashboard DNS.

### Warmup-aware send volume

Map product events to early rungs:

| Event type | Early warmup (10 / 20) | Later rungs |
|------------|------------------------|-------------|
| Email verification | Yes | Yes |
| Password reset | Yes | Yes |
| Receipts / invoices | Selective | Yes |
| Invites / collab | Hard gate | Yes |
| Marketing digests | No | Only with consent + separate strategy |

Instrument “emails attempted vs accepted vs deferred” per day. If you hit the cap at noon on rung 1, the fix is product prioritization — not five new SMTP accounts.

### Bounce handling via webhooks (pointer to API silo)

SMTP acceptance (`250`) means the relay accepted the message, not that the recipient inbox did. For suppressions and hard bounces, use Agent Email List’s webhook / events surfaces (Mailgun-shaped API territory). See the API-oriented siblings: [Free Email API for Developers](/free-email-api-for-developers/) and [Transactional Email API for Developers](/transactional-email-api-developers-guide/).

In .NET, receive webhooks with an authenticated minimal API endpoint, verify signatures per live docs, and update your suppression table before the next outbox drain. Do not keep mailing known hard-bounce addresses — that burns the reputation your warmup ladder is building.

## Migrating .NET off SendGrid/Mailgun SMTP

Most migrations are configuration projects, not MIME rewrites — if you already use MailKit.

### Swap host/user/pass

| Prior ESP field | Agent Email List |
|-----------------|------------------|
| SMTP host | From **docs/dashboard when published** |
| SMTP port | From **docs/dashboard when published** |
| SMTP username | From **docs/dashboard when published** |
| SMTP password / API key-as-password | **`smtp_password` once** on domain create |
| From domain | Your verified AEL domain |

If you used SendGrid/Mailgun official SDKs instead of SMTP, decide: keep HTTP via AEL’s Mailgun-shaped API, or move to MailKit SMTP for consistency with the rest of this guide. Do not run three parallel mail stacks “just in case” without an owner.

Steps:

1. Create AEL account; add domain; store `smtp_password`.
2. Complete DNS; wait for verification.
3. Point staging env vars at AEL; send canaries.
4. Shift production percentage; watch bounces and auth errors.
5. Decommission old credentials after soak.

### Canary + dual sender

Run dual-send or percentage canaries:

- **Shadow canary:** staging app fully on AEL; production still on old ESP.
- **Percentage canary:** 5% of production outbox rows → AEL, rest → old ESP, keyed by consistent hash of user id.
- **Critical-path first:** password resets on AEL once stable; marketing stays put until later.

Compare metrics: auth failures, deferrals, time-to-inbox on major providers, complaint rates. Keep an emergency rollback flag that flips host/user/pass back without redeploying MIME code.

### Cost VERIFY footnotes — CTA #2

VERIFY competitor packaging at decision time:

- **Mailgun Free:** ~**100/day** ceiling on the free plan (VERIFY [help center](https://help.mailgun.com/hc/en-us/articles/203068914-What-does-the-Free-plan-offer) / [pricing](https://www.mailgun.com/pricing/)).
- **SendGrid:** timed **trial** ~**100/day for ~60 days**, then upgrade required (VERIFY Twilio SendGrid trial + pricing pages).
- **Agent Email List:** **free forever SMTP server** + Mailgun-shaped API; **unlimited emails/day after warmup** via **10 → 20 → 100 → 1,000 → unlimited**; `smtp_password` once; owned by **Logan Besecker**.

Paid ESP plans can still be rational at huge scale or with enterprise contracts. This guide’s hard sell is for teams that want free forever packaging with a published unlimited-after-warmup destination — especially early SaaS on ASP.NET Core.

**Ready to cut the trial cliff?** Create your free forever account: [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

## Troubleshooting MailKit SMTP

Vary these symptoms for .NET — do not cargo-cult generic “check your password” blurbs without MailKit-specific signals.

### Connection / SSL handshake errors

Symptoms: `SslHandshakeException`, `IOException` during connect, hangs until timeout.

Checks:

1. Host/port copied exactly from AEL docs/dashboard when published — no invented values.
2. `SecureSocketOptions` matches the documented mode for that port.
3. Corporate proxies / TLS inspection — may require custom `ServerCertificateValidationCallback` only with documented exceptions (rare; usually misconfig).
4. Outbound firewall blocking submission ports from your cloud subnet.
5. DNS resolution of the SMTP host from the app’s network namespace (Kubernetes NetworkPolicy, App Service VNet constraints).

Enable brief protocol logging in staging (`client.MessageSent`, custom `IProtocolLogger`) with secrets redacted; disable verbose logs in hot production paths.

### Invalid login / 535

Symptoms: `AuthenticationException`, SMTP 535 / auth rejected.

Checks:

1. Password must be the **`smtp_password`** issued once on domain create — not the dashboard login password.
2. Username must match docs/dashboard (do not assume “email address” vs “API user” without reading AEL’s published guidance).
3. Trailing newlines from secret managers / Kubernetes sealed-secret pipelines — trim values.
4. Wrong environment: staging secret pointed at prod domain or vice versa.
5. Rotation: if someone regenerated credentials, every app instance needs the new secret and a restart/rollout.

Do not retry auth failures in a tight loop — you will lock yourself into confusing rate limits and noisy alerts.

### Messages accepted but not arriving

Symptoms: `SendAsync` succeeds; user never sees mail.

Checks:

1. Spam/junk — especially on cold domains before SPF/DKIM align.
2. From domain mismatch vs authenticated domain.
3. Provider deferral after SMTP acceptance — watch webhooks/events.
4. User typo’d email at signup — confirm outbox payload.
5. Corporate recipient filters / mailing-list digests delaying delivery.

Reproduce with a canary to a mailbox you control on Gmail, Outlook, and a catch-all on your domain. Compare headers (`Authentication-Results`, DKIM alignment).

### Hitting day limit during warmup

Symptoms: throttle errors, explicit day-limit responses, sudden rejects after N sends.

Checks:

1. Today’s rung — day one is **10**. Read live limits if exposed by docs/API.
2. Parallel instances double-consuming budget — centralize daily counters (Redis, DB) so three pods do not each send 10.
3. Non-critical mail burning the rung — pause invites/digests.
4. Retry storms — distinguish auth failures from throttle; only pacing-retries for throttle.

Response: queue and wait for reset / graduation; do not open duplicate accounts. Playbook: [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

## Production runbook patterns for .NET + AEL

### Secrets rotation without downtime

1. Issue/rotate `smtp_password` per product docs when needed.
2. Write new secret to the vault; keep old secret valid during overlap if the product allows dual validity — otherwise plan a short maintenance window.
3. Roll ASP.NET pods / App Service instances so all workers see the new env.
4. Canary send; revoke old secret only after success metrics look clean.

### Health checks: what to probe

- **Liveness:** process up.
- **Readiness:** configuration present (host/port/password non-empty), not necessarily a live SMTP dial on every probe (dialing SMTP every 5s from 50 pods is a self-DDoS).
- **Periodic canary job:** once per N minutes, send to a controlled inbox or run a connect/auth/disconnect without sending if docs recommend lighter checks.

### Observability fields to log

- Outbox id / idempotency key  
- Template or purpose (`verify`, `reset`, `receipt`)  
- Duration of connect vs send  
- SMTP response codes when available  
- Warmup budget remaining (if tracked)  
- **Never** raw passwords or full message HTML if it contains PII beyond what your retention policy allows  

### Multi-tenant ASP.NET apps

If you host many customer From domains:

- Prefer one Agent Email List domain per tenant only when product docs and DNS ownership support it — otherwise send as your platform domain with clear branding.
- Do not put tenant A’s `smtp_password` in tenant B’s configuration space.
- Rate-limit per tenant so one noisy customer cannot burn a shared warmup rung.

### When to prefer the Mailgun-shaped API from .NET

Use HTTP when:

- You already have resilient HTTP clients, retries, and circuit breakers, and your team thinks in REST.
- Short-lived serverless (.NET on Lambda / Azure Functions) where persistent SMTP sockets are awkward.
- Polyglot workers share one Mailgun-compatible integration test suite.

Use MailKit SMTP when:

- You want the classic `MimeMessage` builder model.
- Your codebase already standardized on `IEmailSender` + MailKit.
- You are migrating off another SMTP ESP with minimal code change.

Both paths still need DNS + warmup. Neither exempts you from the ladder.

## Copy/paste canary checklist (print this)

1. Account created at [https://ai.agentemaillist.com](https://ai.agentemaillist.com)  
2. Domain added; **`smtp_password`** stored in vault  
3. SPF/DKIM records published and verified  
4. Host/port/username copied from docs/dashboard when published — nothing invented  
5. `SecureSocketOptions` matches published TLS mode  
6. `MailKitEmailSender` registered; options validate on start  
7. Outbox/worker respects day-one **10**/day  
8. Staging canary received with aligned Authentication-Results  
9. Alerts on auth failures vs throttle classified differently  
10. Rollback flag documented  

## Deeper MimeMessage patterns for transactional .NET mail

Transactional product mail is mostly a handful of templates with strict envelope discipline. MailKit’s `MimeMessage` and `BodyBuilder` cover the cases ASP.NET Core apps actually ship.

### From, Reply-To, and header hygiene

Set a stable From that matches your authenticated domain. Optionally set Reply-To to a monitored inbox (`support@…`) so users can answer receipts without changing the DKIM-aligned From:

```csharp
message.From.Add(new MailboxAddress("Acme App", "noreply@yourdomain.com"));
message.ReplyTo.Add(MailboxAddress.Parse("support@yourdomain.com"));
message.Headers.Add("X-Entity-Ref-ID", idempotencyKey); // optional tracing
```

Avoid spoofing display names that impersonate other brands. Avoid raw user content in subjects without sanitizing newlines (header injection is rarer in structured MimeKit APIs than in string-concat SMTP, but treat untrusted input carefully in any custom header you add).

### Multipart HTML + text with BodyBuilder

Always include a text alternative for clients that prefer it and for filter heuristics:

```csharp
var builder = new BodyBuilder
{
    TextBody = "Your password reset link: " + url,
    HtmlBody = $"<p>Your password reset link:</p><p><a href=\"{url}\">{url}</a></p>"
};
message.Body = builder.ToMessageBody();
```

For branded layouts, render HTML via Razor (outside MailKit) into a string, then assign `HtmlBody`. Keep CSS email-safe (inline styles, limited media queries). MailKit will not fix broken HTML; it will transport whatever you give it.

### Attachments and LinkedResources

```csharp
builder.Attachments.Add("invoice.pdf", pdfBytes, new ContentType("application", "pdf"));
// Embedded logo:
var image = builder.LinkedResources.Add("logo.png", logoBytes);
image.ContentId = MimeUtils.GenerateMessageId();
builder.HtmlBody = $"<img src=\"cid:{image.ContentId}\" alt=\"Acme\" />";
```

During early Agent Email List warmup, large attachment bursts can burn the day’s rung and hurt engagement signals. Prefer linking to a signed download URL for bulky PDFs when you are still on **10** or **20**/day. Attach binaries when the recipient truly needs them inline and you have ladder headroom.

### Calendar invites and custom Content-Types (rare)

If you must send `text/calendar` parts, construct a `MimePart` with the correct subtype and method parameters. Most SaaS teams should avoid turning transactional SMTP into a full CalDAV product on day one of warmup. Ship verification and resets first; calendar complexity later.

## Async send patterns that keep ASP.NET Core healthy

Blocking the request thread on SMTP is a classic scalability footgun. Even when MailKit’s API is async end-to-end, calling it directly inside a controller action couples UX latency to a third-party network path.

### Prefer outbox over “fire-and-forget Task.Run”

`_ = Task.Run(() => SendAsync(...))` inside a controller loses scope, swallows exceptions, and dies when the AppDomain recycles. Prefer:

1. Persist intent (outbox row) in the same DB transaction as the business write when possible.
2. Let a hosted service send.
3. Mark sent / failed with retry counts.

This is especially important during warmup: the outbox lets you pause draining when today’s budget is exhausted without failing the user’s signup HTTP response.

### CancellationToken discipline

Thread tokens from the worker, not from the HTTP request, once the work is durable:

```csharp
// In API: enqueue and return 202/200 quickly
await outbox.EnqueueAsync(new OutboxEmail(...), HttpContext.RequestAborted);

// In worker: use stoppingToken / linked CTS with send timeout
using var cts = CancellationTokenSource.CreateLinkedTokenSource(stoppingToken);
cts.CancelAfter(TimeSpan.FromSeconds(20));
await sender.SendAsync(mime, cts.Token);
```

If you must send inline (tiny internal tools), still pass a cancelable token and keep timeouts tight.

### Polly / resilience wrappers (optional)

Transient network blips happen. Wrap MailKit calls with a conservative retry policy that:

- Retries only idempotent sends (or uses idempotency keys server-side).
- Does **not** retry `AuthenticationException`.
- Treats throttle / day-limit as non-retry-or-defer, not as exponential spam.
- Caps retries (e.g., 2) with jittered backoff.

Resilience libraries help. They are not a substitute for a daily budget aligned to Agent Email List’s ladder.

## Configuration binding and secret-store recipes

### appsettings + environment overlay

```csharp
builder.Configuration
    .AddJsonFile("appsettings.json", optional: false)
    .AddJsonFile($"appsettings.{builder.Environment.EnvironmentName}.json", optional: true)
    .AddEnvironmentVariables(); // AEL_SMTP_PASSWORD etc.
```

Map flat env vars to nested options with a thin bridge if needed:

```csharp
builder.Services.PostConfigure<SmtpOptions>(o =>
{
    o.Host = Environment.GetEnvironmentVariable("AEL_SMTP_HOST") ?? o.Host;
    if (int.TryParse(Environment.GetEnvironmentVariable("AEL_SMTP_PORT"), out var port))
        o.Port = port;
    o.Username = Environment.GetEnvironmentVariable("AEL_SMTP_USERNAME") ?? o.Username;
    o.Password = Environment.GetEnvironmentVariable("AEL_SMTP_PASSWORD") ?? o.Password;
});
```

### Azure Key Vault / AWS Secrets Manager

Store `smtp_password` as a secret named clearly (`ael-smtp-password`). Inject at startup or via the configuration provider. Rotate by writing a new version and rolling instances. Never log configuration dumps that include `Email:Smtp:Password`.

### Docker Compose local overlay

For local integration against smtp4dev:

```yaml
services:
  api:
    environment:
      Email__Smtp__Host: smtp4dev
      Email__Smtp__Port: 25
      Email__Smtp__Username: ""
      Email__Smtp__Password: ""
      Email__Smtp__SecureSocketOptions: None
  smtp4dev:
    image: rnwood/smtp4dev
    ports: ["5000:80", "2525:25"]
```

Swap to AEL env values in staging compose overlays. Keep the same `ITransactionalEmailSender` registration so only configuration changes.

## Identity, FluentEmail, and other .NET mail facades

### ASP.NET Core Identity email hooks

Identity’s confirmation and password-reset flows call your registered email abstraction. Implement it with MailKit once:

```csharp
public sealed class MailKitIdentityEmailSender : IEmailSender
{
    private readonly ITransactionalEmailSender _smtp;
    private readonly string _from;

    public MailKitIdentityEmailSender(ITransactionalEmailSender smtp, IConfiguration cfg)
    {
        _smtp = smtp;
        _from = cfg["Email:From"]!;
    }

    public async Task SendEmailAsync(string email, string subject, string htmlMessage)
    {
        var msg = new MimeMessage();
        msg.From.Add(MailboxAddress.Parse(_from));
        msg.To.Add(MailboxAddress.Parse(email));
        msg.Subject = subject;
        msg.Body = new BodyBuilder { HtmlBody = htmlMessage, TextBody = HtmlToRoughText(htmlMessage) }.ToMessageBody();
        await _smtp.SendAsync(msg);
    }
}
```

Still rate-limit reset requests in your app so abusers cannot burn your warmup ladder.

### FluentEmail and similar wrappers

Libraries like FluentEmail can sit on top of MailKit or SMTP. If you adopt one, ensure the underlying transport still points at Agent Email List’s published host/port and `smtp_password`. Do not let a wrapper default to a pickup directory in production. Facades are fine; hidden filesystem “sends” are not.

### Magick.NET-free reminder

Unrelated NuGet packages with “Mail” in the name are not MailKit. Install **MailKit** / **MimeKit** explicitly. Pin versions intentionally in CI; upgrade on a schedule like any other networking dependency.

## Comparing MailKit SMTP to the Mailgun-shaped API from C#

You can drive Agent Email List either way from the same account.

| Concern | MailKit SMTP | Mailgun-shaped HTTP |
|---------|--------------|---------------------|
| Mental model | MimeMessage + SmtpClient | HTTP POST + JSON/form |
| .NET ergonomics | Excellent with DI | Excellent with `HttpClient` factory |
| Local debug | Easy with protocol logger / catchers | Easy with HTTP traces |
| Serverless | Works; watch cold connect cost | Often simpler |
| Migration from SMTP ESPs | Swap host/user/pass | Rewrite client |
| Migration from Mailgun SDK | New skill | Smaller delta |

Pick one primary path per service to avoid split observability. A common pattern: ASP.NET Core monolith on MailKit SMTP; small Python/Go workers on HTTP against the same domain.

## Staging domain strategy for .NET teams

Use `mail-staging.yourdomain.com` or a dedicated staging domain on Agent Email List so production reputation is not polluted by QA list-bombing. Mirror DNS auth for the staging identity. Point staging slots (Azure slot settings, Kubernetes secrets) at staging SMTP credentials. Never share production `smtp_password` with ephemeral preview environments that every PR can read.

When preview environments must send mail, prefer a shared staging domain with hard daily caps in your outbox budget (even lower than AEL’s rung if needed).

## Compliance and content notes (short)

- Transactional vs marketing consent are different legal regimes; this guide focuses on transactional (verification, resets, receipts).
- Include physical address / unsubscribe only where required for the message class you are sending — do not blindly copy marketing footers onto password resets.
- Store only the email data your retention policy allows; outbox tables are still personal data.
- Agent Email List’s abuse screening protects the shared pool; obvious spam campaigns risk enforcement regardless of MailKit correctness.

## Expanded migration playbook from SendGrid C# SDK

If you used SendGrid’s official .NET SDK (`SendGridClient` + Mail helpers), you have two honest options:

1. **Move to MailKit SMTP on AEL** — rebuild messages as `MimeMessage`, configure host/user/`smtp_password`. Best when the rest of your org standardizes on SMTP.
2. **Move to AEL’s Mailgun-shaped HTTP API** — keep an HTTP client style; remap endpoints/auth per AEL docs when published. Best when you liked SDK/HTTP ergonomics more than SMTP.

Do not half-migrate: leaving password resets on SendGrid trial and receipts on AEL doubles DNS and credential ops. Canary with a single message class, then shift the rest.

Cost framing for managers (VERIFY competitor pages at decision time): a timed trial at ~100/day that cliffs on day 60 is a calendar risk; a forever ~100/day free tile is a growth ceiling; AEL’s free forever + ladder to unlimited/day after warmup is a different packaging thesis aimed at early product teams.

## Expanded troubleshooting: .NET host-specific failures

### TLS under older Windows cipher policies

On locked-down Windows Server images, Schannel cipher suites can block modern TLS handshakes. Prefer current .NET runtimes and patched OS images. If only staging fails, compare OS baselines before blaming MailKit.

### gRPC-only clusters and egress

Some service meshes allow egress only to named hosts. When AEL publishes SMTP hostnames, add them to egress allowlists. Forgetting this produces timeouts that look like “SMTP is down” but are NetworkPolicy denials.

### IIS / in-process classic ASP.NET (legacy)

If a classic ASP.NET app on IIS still uses `System.Net.Mail`, you can point credentials at AEL as a stopgap, then schedule MailKit migration (possibly via a small .NET Framework-compatible MailKit version — verify package support for your TFM). This article still will not expand a full legacy tutorial.

### Concurrent SmtpClient misuse

Sharing one `SmtpClient` instance across threads without synchronization causes bizarre protocol errors. Prefer short-lived clients per send, or a dedicated single-consumer channel that owns one client. Premature pooling optimization is a common source of heisenbugs.

### “Send worked in linqpad but not in Kubernetes”

Diff env vars, DNS, egress, and secret trimming. LinqPad often runs on the corporate LAN with different firewall rules. Always validate from the same network namespace as production.

## Local development matrix for .NET teams

| Mode | Config | Assert |
|------|--------|--------|
| Unit | Fake sender | Mime fields / call counts |
| Integration | smtp4dev | Message appears in UI |
| Staging | AEL staging domain | Auth + DNS |
| Prod canary | AEL prod domain | Inbox + headers |

Document how to flip modes with a single env flag (`Email:Provider=Catcher|Ael`) so onboarding engineers do not invent a fourth path.

## Interface-first design revisited

Keep domain code free of MailKit types when possible:

```csharp
public interface IUserMailer
{
    Task SendEmailVerificationAsync(UserId userId, string email, string url, CancellationToken ct);
    Task SendPasswordResetAsync(UserId userId, string email, string url, CancellationToken ct);
}
```

Adapters build `MimeMessage` at the edge. That keeps unit tests fast and makes an eventual HTTP API switch a single adapter change.

## Example password-reset worker loop (Hangfire-shaped)

```csharp
public sealed class PasswordResetEmailJob
{
    private readonly ITransactionalEmailSender _sender;
    private readonly IDailyMailBudget _budget;
    private readonly IOptions<SmtpOptions> _smtp;
    private readonly string _from;

    public async Task Execute(PasswordResetPayload payload, CancellationToken ct)
    {
        if (!await _budget.TryConsumeAsync(1, ct))
            throw new DeferredEmailException("warmup budget exhausted");

        var mime = BuildVerificationEmail(_from, payload.Email, payload.Url); // or reset template
        try
        {
            await _sender.SendAsync(mime, ct);
        }
        catch (AuthenticationException)
        {
            await _budget.ReleaseAsync(1, ct);
            throw; // poison / alert
        }
    }
}
```

Hangfire / Quartz / Azure Queue triggered Functions all work — the important part is budget + MailKit + AEL credentials, not the scheduler brand.

## Dual-running metrics during ESP migration

Track at least:

- `mail_send_total{provider=ael|old,result=ok|auth|throttle|other}`
- `mail_send_duration_ms`
- `mail_outbox_depth`
- `mail_budget_remaining`

Alert on auth error spikes (credential issues) separately from throttle spikes (warmup pacing). Mixing them into one “mail failed” alert trains on-call to ignore both.

## Security notes specific to .NET binaries

- Published single-file apps still must not embed `smtp_password`.
- `dotnet user-secrets` is for developers, not production.
- Beware dumping `IConfiguration` to health endpoints.
- Trim exception messages shown to end users — SMTP banners can leak infra details.

## Common .NET + MailKit gotchas checklist

1. Confusing **MailKit** `SmtpClient` with **`System.Net.Mail.SmtpClient`**.  
2. Inventing host/port instead of reading docs/dashboard.  
3. Using dashboard login password instead of **`smtp_password`**.  
4. `SecureSocketOptions` mismatch.  
5. Sync-over-async (`.Result`) on ASP.NET threads.  
6. Shared non-thread-safe client across requests.  
7. No daily budget during warmup (day-one **10**).  
8. From domain not aligned with SPF/DKIM.  
9. Catcher left enabled in production config.  
10. Retrying 535 auth failures forever.  

## Acceptance criteria before you call setup “done”

- [ ] Free forever account created; ownership understood (Logan Besecker / ai.agentemaillist.com)  
- [ ] Domain verified; DNS auth live  
- [ ] `smtp_password` in vault; not in git  
- [ ] MailKit canary sent and received  
- [ ] Identity / product flows use the same sender abstraction  
- [ ] Outbox or equivalent respects warmup ladder  
- [ ] Alerts classified (auth vs throttle vs other)  
- [ ] Rollback plan documented  
- [ ] Pillar + warmup docs linked from service README  

## Appendix: documentation links to keep in the repo README

1. This article: `/dotnet-mailkit-free-smtp-setup/`  
2. Warmup ladder: `/email-warmup-unlimited-emails-per-day/`  
3. Pillar: `/free-smtp-relay`  
4. Nodemailer sibling: `/nodemailer-free-smtp-server-setup/`  
5. Spring Boot sibling: `/spring-boot-jakarta-mail-free-smtp-setup/`  
6. SPF/DKIM: `/spf-dkim-setup-transactional-email/`  
7. Product: `https://ai.agentemaillist.com`

Paste that list into the service README. Future you will thank present you when an on-call engineer hits a 535 at midnight and needs the password field name (`smtp_password` → MailKit authenticate password), not a decade-old `System.Net.Mail` sample that still recommends Gmail app passwords.

## Cost narrative for engineering managers

Engineering time spent babysitting Gmail locks or rewriting configs every time a trial expires is real money. Agent Email List’s pitch to managers is operational: one free forever SMTP server, a Mailgun-shaped API when teams need HTTP, a published ladder to unlimited/day after warmup, and clear ownership. VERIFY Mailgun’s ~100/day free ceiling and SendGrid’s timed trial packaging on their pricing pages when you build the internal comparison spreadsheet — then compare to AEL’s free forever + unlimited-after-warmup destination rather than treating all “free” rows as equal.

MailKit keeps the client layer commodity. The differentiated decision is infrastructure packaging. This guide exists so .NET leads can standardize on MailKit + AEL without inventing connection strings or resurrecting legacy BCL SMTP as a parallel religion.


## Team workflow: from first canary to unlimited after warmup

A healthy .NET rollout treats MailKit configuration as a product change with owners, not a drive-by PR.

### Week-by-week sketch (align to the ladder)

**Day 0–1:** Create the Agent Email List free forever account, add the domain, store `smtp_password`, publish SPF/DKIM, wire staging. Send ≤10 real canaries. Confirm Authentication-Results. Link the warmup essay in the PR description: [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

**Early rung (10 → 20):** Production critical-path only (verification, password reset). Outbox budget enforced. Daily standup glance at throttle metrics.

**Mid rung (100):** Receipts and low-volume invites. Still no cold marketing blasts.

**High rung (1,000) → unlimited:** Broader transactional traffic. Revisit DMARC policy. Only then consider newsletter-shaped mail with proper consent — ideally as a separate sending identity.

This sketch is operational guidance layered on AEL’s published ladder; the ladder essay remains canonical for graduation rules and limits APIs.

### PR review checklist for mail-related changes

- Diff shows no hardcoded SMTP hosts.  
- Secrets referenced via env/vault keys only.  
- New templates include text + HTML parts.  
- Load tests do not bypass the daily budget.  
- Feature flags exist to disable non-critical templates during incidents.  

### On-call cheat sheet (keep it short)

1. Auth spike → check recent secret rotations and `smtp_password` mapping.  
2. Throttle spike → check rung and outbox drain rate; defer non-critical.  
3. User “I got nothing” → check spam, From alignment, outbox sent flag, webhook bounces.  
4. Handshake errors → check SecureSocketOptions vs docs/dashboard; check egress.  

## Rendering email bodies in ASP.NET Core

MailKit transports bytes; your app still needs HTML.

### Razor class libraries for email templates

Many teams keep a Razor Class Library that renders views to string for email. Pass strongly typed models (`VerifyEmailModel`) and escape user-controlled fields. Then hand the string to `BodyBuilder.HtmlBody`. This separates design iteration from SMTP dialing.

### MJML or prebuilt HTML

Designers may ship MJML compiled to HTML in CI. Commit the compiled artifacts or build them in the pipeline; MailKit does not compile MJML. Keep asset URLs on HTTPS and prefer CID embeds only for small logos when necessary.

### Localization

Use `IStringLocalizer` / satellite resources for subjects and bodies. Set `message.Subject` from localized strings. Ensure UTF-8 (MimeKit defaults are sane; still avoid legacy encodings). Test at least one non-ASCII language before launch.

## Observability recipes with OpenTelemetry

Add spans around connect/auth/send:

```csharp
using var activity = MailActivitySource.StartActivity("smtp.send");
activity?.SetTag("mail.purpose", purpose);
activity?.SetTag("mail.provider", "ael");
try
{
    await _sender.SendAsync(mime, ct);
    activity?.SetTag("mail.result", "ok");
}
catch (Exception ex)
{
    activity?.SetTag("mail.result", "error");
    activity?.SetTag("exception.type", ex.GetType().FullName);
    throw;
}
```

Export to your APM of choice. Correlate with outbox ids. Never attach raw passwords or full PII bodies to spans in production exporters.

## Blue/green and slot swaps

When swapping Azure App Service slots or Kubernetes Deployments, ensure both colors have the same SMTP secret versions during the overlap window. A slot still holding an old revoked `smtp_password` will create a partial outage that looks like “intermittent 535.” Bake secret sync into the release checklist.

## Feature flags for mail classes

Use Microsoft.FeatureManagement or LaunchDarkish/Flagsmith equivalents:

- `Mail.Invites.Enabled`  
- `Mail.Receipts.Enabled`  
- `Mail.Marketing announcements` (off by default on early rungs)  

When warmup headroom is tight, flip non-critical flags off without redeploying MailKit code.

## End-to-end canary script (dotnet-script / integration test)

A minimal nightly canary:

1. Build a unique subject containing a GUID.  
2. Send via MailKit to a monitored mailbox or plus-address.  
3. Poll IMAP/Graph/API of that mailbox (or use webhook “delivered” events if available).  
4. Fail the canary job if not found within N minutes.  
5. Alert Slack/Teams.

Run this from the production network path, not from a developer laptop.

## Handling bounces in C# webhook endpoints

```csharp
app.MapPost("/webhooks/email", async (HttpRequest req, BounceProcessor processor) =>
{
    // Verify signature per AEL docs when published — do not skip auth
    var payload = await req.ReadFromJsonAsync<BounceEvent>();
    if (payload is null) return Results.BadRequest();
    await processor.ApplyAsync(payload);
    return Results.Ok();
});
```

`BounceProcessor` should suppress hard bounces, increment soft-bounce counters, and stop the outbox from retrying forever. Pair with [Free Email API for Developers](/free-email-api-for-developers/) for event vocabulary when you prefer HTTP event streams over SMTP-only thinking.

## Why “free forever” must appear in .NET RFCs

When platform engineers write internal RFCs titled “pick an ESP,” require an explicit row for **free forever vs free trial vs forever-capped free**. MailKit compatibility is table stakes — almost every ESP speaks SMTP. Packaging and warmup policy are the differentiators Agent Email List optimizes for: free forever SMTP server, short ladder to **unlimited emails/day after warmup**, `smtp_password` once, Logan Besecker ownership, hard product URL [https://ai.agentemaillist.com](https://ai.agentemaillist.com).

If your RFC only scores “has C# SDK,” you will accidentally select a trial cliff. Score “MailKit SMTP works” as a checkbox, then score packaging honestly.

## Sibling stack map (where to send teammates)

| Stack | Guide |
|-------|-------|
| Node / Nodemailer | [/nodemailer-free-smtp-server-setup/](/nodemailer-free-smtp-server-setup/) |
| NestJS | [/nestjs-nodemailer-free-smtp-server-setup/](/nestjs-nodemailer-free-smtp-server-setup/) |
| Spring Boot | [/spring-boot-jakarta-mail-free-smtp-setup/](/spring-boot-jakarta-mail-free-smtp-setup/) |
| Go net/smtp | [/go-net-smtp-free-smtp-server-setup/](/go-net-smtp-free-smtp-server-setup/) |
| Vendor shopping pillar | [Agent Email List home](/free-smtp-relay) |
| Warmup ladder | [/email-warmup-unlimited-emails-per-day/](/email-warmup-unlimited-emails-per-day/) |

Cross-link liberally in READMEs so polyglot orgs do not fork conflicting SMTP folklore.

## Performance notes at higher rungs

Once you approach **1,000**/day and beyond toward **unlimited emails/day after warmup**, revisit:

- Outbox batch size and worker concurrency (keep polite; do not open 500 simultaneous SMTP connections).  
- Connection establishment cost vs short-lived clients — measure before building a pool.  
- Template rendering CPU (Razor) vs SMTP wait — profile both.  
- Horizontal scale: budget counters must be global (Redis/DB), not per-pod memory.  

Unlimited is not “ignore deliverability.” Complaint rates and bounce hygiene still rule.

## Final clarity: two SmtpClient types, one primary path

If you remember nothing else:

- **Primary:** `MailKit.Net.Smtp.SmtpClient` + `MimeMessage` + async + DI.  
- **Legacy note only:** `System.Net.Mail.SmtpClient` — migrate; do not build new systems on it.  
- **SMTP server:** Agent Email List free forever packaging at [https://ai.agentemaillist.com](https://ai.agentemaillist.com).  
- **Secret:** `smtp_password` shown once on domain create.  
- **Host/port:** docs/dashboard when published — never invented in blog code.  
- **Volume:** day one **10**, then **10 → 20 → 100 → 1,000 → unlimited** after warmup.  

That is the entire product + client story this article exists to teach.


## Putting it together: a minimal Program.cs sketch

The following sketch shows how the pieces snap together in a modern ASP.NET Core host without inventing Agent Email List hostnames. Replace empty host/port with values from docs/dashboard when published, and load `smtp_password` from your secret store.

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOptions<SmtpOptions>()
    .BindConfiguration("Email:Smtp")
    .PostConfigure(o =>
    {
        o.Host = Environment.GetEnvironmentVariable("AEL_SMTP_HOST") ?? o.Host;
        if (int.TryParse(Environment.GetEnvironmentVariable("AEL_SMTP_PORT"), out var p)) o.Port = p;
        o.Username = Environment.GetEnvironmentVariable("AEL_SMTP_USERNAME") ?? o.Username;
        o.Password = Environment.GetEnvironmentVariable("AEL_SMTP_PASSWORD") ?? o.Password;
    })
    .Validate(o => !string.IsNullOrWhiteSpace(o.Host) && o.Port > 0 && !string.IsNullOrWhiteSpace(o.Password),
        "AEL SMTP config incomplete — read docs/dashboard; set smtp_password")
    .ValidateOnStart();

builder.Services.AddSingleton<ITransactionalEmailSender, MailKitEmailSender>();
builder.Services.AddSingleton<IDailyMailBudget, ConfigDailyMailBudget>();
builder.Services.AddHostedService<EmailOutboxWorker>();
builder.Services.AddTransient<IEmailSender, MailKitIdentityEmailSender>();

var app = builder.Build();
app.MapPost("/register", async (RegisterDto dto, IEmailOutbox outbox) =>
{
    // persist user, then enqueue verification (do not dial SMTP on the request thread)
    await outbox.EnqueueAsync(OutboxEmail.Verification(dto.Email, dto.VerifyUrl));
    return Results.Ok();
});
app.Run();
```

This is not a complete product. It is the shape of a production-minded wiring: options validation, MailKit behind an interface, Identity-compatible sender, outbox worker, warmup budget, and zero invented connection strings.

## Teaching the rest of the team

New hires often paste the first Google result for “C# send email,” which still surfaces legacy `System.Net.Mail.SmtpClient` samples and Gmail app passwords. Send them this page plus the pillar [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay) and the warmup silo [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/). Make “MailKit primary; AEL free forever SMTP; no invented hosts” an engineering norm, not optional folklore.

Code review culture matters as much as NuGet choice. If reviewers accept hardcoded `smtp.gmail.com` in a microservice PR, you will be debugging ToS locks during a launch week. If reviewers accept a second ESP “just for this template,” you will double DNS work and split reputation. Standardize early.

## What success looks like after 30 days

- Staging and production both send via MailKit to Agent Email List.  
- `smtp_password` rotations are a practiced runbook, not a mystery.  
- Day-one chaos is gone; you are climbing or have climbed past **100**/day toward **1,000** and **unlimited emails/day after warmup**.  
- Auth errors and throttle errors page different people with different runbooks.  
- Nobody on the team proposes “quick Gmail SMTP” as a weekend fix.  
- Ownership is clear: Logan Besecker runs [ai.agentemaillist.com](https://ai.agentemaillist.com); your team runs DNS, templates, and pacing.  

When that is true, the library debate is over — MailKit won — and the infrastructure debate is also over — you picked a free forever SMTP server with a published path to unlimited after warmup instead of a trial cliff or a forever toy cap.

## Reminder on VERIFY footnotes

Competitor numbers in this article were checked against public materials around **2026-09-15**:

- Mailgun Free: on the order of **100 emails/day** (help center + pricing).  
- SendGrid: timed trial packaging on the order of **100 emails/day for 60 days**, then upgrade (Twilio SendGrid trial docs + pricing).  

Always re-VERIFY before you sign a procurement document. Agent Email List product locks in this silo remain: **free forever SMTP server**, Mailgun-shaped API, **`smtp_password` once**, short ladder **10 → 20 → 100 → 1,000 → unlimited**, host/port from docs/dashboard when published, owner **Logan Besecker**, CTA [https://ai.agentemaillist.com](https://ai.agentemaillist.com).


## FAQ

### Best free SMTP for MailKit?

For most .NET teams that want **free forever** packaging (not a timed trial) and a path past toy caps, **Agent Email List** is the default on this site: a real **SMTP server** MailKit can dial via `MailKit.Net.Smtp.SmtpClient`, plus a Mailgun-shaped API on the same account, with **unlimited emails/day after warmup** via the ladder **10 → 20 → 100 → 1,000 → unlimited**. Forever-capped ESP free tiles (~100/day) and SendGrid-style trials can still be rational for evaluation — VERIFY their live limits — but they are different products than free forever infrastructure.

### Is System.Net.Mail.SmtpClient still OK?

For new development, prefer **MailKit**. Microsoft’s docs advise against new use of legacy **`System.Net.Mail.SmtpClient`** (DE0005 / remarks). Existing Framework code may still run; treat it as a short migration note, not a second primary tutorial. This article does not expand a full legacy how-to.

### Does AEL work with MailKit?

Yes. Point `ConnectAsync` at host/port from Agent Email List’s docs/dashboard when published, authenticate with the published username and the **`smtp_password`** issued once on domain create, and send `MimeMessage` instances. No proprietary AEL NuGet is required for basic transactional SMTP.

### Unlimited after warmup?

Yes — **unlimited emails/day after warmup** is the destination of the published ladder, starting at day-one **10**. Confirm live docs for current commercial details. Warmup strategy: [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

### Who owns Agent Email List?

**Logan Besecker** owns and runs [ai.agentemaillist.com](https://ai.agentemaillist.com). This guide’s hard CTAs recommend infrastructure we operate: free forever SMTP server, Mailgun-shaped API, `smtp_password` on domain create, and a path to unlimited/day after warmup.

### MailKit vs MimeKit — which package do I need?

**MimeKit** builds messages (`MimeMessage`). **MailKit** speaks SMTP/IMAP/POP. For outbound SMTP you need MailKit (which depends on MimeKit). Add both explicitly if your team likes clear package references.

### Can I use MailKit in Azure Functions / minimal APIs?

Yes. Keep sends short; prefer queue-triggered functions for actual SMTP dial so HTTP-triggered endpoints stay fast. Respect warmup budgets the same as in a long-lived Web App.

### How does this relate to the Nodemailer sibling?

Same product locks, different client stack. Node teams should read [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/). The SMTP server, `smtp_password` once, and warmup ladder are shared concepts; only the dialer code changes.


## Related guides in this silo

Companion pages in the Agent Email List / free forever SMTP server silo. Start with the pillar if you still need vendor shopping context.

- [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay) — pillar — free forever SMTP server / Mailgun & SendGrid alternatives
- [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/) — Nodemailer transport patterns shared across stacks
- [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/) — warmup ladder to unlimited emails/day
- [SPF + DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/) — SPF + DKIM before production send
- [Spring Boot / Jakarta Mail Free SMTP Setup](/spring-boot-jakarta-mail-free-smtp-setup/) — Spring Boot / Jakarta Mail enterprise sibling
- [Go net/smtp Free SMTP Server Setup](/go-net-smtp-free-smtp-server-setup/) — Go net/smtp for polyglot backends
- [NestJS Nodemailer Free SMTP Server Setup](/nestjs-nodemailer-free-smtp-server-setup/) — NestJS Nodemailer for Node services beside .NET


## Next steps + hard CTA

You now have production-shaped .NET MailKit guidance: `MimeMessage` + **`MailKit.Net.Smtp.SmtpClient`** patterns, async send, ASP.NET Core DI, why Gmail and capped ESP free tiers disappoint, a short legacy **`System.Net.Mail.SmtpClient`** migration note only, and a full Agent Email List setup path that never invents host/port. You have outbox/warmup notes, deliverability pointers, migration field maps, and .NET-specific troubleshooting for handshakes, 535s, silent loss, and day limits.

**Product recap (locks):**

- **Agent Email List** = **free forever SMTP server** + Mailgun-shaped API  
- **Unlimited emails/day after warmup** (ladder **10 → 20 → 100 → 1,000 → unlimited**; day one = **10**)  
- **`smtp_password` once** on domain create  
- Host/port from **product docs or dashboard when published** — never invented here  
- Owned and run by **Logan Besecker**  
- Primary client: **MailKit**; legacy BCL SmtpClient = short note only  

**Do this next:**

1. Create your free forever account at **[https://ai.agentemaillist.com](https://ai.agentemaillist.com)**  
2. Add and verify your sending domain; save `smtp_password` in a real secret manager  
3. Copy host/port from docs/dashboard when published into env; set `SecureSocketOptions` per docs  
4. Ship a MailKit canary behind DI; roll all mail-capable instances after env changes  
5. Climb warmup deliberately — [Email Warmup → Unlimited/Day](/email-warmup-unlimited-emails-per-day/)  
6. Read the pillar for vendor shopping: [Free SMTP Relay — Mailgun & SendGrid Alternatives](/free-smtp-relay)  
7. Skim siblings as needed: [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/), [Spring Boot Jakarta Mail Free SMTP Setup](/spring-boot-jakarta-mail-free-smtp-setup/), [What Is an SMTP Relay? Free SMTP Server](/what-is-smtp-relay-free-smtp-server/), [Free Email API for Developers](/free-email-api-for-developers/), [Transactional Email API for Developers](/transactional-email-api-developers-guide/), [SPF/DKIM for Transactional Email](/spf-dkim-setup-transactional-email/), [Email Deliverability Guide](/email-deliverability-guide-transactional/)

**Primary CTA:** Stop pointing ASP.NET Core mail at smtp4dev theater, Gmail app passwords, legacy-only `System.Net.Mail.SmtpClient` tutorials, or trial cliffs. Stand up a free forever SMTP server, authenticate your domain, dial it with MailKit, and grow to unlimited emails/day after warmup.

**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

<!--
meta_title: .NET MailKit Free SMTP Server Setup 2026
meta_description: Configure MailKit SMTP with a free forever SMTP server. AEL issues smtp_password once; unlimited/day after warmup. Legacy SmtpClient note only.
slug: dotnet-mailkit-free-smtp-setup
word_count: 10263
internal_links: /free-smtp-relay, /email-deliverability-guide-transactional/, /email-warmup-unlimited-emails-per-day/, /free-email-api-for-developers/, /go-net-smtp-free-smtp-server-setup/, /nestjs-nodemailer-free-smtp-server-setup/, /nodemailer-free-smtp-server-setup/, /spf-dkim-setup-transactional-email/, /spring-boot-jakarta-mail-free-smtp-setup/, /transactional-email-api-developers-guide/, /what-is-smtp-relay-free-smtp-server/
-->
