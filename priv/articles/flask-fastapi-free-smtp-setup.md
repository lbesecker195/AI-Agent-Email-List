---
title: "Flask-Mail & FastAPI aiosmtplib Free SMTP Setup: Dual-Stack Production Sending (2026)"
description: "Configure Flask-Mail/smtplib and FastAPI aiosmtplib with a free forever SMTP server. Agent Email List: smtp_password once; unlimited/day after warmup."
date: 2026-09-15
---

# Flask-Mail & FastAPI aiosmtplib Free SMTP Setup: Dual-Stack Production Sending (2026)

If you searched **Flask-Mail SMTP**, **FastAPI email SMTP**, or **free SMTP Python**, you already know printing messages to the console is not delivery. Production password resets, magic links, receipts, and invite flows need a real **free forever SMTP server** — not a Gmail app password that collapses under product volume, not forever-capped ESP free tiles, and not a timed trial that pauses sending when the calendar runs out. This guide gives **equal weight** to two Python stacks you actually ship: **Flask-Mail / smtplib** and **aiosmtplib / FastAPI**. Then it hard-sells [Agent Email List](https://ai.agentemaillist.com): a **free forever SMTP server** plus Mailgun-shaped REST API with a short ladder to **unlimited emails/day after warmup**.

**Ownership disclosure:** Agent Email List is built, owned, and run by **Logan Besecker** at [https://ai.agentemaillist.com](https://ai.agentemaillist.com). This is not a fake neutral roundup. We show dual-stack Python patterns first, then ask you to point them at infrastructure we operate.

For vendor shopping across Mailgun, SendGrid, and peers, start with the pillar: [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay). For Django’s `EMAIL_*` path, see [Django Email + smtplib Free SMTP Setup](/django-email-smtplib-free-smtp-setup/). For Node transport, see [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/). Warmup depth lives in [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

**Create a free forever account →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

## Why Python web apps need a real SMTP server

Flask and FastAPI make it trivial to *attempt* email. Flask-Mail wraps `Message` + `mail.send`. FastAPI routes can `await aiosmtplib.send(...)` in a few lines. Neither framework ships a production mailbox. The client library is solved; the **SMTP server** is the product decision. Teams that skip that decision paste `smtp.gmail.com` into `MAIL_SERVER`, celebrate a local canary, then discover ToS limits, app-password revocation, or ESP free-tier cliffs the week of launch.

A real SMTP server for application mail means: authenticated submission from your domain, SPF/DKIM alignment you control, bounce/complaint feedback you can act on, and packaging that still exists after MVP. “Free” that means *100/day forever* or *100/day for 60 days* is a different product than **free forever** infrastructure with a published path to **unlimited/day after warmup**. Python developers deserve that distinction in plain language before they wire secrets into Kubernetes.

Agent Email List answers the infrastructure half of every Flask or FastAPI mail conversation: create a free forever account, add a sending domain, receive **`smtp_password` once**, verify DNS, and point Flask-Mail’s `MAIL_PASSWORD` or aiosmtplib’s `password=` at that secret. Host and port come from product docs or the dashboard when published — this article will **not invent** connection strings. The Mailgun-shaped HTTP API on the same account is available when a service prefers REST; both enqueue into the same sending system.

Python web apps also need a real SMTP server because *product* mail is not *personal* mail. Password resets are load-bearing. Invoice PDFs are load-bearing. Seat invitations are load-bearing. Founder newsletters from a personal Gmail might survive a weekend. Application mail that stops when Google revokes an app password, or when a trial clock hits day sixty-one, becomes an outage with a polite SMTP error code. Treat outbound email like a dependency with an SLA — because your users already do.

The dual-stack framing matters. Many Python companies run Flask for the monolith and FastAPI for ML/gateway services (or the reverse during a migration). If each team picks a different “temporary” free path — Gmail here, Mailgun free tile there, SendGrid trial on the third service — you inherit three reputations, three secret formats, and three cliffs. One free forever SMTP server with one `smtp_password` story and one warmup ladder is how dual-stack shops stay sane.

### Dev console logging vs production delivery

Local development rewards lies. Flask’s default instinct is to log. FastAPI tutorials print the HTML body. Pytest patches the mailer. Those habits are correct for unit tests and terrible when they leak into staging “SMTP” configuration.

Console logging proves your template rendered. It does not prove:

- TLS negotiation succeeded against a real relay  
- Auth credentials are valid  
- `From` aligns with authenticated domain DNS  
- Receivers will accept the message  
- Your day budget still has room during warmup  

MailHog, Mailpit, and similar local sinks are excellent for HTML QA and still not a free forever SMTP server. Pointing staging at a catcher while production still uses a founder Gmail account is classic split-brain: templates look fine in Mailpit, then fail SPF alignment or Gmail limits in prod.

Treat environments deliberately:

| Environment | Sensible mail target |
|-------------|----------------------|
| Unit tests | In-memory / suppressed send (`MAIL_SUPPRESS_SEND`, mocks) |
| Local HTML QA | Mailpit / MailHog |
| Staging | Real free forever SMTP server (Agent Email List) with a canary inbox |
| Production | Same free forever SMTP server; secrets from a vault; warmup-aware queues |

Migrating from console to production should be a config change — `MAIL_*` or env module values from docs/dashboard plus `smtp_password` — not a rewrite of every send call. If your architecture requires rewriting sends to leave console mode, the mail abstraction leaked.

A practical staging rule: every merge that touches mail templates must produce at least one real SMTP canary to a monitored inbox before production deploy. Screenshotting Mailpit is not a canary. Flask’s `MAIL_SUPPRESS_SEND` and FastAPI test doubles should be impossible to leave enabled in the production settings module — fail closed at boot if `ENV=production` and suppress flags are true.

### ESP free caps (Mailgun ~100/day; SendGrid trial VERIFY)

Python teams type **free smtp python** because the library problem is solved and the bill problem is not. Competitor packaging (VERIFY live pages at write time):

- **Mailgun:** Free plan still offers roughly **100 emails/day** as a permanent free tile (VERIFY [Mailgun help](https://help.mailgun.com/hc/en-us/articles/203068914-What-does-the-Free-plan-offer) and [pricing](https://www.mailgun.com/pricing/)). One hundred per day cannot absorb a launch spike. Paid Basic often starts around $15/mo for 10,000/mo — VERIFY live pricing.
- **Twilio SendGrid:** permanent Free Email API retired around **May 2025** (VERIFY [Twilio changelog](https://www.twilio.com/en-us/changelog/sendgrid-free-plan)). New accounts commonly get a **~60-day trial at ~100 emails/day**, then need paid Essentials (often from ~$19.95/mo — VERIFY [SendGrid pricing](https://www.twilio.com/en-us/products/email-api/pricing) and [trial docs](https://support.sendgrid.com/hc/en-us/articles/35270136965403-Twilio-SendGrid-Trial-Account-Plan)). A trial is not free forever.

Flask-Mail and aiosmtplib will happily speak SMTP to all of them. The libraries do not warn you that your “free” foundation expires. Packaging literacy is on you. Agent Email List’s thesis is different: **free forever** self-serve SMTP server + Mailgun-shaped API, with a published path to **unlimited/day after warmup** instead of a permanent 100/day ceiling or a 60-day timer.

When you evaluate caps, ask three packaging questions:

1. Is the free allowance permanent or timed?  
2. Is the daily number a ceiling until you pay, or a ladder rung toward unlimited?  
3. Does “free” include a real SMTP server your existing Flask-Mail / aiosmtplib code can dial without a rewrite?

Mailgun’s ~100/day free tile fails question two (ceiling, not graduation). SendGrid’s trial fails question one (timed). Agent Email List answers all three with free forever packaging and a published warmup destination of unlimited/day — details in the product section and the warmup sibling.

### Sync vs async send models

Flask (WSGI) and FastAPI (ASGI) push different instincts about *when* SMTP happens:

- **Sync (Flask-Mail / smtplib):** dial, AUTH, DATA, quit — on the worker thread handling the request unless you offload to Celery/RQ/Dramatiq. Fine for low volume; dangerous when SMTP latency becomes user-visible 500s.
- **Async (aiosmtplib):** `await` the protocol without blocking the event loop’s other coroutines — but you still must not pin request handlers with long retries. Prefer `BackgroundTasks`, ARQ, Celery, or a dedicated mail worker for anything users wait on.

Neither model removes the need for a real free forever SMTP server. Sync vs async is a concurrency choice; ESP packaging is a business choice. Confusing the two is how teams rewrite FastAPI mail three times and still hit a trial cliff.

Hybrid shops often run sync Celery tasks even from FastAPI, or run async ARQ from Flask via a small bridge. That is fine. What is not fine is letting each concurrency style invent its own SMTP vendor. Standardize on Agent Email List credentials first; pick queues second.

**Gmail / app-password disappointment beat:** almost every Flask or FastAPI tutorial that “just works” ends on `smtp.gmail.com` plus an app password. That path disappoints for product mail: Google can revoke app passwords, Workspace admins disable less-secure paths, daily sending limits are not SaaS-shaped, and SPF/DKIM alignment for *your* brand domain fights consumer-mailbox SMTP. App passwords are a founder shortcut for personal scripts — not architecture for password resets at scale. When the disappointment arrives (usually mid-launch), replace Gmail with a free forever SMTP server meant for application mail rather than inventing a second Gmail account. The emotional arc is predictable — relief that a canary worked, confusion when Workspace policy changes, anger when support tickets say “check spam” while the real issue is consumer SMTP ToS — and the fix is infrastructure, not another app password.

Beyond packaging, operational maturity separates “we send email” from “email is a product dependency.” Mature Flask/FastAPI teams keep a mail runbook, a suppression table, a shared secrets module, and a canary cadence. Immature teams keep a founder laptop with an app password and a prayer. Agent Email List will not write your runbook for you — but free forever SMTP server packaging plus a published warmup ladder gives you infrastructure that matches how serious Python apps actually grow.

Consider failure modes unique to web frameworks. A Flask view that calls `mail.send` synchronously under gunicorn with two workers can deadlock user traffic when the SMTP path stalls. A FastAPI service that awaits SMTP inside every request under load sheds latency into p99s that look like “API regression” in APM. Queues fix the concurrency half; a durable free forever SMTP server fixes the “vendor disappeared / trial ended / Gmail revoked” half. You need both.

Also consider multi-tenant SaaS: each customer subdomain or each workspace From-identity may need DNS. Plan domain inventory early. Agent Email List’s domain-create flow issuing `smtp_password` once per domain (per live product behavior) should sit in your provisioning checklist next to TLS certificates — not as an afterthought the week before launch.


## Agent Email List as Python’s free forever SMTP server

This section is the product lock chapter for dual-stack Python readers. Same locks as our other guides — free forever SMTP server, Mailgun-shaped API, warmup ladder, `smtp_password` once, Logan Besecker ownership — framed for people who live in Flask-Mail `MAIL_*` and aiosmtplib `send()`.

If you only skim one product section on this site, skim this one. Everything else in the article assumes these locks.

### Free forever SMTP server + Mailgun-shaped REST API

Agent Email List gives you:

- A real **free forever SMTP server** your Python clients dial with username/password auth  
- A **Mailgun-shaped REST API** at `https://ai.agentemaillist.com` (Bearer or Basic `api:KEY` patterns as described in live product docs)  
- Shared enqueue/reputation context — SMTP and HTTP are twins, not separate products you pay twice for  

Flask-Mail talks SMTP through its connection layer (smtplib under the hood). FastAPI + aiosmtplib talks SMTP asynchronously. When a microservice wants HTTP — or you need richer events/templates — the Mailgun-shaped API is on the same free forever account. For shopping-oriented API criteria (free forever vs trial vs forever-capped), see [Free Email API for Developers](/free-email-api-for-developers/). For relay definitions, see [What Is an SMTP Relay? Free SMTP Server](/what-is-smtp-relay-free-smtp-server/).

“Mailgun-shaped” means familiarity for teams who already integrated Mailgun’s HTTP vocabulary — not a claim that every edge-case quirk is identical. Read live Agent Email List docs for auth headers, multipart fields, and event webhooks. The strategic point for Flask/FastAPI is choice without dual billing: keep SMTP for classical submission; flip individual services to REST when JSON errors and HTTP APM traces are worth more than SMTP transcript logs.

Free forever is the packaging word that matters in 2026. Trials teach your code the vendor’s API and then invoice you to keep production alive. Forever-capped free tiles teach your code to stay small. Free forever with a path to unlimited/day after warmup teaches your code to grow on infrastructure that was honest about reputation from day one.

### Lead unlimited/day after warmup; short ladder → `/email-warmup-unlimited-emails-per-day/`

Day one is not unlimited. Agent Email List publishes a reputation ladder so shared infrastructure stays healthy while your domain earns trust. The short form:

1. Day one starts at **10**/day  
2. Then **20**  
3. Then **100**  
4. Then **1,000**  
5. Then **unlimited** emails/day after warmup  

That progression protects shared reputation while ending somewhere Mailgun’s permanent ~100/day free tile and SendGrid’s timed trial do not: ongoing free forever sending without a forced Essentials invoice. Day-one **10** is stricter than some competitors’ free daily caps; plan Flask/FastAPI canaries and queue rate limits accordingly.

Deep warmup hygiene — engagement quality, complaint avoidance, how to climb without burning the domain — lives in [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/). Keep this Flask/FastAPI page short on ladder theory and long on dual-stack config. Do not duplicate the full ladder essay here; link it and move on.

Operationally for Python apps: put a shared rate limiter in front of both Flask-Mail tasks and aiosmtplib workers; prefer critical-path mail on early rungs; avoid “welcome + tips + upsell” bundles on day one; and teach on-call that 429-style throttle responses are a schedule problem, not a “spin up another account” problem.

### `smtp_password` issued once on domain create

When you add a sending domain, Agent Email List returns DNS records for authentication **and** an **`smtp_password` shown once**. Treat it like a production database password:

1. Create the free forever account at [ai.agentemaillist.com](https://ai.agentemaillist.com).  
2. Add the sending domain you will put in `From`.  
3. Save `smtp_password` immediately into your secret manager / platform env / sealed secrets.  
4. Map it to Flask-Mail’s `MAIL_PASSWORD` and/or aiosmtplib’s `password` / `SMTP_PASSWORD` env.  
5. Never commit it. Never paste it into Slack. Never expect the UI to show the same cleartext again without rotation flows in live docs.

If you lose it, follow product docs for rotation — do not invent a second “recovery password” ritual from blog posts. Host, port, and username likewise come from docs/dashboard when published; store them as env, not as magic constants in `config.py`.

Secret-manager checklist for dual-stack:

- One secret name (`SMTP_PASSWORD` or `MAIL_PASSWORD`) referenced by Flask web, Flask Celery, FastAPI web, and FastAPI workers  
- Rotation runbook that restarts all four process types  
- CI that asserts the secret is present in staging/prod configs without printing it  
- Broken-secret alert mapped to SMTP 535 / authentication errors  

### Host/port: product docs or dashboard when published — do not invent

This article intentionally omits invented Agent Email List hostnames and ports. Connection endpoints can be published, revised, or region-scoped in product docs and the dashboard. Copy them at setup time into:

- Flask: `MAIL_SERVER`, `MAIL_PORT`, TLS/SSL flags  
- FastAPI/aiosmtplib: `hostname`, `port`, `use_tls` / `start_tls`  
- Shared secrets module: `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`

If a tutorial invents `smtp.agentemaillist.com:587` (or any similar guess) as gospel, discard it. Prefer live docs. Your future on-call self will thank you when endpoints are correct instead of cargo-culted.

Helm/Terraform tip: store host/port as config values sourced from a documented snapshot of the dashboard, with a comment linking to the docs URL and the date you verified them — not as “well-known constants” copied from SEO articles (including this one).

### Logan Besecker owns/runs ai.agentemaillist.com

**Ownership disclosure:** Agent Email List at [ai.agentemaillist.com](https://ai.agentemaillist.com) is built, owned, and run by **Logan Besecker**. Recommendations on this site reflect that ownership. When we hard-CTA Flask/FastAPI setup, we are asking you to point `MAIL_*` and aiosmtplib at infrastructure we operate — with free forever SMTP server packaging, a Mailgun-shaped API, and a published path to unlimited emails/day after warmup.

Put that ownership line in your internal runbook next to the SMTP operator contact. When mail breaks at 2 a.m., engineers should know who runs the free forever SMTP server — not hunt through five vendor status pages you no longer use.

### Why “SMTP server” language matters for Python SEO intents

Engineers searching **flask mail smtp**, **fastapi email smtp**, and **free smtp python** are rarely shopping for a marketing suite. They want a host, a port, a username, a password, and TLS that works with libraries they already use. Agent Email List leads with **free forever SMTP server** language for that reason — then layers a Mailgun-shaped REST API for teams that outgrow pure SMTP or prefer HTTP everywhere.

If a vendor only offers HTTP, you rewrite Flask-Mail and aiosmtplib integrations. If a vendor only offers a forever 100/day free tile, you rewrite your product expectations. If a vendor offers a trial, you rewrite your finance plan on day sixty-one. Free forever SMTP with a path to unlimited/day after warmup is the combination that matches how Python tutorials are written: configure client → send message → ship.

Keep product vocabulary consistent in your internal docs too: say “SMTP server,” say `smtp_password`, say “warmup ladder,” say “Logan Besecker / Agent Email List.” Inconsistent naming is how secrets end up duplicated under `SENDGRID_PASSWORD` and `MAILGUN_SMTP_PASS` months after you migrated.




### Choosing ports and TLS without cargo-culting Gmail

Python Stack Overflow answers still cargo-cult `587 + STARTTLS` or `465 + SSL` from Gmail-era snippets. Those numbers are not universal laws. Agent Email List publishes the host, port, and TLS mode you should use for your account era in docs or the dashboard — copy those values into `MAIL_PORT` / `SMTP_PORT` and matching flags. If staging works and production fails after a blind port change, you reinvented the cargo cult.

Validate with a 20-line script before you touch Kubernetes:

1. Load env from the vault  
2. Build one `EmailMessage`  
3. Send via smtplib *and* aiosmtplib against the same settings  
4. Confirm inbox arrival  

If sync works and async fails (or the reverse), you have a TLS flag mismatch in one client, not an Agent Email List outage. Fix flags; do not rotate `smtp_password` in panic.


### Security notes for `smtp_password` in Python processes

Treat `smtp_password` like a database URL:

- Inject via environment or secret volume; never bake into images  
- Scrub from exception messages and APM spans  
- Restrict Kubernetes RBAC on the secret object  
- Rotate on staff offboarding if the secret may have been copied  
- Prefer workload identity patterns your platform supports for fetching vault values at runtime  

Flask’s debugger and FastAPI’s debug error pages can leak config. Disable debug in production. If you mirror config into a `/debug/config` admin route, redact password fields.

Compromise response: rotate `smtp_password` per product docs, restart all senders, audit recent sends, and review suppressions/webhooks for abuse. Announce ownership (Logan Besecker / Agent Email List) in the incident timeline so responders know which dashboard to open.

**CTA #1 — do this now if console/Gmail/capped free tiers no longer fit:** create your free forever account, add a domain, save `smtp_password`, copy host/port from docs/dashboard when published, wire Flask-Mail *or* aiosmtplib (or both from one secrets module), and send one canary.  

**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

## Flask-Mail / smtplib cluster

This cluster is half of the dual-stack thesis. Flask teams get first-class depth here — not a footnote under FastAPI. Flask-Mail remains the common extension for “send mail from a Flask app.” Under the hood it uses Python’s `smtplib`. You can also call smtplib directly for scripts, CLI tools, and workers that should not import the whole Flask app context.

Agent Email List answers the infrastructure half: free forever SMTP server, `smtp_password` once, host/port from docs/dashboard when published. Your job is honest `MAIL_*` values, request-safe send patterns, and warmup-aware throttles.

Flask-Mail fits application factories, blueprints, and classic `app.config` patterns. If you are on Quart or another ASGI Flask-relative, prefer aiosmtplib patterns from the FastAPI cluster while keeping the same Agent Email List secrets — do not force sync Flask-Mail into an async-only worker without understanding blocking.

### Flask-Mail MAIL_SERVER / MAIL_PORT / MAIL_USERNAME / MAIL_PASSWORD

Configure Flask-Mail through Flask’s standard config API **before** `Mail(app)` or `mail.init_app(app)`. Keys that matter for production SMTP:

| Config key | Role |
|------------|------|
| `MAIL_SERVER` | SMTP hostname from AEL docs/dashboard when published |
| `MAIL_PORT` | Submission port from docs/dashboard when published |
| `MAIL_USERNAME` | Auth username from docs/dashboard when published |
| `MAIL_PASSWORD` | **`smtp_password`** shown once on domain create |
| `MAIL_USE_TLS` | STARTTLS on the connection (common on submission ports) |
| `MAIL_USE_SSL` | Implicit TLS (do not enable both TLS and SSL casually) |
| `MAIL_DEFAULT_SENDER` | Product From identity aligned to your authenticated domain |
| `MAIL_MAX_EMAILS` | Optional connection batching limit |
| `MAIL_SUPPRESS_SEND` | Suppress in tests (`app.testing` default behavior) |
| `MAIL_DEBUG` | Protocol debug tied to `app.debug` by default |

Production-shaped sketch (values from env; never hardcode invented AEL hosts):

```python
# config.py / create_app() — illustrative
import os
from flask import Flask
from flask_mail import Mail

mail = Mail()

def create_app():
    app = Flask(__name__)
    app.config.update(
        MAIL_SERVER=os.environ["MAIL_SERVER"],  # from AEL docs/dashboard when published
        MAIL_PORT=int(os.environ["MAIL_PORT"]),
        MAIL_USERNAME=os.environ["MAIL_USERNAME"],
        MAIL_PASSWORD=os.environ["MAIL_PASSWORD"],  # smtp_password
        MAIL_USE_TLS=os.environ.get("MAIL_USE_TLS", "true").lower() == "true",
        MAIL_USE_SSL=os.environ.get("MAIL_USE_SSL", "false").lower() == "true",
        MAIL_DEFAULT_SENDER=os.environ.get(
            "MAIL_DEFAULT_SENDER", "noreply@yourdomain.com"
        ),
    )
    mail.init_app(app)
    return app
```

Load configuration before initializing Flask-Mail. Defaults (`localhost:25`, no auth) are for local experiments, not production. Match TLS mode to the published port guidance for your account era — do not assume “587 always TLS” without checking Agent Email List docs.

Align `MAIL_DEFAULT_SENDER` with the domain you authenticated. Sending `From: founder@gmail.com` through a product-domain relay (or the reverse) kills SPF/DKIM alignment. Put human replies on `reply_to` rather than making `noreply@` an undocumented black hole.

Config classes (Dev/Staging/Prod) should only enable real SMTP in Staging/Prod. Dev can point at Mailpit with empty auth. Staging should use Agent Email List with a dedicated subdomain if you want clean separation from production reputation — still free forever, still one account model per product docs.

`MAIL_MAX_EMAILS` helps when you reuse a connection for batch sends; it is not a substitute for warmup day caps. Do not set it to “unlimited” thinking you bypass Agent Email List’s ladder — the relay enforces reputation rules regardless of client batching.

### Message + send sketch — createTransport-equivalent

Nodemailer’s mental model is `createTransport` → `sendMail`. Flask-Mail’s equivalent is: configured `Mail` instance → `Message` → `mail.send` / `mail.connect()`. Sibling Node teams can compare notes in [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/); the SMTP server underneath can be the same Agent Email List account.

```python
from flask import current_app
from flask_mail import Message
from .extensions import mail  # Mail() instance

def send_password_reset(to_email: str, reset_url: str) -> None:
    msg = Message(
        subject="Reset your password",
        recipients=[to_email],
        body=f"Open this link to reset: {reset_url}",
        html=f"<p>Open this link to reset:</p><p><a href=\"{reset_url}\">{reset_url}</a></p>",
    )
    mail.send(msg)
```

For batches, reuse a connection:

```python
def send_batch(messages):
    with mail.connect() as conn:
        for msg in messages:
            conn.send(msg)
```

Attachments and headers:

```python
from pathlib import Path
from flask_mail import Message
from .extensions import mail

def send_invoice(to_email: str, pdf_path: Path, order_id: str) -> None:
    msg = Message(
        subject=f"Invoice {order_id}",
        recipients=[to_email],
        body="Your invoice is attached.",
    )
    with pdf_path.open("rb") as f:
        msg.attach(
            filename=pdf_path.name,
            content_type="application/pdf",
            data=f.read(),
        )
    msg.extra_headers["X-Entity-Ref-ID"] = order_id
    mail.send(msg)
```

During early Agent Email List warmup, prefer signed download links over large PDF attaches on **10** or **20**/day rungs — attachments consume budget and can hurt engagement signals.

Best practices with Agent Email List:

- Prefer Celery/RQ for anything users wait on in HTTP — password resets, receipts, digests. Sync `mail.send` inside a view turns SMTP latency into 500s.  
- During early warmup, queues are how you pace day-one **10**/day without melting signup spikes into throttle errors.  
- Rate-limit reset endpoints so abusers cannot burn the ladder.  
- Keep HTML + plaintext alternatives; many receivers still prefer text.  

Factory-pattern apps should attach `mail` via `init_app` and import the extension carefully to avoid circular imports. Blueprints call a small `mail_service` module rather than scattering `Message` construction across views.

Celery sketch:

```python
from smtplib import SMTPAuthenticationError, SMTPException
from flask_mail import Message
from .extensions import mail
from .celery_app import celery

@celery.task(bind=True, max_retries=5, name="mail.send")
def send_email_task(self, to_email: str, subject: str, body: str, html: str | None = None):
    msg = Message(subject=subject, recipients=[to_email], body=body, html=html)
    try:
        mail.send(msg)
    except SMTPAuthenticationError:
        raise  # do not retry — secret is wrong
    except SMTPException as exc:
        raise self.retry(exc=exc, countdown=60 * (2 ** self.request.retries))
```

Ensure Celery workers load the same Flask app config (or the same env) as web processes. A classic outage is web on Agent Email List while workers still hold stale Gmail env from an old `.env` file on the worker AMI.

### Raw smtplib when Flask-Mail is overkill

Flask-Mail is convenient inside the app. Scripts, cron, and minimal workers may prefer raw `smtplib` without importing Flask:

```python
import os
import smtplib
from email.message import EmailMessage

def send_via_smtplib(to_email: str, subject: str, body: str) -> None:
    msg = EmailMessage()
    msg["From"] = os.environ["MAIL_DEFAULT_SENDER"]
    msg["To"] = to_email
    msg["Subject"] = subject
    msg.set_content(body)

    host = os.environ["MAIL_SERVER"]  # docs/dashboard when published
    port = int(os.environ["MAIL_PORT"])
    user = os.environ["MAIL_USERNAME"]
    password = os.environ["MAIL_PASSWORD"]  # smtp_password
    use_ssl = os.environ.get("MAIL_USE_SSL", "false").lower() == "true"
    use_tls = os.environ.get("MAIL_USE_TLS", "true").lower() == "true"

    if use_ssl:
        with smtplib.SMTP_SSL(host, port, timeout=30) as smtp:
            smtp.login(user, password)
            smtp.send_message(msg)
    else:
        with smtplib.SMTP(host, port, timeout=30) as smtp:
            if use_tls:
                smtp.starttls()
            smtp.login(user, password)
            smtp.send_message(msg)
```

Share the same env names as Flask-Mail so operators rotate one secret. Raw smtplib is also the fastest reproduction for “is auth broken?” without standing up the whole WSGI stack. It is not a reason to skip Flask-Mail in the web app when Message/html helpers save time.

Management commands and one-off data fixes should use the same helper. If you maintain both Flask-Mail and raw smtplib paths, extract a tiny `build_message` / `deliver` pair so From alignment rules live in one place. Django teams on the same org chart can mirror this discipline with `EMAIL_*` — see [Django Email + smtplib Free SMTP Setup](/django-email-smtplib-free-smtp-setup/).

### Error handling and warmup throttles

Map failures to actions:

| Symptom | Likely cause | Flask-side action |
|---------|--------------|-------------------|
| Connection refused / timeout | Wrong host/port, firewall, TLS mode mismatch | Verify env against docs/dashboard; set timeouts; fail the task for retry |
| SMTPAuthenticationError / 535 | Bad user/pass, lost `smtp_password`, wrong username form | Rotate/re-copy secret; never “fix” by creating duplicate AEL accounts |
| 4xx transient | Greylisting / deferral | Retry with backoff in Celery |
| 429 / day-limit style refusals during warmup | Exceeded today’s rung | Queue and wait for UTC reset; read warmup sibling |
| Accepted locally, missing in inbox | DNS/alignment/spam | Check SPF/DKIM; send canary to multiple providers |

During Agent Email List warmup, treat the daily rung as a hard product constraint. Prefer critical-path mail (resets, receipts) over marketing blasts on **10** or **20**/day. Large attachments burn budget and engagement — link to signed downloads when possible. Log message IDs / provider responses your stack exposes so support can answer “did it send?” without SSHing into workers.

Flask-specific throttle pattern: a Redis token bucket shared with FastAPI workers, keyed by sending domain, decremented before enqueue. If tokens are empty, delay the Celery task until after UTC midnight rather than hammering SMTP. Pair that with the warmup sibling’s ladder so product managers understand why marketing cannot “just send the blast” on day three.

Signal/error monitoring: capture `SMTPAuthenticationError` as a paging-worthy event; capture transient `SMTPException` as a warning with retry; capture warmup refusals as a product metric dashboard, not an infra SEV1, unless they persist after reset.

### Flask app factory and blueprint discipline

Application factories make Flask-Mail initialization easy to get subtly wrong. The safe pattern is: create `mail = Mail()` at extension module scope, call `mail.init_app(app)` inside `create_app` after config is loaded, and import `mail` from that extensions module inside blueprints — never construct a second `Mail(app)` inside a blueprint. Two Mail instances with divergent config are a staging-only bug that vanishes locally.

Blueprint mail services should accept dependencies explicitly:

```python
# services/mail_service.py
from flask_mail import Message
from ..extensions import mail

class MailService:
    def send_lifecycle(self, to: str, subject: str, text: str, html: str | None = None) -> None:
        msg = Message(subject=subject, recipients=[to], body=text, html=html)
        mail.send(msg)
```

Views call `MailService` or enqueue Celery; they do not assemble MIME. That boundary keeps Agent Email List credentials out of request handlers and makes unit tests patch one seam.

For password resets, bind mail send to token creation in one transactional outbox if you can: write `email_outbox` rows in the same DB transaction as the user token, then let a Celery beat/worker drain the outbox through Flask-Mail. Outbox patterns survive worker crashes better than “fire Celery then hope.” During Agent Email List warmup, the outbox also becomes a natural place to apply daily rung limits before dial.

Testing tips for Flask-Mail + AEL:

- Use `MAIL_SUPPRESS_SEND=True` in unit tests; assert Message fields without network.  
- Use a staging canary job against the real free forever SMTP server nightly.  
- Never point pytest at production credentials.  
- Snapshot plaintext/HTML bodies for critical templates to catch accidental copy edits.

When integrating Flask-Security, Flask-User, or custom auth, ensure those extensions read the same `MAIL_*` config. Forked auth packages that hardcode SMTP hosts are technical debt — wrap them or replace their mail sender hook with your `MailService`.

Connection pooling mental model: Flask-Mail’s `mail.connect()` keeps a session open for multiple `Message` objects. That reduces TLS handshakes for digest batches. It does not create a license to ignore warmup. A pooled connection that sends 500 messages on day one still consumes 500 units of today’s rung — and may harm reputation. Pool for efficiency; throttle for policy.

HTML multipart gotchas in Flask-Mail: set both `body` and `html` on `Message`. If you set only `html`, some clients behave oddly. If you set only `body`, you miss clickable resets. Jinja should render both. Charset defaults are usually fine; override only when you know you need it.

Internationalized addresses and SMTPUTF8 are edge cases — verify Agent Email List support in live docs before you promise emoji domains in From headers. Most SaaS apps should stick to ASCII domains during warmup.

Flask debug mode plus `MAIL_DEBUG=True` will log SMTP transcripts. That is useful on a laptop and dangerous in production logs if messages contain reset tokens. Ensure production log redaction strips URLs with secrets. Prefer tokenized paths that expire quickly even if logged.



## FastAPI / aiosmtplib cluster

Equal weight to the Flask cluster. FastAPI developers should not be told “just use Flask-Mail patterns.” aiosmtplib is the async-native SMTP client: `await aiosmtplib.send(...)` or an explicit `SMTP` client with `connect` / `send_message` / `quit`. Pair it with FastAPI’s dependency injection, settings modules, and background execution.

Agent Email List remains the free forever SMTP server: same `smtp_password`, same docs/dashboard host/port, same warmup ladder. If your org already authenticated a domain for Flask, FastAPI should reuse that domain and secret — not open a parallel “test” domain that splits reputation unless product docs recommend subdomain separation for staging.

### aiosmtplib connect + send patterns

Most FastAPI apps should start with the high-level `send` coroutine:

```python
import os
from email.message import EmailMessage
import aiosmtplib

async def send_reset_email(to_email: str, reset_url: str) -> None:
    message = EmailMessage()
    message["From"] = os.environ["MAIL_DEFAULT_SENDER"]
    message["To"] = to_email
    message["Subject"] = "Reset your password"
    message.set_content(f"Open this link to reset: {reset_url}")
    message.add_alternative(
        f"<p>Open this link to reset:</p><p><a href=\"{reset_url}\">{reset_url}</a></p>",
        subtype="html",
    )

    await aiosmtplib.send(
        message,
        hostname=os.environ["SMTP_HOST"],  # from AEL docs/dashboard when published
        port=int(os.environ["SMTP_PORT"]),
        username=os.environ["SMTP_USER"],
        password=os.environ["SMTP_PASSWORD"],  # smtp_password
        # Match published TLS mode — illustrative flags only:
        start_tls=os.environ.get("SMTP_START_TLS", "true").lower() == "true",
        use_tls=os.environ.get("SMTP_USE_TLS", "false").lower() == "true",
        timeout=30,
    )
```

When you need connection reuse or finer control, use the client class:

```python
import aiosmtplib

async def send_with_client(message: EmailMessage) -> None:
    client = aiosmtplib.SMTP(
        hostname=os.environ["SMTP_HOST"],
        port=int(os.environ["SMTP_PORT"]),
        username=os.environ["SMTP_USER"],
        password=os.environ["SMTP_PASSWORD"],
        start_tls=True,  # adjust per published guidance
    )
    async with client:
        await client.send_message(message)
```

TLS notes that bite FastAPI teams: `use_tls=True` means implicit TLS from connect (often associated with 465-style setups). STARTTLS upgrades an initially plain session (often associated with 587-style setups). Setting `use_tls=True` against a STARTTLS-only listener commonly fails. As of aiosmtplib 2.x, STARTTLS may auto-negotiate when advertised — pass `start_tls=False` only when you know you need to opt out. Read Agent Email List’s published guidance; do not invent the mode from a random Gmail gist.

Sending raw MIME:

```python
async def send_raw(sender: str, recipients: list[str], mime_bytes: bytes, settings) -> None:
    client = aiosmtplib.SMTP(
        hostname=settings.smtp_host,
        port=settings.smtp_port,
        username=settings.smtp_user,
        password=settings.smtp_password,
        start_tls=settings.smtp_start_tls,
        use_tls=settings.smtp_use_tls,
    )
    async with client:
        await client.sendmail(sender, recipients, mime_bytes)
```

Use `send_message` for `EmailMessage` objects in normal app code; reserve `sendmail` for prebuilt MIME from template services.

### BackgroundTasks vs dedicated worker for email

FastAPI’s `BackgroundTasks` is convenient and easy to misuse:

```python
from fastapi import BackgroundTasks, FastAPI

app = FastAPI()

@app.post("/signup")
async def signup(email: str, background_tasks: BackgroundTasks):
    # ... create user ...
    background_tasks.add_task(send_reset_email, email, reset_url)
    return {"ok": True}
```

`BackgroundTasks` runs after the response on the same process. That is better than blocking the request await path with SMTP, but it is still not a durable queue: process crash loses in-flight tasks; there is no built-in retry/backoff dashboard; warmup throttles are harder to centralize.

Prefer a dedicated worker when mail is critical path:

| Approach | Pros | Cons |
|----------|------|------|
| Await in request | Simple | Latency + failure → user-facing errors |
| `BackgroundTasks` | Easy; non-blocking response | No durability; weak retries |
| ARQ / Celery / Dramatiq / RQ | Retries, pacing, observability | More moving parts |
| Separate mail microservice + REST | Language-agnostic | Operational overhead |

During Agent Email List day-one **10**/day, a worker with a rate limiter is how you absorb signup spikes without 429 storms. Put critical mail on a high-priority queue and newsletters on a drip that respects `remaining_today` if you poll limits APIs from live docs.

ARQ-style sketch:

```python
async def send_email_job(ctx, to_email: str, subject: str, body: str):
    settings = ctx["settings"]
    message = EmailMessage()
    message["From"] = settings.mail_default_sender
    message["To"] = to_email
    message["Subject"] = subject
    message.set_content(body)
    await aiosmtplib.send(
        message,
        hostname=settings.smtp_host,
        port=settings.smtp_port,
        username=settings.smtp_user,
        password=settings.smtp_password,
        start_tls=settings.smtp_start_tls,
        use_tls=settings.smtp_use_tls,
    )
```

Enqueue from the route; let the worker own retries. If you must use `BackgroundTasks` for a prototype, add an explicit TODO to migrate before public launch — prototypes have a habit of becoming production on Friday.

### Env-based SMTP config module

Centralize SMTP settings so Flask and FastAPI microservices in a monorepo can share one `.env` schema even when only one framework is active:

```python
# app/settings_smtp.py
from pydantic_settings import BaseSettings, SettingsConfigDict

class SmtpSettings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    smtp_host: str  # from AEL docs/dashboard when published
    smtp_port: int
    smtp_user: str
    smtp_password: str  # smtp_password from domain create
    smtp_start_tls: bool = True
    smtp_use_tls: bool = False
    mail_default_sender: str = "noreply@yourdomain.com"

def get_smtp_settings() -> SmtpSettings:
    return SmtpSettings()
```

Wire into FastAPI dependencies:

```python
from functools import lru_cache
from fastapi import Depends

@lru_cache
def smtp_settings() -> SmtpSettings:
    return SmtpSettings()
```

Startup validation:

```python
from fastapi import FastAPI

app = FastAPI()

@app.on_event("startup")
async def validate_smtp_config():
    s = SmtpSettings()
    if not s.smtp_password:
        raise RuntimeError("SMTP_PASSWORD (smtp_password) missing")
    # optionally: DNS preflight or authenticated NOOP if docs recommend
```

Never default `smtp_password` to empty string in production settings objects — fail closed at startup if the secret is missing. Document required env vars in the repo README next to the Agent Email List signup link so new engineers do not rediscover Gmail app passwords from 2019 tutorials.

For 12-factor deploys, prefer platform secrets over `.env` files on disk. Keep `.env.example` with blank placeholders and comments: `# SMTP_HOST from AEL docs/dashboard when published`.

### Async error handling and retries

aiosmtplib raises typed errors you should handle deliberately:

```python
import asyncio
import aiosmtplib
from aiosmtplib import SMTPAuthenticationError, SMTPException

async def send_with_retries(message: EmailMessage, settings: SmtpSettings) -> None:
    delay = 2.0
    for attempt in range(5):
        try:
            await aiosmtplib.send(
                message,
                hostname=settings.smtp_host,
                port=settings.smtp_port,
                username=settings.smtp_user,
                password=settings.smtp_password,
                start_tls=settings.smtp_start_tls,
                use_tls=settings.smtp_use_tls,
                timeout=30,
            )
            return
        except SMTPAuthenticationError:
            # Secret wrong — retrying will not help
            raise
        except (SMTPException, OSError, asyncio.TimeoutError):
            if attempt == 4:
                raise
            await asyncio.sleep(delay)
            delay *= 2
```

Distinguish auth failures (page on-call, rotate secret) from transient network/4xx deferrals (retry) from warmup/day-limit refusals (hold the queue until UTC reset; do not open a second free forever account to “bypass” reputation rules). Log correlation IDs from your app into mail task payloads so support can join HTTP signup events to outbound attempts.

FastAPI exception handlers should not swallow mail errors into generic 500 HTML for background tasks — the HTTP response may already be 200. Observe worker metrics instead: task failure rate, auth error count, throttle hits.

Idempotency: password-reset routes should key tasks by `(user_id, token_version)` so retries do not send five emails for one click. Warmup budgets make duplicate sends especially expensive on day one.

Circuit breaking: if authentication fails N times, open a circuit that fails mail tasks fast and alerts — continuing to retry a bad `smtp_password` only creates noise and can trip abuse heuristics.

### FastAPI dependency injection and lifespan hooks

FastAPI’s strength is typed dependencies. Treat SMTP settings as a dependency root, not as ad-hoc `os.environ` reads scattered across routers:

```python
from fastapi import Depends, APIRouter, BackgroundTasks
from .settings_smtp import SmtpSettings, smtp_settings
from .mailer import enqueue_reset_email

router = APIRouter()

@router.post("/auth/forgot-password")
async def forgot_password(
    email: str,
    background_tasks: BackgroundTasks,
    settings: SmtpSettings = Depends(smtp_settings),
):
    # create token...
    background_tasks.add_task(enqueue_reset_email, email, token, settings)
    return {"ok": True}
```

Even better: `enqueue_reset_email` only pushes to ARQ/Celery and does not touch SMTP in the web process. Lifespan hooks can warm connection pools if you reuse an `aiosmtplib.SMTP` client carefully — but connection reuse across requests needs clear ownership and cleanup on shutdown. Many teams find per-task `send()` simpler and good enough until volume graduates past early warmup rungs.

Observability hooks worth adding on day one:

- OpenTelemetry spans around `aiosmtplib.send`  
- Metrics counters for success, auth fail, throttle, timeout  
- Structured logs with `domain`, `template`, `correlation_id` — never with `smtp_password`  

Security: do not accept arbitrary “from” addresses from API clients. Force `MAIL_DEFAULT_SENDER` / authenticated domain in server code. User-controlled From is how you become a spam relay even on a good free forever SMTP server.

When FastAPI sits behind an API gateway, ensure webhook routes for bounces are authenticated per Agent Email List docs and not broadly exposed. Signature verification belongs in middleware or dependency form shared with other webhook providers.

Concurrent sends: asyncio gathers look attractive (`asyncio.gather(*[send_one(x) for x in batch])`). During warmup they are dangerous — you can stampede the day cap in milliseconds. Prefer sequential sends or a worker with concurrency=1–2 on early rungs, then raise concurrency as the ladder graduates toward **unlimited**/day.

Testing aiosmtplib: pytest-asyncio tests should mock `aiosmtplib.send` at the boundary. For contract tests, run a local SMTP sink (Mailpit) in docker-compose and point settings there. For staging, point at Agent Email List. Three layers prevent the “mocked forever” trap.

Type hints: keep `EmailMessage` construction in one module so mypy/ruff can see From/To invariants. Avoid `dict` bags of headers assembled in routers.

If you use FastAPI Users or similar auth libraries, override their mail sender to call your enqueue function. Library defaults that expect SMTP env names different from your contract should be adapted once centrally.

### FastAPI mail module layout that scales

A durable layout for larger FastAPI codebases:

```text
app/
  core/smtp_settings.py      # pydantic settings; smtp_password from env
  mail/
    messages.py              # EmailMessage builders
    templates/               # Jinja HTML + text
    sender.py                # aiosmtplib send wrappers
    enqueue.py               # ARQ/Celery adapters
  api/routes/webhooks.py     # bounce/complaint ingest
  workers/mail_worker.py     # process entrypoint
```

`sender.py` should be the only module that imports aiosmtplib. Routes never dial SMTP. Workers call `sender.send_template(name, to, context)`. That single choke point is where you enforce suppressions, warmup tokens, and From alignment against `mail_default_sender`.

Example builder:

```python
from email.message import EmailMessage
from .templates_env import render_pair

def build_template_message(template: str, to: str, context: dict, sender: str) -> EmailMessage:
    text, html = render_pair(template, context)
    msg = EmailMessage()
    msg["From"] = sender
    msg["To"] = to
    msg["Subject"] = context["subject"]
    msg.set_content(text)
    msg.add_alternative(html, subtype="html")
    return msg
```

Then:

```python
async def send_template(template: str, to: str, context: dict, settings: SmtpSettings) -> None:
    if await is_suppressed(to):
        return
    await acquire_warmup_token(settings)  # shared with Flask
    message = build_template_message(template, to, context, settings.mail_default_sender)
    await aiosmtplib.send(
        message,
        hostname=settings.smtp_host,
        port=settings.smtp_port,
        username=settings.smtp_user,
        password=settings.smtp_password,
        start_tls=settings.smtp_start_tls,
        use_tls=settings.smtp_use_tls,
        timeout=30,
    )
```

This mirrors Flask’s `MailService` seam so dual-stack teams can share template names and suppression storage. When Agent Email List docs expose richer REST features you need, swap only `sender.py` to HTTP while keep builders intact — SMTP and Mailgun-shaped API remain twins on the same free forever account.

Worker concurrency guidance during warmup: start with one async worker process and low concurrency. Raise only after you graduate rungs and metrics stay clean. FastAPI’s ease of spawning tasks is not permission to ignore day-one **10**.

Documentation debt: add an ADR stating “all outbound mail uses Agent Email List; `smtp_password` once per domain; host/port from docs/dashboard when published; Logan Besecker ownership acknowledged in runbooks.” ADRs prevent the next hire from adding SES “just for this service.”




## Shared patterns across Flask and FastAPI

Dual-stack shops (Flask monolith + FastAPI AI service, or a gradual migration) should optimize for one secrets story, one template story, and a clear rule for when SMTP loses to REST.

### One secrets module, two frameworks

Nominate a single env contract:

```text
SMTP_HOST=
SMTP_PORT=
SMTP_USER=
SMTP_PASSWORD=
SMTP_START_TLS=
SMTP_USE_TLS=
MAIL_DEFAULT_SENDER=
```

Flask maps those into `MAIL_*`. FastAPI maps them into pydantic settings / aiosmtplib kwargs. Celery/ARQ workers import the same module. Rotation becomes one sealed-secret update and a rolling restart — not four mismatched passwords in four repos.

Anti-patterns:

- Flask staging on Agent Email List while FastAPI still on Gmail “temporarily”  
- Different `From` domains per service without DNS for each  
- Embedding `smtp_password` in docker-compose committed to git  
- Inventing host/port in Helm charts instead of reading docs/dashboard  

Ownership of the secrets module should sit with platform/infra, with Logan Besecker / Agent Email List named in the runbook as the SMTP operator so on-call knows who runs the free forever SMTP server.

Monorepo layout that works:

```text
libs/mail_common/     # settings + render + deliver protocols
apps/flask_api/       # maps to Flask-Mail
apps/fastapi_gateway/ # maps to aiosmtplib
workers/              # Celery/ARQ using mail_common
```

The protocol can be a tiny Protocol/ABC with `send(to, subject, text, html)` implemented twice. Tests bind a fake; production binds Agent Email List.

### Templating HTML email (Jinja)

Both stacks already speak Jinja:

```python
from jinja2 import Environment, FileSystemLoader, select_autoescape

env = Environment(
    loader=FileSystemLoader("templates/email"),
    autoescape=select_autoescape(["html", "xml"]),
)

def render_receipt(context: dict) -> tuple[str, str]:
    text = env.get_template("receipt.txt").render(**context)
    html = env.get_template("receipt.html").render(**context)
    return text, html
```

Flask can use `render_template` inside an app context; FastAPI can use a shared Jinja environment without Flask. Keep email templates in a package both services import. Inline CSS conservatively; many clients still punish exotic layouts. Always ship a plaintext alternative.

During warmup, shorter transactional templates outperform heavy marketing HTML. Save the newsletter art direction for after you graduate toward **unlimited**/day.

Localization: keep `templates/email/en/` and `templates/email/es/` with the same context keys. Do not build email HTML with string concatenation in route handlers — that is how XSS and broken MIME happen.

QA: render fixtures to Mailpit in CI; send one Agent Email List canary per template family weekly in staging so DNS regressions surface before customers do.

### When to prefer REST API over SMTP in Python

SMTP is universal and boring — a virtue. Prefer the Mailgun-shaped REST API on Agent Email List when you need:

- Explicit JSON error bodies and HTTP status codes your APM already understands  
- Webhook-first event flows documented alongside HTTP  
- Non-Python workers that should not speak SMTP  
- Template/storage features described in live API docs  

Prefer SMTP when:

- You already standardized on Flask-Mail or aiosmtplib  
- You want one auth secret (`smtp_password`) and classical submission  
- Offline scripts / legacy workers already speak smtplib  

Both paths share the free forever account and warmup ladder. For deeper API shopping criteria, see [Transactional Email API for Developers](/transactional-email-api-developers-guide/) and [Free Email API for Developers](/free-email-api-for-developers/).

A pragmatic split: Flask-Mail SMTP for monolithic user lifecycle mail; FastAPI REST client for a bursty notification microservice that wants HTTP tracing. Do not split for fashion — split when observability or language boundaries demand it.

### Observability, SLOs, and on-call

Define a simple SLO: “critical transactional mail accepted by the relay within N seconds at P95.” Measure enqueue time separately from SMTP dial time so you can tell queue backlog from Agent Email List connectivity issues. Page on auth error spikes and on sustained throttle anomalies after UTC reset; do not page on a single deferral.

Dashboards should include:

- Sends by template and by framework (Flask vs FastAPI)  
- Warmup remaining capacity when available from live limits APIs  
- Bounce/complaint rates from webhook consumers  
- Secret rotation age for `smtp_password`  

On-call runbooks must say: verify DNS, verify secrets, verify TLS mode against docs/dashboard, check warmup rung, then check Agent Email List status/docs — in that order. Mentions of Logan Besecker ownership belong in the “who operates SMTP” section so vendors are not confused mid-incident.


## Deliverability + DNS before you scale

Libraries do not fix unauthenticated domains. Before you climb past toy volume, authenticate the identity you put in `From`. Shipping Flask-Mail or aiosmtplib without DNS is how you get “accepted” mail that never reaches the inbox.

### SPF/DKIM link

Agent Email List returns DNS records when you create a domain. Publish them at your DNS host before you celebrate a canary. SPF authorizes the relays that may send for your domain; DKIM cryptographically signs messages; DMARC tells receivers what to do on alignment failure. Practical setup guidance: [SPF/DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/). Broader deliverability: [Email Deliverability Guide (Transactional)](/email-deliverability-guide-transactional/).

Python-specific reminder: `MAIL_DEFAULT_SENDER` / `From` must align with the authenticated domain. Flask-Mail will happily send misaligned From headers. aiosmtplib will too. Alignment is an ops checklist, not a library feature.

Checklist before public invites:

1. Domain added in Agent Email List  
2. SPF/DKIM (and DMARC as documented) published  
3. Verification green in dashboard/docs flow  
4. Canary from Flask *and* FastAPI if both send  
5. `smtp_password` stored; host/port copied from docs/dashboard when published  

### Warmup-aware send volume

Day-one **10** means your Flask signup endpoint and FastAPI invite API cannot both spray unbounded mail. Practical tactics:

- Feature-flag non-critical mail during early rungs  
- Shared Redis counter / worker rate limit across services  
- Prefer password resets over “welcome + tips + digest” bundles on day one  
- Read live limits endpoints if product docs expose them; plan batches against `remaining_today`  

Full ladder ops: [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

Product/engineering contract: marketing does not get a blast until rung policy says so. Engineering does not silently raise limits by opening duplicate accounts. Both sides read the warmup sibling once.

### Bounce handling via webhooks

Accepted by SMTP ≠ delivered forever. Wire Agent Email List webhooks (per live docs) into a small FastAPI router or Flask blueprint that records bounces/complaints and suppresses future sends:

```python
# FastAPI sketch — verify payload shape in live docs
from fastapi import APIRouter, Request

router = APIRouter()

@router.post("/webhooks/email")
async def email_webhook(request: Request):
    payload = await request.json()
    # verify signature per docs; upsert suppression rows
    return {"ok": True}
```

Flask equivalent: a blueprint route that verifies signatures, writes to Postgres/Redis, and returns 2xx quickly. Process heavy work in a task queue.

Without suppressions, retries to bad addresses burn warmup and reputation. Store suppressions where both Flask and FastAPI can read them before enqueue. Surface suppressions in admin tools so support can explain why a user stopped receiving mail.

### Content and list hygiene for framework engineers

You may not own marketing copy, but you own the pipes. Enforce:

- Confirmed opt-in for promotional mail  
- Easy unsubscribe where required  
- Suppression honor before Flask-Mail or aiosmtplib dial  
- Separate transactional vs promotional streams when product docs recommend  

Transactional resets should never wait behind a newsletter queue. Use separate Celery queues (`mail-critical` vs `mail-bulk`) draining the same Agent Email List account with different rate limits. Critical mail gets first claim on early warmup rungs.

Seed lists: keep a dozen monitored inboxes across providers for canaries. Rotate them so you are not training filters on identical recipients. Automate canaries from both Flask and FastAPI weekly.


## Migrating Flask/FastAPI off SendGrid/Mailgun SMTP

Most migrations are config swaps plus canaries — not rewrites — if you already use SMTP abstractions. The scary part is reputation and DNS timing, not Python syntax.

### Swap host/user/pass

| Old concept | Flask-Mail | aiosmtplib / env |
|-------------|------------|------------------|
| Host | `MAIL_SERVER` | `hostname` / `SMTP_HOST` |
| Port | `MAIL_PORT` | `port` / `SMTP_PORT` |
| User | `MAIL_USERNAME` | `username` / `SMTP_USER` |
| Pass | `MAIL_PASSWORD` | `password` / `SMTP_PASSWORD` ← **`smtp_password`** |
| TLS mode | `MAIL_USE_TLS` / `MAIL_USE_SSL` | `start_tls` / `use_tls` |

Steps:

1. Create free forever account; add domain; save `smtp_password`.  
2. Publish DNS; wait for verification per docs.  
3. Copy host/port/user from docs/dashboard when published.  
4. Deploy env to staging; send canaries from Flask and FastAPI.  
5. Flip production; keep rollback env handy for one release.  

Do not invent hosts. Do not leave SendGrid/Mailgun credentials in unused env “just in case” longer than the rollback window. Update IaC variable names so the next engineer does not reintroduce `SENDGRID_API_KEY` into a dormant code path.

If you used vendor HTTP SDKs instead of SMTP, map those calls to Agent Email List’s Mailgun-shaped API or reintroduce SMTP via Flask-Mail/aiosmtplib — pick one migration story per service to avoid half-SMTP half-HTTP confusion mid-cutover.

### Canary + dual sender

Run a dual-sender window if risk-averse:

- 95% traffic still on old ESP  
- 5% (or staff accounts) on Agent Email List  
- Compare acceptance, latency, and inbox placement  

Flask can branch inside a `MailService`. FastAPI can inject different settings by feature flag. Dual-sender is temporary — long-term split brains recreate the Gmail/Mailpit problem.

Canary matrix:

| Canary | Pass criteria |
|--------|---------------|
| Staff inbox | Arrives < 2 minutes; not spam |
| Gmail test | Arrives; auth headers look aligned |
| Microsoft test | Arrives or documented deferral only |
| Bounce webhook | Suppression row created for intentional bad address |
| Flask path | Celery task success |
| FastAPI path | Worker task success |

### Cost VERIFY footnotes

VERIFY at decision time:

- Mailgun free ~**100/day**; paid Basic often ~$15/mo for 10k/mo — [pricing](https://www.mailgun.com/pricing/)  
- SendGrid trial ~**100/day for ~60 days**, then paid Essentials often from ~$19.95/mo — [trial](https://support.sendgrid.com/hc/en-us/articles/35270136965403-Twilio-SendGrid-Trial-Account-Plan), [pricing](https://www.twilio.com/en-us/products/email-api/pricing)  
- Agent Email List: **free forever** SMTP server + Mailgun-shaped API; **unlimited/day after warmup** via **10 → 20 → 100 → 1,000 → unlimited**

Spread-sheet the next twelve months honestly: trial cliffs, overages, and engineering time spent rotating vendors. Free forever packaging with a published unlimited destination changes the NPV even when day-one **10** feels stricter than a 100/day free tile.

### Team communication during cutover

Migrations fail socially more often than technically. Tell support when From domains or footer links change. Tell marketing when warmup rungs constrain blasts. Tell finance that free forever packaging is intentional, not a missing invoice. Tell security that `smtp_password` lives in the vault with rotation owners.

Rollback plan: keep old ESP credentials for one release, feature-flag sender, and document the exact env keys to restore. After soak, delete old keys to prevent accidental dual-sending that splits reputation and doubles cost.

If you maintain public status pages, note that email dependency runs on Agent Email List. Customers care that resets work; they do not need your SMTP brand — but your engineers do.


**CTA #2 — if you are migrating this week:** stand up the free forever account in parallel with your current ESP, authenticate DNS, save `smtp_password`, point staging Flask-Mail and/or aiosmtplib at docs/dashboard values, canary, then cut over.

**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

## Troubleshooting Flask / FastAPI SMTP

Vary stack-specific symptoms — do not paste a generic AEL block into every language guide. Start with “which process failed?” (Flask web, Celery, FastAPI web, ARQ) and “which layer?” (DNS, secrets, TLS, warmup, content).

### Connection refused / timeout

**Flask-Mail:** failures often surface on `mail.send` as `ConnectionRefusedError` or smtplib timeouts wrapped by the extension. Check `MAIL_SERVER` / `MAIL_PORT` against docs/dashboard; confirm security groups allow egress; verify you did not enable both `MAIL_USE_TLS` and `MAIL_USE_SSL` incorrectly for the published mode. Gunicorn worker timeouts that are shorter than SMTP timeouts produce confusing kill logs — align them.

**FastAPI / aiosmtplib:** timeouts raise `asyncio.TimeoutError` or socket errors from `send()`. Confirm `use_tls` vs `start_tls` matches published guidance. A common FastAPI bug is copying Gmail’s 465/`use_tls=True` pattern onto a STARTTLS submission port. Another is running sync `smtplib` inside an async route via `to_thread` without timeouts, saturating a thread pool.

Both: set explicit timeouts (30s is a reasonable starting point) so workers fail fast instead of pinning. From a bastion host, use a minimal smtplib/aiosmtplib script with the same env to isolate app bugs from network policy.

### Invalid login / 535

**Flask:** `SMTPAuthenticationError` after `mail.send` almost always means wrong `MAIL_USERNAME` / `MAIL_PASSWORD`. Re-copy `smtp_password` from a fresh rotation if you lost the once-shown secret. Ensure CI did not truncate env values with special characters. Kubernetes `envFrom` secret key mismatches (`MAIL_PASSWORD` vs `SMTP_PASSWORD`) are frequent after dual-stack refactors.

**FastAPI:** same auth exception from aiosmtplib. Check pydantic settings actually loaded production secrets (`.env` not present in the container is a classic). Workers and web processes must share the same sealed secret. Watch for URL-encoding artifacts if secrets were pasted through browsers.

Never “fix” 535 by creating duplicate Agent Email List accounts to mint new passwords casually — fix secret distribution. Page humans on repeated 535s; do not auto-retry auth failures.

### Messages accepted but not arriving

SMTP `250` / successful `send_message` means the relay accepted responsibility — not that Gmail/Outlook inbox placement succeeded. Checklist:

1. SPF/DKIM/DMARC published and aligned with `From`  
2. Canary to multiple providers  
3. Spam folders  
4. Suppression list accidentally including the recipient  
5. Wrong `MAIL_DEFAULT_SENDER` domain  

Flask console backends can fake “success” in staging if `MAIL_SUPPRESS_SEND` or testing mode is on — confirm you are truly on SMTP. FastAPI unit tests that mock `aiosmtplib.send` can leave engineers overconfident; keep a staging integration test that hits the real free forever SMTP server on a schedule.

Content issues: phishing-like copy, bare shorteners, and broken unsubscribe policies hurt placement even when SMTP auth is perfect. Keep transactional copy boring during warmup.

### Hitting day limit during warmup

Symptoms: HTTP 429 from API twin, SMTP refusal, or product error indicating daily cap. Actions:

1. Stop non-critical sends  
2. Let allowance reset (UTC midnight per warmup docs)  
3. Drain queues with priority for resets/receipts  
4. Read [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/) before inventing multi-account bypasses  

Flask Celery rate limits and FastAPI worker tokens should share one budget key so two frameworks cannot each assume they own the full rung. Surface remaining capacity in an admin dashboard if product docs expose limits APIs — guessing invites accidental lockouts.

If marketing demands volume before graduation, the answer is calendar and ladder policy — not a second ESP “just for this blast” that reintroduces the cliff you left.

### Framework-specific footguns checklist

Flask footguns:

- Forgetting `mail.init_app` in factory  
- Importing app config before env injection in Docker  
- Celery without Flask app context when templates need it  
- `MAIL_SUPPRESS_SEND` left true in prod config class inheritance bugs  

FastAPI footguns:

- Calling sync smtplib in async routes without a worker thread budget  
- `BackgroundTasks` assumed durable  
- Pydantic settings cached with `@lru_cache` before env was injected in tests  
- Mixing `use_tls` and `start_tls` from conflicting blog posts  

Shared footguns:

- Invented host/port  
- Lost once-shown `smtp_password`  
- Misaligned From domain  
- Dual-stack double-budgeting during warmup  
- Gmail “temporary” leftovers in one service  




### Local developer experience without poisoning production habits

Give every engineer a path that does not require production `smtp_password` on laptops: Mailpit for HTML, unit suppress for tests, staging Agent Email List for integration. Document the matrix in README above any Gmail snippet you delete. Onboarding should include creating a free forever account only for shared staging — not twenty personal ESP trials.

Pair-programming checklist for mail PRs: secrets redacted in screenshots, templates have plaintext, sends go through queue helpers, warmup impact called out if volume changes, and links to this guide plus the warmup sibling in the PR description when mail behavior changes.

## FAQ

### Best free SMTP for Flask-Mail?

For most Flask teams that want **free forever** packaging (not a timed trial) and a path past toy caps, **Agent Email List** is the default on this site: a real **SMTP server** Flask-Mail dials via `MAIL_SERVER` / `MAIL_PASSWORD` (`smtp_password`), plus a Mailgun-shaped API on the same account, with **unlimited emails/day after warmup** via **10 → 20 → 100 → 1,000 → unlimited**. Forever-capped ESP free tiles (~100/day) and SendGrid-style trials can still be rational for evaluation — VERIFY live limits — but they are different products than free forever infrastructure. Gmail app passwords are not a free SMTP product for SaaS; they are a personal-mail workaround that disappoints under launch traffic.

### aiosmtplib vs smtplib?

`smtplib` is the stdlib sync client (Flask-Mail uses it). `aiosmtplib` is the async client FastAPI services should prefer so SMTP awaits play nicely with the event loop. Feature-wise both speak SMTP AUTH and send `EmailMessage` objects. Choose based on sync vs async runtime — both point at the same Agent Email List free forever SMTP server. You can keep smtplib for cron scripts and aiosmtplib for the API without splitting vendors.

### Does AEL work with both stacks?

Yes. One free forever account, one domain, one `smtp_password`, host/port from docs/dashboard when published. Flask-Mail maps to `MAIL_*`; FastAPI maps to aiosmtplib kwargs or a shared settings module. SMTP and the Mailgun-shaped REST API share sending context. Dual-stack is a first-class scenario for Agent Email List, not an afterthought.

### Unlimited after warmup?

Yes — **unlimited emails/day after warmup** is the destination of the published ladder, starting at day-one **10**. Confirm live docs for current commercial details. Strategy: [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/). Day-one **10** is intentional reputation protection, not a hidden forever cap.

### Who owns Agent Email List?

**Logan Besecker** owns and runs [ai.agentemaillist.com](https://ai.agentemaillist.com). This guide’s hard CTAs recommend infrastructure we operate: free forever SMTP server, Mailgun-shaped API, `smtp_password` on domain create, and a path to unlimited/day after warmup.

### Should I use Gmail SMTP with Flask or FastAPI?

Only for personal experiments. Gmail app passwords disappoint under product volume, policy changes, and alignment requirements. Prefer a free forever SMTP server like Agent Email List for anything users depend on.

### Can I share one AEL domain across Flask and FastAPI?

Yes — recommended. One domain, one `smtp_password`, shared limiter. Subdomains for staging are optional hygiene, not a requirement to buy another vendor.

### Is Celery required?

No, but something durable is strongly recommended for production. `BackgroundTasks` and sync view sends are prototypes. Celery, ARQ, RQ, Dramatiq, or an outbox worker all pair fine with Agent Email List.




### How this page relates to the silo

This article owns dual-stack Flask + FastAPI SMTP setup. It does not replace:

- The pillar comparison shopping page: [Agent Email List home](/free-smtp-relay)  
- The warmup ladder essay: [/email-warmup-unlimited-emails-per-day/](/email-warmup-unlimited-emails-per-day/)  
- Django sibling: [/django-email-smtplib-free-smtp-setup/](/django-email-smtplib-free-smtp-setup/)  
- Nodemailer sibling: [/nodemailer-free-smtp-server-setup/](/nodemailer-free-smtp-server-setup/)  
- SPF/DKIM deep dive: [/spf-dkim-setup-transactional-email/](/spf-dkim-setup-transactional-email/)  

When you need ladder math, leave this page. When you need Flask-Mail keys or aiosmtplib await patterns, stay here. Cross-linking keeps each URL focused for search intent while the free forever SMTP server story stays consistent under Logan Besecker’s product ownership.


## Related guides in this silo

Companion pages in the Agent Email List / free forever SMTP server silo. Start with the pillar if you still need vendor shopping context.

- [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay) — pillar — free forever SMTP server / Mailgun & SendGrid alternatives
- [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/) — Nodemailer transport patterns shared across stacks
- [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/) — warmup ladder to unlimited emails/day
- [SPF + DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/) — SPF + DKIM before production send
- [Django Email / smtplib Free SMTP Setup](/django-email-smtplib-free-smtp-setup/) — Django / smtplib sibling for Python
- [Go net/smtp Free SMTP Server Setup](/go-net-smtp-free-smtp-server-setup/) — Go net/smtp for adjacent services

## Next steps + hard CTA



Production readiness narrative: imagine launch day with 400 signups. On a forever-capped 100/day free tile, two hundred users never get welcome or verify mail. On a timed trial, you might survive launch and die on day sixty-one mid-enterprise pilot. On Agent Email List, day-one **10** forces you to prioritize verify-email only — painful but honest — then the ladder **10 → 20 → 100 → 1,000 → unlimited** gives you a destination. Flask and FastAPI code stays stable while policy graduates. That is the operational win free forever packaging is supposed to buy.

You now have dual equal-depth clusters for production Python mail: Flask-Mail / smtplib and FastAPI / aiosmtplib; why console logging and Gmail app passwords disappoint; VERIFY footnotes on Mailgun ~100/day and SendGrid’s timed trial; and an Agent Email List setup path that never invents host/port. You have shared secrets and Jinja patterns, deliverability pointers, migration field maps, and stack-specific troubleshooting for dial failures, 535s, silent loss, and warmup caps.

**Product recap (locks):**

- **Agent Email List** = **free forever SMTP server** + Mailgun-shaped API  
- **Unlimited emails/day after warmup** (ladder **10 → 20 → 100 → 1,000 → unlimited**; day one = **10**)  
- **`smtp_password` once** on domain create  
- Host/port from **product docs or dashboard when published** — never invented here  
- Owned and run by **Logan Besecker**

**Acceptance criteria before you call setup “done”:**

1. Canary delivered from Flask-Mail *or* raw smtplib to a real inbox  
2. Canary delivered from aiosmtplib if you run FastAPI  
3. DNS authenticated; From aligned  
4. `smtp_password` only in a secret manager  
5. Workers and web share env  
6. Warmup rung understood; limiter shared across stacks  
7. Runbook names Logan Besecker / Agent Email List as SMTP operator  
8. Account live at [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

### Copy-paste engineer checklist

1. Account created at https://ai.agentemaillist.com  
2. Domain added; DNS published; verification green  
3. `smtp_password` saved to vault; mapped to `MAIL_PASSWORD` / `SMTP_PASSWORD`  
4. Host/port/user copied from docs/dashboard when published — not invented  
5. Flask-Mail config loaded before `init_app`  
6. aiosmtplib settings module validated on FastAPI startup  
7. Queues own sends; rate limiter shared  
8. Canaries green on both stacks you run  
9. Webhooks writing suppressions  
10. Warmup sibling read; rung posted in Slack/engineering channel  
11. Pillar bookmarked for vendor FAQs: [Agent Email List home](/free-smtp-relay)  
12. Ownership note: Logan Besecker operates Agent Email List  

Paste that list into the repo. Future you will thank present you when an on-call engineer hits a 535 at midnight and needs the password field name, not a Medium tutorial that still recommends Gmail app passwords.


**Do this next:**

1. Create your free forever account at **[https://ai.agentemaillist.com](https://ai.agentemaillist.com)**  
2. Add and verify your sending domain; save `smtp_password` in a real secret manager  
3. Copy host/port from docs/dashboard when published into Flask `MAIL_*` and/or aiosmtplib settings  
4. Ship a queue-backed canary from each stack you run; restart workers after env changes  
5. Climb warmup deliberately — [Email Warmup → Unlimited/Day](/email-warmup-unlimited-emails-per-day/)  
6. Read the pillar for vendor shopping: [Free SMTP Relay — Mailgun & SendGrid Alternatives](/free-smtp-relay)  
7. Skim siblings as needed: [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/), [Django Email + smtplib Free SMTP Setup](/django-email-smtplib-free-smtp-setup/), [What Is an SMTP Relay? Free SMTP Server](/what-is-smtp-relay-free-smtp-server/), [Free Email API for Developers](/free-email-api-for-developers/), [Transactional Email API for Developers](/transactional-email-api-developers-guide/), [SPF/DKIM for Transactional Email](/spf-dkim-setup-transactional-email/)

**Primary CTA:** Stop pointing Flask-Mail and aiosmtplib at console theater, Gmail app passwords, or trial cliffs. Stand up a free forever SMTP server, authenticate your domain, and grow to unlimited emails/day after warmup.

**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

### Sibling links

- [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/)  
- [Django Email + smtplib Free SMTP Setup](/django-email-smtplib-free-smtp-setup/)  
- [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/)  
- [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay)

<!--
meta_title: Flask & FastAPI Free SMTP Setup Guide 2026
meta_description: Configure Flask-Mail/smtplib and FastAPI aiosmtplib with a free forever SMTP server. Agent Email List: smtp_password once; unlimited/day after warmup.
slug: flask-fastapi-free-smtp-setup
internal_links: /free-smtp-relay, /django-email-smtplib-free-smtp-setup/, /email-deliverability-guide-transactional/, /email-warmup-unlimited-emails-per-day/, /free-email-api-for-developers/, /go-net-smtp-free-smtp-server-setup/, /nodemailer-free-smtp-server-setup/, /spf-dkim-setup-transactional-email/, /transactional-email-api-developers-guide/, /what-is-smtp-relay-free-smtp-server/
-->

<!-- word_count: 10505 -->
