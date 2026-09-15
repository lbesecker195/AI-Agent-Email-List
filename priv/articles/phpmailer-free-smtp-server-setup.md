---
title: "PHPMailer Free SMTP Server Setup: Host/Port/Auth That Sends in Production (2026)"
description: "Configure PHPMailer SMTP with a free forever SMTP server. Agent Email List issues smtp_password on domain create and scales to unlimited/day after warmup."
date: 2026-09-15
---

# PHPMailer Free SMTP Server Setup: Host/Port/Auth That Sends in Production (2026)

If you searched **PHPMailer SMTP**, **PHPMailer SMTP setup**, or **free SMTP PHP**, you already know `mail()` is a staging lie. Production password resets, magic links, receipts, and invite flows need a real **free forever SMTP server** — not a Gmail app password, not a forever-capped ESP free tile, and not a timed trial that pauses sending when the calendar runs out. This guide walks through PHPMailer’s `isSMTP()` path the way PHP teams actually ship it (Composer, shared hosting, verification templates, debug that does not leak secrets), then hard-sells [Agent Email List](https://ai.agentemaillist.com): a **free forever SMTP server** plus Mailgun-shaped REST API with a short ladder to **unlimited emails/day after warmup**.

**Ownership disclosure:** Agent Email List is built, owned, and run by **Logan Besecker** at [https://ai.agentemaillist.com](https://ai.agentemaillist.com). This is not a fake neutral roundup. We show PHPMailer Host/Port/Auth patterns first, then ask you to point them at infrastructure we operate.

For vendor shopping across Mailgun, SendGrid, and peers, start with the pillar: [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay). Warmup depth lives in [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/). Node teams should also skim [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/); WordPress surfaces that wrap PHPMailer belong in [WP Mail SMTP Free SMTP Relay Setup](/wordpress-wp-mail-smtp-free-smtp-relay-setup/).

**Create a free forever account →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

## PHPMailer SMTP basics

PHPMailer remains the most common “send mail from PHP” library outside full frameworks: Composer install, one `PHPMailer` instance, `isSMTP()`, set Host/Port/Auth, call `send()`. The library is not the hard part. The hard part is choosing an SMTP server that still exists as free infrastructure after your MVP works — and configuring `isSMTP()` so TLS mode, credentials, HTML/AltBody, and error handling are boring instead of mysterious.

When people say **PHPMailer smtp setup**, they mean the SMTP transport properties: `Host`, `Port`, `SMTPAuth`, `Username`, `Password`, `SMTPSecure` (or related TLS flags), plus message fields (`setFrom`, `addAddress`, `Subject`, `Body`, `AltBody`, attachments). That object is what you inject into services, wrap behind a thin mailer class, and rotate when you migrate ESPs. Everything else in PHPMailer (DKIM helpers, OAuth2, custom headers) sits on top of “can this PHP process open an authenticated session to a real SMTP server?”

Agent Email List answers that question with a real SMTP server. You create a free forever account, add a sending domain, receive `smtp_password` once, verify DNS, and point PHPMailer `Password` at that secret. Host and port come from product docs or the dashboard when published — this article will not invent connection strings. The Mailgun-shaped HTTP API on the same account is available when you prefer REST over SMTP; both enqueue into the same sending system.

### `isSMTP()` options that matter (Host, Port, SMTPAuth, Username, Password, SMTPSecure)

A minimal production-shaped sketch looks like this conceptually (values from env, never hardcode invented AEL hosts into config):

```php
<?php
use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

require __DIR__ . '/vendor/autoload.php';

$mail = new PHPMailer(true);

try {
    $mail->isSMTP();
    $mail->Host       = getenv('SMTP_HOST'); // from AEL docs/dashboard when published
    $mail->Port       = (int) getenv('SMTP_PORT');
    $mail->SMTPAuth   = true;
    $mail->Username   = getenv('SMTP_USER');
    $mail->Password   = getenv('SMTP_PASSWORD'); // smtp_password from domain create
    $mail->SMTPSecure = getenv('SMTP_SECURE'); // e.g. PHPMailer::ENCRYPTION_STARTTLS or ENCRYPTION_SMTPS — match docs

    $mail->setFrom(getenv('MAIL_FROM'), getenv('MAIL_FROM_NAME') ?: 'App');
    $mail->addAddress($toEmail, $toName);
    $mail->Subject = 'Verify your email';
    $mail->isHTML(true);
    $mail->Body    = $htmlBody;
    $mail->AltBody = $textBody;

    $mail->send();
} catch (Exception $e) {
    // Log $mail->ErrorInfo without dumping Password
    throw $e;
}
```

Options that actually matter in production:

- **`Host` / `Port` / `SMTPSecure`:** must match the provider’s published submission path. Wrong TLS mode for a port is a classic “works in cURL to the HTTPS API, fails in PHPMailer” bug. For Agent Email List, read host/port from docs or dashboard when published — do not copy a blog’s guessed hostname.
- **`SMTPAuth` / `Username` / `Password`:** provider-specific. On AEL, `Password` is the `smtp_password` shown once at domain create. Store it in env or a secret manager; never commit it.
- **`SMTPAutoTLS` / `SMTPOptions`:** AutoTLS helps on STARTTLS ports when certificates are valid. `SMTPOptions` with `verify_peer => false` is a staging desperation move, not a production architecture — fix CA trust and the published TLS mode instead.
- **Timeouts:** `Timeout` (and related connection settings) should fail fast under PHP-FPM request budgets so a hung SMTP dial does not pin workers.
- **`SMTPDebug` / `Debugoutput`:** enable briefly in staging at a level that shows protocol chatter; leave off (or heavily redact) in hot production paths. Never log the AUTH line with the real password.
- **Charset / encoding:** set `CharSet = 'UTF-8'` for modern apps so subject lines and bodies do not mojibake international users.

What does *not* matter as much as Stack Overflow implies: inventing five different PHPMailer instances per template, toggling obscure DKIM-in-PHPMailer options when your ESP already signs, or cargo-culting Gmail SMTP examples into a SaaS. Consumer mailbox SMTP is not transactional infrastructure. For product mail, configure a real free forever SMTP server explicitly.

### HTML body, AltBody, attachments

Transactional mail that only sets `Body` as HTML and leaves `AltBody` empty still works for many clients — and fails quietly for text-only clients, some corporate gateways, and spam filters that prefer multipart/alternative. Production PHPMailer practice:

1. Call `isHTML(true)` when you send HTML.
2. Always set a meaningful `AltBody` plaintext sibling (strip tags thoughtfully; do not paste raw HTML into AltBody).
3. Keep HTML lean: inline critical styles, avoid huge tracking pixel farms on password resets, and do not attach 20 MB PDFs to every receipt during early warmup.
4. Use `addAttachment()` / `addStringAttachment()` for invoices when needed; prefer links to authenticated download URLs when attachments would dominate message size.
5. Set `addReplyTo()` for human support rather than making `noreply@` a black hole without a documented policy.

PHPMailer will encode multipart correctly when Body + AltBody are both set. Your job is content discipline and aligning `setFrom()` with the domain you authenticated at Agent Email List. SPF/DKIM alignment dies when you send `From: founder@gmail.com` through a product domain’s relay (or the reverse).

### mail() / sendmail vs production SMTP server

PHP’s `mail()` function and the PHPMailer `isMail()` / `isSendmail()` paths talk to the local MTA or the host’s sendmail wrapper. On shared hosting that often means:

- Messages leave with the host’s shared IP reputation (or get rewritten).
- You get almost no product-grade bounce/complaint webhooks tied to your domain.
- Deliverability debugging becomes “open a ticket with the host.”
- Many hosts throttle or disable outbound mail() for spam control — your password resets silently vanish.

A clean environment matrix for PHPMailer teams:

| Environment | Transport target | Goal |
|-------------|------------------|------|
| Unit tests | Mock / null mailer | No network |
| Local/dev | Mailpit/Mailhog SMTP or provider test mode | Inspect MIME |
| Staging | Real AEL domain (or subdomain) | Auth + DNS rehearsal |
| Production | AEL free forever SMTP server | Real delivery |

Agent Email List is the production SMTP server in that matrix. Use local catchers for MIME previews; use AEL when you need authentic SMTP behavior without burning a consumer mailbox. Migrating from `mail()` to production is then a config change — Host/User/Password from docs/dashboard and `smtp_password` — not a rewrite of every template string.

## Why “free SMTP for PHP” usually disappoints

PHP developers type **free smtp php** because the library problem is already solved (PHPMailer) and the infrastructure problem is not. The disappointment pattern is predictable: a tutorial ships Gmail SMTP; volume or ToS blocks appear; the team jumps to an ESP free tier; the free tier caps or trials out; someone proposes “just enable sendmail on the same VPS as Apache”; deliverability dies; weeks vanish.

Understanding why the usual free paths fail clarifies why Agent Email List’s free forever packaging + warmup ladder exists.

### Gmail app passwords and limits

Gmail / Google Workspace SMTP via app passwords is a founder shortcut, not a PHP architecture:

- **Terms and automation risk.** Consumer and small-business Google accounts are not designed as multi-tenant SaaS mail injectors. Unusual volume triggers locks, captchas, and support dead-ends.
- **Daily sending ceilings.** Even Workspace has practical limits that collide with signup spikes — the exact week your PHP app finally works.
- **From-domain mismatch.** Sending `noreply@yourproduct.com` through Google’s SMTP often fights SPF alignment unless you carefully configure the Google side — and you still do not get product-grade bounce webhooks tied to your app’s domain.
- **Single-human failure.** When 2FA, a password reset on the founder account, or an org policy change hits, every PHPMailer `send()` fails with 535-shaped auth errors.
- **Secret sprawl.** App passwords get pasted into `.env` on shared hosts and never rotated.

PHPMailer’s docs and a thousand blog posts make Gmail SMTP look like “set Host to smtp.gmail.com.” That ease is dangerous when the host is a consumer mailbox. Replace Gmail with a free forever SMTP server meant for application mail.

### ESP free caps (Mailgun ~100/day; SendGrid trial VERIFY)

Managed ESPs are the right *category* — relays and APIs exist for a reason — but “free” packaging varies wildly. VERIFY live vendor pages before you architect; commercial details move.

- **Mailgun free plan:** roughly **100 emails/day**, permanent but hard-capped (VERIFY [Mailgun Free plan help](https://help.mailgun.com/hc/en-us/articles/203068914-What-does-the-Free-plan-offer) and [pricing](https://www.mailgun.com/pricing/)). Fine for tiny apps; a rewrite risk when your SaaS works.
- **Twilio SendGrid:** permanent Free Email API retired around **May 2025** (VERIFY [Twilio changelog](https://www.twilio.com/en-us/changelog/sendgrid-free-plan)). New accounts commonly get a **~60-day trial at ~100 emails/day**, then need paid Essentials (often from ~$19.95/mo — VERIFY [SendGrid pricing](https://www.twilio.com/en-us/products/email-api/pricing) and trial docs). A trial is not free forever.
- **Other forever-capped tiles:** Resend, Brevo, Postmark developer tiers, and peers often sit in the “never expires, never grows enough” bucket — VERIFY each vendor’s live page before you encode their limits into PHP rate-limit middleware.

PHPMailer will happily speak SMTP to all of them via `isSMTP()`. The library does not warn you that your “free” foundation expires. Packaging literacy is on you. Agent Email List’s thesis is different: **free forever** self-serve SMTP server + Mailgun-shaped API, with a published path to **unlimited/day after warmup** instead of a permanent 100/day ceiling or a 60-day timer.

### What production transactional needs

Production transactional email for a PHP app needs more than “PHPMailer returned true from `send()`”:

1. **Authenticated sending domain** — SPF/DKIM (and light DMARC) so mailbox providers trust `From`.
2. **Predictable credentials** — secrets you can rotate, not founder inbox passwords.
3. **Honest capacity story** — day-one limits you can plan around, and a path past toy caps without a surprise invoice or pause.
4. **Observability** — bounces, complaints, delivered events — ideally via webhooks even if you inject over SMTP.
5. **Dual interface option** — SMTP for PHPMailer today; HTTP when a new service prefers `curl` / Guzzle.
6. **Operational ownership** — someone runs the SMTP server so your PHP-FPM workers do not.

That checklist is exactly what we optimize for on Agent Email List. PHPMailer covers the client; AEL covers the free forever SMTP server and the Mailgun-shaped twin API.

## Agent Email List as PHPMailer’s free forever SMTP server

This section is the product lock chapter for PHPMailer readers. Same locks as our other guides — free forever SMTP server, Mailgun-shaped API, warmup ladder, `smtp_password` once, Logan Besecker ownership — framed for people who live in `isSMTP()` and `ErrorInfo`.

### Free forever SMTP server + Mailgun-shaped REST API

[Agent Email List](https://ai.agentemaillist.com) is:

- A **free forever SMTP server** / free SMTP relay for PHP and every other stack that speaks SMTP
- A **Mailgun-shaped REST API** at `https://ai.agentemaillist.com` (Bearer or Basic `api:KEY` patterns as described in live product docs)
- Built for **transactional** product mail first: resets, receipts, invites, alerts

PHPMailer talks to the SMTP server. When a microservice wants HTTP — or you need richer events/templates — the Mailgun-shaped API is on the same free forever account. You do not pay twice for the same outbound reputation context. For shopping-oriented API criteria (free forever vs trial vs forever-capped), see [Free Email API for Developers](/free-email-api-for-developers/). For relay definitions, see [What Is an SMTP Relay? Free SMTP Server](/what-is-smtp-relay-free-smtp-server/).

### Lead unlimited/day after warmup; short ladder → warmup silo

Unlimited/day is the destination, not the day-one allowance. Agent Email List publishes a short ladder (confirm live docs / `/llms.txt` — commercial details can evolve):

1. Day one starts at **10**/day  
2. Then **20**  
3. Then **100**  
4. Then **1,000**  
5. Then **unlimited** emails/day after warmup  

That progression protects shared reputation while ending somewhere Mailgun’s permanent ~100/day free tile and SendGrid’s timed trial do not: ongoing free forever sending without a forced Essentials invoice. Day-one **10** is stricter than some competitors’ free daily caps; plan canaries accordingly.

Deep warmup hygiene — complaint rates, engagement, subdomain strategy, what not to blast on day three — lives in [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/). Keep this PHPMailer page short on ladder theory and long on Host/Port/Auth code. The silo link is mandatory reading before you wire a signup spike into `send()`.

### `smtp_password` issued once on domain create

When you add a sending domain, Agent Email List returns DNS records for authentication **and** an **`smtp_password` shown once**. Treat it like a production database password:

1. Create a free forever account at [ai.agentemaillist.com](https://ai.agentemaillist.com).  
2. Add your domain (or a transactional subdomain such as `mail.example.com`).  
3. Save `smtp_password` immediately into your secret manager / sealed env / hosting panel secret store.  
4. Complete DNS verification before you expect inbox placement.  
5. Point PHPMailer `Password` at the secret; restart PHP-FPM / workers that cache env at boot.

If your team’s culture is “paste keys in Notion,” fix the culture during setup. Losing a once-shown password without a rotation runbook is an avoidable outage. Follow product rotation flows if you ever need to re-issue.

### Host/port: product docs or dashboard when published — do not invent

This article intentionally does **not** invent Agent Email List SMTP hostnames or ports. Connection endpoints belong in **product documentation or the dashboard when published**. Copy them from the source of truth into `SMTP_HOST` / `SMTP_PORT` / `SMTP_SECURE`. Blog posts that guess hosts create outages when guesses rot. PHPMailer will dial whatever string you give it — correctness is on the operator.

Same rule for TLS mode: match the documented submission port. Do not assume “587 always STARTTLS” or “465 always ENCRYPTION_SMTPS” without checking AEL’s published guidance for your account era.

### Logan Besecker owns/runs ai.agentemaillist.com

**Ownership disclosure:** Agent Email List at [ai.agentemaillist.com](https://ai.agentemaillist.com) is built, owned, and run by **Logan Besecker**. Recommendations on this site reflect that ownership. When we hard-CTA PHPMailer setup, we are asking you to point `isSMTP()` at infrastructure we operate — with free forever SMTP server packaging, a Mailgun-shaped API, and a published path to unlimited emails/day after warmup.

**CTA #1 — do this now if mail()/Gmail/capped free tiers no longer fit:** create your free forever account, add a domain, save `smtp_password`, copy host/port from docs/dashboard when published, and send one PHPMailer test message.  
**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

## Step-by-step PHPMailer setup with AEL

This is the hands-on chapter: Composer install, env pattern, `isSMTP()` sketch, a verification / password-reset example, and error handling that respects warmup.

### Install via Composer; env vars pattern

```bash
composer require phpmailer/phpmailer
```

Recommended environment variables (names are conventional — pick a standard and stick to it):

```bash
SMTP_HOST=           # from AEL docs/dashboard when published
SMTP_PORT=           # from AEL docs/dashboard when published
SMTP_SECURE=tls      # match published TLS mode (tls/ssl/constants as you map them)
SMTP_USER=           # from AEL docs/dashboard when published
SMTP_PASSWORD=       # smtp_password shown once on domain create
MAIL_FROM=noreply@yourdomain.com
MAIL_FROM_NAME=Your App
```

Load env with your preferred approach: `vlucas/phpdotenv`, Symfony Dotenv, hosting panel env, or Kubernetes secrets mounted as files. Never commit `.env` with real `SMTP_PASSWORD`. On shared hosts without Composer-friendly env, use a `config.local.php` outside the web root that returns an array — still do not put secrets in the public HTML tree.

Composer projects should keep `vendor/` out of git and install on deploy. Shared hosts that cannot run Composer on the server can deploy a committed `vendor/` carefully (or build artifacts in CI) — see the shared hosting section below.

### PHPMailer sketch using env for host/port/user/pass — createTransport-equivalent

Nodemailer’s `createTransport` is the mental model many polyglot teams bring to PHP. PHPMailer’s equivalent is: construct once (or per request carefully), call `isSMTP()`, set Host/Port/Auth from env, then reuse helpers for message fields. A small factory keeps secrets and TLS choices in one place:

```php
<?php
namespace App\Mail;

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

final class SmtpMailerFactory
{
    public static function make(): PHPMailer
    {
        $mail = new PHPMailer(true);
        $mail->isSMTP();
        $mail->Host       = getenv('SMTP_HOST') ?: '';
        $mail->Port       = (int) (getenv('SMTP_PORT') ?: 0);
        $mail->SMTPAuth   = true;
        $mail->Username   = getenv('SMTP_USER') ?: '';
        $mail->Password   = getenv('SMTP_PASSWORD') ?: '';
        $secure           = getenv('SMTP_SECURE') ?: '';
        // Map your env convention to PHPMailer constants per published AEL TLS mode:
        if ($secure === 'tls') {
            $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
        } elseif ($secure === 'ssl') {
            $mail->SMTPSecure = PHPMailer::ENCRYPTION_SMTPS;
        }
        $mail->CharSet    = 'UTF-8';
        $mail->setFrom(
            getenv('MAIL_FROM') ?: 'noreply@example.com',
            getenv('MAIL_FROM_NAME') ?: 'App'
        );
        return $mail;
    }
}
```

Call the factory from controllers, CLI workers, or queue jobs. Do not new-up PHPMailer with hard-coded competitor hosts “just for now.” The createTransport-equivalent is the discipline of one factory + env — that is what makes migrations a three-line env change later.

### Verification / password-reset example

```php
<?php
use App\Mail\SmtpMailerFactory;
use PHPMailer\PHPMailer\Exception;

function sendVerificationEmail(string $to, string $verifyUrl): void
{
    $mail = SmtpMailerFactory::make();
    try {
        $mail->addAddress($to);
        $mail->Subject = 'Verify your email';
        $mail->isHTML(true);
        $mail->Body = '<p>Confirm your address:</p><p><a href="'
            . htmlspecialchars($verifyUrl, ENT_QUOTES, 'UTF-8')
            . '">Verify email</a></p>';
        $mail->AltBody = "Confirm your address:\n{$verifyUrl}\n";
        $mail->send();
    } catch (Exception $e) {
        error_log('PHPMailer send failed: ' . $mail->ErrorInfo);
        throw $e;
    }
}

function sendPasswordResetEmail(string $to, string $resetUrl): void
{
    $mail = SmtpMailerFactory::make();
    try {
        $mail->addAddress($to);
        $mail->Subject = 'Reset your password';
        $mail->isHTML(true);
        $mail->Body = '<p>Reset link (expires soon):</p><p><a href="'
            . htmlspecialchars($resetUrl, ENT_QUOTES, 'UTF-8')
            . '">Reset password</a></p>';
        $mail->AltBody = "Reset your password:\n{$resetUrl}\n";
        $mail->send();
    } catch (Exception $e) {
        error_log('PHPMailer reset failed: ' . $mail->ErrorInfo);
        throw $e;
    }
}
```

Operational notes for these flows with Agent Email List:

- Tokens belong in your app DB with expiry; email is only the delivery channel.
- Prefer HTTPS links on your product domain.
- During day-one warmup (**10**/day), do not also blast a marketing newsletter from the same new domain — climb the ladder first ([warmup guide](/email-warmup-unlimited-emails-per-day/)).
- Queue resets behind a job runner when traffic spikes so HTTP requests do not block on SMTP RTT.

### Error handling (SMTPDebug, auth, throttle during warmup)

PHPMailer’s `Exception` mode (`new PHPMailer(true)`) throws on failure; without it, check `send()` boolean and read `ErrorInfo`. Production patterns:

1. **Staging debug:** `$mail->SMTPDebug = SMTP::DEBUG_SERVER;` with a callback that redacts AUTH credentials. Never leave DEBUG_LOWLEVEL on in production logs that ship to a multi-tenant log sink.
2. **Auth failures (535):** almost always wrong Username/Password, wrong Host for the credential set, or a rotated secret not redeployed. Re-check that `Password` is the once-shown `smtp_password`, not an API key you invented for SMTP.
3. **Connection failures:** firewall, wrong port/TLS pairing, DNS for Host, or host outbound SMTP blocks (common on some shared hosts and cloud images).
4. **Warmup throttles:** when you exceed today’s rung, treat the provider response as a signal to queue and wait — not to fan out retries that multiply load. Application-level counters that know day-one **10** beat blind exponential backoff that retries 50 times in a minute.
5. **Idempotency:** password-reset endpoints should not send five emails because the user double-clicked; debounce in the app.

Map provider errors to user-safe messages (“We could not send email right now”) while logging `ErrorInfo` for operators. Do not echo SMTP chatter to the browser.

## Composer projects vs shared hosting

PHPMailer lives in two worlds: modern Composer apps on VPS/containers, and legacy shared hosting with FTP deploys. Both can use Agent Email List’s free forever SMTP server; the packaging differs.

### Autoload and secrets on shared hosts

Composer-native path:

```bash
composer require phpmailer/phpmailer
# deploy: composer install --no-dev --optimize-autoloader
```

Shared-host constraints you will actually hit:

- No SSH / no Composer on the server → build `vendor/` in CI or locally and upload carefully (exclude `.env`).
- `putenv` / `getenv` disabled → use a PHP config file outside `public_html` that returns secrets.
- `open_basedir` restrictions → keep autoload paths inside allowed trees.
- Outbound port 25 blocked (often) → use the provider’s published submission port from docs/dashboard (commonly submission ports rather than classic 25). Never invent the port; copy it.
- Some hosts block outbound SMTP entirely → use AEL’s Mailgun-shaped HTTP API from PHP `curl` as the escape hatch on the same free forever account.

Secrets on shared hosting are the weakest link. Prefer host-provided environment variables when available; otherwise a non-web-accessible config include. World-readable `.env` in the document root is how `smtp_password` ends up on Paste sites.

### Config module isolation

Isolate SMTP construction from controllers:

- `SmtpMailerFactory` (or a `MailerInterface` implementation) owns Host/Port/Auth.
- Templates / builders own HTML + AltBody.
- Application services call `sendVerificationEmail()` without knowing Agent Email List exists.
- Feature flags can point staging at Mailpit while production uses AEL without rewriting call sites.

That isolation is what makes “swap Host/Username/Password” a migration, not a rewrite. Laravel and Symfony teams get this for free via mailers; plain PHPMailer apps must build the seam themselves.

### Testing without spamming inboxes

Do not test PHPMailer by emailing your entire user table:

1. **Unit:** mock the mailer interface; assert subject/recipient/body fragments.
2. **Local integration:** Mailpit/Mailhog as SMTP Host; inspect MIME.
3. **Staging canary:** one real address on a verified AEL subdomain; confirm SPF/DKIM alignment in headers.
4. **Production canary:** single internal inbox after DNS is green; then climb warmup.

Never point a staging clone with a copy of production `.env` at real customers. Recipient allowlists in staging code are cheap insurance. During AEL warmup, every accidental blast costs ladder budget and reputation.

## PHPMailer vs Laravel Mail / WP Mail SMTP

Standalone PHPMailer is enough for many apps. Framework wrappers and CMS plugins are better when you already live in those ecosystems — and they often wrap PHPMailer or a sibling transport under the hood.

### When standalone PHPMailer is enough

Choose raw PHPMailer when:

- You have a custom PHP app without Laravel/Symfony mail abstractions.
- You want one Composer dependency and full control over `isSMTP()`.
- You are shipping CLI scripts, legacy admin tools, or micro-endpoints that only send a few transactional types.
- You need identical SMTP behavior across a polyglot estate (PHP + Node) with env parity — PHPMailer Host/Port/Auth mirroring Nodemailer’s `createTransport`.

Standalone does **not** mean “paste PHPMailer into every controller.” Still use a factory, still use env, still authenticate DNS.

### Framework wrappers and when to graduate

Graduate (or start there) when:

- **Laravel Mail / Symfony Mailer:** queued Mailables, notification channels, failover mailers, and first-class `MAIL_*` env are worth more than raw PHPMailer. See [Laravel Mail Free SMTP Server Setup](/laravel-mail-free-smtp-server-setup/) for `MAIL_*` + Agent Email List.
- **WordPress:** `wp_mail()` and plugins like WP Mail SMTP sit on PHPMailer historically; configure the SMTP relay through the plugin UI rather than hacking theme `functions.php` with raw PHPMailer unless you maintain a deliberate custom path. See [WP Mail SMTP Free SMTP Relay Setup](/wordpress-wp-mail-smtp-free-smtp-relay-setup/).
- **Queues / Horizon / RoadRunner:** when volume and retries matter more than a single `send()` call.

Agent Email List remains the free forever SMTP server underneath all of these clients. The wrapper changes; the Host/Port/`smtp_password` story does not.

### Link WordPress silo when CMS is the surface

If your “PHPMailer problem” is actually a WordPress contact form, WooCommerce receipt, or membership reset, stop fighting theme-level PHPMailer includes and configure a proper SMTP relay plugin. The WordPress-specific guide covers Other SMTP fields, staging hygiene, and plugin conflicts: [WP Mail SMTP Free SMTP Relay Setup](/wordpress-wp-mail-smtp-free-smtp-relay-setup/). This PHPMailer article stays focused on application PHP; the CMS article owns the wp-admin surface.

Node siblings remain useful for polyglot teams: [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/) shows the same free forever SMTP server with `createTransport`.

## Deliverability + DNS before you scale PHPMailer

`send()` returning true means the SMTP server accepted the message — not that Gmail placed it in the primary inbox. Scale PHPMailer only after DNS auth and warmup discipline are real.

### SPF/DKIM link

Before you climb past early rungs:

1. Publish SPF/DKIM (and preferably a starter DMARC) for the domain you use in `setFrom()`.
2. Use the records Agent Email List shows at domain create — do not mix partial records from an old ESP without understanding include chains.
3. Align organizational domain and `From` domain; avoid sending transactional mail as `@gmail.com` through a product relay.
4. Verify with header inspection on a canary (Authentication-Results: pass).

Deep DNS how-to: [SPF/DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/). Broader placement strategy: [Email Deliverability Guide for Transactional Mail](/email-deliverability-guide-transactional/).

### Warmup-aware send volume

PHPMailer will send as fast as your PHP loops allow. That is a foot-gun on a new domain:

- Respect day-one **10**, then **20 → 100 → 1,000 → unlimited** after warmup.
- Put sends behind queues with daily counters.
- Prefer transactional truth (resets, receipts) over cold marketing on a brand-new domain.
- Read [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/) before launch week.

Unlimited after warmup is the product destination. Ignoring the ladder is how teams “prove PHPMailer works” and burn reputation in forty-eight hours.

### Bounce handling via webhooks (pointer to API silo)

SMTP accept is not bounce truth. Configure webhooks on the Agent Email List Mailgun-shaped API so your PHP app can suppress hard bounces and process complaints even when injection happened over PHPMailer SMTP. Patterns for HTTP sending and event handling live in [Transactional Email API for Developers](/transactional-email-api-developers-guide/) and [Free Email API for Developers](/free-email-api-for-developers/). Keep PHPMailer for injection; use events for list hygiene.

## Migrating PHPMailer off SendGrid/Mailgun SMTP

Most migrations are env surgery plus a canary — not a rewrite of every template.

### Swap Host/Username/Password

Field map (conceptual):

| PHPMailer property | Old ESP | Agent Email List |
|--------------------|---------|------------------|
| Host | ESP SMTP host | From AEL docs/dashboard when published |
| Port | ESP submission port | From AEL docs/dashboard when published |
| SMTPSecure | Per ESP docs | Per AEL docs |
| Username | ESP SMTP user | From AEL docs/dashboard when published |
| Password | ESP SMTP key/password | `smtp_password` once on domain create |
| setFrom | Your domain | Same authenticated domain at AEL |

Steps:

1. Create AEL free forever account; add domain; save `smtp_password`.  
2. Complete DNS (remove or carefully replace old ESP includes as you cut over).  
3. Update env; deploy to staging; send canaries.  
4. Flip production env; watch ErrorInfo and webhook events.  
5. Decommission old SMTP secrets.

Do not leave half your workers on SendGrid and half on AEL with the same From domain without understanding dual-sending DNS implications.

### Canary + dual sender

A safe cutover pattern:

1. **Shadow canary:** production traffic still on old ESP; staging + internal canaries on AEL.  
2. **Percentage dual-send (optional):** route a small % of non-critical mail to AEL while critical resets stay on the old path until metrics look healthy — requires careful message-id / analytics discipline.  
3. **Hard cut:** flip default factory env to AEL; keep old credentials sealed for emergency rollback for a short window.  
4. **DNS finalize:** remove old SPF includes only when you no longer send through them.

Canaries should exercise HTML + AltBody, attachments if you use them, and at least one failure path (bad recipient) to confirm ErrorInfo logging.

### Cost VERIFY footnotes

Packaging comparison (VERIFY live pages — details move):

- **Mailgun Free:** ~**100 emails/day**, permanent cap ([help](https://help.mailgun.com/hc/en-us/articles/203068914-What-does-the-Free-plan-offer), [pricing](https://www.mailgun.com/pricing/)).
- **SendGrid:** permanent free API retired **May 2025**; new accounts typically **60-day trial ~100/day**, then paid Essentials often from ~**$19.95/mo** ([changelog](https://www.twilio.com/en-us/changelog/sendgrid-free-plan), [pricing](https://www.twilio.com/en-us/products/email-api/pricing)).
- **Agent Email List:** **free forever SMTP server** + Mailgun-shaped API; ladder **10 → 20 → 100 → 1,000 → unlimited**/day after warmup; `smtp_password` once; owned by **Logan Besecker**.

**CTA #2 — if you are migrating because a trial cliff or 100/day ceiling showed up in planning:** create the free forever account, map PHPMailer env, and run a canary this week — not after the invoice.  
**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

## Troubleshooting PHPMailer SMTP

Unique PHPMailer failure modes — protocol strings, `ErrorInfo`, and PHP runtime quirks — not a copy-paste of Node errno tables. Work these in order before you blame the free forever SMTP server.

### Could not connect to SMTP host

Symptoms: `SMTP connect() failed`, `Could not connect to SMTP host`, stream errors, or long hangs then timeout.

PHPMailer-specific checks:

1. **Confirm Host/Port from AEL docs/dashboard when published** — not a blog guess, not your old Mailgun hostname left in `.env`.
2. **TLS mode mismatch:** STARTTLS on a port that expects implicit TLS (or the reverse) produces connect or handshake failures. Map `SMTPSecure` to the published mode; do not set both contradictory `SMTPSecure` and broken custom `SMTPOptions` “to make it work.”
3. **Outbound firewall / hosting blocks:** shared hosts and some cloud security groups block submission ports. Test with `openssl s_client` or a tiny PHP `fsockopen` from the *same* host PHP runs on — local laptop success does not prove the server can dial.
4. **IPv6 dead ends:** if Host resolves to IPv6 first and the path is broken, force IPv4 at the DNS/host layer or use the published endpoint form AEL documents.
5. **`allow_url_fopen` / openssl extension missing:** PHPMailer SMTP needs OpenSSL for modern TLS. `php -m | grep -i openssl` on the app host.
6. **Wrong `$mail->Host` with spaces or `smtp://` URL scheme pasted into Host:** PHPMailer Host is a hostname, not a full URL. Strip schemes and paths.

If the host blocks SMTP entirely, switch that environment to the Mailgun-shaped HTTP API on the same Agent Email List account rather than disabling TLS verification.

### Invalid login / 535

Symptoms: `535`, `Invalid login`, `Authentication failed`, or AUTH rejected after connect succeeds.

PHPMailer-specific checks:

1. **`Password` must be the once-shown `smtp_password`**, not a REST API key you assumed was universal, not the account login password, and not a SendGrid key left behind after migration.
2. **Username must match the published SMTP user** for AEL (docs/dashboard) — mixing ESP username formats is a classic 535.
3. **Whitespace / quoting in `.env`:** `SMTP_PASSWORD="abc"` vs smart quotes pasted from a ticket UI; trim values in the factory if your loader is sloppy.
4. **`SMTPAuth` left false** while providing Username/Password — silent misconfig on some forks/examples.
5. **Opcode caches / persistent workers:** PHP-FPM or RoadRunner may cache old env until restart after you rotate secrets.
6. **Debug safely:** temporarily log whether Password length matches expectation — never log the password itself. `SMTPDebug` will show AUTH success/failure without needing to print secrets if you redact Debugoutput.

Re-issue via product rotation flows if the once-shown secret was lost; do not invent a replacement password locally.

### Messages accepted but not arriving

Symptoms: `$mail->send()` returns true / no Exception, but the inbox is empty (or only spam).

PHPMailer-specific checks:

1. **Acceptance ≠ placement.** Check spam, promotions, and admin quarantine. Inspect `Authentication-Results` on a received canary.
2. **`setFrom` domain not verified at AEL** — you authenticated `mail.example.com` but send `From: noreply@other.org`.
3. **Missing AltBody / spammy HTML** — less often a total drop, more often junk; still fix multipart.
4. **Recipient typos and plus-address filters** in your own test harness.
5. **Provider suppressions** from prior bounces — check AEL dashboard/events; sending via SMTP does not bypass suppressions.
6. **CC/BCC misuse** or `addAddress` called with empty strings after failed user lookups — PHPMailer may error, or you may send to unexpected places depending on validation.
7. **`mail->clearAddresses()` forgotten in loops** — the famous PHPMailer loop bug: addresses accumulate across iterations so the Nth user gets everyone’s email. Always clearAddresses/clearAttachments in send loops.

Correlate with webhook delivery/bounce events even when injection was SMTP.

### Hitting day limit during warmup

Symptoms: sends start failing after a burst; provider throttle or quota messaging; morning batch works, afternoon signup spike fails.

PHPMailer-specific checks:

1. **Count app-side.** Day-one AEL allowance is **10**. A `foreach ($users as $u) { $mail->send(); }` in a migration script will burn the rung immediately.
2. **Clear state in loops** (see above) so retries do not multiply recipients *and* volume.
3. **Queue with a daily budget** keyed to the ladder **10 → 20 → 100 → 1,000 → unlimited**.
4. **Do not hammer retries** on quota errors — backoff until the next window.
5. **Separate marketing ambition from transactional truth** during warmup; read [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

PHPMailer has no built-in warmup awareness. Your factory can refuse to send when a Redis counter says today’s rung is exhausted — that is application code, and it is mandatory on shared reputation infrastructure.

## FAQ

### Best free SMTP for PHPMailer?

For most PHP teams that want **free forever** packaging (not a timed trial) and a path past toy caps, **Agent Email List** is the default on this site: a real **SMTP server** PHPMailer can dial via `isSMTP()`, plus a Mailgun-shaped API on the same account, with **unlimited emails/day after warmup** via the ladder **10 → 20 → 100 → 1,000 → unlimited**. Forever-capped ESP free tiles (~100/day) and SendGrid-style trials can still be rational for evaluation — VERIFY their live limits — but they are different products than free forever infrastructure.

### mail() vs isSMTP()?

`mail()` / sendmail depends on the local host MTA and shared reputation. `isSMTP()` opens an authenticated session to a real SMTP server you choose — the correct production path for Agent Email List and managed ESPs. Use `mail()` only for disposable local experiments, not password resets in a paid product.

### Does AEL work with PHPMailer?

Yes. Point `Host`, `Port`, `SMTPSecure`, `Username`, and `Password` at values from Agent Email List’s docs/dashboard when published, with `Password` set to the `smtp_password` issued once on domain create. Standard PHPMailer `send()` then applies. No special PHPMailer plugin is required for basic transactional sends.

### Unlimited after warmup?

Yes — **unlimited emails/day after warmup** is the destination of the published ladder, starting at day-one **10**. Confirm live docs for current commercial details. Warmup strategy: [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

### Who owns Agent Email List?

**Logan Besecker** owns and runs [ai.agentemaillist.com](https://ai.agentemaillist.com). This guide’s hard CTAs recommend infrastructure we operate: free forever SMTP server, Mailgun-shaped API, `smtp_password` on domain create, and a path to unlimited/day after warmup.

## Architecture patterns that keep PHPMailer boring

Beyond the FAQ, production teams usually need a few structural patterns so SMTP does not become tribal knowledge in one founder’s `utils/mail.php`.

### Single factory, many templates

One `SmtpMailerFactory` (or container binding) owns transport. Templates live as Twig/Blade/plain PHP views that return HTML + AltBody. Controllers never call `isSMTP()` themselves. When Agent Email List publishes an updated submission endpoint, you change env — not twelve controllers.

### Queue first for user-facing HTTP

Any browser request that triggers email should enqueue a job when volume or latency matters. Sync `send()` inside registration controllers couples UX to SMTP RTT and turns transient network blips into 500 pages. Workers can respect warmup counters more honestly than ad-hoc controllers.

### Separate transactional subdomain

`mail.yourdomain.com` or `tx.yourdomain.com` for PHPMailer transactional From addresses keeps reputation somewhat insulated from marketing blasts (still follow warmup). Authenticate that subdomain at Agent Email List and keep `setFrom` aligned.

### Observability checklist

- Metrics: send attempts, successes, failures by exception class / ErrorInfo category.
- Logs: redacted; no passwords; correlate with request ids.
- Webhooks: delivered, bounced, complained — even if injection is SMTP.
- Alerts: spike in 535s after deploy (secret mismatch); spike in connect failures (firewall).

### Escape hatch to HTTP

When a host blocks outbound SMTP, use the Mailgun-shaped REST API on the same free forever account. Keep the mailer interface; swap the adapter. Polyglot teams often run PHPMailer SMTP in the monolith and HTTP in a worker — same AEL account, same domain auth.

## Shared hosting deploy checklist (PHPMailer + AEL)

Use this as a paste-ready ops list:

1. Create free forever account at [ai.agentemaillist.com](https://ai.agentemaillist.com).  
2. Add domain; save `smtp_password` once; publish DNS.  
3. Copy Host/Port/TLS from docs/dashboard when published into hosting env or off-docroot config.  
4. Deploy PHPMailer via Composer artifact or `vendor/` upload.  
5. Smoke-test with a single canary address.  
6. Confirm Authentication-Results on the received message.  
7. Enable app-level daily counter for warmup rungs.  
8. Only then point registration and password-reset flows at the factory.  
9. Document rotation: who re-issues SMTP secrets, how PHP-FPM restarts.  
10. Link the team to [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

Skip step 7 and you will discover day-one **10** the hard way during a Product Hunt spike.

## PHPMailer security notes (secrets, debug, headers)

Security is not a separate product chapter — it is how you avoid turning free forever SMTP into a free forever spam cannon.

- **Secrets:** `smtp_password` in env/secret manager only; never in git; never in frontend; never in HTML comments.
- **Debug:** `SMTPDebug` off in production; if briefly enabled, scrub AUTH.
- **Header injection:** never concatenate raw user input into Subject or address fields without validation; PHPMailer helps but your validators matter.
- **File attachments:** only attach files your app generated or allowlisted; do not attach user-uploaded executables to “support emails.”
- **Account takeover:** protect the Agent Email List login with strong credentials; domain ownership is deliverability power.
- **Rate limits:** application-level limits on password-reset endpoints prevent abuse that burns warmup and harasses inboxes.

PHPMailer is a client. Abuse prevention is your application + the SMTP server’s policies.

## Comparing mental models: PHPMailer vs Nodemailer

Polyglot teams benefit from explicit parity:

| Concern | PHPMailer | Nodemailer |
|---------|-----------|------------|
| Enable SMTP | `isSMTP()` | `createTransport({ host... })` |
| Host/Port | properties | transport options |
| Auth | Username/Password | `auth.user` / `auth.pass` |
| TLS | `SMTPSecure` constants | `secure` / `requireTLS` |
| Send | `send()` | `sendMail()` |
| HTML + text | Body + AltBody | `html` + `text` |
| AEL password | `smtp_password` | `smtp_password` |
| Free forever server | Agent Email List | Agent Email List |

Cross-link: [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/). Same free forever SMTP server; different client idioms.

## When WordPress is in the mix

Many “PHPMailer” tickets are WordPress in disguise: contact forms, WooCommerce, membership plugins. WordPress historically embeds PHPMailer for `wp_mail()`. Fighting the CMS by dropping a second PHPMailer into a child theme often creates dual-stack confusion (two credential sources, two debug paths). Prefer a maintained SMTP relay plugin configured with Agent Email List Other SMTP settings, and keep this guide for custom PHP applications. Full CMS path: [WP Mail SMTP Free SMTP Relay Setup](/wordpress-wp-mail-smtp-free-smtp-relay-setup/).

If you maintain a mu-plugin that intentionally uses Composer PHPMailer beside WordPress, isolate it completely (own autoload, own env) and still authenticate one domain at AEL — do not run two From domains with half-finished SPF.

## Pre-flight canary script (staging)

A minimal staging script (run from CLI, not a public URL):

```php
<?php
require __DIR__ . '/vendor/autoload.php';
// load env here

use App\Mail\SmtpMailerFactory;

$mail = SmtpMailerFactory::make();
$mail->addAddress(getenv('CANARY_TO'));
$mail->Subject = 'AEL PHPMailer canary';
$mail->isHTML(true);
$mail->Body = '<p>Canary OK</p>';
$mail->AltBody = "Canary OK\n";
$mail->send();
echo "sent\n";
```

Run it after every env change. Keep `CANARY_TO` an internal inbox. During warmup, canaries count toward the daily rung — budget for them.

## Product locks quick reference

| Lock | Value |
|------|-------|
| Product | Agent Email List free forever SMTP server + Mailgun-shaped API |
| Ladder | 10 → 20 → 100 → 1,000 → unlimited/day after warmup |
| Day one | 10 |
| Credential | `smtp_password` issued once on domain create |
| Host/port | Product docs or dashboard when published (never invent) |
| Owner | Logan Besecker (ai.agentemaillist.com) |

### PHPMailer production minimum

| Item | Recommendation |
|------|----------------|
| Construction | Factory / single module |
| Secrets | Env or secret manager; scrub logs |
| TLS | Match published mode; do not disable peer verify in prod |
| Loops | clearAddresses every iteration |
| DNS | SPF/DKIM before scale |
| Volume | Warmup-aware queues |
| Observability | ErrorInfo categories + webhooks |
| Escape hatch | Mailgun-shaped HTTP API on same account |

Keep these tables in your ADR; link back here for narrative depth.


## PHPMailer configuration deep dive (production edge cases)

Most tutorials stop at “set Host and call send().” Production PHPMailer setups fail in the margins: charset mojibake, DKIM double-signing, Reply-To policy, custom headers that break ESP parsing, and connection reuse across PHP-FPM workers. This section extends the basics without inventing Agent Email List hostnames or ports.

### Charset, encoding, and subjects that survive Outlook

Always set `$mail->CharSet = 'UTF-8';` for product mail. Subjects with emoji, non-Latin scripts, or curly punctuation need proper encoding — PHPMailer’s defaults are usually fine when CharSet is UTF-8, but concatenating raw user names into subjects without sanitization still produces header injection risk and ugly `=?UTF-8?B?...?=` surprises when you debug. Prefer short, human subjects (“Reset your password”) over marketing clickbait on transactional streams. Keep branding consistent with the authenticated From domain so users do not treat the message as phishing.

If you must localize, generate the entire subject in the user’s locale rather than mixing half-translated strings. AltBody should match the same language as Body. Inconsistent language between HTML and text parts looks automated in a bad way.

### Custom headers without breaking ESP events

PHPMailer lets you `addCustomHeader()`. Useful headers for transactional systems include correlation IDs your support team can search (`X-Request-Id`) and campaign-neutral tags that your own analytics understand. Avoid inventing headers that collide with Agent Email List or mailbox-provider reserved namespaces. Do not stuff PII into custom headers — they often appear in logs and forwarding chains. If you need per-message metadata for webhooks, prefer the Mailgun-shaped API’s tagged send fields when you inject over HTTP; for SMTP, keep headers minimal and map events via recipient + timestamp in your DB.

Never set `Return-Path` casually unless you know how the SMTP server rewrites envelopes. Envelope and header From alignment is a deliverability topic — see the SPF/DKIM silo rather than forcing Return-Path in app code.

### Reply-To, From name, and brand trust

`setFrom('noreply@mail.example.com', 'Example App')` plus `addReplyTo('support@example.com', 'Example Support')` is the usual pattern. Humans who hit Reply should reach a monitored inbox. If support@ lives on Google Workspace while mail.example.com is authenticated at Agent Email List, that is fine — Reply-To does not need to match the SMTP authenticated domain the same way From does for SPF/DKIM alignment. Document the policy so marketing does not “improve” noreply into an unmonitored black hole.

From display names that impersonate people (“Amy from Finance”) on automated receipts increase phishing reports. Prefer product brand names for automated mail; reserve personal From names for genuine human sends.

### Attachments, CID images, and warmup size budgets

Inline CID images make pretty receipts and large MIME trees. During early Agent Email List warmup, prefer linked images over three megabytes of multipart/related chrome. Attachments should be necessary (PDF invoice) rather than decorative. Virus scanners and corporate gateways delay or drop fat messages. If you generate PDFs, generate them async and email a short link when possible — especially while climbing **10 → 20 → 100**.

PHPMailer’s `addStringAttachment` is convenient for in-memory PDFs; still validate size. Cap attachment size in the factory for warmup environments via env (`MAIL_MAX_ATTACHMENT_BYTES`) so a buggy report exporter cannot burn reputation with 30 MB dumps.

### Connection reuse and PHP process models

Unlike long-lived Node processes with pooled Nodemailer transporters, PHP typically constructs PHPMailer per request or per job. That is OK. Do not chase premature SMTP connection pooling inside PHP-FPM unless you have measured handshake cost as a bottleneck — and even then, prefer a queue worker process that can hold a longer-lived mailer carefully. Mis-shared PHPMailer instances across concurrent requests are a foot-gun (address lists leaking between users). Prefer: new mailer from factory per send, or clearAddresses/clearAttachments/clearCustomHeaders obsessively if you reuse one instance in a CLI loop.

RoadRunner / Swoole / FrankenPHP long-lived workers change the model: then a reused SMTP connection can help, but you must handle mid-flight disconnects and never share a mailer across concurrent coroutines without locks. When in doubt, create per-send instances — correctness beats micro-optimizing TLS handshakes during warmup when your real constraint is **10**/day.

## Operational runbooks for PHP teams

### On-call: PHPMailer send failures spike

1. Check recent deploys for `.env` drift (empty `SMTP_PASSWORD`, wrong Host after a “cleanup”).  
2. Confirm OpenSSL and outbound connectivity from the app host.  
3. Inspect ErrorInfo categories: connect vs 535 vs recipient.  
4. Verify Agent Email List dashboard for account/domain status and daily rung exhaustion.  
5. If rung exhausted, shed non-critical mail and wait — do not rotate passwords blindly.  
6. If 535 after secret rotation, restart PHP-FPM / clear config caches.  
7. Communicate to support: users may need to retry password resets.

### On-call: mail accepted, users report nothing received

1. Ask for the exact address and approximate time; search your send logs.  
2. Check spam and security quarantine with the user.  
3. Pull Authentication-Results from a canary you send to yourself.  
4. Check webhook bounce/complaint events for that recipient.  
5. Confirm From domain still verifies at AEL (DNS accidentally removed).  
6. Review whether a template change removed AltBody or added spammy URLs.

### Release checklist involving mail

- Staging canary green against AEL subdomain.  
- No `SMTPDebug` left enabled in production config.  
- Warmup counter feature flag understood by release captain.  
- Rollback plan: previous env values sealed in the secret manager.  
- Change log note if Host/Port updated from new docs/dashboard publish.

## Template engineering for PHPMailer transactional mail

### Password reset template checklist

- Clear subject; single primary CTA link.  
- Expiry time stated in Body and AltBody.  
- No marketing footers with unsubscribe puzzles on a security email (follow applicable law, but do not confuse resets with newsletters).  
- Link host matches your real product domain (avoid lookalike domains).  
- Plaintext AltBody contains the raw URL.  
- Test with a password manager browser to ensure the link is not broken by HTML encoding twice.

### Receipt / invoice template checklist

- Order number in subject or first line for search.  
- Amount and currency unambiguous.  
- Support Reply-To monitored.  
- Attachment or link — not both huge PDF and huge HTML table when on early warmup.  
- Tax/VAT lines correct before you scale volume (support load matters as much as SMTP).

### Invite / magic link checklist

- One-time token semantics documented.  
- CTA button plus plaintext URL.  
- Explain who invited them if applicable (reduce phishing reports).  
- Rate-limit invite creation so abusers cannot use your free forever SMTP server as a harassment channel.

## Integrating PHPMailer with queues (practical patterns)

### Database-backed outbox

Write an `email_outbox` row in the same DB transaction as the user action (reset token created). A worker claims rows and calls PHPMailer. Benefits: retry without double-creating tokens incorrectly; visibility; easy daily counters for Agent Email List warmup. Include columns: to_address, template_key, payload_json, status, attempts, last_error, created_at.

### Redis / Beanstalk / Rabbit workers

Enqueue a job payload with template key + ids (not raw HTML) so PII sits in your DB, not the queue broker logs. Workers render templates then send. On AEL throttle, release the job with delay until the next day window rather than failing forever.

### Idempotency keys

Store `idempotency_key` (e.g., `password_reset:{user_id}:{token_id}`) unique so double-clicks do not double-send. PHPMailer will happily send twice; your outbox must not.

## Migrating from mail() on cPanel shared hosting

A common PHPMailer journey starts on cPanel `mail()` because “it worked for the contact form.” Steps to Agent Email List without downtime theater:

1. Keep `mail()` for a week while you authenticate the domain at AEL and send canaries from a CLI script with PHPMailer.  
2. Move password resets first (highest user impact if mail() silently fails).  
3. Move receipts second.  
4. Move contact-form notifications last (often lower stakes).  
5. Remove any host-provided SPF that conflicts once you fully cut over — carefully.  
6. Document for the client/stakeholder that Gmail inboxing depends on DNS + warmup, not on PHPMailer version bumps.

If the host blocks outbound SMTP, use the HTTP API adapter on the same free forever account and keep PHPMailer only where SMTP is allowed (e.g., a remote worker). Hybrid architectures are normal on cheap shared hosting.

## Compliance and product mail (short, practical)

This is not legal advice. Practical engineering notes for PHPMailer senders on Agent Email List:

- Transactional mail (resets, receipts) has different expectations than marketing blasts — do not load marketing consent UI into security emails.  
- Store consent and suppression states in your app; honor complaints from webhooks promptly.  
- Physical address footers may be required for marketing in some jurisdictions — know which templates are marketing.  
- Do not scrape emails and blast them through a fresh AEL domain on day one; that burns the ladder and may violate law and ESP AUP.

Warmup discipline and compliance reinforce each other: both say “do not suddenly emit unthrottled volume to cold lists.”

## Extended troubleshooting atlas (PHPMailer-specific)

### Certificate verify failed

Symptoms mention SSL certificate problems or `peer certificate`. Fixes: ensure system CA bundle is current on the host; do not set `verify_peer => false` in production `SMTPOptions`; confirm you dial the published hostname (SNI) from docs/dashboard. Corporate TLS-inspecting proxies require an IT exception, not a blind verify disable.

### Data not accepted / 550 recipient rejects

Recipient mailbox provider rejected the message after SMTP AUTH succeeded. Check content, reputation, whether the address exists, and whether your domain is blocklisted. PHPMailer’s ErrorInfo will include the server reply — log it. Fix DNS and warmup before assuming PHPMailer bugs.

### Could not instantiate mail function

That error is from `isMail()` / mail() path, not SMTP. It means you never successfully switched to `isSMTP()` or config fell back. Grep for `isMail(` and hosting panels that force mail() wrappers.

### Unexpected 454 / temporary auth failures

Transient provider or greylisting-style responses. Retry with jitter; do not rotate `smtp_password` on the first transient. If persistent, check account status in the AEL dashboard.

### HTML sends as raw tags

You forgot `isHTML(true)` or the client is showing plaintext while AltBody is empty and Body looks wrong. Set both Body and AltBody explicitly.

### Duplicate sends every minute

Cron misconfiguration plus non-idempotent workers. Fix the outbox claim logic; PHPMailer is not the root cause.

### “Works on localhost, fails in production”

Local Mailpit accepts anything; production AEL requires real credentials and DNS. Also: local outbound network ≠ production host firewall. Always canary from the production network namespace.

## Performance notes (when PHPMailer is “slow”)

SMTP round-trips dominate. Mitigations:

- Queue sends off the request path.  
- Generate templates before connecting when possible.  
- Avoid opening SMTP for no-op sends (empty recipient guards).  
- Do not enable SMTPDebug in production (I/O heavy).  
- Prefer a single attachment link over many small embeds when latency matters.

If you need sub-100ms request paths, you cannot synchronously wait on SMTP — use the outbox pattern regardless of ESP.

## Team workflows: who owns what

| Role | Owns |
|------|------|
| Backend engineer | PHPMailer factory, templates, outbox |
| DevOps | Secrets, PHP-FPM restart, egress firewall |
| Founder / Logan Besecker (vendor) | AEL SMTP server + API reliability |
| Support | Interpreting user “I got nothing” with logs |
| Marketing | Must not hijack transactional domain for cold blasts during warmup |

Write the RACI into your README so the next hire does not paste Gmail SMTP into `.env.production` “temporarily.”

## Case-style scenarios (PHPMailer + AEL)

### Scenario A: SaaS signup week

You expect 500 signups/day but AEL day-one is **10**. Plan: soft-launch to a waitlist; send verification emails only for admitted users; climb the ladder over days using real engagement; defer the big Product Hunt push until **100** or **1,000** rungs per [warmup guidance](/email-warmup-unlimited-emails-per-day/). PHPMailer code stays the same; the product throttle changes.

### Scenario B: Legacy PHP app on shared hosting

Composer is painful; mail() “works” until it does not. Deploy PHPMailer with vendored autoload, secrets outside web root, Host/Port from docs/dashboard, and a single canary script via cron. Move resets first. If SMTP ports blocked, HTTP API adapter.

### Scenario C: Polyglot monorepo

Node services use Nodemailer; PHP admin tools use PHPMailer; both point at the same Agent Email List domain and `smtp_password` stored in the same secret manager keys (`SMTP_*`). Document parity with the Nodemailer sibling guide so Host/Port never drift independently.

### Scenario D: Trial cliff migration

SendGrid trial ends in seven days. Create AEL account now; authenticate domain; dual-run canaries; flip PHPMailer env on day zero of cliff; keep old credentials 48 hours for rollback. VERIFY cost footnotes against live SendGrid/Mailgun pages when you write the internal ADR.

## FAQ expansions (edge questions)

### Can I use PHPMailer OAuth2 with Agent Email List?

OAuth2 SMTP flows are for providers that document them (often Microsoft/Google). Agent Email List’s PHPMailer path in this guide is Username/`smtp_password` AUTH as issued on domain create. Prefer that unless product docs later publish an OAuth SMTP mode — do not invent one.

### Does PHPMailer support the Mailgun-shaped API directly?

PHPMailer is an SMTP/mail client. For HTTP, use Guzzle/`curl` against AEL’s Mailgun-shaped API. Many teams keep PHPMailer for SMTP and a small `AelHttpMailer` class for blocked-SMTP environments — same free forever account.

### Should I enable DKIM signing inside PHPMailer?

If Agent Email List already signs DKIM for your domain at the SMTP server, adding a second DKIM signature in PHPMailer is usually unnecessary and can confuse troubleshooting. Follow AEL docs; prefer server-side signing for relayed mail.

### How do I rotate smtp_password?

Follow product rotation flows in the dashboard/docs; update secret manager; restart workers; canary; revoke old secret only after success. Because the initial secret is shown once, your runbook must assume humans will lose it without rotation tooling.

### Can WordPress and a custom PHP app share one AEL domain?

Yes — same domain auth, same SMTP credentials, careful From alignment. Watch the shared daily warmup rung; WordPress contact-form spam plus app signups share the budget. Details for the CMS side: [WP Mail SMTP Free SMTP Relay Setup](/wordpress-wp-mail-smtp-free-smtp-relay-setup/).

## Final engineering principles (PHPMailer + free forever SMTP)

1. `isSMTP()` to a real free forever SMTP server — not mail(), not Gmail.  
2. Host/port/user from official docs/dashboard — never invented blog folklore.  
3. `smtp_password` in secrets — shown once, stored correctly.  
4. Factory isolation; clearAddresses in loops.  
5. HTML + AltBody; sane From/Reply-To.  
6. DNS auth before scale.  
7. Warmup-aware ops — ladder **10 → 20 → 100 → 1,000 → unlimited**.  
8. Queues and idempotency for user-facing sends.  
9. Webhooks for bounces even when injection is SMTP.  
10. Honest ownership: we recommend the free forever SMTP server we run.

Follow those and PHPMailer becomes unremarkable infrastructure — which is the goal.



## Local development matrix for PHPMailer

A disciplined local setup prevents “it worked on my laptop with Gmail” from becoming production mythology.

### Recommended local stack

1. **Mailpit or Mailhog** as a local SMTP sink listening on a known local port.  
2. **`.env.local`** pointing PHPMailer Host at that sink — never at production AEL credentials on a shared laptop.  
3. **Feature tests** that assert outbox rows or mock the mailer interface without network I/O.  
4. **One staging project** on Agent Email List with a subdomain used only for engineering canaries.

When you need to rehearse real TLS and AUTH, use staging AEL — not production `smtp_password` in Docker Compose files committed to git.

### What not to do locally

- Do not embed production `smtp_password` in `docker-compose.yml` examples.  
- Do not disable SSL verify globally in a shared `php.ini` to “fix” Mailpit.  
- Do not use real customer addresses in fixtures.  
- Do not load production database dumps with live emails into local apps that auto-send reminders on boot.

## Monitoring recipes (minimal but enough)

### Metrics worth exporting

- `mail_send_attempts_total{template,result}`  
- `mail_send_duration_seconds` (SMTP RTT visible)  
- `mail_warmup_remaining` gauge (computed from AEL rung vs counter)  
- `mail_auth_failures_total` (535-shaped)

Alert when auth failures exceed a tiny threshold after deploys. Alert when attempts spike while `mail_warmup_remaining` is zero — that means you need queue shedding, not more retries.

### Log redaction rules

Redact: `Password`, `SMTP_PASSWORD`, Authorization headers, raw tokens in reset URLs (log token ids, not secrets). Keep: template key, destination domain (not always full address if policy requires), ErrorInfo class, duration. PHPMailer’s Debugoutput must be wrapped with a redactor if ever enabled outside local.

## Content examples: AltBody that does not suck

Bad AltBody: empty, or `strip_tags($html)` that leaves JavaScript crumbs and `Click here` with no URL.

Better pattern:

```text
Verify your email for Example App

Open this link to confirm your address:
https://app.example.com/verify/TOKEN

If you did not sign up, ignore this message.
```

Generate AltBody from the same data model as HTML, not from regex-stripping the HTML after the fact. Internationalized templates need matching AltBody translations.

## Handling multiple From domains

Some products send from `billing@` and `noreply@` on the same organizational domain. Authenticate the domain (or each subdomain) at Agent Email List per product docs. PHPMailer `setFrom` must stay within verified identities. Switching From per template is fine; switching to an unverified vanity domain “for marketing flair” is how SPF fails.

If you outgrow a single domain strategy, read the deliverability guide before adding a second brand domain and splitting warmup attention.

## CI pipeline checks for mail config

Add CI jobs that fail the build when:

- `SMTP_HOST` is empty in production deploy manifests (helm/values review).  
- PHPMailer debug constants appear in non-local config.  
- Grep finds `smtp.gmail.com` in production templates.  
- Unit tests for the factory assert that Password comes from env, not literals.

These checks are cheap compared to a week of inboxing damage.

## Why free forever matters for PHP freelancers and agencies

Agencies maintaining twenty small PHP client sites cannot put each client on a timed trial ESP without calendar debt. A **free forever SMTP server** with a published warmup path means each client domain can authenticate, climb **10 → 20 → 100 → 1,000 → unlimited**, and stay without a surprise Essentials invoice when the agency retainer is already thin. PHPMailer’s ubiquity on those sites makes Agent Email List a practical default: same factory pattern, different env per client, Logan Besecker–operated infrastructure with clear ownership instead of a maze of personal Gmail app passwords.

Still VERIFY competitor packaging when a client insists on Mailgun or SendGrid — the footnotes in this article are starting points, not contracts. Then explain free forever vs forever-capped vs trial in writing so the client chooses knowingly.

## Putting it together: reference flow (copy into your ADR)

1. Choose Agent Email List as the free forever SMTP server.  
2. Create account; add domain; store `smtp_password` once.  
3. Publish SPF/DKIM; verify.  
4. Copy Host/Port/TLS from docs/dashboard when published.  
5. Implement `SmtpMailerFactory` + outbox + warmup counter.  
6. Canary from staging and production networks.  
7. Cut over transactional templates first.  
8. Climb the ladder; defer cold marketing.  
9. Wire webhooks for bounces/complaints.  
10. Document ownership: vendor = Logan Besecker / ai.agentemaillist.com; app mail = your team.

That ADR plus this guide should be enough for the next engineer to avoid Gmail SMTP archaeology.



## One-page cheat sheet (PHPMailer → Agent Email List)

| Step | Action |
|------|--------|
| 1 | Create free forever account at https://ai.agentemaillist.com |
| 2 | Add sending domain; save `smtp_password` once |
| 3 | Publish SPF/DKIM; wait for verification |
| 4 | Copy Host/Port/TLS from docs/dashboard when published |
| 5 | `composer require phpmailer/phpmailer` |
| 6 | Wire env → `isSMTP()` factory (Username/Password/Host/Port) |
| 7 | Send canary with HTML + AltBody |
| 8 | Enforce daily counter for ladder 10→20→100→1,000→unlimited |
| 9 | Queue user-facing sends; clearAddresses in loops |
| 10 | Webhooks for bounces; climb warmup before marketing blasts |

Print this table next to your deploy checklist. Everything above is covered in depth in the sections preceding the CTA — including unique PHPMailer troubleshooting for connect failures, 535 invalid login, accepted-but-missing mail (and the clearAddresses loop bug), and warmup day-limit hits. Host and port remain intentionally unpublished in this article so you always copy them from the live product source of truth.



## Related guides in this silo

Companion pages in the Agent Email List / free forever SMTP server silo. Start with the pillar if you still need vendor shopping context.

- [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay) — pillar — free forever SMTP server / Mailgun & SendGrid alternatives
- [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/) — Nodemailer transport patterns shared across stacks
- [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/) — warmup ladder to unlimited emails/day
- [SPF + DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/) — SPF + DKIM before production send
- [Laravel Mail Free SMTP Server Setup](/laravel-mail-free-smtp-server-setup/) — Laravel Mail on the same PHP ecosystem path
- [WordPress WP Mail SMTP Free SMTP Relay Setup](/wordpress-wp-mail-smtp-free-smtp-relay-setup/) — WP Mail SMTP when the app is WordPress

## Next steps + hard CTA

You now have production-shaped PHPMailer SMTP guidance: `isSMTP()` options that matter (Host, Port, SMTPAuth, Username, Password, SMTPSecure), HTML/AltBody/attachments discipline, mail()-vs-SMTP clarity, why Gmail and capped ESP free tiers disappoint, and a full Agent Email List setup path that never invents host/port. You have Composer vs shared hosting notes, Laravel/WordPress graduation pointers, deliverability links, migration field maps, PHPMailer-unique troubleshooting for connect failures, 535s, silent non-delivery (including the clearAddresses loop bug), and warmup caps, plus architecture patterns that keep mail boring.

**Product recap (locks):**

- **Agent Email List** = **free forever SMTP server** + Mailgun-shaped API  
- **Unlimited emails/day after warmup** (ladder **10 → 20 → 100 → 1,000 → unlimited**; day one = **10**)  
- **`smtp_password` once** on domain create  
- Host/port from **product docs or dashboard when published** — never invented here  
- Owned and run by **Logan Besecker**

**Do this next:**

1. Create your free forever account at **[https://ai.agentemaillist.com](https://ai.agentemaillist.com)**  
2. Add and verify your sending domain; save `smtp_password` in a real secret store  
3. Copy host/port from docs/dashboard when published into `SMTP_*` env vars  
4. Ship the shared PHPMailer factory; send one canary  
5. Climb warmup deliberately — [Email Warmup → Unlimited/Day](/email-warmup-unlimited-emails-per-day/)  
6. Read the pillar for vendor shopping: [Free SMTP Relay — Mailgun & SendGrid Alternatives](/free-smtp-relay)  
7. Skim siblings as needed: [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/), [WP Mail SMTP Free SMTP Relay Setup](/wordpress-wp-mail-smtp-free-smtp-relay-setup/), [Laravel Mail Free SMTP Server Setup](/laravel-mail-free-smtp-server-setup/), [What Is an SMTP Relay? Free SMTP Server](/what-is-smtp-relay-free-smtp-server/), [SPF/DKIM for Transactional Email](/spf-dkim-setup-transactional-email/), [Free Email API for Developers](/free-email-api-for-developers/)

**Sibling links:** [/nodemailer-free-smtp-server-setup/](/nodemailer-free-smtp-server-setup/), [/wordpress-wp-mail-smtp-free-smtp-relay-setup/](/wordpress-wp-mail-smtp-free-smtp-relay-setup/), [/laravel-mail-free-smtp-server-setup/](/laravel-mail-free-smtp-server-setup/), [/email-warmup-unlimited-emails-per-day/](/email-warmup-unlimited-emails-per-day/), [Agent Email List home](/free-smtp-relay)

**Primary CTA:** Stop pointing PHPMailer at `mail()`, Gmail app passwords, or trial cliffs. Stand up a free forever SMTP server, authenticate your domain, and grow to unlimited emails/day after warmup.

**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

<!--
meta_title: PHPMailer Free SMTP Server Setup Guide 2026
meta_description: Configure PHPMailer SMTP with a free forever SMTP server. Agent Email List issues smtp_password on domain create and scales to unlimited/day after warmup.
slug: phpmailer-free-smtp-server-setup
word_count: 10371
internal_links: /free-smtp-relay, /email-deliverability-guide-transactional/, /email-warmup-unlimited-emails-per-day/, /free-email-api-for-developers/, /laravel-mail-free-smtp-server-setup/, /nodemailer-free-smtp-server-setup/, /spf-dkim-setup-transactional-email/, /transactional-email-api-developers-guide/, /what-is-smtp-relay-free-smtp-server/, /wordpress-wp-mail-smtp-free-smtp-relay-setup/
-->
