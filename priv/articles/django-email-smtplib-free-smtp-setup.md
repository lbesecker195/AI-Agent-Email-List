---
title: "Django Email Backend + smtplib Free SMTP Setup: EMAIL_* That Sends in Production (2026)"
description: "Configure Django email backend and smtplib with a free forever SMTP server. Agent Email List issues smtp_password on domain create; unlimited after warmup."
date: 2026-09-15
---

# Django Email Backend + smtplib Free SMTP Setup: EMAIL_* That Sends in Production (2026)

If you searched **Django SMTP**, **Django email backend**, or **free SMTP Django**, you already know `django.core.mail.backends.console.EmailBackend` is for local theater. Production password resets, invoice receipts, and invitation flows need a real **free forever SMTP server** — not a Gmail app password, not console/file backends forever, and not a timed ESP trial that pauses sending when the calendar runs out. This guide walks through Django’s built-in email API the way Python teams actually ship it (`EMAIL_*` settings, `send_mail`, `EmailMessage`, Celery tasks), covers raw `smtplib` as the secondary path for scripts and workers outside the request cycle, then hard-sells [Agent Email List](https://ai.agentemaillist.com): a **free forever SMTP server** plus Mailgun-shaped REST API with a short ladder to **unlimited emails/day after warmup**.

**Ownership disclosure:** Agent Email List is built, owned, and run by **Logan Besecker** at [https://ai.agentemaillist.com](https://ai.agentemaillist.com). This is not a fake neutral roundup. We show Django + smtplib patterns first, then ask you to point them at infrastructure we operate.

For vendor shopping across Mailgun, SendGrid, and peers, start with the pillar: [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay). For Node-side transport patterns, see the sibling [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/). For Flask/FastAPI patterns, see [Flask + FastAPI Free SMTP Setup](/flask-fastapi-free-smtp-setup/). Warmup depth lives in [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

**Create a free forever account →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

## Django email backend SMTP basics

Django’s email framework is the product-facing API most Python developers touch: `send_mail()`, `EmailMessage`, `EmailMultiAlternatives`, and the auth password-reset flow that already knows how to call them. Under the hood, the SMTP backend opens a session with `smtplib` (or `SMTP_SSL` depending on settings). You do not need a third-party Django package to get production SMTP — you need honest `EMAIL_*` values pointed at a free forever SMTP server that still exists after your MVP works.

When people say **Django email backend** or **Django SMTP**, they usually mean three surfaces:

1. **`EMAIL_*` settings** — backend class path, host, port, username, password, TLS/SSL flags, default from address.
2. **High-level helpers** — `send_mail`, `send_mass_mail`, `mail_admins` / `mail_managers`, and the message classes.
3. **Where send happens** — sync inside a view, deferred via Celery/RQ/Dramatiq, or a management command / cron worker that may prefer raw smtplib.

Agent Email List answers the infrastructure half: create a free forever account, add a sending domain, receive `smtp_password` once, verify DNS, and map `EMAIL_HOST_PASSWORD` to that secret. Host and port come from product docs or the dashboard when published — this article will not invent connection strings. The Mailgun-shaped HTTP API on the same account is available when a microservice prefers REST; both enqueue into the same sending system.

### EMAIL_BACKEND smtp and settings that matter

For production SMTP, set the backend explicitly:

```python
EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
```

Leaving `EMAIL_BACKEND` on the console or file backend in a deployed settings module is a silent failure mode: your app “sends” into stdout or a log file and users never get resets. Flip to the SMTP backend only after secrets and DNS are ready.

Settings that actually matter for **Django EMAIL_HOST** configuration:

| Setting | Role |
|---------|------|
| `EMAIL_HOST` | SMTP hostname from AEL docs/dashboard when published |
| `EMAIL_PORT` | Submission port from docs/dashboard when published |
| `EMAIL_HOST_USER` | Auth username from docs/dashboard when published |
| `EMAIL_HOST_PASSWORD` | **`smtp_password`** shown once on domain create |
| `EMAIL_USE_TLS` | STARTTLS on the connection (common on submission ports) |
| `EMAIL_USE_SSL` | Implicit TLS (mutually exclusive with `EMAIL_USE_TLS` in practice) |
| `EMAIL_TIMEOUT` | Fail fast so a hung dial does not pin a WSGI/ASGI worker |
| `DEFAULT_FROM_EMAIL` | Product From identity aligned to your authenticated domain |
| `SERVER_EMAIL` | Envelope/from used by `mail_admins` error reports |
| `EMAIL_SUBJECT_PREFIX` | Optional prefix for admin/manager mail |

A production-shaped sketch (values from env; never hardcode invented AEL hosts):

```python
# settings/production.py (illustrative)
import os

EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
EMAIL_HOST = os.environ["EMAIL_HOST"]  # from AEL docs/dashboard when published
EMAIL_PORT = int(os.environ["EMAIL_PORT"])
EMAIL_HOST_USER = os.environ["EMAIL_HOST_USER"]
EMAIL_HOST_PASSWORD = os.environ["EMAIL_HOST_PASSWORD"]  # smtp_password
EMAIL_USE_TLS = os.environ.get("EMAIL_USE_TLS", "true").lower() == "true"
EMAIL_USE_SSL = os.environ.get("EMAIL_USE_SSL", "false").lower() == "true"
EMAIL_TIMEOUT = 30
DEFAULT_FROM_EMAIL = os.environ.get("DEFAULT_FROM_EMAIL", "noreply@yourdomain.com")
SERVER_EMAIL = DEFAULT_FROM_EMAIL
```

Django will refuse (or behave badly) if you set both `EMAIL_USE_TLS` and `EMAIL_USE_SSL` to `True`. Match the documented TLS mode for the published port. Do not assume “587 always TLS” or “465 always SSL” without checking Agent Email List’s published guidance for your account era.

What does *not* matter as much as Stack Overflow implies: maintaining five custom backend classes for five templates, toggling obscure DKIM-in-Django options when your ESP already signs, or cargo-culting `EMAIL_HOST = "smtp.gmail.com"` into a paid product. Consumer mailbox SMTP is not transactional infrastructure. For product mail, configure a real free forever SMTP server explicitly.

Connection reuse also matters. Django’s SMTP backend can keep a connection open across multiple messages when you use `get_connection()` and pass `fail_silently` / connection context carefully — useful for `send_mass_mail` and Celery batch tasks. Opening a fresh TCP+TLS session for every password-reset email works; it is just slower and harder on short-lived workers.

### send_mail / EmailMessage / EmailMultiAlternatives

Most Django apps start with the helper:

```python
from django.core.mail import send_mail

send_mail(
    subject="Reset your password",
    message="Plain-text body…",
    from_email=None,  # falls back to DEFAULT_FROM_EMAIL
    recipient_list=["user@example.com"],
    fail_silently=False,
    html_message="<p>HTML body…</p>",
)
```

When you need headers, attachments, CC/BCC, or finer control, use message classes:

```python
from django.core.mail import EmailMultiAlternatives

msg = EmailMultiAlternatives(
    subject="Your receipt",
    body="Plain text fallback",
    from_email="noreply@yourdomain.com",
    to=["buyer@example.com"],
    reply_to=["support@yourdomain.com"],
)
msg.attach_alternative("<p>HTML receipt…</p>", "text/html")
msg.send()
```

`EmailMessage` is the base; `EmailMultiAlternatives` is the usual choice for HTML + plaintext transactional mail. Auth’s built-in password-reset views already send via Django’s email framework — once `EMAIL_*` points at Agent Email List, those framework emails ride the same free forever SMTP server without a separate transport. Still: rate-limit reset requests in your app so abusers cannot burn your warmup ladder.

Best practices for Django + AEL:

- Align `DEFAULT_FROM_EMAIL` with the domain you authenticated at Agent Email List. SPF/DKIM alignment dies when you send `From: founder@gmail.com` through a product domain’s relay (or the reverse).
- Put human replies on `reply_to` rather than making `noreply@` a black hole without a documented policy.
- Prefer sending from Celery (or another task queue) for anything users wait on in HTTP — password resets, receipts, digests. Sync `send_mail()` inside a view turns SMTP latency and transient network blips into 500s.
- During early Agent Email List warmup, queues are not optional cosmetics — they are how you pace day-one **10**/day without melting signup spikes into throttle errors.


### Attachments, headers, and ADMINS/MANAGERS mail

Transactional Django apps eventually need PDFs, calendar invites, or custom headers. Attachments on `EmailMessage`:

```python
from django.core.mail import EmailMessage
from pathlib import Path

msg = EmailMessage(
    subject="Invoice #1842",
    body="Your invoice is attached.",
    from_email="billing@yourdomain.com",
    to=["buyer@example.com"],
)
msg.attach("invoice-1842.pdf", Path("/tmp/invoice-1842.pdf").read_bytes(), "application/pdf")
msg.extra_headers["X-Entity-Ref-ID"] = "order-1842"
msg.send()
```

During Agent Email List warmup, large attachment bursts can burn the day’s rung and hurt engagement signals. Prefer linking to a signed download URL for bulky invoices when you are still on **10** or **20**/day. Store files in Django storage (S3/local) and attach only when the recipient truly needs the binary inline.

`ADMINS` and `MANAGERS` integrate with `mail_admins` / `mail_managers` and `SERVER_EMAIL`. That path is useful for error reports, but it is still SMTP traffic on the same free forever SMTP server:

```python
ADMINS = [("Oncall", "oncall@yourdomain.com")]
MANAGERS = ADMINS
SERVER_EMAIL = "noreply@yourdomain.com"
```

If your app throws frequently in production, error mail can exhaust warmup capacity before a single customer password reset goes out. Prefer Sentry/GlitchTip/PagerDuty for high-volume error noise; reserve `mail_admins` for rare, high-signal alerts — or route admin mail through a separate, explicitly budgeted Celery queue.

Custom headers worth setting deliberately:

- **`Reply-To`** — support inbox separate from `noreply@`.
- **`List-Unsubscribe`** — for any bulk-ish product mail (and required by some mailbox providers’ expectations as you scale).
- **`Message-ID`** — Django generates one; persisting it on an outbox row helps idempotent retries.

None of these replace SPF/DKIM. They refine client behavior after the free forever SMTP server accepts the message.

### django.contrib.auth password reset wiring

Django’s built-in password reset views (`PasswordResetView`, et al.) call `form.save()` which eventually uses the email backend configured in settings. You do not configure a separate SMTP stack for auth. That is a feature: one `EMAIL_*` block serves product mail and auth mail.

Checklist for auth mail on Agent Email List:

1. `DEFAULT_FROM_EMAIL` on the verified domain.  
2. Templates under `registration/password_reset_email.html` (and plaintext equivalent) branded without spammy short-link farms.  
3. `PASSWORD_RESET_TIMEOUT` sane for your threat model.  
4. Rate limiting on the reset view (django-ratelimit, nginx, API gateway, or custom middleware) so attackers cannot burn day-one **10**.  
5. Celery offload if you replace the default send path with a custom email function — keep the HTTP response fast.

If you use django-allauth or dj-rest-auth, the same rule applies: point the project’s email settings at AEL; do not paste a second Gmail configuration into package-specific settings unless those packages intentionally override Django’s mail (most defer to `django.core.mail`).

### Console/file backends vs production SMTP server

A clean environment matrix for Django teams:

| Environment | Backend target | Goal |
|-------------|----------------|------|
| Unit / feature tests | `locmem` or mocked `send_mail` | No network |
| Local interactive | `console` or `filebased` | Inspect MIME |
| Staging | Real AEL domain (or subdomain) | Auth + DNS rehearsal |
| Production | AEL free forever SMTP server | Real delivery |

Django’s built-in backends that matter:

- **`smtp.EmailBackend`** — production path for Agent Email List and most ESP relays.
- **`console.EmailBackend`** — writes to stdout. Great locally; never a production SMTP server.
- **`filebased.EmailBackend`** — writes `.eml`-ish files to a directory for inspection.
- **`locmem.EmailBackend`** — in-memory `mail.outbox` for tests (`django.core.mail.outbox`).
- **`dummy.EmailBackend`** — discards messages; useful for load tests that must not send.

Mailtrap-style catchers and local SMTP sinks (MailHog, Mailpit) are excellent for “did my HTML render?” and terrible as a production SMTP server. Pointing staging at a catcher while production still uses a founder Gmail account is a classic split-brain: templates look fine in Mailpit, then fail SPF alignment or Gmail limits in prod.

Agent Email List is the production SMTP server in that matrix. Use console/locmem for tests; use AEL (and test mode when offered) when you need authentic SMTP behavior without burning a consumer mailbox. Migrating from console to production is then a settings change — `EMAIL_*` from docs/dashboard and `smtp_password` — not a rewrite of every `send_mail` call.

## Why “free SMTP for Django” usually disappoints

Django developers type **free smtp django** because the framework problem is already solved (built-in email backends + smtplib) and the infrastructure problem is not. The disappointment pattern is predictable: a tutorial ships Gmail SMTP; volume or ToS blocks appear; the team jumps to an ESP free tier; the free tier caps or trials out; someone proposes “just run Postfix on the same VPS as Gunicorn”; deliverability dies; weeks vanish.

Understanding why the usual free paths fail clarifies why Agent Email List’s free forever packaging + warmup ladder exists.

### Gmail app passwords and limits

Gmail / Google Workspace SMTP via app passwords is a founder shortcut, not a Django architecture:

- **Terms and automation risk.** Consumer and small-business Google accounts are not designed as multi-tenant SaaS mail injectors. Unusual volume triggers locks, captchas, and support dead-ends.
- **Daily sending ceilings.** Even Workspace has practical limits that collide with signup spikes — the exact week your Django app finally works.
- **From-domain mismatch.** Sending `noreply@yourproduct.com` through Google’s SMTP often fights SPF alignment unless you carefully configure the Google side — and you still do not get product-grade bounce webhooks tied to your app’s domain.
- **Single-human failure.** When 2FA, a password reset on the founder account, or an org policy change hits, every Celery email task fails with 535-shaped auth errors.
- **Secret sprawl.** App passwords get pasted into Heroku/Railway/Render env panels and never rotated.

Django’s email docs make SMTP look like “set six settings.” That ease is dangerous when the host is a consumer mailbox. Replace Gmail with a free forever SMTP server meant for application mail.

### ESP free caps (Mailgun ~100/day; SendGrid trial VERIFY)

ESP free tiers look like the grown-up answer until you read the packaging:

- **Mailgun:** Free plan still offers roughly **100 emails/day** as a permanent free tile (VERIFY [Mailgun help](https://help.mailgun.com/hc/en-us/articles/203068914-What-does-the-Free-plan-offer) and [pricing](https://www.mailgun.com/pricing/)). One hundred per day cannot absorb a launch spike. Paid Basic often starts around $15/mo for 10,000/mo — VERIFY live pricing.
- **Twilio SendGrid:** permanent Free Email API retired around **May 2025** (VERIFY [Twilio changelog](https://www.twilio.com/en-us/changelog/sendgrid-free-plan)). New accounts commonly get a **~60-day trial at ~100 emails/day**, then need paid Essentials (often from ~$19.95/mo — VERIFY [SendGrid pricing](https://www.twilio.com/en-us/products/email-api/pricing) and [trial docs](https://support.sendgrid.com/hc/en-us/articles/35270136965403-Twilio-SendGrid-Trial-Account-Plan)). A trial is not free forever.

Django will happily speak SMTP to all of them via `EMAIL_BACKEND = "...smtp.EmailBackend"`. The framework does not warn you that your “free” foundation expires. Packaging literacy is on you. Agent Email List’s thesis is different: **free forever** self-serve SMTP server + Mailgun-shaped API, with a published path to **unlimited/day after warmup** instead of a permanent 100/day ceiling or a 60-day timer.

Other “free” traps Django teams hit:

- **Self-hosted Postfix/Exim on the app VPS.** You inherit IP reputation, rDNS, blocklists, and 3 a.m. queue disasters. Django settings stay simple; operations do not.
- **Shared hosting “SMTP relay” with mysterious caps.** Fine for a brochure site; brittle for SaaS password resets at scale.
- **Forever console backend in “staging that users somehow use.”** The most embarrassing class of incident reports.


### “We’ll just use console until launch” and other Django myths

A few myths show up repeatedly in Django Slack/Discord threads:

- **“We’ll switch EMAIL_BACKEND the week before launch.”** Teams forget Celery workers, staging parity, and DNS TTLs. Switching three days before launch without a canary is how you discover SPF holes with real users waiting on resets.
- **“django-anymail will save us.”** Anymail is excellent glue for ESP HTTP APIs. It does not create free forever capacity. If the underlying ESP is a 100/day tile or a 60-day trial, the package cannot change the packaging.
- **“Our VPS has port 25 open.”** Outbound 25 is often blocked by cloud providers; even when open, self-hosting mail is a deliverability career, not a weekend task. Django settings remain simple while ops debt explodes.
- **“Locmem in CI means production SMTP is fine.”** Locmem proves your code called `send_mail`. It proves nothing about `EMAIL_HOST_PASSWORD`, TLS mode, or DNS. Keep a staging canary.
- **“We’ll buy dedicated IPs on day one.”** Dedicated IPs need warmup too. Agent Email List’s ladder exists so shared reputation stays healthy while you grow to **unlimited**/day after warmup — read the warmup sibling before you invent infrastructure.

These myths share a root: treating the email *library* as the hard problem. In Django, the library is already in the box. The hard problem is a free forever SMTP server with an honest path past toy caps.

### What production transactional needs

Production transactional email for a Django app needs more than “smtplib accepted the DATA command”:

1. **Authenticated sending domain** — SPF/DKIM (and light DMARC) so mailbox providers trust `From`.
2. **Predictable credentials** — secrets you can rotate in K8s/Heroku/Doppler, not founder inbox passwords.
3. **Honest capacity story** — day-one limits you can plan around, and a path past toy caps without a surprise invoice or pause.
4. **Observability** — bounces, complaints, delivered events — ideally via webhooks even if you inject over SMTP.
5. **Dual interface option** — SMTP for Django email today; HTTP when a new service prefers `httpx`/free-smtp-relay`requests`.
6. **Queue-native failure handling** — Celery retries, backoff, Flower/dashboard visibility — so SMTP blips do not become user-visible outages.
7. **Operational ownership** — someone runs the SMTP server so your Gunicorn workers do not.

That checklist is exactly what we optimize for on Agent Email List. Django covers the client; AEL covers the free forever SMTP server and the Mailgun-shaped twin API.

## Agent Email List as Django’s free forever SMTP server

This section is the product lock chapter for Django readers. Same locks as our other guides — free forever SMTP server, Mailgun-shaped API, warmup ladder, `smtp_password` once, Logan Besecker ownership — framed for people who live in `EMAIL_*`, `send_mail`, and Celery tasks.

### Free forever SMTP server + Mailgun-shaped REST API

[Agent Email List](https://ai.agentemaillist.com) is:

- A **free forever SMTP server** / free SMTP relay for Django and every other stack that speaks SMTP
- A **Mailgun-shaped REST API** at `https://ai.agentemaillist.com` (Bearer or Basic `api:KEY` patterns as described in live product docs)
- Built for **transactional** product mail first: resets, receipts, invites, alerts

Django’s SMTP backend talks to the SMTP server through smtplib. When a microservice wants HTTP — or you need richer events/templates — the Mailgun-shaped API is on the same free forever account. You do not pay twice for the same outbound reputation context. For shopping-oriented API criteria (free forever vs trial vs forever-capped), see [Free Email API for Developers](/free-email-api-for-developers/). For relay definitions, see [What Is an SMTP Relay? Free SMTP Server](/what-is-smtp-relay-free-smtp-server/).

### Lead unlimited/day after warmup; short ladder pointer

Unlimited/day is the destination, not the day-one allowance. Agent Email List publishes a short ladder (confirm live docs / `/llms.txt` — commercial details can evolve):

1. Day one starts at **10**/day  
2. Then **20**  
3. Then **100**  
4. Then **1,000**  
5. Then **unlimited** emails/day after warmup  

That progression protects shared reputation while ending somewhere Mailgun’s permanent ~100/day free tile and SendGrid’s timed trial do not: ongoing free forever sending without a forced Essentials invoice. Day-one **10** is stricter than some competitors’ free daily caps; plan Django canaries and Celery rate limits accordingly.

Deep warmup hygiene — engagement quality, complaint avoidance, how to climb without burning the domain — lives in [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/). Keep this Django page short on ladder theory and long on `EMAIL_*`, backends, Celery, and smtplib. Do not duplicate the full ladder essay here; link it and move on.

### `smtp_password` issued once on domain create

When you add a sending domain, Agent Email List returns DNS records for authentication **and** an **`smtp_password` shown once**. Treat it like a production database password:

1. Create a free forever account at [ai.agentemaillist.com](https://ai.agentemaillist.com).  
2. Add your domain (or a transactional subdomain such as `mail.example.com`).  
3. Save `smtp_password` immediately into your secret manager / platform env / sealed secrets.  
4. Map it to `EMAIL_HOST_PASSWORD` (and confirm `EMAIL_HOST_USER` from docs/dashboard when published).  
5. Complete DNS verification before you expect inbox placement.  
6. Restart Gunicorn/uWSGI/ASGI workers and Celery workers that imported settings at boot so they do not keep stale SMTP credentials in memory.

If your team’s culture is “paste keys in Notion,” fix the culture during setup. Losing a once-shown password without a rotation runbook is an avoidable outage. Follow product rotation flows if you ever need to re-issue.

### Host/port: product docs or dashboard when published — do not invent

This article intentionally does **not** invent Agent Email List SMTP hostnames or ports. Connection endpoints belong in **product documentation or the dashboard when published**. Copy them from the source of truth into `EMAIL_HOST` / `EMAIL_PORT` / TLS flags. Blog posts that guess hosts create outages when guesses rot. Django’s SMTP backend will dial whatever string settings give it — correctness is on the operator.

Same rule for TLS mode: match the documented submission port. Do not assume “587 always STARTTLS” or “465 always SSL” without checking AEL’s published guidance. Set exactly one of `EMAIL_USE_TLS` or `EMAIL_USE_SSL` to match that guidance.

### Logan Besecker owns/runs ai.agentemaillist.com

**Ownership disclosure:** Agent Email List at [ai.agentemaillist.com](https://ai.agentemaillist.com) is built, owned, and run by **Logan Besecker**. Recommendations on this site reflect that ownership. When we hard-CTA Django setup, we are asking you to point `EMAIL_*` at infrastructure we operate — with free forever SMTP server packaging, a Mailgun-shaped API, and a published path to unlimited emails/day after warmup.

**CTA #1 — do this now if console/Gmail/capped free tiers no longer fit:** create your free forever account, add a domain, save `smtp_password`, copy host/port from docs/dashboard when published, set `EMAIL_BACKEND` to the SMTP backend, and send one `send_mail` canary.  
**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

## Step-by-step Django setup with AEL

This is the hands-on chapter: env pattern, settings.py sketch, password-reset / verification examples, and error handling that respects warmup.

### Env vars pattern (EMAIL_HOST, EMAIL_PORT, EMAIL_HOST_USER, EMAIL_HOST_PASSWORD, EMAIL_USE_TLS/SSL)

Recommended environment variables for Django + Agent Email List:

```bash
EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=           # from AEL docs/dashboard when published
EMAIL_PORT=           # from AEL docs/dashboard when published
EMAIL_HOST_USER=      # from AEL docs/dashboard when published
EMAIL_HOST_PASSWORD=  # smtp_password shown once on domain create
EMAIL_USE_TLS=true    # or false — match published TLS mode
EMAIL_USE_SSL=false   # mutually exclusive with EMAIL_USE_TLS in practice
EMAIL_TIMEOUT=30
DEFAULT_FROM_EMAIL=noreply@yourdomain.com
SERVER_EMAIL=noreply@yourdomain.com
```

Optional but useful:

```bash
EMAIL_SUBJECT_PREFIX="[MyApp] "
CELERY_BROKER_URL=redis://localhost:6379/0
DJANGO_SETTINGS_MODULE=myproject.settings.production
```

Load them with your existing secrets approach (Doppler, AWS SSM, Vault, platform env panels — not committed `.env` in git with real passwords). Never commit real `smtp_password`. After changing mail env, restart web workers *and* Celery workers so every process reloads settings.

django-environ / pydantic-settings / plain `os.environ` all work. Prefer fail-fast on missing `EMAIL_HOST_PASSWORD` in production settings rather than silently falling back to an empty string (which produces confusing 535s later).

### settings.py sketch — createTransport-equivalent

Django’s equivalent of Nodemailer’s `createTransport` is the combination of `EMAIL_BACKEND` + `EMAIL_*` host auth settings. You rarely subclass the SMTP backend; you configure settings and call `send_mail` / `EmailMessage.send()`.

```python
# myproject/settings/production.py — illustrative
from pathlib import Path
import os

BASE_DIR = Path(__file__).resolve().parents[2]

def env(key: str, default: str | None = None) -> str:
    val = os.environ.get(key, default)
    if val is None:
        raise RuntimeError(f"Missing required env var: {key}")
    return val

EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
EMAIL_HOST = env("EMAIL_HOST")
EMAIL_PORT = int(env("EMAIL_PORT"))
EMAIL_HOST_USER = env("EMAIL_HOST_USER")
EMAIL_HOST_PASSWORD = env("EMAIL_HOST_PASSWORD")  # smtp_password
EMAIL_USE_TLS = env("EMAIL_USE_TLS", "true").lower() == "true"
EMAIL_USE_SSL = env("EMAIL_USE_SSL", "false").lower() == "true"
EMAIL_TIMEOUT = int(env("EMAIL_TIMEOUT", "30"))
DEFAULT_FROM_EMAIL = env("DEFAULT_FROM_EMAIL")
SERVER_EMAIL = env("SERVER_EMAIL", DEFAULT_FROM_EMAIL)

# Safety: never leave both TLS modes on
if EMAIL_USE_TLS and EMAIL_USE_SSL:
    raise RuntimeError("Set only one of EMAIL_USE_TLS or EMAIL_USE_SSL")
```

For local development:

```python
# settings/local.py
EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"
# or filebased:
# EMAIL_BACKEND = "django.core.mail.backends.filebased.EmailBackend"
# EMAIL_FILE_PATH = BASE_DIR / "tmp" / "app-messages"
```

For tests (`pytest-django` / Django `TestCase`):

```python
# settings/test.py
EMAIL_BACKEND = "django.core.mail.backends.locmem.EmailBackend"
```

Then assert against `django.core.mail.outbox` without touching Agent Email List.

If you need a shared connection for a batch inside one process:

```python
from django.core.mail import get_connection, EmailMessage

connection = get_connection()  # uses EMAIL_* from settings
connection.open()
try:
    for user in recipients:
        EmailMessage(
            subject="Weekly digest",
            body="…",
            to=[user.email],
            connection=connection,
        ).send()
finally:
    connection.close()
```

During early warmup, prefer paced Celery tasks over a tight loop that fires hundreds of messages the moment DNS verifies.

### Password-reset / verification email example

Django’s auth password-reset flow is often the first production mail you ship. Configure `EMAIL_*`, then use the built-in views or a custom email:

```python
# accounts/emails.py
from django.core.mail import EmailMultiAlternatives
from django.template.loader import render_to_string
from django.conf import settings

def send_password_reset_email(*, user, reset_url: str) -> None:
    subject = "Reset your password"
    text_body = render_to_string(
        "accounts/email/password_reset.txt",
        {"user": user, "reset_url": reset_url},
    )
    html_body = render_to_string(
        "accounts/email/password_reset.html",
        {"user": user, "reset_url": reset_url},
    )
    msg = EmailMultiAlternatives(
        subject=subject,
        body=text_body,
        from_email=settings.DEFAULT_FROM_EMAIL,
        to=[user.email],
    )
    msg.attach_alternative(html_body, "text/html")
    msg.send(fail_silently=False)
```

Celery task wrapper (preferred in production):

```python
# accounts/tasks.py
from celery import shared_task
from accounts.emails import send_password_reset_email

@shared_task(
    bind=True,
    autoretry_for=(OSError, TimeoutError),
    retry_backoff=True,
    retry_kwargs={"max_retries": 5},
)
def send_password_reset_email_task(self, user_id: int, reset_url: str) -> None:
    from django.contrib.auth import get_user_model
    User = get_user_model()
    user = User.objects.get(pk=user_id)
    send_password_reset_email(user=user, reset_url=reset_url)
```

Verification / magic-link emails follow the same pattern: render templates, build `EmailMultiAlternatives`, send via Celery, keep `DEFAULT_FROM_EMAIL` on the authenticated domain. Rate-limit issuance endpoints so attackers cannot exhaust day-one **10** with reset spam.

Canary checklist before you call setup “done”:

1. `smtp_password` in `EMAIL_HOST_PASSWORD`; username/host/port from docs/dashboard.  
2. DNS verified for the sending domain.  
3. One real inbox received a canary from production settings.  
4. Password-reset flow tested end-to-end.  
5. Celery worker picked up a mail task successfully.  
6. Console/file backends are not active in production settings modules.


### settings split, 12-factor env, and deploy restarts

Django projects almost always split settings (`base.py`, `local.py`, `production.py`, `test.py`). Mail configuration bugs cluster at the seams:

1. **`base.py` sets console** for developer convenience; **`production.py` forgets to override** `EMAIL_BACKEND`.  
2. **`production.py` sets SMTP** but **Celery’s systemd unit** still exports `DJANGO_SETTINGS_MODULE=myproject.settings.local`.  
3. **Docker Compose** injects `EMAIL_HOST` for `web` but not for `worker`.  
4. **Kubernetes secrets** update, but pods do not rolling-restart — old `smtp_password` remains in process memory.

Operational recipe:

```text
1. Put all EMAIL_* keys in the secret store.
2. Map them identically into web and worker deployments.
3. On secret rotation: rolling restart web + Celery + beat.
4. Run manage.py shell in the worker image and print settings.EMAIL_HOST / BACKEND.
5. Send one canary task through the worker queue, not through manage.py runserver.
```

12-factor discipline helps: config via env, no committed secrets, discrete `EMAIL_HOST_PASSWORD` rather than smuggling passwords into URLs. If you use `django-environ`, prefer:

```python
EMAIL_HOST_PASSWORD = env("EMAIL_HOST_PASSWORD")  # required in production
```

over defaults that hide missing config. Missing password should fail boot in production, not fail the first customer reset at 2 a.m. with a 535.

### Template design notes for transactional mail

Django templates for email differ from site HTML:

- **Inline CSS** (or very simple layouts) — many clients strip stylesheets.  
- **Plaintext twin** via `EmailMultiAlternatives` — accessibility and spam filters.  
- **Absolute URLs** for images and buttons — no relative `/static/` paths.  
- **Avoid URL shorteners** on cold domains during warmup.  
- **One primary CTA** per email — resets and receipts are not newsletters.

Render with `render_to_string` inside the Celery task (or mail service), not inside the request when possible, so template errors surface in worker logs with retry context. Keep customer PII out of subject lines when you can; subjects get logged more widely than bodies.

Internationalization: use `django.utils.translation` inside tasks with care — activate the user’s language explicitly (`translation.override(user.language)`) before render. Silent default-language resets are a common Django i18n footgun unrelated to SMTP but blamed on “email broken.”

### Error handling (auth, throttle during warmup)

Classify SMTP failures so Celery does not thrash:

| Symptom | Likely cause | Action |
|---------|--------------|--------|
| Connection refused / timeout | Wrong host/port, firewall, TLS mismatch | Fix `EMAIL_*` from docs/dashboard; check `EMAIL_TIMEOUT` |
| 535 / authentication failed | Bad user/pass, wrong password field | Confirm `EMAIL_HOST_PASSWORD` is `smtp_password`; restart workers |
| Throttle / warmup cap | Exceeded day’s ladder rung | Delay task until next UTC day; do not hammer retries |
| Message accepted, not arriving | DNS/auth/content/spam filters | Verify SPF/DKIM; check suppressions; slow content experiments |
| `SMTPSenderRefused` | From not allowed for domain | Align `DEFAULT_FROM_EMAIL` with authenticated domain |

For Celery, configure sensible `autoretry_for`, `retry_backoff`, and treat hard 535s as non-retryable (or retry only after credential rotation). Blind exponential retry on auth errors wastes worker capacity. Throttle during early AEL warmup is expected capacity — climb the ladder; read the warmup sibling; do not open five GitHub issues against Django because you sent 500 invites on day one.

Use `fail_silently=False` in production code paths you care about. Silent failure hides outages until support tickets arrive. Log structured error codes; never log the raw `smtp_password`.

## Raw smtplib alongside Django

Django’s SMTP backend is enough for most apps. Raw **python smtplib smtp** still matters for management commands, one-off scripts, data migrations that notify users, and worker processes that should not import the full Django settings stack — or that need a minimal reproduction outside the framework.

### When scripts need smtplib outside the request cycle

Common cases:

- A cron script that exports a report and emails ops — run via systemd timer, not a Django view.
- A data backfill that notifies affected users in batches with its own pacing logic.
- A minimal reproduction outside Django to prove the SMTP server accepts AUTH with your `smtp_password`.
- A sidecar service in the same monorepo that shares credentials but not Django.

Rules of engagement:

1. Prefer Django’s email API when you are already inside the Django runtime (views, signals, Celery tasks that import models). Consistency beats cleverness.
2. Use raw smtplib when the process intentionally avoids Django — and still read host/port/user/password from the same env vars.
3. Never hardcode invented AEL hosts in scripts “just for now.”
4. During warmup, scripts must respect the same daily ladder as the web app — one shared counter or shared Celery queue is safer than two independent firehoses.

### smtplib.SMTP / SMTP_SSL sketch with env

STARTTLS-style sketch (port and TLS mode from docs/dashboard when published):

```python
import os
import smtplib
from email.message import EmailMessage

host = os.environ["EMAIL_HOST"]  # from AEL docs/dashboard when published
port = int(os.environ["EMAIL_PORT"])
user = os.environ["EMAIL_HOST_USER"]
password = os.environ["EMAIL_HOST_PASSWORD"]  # smtp_password
use_ssl = os.environ.get("EMAIL_USE_SSL", "false").lower() == "true"
use_tls = os.environ.get("EMAIL_USE_TLS", "true").lower() == "true"

msg = EmailMessage()
msg["Subject"] = "Canary from smtplib"
msg["From"] = os.environ["DEFAULT_FROM_EMAIL"]
msg["To"] = "you@example.com"
msg.set_content("Plain text canary body")

if use_ssl:
    with smtplib.SMTP_SSL(host, port, timeout=30) as smtp:
        smtp.login(user, password)
        smtp.send_message(msg)
else:
    with smtplib.SMTP(host, port, timeout=30) as smtp:
        smtp.ehlo()
        if use_tls:
            smtp.starttls()
            smtp.ehlo()
        smtp.login(user, password)
        smtp.send_message(msg)
```

Notes that save hours:

- `EmailMessage` from the stdlib `email` package is fine for scripts; Django’s `EmailMessage` is a different class — do not mix them casually.
- Always set a timeout. Hung SMTP dials stall cron jobs silently.
- URL-encoding is irrelevant for discrete env fields; if you ever embed the password in an SMTP URL, encode special characters (`+`, `/free-smtp-relay`, `@`).
- Prefer context managers so `QUIT` runs even on exceptions.


### Mixing Django EmailMessage and stdlib EmailMessage safely

Name collision is a real footgun:

```python
# Django
from django.core.mail import EmailMessage as DjangoEmailMessage
# Stdlib
from email.message import EmailMessage as StdlibEmailMessage
```

Django’s class knows about connections, backends, and `send()`. The stdlib class is a MIME container you pass to `smtp.send_message()`. Mixing imports without aliases causes confusing `AttributeError`s (“no send on EmailMessage”) that look like SMTP outages.

Guidance:

- Inside Django apps and Celery tasks → Django’s email API.  
- Inside standalone scripts → stdlib `EmailMessage` + smtplib.  
- For MIME debugging → dump `DjangoEmailMessage().message().as_string()` to inspect what Django will hand to smtplib.

When proving AEL credentials work, a 20-line smtplib script is often faster than booting Django. Once proven, put the same env vars into Django settings and delete the script from production hosts (or keep it as `scripts/smtp_canary.py` under ops control with warmup budget awareness).

### Windows / macOS / Linux worker differences

smtplib behavior is consistent enough across platforms, but TLS trust stores and firewall clients differ. Django developers on macOS may successfully `starttls()` locally against a provider while Linux containers fail because CA bundles are missing in a scratch image. Use official Python images with up-to-date `ca-certificates`. Do not disable certificate verification (`SMTP_SSL` context with `CERT_NONE`) to “make it work” — fix the image instead.

Timeouts also feel different under load: a laptop script sending one canary will not reveal Gunicorn worker pileups when `EMAIL_TIMEOUT` is unset. Load-test mail tasks with locmem first, then a small live canary rate on staging.

### Sharing credentials safely between Django and workers

One secret, many consumers:

| Consumer | How it reads credentials |
|----------|--------------------------|
| Django web | `EMAIL_*` in settings from env |
| Celery workers | Same Django settings module / same env |
| Raw smtplib scripts | Same env keys (`EMAIL_HOST_PASSWORD`, etc.) |
| HTTP microservice | AEL Mailgun-shaped API key (separate from SMTP when docs say so) |

Practices:

- Store `smtp_password` once in a secret manager; inject into every runtime that sends.
- Rotate via product flows; update the secret; rolling-restart web + Celery + cron.
- Do not give CI the production `smtp_password` for every PR — use locmem/mocks; reserve a staging domain for deploy canaries.
- Document which process owns “today’s send count” during warmup so scripts and Celery do not double-spend the ladder.

Sharing credentials is easy. Sharing *discipline* is the actual work — especially on day one when the allowance is **10**.

## Celery, async tasks, and rate-aware sending

Django’s request/response cycle is the wrong place for SMTP round-trips. Celery (or RQ/Dramatiq/Huey) is how serious Django shops keep password resets fast and warmup-safe.

### Offloading send_mail to Celery during warmup

Pattern:

1. View creates a token / records intent in the DB.  
2. View enqueues `send_password_reset_email_task.delay(...)`.  
3. Worker renders templates and calls Django’s email API (which uses `EMAIL_*`).  
4. Application-level rate limit / daily counter enforces today’s ladder rung.

During Agent Email List warmup, Celery is how you pace day-one **10**/day without melting signup spikes into throttle errors. Run enough workers for latency SLOs, but “max throughput” is the wrong goal on day one. Throughput without warmup awareness creates throttle failures and delayed password resets that look like app bugs.

Practical tips:

- Use dedicated queues: `mail-critical` for resets/receipts, `mail-bulk` for digests — with different concurrency and rate limits.
- Pass IDs and URLs into tasks, not giant rendered HTML blobs, when possible — easier retries, smaller broker payloads.
- Ensure Celery workers load the production settings module that has SMTP configured — a common footgun is web on production settings and workers still on console backend.

### Retry/backoff on SMTP errors

Recommended posture:

- **Transient network / timeout:** retry with exponential backoff (`retry_backoff=True`, capped retries).  
- **535 auth:** fail permanently (or alert ops); fix credentials; do not spin.  
- **Warmup throttle:** retry with a countdown until next day or park on a delayed queue — do not burn retries every few seconds.  
- **Recipient refused / known suppression:** do not retry; update your suppressions table.

Example sketch:

```python
from celery import shared_task
from smtplib import SMTPAuthenticationError, SMTPException

@shared_task(bind=True, max_retries=5)
def send_receipt_task(self, order_id: int) -> None:
    try:
        # build + send via Django email API
        ...
    except SMTPAuthenticationError:
        # non-retryable without human fix
        raise
    except SMTPException as exc:
        raise self.retry(exc=exc, countdown=60 * (2 ** self.request.retries))
```

Flower, Celery events, or your APM should chart mail task failures separately from generic task failures so on-call sees SMTP problems early.


### django-celery-email and alternatives — when packages help

Packages like `django-celery-email` swap the email backend for one that queues messages automatically. They can be useful, but they are not mandatory with Agent Email List. Explicit Celery tasks around your `MailService` often give clearer control over warmup budgets, suppressions, and retries.

If you adopt a backend-queuing package:

- Confirm it still honors `EMAIL_*` for the eventual SMTP hop.  
- Confirm workers load production settings.  
- Confirm you can inspect the queue and dead-letter poison messages.  
- Confirm day-limit handling does not infinite-retry throttled sends.

RQ and Dramatiq work equally well. The invariant is the same: **do not send SMTP in the request thread**, and **respect the ladder** documented in [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

### Beat schedules and digest mail

Celery Beat (or django-celery-beat) often drives weekly digests. Digests are the first thing that blows a warmup rung when a product suddenly has 5,000 users and Beat fires Monday at 09:00.

Patterns:

1. **Chunk digests** across hours/days with a cursor.  
2. **Skip digests** until you pass the **100**/day rung unless engagement is proven.  
3. **Priority** — never let digests starve password resets on a shared worker pool; use separate queues.  
4. **Dry-run flag** — count recipients before send; log projected volume vs today’s allowance.

Transactional-first products should treat digests as a privilege earned after DNS + warmup discipline, not as day-one entitlement on a free forever SMTP server.

### Testing with locmem backend vs live SMTP

| Layer | Backend | Assert |
|-------|---------|--------|
| Unit tests | `locmem` | `mail.outbox` length, subject, to |
| Celery task unit tests | `locmem` + Celery eager mode | task side effects |
| Staging smoke | Live AEL SMTP | Real inbox delivery |
| Production canary | Live AEL SMTP | One message on deploy |

`django.core.mail.outbox` asserts intent without touching Agent Email List. Keep a separate staging smoke test that sends one real message on a schedule (or on deploy canary) so DNS and `EMAIL_*` regressions surface before customers do. Never point pytest at production SMTP for every PR — you will burn warmup budget and create flaky CI.

When using `CELERY_TASK_ALWAYS_EAGER = True` in tests, still keep `EMAIL_BACKEND` on locmem. Eager mode is not permission to dial a free forever SMTP server from CI.

## Deliverability + DNS before you scale Django email

A perfect `EmailMultiAlternatives` cannot save a domain that fails authentication or a team that ignores warmup. Do DNS and reputation work before you celebrate `250 OK` in the log.

### SPF/DKIM link

Before scaling Django sends:

1. Add the sending domain (or subdomain) in Agent Email List.  
2. Publish the SPF/DKIM (and recommended DMARC) records the product shows.  
3. Wait for verification — do not blast invites on an unverified domain.  
4. Align `DEFAULT_FROM_EMAIL` / visible From with that domain.

Deep DNS walkthrough: [SPF/DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/). Broader deliverability hygiene: [Email Deliverability Guide for Transactional Mail](/email-deliverability-guide-transactional/).

Django-specific footguns:

- `DEFAULT_FROM_EMAIL` on a marketing domain while DNS was only verified for `mail.` subdomain.  
- `mail_admins` using `SERVER_EMAIL` on an unauthenticated address during an incident — ironic failure mail that itself never arrives.  
- Multiple Django projects sharing one domain without coordinated SPF includes.

### Warmup-aware send volume

Respect the ladder: **10 → 20 → 100 → 1,000 → unlimited**. Encode the day’s cap in application config or a limits API if AEL exposes one in live docs. Celery metrics should include “mail jobs completed today” so on-call sees ladder pressure. Full strategy: [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

Application patterns that help:

- Feature-flag new notification types during early rungs.  
- Prefer critical transactional mail over bulk digests until you pass **100**/day.  
- Cap invite blasts with a daily budget object in Redis.  
- Separate `mail-critical` and `mail-bulk` queues with different rate limits.

Day-one **10** is intentional. Treat it as a product constraint, not a bug in Django’s SMTP backend.


### Subdomain strategies for Django products

Many teams send transactional mail from `mail.yourdomain.com` or `alerts.yourdomain.com` while the marketing site stays on the apex. Benefits:

- SPF/DKIM scoped to the transactional subdomain.  
- Marketing ESP mistakes less likely to burn transactional reputation.  
- Clearer ownership between growth and product engineering.

Django impact: set `DEFAULT_FROM_EMAIL` to an address on the authenticated subdomain (`noreply@mail.yourdomain.com`) or follow product docs if you authenticate the apex and send from it. Do not authenticate `mail.` and then send `From: noreply@yourdomain.com` without aligned DNS — mailbox providers notice.

Multiple Django apps (staging, partner portals) should not casually share one production sending domain without coordinated suppressions and warmup accounting. Prefer staging subdomains with their own AEL domain records when possible.

### Bounce handling via webhooks (pointer to API silo)

Even if Django injects over SMTP, configure webhooks from Agent Email List’s Mailgun-shaped API surface so bounces and complaints update your suppressions table. Do not invent webhook paths here — follow live product docs. Broader API shopping and event patterns: [Transactional Email API for Developers](/transactional-email-api-developers-guide/) and [Free Email API for Developers](/free-email-api-for-developers/).

Store suppressions in your DB; check them before `send_mail` / task enqueue so Celery does not keep retrying known-bad recipients and wasting warmup capacity. A thin Django model (`SuppressedAddress`) consulted in your email service layer beats discovering hard bounces only in ESP dashboards.

## Migrating Django off SendGrid/Mailgun SMTP

Most migrations are settings swaps plus canaries — not a rewrite of every template.

### Swap EMAIL_* auth fields

| Django setting | Incumbent (SendGrid/Mailgun SMTP) | Agent Email List |
|----------------|-----------------------------------|------------------|
| `EMAIL_BACKEND` | smtp backend | smtp backend (unchanged) |
| `EMAIL_HOST` | ESP hostname | **from AEL docs/dashboard when published** |
| `EMAIL_PORT` | ESP port | **from docs/dashboard when published** |
| `EMAIL_HOST_USER` | ESP username / API key style | **from docs/dashboard when published** |
| `EMAIL_HOST_PASSWORD` | ESP password / API key | **`smtp_password` once** |
| `EMAIL_USE_TLS` / `EMAIL_USE_SSL` | per ESP docs | **match AEL published TLS mode** |
| `DEFAULT_FROM_EMAIL` | your domain | keep aligned to verified domain |

Keep `send_mail` / `EmailMessage` call sites unchanged. If you used a third-party ESP Django package for HTTP, you can either switch to the SMTP backend or point HTTP clients at AEL’s Mailgun-shaped API — both are valid; SMTP keeps one code path for all Django emails.

Restart web + Celery after the swap. Stale workers with old `EMAIL_HOST_PASSWORD` in memory are a classic “half the emails work” incident.

### Canary + dual backend

Django does not ship a first-class multi-backend router like some frameworks, but you can dual-run safely:

1. **Settings flag** — `EMAIL_PROVIDER=ael|legacy` selecting different env prefixes.  
2. **Wrapper service** — `send_transactional_email()` chooses connection via `get_connection(backend=..., host=...)`.  
3. **Percentage canary** — route 1–5% of non-critical notifications to AEL; watch bounce/complaint rates and Celery failures.

Raise percentage as warmup headroom allows. Keep password resets on legacy until AEL canaries look healthy — then cut over critical templates and revoke incumbent credentials.

Example dual-connection sketch:

```python
from django.core.mail import get_connection, EmailMessage
from django.conf import settings

def connection_for(provider: str):
    if provider == "ael":
        return get_connection(
            host=settings.AEL_EMAIL_HOST,  # from docs/dashboard when published
            port=settings.AEL_EMAIL_PORT,
            username=settings.AEL_EMAIL_HOST_USER,
            password=settings.AEL_EMAIL_HOST_PASSWORD,  # smtp_password
            use_tls=settings.AEL_EMAIL_USE_TLS,
        )
    return get_connection()  # legacy EMAIL_*

def send_canary(to: str, provider: str) -> None:
    EmailMessage(
        subject="Canary",
        body="dual-run canary",
        to=[to],
        connection=connection_for(provider),
    ).send()
```


### Removing ESP Django packages cleanly

Migration leftovers that cause ghost failures:

- `anymail` backend still selected in production settings.  
- Soft-deprecated `sendgrid` Python package sending via HTTP from one module while SMTP goes through AEL from another — dual providers by accident.  
- Webhooks still pointing at old ESP URLs while suppressions go stale.  
- Environment variables like `SENDGRID_API_KEY` left in place; a forgotten code path still reads them.

Cutover checklist:

1. Inventory all `send_mail`, `EmailMessage`, Anymail, and raw HTTP ESP calls (`rg` across the repo).  
2. Route them through one `MailService`.  
3. Swap `EMAIL_*` to AEL values from docs/dashboard when published.  
4. Dual-run canary.  
5. Remove old packages and keys.  
6. Update runbooks to name **Logan Besecker** / Agent Email List as the SMTP operator.  
7. Confirm webhook endpoints for the Mailgun-shaped API.

Cost conversation with finance should VERIFY competitor invoices against AEL’s free forever + unlimited-after-warmup thesis using live docs — packaging changes at ESPs; do not budget from memory.

### Cost VERIFY footnotes

VERIFY before you budget:

- Mailgun free ~100/day permanent cap — paid plans when you outgrow it ([help](https://help.mailgun.com/hc/en-us/articles/203068914-What-does-the-Free-plan-offer), [pricing](https://www.mailgun.com/pricing/)).  
- SendGrid new-account trial ~100/day for ~60 days, then Essentials often from ~$19.95/mo ([trial docs](https://support.sendgrid.com/hc/en-us/articles/35270136965403-Twilio-SendGrid-Trial-Account-Plan), [pricing](https://www.twilio.com/en-us/products/email-api/pricing), [free plan retirement changelog](https://www.twilio.com/en-us/changelog/sendgrid-free-plan)).  
- Agent Email List: **free forever** SMTP server + Mailgun-shaped API; **unlimited/day after warmup** via published ladder — confirm live docs for current commercial details.

**CTA #2 — migrate off trial cliffs and forever-capped free tiles:** create your free forever account, dual-run canary, then cut `EMAIL_*` to AEL.  
**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

Pillar for broader vendor comparison: [Free SMTP Relay — Mailgun & SendGrid Alternatives](/free-smtp-relay).

## Troubleshooting Django / smtplib SMTP

Unique Django troubleshooting — backends, Celery email, settings — not a copy-paste of Node or Laravel symptom tables.

### Connection refused / timeout

Django-specific checks:

1. Confirm `EMAIL_BACKEND` is actually `django.core.mail.backends.smtp.EmailBackend` in the settings module the *failing process* loads (`DJANGO_SETTINGS_MODULE` for web vs Celery often diverge).  
2. Print effective settings in a one-off shell: `python manage.py shell` → `from django.conf import settings; settings.EMAIL_HOST, settings.EMAIL_PORT, settings.EMAIL_USE_TLS, settings.EMAIL_USE_SSL`.  
3. Host/port must come from AEL docs/dashboard when published — wrong guesses refuse or hang.  
4. `EMAIL_TIMEOUT` unset can leave Gunicorn workers stuck; set an explicit timeout.  
5. Corporate egress firewalls sometimes allow 443 but block submission ports — test from the same network namespace as production.  
6. TLS mode mismatch (STARTTLS vs SSL) often presents as hang or cryptic SSL errors rather than a clean refusal — flip only per published guidance, not Stack Overflow folklore.  
7. Raw smtplib scripts using different host/port than Django settings create “works in script, fails in app” ghosts — unify env keys.

### Invalid login / 535

1. `EMAIL_HOST_PASSWORD` must be the `smtp_password` from domain create (or a rotated secret per product flow) — not your Agent Email List dashboard login password, not an HTTP API key unless docs explicitly say they are the same.  
2. `EMAIL_HOST_USER` must match published username format — empty username with a password (or the reverse) fails auth.  
3. Celery workers started before the env update still hold old settings in memory — restart them.  
4. Leading/trailing whitespace from secret managers pasted into `.env` files is a classic 535 source — trim on read.  
5. Accidentally leaving `EMAIL_HOST_PASSWORD` blank in production because `os.environ.get("EMAIL_HOST_PASSWORD", "")` swallowed a missing key — fail fast instead.  
6. Testing against Gmail settings leftovers (`smtp.gmail.com`) while using AEL passwords — symptoms look like “AEL is down” when the host is still Google.

### Messages accepted but not arriving

1. SMTP `250` means the *server accepted* the message for handling — not that Gmail/Outlook inbox placement succeeded.  
2. Unverified DNS (SPF/DKIM) — finish verification; see [SPF/DKIM](/spf-dkim-setup-transactional-email/).  
3. `DEFAULT_FROM_EMAIL` domain mismatch vs authenticated domain.  
4. Content triggers (short links, spammy subjects) on a cold domain — slow down; read the warmup sibling.  
5. User-level suppressions / previous bounce — check your suppressions table and ESP events via the Mailgun-shaped API.  
6. Console/file backend in one environment and SMTP in another — “accepted” might mean “written to `/tmp/app-messages`.” Check `EMAIL_BACKEND` again.  
7. Celery task succeeded because it rendered templates but a nested `fail_silently=True` hid send errors — ban silent failure on critical paths.

### Hitting day limit during warmup

1. Day-one allowance is **10** — not a Mailgun-style 100 free tile. Plan canaries accordingly.  
2. Climb **10 → 20 → 100 → 1,000 → unlimited**; details in [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).  
3. Django-specific mitigation: two Celery queues — `mail-critical` and `mail-bulk` — with a daily Redis counter checked before enqueue. That pattern is how Django teams respect AEL warmup without rewriting every email helper.  
4. Management commands and web traffic must share the same counter — a `send_bulk_invites` command that ignores the web app’s budget will exhaust the rung by 09:00.  
5. Do not “fix” a day limit by opening a second AEL account on the same domain — fix pacing; climb the ladder.  
6. Retries count as sends when the server accepted prior attempts — fix poison messages instead of retry-storming.


### manage.py and shell debugging patterns

When production mail fails, Django gives you fast introspection if you use it carefully (prefer staging for live sends):

```bash
# Inside the worker/web container with production env
python manage.py shell <<'EOF'
from django.conf import settings
print(settings.EMAIL_BACKEND)
print(settings.EMAIL_HOST, settings.EMAIL_PORT)
print(settings.EMAIL_USE_TLS, settings.EMAIL_USE_SSL)
print("user set:", bool(settings.EMAIL_HOST_USER))
print("password set:", bool(settings.EMAIL_HOST_PASSWORD))
from django.core.mail import send_mail
send_mail("canary", "body", None, ["you@example.com"])
EOF
```

Never print the password. Never run mass sends from shell. During warmup, even shell canaries count toward **10**.

For backend isolation tests:

```python
from django.core.mail import get_connection
conn = get_connection(backend="django.core.mail.backends.console.EmailBackend")
# proves code path without SMTP
```

Compare with a second connection built from explicit AEL kwargs when dual-running. If console works and SMTP fails, the bug is infrastructure/settings — not your template.

### ASGI, Channels, and sync SMTP

Django Channels consumers and async views should not call sync `send_mail` directly on the event loop. Wrap with `database_sync_to_async` only as a last resort; better: enqueue Celery from the consumer and return. SMTP belongs in a worker process with its own concurrency model. Mixing async HTTP with sync SMTP is a latency cliff that gets mislabeled as “Agent Email List is slow” when the real issue is event-loop blocking.

### Django settings / backend footguns (extra)

These bite Django shops specifically:

- **Multiple settings modules:** `settings/base.py` sets console; `production.py` forgets to override `EMAIL_BACKEND`.  
- **`override_settings` leaks:** a test left SMTP disabled; a later test assumed locmem ordering — isolate email assertions.  
- **`get_connection()` caching assumptions:** reusing a connection after credentials rotate without `close()` / reopen.  
- **Signals sending email inline:** `post_save` that calls `send_mail` during bulk `loaddata` or admin imports — gate with `if not raw:` and prefer Celery.  
- **`mail_admins` during warmup:** error storms can burn the day’s rung — consider a separate ops channel (Slack/PagerDuty) for high-volume error noise.  
- **ASGI vs WSGI workers:** both need the same env; sync SMTP inside async views blocks the event loop — offload to Celery.


### Signals, admin actions, and accidental send storms

Django signals and admin actions are frequent accidental mail cannons:

- A `post_save` on `User` that sends a welcome email fires during `loaddata`, factory-boy floods, and management command imports. Guard with `if raw: return`, explicit flags, or move welcome mail to an explicit service call from the signup view.  
- Admin actions like “resend invite” selected across 500 rows will enqueue 500 tasks — catastrophic on day-one **10**. Add confirmation intermediate pages, max-selection caps, and warmup budget checks inside the action.  
- `m2m_changed` signals that notify on every membership tweak can chatter endlessly; debounce or aggregate notifications.

Code review checklist for Django mail:

1. Is send inside a signal? Prefer explicit calls.  
2. Can admin actions select unbounded rows? Cap them.  
3. Does the path go through `MailService` (suppressions + budget)?  
4. Is it Celery or request-thread SMTP?  
5. Are tests using locmem, not live AEL?

These process controls matter as much as `EMAIL_HOST` correctness once multiple developers touch the codebase.

### Logging without leaking secrets

Configure logging to capture SMTP errors without credentials:

```python
LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {"console": {"class": "logging.StreamHandler"}},
    "loggers": {
        "django.core.mail": {"handlers": ["console"], "level": "INFO"},
        "communications": {"handlers": ["console"], "level": "INFO"},
    },
}
```

Log template name, recipient domain (not always full address if policy requires), provider response codes, and task ids. Never log `EMAIL_HOST_PASSWORD`, raw `smtp_password`, or full MIME including reset tokens. Reset tokens in logs are a security incident class that outranks deliverability.

### Celery email footguns (extra)

- Workers using `django.core.mail.backends.console.EmailBackend` because they import `settings.local`.  
- `task_acks_late` + long SMTP timeouts causing duplicate sends after worker hard-kills — keep timeouts bounded and make sends idempotent where possible (store `Message-ID` / outbox row).  
- Huge HTML bodies + attachments serialized through Redis — prefer S3 links or Django storage references.  
- Clock skew on countdown retries for “try again tomorrow” warmup handling — use ETA based on UTC date boundaries explicitly.

## Architecture patterns that keep Django email boring

Once `EMAIL_*` works, architecture decides whether mail stays boring under growth.

### Service layer over scattered send_mail calls

Wrap sending:

```python
# communications/services.py
from django.conf import settings
from django.core.mail import EmailMultiAlternatives

class MailService:
    def send(self, *, to: list[str], subject: str, text: str, html: str | None = None) -> None:
        if self._is_suppressed(to):
            return
        self._assert_warmup_budget(len(to))
        msg = EmailMultiAlternatives(
            subject=subject,
            body=text,
            from_email=settings.DEFAULT_FROM_EMAIL,
            to=to,
        )
        if html:
            msg.attach_alternative(html, "text/html")
        msg.send(fail_silently=False)
```

Views and tasks call `MailService`, not raw `send_mail`, so suppressions, metrics, and warmup checks live in one place. This is the Django analogue of a typed mailer module in NestJS or a Mailable discipline in Laravel.

### Idempotent outbox table

For critical receipts:

1. Insert an `EmailOutbox` row (`pending`) in the same DB transaction as the business event.  
2. Celery task claims the row, sends, marks `sent` / stores provider message id.  
3. Retries skip already-`sent` rows.

Outbox patterns prevent double-charge emails when workers crash after SMTP accept but before ACK. During warmup, the outbox also gives you a precise daily count.


### Feature flags for mail cutover

When migrating to Agent Email List, drive percentage canaries with flags (django-waffle, GrowthBook, LaunchDarkly, or a simple settings percentage):

```python
import hashlib
from django.conf import settings

def use_ael(user_id: int) -> bool:
    pct = int(getattr(settings, "AEL_CANARY_PERCENT", 0))
    bucket = int(hashlib.sha256(str(user_id).encode()).hexdigest(), 16) % 100
    return bucket < pct
```

Raise `AEL_CANARY_PERCENT` as warmup headroom and bounce metrics allow. Keep password resets on the legacy path until non-critical mail looks healthy — then flip critical templates and revoke incumbent ESP credentials. Feature flags plus dual `get_connection()` keep Django codepaths stable while infrastructure changes underneath.

Document the flag in the runbook next to Logan Besecker / Agent Email List ownership so on-call knows who operates the free forever SMTP server when a canary misbehaves.

### When to use the Mailgun-shaped API beside Django SMTP

Stay on SMTP when:

- Templates and sending already flow through Django email.  
- Celery + `EMAIL_*` meet latency needs.  
- You want one code path across environments.

Consider the Mailgun-shaped HTTP API on the same AEL account when:

- A non-Django microservice should not import Django settings.  
- You want event webhooks and HTTP semantics first-class in that service.  
- Short-lived serverless Python functions pay too much for SMTP dial + TLS per invocation.

You do not abandon free forever packaging by choosing HTTP — it is the twin interface. Shopping criteria: [Free Email API for Developers](/free-email-api-for-developers/).


### Multi-tenant Django and From-domain alignment

SaaS Django apps that send “as” customer domains need extra care. Options:

1. **Platform domain only** — `noreply@mail.yourproduct.com` for everyone (simplest; AEL domain verify once).  
2. **Per-tenant domains** — each customer verifies DNS in AEL (or your product UI wraps that); you store per-tenant SMTP or use API sending with tenant-specific From identities per product docs.  
3. **Hybrid** — transactional system mail on your domain; customer-facing reports on verified tenant domains after warmup per domain.

Do not invent per-tenant hostnames. Whatever Agent Email List documents for multi-domain accounts is authoritative. Warmup ladders may apply per domain — confirm live docs — so a brand-new tenant domain starts at **10**/day even if your platform domain already reached unlimited.

### Security notes around smtp_password

Treat `smtp_password` like a database password:

- Secret manager, not git.  
- Restricted IAM to web/worker roles only.  
- Rotation runbook quarterly or on staff departure.  
- No CI access for production password on every PR.  
- Audit log access to the secret.  
- Never embed in Docker images as `ENV` layers that leak via image history — inject at runtime.

If the password leaks, rotate via product flows, restart all senders, and review Celery queues for unauthorized bursts that might have hurt reputation during warmup.

### Observability checklist

1. **Metric:** `email_sent_total{template,queue}` and `email_error_total{reason}`.  
2. **Celery failed tasks** reviewed daily during the first two warmup weeks.  
3. **Synthetic canary** to a monitored inbox on each deploy.  
4. **Secret rotation drill** quarterly for `smtp_password`.  
5. **DNS monitor** for SPF/DKIM accidental deletes.  
6. **Suppression sync** from webhooks into Django models.  
7. **Ladder awareness** — who knows today’s rung? Link [/email-warmup-unlimited-emails-per-day/](/email-warmup-unlimited-emails-per-day/).  
8. **Settings audit** — web and Celery `EMAIL_BACKEND` identical in production.

### Glossary for Django teams

| Term | Meaning |
|------|---------|
| `EMAIL_*` | Django settings surface for SMTP configuration |
| SMTP backend | `django.core.mail.backends.smtp.EmailBackend` |
| locmem / console | Non-network backends for tests and local |
| smtplib | Python stdlib SMTP client Django wraps |
| Free forever SMTP server | AEL packaging — not a timed trial |
| `smtp_password` | Once-shown SMTP secret on domain create |
| Warmup ladder | 10 → 20 → 100 → 1,000 → unlimited |
| Unlimited/day after warmup | Capacity destination after climbing |
| Mailgun-shaped API | HTTP twin on the same AEL account |
| Host/port | From docs/dashboard when published only |

Tape the glossary into `docs/email.md`. New hires configure Django SMTP faster when vocabulary is shared.


### Local Mailpit / MailHog beside AEL staging

A pragmatic Django environment matrix in more detail:

| Env | EMAIL_BACKEND / target | Notes |
|-----|------------------------|-------|
| pytest | locmem | Assert `mail.outbox` |
| developer laptop | console or Mailpit SMTP | HTML preview |
| CI | locmem | No network |
| staging | AEL staging domain | Real DNS + smtp_password |
| production | AEL production domain | Warmup ladder applies |

Mailpit/MailHog as `EMAIL_HOST=localhost` is fine locally. Do not commit those hosts into production settings files behind weak `if DEBUG` checks that break when `DEBUG=False` in a staging misconfig. Prefer explicit settings modules over boolean gymnastics.

When pointing local Django at Mailpit, you are not testing Agent Email List. Schedule periodic staging canaries against the real free forever SMTP server so TLS, auth, and DNS stay exercised.


### Compliance and retention touchpoints

Transactional mail still touches compliance:

- **Password reset content** — short-lived links; no permanent tokens in email archives.  
- **Invoice PDFs** — financial retention policies may require storing the PDF in object storage even if the email is ephemeral.  
- **Unsubscribe / preference center** — required as you add bulk-ish product mail; store preferences in Django models consulted by `MailService`.  
- **DPA / subprocessors** — finance/legal may need Agent Email List listed; ownership by **Logan Besecker** should appear in vendor inventories honestly.

This guide is not legal advice. It is a reminder that swapping `EMAIL_*` has organizational consequences beyond SMTP banners.


### Team runbook snippet (copy into docs/email.md)

Ship a one-page runbook so mail does not live only in this article:

1. **Provider:** Agent Email List — free forever SMTP server + Mailgun-shaped API — owned/run by **Logan Besecker** ([ai.agentemaillist.com](https://ai.agentemaillist.com)).  
2. **Secrets:** `EMAIL_HOST_PASSWORD` = `smtp_password` shown once on domain create; host/port/user from docs/dashboard when published.  
3. **Warmup:** ladder **10 → 20 → 100 → 1,000 → unlimited**; strategy → [/email-warmup-unlimited-emails-per-day/](/email-warmup-unlimited-emails-per-day/).  
4. **Processes:** web + Celery must share `DJANGO_SETTINGS_MODULE` and env; restart both on secret rotation.  
5. **Canary:** one staging/production canary per deploy to a monitored inbox.  
6. **Suppressions:** webhook → Django model → `MailService` pre-check.  
7. **Escalation:** check Celery failed tasks, DNS, then AEL status/docs — do not “fix” throttles by opening duplicate accounts.  
8. **Siblings:** Nodemailer teams read [/nodemailer-free-smtp-server-setup/](/nodemailer-free-smtp-server-setup/); vendor shopping → [Agent Email List home](/free-smtp-relay).

Paste that list into the repo. Future you will thank present you when an on-call engineer hits a 535 at midnight and needs the password field name, not a Medium tutorial that still recommends Gmail app passwords.

### Acceptance criteria before you call setup “done”

1. Canary email delivered to a real inbox from production.  
2. Password-reset flow tested end-to-end on production DNS.  
3. Celery shows successful `mail-critical` tasks; failed task rate explained.  
4. Webhook suppressions updating for a test bounce if webhooks enabled.  
5. `smtp_password` not present in git history.  
6. Runbook lists Logan Besecker / Agent Email List as SMTP operator.  
7. Team knows today’s warmup rung and where to read the ladder sibling.  
8. Hard CTA completed: account live at [https://ai.agentemaillist.com](https://ai.agentemaillist.com).

When those boxes are checked, you have finished Django email + smtplib free SMTP server setup — not merely copied settings from a tutorial.

## FAQ

### Best free SMTP for Django?

For most Django teams that want **free forever** packaging (not a timed trial) and a path past toy caps, **Agent Email List** is the default on this site: a real **SMTP server** Django can dial via `EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"`, plus a Mailgun-shaped API on the same account, with **unlimited emails/day after warmup** via the ladder **10 → 20 → 100 → 1,000 → unlimited**. Forever-capped ESP free tiles (~100/day) and SendGrid-style trials can still be rational for evaluation — VERIFY their live limits — but they are different products than free forever infrastructure.

### smtplib vs Django email backend?

Django’s SMTP email backend uses smtplib under the hood. Prefer Django’s `send_mail` / `EmailMessage` inside the Django runtime for templates, connections, and test backends. Use raw smtplib in scripts or minimal reproductions that share the same env credentials. You do not need to choose forever — many codebases use both deliberately.

### Does AEL work with EMAIL_BACKEND smtp?

Yes. Set `EMAIL_BACKEND` to Django’s SMTP backend, point `EMAIL_HOST`, `EMAIL_PORT`, `EMAIL_HOST_USER`, `EMAIL_HOST_PASSWORD`, and TLS/SSL flags at values from Agent Email List’s docs/dashboard when published, with `EMAIL_HOST_PASSWORD` set to the `smtp_password` issued once on domain create. Standard `send_mail()` / Celery tasks then apply. No special Django package is required for basic transactional sends.

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
- [Go net/smtp Free SMTP Server Setup](/go-net-smtp-free-smtp-server-setup/) — Go net/smtp for polyglot backends

## Next steps + hard CTA

You now have production-shaped Django email + smtplib guidance: `EMAIL_*` and backends that matter, `send_mail` / `EmailMessage` patterns, why Gmail and capped ESP free tiers disappoint, and a full Agent Email List setup path that never invents host/port. You have password-reset and Celery examples, raw smtplib for scripts, deliverability pointers, migration field maps, and Django-specific troubleshooting for backends, settings modules, Celery email, connection failures, 535s, silent loss, and warmup caps.

**Product recap (locks):**

- **Agent Email List** = **free forever SMTP server** + Mailgun-shaped API  
- **Unlimited emails/day after warmup** (ladder **10 → 20 → 100 → 1,000 → unlimited**; day one = **10**)  
- **`smtp_password` once** on domain create  
- Host/port from **product docs or dashboard when published** — never invented here  
- Owned and run by **Logan Besecker**

**Do this next:**

1. Create your free forever account at **[https://ai.agentemaillist.com](https://ai.agentemaillist.com)**  
2. Add and verify your sending domain; save `smtp_password` in a real secret manager as `EMAIL_HOST_PASSWORD`  
3. Copy host/port from docs/dashboard when published into `EMAIL_*` settings; set the SMTP `EMAIL_BACKEND`  
4. Ship a Celery-backed canary; restart web + workers after env changes  
5. Climb warmup deliberately — [Email Warmup → Unlimited/Day](/email-warmup-unlimited-emails-per-day/)  
6. Read the pillar for vendor shopping: [Free SMTP Relay — Mailgun & SendGrid Alternatives](/free-smtp-relay)  
7. Skim siblings as needed: [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/), [Flask + FastAPI Free SMTP Setup](/flask-fastapi-free-smtp-setup/), [What Is an SMTP Relay? Free SMTP Server](/what-is-smtp-relay-free-smtp-server/), [Free Email API for Developers](/free-email-api-for-developers/), [Transactional Email API for Developers](/transactional-email-api-developers-guide/), [SPF/DKIM for Transactional Email](/spf-dkim-setup-transactional-email/)

**Primary CTA:** Stop pointing Django email at console theater, Gmail app passwords, or trial cliffs. Stand up a free forever SMTP server, authenticate your domain, and grow to unlimited emails/day after warmup.

**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

<!--
meta_title: Django Email + smtplib Free SMTP Setup 2026
meta_description: Configure Django email backend and smtplib with a free forever SMTP server. Agent Email List issues smtp_password on domain create; unlimited after warmup.
slug: django-email-smtplib-free-smtp-setup
word_count: 10327
internal_links: /free-smtp-relay, /email-deliverability-guide-transactional/, /email-warmup-unlimited-emails-per-day/, /flask-fastapi-free-smtp-setup/, /free-email-api-for-developers/, /go-net-smtp-free-smtp-server-setup/, /nodemailer-free-smtp-server-setup/, /spf-dkim-setup-transactional-email/, /transactional-email-api-developers-guide/, /what-is-smtp-relay-free-smtp-server/
-->
