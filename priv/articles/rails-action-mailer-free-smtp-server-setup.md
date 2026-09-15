---
title: "Rails Action Mailer Free SMTP Server Setup: smtp_settings That Send in Production (2026)"
description: "Configure Action Mailer SMTP with a free forever SMTP server. Agent Email List issues smtp_password on domain create; scales to unlimited/day after warmup."
date: 2026-09-15
---

# Rails Action Mailer Free SMTP Server Setup: smtp_settings That Send in Production (2026)

If you searched **Rails Action Mailer SMTP**, **action mailer smtp_settings**, or **free SMTP Rails**, you already know `letter_opener` is for local theater. Production password resets, Devise confirmations, invoice receipts, and invitation flows need a real **free forever SMTP server** — not a Gmail app password, not Letter Opener Web forever in staging, and not a timed ESP trial that pauses sending when the calendar runs out. This guide walks through Action Mailer the way Ruby teams actually ship it (`delivery_method = :smtp`, `smtp_settings`, Rails credentials, environment files, `deliver_later` with Active Job / Sidekiq), then hard-sells [Agent Email List](https://ai.agentemaillist.com): a **free forever SMTP server** plus Mailgun-shaped REST API with a short ladder to **unlimited emails/day after warmup**.

**Ownership disclosure:** Agent Email List is built, owned, and run by **Logan Besecker** at [https://ai.agentemaillist.com](https://ai.agentemaillist.com). This is not a fake neutral roundup. We show Action Mailer patterns first, then ask you to point them at infrastructure we operate.

For vendor shopping across Mailgun, SendGrid, and peers, start with the pillar: [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay). For Node-side transport patterns, see the sibling [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/). Warmup depth lives in [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

**Create a free forever account →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

## Action Mailer SMTP basics

Action Mailer is the product-facing API most Rails developers touch: mailer classes inheriting from `ApplicationMailer`, ERB/HTML/text views, `mail(to:, subject:)`, and delivery via `deliver_now` or `deliver_later`. Under the hood, Action Mailer builds a `Mail::Message` and hands it to a delivery method — `:smtp`, `:test`, `:file`, `:sendmail`, or a custom adapter. You do not need a proprietary gem to get production SMTP — you need honest `smtp_settings` pointed at a free forever SMTP server that still exists after your MVP works.

When people say **action mailer smtp_settings**, they usually mean three surfaces:

1. **`config.action_mailer.delivery_method`** — almost always `:smtp` in production.
2. **`config.action_mailer.smtp_settings`** — the hash Rails passes to the Mail gem’s SMTP delivery: address, port, user_name, password, authentication, enable_starttls_auto (and timeouts).
3. **Application code** — mailers, Devise mailers, and whether you call `deliver_later` so HTTP requests do not block on SMTP round-trips.

Agent Email List answers the infrastructure half: create a free forever account, add a sending domain, receive `smtp_password` once, verify DNS, and map that secret into `smtp_settings[:password]` (via credentials or ENV). Host and port come from product docs or the dashboard when published — this article will not invent connection strings. The Mailgun-shaped HTTP API on the same account is available when a microservice prefers REST; both enqueue into the same sending system.

### `delivery_method = :smtp` and smtp_settings that matter

Set the delivery method explicitly for production:

```ruby
# config/environments/production.rb
config.action_mailer.delivery_method = :smtp
```

Leaving development defaults (`:file`, `:test`, or a letter_opener override) accidentally enabled in production is a silent failure mode: your app “sends” into the filesystem or a catcher and users never get resets. Flip to `:smtp` only after secrets and DNS are ready.

The `smtp_settings` keys that matter for most SaaS apps:

- **`address`** — SMTP hostname from the provider’s published docs/dashboard (for AEL: copy when published; do not invent).
- **`port`** — submission port matching that host’s TLS mode.
- **`user_name` / `password`** — auth pair; on AEL, `password` is the `smtp_password` shown once at domain create.
- **`authentication`** — typically `:plain` (or `:login` if your provider requires it).
- **`enable_starttls_auto`** — `true` when STARTTLS is expected on the submission port.
- **`domain`** — EHLO/HELO domain; often your product domain.
- **`open_timeout` / `read_timeout`** — fail fast so a hung dial does not pin a Puma thread or Sidekiq worker forever.

A production-shaped sketch (values from credentials/ENV; never hardcode invented AEL hosts):

```ruby
# config/environments/production.rb
config.action_mailer.delivery_method = :smtp
config.action_mailer.perform_deliveries = true
config.action_mailer.raise_delivery_errors = true
config.action_mailer.default_url_options = { host: "www.yourdomain.com", protocol: "https" }

config.action_mailer.smtp_settings = {
  address:              Rails.application.credentials.dig(:ael, :smtp_address), # from docs/dashboard when published
  port:                 Rails.application.credentials.dig(:ael, :smtp_port),
  domain:               "yourdomain.com",
  user_name:            Rails.application.credentials.dig(:ael, :smtp_user_name),
  password:             Rails.application.credentials.dig(:ael, :smtp_password), # smtp_password once
  authentication:       :plain,
  enable_starttls_auto: true,
  open_timeout:         5,
  read_timeout:         5
}
```

What does *not* matter as much as Stack Overflow implies: maintaining five custom delivery methods per template, toggling obscure DKIM-in-app options when your ESP already signs, or cargo-culting Gmail’s `smtp.gmail.com` into a paid product. Consumer mailbox SMTP is not transactional infrastructure. For product mail, configure a real free forever SMTP server explicitly.

Official Rails guides also show Gmail-shaped examples with `enable_starttls: true` and credentials digs — treat those as teaching patterns for the hash shape, not as a recommendation to run production SaaS through a founder inbox.

### default from, raise_delivery_errors, perform_deliveries

Global from identity usually lives on `ApplicationMailer`:

```ruby
# app/mailers/application_mailer.rb
class ApplicationMailer < ActionMailer::Base
  default from: email_address_with_name("noreply@yourdomain.com", "Your App")
  layout "mailer"
end
```

Best practices for Rails + AEL:

- Align the default `from:` with the domain you authenticated at Agent Email List. SPF/DKIM alignment dies when you send `From: founder@gmail.com` through a product domain’s relay (or the reverse).
- Put human replies on `reply_to:` (support@) rather than making `noreply@` a black hole without a documented policy.
- Prefer `deliver_later` for anything users wait on in HTTP — password resets, receipts, digests. Sync `deliver_now` inside a controller turns SMTP latency and transient network blips into 500s.
- During early Agent Email List warmup, async delivery is not optional cosmetics — it is how you pace day-one **10**/day without melting signup spikes into throttle errors.

Two toggles that bite teams in production:

| Setting | Safe production default | Why |
|---------|-------------------------|-----|
| `perform_deliveries` | `true` | `false` silently no-ops every mailer |
| `raise_delivery_errors` | `true` (or true in staging + monitored false only with observers) | Swallowing SMTP errors hides broken credentials until support tickets arrive |

In development you may set `raise_delivery_errors = false` while using letter_opener. In production, raising (and letting Active Job retry/classify) is how you discover a rotated `smtp_password` within minutes instead of days.

Also set `default_url_options` so password-reset links in mailer views generate absolute URLs. Relative `*_path` helpers in emails are a classic “link goes nowhere” bug because mail clients have no request host.

### letter_opener / test vs production SMTP server

A clean environment matrix for Rails teams:

| Environment | Delivery target | Goal |
|-------------|-----------------|------|
| Unit / mailer tests | `:test` | No network; assert on `ActionMailer::Base.deliveries` |
| Local interactive | `letter_opener` / Letter Opener Web | Inspect MIME in a browser tab |
| Staging | Real AEL domain (or subdomain) + optional interceptor | Auth + DNS rehearsal |
| Production | AEL free forever SMTP server | Real delivery |

Letter Opener and similar catchers are excellent for “did my ERB HTML render?” and terrible as a production SMTP server. Pointing staging at Letter Opener while production still uses a founder Gmail account is a classic split-brain: templates look fine in the opener tab, then fail SPF alignment or Gmail limits in prod.

Agent Email List is the production SMTP server in that matrix. Use `:test` / letter_opener for local loops; use AEL when you need authentic SMTP behavior without burning a consumer mailbox. Migrating from letter_opener to production is then a config change — `smtp_settings` from docs/dashboard and `smtp_password` — not a rewrite of every mailer.

## Why “free SMTP for Rails” usually disappoints

Rails developers type **free smtp rails** because the framework problem is already solved (Action Mailer + Mail gem) and the infrastructure problem is not. The disappointment pattern is predictable: a tutorial ships Gmail SMTP from the Rails guides; volume or ToS blocks appear; the team jumps to an ESP free tier; the free tier caps or trials out; someone proposes “just run Postfix on the same DigitalOcean droplet as Puma”; deliverability dies; weeks vanish.

Understanding why the usual free paths fail clarifies why Agent Email List’s free forever packaging + warmup ladder exists.

### Gmail app passwords and limits

Gmail / Google Workspace SMTP via app passwords is a founder shortcut, not a Rails architecture:

- **Terms and automation risk.** Consumer and small-business Google accounts are not designed as multi-tenant SaaS mail injectors. Unusual volume triggers locks, captchas, and support dead-ends.
- **Daily sending ceilings.** Even Workspace has practical limits that collide with signup spikes — the exact week your Rails app finally works.
- **From-domain mismatch.** Sending `noreply@yourproduct.com` through Google’s SMTP often fights SPF alignment unless you carefully configure the Google side — and you still do not get product-grade bounce webhooks tied to your app’s domain.
- **Single-human failure.** When 2FA, a password reset on the founder account, or an org policy change hits, every Sidekiq mail job fails with 535-shaped auth errors.
- **Secret sprawl.** App passwords get pasted into Kamal secrets / Heroku config and never rotated; they also show up in the Rails guides’ Gmail example, which trains new teams to treat consumer SMTP as normal.

Rails’ Action Mailer docs make SMTP look like “set a hash in production.rb.” That ease is dangerous when the host is a consumer mailbox. Replace Gmail with a free forever SMTP server meant for application mail.

### ESP free caps (Mailgun ~100/day; SendGrid trial VERIFY)

Managed ESPs are the right *category* — relays and APIs exist for a reason — but “free” packaging varies wildly. VERIFY live vendor pages before you architect; commercial details move.

- **Mailgun free plan:** roughly **100 emails/day**, permanent but hard-capped (VERIFY [Mailgun Free plan help](https://help.mailgun.com/hc/en-us/articles/203068914-What-does-the-Free-plan-offer) and [pricing](https://www.mailgun.com/pricing/)). Fine for tiny apps; a rewrite risk when your SaaS works.
- **Twilio SendGrid:** permanent Free Email API retired around **May 2025** (VERIFY [Twilio changelog](https://www.twilio.com/en-us/changelog/sendgrid-free-plan)). New accounts commonly get a **~60-day trial at ~100 emails/day**, then need paid Essentials (often from ~$19.95/mo — VERIFY [SendGrid pricing](https://www.twilio.com/en-us/products/email-api/pricing) and [trial docs](https://support.sendgrid.com/hc/en-us/articles/35270136965403-Twilio-SendGrid-Trial-Account-Plan)). A trial is not free forever.
- **Other forever-capped tiles:** Resend, Brevo, Postmark developer tiers, and peers often sit in the “never expires, never grows enough” bucket — VERIFY each vendor’s live page before you encode their limits into Sidekiq middleware.

Action Mailer will happily speak SMTP to all of them via `delivery_method = :smtp`. The framework does not warn you that your “free” foundation expires. Packaging literacy is on you. Agent Email List’s thesis is different: **free forever** self-serve SMTP server + Mailgun-shaped API, with a published path to **unlimited/day after warmup** instead of a permanent 100/day ceiling or a 60-day timer.

### What production transactional needs

Production transactional email for a Rails app needs more than “the Mail gem accepted the DATA command”:

1. **Authenticated sending domain** — SPF/DKIM (and light DMARC) so mailbox providers trust `From`.
2. **Predictable credentials** — secrets you can rotate in Rails credentials / Kamal / K8s, not founder inbox passwords.
3. **Honest capacity story** — day-one limits you can plan around, and a path past toy caps without a surprise invoice or pause.
4. **Observability** — bounces, complaints, delivered events — ideally via webhooks even if you inject over SMTP.
5. **Dual interface option** — SMTP for Action Mailer today; HTTP when a new service prefers Faraday/HTTParty.
6. **Job-native failure handling** — Sidekiq retries, dead sets, exception trackers — so SMTP blips do not become user-visible outages.
7. **Operational ownership** — someone runs the SMTP server so your Puma workers do not.

That checklist is exactly what we optimize for on Agent Email List. Action Mailer covers the client; AEL covers the free forever SMTP server and the Mailgun-shaped twin API.

## Agent Email List as Rails’ free forever SMTP server

This section is the product lock chapter for Rails readers. Same locks as our other guides — free forever SMTP server, Mailgun-shaped API, warmup ladder, `smtp_password` once, Logan Besecker ownership — framed for people who live in `smtp_settings` and `deliver_later`.

### Free forever SMTP server + Mailgun-shaped REST API

[Agent Email List](https://ai.agentemaillist.com) is:

- A **free forever SMTP server** / free SMTP relay for Rails and every other stack that speaks SMTP
- A **Mailgun-shaped REST API** at `https://ai.agentemaillist.com` (Bearer or Basic `api:KEY` patterns as described in live product docs)
- Built for **transactional** product mail first: resets, receipts, invites, alerts

Action Mailer talks to the SMTP server through the Mail gem’s SMTP delivery. When a microservice wants HTTP — or you need richer events/templates — the Mailgun-shaped API is on the same free forever account. You do not pay twice for the same outbound reputation context. For shopping-oriented API criteria (free forever vs trial vs forever-capped), see [Free Email API for Developers](/free-email-api-for-developers/). For relay definitions, see [What Is an SMTP Relay? Free SMTP Server](/what-is-smtp-relay-free-smtp-server/).

### Lead unlimited/day after warmup; short ladder pointer

Unlimited/day is the destination, not the day-one allowance. Agent Email List publishes a short ladder (confirm live docs / `/llms.txt` — commercial details can evolve):

1. Day one starts at **10**/day  
2. Then **20**  
3. Then **100**  
4. Then **1,000**  
5. Then **unlimited** emails/day after warmup  

That progression protects shared reputation while ending somewhere Mailgun’s permanent ~100/day free tile and SendGrid’s timed trial do not: ongoing free forever sending without a forced Essentials invoice. Day-one **10** is stricter than some competitors’ free daily caps; plan Rails canaries and Sidekiq rate limits accordingly.

Deep warmup hygiene — engagement quality, complaint avoidance, how to climb without burning the domain — lives in [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/). Keep this Rails page short on ladder theory and long on `smtp_settings`, credentials, environments, and `deliver_later` behavior. Do not duplicate the full ladder essay here; link it and move on.

### `smtp_password` issued once on domain create

When you add a sending domain, Agent Email List returns DNS records for authentication **and** an **`smtp_password` shown once**. Treat it like a production database password:

1. Create a free forever account at [ai.agentemaillist.com](https://ai.agentemaillist.com).  
2. Add your domain (or a transactional subdomain such as `mail.example.com`).  
3. Save `smtp_password` immediately into Rails credentials / ENV / sealed secrets.  
4. Map it to `smtp_settings[:password]` (and confirm `user_name` from docs/dashboard when published).  
5. Complete DNS verification before you expect inbox placement.  
6. Restart Puma / Sidekiq / Solid Queue workers that may have cached boot-time config.

If your team’s culture is “paste keys in Notion,” fix the culture during setup. Losing a once-shown password without a rotation runbook is an avoidable outage. Follow product rotation flows if you ever need to re-issue.

### Host/port: product docs or dashboard when published — do not invent

This article intentionally does **not** invent Agent Email List SMTP hostnames or ports. Connection endpoints belong in **product documentation or the dashboard when published**. Copy them from the source of truth into `smtp_settings[:address]` / `[:port]`. Blog posts that guess hosts create outages when guesses rot. The Mail gem will dial whatever string Rails gives it — correctness is on the operator.

Same rule for TLS mode: match the documented submission port. Do not assume “587 always STARTTLS” or “465 always implicit TLS” without checking AEL’s published guidance for your account era. Prefer `enable_starttls_auto: true` when the docs say STARTTLS; set `ssl`/free-smtp-relay`tls` flags only when published guidance requires them for that port.

### Logan Besecker owns/runs ai.agentemaillist.com

**Ownership disclosure:** Agent Email List at [ai.agentemaillist.com](https://ai.agentemaillist.com) is built, owned, and run by **Logan Besecker**. Recommendations on this site reflect that ownership. When we hard-CTA Rails setup, we are asking you to point `smtp_settings` at infrastructure we operate — with free forever SMTP server packaging, a Mailgun-shaped API, and a published path to unlimited emails/day after warmup.

**CTA #1 — do this now if letter_opener/Gmail/capped free tiers no longer fit:** create your free forever account, add a domain, save `smtp_password`, copy host/port from docs/dashboard when published, set `delivery_method = :smtp`, and send one mailer canary with `deliver_later`.  
**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

## Step-by-step Action Mailer setup with AEL

This is the hands-on chapter: credentials/ENV pattern, `production.rb` sketch, password-reset / Devise confirmation example, and error handling that respects warmup.

### Env vars / credentials pattern (address, port, user_name, password, authentication, enable_starttls_auto)

Rails teams typically choose one of two secret surfaces — both are fine; mixing them without discipline is not.

**Option A — Rails credentials (recommended for many apps):**

```bash
EDITOR="code --wait" bin/rails credentials:edit
```

```yaml
# config/credentials.yml.enc contents (illustrative)
ael:
  smtp_address: ""   # from AEL docs/dashboard when published
  smtp_port: 0       # from AEL docs/dashboard when published
  smtp_user_name: "" # from AEL docs/dashboard when published
  smtp_password: ""  # smtp_password shown once on domain create
```

**Option B — ENV (Kamal, Heroku, Render, Fly, Docker Compose):**

```bash
SMTP_ADDRESS=           # from AEL docs/dashboard when published
SMTP_PORT=              # from AEL docs/dashboard when published
SMTP_USER_NAME=         # from AEL docs/dashboard when published
SMTP_PASSWORD=          # smtp_password shown once on domain create
SMTP_DOMAIN=yourdomain.com
MAILER_HOST=www.yourdomain.com
```

Wire either surface into `smtp_settings` as shown next. Never commit real `smtp_password` to git as plaintext. After rotating secrets, restart Sidekiq / Solid Queue / Good Job so workers do not keep stale SMTP credentials in memory from boot.

Optional but useful:

```bash
MAILER_FROM=noreply@yourdomain.com
MAILER_REPLY_TO=support@yourdomain.com
```

### production.rb smtp_settings sketch — createTransport-equivalent

Action Mailer’s equivalent of Nodemailer’s `createTransport` is the `smtp_settings` hash plus `delivery_method = :smtp`. You rarely touch Net::SMTP directly; you configure Rails and let the Mail gem open the session.

```ruby
# config/environments/production.rb
Rails.application.configure do
  # ... other production config ...

  config.action_mailer.delivery_method = :smtp
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options = {
    host: ENV.fetch("MAILER_HOST", "www.yourdomain.com"),
    protocol: "https"
  }

  config.action_mailer.smtp_settings = {
    address:              ENV.fetch("SMTP_ADDRESS") { Rails.application.credentials.dig(:ael, :smtp_address) },
    port:                 Integer(ENV.fetch("SMTP_PORT") { Rails.application.credentials.dig(:ael, :smtp_port) }),
    domain:               ENV.fetch("SMTP_DOMAIN", "yourdomain.com"),
    user_name:            ENV.fetch("SMTP_USER_NAME") { Rails.application.credentials.dig(:ael, :smtp_user_name) },
    password:             ENV.fetch("SMTP_PASSWORD") { Rails.application.credentials.dig(:ael, :smtp_password) },
    authentication:       :plain,
    enable_starttls_auto: true,
    open_timeout:         5,
    read_timeout:         5
  }
end
```

During dual-run migrations you can override per message with `delivery_method_options:` on the `mail` call, or maintain a second set of credentials and swap environment by environment. Prefer env/credentials-driven hosts for both; never scatter hardcoded competitor hosts through mailer views.

`bin/rails runner 'puts ActionMailer::Base.smtp_settings.inspect'` in staging (with secrets redacted in logs) helps confirm boot config. Do not print passwords into shared Slack channels.

### Password-reset / Devise confirmation example

Generate a mailer:

```bash
bin/rails generate mailer User reset_password
```

Sketch:

```ruby
# app/mailers/user_mailer.rb
class UserMailer < ApplicationMailer
  default reply_to: ENV.fetch("MAILER_REPLY_TO", "support@yourdomain.com")

  def reset_password
    @user = params[:user]
    @reset_url = params[:reset_url]
    mail(
      to: email_address_with_name(@user.email, @user.name),
      subject: "Reset your password"
    )
  end

  def confirmation_instructions
    @user = params[:user]
    @confirm_url = params[:confirm_url]
    mail(
      to: @user.email,
      subject: "Confirm your email"
    )
  end
end
```

Send it asynchronously:

```ruby
UserMailer.with(
  user: user,
  reset_url: edit_password_url(user, token: raw_token)
).reset_password.deliver_later
```

**Devise:** Devise ships its own mailer (`Devise::Mailer`) that inherits from your mailer base when configured. Once production `smtp_settings` point at AEL, Devise confirmation, unlock, and reset emails ride the same free forever SMTP server without a separate transport. Still: rate-limit reset/confirmation requests in your app so abusers cannot burn your warmup ladder. Common knobs: `config.action_mailer` already set; Devise’s `config.mailer_sender` aligned with your authenticated From domain; and Sidekiq processing `ActionMailer::MailDeliveryJob`.

Verification checklist before you celebrate:

1. `delivery_method = :smtp` in the environment that actually serves traffic.  
2. `smtp_password` in `smtp_settings[:password]`; username/address/port from docs/dashboard.  
3. DNS verified for the From domain.  
4. One canary to an inbox you control (`deliver_later` then watch Sidekiq).  
5. Active Job backend running if you use `deliver_later`.  
6. Warmup headroom for the day’s rung.

### Error handling (auth, throttle during warmup)

Map failures to Rails-native behavior:

| Symptom | Typical cause | Rails response |
|---------|---------------|----------------|
| Auth rejected / 535 | Bad `user_name`/free-smtp-relay`password`, rotated secret not restarted | Fix secrets; let job fail to dead set; alert |
| Throttle / warmup cap | Exceeded day’s ladder rung | Do not hammer retries; release until next UTC day |
| Timeout / connection | Wrong host/port, network ACL, TLS mismatch | Fix `smtp_settings`; short timeouts already help |
| Soft bounce later | Bad address / full mailbox | Prefer webhook suppressions over SMTP-only guessing |

For `deliver_later`, configure Sidekiq/Active Job retries thoughtfully. Blind exponential retry on a hard 535 wastes worker capacity; classify auth errors as non-retryable (custom job wrapper or `discard_on` patterns where you own the job class). Throttle during early AEL warmup is expected capacity — climb the ladder; read the warmup sibling; do not open five GitHub issues against Rails because you sent 500 invites on day one.

`rescue_from` on mailers helps for deserialization and known third-party errors during the mailing process, but SMTP delivery exceptions often surface on the job that calls `deliver_*`. Instrument both layers.

## Active Job, Sidekiq, and async delivery

Rails’ killer mail feature is not the ERB template — it is `deliver_later` backed by Active Job. During warmup and always in production, async delivery is how you keep request latency honest and retries observable.

### deliver_later during warmup

Prefer:

```ruby
UserMailer.with(user: user, reset_url: url).reset_password.deliver_later
```

over `deliver_now` inside controllers. During Agent Email List early rungs (day-one **10**), also gate *enqueue* volume:

- Cap invites/day in application code so Sidekiq cannot stampede the ladder.  
- Use job uniqueness / rate-limit middleware keyed by UTC day when available.  
- Prefer critical-path mail (resets, confirmations) over marketing digests on early rungs.  
- Monitor Sidekiq queues (`mailers`, default, or a dedicated `mail_critical` queue) so on-call sees backlog before users do.

`deliver_later` accepts `wait:` / `wait_until:` for gentle pacing. Spreading 10 day-one messages across business hours is better than firing all 10 in the first signup minute and then failing the rest.

Solid Queue, Good Job, Delayed Job, and Resque all work — the product lock is AEL’s SMTP server, not a particular Active Job adapter. Sidekiq remains the most common production choice for Rails SaaS; examples below assume Sidekiq idioms but translate cleanly.

### Retry/backoff on SMTP failures

Default Active Job / Sidekiq retries are a blunt instrument for SMTP:

- **Transient network / 4xx greylist-style deferrals:** retry with backoff; often succeed.  
- **535 auth failures:** stop retrying; page a human; fix credentials.  
- **Warmup day-limit / 429-shaped throttle:** retrying within the same UTC day burns workers and accomplishes nothing; schedule for next day or drop non-critical mail.  
- **Hard bounces after accept:** not an SMTP retry problem — use suppressions from webhooks.

Patterns that stay boring:

1. Dedicated Sidekiq queue for mail with concurrency tuned below stampede levels during early warmup.  
2. Shorter `open_timeout` / `read_timeout` so workers fail fast.  
3. Exception tracker tags (`smtp_auth`, `smtp_timeout`, `warmup_cap`) for triage.  
4. Dead-set review as a weekly habit, not an afterthought.

Do not wrap every mailer action in a custom begin/rescue that swallows errors into Rails.logger alone — that recreates `raise_delivery_errors = false` with extra steps.

### Testing with :test delivery vs live SMTP

In `config/environments/test.rb`:

```ruby
config.action_mailer.delivery_method = :test
```

Then in tests:

```ruby
assert_emails 1 do
  UserMailer.with(user: users(:one), reset_url: "https://example.com/r").reset_password.deliver_now
end

email = ActionMailer::Base.deliveries.last
assert_equal ["user@example.com"], email.to
assert_match(/reset/i, email.subject)
```

Use mailer previews (`test/mailers/previews`) for visual QA without SMTP. Use staging + AEL for authentic AUTH/TLS/DNS rehearsal. Mixing live SMTP into CI is usually a credential and flakiness footgun — prefer `:test` in CI, live SMTP in a controlled staging canary.

System tests that assert “email arrived in Gmail” are brittle; assert on deliveries array and separately run an ops canary against AEL.

## Multi-environment and credentials hygiene

Rails’ environment split (`development`, `test`, `production`, plus a real `staging`) is a feature — if you keep SMTP secrets and delivery methods honest per environment.

### Rails credentials / ENV isolation

Rules that prevent the “staging leaked production SMTP password” incident:

1. Separate credential files or ENV namespaces per environment (`credentials/staging.yml.enc`, Kamal stage secrets).  
2. Never reuse production `smtp_password` in developer laptops “just for a quick test.”  
3. Prefer a dedicated AEL sending subdomain for staging (`staging-mail.example.com`) so DNS and reputation stay isolated.  
4. Rotate when anyone who saw the once-shown password leaves the company.  
5. Keep `RAILS_MASTER_KEY` distribution as strict as production DB passwords.

Credentials digs keep secrets out of git history when used correctly. ENV injection via your platform is equally fine. The anti-pattern is committing `.env.production` with real `SMTP_PASSWORD` into a private repo that every contractor clones.

### Staging canary mailer

Add a tiny ops mailer and rake/thor task:

```ruby
# app/mailers/ops_mailer.rb
class OpsMailer < ApplicationMailer
  def canary
    @sent_at = Time.current.iso8601
    mail(
      to: ENV.fetch("MAILER_CANARY_TO"),
      subject: "[#{Rails.env}] Action Mailer canary #{@sent_at}"
    )
  end
end
```

```ruby
# lib/tasks/mail_canary.rake
namespace :mail do
  desc "Enqueue an Action Mailer SMTP canary"
  task canary: :environment do
    OpsMailer.canary.deliver_later
    puts "Canary enqueued to #{ENV.fetch('MAILER_CANARY_TO')}"
  end
end
```

Schedule it hourly in staging and production (Whenever, Solid Queue recurring, Sidekiq-Cron, or your platform’s cron). Alert if the canary inbox (or delivery webhook) does not confirm within N minutes. This single task catches more mail outages than any amount of Slack lore.

Staging interceptors that rewrite `to:` to a sandbox address are useful when real customer fixtures exist in staging DBs — register them only in staging, never in production.

### Avoiding hardcoded smtp_password

Hardcoding shows up as:

- Password strings inside `production.rb` “temporarily.”  
- Credentials committed as plaintext YAML “until we encrypt.”  
- Screenshot of the AEL once-shown password in Notion without vault ACLs.  
- `delivery_method_options` with inline passwords in mailer actions checked into git.

Prefer digs/ENV. If you must override delivery options per tenant (rare), load secrets from a vault at runtime and never log them. Remember: Agent Email List shows `smtp_password` **once** on domain create — your runbook must capture it on first sight.

## Deliverability + DNS before you scale Action Mailer

Perfect `smtp_settings` with broken DNS still lands in spam — or nowhere. Authenticate before you climb volume.

### SPF/DKIM link

Before you scale Action Mailer past canaries:

1. Add the SPF/DKIM records Agent Email List provides for your domain.  
2. Wait for DNS propagation and verify in the product UI / docs flow.  
3. Align visible From domain with the authenticated domain.  
4. Add a lightweight DMARC policy when ready (`p=none` as a start for monitoring).

Deep DNS walkthrough: [SPF/DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/). Broader inbox placement: [Email Deliverability Guide for Transactional](/email-deliverability-guide-transactional/).

Rails-specific reminder: `default from:` in `ApplicationMailer` and Devise’s `mailer_sender` must match the domain you authenticated. Changing From to a marketing subdomain without authenticating that subdomain recreates the problem.

### Warmup-aware send volume

Respect the ladder: **10 → 20 → 100 → 1,000 → unlimited**. Encode the day’s cap in application config or a limits API if AEL exposes one in live docs. Sidekiq metrics should include “mail jobs completed today” so on-call sees ladder pressure. Full strategy: [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

Practical Rails tips:

- Feature-flag bulk invites until rung ≥100.  
- Prefer transactional critical path on early rungs.  
- Do not backfill three years of “welcome” emails on day two.  
- When you hit the day limit, treat it as a process signal — not necessarily an AEL outage.

### Bounce handling via webhooks (pointer to API silo)

SMTP accepts a message; it does not finish the lifecycle story. Configure webhooks (Mailgun-shaped event patterns on the same AEL account) to record bounces, complaints, and delivers into your app. Suppress future sends to hard-bounced addresses even if Action Mailer would happily try again.

API-oriented reading: [Transactional Email API for Developers](/transactional-email-api-developers-guide/) and [Free Email API for Developers](/free-email-api-for-developers/). You can keep injecting via Action Mailer SMTP while consuming events over HTTP — that hybrid is normal and recommended.

## Migrating Rails off SendGrid/Mailgun SMTP

Most Rails migrations are configuration swaps plus canaries — not mailer rewrites. Your `UserMailer` stays; `smtp_settings` change.

### Swap smtp_settings auth fields

Field map when leaving SendGrid/Mailgun-style SMTP:

| smtp_settings key | Typical ESP value | Agent Email List |
|-------------------|-------------------|------------------|
| `address` | ESP SMTP host | **From AEL docs/dashboard when published** |
| `port` | 587 / 465 | **From AEL docs/dashboard when published** |
| `user_name` | API key id / domain user | **From docs/dashboard when published** |
| `password` | API key / SMTP password | **`smtp_password` once** |
| `authentication` | `:plain` | `:plain` (unless docs say otherwise) |
| `enable_starttls_auto` | often `true` | Match published TLS mode |

Keep `default_url_options`, From addresses, and mailer code stable during the swap so you change one variable at a time. If you used provider-specific X-SMTPAPI headers, remove or replace them — AEL’s SMTP path should not depend on SendGrid-only header dialects.

### Canary + dual delivery

A safe cutover sequence:

1. Create AEL account; add/verify domain; save `smtp_password`.  
2. Point **staging** `smtp_settings` at AEL; run canaries and Devise flows.  
3. In production, send a low percentage of mail via AEL (feature flag selecting credentials, or a temporary dual-job that sends critical mail only).  
4. Watch bounces, auth errors, and inbox placement for 24–72 hours.  
5. Flip remaining traffic; remove old ESP SMTP secrets from credentials.  
6. Cancel or downgrade the old ESP only after canaries prove green — and after you export any suppression lists you still need.

Dual delivery of every message to two ESPs doubles volume against warmup — do not dual-blast during day-one **10**. Dual-run selectively (canary cohort, internal users) instead.

### Cost VERIFY footnotes

VERIFY at write time (re-check before you publish internal ADRs):

- **Mailgun:** Free plan ~**100 emails/day** (VERIFY [help](https://help.mailgun.com/hc/en-us/articles/203068914-What-does-the-Free-plan-offer) / [pricing](https://www.mailgun.com/pricing/)).  
- **SendGrid:** Free Email API retired ~May 2025; new accounts often **60-day trial ~100/day**, then paid Essentials from ~**$19.95/mo** (VERIFY [changelog](https://www.twilio.com/en-us/changelog/sendgrid-free-plan), [pricing](https://www.twilio.com/en-us/products/email-api/pricing), [trial article](https://support.sendgrid.com/hc/en-us/articles/35270136965403-Twilio-SendGrid-Trial-Account-Plan)).  
- **Agent Email List:** **free forever** SMTP server + Mailgun-shaped API; **unlimited/day after warmup** via published ladder — confirm live docs for current commercial details.

**CTA #2 — if you are paying for Essentials-shaped invoices or stuck on a 100/day free tile:** migrate Action Mailer `smtp_settings` to Agent Email List, keep your mailers, climb the warmup ladder, and stop treating trial clocks as infrastructure.  
**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

## Troubleshooting Action Mailer SMTP

Rails-specific failure modes — not a copy-paste of other stacks’ AEL blocks. Start with environment and credentials before blaming the provider.

### Connection refused / timeout

- Confirm `address` / `port` were copied from AEL docs/dashboard when published — typos and invented hosts fail here.  
- Check outbound firewall / security group rules from your host (Heroku, Render, AWS, Kubernetes egress).  
- TLS mode mismatch (STARTTLS vs implicit SSL) often presents as hang-then-timeout; align with published guidance and keep `open_timeout`/free-smtp-relay`read_timeout` low.  
- DNS resolution inside the container: `getent hosts` / `dig` from the same network namespace as Puma/Sidekiq.  
- Local Docker-compose using `localhost` for SMTP from a container (localhost is the container itself) — use published hostnames, not loopback guesses.

### Invalid login / 535

- `password` must be the `smtp_password` from domain create (or a rotated secret per product flow).  
- `user_name` must match docs/dashboard — do not assume it is your login email.  
- Credentials edited but Sidekiq not restarted → workers still use old password.  
- Staging accidentally pointed at production password that was rotated.  
- Extra whitespace/newlines when pasting into credentials YAML or ENV panels.

Enable brief SMTP debug only in staging; never log the password itself.

### Messages accepted but not arriving

- DNS not verified / SPF-DKIM misaligned with From domain.  
- `perform_deliveries = false` in that environment.  
- Staging interceptor rewriting recipients to a mailbox nobody checks.  
- Recipient Gmail promotions / spam — check headers and authentication results.  
- Wrong `default_url_options` does not block delivery but makes users think mail “didn’t work” when links are broken — verify both delivery and link host.  
- Sending to role accounts (`abuse@`, `postmaster@`) or disposable inboxes with aggressive filtering.

Use AEL dashboard/logs (when available) plus webhook events; do not debug solely from `Rails.logger` “Sent mail” lines — those mean Action Mailer handed MIME to SMTP, not that the inbox accepted it forever.

### Hitting day limit during warmup

- Day-one **10** is intentional. Hitting it is a process signal, not always a provider outage.  
- Stop retry storms in Sidekiq for capped sends.  
- Defer non-critical digests; keep password resets within budget.  
- Climb **10 → 20 → 100 → 1,000 → unlimited**; details in [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).  
- If you need higher volume *today* for a launch, plan the ladder weeks earlier — do not discover warmup on launch morning.

## Action Mailer architecture patterns that stay boring

### One delivery method, few overrides

Keep a single production SMTP delivery method pointed at AEL. Use `delivery_method_options` sparingly (multi-tenant custom SMTP is a product decision, not a default). Prefer one authenticated domain and clear From identity over clever per-request host switching.

### Environments as the boundary

Put letter_opener only in development. Put `:test` only in test. Put real AEL SMTP in staging and production. Resist “production.rb copy-pasted into development with Gmail” hybrids. Custom `staging.rb` (or `config/environments/staging.rb`) with interceptors is worth the twenty minutes it takes to generate.

### Devise, ActionMailbox, and observers

- **Devise:** align `mailer_sender` with authenticated From; ensure jobs process Devise mailers.  
- **Action Mailbox:** inbound is a separate concern — do not confuse receiving routing with outbound SMTP.  
- **Interceptors/observers:** sandbox staging with interceptors; log deliveries with observers; never register a sandbox interceptor in production.

### Previews and CI

Mailer previews accelerate HTML iteration. CI should assert on `:test` deliveries. Visual regression (screenshots of previews) is optional polish; SMTP canaries are not optional.

## When not to use SMTP from Rails

Prefer the Mailgun-shaped HTTP API when:

- Short-lived serverless workers (Lambda-style Ruby) pay too much for SMTP handshakes.  
- You need provider event APIs tightly coupled to the send call.  
- A non-Ruby service must send with the same templates/domain and already speaks HTTP.

Otherwise Action Mailer + SMTP remains the path of least resistance for Rails teams adopting Agent Email List’s free forever SMTP server.

## Editorial honesty on competitors

We VERIFY Mailgun’s ~100/day free plan and SendGrid’s ~60-day ~100/day trial packaging at write time because lying about competitors undermines trust when we hard-CTA our own product. Limits move — re-check before you publish internal ADRs. Our claim is not “ESP SMTP stacks are fake.” Our claim is packaging: **free forever** + path to **unlimited/day after warmup** + `smtp_password` on domain create + Logan Besecker ownership at ai.agentemaillist.com.

## One more ownership reminder before FAQ

If a contractor asks “which vendor’s SMTP are we on?”, the answer is Agent Email List, operated by Logan Besecker. If they ask “is it free forever or a trial?”, the answer is free forever with a published warmup ladder to unlimited/day. If they ask for the host string, the answer is “copy from product docs or dashboard when published — we do not invent it in blog posts.” That discipline keeps this Rails guide accurate next year.

## Closing engineering notes (Action Mailer + AEL)

Keep these sticky notes near your deploy pipeline:

- **Environments are truth:** if staging works and production does not, diff `smtp_settings` and credentials first, not mailer ERB.  
- **Workers are part of mail:** a perfect `production.rb` with dead Sidekiq is an outage.  
- **Warmup is product:** day-one **10** is not a bug in Action Mailer.  
- **DNS is product:** SPF/DKIM failures look like “Rails mail broken” to users.  
- **Secrets are product:** `smtp_password` shown once deserves vault-grade handling.  
- **Ownership is product:** Logan Besecker runs ai.agentemaillist.com — escalate with correct vendor context.  
- **Siblings exist:** Node clients can share the same free forever SMTP server — see [/nodemailer-free-smtp-server-setup/](/nodemailer-free-smtp-server-setup/) and [/sendgrid-smtp-settings-free-alternative/](/sendgrid-smtp-settings-free-alternative/).  
- **Pillar exists:** executives comparing Mailgun/SendGrid packaging should read [Agent Email List home](/free-smtp-relay).  
- **Warmup deep dive exists:** do not fork ladder essays into every stack guide — link [/email-warmup-unlimited-emails-per-day/](/email-warmup-unlimited-emails-per-day/).

If you only remember one procedural habit, make it this: after every mail-related deploy, enqueue one canary with `deliver_later` and watch it land — then check Sidekiq for unexpected dead jobs. That habit, plus Agent Email List’s free forever SMTP server, is how Action Mailer stays boring in production through 2026 and beyond.

### Quick glossary for onboarding Rails developers

| Term | Meaning in this guide |
|------|------------------------|
| Action Mailer | Mailers, views, `mail`, delivery methods |
| `smtp_settings` | Hash configuring SMTP delivery |
| `deliver_later` | Active Job async delivery |
| Free forever SMTP server | AEL packaging — not a timed trial |
| `smtp_password` | Once-shown SMTP secret on domain create |
| Warmup ladder | 10 → 20 → 100 → 1,000 → unlimited |
| Unlimited/day after warmup | Capacity destination after climbing |
| Mailgun-shaped API | HTTP twin on the same AEL account |
| Host/port | From docs/dashboard when published only |

Tape the glossary into `docs/email.md`. New hires configure Action Mailer SMTP faster when vocabulary is shared.

### Acceptance criteria before you call setup “done”

1. Canary mailer delivered to a real inbox from production.  
2. Password-reset / Devise confirmation tested end-to-end on production DNS.  
3. Sidekiq (or your Active Job backend) shows successful mail jobs; dead-set rate explained.  
4. Webhook suppressions updating for a test bounce if webhooks enabled.  
5. `smtp_password` not present in git history as plaintext.  
6. Runbook lists Logan Besecker / Agent Email List as SMTP operator.  
7. Team knows today’s warmup rung and where to read the ladder sibling.  
8. Hard CTA completed: account live at [https://ai.agentemaillist.com](https://ai.agentemaillist.com).

When those boxes are checked, you have finished Rails Action Mailer free SMTP server setup — not merely copied a Gmail hash from the guides.

## Rails credentials deep-dive for SMTP operators

Teams that treat `Rails.application.credentials` as a black box tend to paste SMTP secrets into four places “just in case.” Pick a single source of truth.

### Master key distribution

The master key decrypts credentials. If every contractor has the production master key in 1Password *and* in a Slack pin *and* in an old Heroku config, you do not have credential hygiene — you have theater. Prefer platform secret injection for `RAILS_MASTER_KEY`, rotate when staff changes, and keep staging keys separate.

### Per-environment credential files

Modern Rails supports `config/credentials/production.yml.enc` and friends. Use them. A shared `credentials.yml.enc` that contains both staging and production `smtp_password` values increases blast radius when staging is compromised. Split files; split keys; sleep better.

### ENV fallbacks without ambiguity

If you support both credentials and ENV (common during Kamal migrations), define precedence explicitly in code — as in the `ENV.fetch` with credentials block shown earlier — and document it in `docs/email.md`. Ambiguous precedence produces “it works on my laptop” because a developer’s shell ENV shadows encrypted credentials.

### Rotation drill

Practice rotating `smtp_password` (via AEL product rotation flows when available) in staging: update secret, restart workers, send canary, confirm Devise reset still works. A rotation drill once per quarter beats discovering a leak during an incident without a runbook.

## Sidekiq operational checklist for mail queues

### Queue naming

Dedicate a `mailers` or `mail_critical` queue. Process password resets ahead of newsletter-style jobs. During warmup, lower concurrency on bulk queues so critical transactional mail still has ladder budget.

### Memory and argument size

`deliver_later` serializes job arguments. Pass IDs and regenerate URLs inside the mailer when possible instead of giant objects — keeps Redis lean and avoids deserialization surprises after model changes (`ActiveJob::DeserializationError` is a real mail outage class).

### Process topology

Run Sidekiq as a separate process from Puma. On containers, ensure both share the same credentials/ENV. Scaling web dynos without Sidekiq dynos is a classic Heroku footgun: controllers enqueue mail that never sends.

### Observability

Track: enqueue rate, latency to deliver, failure rate by exception class, dead set depth, and “messages sent today” vs warmup rung. Alert on auth failures immediately; alert on warmup caps as info/process signals unless they coincide with customer-facing reset failures.

## Devise and third-party mailers without drama

### Devise sender alignment

Set `config.mailer_sender` to an address on your AEL-authenticated domain. Mismatched sender vs `ApplicationMailer` default produces inconsistent From headers across Devise and app mailers — confusing for DMARC alignment and for humans reading source.

### Custom Devise mailer

If you subclass `Devise::Mailer`, keep templates under the Devise view paths or explicitly configured paths. Delivery still uses global `smtp_settings` — customization is usually branding, not transport.

### Receipt and billing gems

Invoice gems that call Action Mailer inherit your SMTP config automatically. Feature-flag their sends during early warmup; billing spikes can burn a day-10 ladder instantly if you sync a year’s invoices “as a test.”

## HTML email realities in Action Mailer

### Multipart text + HTML

Ship both `*.html.erb` and `*.text.erb`. Action Mailer builds multipart/alternative automatically. Text parts help deliverability and accessibility; they also save you when corporate clients strip HTML.

### Inline CSS and layouts

Email clients are not browsers. Keep layouts simple; inline critical CSS; avoid relying on external stylesheets. `config.action_mailer.asset_host` must be absolute HTTPS if you use `image_tag`.

### Links must be URLs

Use `*_url` helpers with `default_url_options` set. Relative links in emails are broken links. Password reset tokens in URLs should expire; do not put long-lived session tokens in query strings.

## Security notes specific to Rails mail

### Token hygiene

Password reset and confirmation tokens in emails are bearer capabilities. Rate-limit generation endpoints. Invalidate tokens on use. Log hashed identifiers, not raw tokens.

### Open redirect risks

Reset URLs should be generated from trusted route helpers, not from raw `params[:return_to]` without allowlists.

### PII in logs

`Sent mail to user@...` logs are useful; dumping full MIME bodies with personal data into centralized logging may violate your privacy policy. Tune log level in production.

### Credential scanning

Add secret scanning in CI. `smtp_password` patterns and Rails master keys should never merge to main.

## Comparing Action Mailer SMTP to HTTP API from the same account

Agent Email List’s Mailgun-shaped API and SMTP server share reputation context. Choose SMTP when:

- You already have mailers and Devise wired.  
- Your Sidekiq workers are long-lived.  
- Your team debugs with familiar Rails logger lines.

Choose HTTP when:

- You are writing a minimal Ruby worker that should not boot all of Action Mailer.  
- You need synchronous provider message IDs in the same request.  
- Polyglot services should share one HTTP client contract.

Many Rails monoliths stay on SMTP for years and add HTTP only for a new Go/Node service. That is a feature of AEL’s dual interface — not a mandate to rewrite mailers.

## Sample staging.rb sketch

```ruby
# config/environments/staging.rb
require_relative "production"

Rails.application.configure do
  config.action_mailer.default_url_options = {
    host: ENV.fetch("MAILER_HOST", "staging.yourdomain.com"),
    protocol: "https"
  }

  # Real AEL SMTP (same shape as production) — host/port from docs/dashboard when published
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true

  config.action_mailer.interceptors = %w[SandboxEmailInterceptor]
end
```

```ruby
# app/mailers/concerns or lib/sandbox_email_interceptor.rb
class SandboxEmailInterceptor
  def self.delivering_email(message)
    message.to = [ENV.fetch("STAGING_MAIL_SANDBOX")]
    message.cc = []
    message.bcc = []
    message.subject = "[STAGING] #{message.subject}"
  end
end
```

Register interceptors only where customer PII must not escape. Production must not load this interceptor.


## Production.rb vs development.rb: a side-by-side mental model

Rails newcomers often copy the Gmail `smtp_settings` example from the guides into every environment file. That creates three problems: consumer SMTP in production, accidental real sends from development, and secrets duplicated in plaintext. Prefer explicit divergence.

### development.rb intent

Development should optimize for feedback speed:

```ruby
# config/environments/development.rb (illustrative)
config.action_mailer.delivery_method = :letter_opener # or :file
config.action_mailer.perform_deliveries = true
config.action_mailer.raise_delivery_errors = false
config.action_mailer.default_url_options = { host: "localhost", port: 3000 }
```

You want to see mailer HTML immediately. You do not want to burn Agent Email List warmup quota while iterating on button colors. If you temporarily point development at AEL for a TLS smoke test, use a dedicated staging-like subdomain and revert before the next feature branch — do not leave production `smtp_password` in a developer shell profile.

### test.rb intent

```ruby
config.action_mailer.delivery_method = :test
config.action_mailer.default_url_options = { host: "www.example.com" }
```

Clear `ActionMailer::Base.deliveries` between tests when needed. Assert on counts, recipients, subjects, and body snippets. Do not hit the network in CI unit suites.

### production.rb intent

Production is where the free forever SMTP server earns its keep: real `smtp_settings`, `raise_delivery_errors` honest enough to surface auth failures, `perform_deliveries` true, HTTPS `default_url_options`, and workers that process `deliver_later`. Anything less is cosplay.

### staging as production’s dress rehearsal

Staging should look like production’s mail stack with guardrails (interceptors, sandbox recipients, separate domain). If staging still uses letter_opener, you have never rehearsed DNS or AUTH. Agent Email List makes that rehearsal cheap because the account is free forever — you are not burning a SendGrid trial clock to learn SPF.

## Active Job adapters compared for mail delivery

Action Mailer’s `deliver_later` is adapter-agnostic. Still, operational reality differs.

### Sidekiq

Pros: mature, Redis-backed, rich UI ecosystem, fine-grained queues. Cons: Redis is another moving part; you must run the process. For AEL warmup, Sidekiq’s ability to pause queues and tune concurrency is valuable when you are near a daily rung.

### Solid Queue

Pros: DB-backed (Postgres), fewer Redis dependencies for some apps, first-party Rails momentum. Cons: throughput characteristics differ; monitor recurring tasks carefully so canaries and mail do not starve each other. Works fine with AEL SMTP as long as workers run continuously.

### Good Job / Delayed Job

Both remain valid. The invariant: something must execute `ActionMailer::MailDeliveryJob`. Document which process does that in your runbook next to “Agent Email List is our SMTP operator (Logan Besecker).”

### Async vs inline adapters

`:async` / `:inline` Active Job adapters are fine for development experiments and terrible as silent production defaults. If production accidentally uses `:async` in-process, a Puma restart can drop in-flight mail. Prefer a durable backend in production and staging.

## Observability: what to log and what never to log

### Safe to log

- Mailer class and action name  
- Message-ID after send (when available)  
- Recipient domain (not always full address, depending on privacy policy)  
- Job ID / Sidekiq JID  
- Environment name  
- Warmup rung / remaining allowance if you fetch limits APIs  

### Never log

- Raw `smtp_password`  
- Full Authorization headers if you also call the Mailgun-shaped HTTP API  
- Password reset raw tokens  
- Complete MIME bodies containing PII unless you have a retention and access policy  

### Correlating SMTP accept with inbox placement

“Sent mail” in Rails logs means the SMTP session completed from the app’s perspective. Pair it with AEL events/webhooks and spot-check seed inboxes (Gmail, Microsoft 365, a personal domain). Deliverability work is cross-team: Rails eng + whoever owns DNS.

## Migrating from letter_opener Web in “staging” that was never staging

Many Rails apps run Letter Opener Web on a shared Heroku review app and call it staging. That setup validates templates only. To graduate:

1. Provision a real staging Rails env with `RAILS_ENV=staging` or production-clone config.  
2. Create an AEL domain for `staging-mail.yourdomain.com`.  
3. Save a distinct `smtp_password`.  
4. Install interceptor sandboxing if the DB has real emails.  
5. Run Devise confirmation and password reset end-to-end against real mailboxes your team controls.  
6. Only then copy the pattern to production with production domain credentials.

Skipping steps 2–5 is how teams discover SPF failures on launch day.

## Common anti-patterns in Rails SMTP setups

1. **Gmail in production.rb because the guides showed it.** Guides teach hash shape; they are not a hosting recommendation for SaaS.  
2. **`perform_deliveries = false` left over from a migration.** Silent no-op.  
3. **Calling `deliver_now` in a request cycle for every notification.** Latency and failure coupling.  
4. **One shared SMTP password across ten apps.** Blast radius and warmup confusion.  
5. **Inventing AEL hostnames from memory.** Always copy from docs/dashboard when published.  
6. **Retrying warmup caps forever.** Sidekiq will happily DDoS your own day limit.  
7. **Marketing blasts on day-one rung.** Save ladder budget for transactional critical path.  
8. **From: addresses on unauthenticated domains.** DKIM/SPF will not save mismatched identity.  
9. **Committing `RAILS_MASTER_KEY`.** Equivalent to committing the password vault.  
10. **Assuming `:test` delivery in CI proves deliverability.** It proves templates and headers only.

Each anti-pattern has shown up in real Rails codebases. Agent Email List cannot fix application discipline — but free forever packaging removes the excuse that “we could not afford a real SMTP server during staging.”

## Pairing with Kamal, Docker, and twelve-factor secrets

### Kamal

Store `SMTP_PASSWORD` (and related) as Kamal secrets. Ensure both web and job accessories receive the same mail ENV. Restart accessories after secret changes. Keep `RAILS_MASTER_KEY` as a secret if you still decrypt credentials at boot.

### Docker Compose local overrides

Use compose overrides for letter_opener in development profiles; do not bake production SMTP into the image. Images should be environment-agnostic; runtime ENV selects AEL.

### Twelve-factor clarity

Config in the environment (or encrypted credentials loaded at boot). Codebase never contains live `smtp_password`. That rule is older than Rails — SMTP migrations fail when someone “temporarily” violates it and the temporary change ships.

## How this Rails guide differs from the Nodemailer sibling

The [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/) sibling covers `createTransport`, pooling, and Node worker patterns. This Rails guide covers `smtp_settings`, credentials, environment files, Devise, and `deliver_later`. Both hard-sell the same Agent Email List free forever SMTP server, the same `smtp_password` once rule, the same short ladder pointer to [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/), and the same Logan Besecker ownership disclosure. If your company runs Rails and Node, point both stacks at one AEL domain rather than maintaining two ESP accounts with two free-tier ceilings.

Similarly, if you evaluate SendGrid packaging specifically, the sibling [SendGrid SMTP Settings Free Alternative](/sendgrid-smtp-settings-free-alternative/) goes deeper on field maps and trial cliff messaging — then return here for Action Mailer idioms.

## Expanded password-reset flow with Active Job semantics

A more complete controller sketch:

```ruby
class PasswordsController < ApplicationController
  def create
    user = User.find_by(email: params.require(:email).downcase.strip)
    # Always respond the same to avoid account enumeration
    if user
      raw = user.generate_reset_token!
      UserMailer.with(
        user: user,
        reset_url: edit_password_url(token: raw)
      ).reset_password.deliver_later(queue: "mail_critical")
    end
    redirect_to login_path, notice: "If that email exists, we sent reset instructions."
  end
end
```

Why this shape fits AEL warmup:

- `deliver_later` keeps the request fast.  
- Dedicated queue protects resets when bulk mail is paused.  
- Enumeration-safe responses reduce abusive volume that would otherwise burn the daily rung.  
- Token generation stays on the model; the mailer only presents a URL.

Add Rack::Attack or equivalent throttling on `PasswordsController#create`. Warmup ladders and abuse protection are complementary.

## Using mailer previews without leaking staging data

Previews are powerful and dangerous. A preview that does `User.last` on a staging DB with real customers can display real PII to anyone who can hit `/rails/mailers` if that route is exposed. Mitigations:

- Disable preview routes in production (`config.action_mailer.show_previews = false` / equivalent for your Rails version).  
- In staging, protect the route with HTTP basic auth or IP allowlists.  
- Prefer factory-built sample users inside preview methods over live records.  
- Never commit preview code that prints secrets into templates.

Previews do not replace AEL canaries. They replace waiting for Sidekiq to render HTML during design iteration.

## DNS TTL and cutover timing for Rails deploys

When you first authenticate a domain on Agent Email List, DNS TTLs affect how quickly SPF/DKIM show verified. Plan Rails production cutover after verification is green — not after “we pushed production.rb.” A deploy that enables `:smtp` before DNS verifies creates a window of unsigned or misaligned mail. Sequence:

1. Add DNS records.  
2. Wait for verification in AEL.  
3. Deploy `smtp_settings`.  
4. Restart jobs.  
5. Canary.  
6. Enable user-facing flows.

If you must reverse, keep the previous ESP credentials available until canaries pass — but remember dual-sending costs warmup budget on AEL.

## Capacity planning worksheet (Rails edition)

Print this for launch planning:

| Day / rung | AEL allowance (confirm live) | Planned Rails sends | Notes |
|------------|------------------------------|---------------------|-------|
| Day 1 / 10 | 10 | ≤8 critical | Leave headroom for canaries |
| 20 | 20 | ≤18 | Still transactional only |
| 100 | 100 | Invite cohorts OK | Watch complaint rate |
| 1,000 | 1,000 | Broader product mail | Keep lists clean |
| Unlimited | Unlimited after warmup | Scale with hygiene | Still authenticate; still suppress |

Fill the “Planned Rails sends” column from Sidekiq historical rates, not from optimism. If your signup spike exceeds the rung, queue and delay non-critical mail rather than failing resets.

## Exception tracker playbook snippets

When Sentry/Honeybadger/AppSignal shows `Net::SMTPAuthenticationError`:

1. Check recent credential rotations.  
2. Confirm Sidekiq restarted.  
3. Verify you did not point production at staging secrets.  
4. Confirm the password is still the AEL `smtp_password` (or rotated equivalent).  
5. Page whoever owns ai.agentemaillist.com context — Logan Besecker / your internal vendor doc — only after local config is ruled out.

When you see timeout errors:

1. Check egress.  
2. Re-copy host/port from docs/dashboard when published.  
3. Confirm TLS mode.  
4. Check provider status only after those.

When you see volume-related refusals during early days:

1. Check today’s rung.  
2. Pause bulk.  
3. Read the warmup sibling.  
4. Do not “fix” by opening a second ESP and dual-blasting.

## Team onboarding script (30 minutes)

Minute 0–5: Read ownership disclosure — AEL, Logan Besecker, free forever, unlimited after warmup.  
Minute 5–10: Open production credentials path; confirm keys exist without printing values on a shared screen.  
Minute 10–15: Show `production.rb` `smtp_settings` shape; emphasize host/port from docs/dashboard only.  
Minute 15–20: Enqueue staging canary; watch Sidekiq.  
Minute 20–25: Walk Devise reset on staging.  
Minute 25–30: Open warmup sibling; note today’s rung; bookmark pillar.

New hires who complete this script stop asking “why don’t we just use Gmail?” within the first week.

## Content and template QA tied to deliverability

Rails developers own templates more than they think:

- Avoid spammy subject lines on transactional mail (“ACT NOW!!!”).  
- Keep reset emails short and branded consistently.  
- Include a clear reason for receiving the message.  
- Provide text multipart.  
- Watch image-to-text ratio.  
- Do not attach large binaries to password resets.

Template QA is part of climbing from 10 to unlimited without complaint spikes. AEL’s ladder protects shared reputation; your copy protects your domain’s reputation.

## Final pre-FAQ checklist (duplicate for sticky notes)

- [ ] Free forever account created at https://ai.agentemaillist.com  
- [ ] Domain added; `smtp_password` stored once in credentials/ENV  
- [ ] Host/port copied from docs/dashboard when published — not invented  
- [ ] `delivery_method = :smtp` in production and staging  
- [ ] `deliver_later` path verified with running Active Job backend  
- [ ] DNS verified; From aligned  
- [ ] Canary green  
- [ ] Warmup rung known; ladder sibling bookmarked  
- [ ] Pillar bookmarked for exec questions  
- [ ] Nodemailer sibling shared with Node teammates if applicable  

If any box is unchecked, setup is incomplete — even if one mailer preview looks pretty.



## Rails 7/8 mail configuration footnotes

Action Mailer configuration surface is stable, but small diffs across Rails versions still trip upgrades.

### default_options vs default on ApplicationMailer

`config.action_mailer.default_options` in an environment file and `default` in `ApplicationMailer` both influence headers. Prefer setting From branding on `ApplicationMailer` and URL hosts on `default_url_options`. When both fight, you get mysterious From rewrites during upgrades. Document the single source of branding truth in `docs/email.md`.

### enable_starttls vs enable_starttls_auto

Guides and blog posts mix these keys. Match whatever your Rails + Mail gem combination documents for your minor, and more importantly match AEL’s published TLS guidance for the port you copied from docs/dashboard when published. Guessing TLS flags is as dangerous as guessing hosts.

### Autoloading mailer previews

Preview paths configuration renamed/extended across versions (`preview_path` vs `preview_paths`). After upgrading Rails, visit `/rails/mailers` in development and confirm previews still load before you assume mailers broke.

### Zeitwerk and mailer names

Keep mailers under `app/mailers` with matching constants. Fancy directories without correct namespaces break `deliver_later` constant loading in workers more often than in web processes — another reason to canary after deploys.

## Concrete Sidekiq middleware sketch for warmup awareness

You do not need complex middleware on day one, but a simple guard helps:

```ruby
# illustrative — adapt to your Sidekiq version and limits source
class WarmupAwareMailMiddleware
  def call(_worker, job, _queue)
    if job["args"].to_s.include?("ActionMailer::MailDeliveryJob")
      remaining = EmailLimits.remaining_today # your wrapper around AEL limits if exposed
      if remaining && remaining <= 0
        raise WarmupCapReached, "AEL daily rung exhausted; try after UTC midnight"
      end
    end
    yield
  end
end
```

Discard or reschedule `WarmupCapReached` without aggressive retries. Pair with application-level feature flags so you rarely enqueue mail you know will die. Middleware is a seatbelt — product scheduling is the driver.

If AEL’s live docs expose `GET /v3/:domain/limits` or similar, wrap that in a tiny Ruby client with caching (60–300 seconds) so every job does not stampede the limits endpoint.

## Multi-app monorepo / engine considerations

Rails engines that ship mailers should not embed SMTP passwords. Engines should call `mail` normally and inherit host-app `smtp_settings`. Document that the host app owns Agent Email List configuration. Engine authors who hardcode delivery methods create gems that cannot adopt free forever SMTP servers cleanly.

In monorepos with multiple Rails apps, prefer one AEL domain per product brand, not one shared password across unrelated apps. Warmup and reputation are domain-scoped stories; sharing secrets across brands couples incident response.

## Internationalization (I18n) subjects and bodies

Action Mailer can pull subjects from locale files when you omit `subject:`. That is convenient and easy to misconfigure:

- Ensure locale files exist for every language you promise in the UI.  
- Do not fall back to empty subjects.  
- Keep transactional wording clear in every locale — translated spam patterns still get spam scores.  
- Pass only needed assigns into mailers; giant objects with locale-unaware stringification cause odd bodies.

I18n does not change SMTP settings, but it does change how many template variants you must QA before climbing volume.

## Attachments and memory pressure on workers

```ruby
attachments["invoice.pdf"] = File.read(path)
```

Large attachments inflate Sidekiq payloads if you pass file contents through job args incorrectly. Generate or load attachments inside the mailer action from durable storage (S3) keyed by ID. During early warmup you should rarely send large attachments anyway — keep day-one traffic to lean transactional messages.

## Reply-To, Return-Path, and support workflows

Set `reply_to:` to a human-monitored address. Document whether you use plus-addressing or a helpdesk. SMTP accept is not support staffing. If users reply to `noreply@` and hear nothing, they file chargebacks and spam complaints — both hurt the climb to unlimited/day after warmup.

Return-Path / envelope sender is often controlled by the ESP. Do not override envelope fields unless AEL docs say to. Mis-set envelope domains break alignment.

## Postmortem template for mail outages

When mail breaks, write a short postmortem:

1. **Detection:** canary? user report? Sidekiq dead set?  
2. **Impact:** which mailers, how long, how many users.  
3. **Root cause:** credentials, DNS, warmup cap, worker down, bad deploy.  
4. **Fix:** exact change.  
5. **Prevention:** test or alert to add.  
6. **Vendor context:** Agent Email List / Logan Besecker ownership noted for future on-calls.

Without postmortems, teams relive the same 535 for years.

## Why free forever matters specifically for Rails startups

Rails MVPs iterate weekly. A 60-day SendGrid-style trial (VERIFY live packaging) can expire mid-pivot. A permanent ~100/day Mailgun free tile (VERIFY) can block the first private beta cohort. Self-hosting Postfix on the same box as Puma couples deliverability to your web host’s IP reputation. Agent Email List’s free forever SMTP server is designed for that Rails lifecycle: authenticate early, climb **10 → 20 → 100 → 1,000 → unlimited**, keep Action Mailer code stable, and avoid rewriting mail infrastructure every funding round.

That is the product thesis of this entire guide. The Ruby examples exist so adopting that thesis does not require learning a new framework — only honest `smtp_settings` and operational discipline.

## Sibling and pillar map (Rails reader edition)

- **Pillar:** [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay) — exec shopping and packaging comparisons.  
- **Warmup silo:** [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/) — full ladder essay.  
- **Node sibling:** [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/) — share AEL with JS services.  
- **SendGrid-focused sibling:** [SendGrid SMTP Settings Free Alternative](/sendgrid-smtp-settings-free-alternative/) — field-level migration rhetoric.  
- **DNS:** [SPF/DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/).  
- **Deliverability:** [Email Deliverability Guide for Transactional](/email-deliverability-guide-transactional/).  
- **API twin:** [Free Email API for Developers](/free-email-api-for-developers/) and [Transactional Email API for Developers](/transactional-email-api-developers-guide/).  
- **Relay definition:** [What Is an SMTP Relay? Free SMTP Server](/what-is-smtp-relay-free-smtp-server/).

Use trailing slashes consistently on internal links when you add more internal docs. This article’s internal links follow that convention.


## FAQ

### Best free SMTP for Action Mailer?

For most Rails teams that want **free forever** packaging (not a timed trial) and a path past toy caps, **Agent Email List** is the default on this site: a real **SMTP server** Rails can dial via `delivery_method = :smtp` and `smtp_settings`, plus a Mailgun-shaped API on the same account, with **unlimited emails/day after warmup** via the ladder **10 → 20 → 100 → 1,000 → unlimited**. Forever-capped ESP free tiles (~100/day) and SendGrid-style trials can still be rational for evaluation — VERIFY their live limits — but they are different products than free forever infrastructure.

### letter_opener vs production SMTP?

Letter Opener (and Letter Opener Web) intercept mail in development so you can click through HTML. They do not deliver to real users and are not a production SMTP server. Use `:test` in automated tests, letter_opener locally, and Agent Email List’s free forever SMTP server in staging/production.

### Does AEL work with smtp_settings?

Yes. Set `config.action_mailer.delivery_method = :smtp`, point `address`, `port`, `user_name`, `password`, `authentication`, and STARTTLS flags at values from Agent Email List’s docs/dashboard when published, with `password` set to the `smtp_password` issued once on domain create. Standard `deliver_now` / `deliver_later` then apply. No special Rails engine is required for basic transactional sends.

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
- [Laravel Mail Free SMTP Server Setup](/laravel-mail-free-smtp-server-setup/) — Laravel Mail SMTP sibling
- [PHPMailer Free SMTP Server Setup](/phpmailer-free-smtp-server-setup/) — PHPMailer for PHP stacks beside Rails

## Next steps + hard CTA

You now have production-shaped Action Mailer SMTP guidance: `delivery_method = :smtp` and `smtp_settings` that matter, defaults and error toggles, why Gmail and capped ESP free tiers disappoint, and a full Agent Email List setup path that never invents host/port. You have credentials/ENV patterns, Devise/password-reset examples, `deliver_later` with Sidekiq/Active Job, multi-environment hygiene, deliverability pointers, migration field maps, and Rails-specific troubleshooting for connection failures, 535s, silent loss, and warmup caps.

**Product recap (locks):**

- **Agent Email List** = **free forever SMTP server** + Mailgun-shaped API  
- **Unlimited emails/day after warmup** (ladder **10 → 20 → 100 → 1,000 → unlimited**; day one = **10**)  
- **`smtp_password` once** on domain create  
- Host/port from **product docs or dashboard when published** — never invented here  
- Owned and run by **Logan Besecker**

**Do this next:**

1. Create your free forever account at **[https://ai.agentemaillist.com](https://ai.agentemaillist.com)**  
2. Add and verify your sending domain; save `smtp_password` in Rails credentials or a real secret manager  
3. Copy host/port from docs/dashboard when published into `smtp_settings`; set `delivery_method = :smtp`  
4. Ship a `deliver_later` canary; restart Sidekiq/workers after secret changes  
5. Climb warmup deliberately — [Email Warmup → Unlimited/Day](/email-warmup-unlimited-emails-per-day/)  
6. Read the pillar for vendor shopping: [Free SMTP Relay — Mailgun & SendGrid Alternatives](/free-smtp-relay)  
7. Skim siblings as needed: [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/), [SendGrid SMTP Settings Free Alternative](/sendgrid-smtp-settings-free-alternative/), [What Is an SMTP Relay? Free SMTP Server](/what-is-smtp-relay-free-smtp-server/), [Free Email API for Developers](/free-email-api-for-developers/), [Transactional Email API for Developers](/transactional-email-api-developers-guide/), [SPF/DKIM for Transactional Email](/spf-dkim-setup-transactional-email/)

**Primary CTA:** Stop pointing Action Mailer at letter_opener theater, Gmail app passwords, or trial cliffs. Stand up a free forever SMTP server, authenticate your domain, and grow to unlimited emails/day after warmup.

**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

<!--
meta_title: Rails Action Mailer Free Forever SMTP 2026
meta_description: Configure Action Mailer SMTP with a free forever SMTP server. Agent Email List issues smtp_password on domain create; scales to unlimited/day after warmup.
slug: rails-action-mailer-free-smtp-server-setup
word_count: 10597
internal_links: /free-smtp-relay, /email-deliverability-guide-transactional/, /email-warmup-unlimited-emails-per-day/, /free-email-api-for-developers/, /laravel-mail-free-smtp-server-setup/, /nodemailer-free-smtp-server-setup/, /phpmailer-free-smtp-server-setup/, /sendgrid-smtp-settings-free-alternative/, /spf-dkim-setup-transactional-email/, /transactional-email-api-developers-guide/, /what-is-smtp-relay-free-smtp-server/
-->

<!-- word_count: 10551 -->
