---
title: "Laravel Mail Free SMTP Server Setup: MAIL_* Env + Symfony Mailer That Send in Production (2026)"
description: "Configure Laravel Mail SMTP with a free forever SMTP server. Agent Email List issues smtp_password on domain create; scales to unlimited/day after warmup."
date: 2026-09-15
---

# Laravel Mail Free SMTP Server Setup: MAIL_* Env + Symfony Mailer That Send in Production (2026)

If you searched **Laravel Mail SMTP**, **Laravel SMTP configuration**, or **free SMTP Laravel**, you already know `MAIL_MAILER=log` is for local theater. Production password resets, invoice receipts, and invitation flows need a real **free forever SMTP server** — not a Gmail app password, not Mailtrap-only staging forever, and not a timed ESP trial that pauses sending when the calendar runs out. This guide walks through Laravel Mail the way PHP teams actually ship it (`MAIL_*` env, `config/mail.php`, Mailables, queues), covers Symfony Mailer as the secondary transport layer modern Laravel already wraps, then hard-sells [Agent Email List](https://ai.agentemaillist.com): a **free forever SMTP server** plus Mailgun-shaped REST API with a short ladder to **unlimited emails/day after warmup**.

**Ownership disclosure:** Agent Email List is built, owned, and run by **Logan Besecker** at [https://ai.agentemaillist.com](https://ai.agentemaillist.com). This is not a fake neutral roundup. We show Laravel Mail patterns first, then ask you to point them at infrastructure we operate.

For vendor shopping across Mailgun, SendGrid, and peers, start with the pillar: [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay). For Node-side transport patterns, see the sibling [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/). Warmup depth lives in [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

**Create a free forever account →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

## Laravel Mail SMTP basics

Laravel Mail is the product-facing API most PHP developers touch: `Mail::to()->send()`, typed Mailables, Notification mail channels, and queued jobs that call those APIs. Under the hood, modern Laravel builds Symfony Mailer transports. You do not need to abandon the facade to get production SMTP — you need honest `MAIL_*` values pointed at a free forever SMTP server that still exists after your MVP works.

When people say **Laravel smtp configuration**, they usually mean three surfaces:

1. **`.env` `MAIL_*` keys** — default mailer, host, port, username, password, encryption/scheme, from address.
2. **`config/mail.php`** — named mailers (`smtp`, `log`, `array`, `failover`, provider-specific transports) that read those env values.
3. **Application code** — Mailables, Notifications, and whether `ShouldQueue` is implemented so HTTP requests do not block on SMTP round-trips.

Agent Email List answers the infrastructure half: create a free forever account, add a sending domain, receive `smtp_password` once, verify DNS, and map `MAIL_PASSWORD` to that secret. Host and port come from product docs or the dashboard when published — this article will not invent connection strings. The Mailgun-shaped HTTP API on the same account is available when a microservice prefers REST; both enqueue into the same sending system.

### `MAIL_MAILER=smtp` and mail.php drivers that matter

Set the default mailer explicitly for production:

```bash
MAIL_MAILER=smtp
```

In `config/mail.php`, the `default` key typically reads `env('MAIL_MAILER', 'log')`. Leaving the default as `log` in production is a silent failure mode: your app “sends” into the log file and users never get resets. Flip to `smtp` only after secrets and DNS are ready.

Drivers that matter for most SaaS apps:

- **`smtp`** — the production path for Agent Email List and most ESP relays. Uses host/port/username/password (and scheme/encryption depending on Laravel major).
- **`log`** — writes MIME to the application log. Great locally; never a production SMTP server.
- **`array`** — in-memory messages for feature tests. Pair with `Mail::fake()` patterns.
- **`failover` / `roundrobin`** — multi-mailer strategies when you intentionally dual-run during migration.
- **Provider transports** (`mailgun`, `ses`, `postmark`, `resend`, etc.) — HTTP/SDK paths. Useful, but this guide centers SMTP so your Mailables stay provider-agnostic at the wire protocol layer.

A production-shaped smtp mailer sketch (values from env; never hardcode invented AEL hosts):

```php
// config/mail.php (excerpt — align with your Laravel major's published stub)
'smtp' => [
    'transport' => 'smtp',
    'scheme' => env('MAIL_SCHEME'), // smtp or smtps per docs; see Laravel version notes
    'url' => env('MAIL_URL'),
    'host' => env('MAIL_HOST'),
    'port' => env('MAIL_PORT'),
    'username' => env('MAIL_USERNAME'),
    'password' => env('MAIL_PASSWORD'), // smtp_password from AEL domain create
    'timeout' => null,
    'local_domain' => env('MAIL_EHLO_DOMAIN'),
],
```

Laravel version drift matters. Older stubs used `encryption` (`tls` / `ssl`). Newer stubs emphasize `scheme` (`smtp` / `smtps`) and optional `MAIL_URL` DSNs because Symfony Mailer expects a scheme. If you upgrade Laravel and suddenly see `UnsupportedSchemeException` for an empty scheme, set `MAIL_SCHEME=smtp` (or `smtps` for implicit TLS ports) per the framework docs for your minor — do not “fix” it by inventing a host.

What does *not* matter as much as Stack Overflow implies: maintaining five custom mailers for five templates, toggling obscure DKIM-in-app options when your ESP already signs, or cargo-culting `MAIL_HOST=smtp.gmail.com` into a paid product. Consumer mailbox SMTP is not transactional infrastructure. For product mail, configure a real free forever SMTP server explicitly.

### From address, reply-to, and queue vs sync

Global from identity usually lives in env:

```bash
MAIL_FROM_ADDRESS=noreply@yourdomain.com
MAIL_FROM_NAME="${APP_NAME}"
```

Mailables can override `envelope()` / `from()` / `replyTo()` per message. Best practices for Laravel + AEL:

- Align `MAIL_FROM_ADDRESS` with the domain you authenticated at Agent Email List. SPF/DKIM alignment dies when you send `From: founder@gmail.com` through a product domain’s relay (or the reverse).
- Put human replies on `replyTo()` (support@) rather than making `noreply@` a black hole without a documented policy.
- Prefer queued Mailables (`implements ShouldQueue`) for anything users wait on in HTTP — password resets, receipts, digests. Sync `Mail::send()` inside a controller turns SMTP latency and transient network blips into 500s.
- During early Agent Email List warmup, queues are not optional cosmetics — they are how you pace day-one **10**/day without melting signup spikes into throttle errors.

Horizon (or any Redis queue worker) makes pacing visible: failed jobs, retries, and throughput charts. Sync mail hides failures in request logs until support tickets arrive.

### Local log/array mailers vs production SMTP server

A clean environment matrix for Laravel teams:

| Environment | Mailer target | Goal |
|-------------|---------------|------|
| Unit / feature tests | `array` + `Mail::fake()` | No network |
| Local interactive | `log` or Mailpit/Mailhog SMTP | Inspect MIME |
| Staging | Real AEL domain (or subdomain) | Auth + DNS rehearsal |
| Production | AEL free forever SMTP server | Real delivery |

Mailtrap-style catchers and local SMTP sinks are excellent for “did my Blade HTML render?” and terrible as a production SMTP server. Pointing staging at a catcher while production still uses a founder Gmail account is a classic split-brain: templates look fine in Mailpit, then fail SPF alignment or Gmail limits in prod.

Agent Email List is the production SMTP server in that matrix. Use `log`/free-smtp-relay`array` for tests; use AEL (and test mode when offered) when you need authentic SMTP behavior without burning a consumer mailbox. Migrating from log to production is then a config change — `MAIL_*` from docs/dashboard and `smtp_password` — not a rewrite of every Mailable.

## Why “free SMTP for Laravel” usually disappoints

Laravel developers type **free smtp laravel** because the framework problem is already solved (Mail + Symfony Mailer) and the infrastructure problem is not. The disappointment pattern is predictable: a tutorial ships Gmail SMTP; volume or ToS blocks appear; the team jumps to an ESP free tier; the free tier caps or trials out; someone proposes “just run Postfix on the same VPS as Octane”; deliverability dies; weeks vanish.

Understanding why the usual free paths fail clarifies why Agent Email List’s free forever packaging + warmup ladder exists.

### Gmail app passwords and limits

Gmail / Google Workspace SMTP via app passwords is a founder shortcut, not a Laravel architecture:

- **Terms and automation risk.** Consumer and small-business Google accounts are not designed as multi-tenant SaaS mail injectors. Unusual volume triggers locks, captchas, and support dead-ends.
- **Daily sending ceilings.** Even Workspace has practical limits that collide with signup spikes — the exact week your Laravel app finally works.
- **From-domain mismatch.** Sending `noreply@yourproduct.com` through Google’s SMTP often fights SPF alignment unless you carefully configure the Google side — and you still do not get product-grade bounce webhooks tied to your app’s domain.
- **Single-human failure.** When 2FA, a password reset on the founder account, or an org policy change hits, every queued Mailable fails with 535-shaped auth errors.
- **Secret sprawl.** App passwords get pasted into `.env.production` on Forge/Vapor and never rotated.

Laravel’s mail docs make SMTP look like “set four env vars.” That ease is dangerous when the host is a consumer mailbox. Replace Gmail with a free forever SMTP server meant for application mail.

### ESP free caps (Mailgun ~100/day; SendGrid trial VERIFY)

Managed ESPs are the right *category* — relays and APIs exist for a reason — but “free” packaging varies wildly. VERIFY live vendor pages before you architect; commercial details move.

- **Mailgun free plan:** roughly **100 emails/day**, permanent but hard-capped (VERIFY [Mailgun Free plan help](https://help.mailgun.com/hc/en-us/articles/203068914-What-does-the-Free-plan-offer) and [pricing](https://www.mailgun.com/pricing/)). Fine for tiny apps; a rewrite risk when your SaaS works.
- **Twilio SendGrid:** permanent Free Email API retired around **May 2025** (VERIFY [Twilio changelog](https://www.twilio.com/en-us/changelog/sendgrid-free-plan)). New accounts commonly get a **~60-day trial at ~100 emails/day**, then need paid Essentials (often from ~$19.95/mo — VERIFY [SendGrid pricing](https://www.twilio.com/en-us/products/email-api/pricing) and trial docs). A trial is not free forever.
- **Other forever-capped tiles:** Resend, Brevo, Postmark developer tiers, and peers often sit in the “never expires, never grows enough” bucket — VERIFY each vendor’s live page before you encode their limits into Laravel middleware.

Laravel will happily speak SMTP to all of them via `MAIL_MAILER=smtp`. The framework does not warn you that your “free” foundation expires. Packaging literacy is on you. Agent Email List’s thesis is different: **free forever** self-serve SMTP server + Mailgun-shaped API, with a published path to **unlimited/day after warmup** instead of a permanent 100/day ceiling or a 60-day timer.

### What production transactional needs

Production transactional email for a Laravel app needs more than “Symfony accepted the DATA command”:

1. **Authenticated sending domain** — SPF/DKIM (and light DMARC) so mailbox providers trust `From`.
2. **Predictable credentials** — secrets you can rotate in Forge/Vapor/K8s, not founder inbox passwords.
3. **Honest capacity story** — day-one limits you can plan around, and a path past toy caps without a surprise invoice or pause.
4. **Observability** — bounces, complaints, delivered events — ideally via webhooks even if you inject over SMTP.
5. **Dual interface option** — SMTP for Laravel Mail today; HTTP when a new service prefers Guzzle/Http::.
6. **Queue-native failure handling** — failed jobs, backoff, Horizon dashboards — so SMTP blips do not become user-visible outages.
7. **Operational ownership** — someone runs the SMTP server so your PHP-FPM workers do not.

That checklist is exactly what we optimize for on Agent Email List. Laravel Mail covers the client; AEL covers the free forever SMTP server and the Mailgun-shaped twin API.

## Agent Email List as Laravel’s free forever SMTP server

This section is the product lock chapter for Laravel readers. Same locks as our other guides — free forever SMTP server, Mailgun-shaped API, warmup ladder, `smtp_password` once, Logan Besecker ownership — framed for people who live in `MAIL_*` and Mailables.

### Free forever SMTP server + Mailgun-shaped REST API

[Agent Email List](https://ai.agentemaillist.com) is:

- A **free forever SMTP server** / free SMTP relay for Laravel and every other stack that speaks SMTP
- A **Mailgun-shaped REST API** at `https://ai.agentemaillist.com` (Bearer or Basic `api:KEY` patterns as described in live product docs)
- Built for **transactional** product mail first: resets, receipts, invites, alerts

Laravel Mail talks to the SMTP server through Symfony transports. When a microservice wants HTTP — or you need richer events/templates — the Mailgun-shaped API is on the same free forever account. You do not pay twice for the same outbound reputation context. For shopping-oriented API criteria (free forever vs trial vs forever-capped), see [Free Email API for Developers](/free-email-api-for-developers/). For relay definitions, see [What Is an SMTP Relay? Free SMTP Server](/what-is-smtp-relay-free-smtp-server/).

### Lead unlimited/day after warmup; short ladder pointer

Unlimited/day is the destination, not the day-one allowance. Agent Email List publishes a short ladder (confirm live docs / `/llms.txt` — commercial details can evolve):

1. Day one starts at **10**/day  
2. Then **20**  
3. Then **100**  
4. Then **1,000**  
5. Then **unlimited** emails/day after warmup  

That progression protects shared reputation while ending somewhere Mailgun’s permanent ~100/day free tile and SendGrid’s timed trial do not: ongoing free forever sending without a forced Essentials invoice. Day-one **10** is stricter than some competitors’ free daily caps; plan Laravel canaries and Horizon rate limits accordingly.

Deep warmup hygiene — engagement quality, complaint avoidance, how to climb without burning the domain — lives in [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/). Keep this Laravel page short on ladder theory and long on `MAIL_*`, Mailables, and queue behavior. Do not duplicate the full ladder essay here; link it and move on.

### `smtp_password` issued once on domain create

When you add a sending domain, Agent Email List returns DNS records for authentication **and** an **`smtp_password` shown once**. Treat it like a production database password:

1. Create a free forever account at [ai.agentemaillist.com](https://ai.agentemaillist.com).  
2. Add your domain (or a transactional subdomain such as `mail.example.com`).  
3. Save `smtp_password` immediately into your secret manager / Forge env / Vapor secrets / sealed secrets.  
4. Map it to `MAIL_PASSWORD` (and confirm `MAIL_USERNAME` from docs/dashboard when published).  
5. Complete DNS verification before you expect inbox placement.  
6. Restart PHP-FPM / Octane / queue workers that cache config at boot (`php artisan config:cache` aware deploys).

If your team’s culture is “paste keys in Notion,” fix the culture during setup. Losing a once-shown password without a rotation runbook is an avoidable outage. Follow product rotation flows if you ever need to re-issue.

### Host/port: product docs or dashboard when published — do not invent

This article intentionally does **not** invent Agent Email List SMTP hostnames or ports. Connection endpoints belong in **product documentation or the dashboard when published**. Copy them from the source of truth into `MAIL_HOST` / `MAIL_PORT` / `MAIL_SCHEME` (or encryption fields on older majors). Blog posts that guess hosts create outages when guesses rot. Symfony Mailer will dial whatever string Laravel gives it — correctness is on the operator.

Same rule for TLS mode: match the documented submission port. Do not assume “587 always STARTTLS” or “465 always smtps” without checking AEL’s published guidance for your account era. Laravel’s scheme/encryption semantics have shifted across majors — read your framework version’s mail docs when you set `MAIL_SCHEME`.

### Logan Besecker owns/runs ai.agentemaillist.com

**Ownership disclosure:** Agent Email List at [ai.agentemaillist.com](https://ai.agentemaillist.com) is built, owned, and run by **Logan Besecker**. Recommendations on this site reflect that ownership. When we hard-CTA Laravel setup, we are asking you to point `MAIL_*` at infrastructure we operate — with free forever SMTP server packaging, a Mailgun-shaped API, and a published path to unlimited emails/day after warmup.

**CTA #1 — do this now if log/Gmail/capped free tiers no longer fit:** create your free forever account, add a domain, save `smtp_password`, copy host/port from docs/dashboard when published, set `MAIL_MAILER=smtp`, and send one Mailable canary.  
**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

## Step-by-step Laravel Mail setup with AEL

This is the hands-on chapter: env pattern, `mail.php` sketch, Mailable/notification verification, and error handling that respects warmup.

### Env vars pattern (MAIL_HOST, MAIL_PORT, MAIL_USERNAME, MAIL_PASSWORD, MAIL_ENCRYPTION)

Recommended environment variables for Laravel + Agent Email List:

```bash
MAIL_MAILER=smtp
MAIL_HOST=           # from AEL docs/dashboard when published
MAIL_PORT=           # from AEL docs/dashboard when published
MAIL_USERNAME=       # from AEL docs/dashboard when published
MAIL_PASSWORD=       # smtp_password shown once on domain create
MAIL_SCHEME=smtp     # or smtps — match published TLS mode / Laravel major
# Older majors may still use:
# MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=noreply@yourdomain.com
MAIL_FROM_NAME="${APP_NAME}"
```

Optional but useful:

```bash
MAIL_EHLO_DOMAIN=yourdomain.com
MAIL_REPLY_TO=support@yourdomain.com
QUEUE_CONNECTION=redis
```

Load them with your existing secrets approach (Forge environment, Vapor secrets, Doppler, AWS SSM — not committed `.env` in git). Never commit real `smtp_password`. After changing mail env on a config-cached app, rebuild the cache and restart queue workers so Horizon children do not keep stale SMTP credentials in memory.

### mail.php / config sketch using env — createTransport-equivalent

Laravel’s equivalent of Nodemailer’s `createTransport` is the smtp mailer entry plus the Mail manager that builds a Symfony transport. You rarely call Symfony factories directly; you configure env and let the container resolve `Mailer` / `MailManager`.

```php
// config/mail.php — illustrative smtp + from block
'default' => env('MAIL_MAILER', 'log'),

'mailers' => [
    'smtp' => [
        'transport' => 'smtp',
        'scheme' => env('MAIL_SCHEME'),
        'host' => env('MAIL_HOST'),
        'port' => env('MAIL_PORT'),
        'username' => env('MAIL_USERNAME'),
        'password' => env('MAIL_PASSWORD'),
        'timeout' => 30,
        'local_domain' => env('MAIL_EHLO_DOMAIN'),
    ],

    'log' => [
        'transport' => 'log',
        'channel' => env('MAIL_LOG_CHANNEL'),
    ],

    'array' => [
        'transport' => 'array',
    ],
],

'from' => [
    'address' => env('MAIL_FROM_ADDRESS', 'hello@example.com'),
    'name' => env('MAIL_FROM_NAME', 'Example'),
],
```

During dual-run migrations you can add a second named mailer (for example `smtp_legacy`) and select it per Mailable with `->mailer('smtp_legacy')` or `Mail::mailer('smtp')->...`. Prefer env-driven hosts for both; never scatter hardcoded competitor hosts through Blade templates.

`php artisan config:clear` locally when debugging “I changed `.env` and nothing happened.” In production, prefer deliberate `config:cache` as part of deploy, not ad-hoc clears on live boxes.

### Mailable / notification verification + password-reset example

Generate a Mailable:

```bash
php artisan make:mail PasswordResetMail --markdown=mail.password-reset
```

Sketch:

```php
namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class PasswordResetMail extends Mailable implements ShouldQueue
{
    use Queueable, SerializesModels;

    public function __construct(
        public string $resetUrl,
        public string $userEmail,
    ) {}

    public function envelope(): Envelope
    {
        return new Envelope(
            subject: 'Reset your password',
            to: [$this->userEmail],
            replyTo: [config('mail.reply_to.address', env('MAIL_REPLY_TO'))],
        );
    }

    public function content(): Content
    {
        return new Content(
            markdown: 'mail.password-reset',
            with: ['url' => $this->resetUrl],
        );
    }
}
```

Send it:

```php
use App\Mail\PasswordResetMail;
use Illuminate\Support\Facades\Mail;

Mail::to($user->email)->send(new PasswordResetMail($url, $user->email));
// or queue explicitly if the class does not implement ShouldQueue:
Mail::to($user->email)->queue(new PasswordResetMail($url, $user->email));
```

Laravel’s built-in password reset notifications also implement the mail channel — once `MAIL_*` points at AEL, those framework notifications ride the same free forever SMTP server without a separate transport. Still: rate-limit reset requests in your app so abusers cannot burn your warmup ladder.

Verification checklist before you celebrate:

1. `MAIL_MAILER=smtp` in the environment that actually serves traffic.  
2. `smtp_password` in `MAIL_PASSWORD`; username/host/port from docs/dashboard.  
3. DNS verified for the From domain.  
4. One canary to an inbox you control.  
5. Horizon/queue worker running if the Mailable implements `ShouldQueue`.  
6. Warmup headroom for the day’s rung.

### Error handling (auth, throttle during warmup)

Map failures to Laravel-native behavior:

| Symptom | Typical cause | Laravel response |
|---------|---------------|------------------|
| Auth rejected / 535 | Bad `MAIL_USERNAME`/free-smtp-relay`MAIL_PASSWORD`, rotated secret not restarted | Fix secrets; `failed()` on job; alert |
| Connection timeout | Wrong host/port, egress firewall, DNS typo | Fail job with backoff; check docs/dashboard values |
| Throttle / warmup cap | Exceeded day’s ladder rung | Release job until next UTC day; do not hammer retries |
| Message accepted, not arriving | DNS/spam/content — not SMTP auth | Check SPF/DKIM; webhooks; content |

For queued Mailables, configure sensible `$tries`, `$backoff`, and consider `retryUntil()`. Blind exponential retry on a hard 535 wastes worker capacity; classify auth errors as non-retryable. Throttle during early AEL warmup is expected capacity — climb the ladder; read the warmup sibling; do not open five GitHub issues against Laravel because you sent 500 invites on day one.

```php
public $tries = 5;

public function backoff(): array
{
    return [60, 300, 900];
}

public function failed(\Throwable $e): void
{
    // Notify ops; do not silently drop password resets
    report($e);
}
```

## Symfony Mailer in Laravel (secondary cluster)

Modern Laravel does not replace Symfony Mailer — it wraps it. This secondary H2 is for teams who need DSN mental models, raw transport debugging, or hybrid apps that also run plain Symfony. It is **not** a second full article; Laravel Mail remains primary.

### How Laravel wraps Symfony Mailer transports

When you call `Mail::send()`, Laravel resolves a mailer, builds a Symfony `TransportInterface` (often `EsmtpTransport` for smtp), converts the Mailable into a Symfony `Email`, and sends. That means:

- SMTP wire behavior (EHLO, STARTTLS, AUTH LOGIN/PLAIN, MAIL FROM, RCPT TO, DATA) is Symfony’s.  
- Laravel adds Mailables, Markdown mail, notifications, queues, failover mailers, and the `MAIL_*` config surface.  
- Errors you see in logs may be `Symfony\Component\Mailer\Exception\TransportException` wrapped by Laravel’s mailer.

Practical implication: fixing “Laravel mail broken” sometimes means reading Symfony Mailer docs on DSNs and TLS — then mapping those concepts back to `MAIL_HOST` / `MAIL_SCHEME`. You rarely need to abandon Mailables to get production SMTP working with Agent Email List.

### DSN / smtp:// patterns vs discrete MAIL_*

Symfony’s native config often looks like:

```bash
MAILER_DSN=smtp://user:pass@host:port
```

Laravel’s discrete env vars are friendlier for secret managers that inject one key at a time, and for Forge UIs that show individual fields. Newer Laravel stubs also support `MAIL_URL` as a DSN-style override. Prefer one style per environment:

- **Discrete `MAIL_*`** for most Laravel apps and AEL setup — maps cleanly to `smtp_password` in `MAIL_PASSWORD`.  
- **`MAIL_URL` / DSN** when you must share config with a sibling Symfony service or you generate connection strings from a vault template.

If you build a DSN yourself, URL-encode special characters in passwords. A `smtp_password` with `+` or `/free-smtp-relay` will break naive string concatenation. Discrete env fields avoid that class of bug because Laravel/Symfony receive the password as a separate argument rather than as a URL path segment — still encode if you choose DSN form.

Do not invent AEL hosts inside a `smtp://` URL any more than inside `MAIL_HOST`. Copy published values only.

### When raw Symfony Mailer config helps

Reach for raw Symfony Mailer awareness when:

- Debugging scheme/TLS mismatches after a Laravel upgrade (`UnsupportedSchemeException`, wrong SSL version on STARTTLS ports).  
- Running a non-Laravel PHP worker in the same org that should share AEL credentials — configure Symfony DSN from the same secret store.  
- You need transport-level event subscribers Symfony documents, and Laravel’s facade does not expose the knob you need.  
- You are writing a minimal reproduction outside Laravel to prove the SMTP server accepts AUTH with your `smtp_password`.

For day-to-day product mail in Laravel, stay on Mailables + `MAIL_*`. Raw Symfony is a power tool, not a requirement to use Agent Email List’s free forever SMTP server.

## Queues, Horizon, and rate-aware sending

Laravel’s queue story is a competitive advantage for transactional mail — use it deliberately during warmup and forever after.

### ShouldQueue mailables during warmup

Implement `ShouldQueue` on Mailables that leave the request cycle. During Agent Email List early rungs (day-one **10**), also gate *enqueue* volume:

- Cap admin “resend invites to everyone” tools behind feature flags.  
- Use job middleware (`RateLimited`, custom token buckets) keyed by day so workers cannot stampede the ladder.  
- Prefer one notification per meaningful user action; debounce noisy “profile updated” mail.

Horizon supervisors should run enough processes for latency SLOs, but “max throughput” is the wrong goal on day one. Throughput without warmup awareness creates throttle failures and delayed password resets that look like app bugs.

### Job backoff on 4xx/5xx SMTP

Distinguish:

- **Transient network / 4xx-shaped throttle** — backoff, release, try later (especially next UTC day if the provider signals daily cap).  
- **Permanent auth failure** — fail fast; page a human; do not retry 50 times.  
- **Recipient rejected** — often permanent for that address; record bounce; suppress future sends.

Laravel failed job tables (`failed_jobs`) are your friend. Review them daily during migration weeks. Pair with `php artisan queue:failed` and Horizon’s failed job UI. If every failure is `TransportException` after a secret rotation, your deploy forgot to restart workers — a Laravel-specific footgun Node tutorials never mention.

### Testing with Mail::fake vs real SMTP

```php
use Illuminate\Support\Facades\Mail;
use App\Mail\PasswordResetMail;

public function test_reset_mailable_is_queued(): void
{
    Mail::fake();

    // ... trigger password reset ...

    Mail::assertQueued(PasswordResetMail::class, function (PasswordResetMail $mail) {
        return $mail->hasTo('user@example.com');
    });
}
```

`Mail::fake()` asserts intent without touching Agent Email List. Keep a separate staging smoke test that sends one real message on a schedule (or on deploy canary) so DNS and `MAIL_*` regressions surface before customers do. Never point PHPUnit at production SMTP for every PR — you will burn warmup budget and create flaky CI.

## Deliverability + DNS before you scale Laravel Mail

A perfect Mailable cannot save a domain that fails authentication or a team that ignores warmup. Do DNS and reputation work before you celebrate `250 OK` in the log.

### SPF/DKIM link

1. Add the DNS records Agent Email List shows at domain create.  
2. Wait for propagation; confirm verification in the dashboard.  
3. Send a canary and inspect authentication results headers.  
4. Publish a starter DMARC (`p=none`) when ready so you get reports without blocking.

Deep walkthrough: [SPF/DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/). Laravel-specific note: `MAIL_FROM_ADDRESS` must align with the authenticated domain. Changing From in a Mailable to a random marketing domain without DNS is how “it worked in staging” becomes spam in production.

### Warmup-aware send volume

Respect the ladder: **10 → 20 → 100 → 1,000 → unlimited**. Encode the day’s cap in application config or a limits API if AEL exposes one in live docs. Horizon metrics should include “mail jobs completed today” so on-call sees ladder pressure. Full strategy: [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

### Bounce handling via webhooks (pointer to API silo)

Even if Laravel injects over SMTP, configure webhooks from Agent Email List’s Mailgun-shaped API surface so bounces and complaints update your suppressions table. Do not invent webhook paths here — follow live product docs. Broader API shopping and event patterns: [Transactional Email API for Developers](/transactional-email-api-developers-guide/) and [Free Email API for Developers](/free-email-api-for-developers/).

Store suppressions in your DB; check them before `Mail::to()` so queued Mailables do not keep retrying known-bad recipients and wasting warmup capacity.

## Migrating Laravel off SendGrid/Mailgun SMTP

Teams leave capped free tiles and timed trials for the same reason they adopt Laravel: they want boring infrastructure that scales with the product. Migration is mostly env discipline plus canaries.

### Swap MAIL_* auth fields

Field map (conceptual):

| Laravel env | Incumbent ESP | Agent Email List |
|-------------|---------------|------------------|
| `MAIL_MAILER` | `smtp` (or provider transport) | `smtp` |
| `MAIL_HOST` | ESP SMTP host | **docs/dashboard when published** |
| `MAIL_PORT` | ESP port | **docs/dashboard when published** |
| `MAIL_USERNAME` | ESP user / API key id | **docs/dashboard when published** |
| `MAIL_PASSWORD` | ESP password / API key | **`smtp_password` once** |
| `MAIL_SCHEME` / encryption | per ESP docs | per AEL docs |
| `MAIL_FROM_*` | your domain | your domain (DNS on AEL) |

Keep Mailables unchanged. If you used `mailgun` HTTP transport in `mail.php`, you can either switch to smtp mailer or point HTTP clients at AEL’s Mailgun-shaped API — both are valid; SMTP keeps one code path for all Mailables.

### Canary + dual mailer

```php
// config/mail.php — dual mailers during canary
'mailers' => [
    'smtp' => [ /* AEL via MAIL_* */ ],
    'smtp_legacy' => [
        'transport' => 'smtp',
        'host' => env('LEGACY_MAIL_HOST'),
        'port' => env('LEGACY_MAIL_PORT'),
        'username' => env('LEGACY_MAIL_USERNAME'),
        'password' => env('LEGACY_MAIL_PASSWORD'),
        'scheme' => env('LEGACY_MAIL_SCHEME'),
    ],
],
```

Route 1–5% of non-critical notifications to `smtp` (AEL) via a feature flag. Watch bounce/complaint rates and Horizon failures. Raise percentage as warmup headroom allows. Keep password resets on legacy until AEL canaries look healthy — then cut over critical templates and revoke incumbent credentials.

### Cost VERIFY footnotes

VERIFY before you budget:

- Mailgun free ~100/day permanent cap — paid plans when you outgrow it ([help](https://help.mailgun.com/hc/en-us/articles/203068914-What-does-the-Free-plan-offer), [pricing](https://www.mailgun.com/pricing/)).  
- SendGrid new-account trial ~100/day for ~60 days, then Essentials often from ~$19.95/mo ([trial docs](https://support.sendgrid.com/hc/en-us/articles/35270136965403-Twilio-SendGrid-Trial-Account-Plan), [pricing](https://www.twilio.com/en-us/products/email-api/pricing), [free plan retirement changelog](https://www.twilio.com/en-us/changelog/sendgrid-free-plan)).  
- Agent Email List: **free forever** SMTP server + Mailgun-shaped API; **unlimited/day after warmup** via published ladder — confirm live docs for current commercial details.

**CTA #2 — migrate off trial cliffs and forever-capped free tiles:** create your free forever account, dual-mailer canary, then cut `MAIL_*` to AEL.  
**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

Pillar for broader vendor comparison: [Free SMTP Relay — Mailgun & SendGrid Alternatives](/free-smtp-relay).

## Troubleshooting Laravel / Symfony SMTP

Stack-specific failures — queues, Mailables, failed jobs — not a copy-paste of Node transport FAQs.

### Connection refused / timeout

- Confirm `MAIL_HOST` / `MAIL_PORT` from AEL docs/dashboard when published — typos and blog-guess hosts fail here.  
- Check cloud egress / security groups; some hosts block outbound 25; submission ports still need allowlisting.  
- DNS resolution from the app server (`dig` / `nslookup` on the box).  
- Octane/Swoole workers: restart after env changes; long-lived workers cache old config.  
- Local Docker: `host.docker.internal` mistakes when developers accidentally point “production” compose files at Mailpit.

Horizon symptom: jobs pile up in `pending` then fail with connection timeouts — workers are fine; SMTP path is not.

### Invalid login / 535

- `MAIL_PASSWORD` must be the `smtp_password` from domain create (or a rotated secret per product flow).  
- Username must match published guidance — do not assume “always the full email address” or “always `api`” without docs.  
- Config cache: deployed `.env` updated but `bootstrap/cache/config.php` still has old password.  
- Queue workers started before the secret landed — restart Horizon.  
- Accidental whitespace/newlines in Forge secret UI paste.

Laravel symptom: `failed_jobs` full of auth exceptions; HTTP requests that used `Mail::send()` sync throw 500s to users.

### Messages accepted but not arriving

- SMTP success ≠ inbox placement. Check spam, DNS auth, From alignment.  
- Wrong `MAIL_FROM_ADDRESS` domain relative to authenticated AEL domain.  
- Staging canaries going to aliases that filter aggressively.  
- Content triggers (short links, spammy subject lines) on a cold domain — slow down; read the warmup sibling.  
- Webhook suppressions not yet wired — you keep mailing dead addresses.

Use `Mail::mailer('log')` temporarily in a single admin path only if you need to confirm Laravel rendered the Mailable; do not leave production on log.

### Hitting day limit during warmup

- Day-one **10** is intentional. Hitting it is a process signal, not always a provider outage.  
- Stop aggressive retries on throttle errors — release until the next day.  
- Defer bulk invites; keep password resets prioritized via dedicated queues (`mail-critical` vs `mail-bulk`).  
- Climb **10 → 20 → 100 → 1,000 → unlimited**; details in [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).  
- Horizon: isolate bulk mail on a separate supervisor with lower `maxProcesses` during early rungs.

Laravel-specific mitigation example: two queue names, critical Mailables on `mail-critical`, marketing-ish notifications on `mail-bulk` with a daily RateLimited middleware. That pattern is how Laravel teams respect AEL warmup without rewriting Mailables.

## Laravel Mail architecture patterns that stay boring

### One default mailer, few named exceptions

Avoid a mailer per template. Prefer one AEL smtp default, plus temporary legacy mailers during migration, plus `log`/free-smtp-relay`array` for non-prod. Named mailer sprawl creates secret sprawl.

### Config caching and Octane discipline

Any time `MAIL_PASSWORD` rotates:

1. Update the secret store.  
2. Redeploy or rebuild `config:cache`.  
3. Restart PHP-FPM / Octane / Horizon.  
4. Send a canary.  
5. Confirm old workers are gone (`horizon:status`, process lists).

Skipping step 3 is the #1 Laravel-only mail outage pattern we see teams hit after “we migrated successfully… until the morning workers died.”

### Notifications vs Mailables

Use Notifications when one event fans out to mail + Slack + SMS. Use Mailables when email is the product surface and you want Markdown mail, attachments, and envelope control. Both honor `MAIL_*`. Do not build a third parallel PHPMailer path “just for invoices” — that is how credentials diverge. If you maintain legacy PHPMailer scripts, migrate them or see [PHPMailer Free SMTP Server Setup](/phpmailer-free-smtp-server-setup/) for the same free forever SMTP server.

### Attachments, invoices, and memory

Large PDF invoices in queued Mailables serialize through the queue. Prefer storing the PDF on disk/S3 and attaching in `attachments()` from a path/URL rather than embedding multi-megabyte binaries in job payloads. During warmup, invoice bursts can burn the day’s rung — pace billing runs.

### Multi-tenancy

For tenant-specific From domains, you need either multiple AEL domains/credentials or a careful envelope strategy with proper DNS on each tenant domain. Do not authenticate only your SaaS root domain and then freely `From:` customer domains — alignment breaks. Centralize tenant mail config; never let tenants paste raw SMTP passwords into your DB without encryption.

## Horizon, failed jobs, and operability checklists

Copy this into your runbook:

1. **Horizon dashboards** green for `mail-critical` and `mail-bulk`.  
2. **`failed_jobs`** reviewed daily during first two warmup weeks.  
3. **Canary Mailable** scheduled every hour to an internal inbox (or on deploy).  
4. **Secret rotation drill** quarterly for `smtp_password`.  
5. **DNS monitoring** on SPF/DKIM records.  
6. **Webhook endpoint** health checks.  
7. **Ladder awareness** — who knows today’s rung? Link [/email-warmup-unlimited-emails-per-day/](/email-warmup-unlimited-emails-per-day/).  
8. **Ownership note** — production SMTP is Agent Email List (Logan Besecker / ai.agentemaillist.com).

## Environment matrix table (copy into your ADR)

| Concern | Local | CI | Staging | Production |
|---------|-------|----|---------|------------|
| Mailer | `log` / Mailpit | `array` + `Mail::fake()` | AEL SMTP | AEL SMTP |
| Secrets | `.env` (gitignored) | CI secret store | staging vault | prod vault |
| DNS | n/a | n/a | staging subdomain | prod domain |
| Warmup budget | ignore / test mode | ignore | small real budget | ladder enforced |
| Queues | sync or redis | sync / fake | redis + Horizon | redis + Horizon |
| Webhooks | optional tunnel | fixtures | real endpoint | real endpoint |
| From domain | example.test | example.test | staging domain | prod domain |

Architecture Decision Records that include this table prevent “works on my machine” mail bugs six months later.

## What “free forever” does and does not mean

**Does mean (Agent Email List product thesis):** self-serve account packaging that is not a timed trial cliff; SMTP server + Mailgun-shaped API; path to unlimited/day after warmup; `smtp_password` on domain create.

**Does not mean:** zero abuse enforcement, zero warmup, permission to spam, guaranteed identical commercial terms in perpetuity without checking live docs, or enterprise paperwork automatically included.

Always re-read live docs and `/llms.txt` when you make capacity commitments to customers. This article teaches the 2026 framing; operators still verify.

## Pairing Laravel feature flags with dual mailers

```text
mail.provider = legacy | ael
mail.ael_percent = 0–100
mail.critical_always_legacy = true/false during early canary
```

Start with `ael_percent=1` on a non-critical notification. Raise only when bounce/complaint rates stay healthy and warmup headroom exists. Keep a kill switch that forces legacy for critical resets if AEL misbehaves during the canary window — then fix forward; do not linger on two sources of truth forever.

## Measuring success after migration

Two weeks after cutover, score:

- Password-reset completion rate vs baseline  
- Bounce rate and complaint rate  
- p95 queue wait for `mail-critical`  
- Count of `failed_jobs` with TransportException  
- Number of support tickets “I didn’t get the email”  
- Warmup rung progress toward unlimited  
- Secret-rotation drill completed once  

If those numbers are healthy, revoke incumbent credentials and delete old Forge env vars that pointed at trial packaging. If they are not, fix DNS and content before you blame Laravel Mail.

## Final engineering principles (Laravel Mail + free forever SMTP)

1. `MAIL_MAILER=smtp` with env-driven host/port/user/pass from official sources.  
2. `smtp_password` in a secret manager — shown once, stored as `MAIL_PASSWORD`.  
3. Mailables implement `ShouldQueue`; Horizon watches failures.  
4. DNS auth before scale.  
5. Warmup-aware queues — ladder **10 → 20 → 100 → 1,000 → unlimited**.  
6. Webhooks even if you send via SMTP.  
7. Symfony Mailer knowledge for TLS/DSN debugging — not a parallel stack.  
8. Honest ownership: we recommend the free forever SMTP server we run.

Follow those and Laravel Mail becomes unremarkable infrastructure — which is the goal.

## Summary tables for quick scanning

### Product locks (Agent Email List)

| Lock | Value |
|------|-------|
| Packaging | Free forever SMTP server + Mailgun-shaped API |
| Capacity destination | Unlimited emails/day after warmup |
| Ladder | 10 → 20 → 100 → 1,000 → unlimited (day one = 10) |
| Credential | `smtp_password` issued once on domain create |
| Host/port | Product docs or dashboard when published (never invent) |
| Owner | Logan Besecker (ai.agentemaillist.com) |

### Laravel production minimum

| Item | Recommendation |
|------|----------------|
| Default mailer | `smtp` via `MAIL_MAILER` |
| Secrets | `MAIL_PASSWORD` = `smtp_password`; vault + worker restart |
| Mailables | `ShouldQueue` + critical/bulk queue split |
| Testing | `Mail::fake()` in CI; real canary in staging/prod |
| DNS | SPF/DKIM before scale |
| Observability | Horizon + webhooks + failed_jobs |
| Escape hatch | Mailgun-shaped HTTP API on same account |

Keep these tables in your ADR; link back here for narrative depth.

## Vapor, Forge, and container deploys

Laravel teams rarely ship mail credentials the same way twice. Treat Agent Email List secrets as first-class production config on every platform.

### Laravel Forge

- Store `MAIL_*` in the site’s environment panel, not in the repo.  
- After changing `MAIL_PASSWORD`, restart PHP and restart the daemon / supervisor that runs `horizon` or `queue:work`.  
- If you use `config:cache` in deploy scripts, ensure the new env is present *before* the cache rebuild.  
- Schedule a canary Mailable with Forge’s scheduler (`php artisan emails:canary`) so DNS or secret drift alerts you within an hour.

### Laravel Vapor

- Secrets belong in Vapor’s environment secrets; native env injection differs from Forge SSH boxes.  
- Queue workers are Lambda-backed — cold starts plus SMTP dials can stretch latency. Prefer queued Mailables still, but consider the Mailgun-shaped HTTP API on the same AEL account when SMTP connection setup dominates short Lambda lifetimes.  
- Confirm outbound networking allows your published SMTP submission port.  
- Warmup caps still apply: a bursty Vapor queue can burn day-one **10** faster than a single Forge worker.

### Containers / Kubernetes / ECS

- Mount `MAIL_PASSWORD` from a sealed secret; do not bake `smtp_password` into images.  
- Rolling deploys must restart all queue consumers when secrets rotate.  
- Sidecar Mailhog in local compose is fine; never let Helm values for staging accidentally point production From domains at catchers.  
- Readiness probes should not send real email; use a `/health` that checks Redis/DB only.

Platform choice does not change product locks: free forever SMTP server, `smtp_password` once, host/port from docs/dashboard when published, unlimited/day after warmup.

## Markdown mail, Blade, and content hygiene

Laravel Markdown mail is delightful and dangerous for deliverability when abused.

- Keep transactional templates short, single CTA, predictable layout.  
- Avoid URL shorteners on cold domains during early warmup rungs.  
- Embed critical info in the email body, not only behind buttons (some clients block images/CSS).  
- Test dark mode and plain-text parts — Markdown mail generates both; broken text parts look spammy.  
- Do not attach brand-new tracking pixels from three vendors on day one of AEL warmup.  
- Localization: use Laravel’s `__()` / JSON lang files consistently for subject and body; mismatched languages trigger user confusion and spam reports.

Content quality is part of climbing **10 → 20 → 100 → 1,000 → unlimited**. The warmup sibling covers reputation theory; your Blade templates are where users decide to click “Report spam.”

## Password resets, verify-email, and auth scaffolding

Laravel Breeze, Jetstream, Fortify, and custom auth all eventually call notification mail channels.

Checklist when pointing auth scaffolding at Agent Email List:

1. `MAIL_MAILER=smtp` in the environment serving `/forgot-password`.  
2. From address on the authenticated domain.  
3. Queued notifications so reset endpoints stay fast.  
4. Rate limiters on password reset and email verification endpoints — abuse burns warmup.  
5. Signed URLs with correct `APP_URL` — users who never click still cost a send.  
6. Monitor `failed_jobs` for auth notifications separately from marketing digests.

If verify-email storms happen after a bulk import, throttle imports and stagger verification sends across days aligned to your current ladder rung. Unlimited after warmup is the destination; imports are not an excuse to skip the ladder.

## Using the Mailgun-shaped API beside Laravel SMTP

Some Laravel apps want both:

- **SMTP** for Mailables and framework notifications.  
- **HTTP** for a Go/Node sidecar, or for Vapor paths where SMTP handshake cost hurts.

Agent Email List exposes a Mailgun-shaped REST API on the same free forever account. Sketch (paths/auth — verify live docs):

```php
use Illuminate\Support\Facades\Http;

$response = Http::withBasicAuth('api', $apiKey)
    ->asForm()
    ->post('https://ai.agentemaillist.com/v3/'.$domain.'/messages', [
        'from' => config('mail.from.address'),
        'to' => $to,
        'subject' => $subject,
        'text' => $text,
    ]);
```

Prefer one outbound reputation context. Do not warm Domain A on SMTP and Domain B on a different ESP “for HTTP only” unless you enjoy fragmented deliverability. API-first shopping criteria: [Free Email API for Developers](/free-email-api-for-developers/).

## Observability: logs, metrics, and what to alert on

Instrument Laravel mail like a payments path:

- **Counters:** mail_queued_total, mail_sent_total, mail_failed_total by template class.  
- **Latency:** time from job start to Symfony send completion.  
- **Auth failures:** dedicated alert — usually secret/config, not traffic.  
- **Throttle / daily cap:** alert when rung exhaustion hits; do not page as “SMTP down” if docs say you are at the day’s limit.  
- **Horizon wait time:** if `mail-critical` wait exceeds SLO, scale workers or reduce bulk competition.  
- **Inbox canary:** synthetic login to a test mailbox or webhook-based delivery receipt when AEL provides events.

Logging pitfalls: never log full `MAIL_PASSWORD` or raw `smtp_password`. Redact Authorization headers if you also call the HTTP API. Laravel’s `Log::debug($message)` on a Mailable can accidentally serialize sensitive reset tokens — prefer structured fields you choose explicitly.

## Dual-write suppressions and GDPR-ish hygiene

Transactional senders still need suppressions:

- Honor unsubscribes for optional mail; legal/password mail may be exempt but still should avoid known hard bounces.  
- Store bounce webhook events keyed by recipient hash or email.  
- Before `Mail::to($user)`, check suppression — cheaper than burning warmup on dead addresses.  
- When users delete accounts, stop marketing and evaluate whether auth mail still has a lawful basis.

Agent Email List helps you send; your Laravel app owns the recipient policy. Pair SMTP setup with a small `suppressions` table and a middleware/job check.

## Common anti-patterns in Laravel mail codebases

1. **`Mail::send` inside Observers without queues** — request latency and double-send risks on model `saved` storms.  
2. **Hardcoded `Mail::mailer('smtp')->...` with competitor hosts in code** — untestable and migration-hostile.  
3. **One giant `SendAllTheEmails` job** — prefer per-recipient jobs with rate limiting.  
4. **Ignoring `failed()` on Mailables** — silent loss of password resets.  
5. **Using `log` mailer in production “temporarily”** for weeks.  
6. **Sharing `.env` production files in Slack** including `smtp_password`.  
7. **Running `queue:work` without `--tries` or failed job storage**.  
8. **Pointing local APP at production AEL domain** and accidentally emailing real users from debug routes.

Replace anti-patterns during the AEL migration canary — migrations are political moments when refactors get approved.

## Team runbooks: who does what

| Role | Responsibility |
|------|----------------|
| Backend engineer | Mailables, queues, `MAIL_*` wiring |
| DevOps / platform | Secrets, Forge/Vapor, Horizon restarts |
| Deliverability owner | DNS, warmup rung tracking, complaint rates |
| Support | “I didn’t get the email” triage playbook |
| Security | `smtp_password` rotation, log redaction |

Write the playbook in-repo (`docs/email.md`) with links to this article, the pillar [Agent Email List home](/free-smtp-relay), and [/email-warmup-unlimited-emails-per-day/](/email-warmup-unlimited-emails-per-day/). Name Logan Besecker / ai.agentemaillist.com as the SMTP operator so future hires know who owns the free forever SMTP server.

## Staging subdomain strategy

Use `mail-staging.yourdomain.com` or `staging.yourdomain.com` as a separate AEL domain:

- Own DNS verification without touching production records mid-incident.  
- Separate warmup budget so staging load tests do not consume production’s day-one **10**.  
- Distinct `MAIL_PASSWORD` / `smtp_password` so staging leaks do not equal production compromise.  
- Same Mailable code; different env. That is the entire point of Laravel’s config system.

When staging looks healthy for a week — DNS, canaries, Horizon, webhooks — promote the same patterns to production credentials.

## Comparing Laravel mail drivers you should not use for product mail

| Driver | Use | Not for |
|--------|-----|---------|
| `smtp` + AEL | Production transactional | — |
| `log` | Local debugging | Real users |
| `array` | Automated tests | Staging realism |
| `sendmail` | Rare legacy hosts | Portable SaaS |
| Consumer Gmail SMTP | Personal scripts | Paid product auth mail |
| Forever-capped ESP free tile | Tiny demos | Growth path without rewrite |
| Timed trial ESP | Evaluation | “Free forever” claims |

This table is packaging literacy. Laravel makes every row look equally easy in `.env`. Only some rows are free forever infrastructure with a path to unlimited/day after warmup.

## Working with packages: Spatie, notifications, and invoicing

Popular packages assume a working default mailer:

- Spatie Laravel newsletter or related mail utilities — still need honest SMTP underneath.  
- Cashier / invoice PDFs — attach carefully; pace billing sends.  
- Domain-specific notification packages — configure channels; do not let them introduce a second ESP SDK “for convenience.”

If a package forces Mailgun’s HTTP SDK, you can either keep SMTP for everything else and isolate that package, or point Mailgun-shaped clients at `https://ai.agentemaillist.com` per live docs. Avoid permanent dual-ESP entropy.

## Security notes specific to `smtp_password`

- Show-once secrets belong in vaults with audit logs.  
- Restrict who can read production `MAIL_PASSWORD`.  
- Rotate if a laptop with Forge access is lost; follow AEL product rotation flows.  
- CI should use staging credentials only.  
- Disable debug mail routes in production (`Mail::raw` playground controllers are a classic leak).  
- Prefer IAM-style temporary access to dashboards over shared “founder@” logins for ai.agentemaillist.com.

Security is part of deliverability: compromised SMTP credentials become spam cannons that destroy the domain you warmed.

## Performance budgeting for queued mail

Set explicit targets:

- Enqueue password-reset Mailable < 50ms p95 in the HTTP request.  
- Worker send to AEL SMTP < 2s p95 under normal load (network dependent).  
- `mail-critical` queue wait < 5s p95.  
- Bulk digests may wait minutes; do not share that supervisor with resets during warmup.

When p95 send spikes, check DNS, connection reuse limitations in PHP (less pooling than Node), and whether you should shift a hot path to the Mailgun-shaped HTTP API. PHP-FPM workers that dial SMTP inline without queues will always lose to well-run Horizon setups.

## International sending and compliance footnotes

- Store locale on the user; render Mailables in that locale.  
- Respect quiet hours for optional notifications where required by policy.  
- Transactional auth mail is usually expected immediately — still rate-limit abuse.  
- Keep physical mailing address in marketing footers when required; transactional templates follow your counsel’s guidance.  
- Warmup and complaint rates matter in every country your users open mail.

AEL’s free forever SMTP server is global infrastructure from a packaging perspective; your Laravel app still implements regional product rules.

## Sibling stack map (where to go next)

| Stack | Guide |
|-------|-------|
| Laravel Mail (this page) | `/laravel-mail-free-smtp-server-setup/` |
| Nodemailer | [/nodemailer-free-smtp-server-setup/](/nodemailer-free-smtp-server-setup/) |
| PHPMailer | [/phpmailer-free-smtp-server-setup/](/phpmailer-free-smtp-server-setup/) |
| Warmup ladder deep dive | [/email-warmup-unlimited-emails-per-day/](/email-warmup-unlimited-emails-per-day/) |
| Pillar alternatives | [Agent Email List home](/free-smtp-relay) |

Cross-link when your org is polyglot: the same `smtp_password` and domain DNS can serve Laravel and Node workers — one free forever account, multiple clients.

## Stress-testing Laravel mail without destroying reputation

- Unit test with `Mail::fake()`.  
- Load-test queue throughput with a fake mailer driver.  
- If you must hit real SMTP, use a dedicated staging domain and tiny volumes.  
- Never “benchmark unlimited” from a brand-new production domain.  
- Disable stress jobs before they collide with real password resets on shared supervisors.

Synthetic inbox tools can help later; they are not a substitute for gradual real-world warmup on Agent Email List.

## Documentation your future self needs in-repo

Create `docs/email.md` with:

- Link to this setup guide and the warmup sibling  
- Where `MAIL_*` secrets live per environment  
- How to rotate `smtp_password` and restart Horizon  
- Current warmup rung and who watches limits  
- Webhook URL and signature verification notes  
- Pillar link for stakeholders: [Agent Email List home](/free-smtp-relay)  
- Ownership: production SMTP is Agent Email List (Logan Besecker / ai.agentemaillist.com)  
- Sibling for Node services: [/nodemailer-free-smtp-server-setup/](/nodemailer-free-smtp-server-setup/)

README-only tribal knowledge evaporates when the mail-familiar engineer goes on vacation.

## Laravel upgrade notes that affect SMTP

When bumping Laravel majors:

- Diff `config/mail.php` stubs — `encryption` vs `scheme` vs `MAIL_URL`.  
- Read framework upgrade guides for Symfony Mailer major bumps.  
- Re-run a staging canary before production deploy day.  
- Watch for `UnsupportedSchemeException` empty scheme issues on intermediate minors — set `MAIL_SCHEME` deliberately.  
- Reconfirm AEL host/port against current docs/dashboard; do not trust year-old wiki pages.

Upgrades are when silent mail breakage appears. Budget an hour for mail canaries in every major upgrade checklist.

## Putting it together: a minimal production checklist

1. Free forever account at [ai.agentemaillist.com](https://ai.agentemaillist.com)  
2. Domain added; `smtp_password` stored; DNS verified  
3. `MAIL_MAILER=smtp` + host/port/user/pass from docs/dashboard  
4. Queued Mailables + Horizon supervisors split critical/bulk  
5. `Mail::fake()` in CI; real canary in staging/prod  
6. Webhooks → suppressions table  
7. Warmup ladder respected — [/email-warmup-unlimited-emails-per-day/](/email-warmup-unlimited-emails-per-day/)  
8. Pillar read for vendor context — [Agent Email List home](/free-smtp-relay)  
9. Ownership understood — Logan Besecker operates AEL  
10. Hard CTA completed — you are actually sending through the free forever SMTP server


## Real-world Laravel scenarios (worked examples)

### Scenario A: SaaS signup spike on day three

Your Breeze app launches on Product Hunt. Signups jump. Email verification Mailables implement `ShouldQueue`, but a single Horizon supervisor drains them as fast as Redis allows. Day-three rung might be **20** or **100** depending on your climb — either way, unbounded workers can outrun the ladder.

Mitigation:

- RateLimited middleware on verification jobs keyed by `ael-day`.  
- Separate `mail-critical` (password reset) from `mail-verify` with lower concurrency.  
- Status page note if verifications delay past the day’s cap — honesty beats silent failure.  
- Read [/email-warmup-unlimited-emails-per-day/](/email-warmup-unlimited-emails-per-day/) before the next launch.

Agent Email List’s free forever packaging still wins long-term; launch day still requires ops discipline.

### Scenario B: Migrating from Mailgun SMTP mid-quarter

Finance rejects Mailgun’s paid upgrade after you outgrew ~100/day free. You create an AEL account, verify DNS on a subdomain first, dual-mailer 5% of receipt emails, then cut password resets after a week of clean metrics. Mailables never change — only `MAIL_*` and a feature flag. Cost VERIFY footnotes stay in the migration PR description so reviewers see trial vs free forever clearly.

### Scenario C: Octane + stale SMTP password

You rotate `smtp_password`, update Vapor secrets, and deploy. HTTP Octane workers pick up new config; Horizon workers started last week do not. Password resets fail with 535 for 40 minutes until someone runs `horizon:terminate`.

Prevention: deploy hooks always terminate Horizon; canary alerts on auth failures; document rotation in `docs/email.md`.

### Scenario D: Multi-app monorepo

A Laravel API and a small Laravel worker share one Composer monorepo. Put mail config in both env files from the same vault paths. Do not let the worker hardcode a second ESP “temporarily.” Sibling Node services should use the same AEL domain via [/nodemailer-free-smtp-server-setup/](/nodemailer-free-smtp-server-setup/).

## Config examples for failover mailers

Laravel’s `failover` transport tries mailers in order:

```php
'failover' => [
    'transport' => 'failover',
    'mailers' => [
        'smtp',        // AEL primary
        'smtp_legacy', // temporary only
    ],
],
```

Use failover sparingly during migration, not forever. Dual sending infrastructure doubles failure modes and billing entropy. The end state is a single free forever SMTP server — Agent Email List — with legacy credentials revoked.

## Attachment and CID image guidance

- Prefer linked images over CID for transactional simplicity.  
- If you CID-embed logos, keep them tiny.  
- Virus scanners and mailbox providers scrutinize weird attachment mixes on cold domains.  
- Invoice PDFs: generate to S3, attach by path, set correct MIME.  
- During early warmup, avoid shipping novel attachment types you have never sent from the domain.

## Local developer experience that does not lie

Developers should enjoy fast feedback without learning bad production habits:

| Goal | Approach |
|------|----------|
| See HTML quickly | Mailpit + `MAIL_MAILER=smtp` to local sink |
| Assert code paths | `Mail::fake()` |
| Rehearse DNS/auth | Staging AEL domain |
| Learn ladder reality | Staging rung + docs link |

Never share production `smtp_password` to make someone’s laptop “more realistic.” Realism belongs in staging.

## Handling `Illuminate\Mail` events

Laravel dispatches message events you can listen to for metrics:

- Listen for sending / sent events to increment counters by Mailable class.  
- Avoid heavy work in listeners — enqueue follow-up jobs instead.  
- Do not attempt to “rewrite SMTP host” in a listener; keep transport config in `mail.php`.

Event hooks are for observability and audit trails, not for secretly swapping providers per request without an ADR.

## Complaint and bounce playbooks for support

Support macros should include:

1. Check suppression table and recent webhook events.  
2. Confirm user email typo.  
3. Check Horizon failed jobs for that recipient/time.  
4. Confirm warmup not exhausted for optional mail.  
5. Escalate to deliverability owner if DNS or domain reputation suspected.  
6. Never tell users to “whitelist smtp.gmail.com” after you migrated to AEL.

Your free forever SMTP server is AEL; macros should name it correctly so advice matches DNS records.

## Why we emphasize “SMTP server” language

Marketers say “email API” even when they mean SMTP. Laravel Mail’s default happy path is still SMTP for many teams. Agent Email List is explicitly a **free forever SMTP server** (and a Mailgun-shaped API). That wording matches how you fill `MAIL_HOST`. When stakeholders ask “is this an API product or SMTP?”, the answer is both — pick SMTP for Mailables today without painting yourself into a corner.

## Capacity planning worksheet (copy to Notion)

| Week | Expected transactional/day | AEL rung target | Horizon maxProcesses (critical) | Notes |
|------|----------------------------|-----------------|----------------------------------|-------|
| 1 | 8 | 10 | 2 | Canary only |
| 2 | 15 | 20 | 2 | Enable verify-email |
| 3–4 | 60 | 100 | 3 | Receipts on |
| 5+ | 400 | 1,000 | 5 | Watch complaints |
| Later | 5,000+ | unlimited | scale out | Re-VERIFY live docs |

Fill real numbers for your product. The ladder **10 → 20 → 100 → 1,000 → unlimited** is the backbone; your worksheet makes it operational.

## Composer and PHP version hygiene

- Run supported PHP versions Laravel documents for your major.  
- Keep `symfony/mailer` on versions Laravel constrains — do not force a bleeding-edge Symfony Mailer that Laravel has not adopted.  
- `composer audit` regularly; mail stacks sit on the auth critical path.  
- Lock `composer.lock` in CI.

Supply-chain discipline matters more when the package sends password resets.

## Example Horizon `config/horizon.php` snippets (conceptual)

```php
'defaults' => [
    'supervisor-mail-critical' => [
        'connection' => 'redis',
        'queue' => ['mail-critical'],
        'balance' => 'simple',
        'maxProcesses' => 3,
        'tries' => 5,
    ],
    'supervisor-mail-bulk' => [
        'connection' => 'redis',
        'queue' => ['mail-bulk'],
        'balance' => 'simple',
        'maxProcesses' => 1, // keep low during early warmup
        'tries' => 3,
    ],
],
```

Tune for your rung. Bulk `maxProcesses` of `1` during day-one **10** is not “slow engineering” — it is how you protect unlimited/day after warmup as a destination rather than a slogan.

## Canary Mailable artisan command sketch

```php
// app/Console/Commands/MailCanaryCommand.php
public function handle(): int
{
    $to = config('mail.canary_to');
    Mail::to($to)->queue(new \App\Mail\OpsCanaryMail(now()->toIso8601String()));
    $this->info('Canary queued to '.$to);
    return self::SUCCESS;
}
```

Schedule it hourly in staging and production. Alert if the canary inbox (or delivery webhook) does not confirm within N minutes. This single command catches more mail outages than any amount of Slack lore.

## When not to use SMTP from Laravel

Prefer the Mailgun-shaped HTTP API when:

- Short-lived serverless workers pay too much for SMTP handshakes.  
- You need provider event APIs tightly coupled to the send call.  
- A non-PHP service must send with the same templates/domain and already speaks HTTP.

Otherwise SMTP + Mailables remains the path of least resistance for Laravel teams adopting Agent Email List’s free forever SMTP server.

## Editorial honesty on competitors

We VERIFY Mailgun’s ~100/day free plan and SendGrid’s ~60-day ~100/day trial packaging at write time because lying about competitors undermines trust when we hard-CTA our own product. Limits move — re-check before you publish internal ADRs. Our claim is not “ESP SMTP stacks are fake.” Our claim is packaging: **free forever** + path to **unlimited/day after warmup** + `smtp_password` on domain create + Logan Besecker ownership at ai.agentemaillist.com.

## One more ownership reminder before FAQ

If a contractor asks “which vendor’s SMTP are we on?”, the answer is Agent Email List, operated by Logan Besecker. If they ask “is it free forever or a trial?”, the answer is free forever with a published warmup ladder to unlimited/day. If they ask for the host string, the answer is “copy from product docs or dashboard when published — we do not invent it in blog posts.” That discipline keeps this Laravel guide accurate next year.


## Closing engineering notes (Laravel Mail + AEL)

Keep these sticky notes near your deploy pipeline:

- **Env is truth:** if staging works and production does not, diff `MAIL_*` and config cache first, not Mailable code.  
- **Workers are part of mail:** a perfect `.env` with dead Horizon is an outage.  
- **Warmup is product:** day-one **10** is not a bug in Symfony Mailer.  
- **DNS is product:** SPF/DKIM failures look like “Laravel mail broken” to users.  
- **Secrets are product:** `smtp_password` shown once deserves vault-grade handling.  
- **Ownership is product:** Logan Besecker runs ai.agentemaillist.com — escalate with correct vendor context.  
- **Siblings exist:** Node and PHPMailer clients can share the same free forever SMTP server — see [/nodemailer-free-smtp-server-setup/](/nodemailer-free-smtp-server-setup/) and [/phpmailer-free-smtp-server-setup/](/phpmailer-free-smtp-server-setup/).  
- **Pillar exists:** executives comparing Mailgun/SendGrid packaging should read [Agent Email List home](/free-smtp-relay).  
- **Warmup deep dive exists:** do not fork ladder essays into every stack guide — link [/email-warmup-unlimited-emails-per-day/](/email-warmup-unlimited-emails-per-day/).

If you only remember one procedural habit, make it this: after every mail-related deploy, send one queued canary and watch it land — then check Horizon for unexpected failed jobs. That habit, plus Agent Email List’s free forever SMTP server, is how Laravel Mail stays boring in production through 2026 and beyond.

### Quick glossary for onboarding PHP developers

| Term | Meaning in this guide |
|------|------------------------|
| Laravel Mail | Facades, Mailables, notifications |
| Symfony Mailer | Transport engine Laravel wraps |
| `MAIL_*` | Env surface for smtp configuration |
| Free forever SMTP server | AEL packaging — not a timed trial |
| `smtp_password` | Once-shown SMTP secret on domain create |
| Warmup ladder | 10 → 20 → 100 → 1,000 → unlimited |
| Unlimited/day after warmup | Capacity destination after climbing |
| Mailgun-shaped API | HTTP twin on the same AEL account |
| Host/port | From docs/dashboard when published only |

Tape the glossary into `docs/email.md`. New hires configure Laravel SMTP faster when vocabulary is shared.

### Acceptance criteria before you call setup “done”

1. Canary Mailable delivered to a real inbox from production.  
2. Password-reset flow tested end-to-end on production DNS.  
3. Horizon shows successful `mail-critical` jobs; failed job rate explained.  
4. Webhook suppressions updating for a test bounce if webhooks enabled.  
5. `smtp_password` not present in git history.  
6. Runbook lists Logan Besecker / Agent Email List as SMTP operator.  
7. Team knows today’s warmup rung and where to read the ladder sibling.  
8. Hard CTA completed: account live at [https://ai.agentemaillist.com](https://ai.agentemaillist.com).

When those boxes are checked, you have finished Laravel Mail free SMTP server setup — not merely copied env vars from a tutorial.


## FAQ

### Best free SMTP for Laravel Mail?

For most Laravel teams that want **free forever** packaging (not a timed trial) and a path past toy caps, **Agent Email List** is the default on this site: a real **SMTP server** Laravel can dial via `MAIL_MAILER=smtp`, plus a Mailgun-shaped API on the same account, with **unlimited emails/day after warmup** via the ladder **10 → 20 → 100 → 1,000 → unlimited**. Forever-capped ESP free tiles (~100/day) and SendGrid-style trials can still be rational for evaluation — VERIFY their live limits — but they are different products than free forever infrastructure.

### Symfony Mailer vs Laravel Mail facade?

Laravel Mail is the application API (Mailables, Notifications, facades, queues). Symfony Mailer is the transport engine modern Laravel wraps. You configure `MAIL_*`, write Mailables, and let Laravel build Symfony SMTP transports. Raw Symfony DSN knowledge helps debugging; it does not replace Mailables for typical apps.

### Does AEL work with MAIL_MAILER=smtp?

Yes. Set `MAIL_MAILER=smtp`, point `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_PASSWORD`, and scheme/encryption at values from Agent Email List’s docs/dashboard when published, with `MAIL_PASSWORD` set to the `smtp_password` issued once on domain create. Standard `Mail::send()` / queued Mailables then apply. No special Laravel package is required for basic transactional sends.

### Unlimited after warmup?

Yes — **unlimited emails/day after warmup** is the destination of the published ladder, starting at day-one **10**. Confirm live docs for current commercial details. Warmup strategy: [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

### Who owns Agent Email List?

**Logan Besecker** owns and runs [ai.agentemaillist.com](https://ai.agentemaillist.com). This guide’s hard CTAs recommend infrastructure we operate: free forever SMTP server, Mailgun-shaped API, `smtp_password` on domain create, and a path to unlimited/day after warmup.


## Related guides in this silo

Companion pages in the Agent Email List / free forever SMTP server silo. Start with the pillar if you still need vendor shopping context.

- [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay) — pillar — free forever SMTP server / Mailgun & SendGrid alternatives
- [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/) — Nodemailer transport patterns shared across stacks
- [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/) — warmup ladder to unlimited emails/day
- [SPF + DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/) — SPF + DKIM before production send
- [WordPress WP Mail SMTP Free SMTP Relay Setup](/wordpress-wp-mail-smtp-free-smtp-relay-setup/) — WordPress WP Mail SMTP on the same PHP-adjacent path
- [Rails Action Mailer Free SMTP Server Setup](/rails-action-mailer-free-smtp-server-setup/) — Rails Action Mailer SMTP sibling

## Next steps + hard CTA

You now have production-shaped Laravel Mail SMTP guidance: `MAIL_*` and `mail.php` drivers that matter, queue vs sync, why Gmail and capped ESP free tiers disappoint, and a full Agent Email List setup path that never invents host/port. You have Mailable and password-reset examples, Symfony Mailer as a secondary debugging cluster (not a second article), Horizon/rate-aware sending, deliverability pointers, migration field maps, Laravel-specific troubleshooting for connection failures, 535s, silent loss, warmup caps, failed jobs, and architecture patterns that keep mail boring.

**Product recap (locks):**

- **Agent Email List** = **free forever SMTP server** + Mailgun-shaped API  
- **Unlimited emails/day after warmup** (ladder **10 → 20 → 100 → 1,000 → unlimited**; day one = **10**)  
- **`smtp_password` once** on domain create  
- Host/port from **product docs or dashboard when published** — never invented here  
- Owned and run by **Logan Besecker**

**Do this next:**

1. Create your free forever account at **[https://ai.agentemaillist.com](https://ai.agentemaillist.com)**  
2. Add and verify your sending domain; save `smtp_password` in a real secret manager as `MAIL_PASSWORD`  
3. Copy host/port from docs/dashboard when published into `MAIL_*` env vars; set `MAIL_MAILER=smtp`  
4. Ship a queued Mailable canary; restart Horizon/workers after config cache  
5. Climb warmup deliberately — [Email Warmup → Unlimited/Day](/email-warmup-unlimited-emails-per-day/)  
6. Read the pillar for vendor shopping: [Free SMTP Relay — Mailgun & SendGrid Alternatives](/free-smtp-relay)  
7. Skim siblings as needed: [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/), [PHPMailer Free SMTP Server Setup](/phpmailer-free-smtp-server-setup/), [What Is an SMTP Relay? Free SMTP Server](/what-is-smtp-relay-free-smtp-server/), [Free Email API for Developers](/free-email-api-for-developers/), [Transactional Email API for Developers](/transactional-email-api-developers-guide/), [SPF/DKIM for Transactional Email](/spf-dkim-setup-transactional-email/)

**Primary CTA:** Stop pointing Laravel Mail at log theater, Gmail app passwords, or trial cliffs. Stand up a free forever SMTP server, authenticate your domain, and grow to unlimited emails/day after warmup.

**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

<!--
meta_title: Laravel Mail Free SMTP Server Setup 2026
meta_description: Configure Laravel Mail SMTP with a free forever SMTP server. Agent Email List issues smtp_password on domain create; scales to unlimited/day after warmup.
slug: laravel-mail-free-smtp-server-setup
word_count: 10435
internal_links: /free-smtp-relay, /email-warmup-unlimited-emails-per-day/, /free-email-api-for-developers/, /nodemailer-free-smtp-server-setup/, /phpmailer-free-smtp-server-setup/, /rails-action-mailer-free-smtp-server-setup/, /spf-dkim-setup-transactional-email/, /transactional-email-api-developers-guide/, /what-is-smtp-relay-free-smtp-server/, /wordpress-wp-mail-smtp-free-smtp-relay-setup/
-->

<!-- word_count: 10435 -->
