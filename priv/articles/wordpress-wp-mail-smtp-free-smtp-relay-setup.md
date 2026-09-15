---
title: "WP Mail SMTP Free SMTP Relay Setup: WordPress That Actually Delivers (2026)"
description: "Configure WP Mail SMTP with a free forever SMTP relay/server. Agent Email List issues smtp_password on domain create; unlimited/day after warmup."
date: 2026-09-15
---

# WP Mail SMTP Free SMTP Relay Setup: WordPress That Actually Delivers (2026)

If you searched **WP Mail SMTP**, **WordPress SMTP plugin**, or **free SMTP WordPress**, you already know the pain: contact forms say “sent,” WooCommerce orders never reach the customer, and password resets vanish into hosting limbo. Default `wp_mail` through PHP `mail()` is not a production **SMTP relay**. This guide walks through configuring WP Mail SMTP (or an equivalent WordPress SMTP plugin) against a real **free forever SMTP server** — [Agent Email List](https://ai.agentemaillist.com) — with Mailgun-shaped API twin, a short ladder to **unlimited emails/day after warmup**, and host/port taken only from product docs or the dashboard when published.

**Ownership disclosure:** Agent Email List is built, owned, and run by **Logan Besecker** at [https://ai.agentemaillist.com](https://ai.agentemaillist.com) (docs also reference HoneyTrap Mail). This is not a fake neutral roundup. We show WordPress SMTP plugin patterns first, then ask you to point Other SMTP at infrastructure we operate.

For vendor shopping across Mailgun, SendGrid, and peers, start with the pillar: [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay). For relay definitions, see [What Is an SMTP Relay? Free SMTP Server](/what-is-smtp-relay-free-smtp-server/). For deep warmup ops, use [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

**Create a free forever account →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

## WP Mail SMTP / WordPress mail basics

WordPress does not ship a production-grade outbound mail stack. It ships `wp_mail()`, a thin wrapper that historically defaulted to PHP’s `mail()` function — which often means “hand the message to whatever local MTA the host configured, or fail silently.” Freelancers and site owners discover this when a Contact Form 7 submission looks successful in the UI while the inbox stays empty. Searching **wp mail smtp** is the rational next step: install a WordPress SMTP plugin, pick a mailer, and stop trusting PHP `mail()`.

WP Mail SMTP (by WPForms / Awesome Motive) is the most common answer to that search. Similar plugins — Easy WP SMTP, Post SMTP, FluentSMTP, and others — solve the same problem: intercept `wp_mail` and speak authenticated SMTP (or a vendor HTTP API) to a real **SMTP relay** / **SMTP server**. This article focuses on WP Mail SMTP’s **Other SMTP** path because that is the createTransport-equivalent for WordPress: host, port, encryption, username, password. Those five fields are how you point WordPress at Agent Email List’s free forever SMTP server without waiting for a first-party mailer tile.

The mental model matters more than the brand name on the plugin. You are not “fixing WordPress email.” You are replacing an unreliable local submission path with an authenticated hop to a managed SMTP server that owns outbound reputation, retries, and (on serious providers) bounce events. That hop is the **SMTP relay** WordPress site owners actually need.

### How `wp_mail` and the PHPMailer bridge work

Under the hood, modern WordPress uses PHPMailer to build and send messages when you call `wp_mail( $to, $subject, $message, $headers, $attachments )`. Themes, Contact Form 7, Gravity Forms, WooCommerce, membership plugins, and LMS tools almost all funnel through that function (or a thin wrapper around it). Filters such as `wp_mail`, `wp_mail_from`, `wp_mail_from_name`, and `phpmailer_init` let plugins mutate the message or the PHPMailer instance before send.

WP Mail SMTP hooks that pipeline. When you choose a mailer, the plugin configures PHPMailer’s transport: for **Other SMTP**, that means `IsSMTP()`, host, port, SMTPSecure / SMTPAutoTLS, SMTPAuth, Username, and Password. Conceptually this is the same surface Nodemailer’s `createTransport` exposes in Node, or PHPMailer’s direct SMTP mode in custom PHP — see the sibling [PHPMailer Free SMTP Server Setup](/phpmailer-free-smtp-server-setup/) if you also run non-WordPress PHP apps.

What site owners miss:

1. **Success at `wp_mail` return is not inbox success.** A `true` return often means “PHPMailer handed the message to the SMTP server and got a queue acceptance,” not “Gmail placed it in Primary.”
2. **Multiple plugins can fight over `phpmailer_init`.** Two SMTP plugins active at once produce classic “works on staging, broken on prod” chaos.
3. **Hosting panels that “enable mail” are not an SMTP relay.** They may open `mail()` to a local queue that your ISP or cloud host throttles or blackholes.
4. **From headers lie easily.** Forcing `noreply@yourdomain.com` while still submitting through a consumer Gmail SMTP path wrecks alignment. Use a verified sending domain on a real SMTP server.

When Agent Email List is the SMTP server behind Other SMTP, `wp_mail` becomes a boring authenticated submission. DNS (SPF/DKIM) and warmup still matter — the plugin cannot invent reputation — but you leave the PHP `mail()` lottery.

Agencies should also remember that **WordPress SMTP plugin** settings survive database migrations only if you migrate options or rebuild constants. A common failure: clone production to staging with All-in-One WP Migration, ship staging URLs to the client, then push staging DB back to production and wipe `WPMS_*` expectations because `wp-config.php` differed. Treat mail config as part of the release checklist beside salts and table prefixes.

If you use a “must-use” SMTP forced by the host (some managed hosts inject mailers), disable or reconcile it before WP Mail SMTP Other SMTP can win. Two forced mail paths produce heisenbugs where Email Test uses one transport and WooCommerce uses another.



### Plugin “Other SMTP” fields that matter

In WP Mail SMTP, open **Settings → WP Mail SMTP** (or complete the setup wizard) and choose **Other SMTP** as the mailer. The fields that map to a real free forever SMTP server are:

| WP Mail SMTP field | What it means | AEL mapping |
|--------------------|---------------|-------------|
| **SMTP Host** | Hostname of the SMTP server | From Agent Email List docs/dashboard when published — **do not invent** |
| **Encryption** | TLS (STARTTLS), SSL (implicit), or none | Match published submission mode |
| **SMTP Port** | Submission port for that encryption mode | From docs/dashboard when published — **do not invent** |
| **Authentication** | Almost always On | On |
| **SMTP Username** | Auth identity | From docs/dashboard (often domain-related user) |
| **SMTP Password** | Secret | The `smtp_password` shown once on domain create |

Also configure **From Email** and **From Name** to addresses on your verified Agent Email List domain, and force From when your theme or WooCommerce tries to override with a mismatched address. Return-Path / bounce address handling should follow provider docs; do not invent envelope senders that fail SPF.

WP Mail SMTP can lock these values via `wp-config.php` constants (`WPMS_ON`, `WPMS_SMTP_HOST`, `WPMS_SMTP_PORT`, `WPMS_SSL`, `WPMS_SMTP_AUTH`, `WPMS_SMTP_USER`, `WPMS_SMTP_PASS`, `WPMS_MAILER`, and related). Constants are the right production pattern: secrets leave the database UI, survive plugin screen edits, and survive “helpful” agency logins. Treat `WPMS_SMTP_PASS` as production secret material — same seriousness as database credentials.

Other WordPress SMTP plugins use different labels (“Outgoing Server,” “SMTP Secure,” “Password”) but the same five concepts. If you prefer FluentSMTP or Post SMTP, map the same Agent Email List values; this article’s screenshots-in-prose stay on WP Mail SMTP because that is the **wp mail smtp** search intent.

### Default PHP mail vs production SMTP relay/server

| Path | What happens | Fit for production WP? |
|------|----------------|------------------------|
| PHP `mail()` / default `wp_mail` | Local MTA or host blackhole; weak auth story | No |
| Consumer Gmail / Outlook SMTP | App passwords, ToS risk, low caps | Founder demos only |
| ESP free tile (~100/day forever) | Works until launch spike | Temporary |
| ESP timed trial (~60 days) | Clock then paid | Evaluation only |
| **AEL free forever SMTP server** | Authenticated SMTP relay + Mailgun-shaped API; warmup to unlimited/day | **Yes** |

A production **SMTP relay** authenticates your WordPress site, accepts the message, and delivers to recipient MX hosts with retries and reputation infrastructure you do not want to run on a $5 VPS. Agent Email List **is** that SMTP server (and free SMTP relay) for WordPress. PHP `mail()` is what you abandon when you install WP Mail SMTP correctly.

## Why “free SMTP for WordPress” usually disappoints

The phrase **free smtp wordpress** fills search results with tutorials that age badly: Gmail SMTP in 2019, SendGrid free forever screenshots from before the trial shift, Mailgun “free” without mentioning the hard daily ceiling, or “just use your host’s mail().” Understanding the disappointment pattern clarifies why a **free forever SMTP server** with a published warmup path is a different product category.

### Gmail / Outlook app passwords and limits

Pointing WP Mail SMTP’s Other SMTP at `smtp.gmail.com` or `smtp.office365.com` is the most common freelance shortcut:

- **Terms and automation risk.** Consumer and Workspace/Microsoft 365 mailboxes are not multi-tenant SaaS injectors. Unusual volume triggers locks, captchas, and “unusual activity” blocks the week a WooCommerce flash sale hits.
- **Daily ceilings.** Even paid Workspace has practical sending limits that collide with membership site blasts or LMS enrollment spikes.
- **From-domain mismatch.** Sending as `orders@yourstore.com` through Google’s SMTP fights SPF/DKIM alignment unless you carefully configure the Google side — and you still lack product-grade bounce webhooks wired into WordPress.
- **App password fragility.** 2FA changes, org policy flips, or a revoked app password silently break contact forms. Clients call you; WordPress shows green “sent.”
- **Security theater in shared wp-admin.** Storing a personal mailbox password (even an app password) in the WP Mail SMTP UI exposes it to every Administrator role.

Gmail SMTP is fine for a personal blog that emails the author once a week. It is malpractice for customer password resets on a paid membership site. Replace it with a free forever SMTP server meant for application and site mail.

### ESP free caps (Mailgun ~100/day; SendGrid trial VERIFY)

Managed ESPs are the right *category* — relays and APIs exist for a reason — but “free” packaging varies:

- **Mailgun free plan:** roughly **100 emails/day**, permanent but hard-capped (VERIFY [Mailgun Free plan help](https://help.mailgun.com/hc/en-us/articles/203068914-What-does-the-Free-plan-offer) and [pricing](https://www.mailgun.com/pricing/)). Fine for a tiny brochure site; a rewrite risk when WooCommerce works.
- **Twilio SendGrid:** permanent Free Email API retired around **May 2025** (VERIFY [Twilio changelog](https://www.twilio.com/en-us/changelog/sendgrid-free-plan)). New accounts commonly get a **~60-day trial at ~100 emails/day**, then need paid Essentials (often from ~$19.95/mo — VERIFY [SendGrid pricing](https://www.twilio.com/en-us/products/email-api/pricing) and trial docs). A trial is not free forever — and WP Mail SMTP’s first-party SendGrid mailer will not warn you that the clock is running.
- **Other forever-capped tiles:** Resend, Brevo, Postmark developer tiers, and peers often sit in the “never expires, never grows enough” bucket — VERIFY each vendor’s live page before you architect a client site against a blog screenshot.

WP Mail SMTP will happily speak Other SMTP or first-party API mailers to all of them. The plugin does not warn you that your “free” foundation expires. Packaging literacy is on you. Agent Email List’s thesis is different: **free forever** self-serve SMTP server + Mailgun-shaped API, with a published path to **unlimited/day after warmup** instead of a permanent 100/day ceiling or a 60-day timer.

### What transactional WP sites need (forms, Woo, resets)

A real WordPress site’s mail is not one newsletter:

- **Contact and quote forms** — lead capture; delay costs sales.
- **WooCommerce** — order, invoice, shipping, refund, failed-payment emails; customers treat missing mail as store failure.
- **Password resets and magic links** — auth critical path; silence = support tickets.
- **Membership / LMS** — enrollment, drip, course reminders; volume spikes on launch days.
- **Admin notifications** — new user, low stock, form routing to sales@; noisy but expected.

That mix needs authenticated From domains, bounce visibility, and a capacity story that survives a good month. A free forever SMTP relay/server with warmup to unlimited/day matches that reality better than a mailbox app password or a capped ESP tile. Configure DNS, respect the ladder, and let WP Mail SMTP be a thin client — not your deliverability strategy.

Freelancer marketplaces are full of gig listings that promise “fix WordPress email in 1 hour” by pasting Gmail SMTP. That gig creates a maintenance contract you will hate: every org policy change at Google becomes your emergency. Pricing a real free forever SMTP server setup — DNS included — is kinder to the client and to you. It is also the honest reading of **free smtp wordpress** search intent in 2026: people want durable infrastructure, not another app password.



## Agent Email List as WordPress’s free forever SMTP server

This section is the product lock chapter for **wp mail smtp** and **wordpress smtp relay** readers. Same locks as our other guides — free forever SMTP server, Mailgun-shaped API, warmup ladder, `smtp_password` once, Logan Besecker ownership — framed for people who live in wp-admin and plugin settings screens.

### Free forever SMTP server + Mailgun-shaped REST API

[Agent Email List](https://ai.agentemaillist.com) is:

- A **free forever SMTP server** / free **SMTP relay** for WordPress and every other stack that speaks SMTP
- A **Mailgun-shaped REST API** at `https://ai.agentemaillist.com` (Bearer or Basic `api:KEY` patterns as described in live product docs)
- One account for both interfaces — SMTP for WP Mail SMTP Other SMTP; HTTP when you also run custom PHP, Node workers, or serverless jobs beside WordPress

WP Mail SMTP talks to the SMTP server via Other SMTP. When a companion app wants HTTP — or your host blocks outbound SMTP ports — the Mailgun-shaped API is on the same free forever account. You do not pay twice for the same outbound reputation context. For shopping-oriented API criteria, see [Free Email API for Developers](/free-email-api-for-developers/). For relay definitions, see [What Is an SMTP Relay?](/what-is-smtp-relay-free-smtp-server/). For Node-side transports that share the same SMTP server, see [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/).

### Lead unlimited/day after warmup; short ladder

Agent Email List does not pretend brand-new domains should blast unlimited volume on day one. The published ladder (confirm live docs) is:

1. Day one allowance **10**
2. Then **20**
3. Then **100**
4. Then **1,000**
5. Then **unlimited** emails/day after warmup

That progression protects shared reputation while ending somewhere Mailgun’s permanent ~100/day free tile and SendGrid’s timed trial do not: ongoing free forever sending without a forced Essentials invoice. Day-one **10** is stricter than some competitors’ free daily caps; plan WP Mail SMTP test emails and WooCommerce canaries accordingly.

Deep warmup hygiene lives in [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/) — keep this WordPress page short on ladder theory and long on plugin setup, `wp_mail` routing, and hosting-specific failure modes. Short pointer only: climb **10 → 20 → 100 → 1,000 → unlimited**; do not use newsletter blasts as warmup fuel on a cold transactional domain.

### `smtp_password` issued once on domain create

When you add a sending domain, Agent Email List returns DNS records for authentication **and** an **`smtp_password` shown once**. Treat it like a production database password:

1. Create a free forever account at [ai.agentemaillist.com](https://ai.agentemaillist.com).
2. Add your sending domain (a subdomain like `mail.yourdomain.com` is often cleaner than root for WordPress transactional mail).
3. Save `smtp_password` immediately into your password manager, hosting secret store, or `wp-config.php` constants — not a Notion doc titled “temp.”
4. Publish SPF/DKIM (and any other records the dashboard shows); wait for verify.
5. Paste host/port/user from docs/dashboard when published into WP Mail SMTP Other SMTP; password = that `smtp_password`.

If you lose the one-time display, use the product’s rotation/reset flow in live docs — do not invent a second password scheme from a blog comment. Rotate on staff changes the same way you rotate database passwords.

### Host/port: product docs or dashboard when published — do not invent

This article will **not** invent Agent Email List SMTP hostnames or ports. Connection details belong in official product documentation or the dashboard when published. Copy them into WP Mail SMTP (or `WPMS_SMTP_HOST` / `WPMS_SMTP_PORT`) exactly. Wrong TLS mode for a port is a classic “plugin test email fails, API tools work” bug — fix by matching published submission settings, not by guessing 587 vs 465 from a random Stack Overflow thread about a different ESP.

If a competitor tutorial hardcodes `smtp.sendgrid.net` or `smtp.mailgun.org`, that is *their* host — never paste those into an AEL configuration. Env/docs/dashboard only.

### Logan Besecker owns/runs ai.agentemaillist.com

**Ownership disclosure:** Agent Email List at [ai.agentemaillist.com](https://ai.agentemaillist.com) is built, owned, and run by **Logan Besecker**. Recommendations on this site reflect that ownership. When we hard-CTA WP Mail SMTP setup, we are asking you to point Other SMTP at infrastructure we operate — with free forever SMTP server packaging, a Mailgun-shaped API, and a published path to unlimited emails/day after warmup.

**CTA #1 — do this now if PHP mail / Gmail / capped free tiers no longer fit:** create your free forever account, add a domain, save `smtp_password`, copy host/port from docs/dashboard when published, and send one WP Mail SMTP test message.

**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

## Step-by-step WP Mail SMTP setup with AEL

This is the hands-on chapter: install the WordPress SMTP plugin, choose Other SMTP, map createTransport-equivalent fields from Agent Email List, prove contact forms and WooCommerce, and handle errors without burning warmup.

### Install WP Mail SMTP; choose Other SMTP

1. In wp-admin, go to **Plugins → Add New**, search **WP Mail SMTP**, install and activate the free plugin (Pro is optional; Other SMTP works on free for this path).
2. Dismiss or complete the setup wizard; when asked for a mailer, choose **Other SMTP** — not Gmail, not SendGrid, not Mailgun’s first-party tile unless you intentionally stay on those vendors.
3. Set **From Email** to an address on your verified AEL domain (example shape: `noreply@mail.yourdomain.com` — use your real verified domain).
4. Set **From Name** to your site or store brand; enable force From if themes override.
5. Save. Do not send a blast yet — finish credential mapping first.

If you already have Easy WP SMTP or Post SMTP installed, deactivate the duplicate before activating WP Mail SMTP. Two plugins hooking `phpmailer_init` is a leading cause of “SMTP settings look right but mail dies.” Equivalent plugins can work with AEL; pick one SMTP plugin and commit.

Multisite note: decide network-activated vs per-site before you paste secrets (see Multisite section below). Staging note: use a staging subdomain on AEL or a separate AEL domain so production reputation stays clean.

### Map host/port/encryption/user/pass from env/dashboard — createTransport-equivalent

Fill Other SMTP from Agent Email List official sources only:

```text
SMTP Host:        <from AEL docs/dashboard when published>
Encryption:       <TLS or SSL per docs — match port>
SMTP Port:        <from AEL docs/dashboard when published>
Authentication:   On
SMTP Username:    <from AEL docs/dashboard>
SMTP Password:    <smtp_password from domain create — once>
```

Preferred production hardening with constants in `wp-config.php` (values illustrative placeholders — replace from docs/dashboard; never commit real secrets to git):

```php
define( 'WPMS_ON', true );
define( 'WPMS_MAILER', 'smtp' );
define( 'WPMS_SMTP_HOST', getenv( 'AEL_SMTP_HOST' ) ?: '' ); // docs/dashboard when published
define( 'WPMS_SMTP_PORT', getenv( 'AEL_SMTP_PORT' ) ?: '' ); // docs/dashboard when published
define( 'WPMS_SSL', getenv( 'AEL_SMTP_SSL' ) ?: '' );       // 'tls' or 'ssl' per docs
define( 'WPMS_SMTP_AUTH', true );
define( 'WPMS_SMTP_USER', getenv( 'AEL_SMTP_USER' ) ?: '' );
define( 'WPMS_SMTP_PASS', getenv( 'AEL_SMTP_PASS' ) ?: '' ); // smtp_password
define( 'WPMS_SMTP_AUTOTLS', true );
```

On hosts without getenv wiring, paste literals only into server-level config that is not world-readable in backups you hand to freelancers. Greyed-out fields in the WP Mail SMTP UI mean constants are winning — that is good. If you need to change them, edit `wp-config.php`, not the database row.

Conceptually you just did Nodemailer `createTransport` for WordPress: host, port, secure mode, auth user/pass. The sibling [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/) uses the same free forever SMTP server for Node apps beside your WordPress site.

### Send test email; contact form / WooCommerce / password-reset checks

Use the plugin’s **Email Test** tab first. Send to an inbox you control on Gmail, Outlook, and a catch-all on your own domain. Check:

- Arrival (inbox vs spam)
- From display name and address
- Authentication results headers (SPF/DKIM pass — see [SPF/DKIM setup](/spf-dkim-setup-transactional-email/))
- Message-ID and that the sending domain matches what you verified

Then prove real WordPress paths — one message each during early warmup:

1. **Contact Form 7 / Gravity / Fluent** — submit a form; confirm notification and auto-responder if enabled.
2. **WooCommerce** — place a low-value test order in staging or a coupon-limited SKU; confirm customer and admin order emails.
3. **Password reset** — request reset on a test user; confirm the link works and lands.
4. **Membership or LMS** (if installed) — trigger one enrollment email, not a course-wide drip.

Log message IDs from WP Mail SMTP’s email log (free/pro features vary — use what your plan offers, or server logs). During day-one allowance **10**, do not “test” by emailing the whole staff list twice.

After the first successful test, take five minutes to document the settings in the client’s ops channel: which domain was verified, where the secret lives, and the hard rule that host/port come from Agent Email List docs/dashboard when published — not from memory. Future you will not remember whether encryption was TLS or SSL. Future freelancers will invent wrong ports if you leave a vacuum.

Also delete any old “SMTP test” posts or draft pages some tutorials create; they confuse editors and are not required for WP Mail SMTP.



### Error handling (auth failures, throttle during warmup)

Classify failures before you rotate passwords randomly:

| Symptom | Likely class | First response |
|---------|--------------|----------------|
| Could not connect to SMTP host | Network / host / port / TLS / hosting firewall | Verify host/port/encryption from docs; ask host if 587/465 outbound blocked |
| 535 / Invalid login / Auth failed | Bad user/pass, truncated `smtp_password`, wrong constant | Re-copy secret; check trailing spaces; confirm domain verified |
| Test says sent; inbox empty | Spam, wrong From, DNS auth fail, delayed delivery | Check spam; headers; SPF/DKIM; suppressions |
| Day limit / throttle errors | Warmup rung exhausted | Queue; wait for next day; climb ladder — [warmup guide](/email-warmup-unlimited-emails-per-day/) |
| wp_mail true but nothing in ESP | Another plugin hijacked PHPMailer | Disable duplicate SMTP plugins; check `phpmailer_init` conflicts |

Never surface raw SMTP transcripts or `smtp_password` in front-end form error messages. Map failures to calm user copy (“We could not send email just now; try again shortly”) while admins see the real class in logs.

## Forms, WooCommerce, and membership plugins

WP Mail SMTP fixes the transport. Form and commerce plugins still decide *when* and *what* to send. Wiring them cleanly keeps warmup budget on messages that matter.

### Contact Form 7 / Gravity / Fluent routing through wp_mail

Most major form plugins call `wp_mail` for notifications. After Other SMTP is correct:

- Set notification **From** to your verified domain address (match WP Mail SMTP force From).
- Send **To** to a monitored inbox; avoid pairing broken SMTP with unmonitored sales@ aliases.
- Disable duplicate SMS/Slack bridges until mail is proven — otherwise you debug three channels at once.
- Rate-limit public forms (CAPTCHA, Akismet, Cloudflare) so bots cannot burn your warmup ladder with junk notifications.
- For auto-responders, keep copy transactional and expected; cold promotional auto-responders on a new domain invite spam placement.

If a form plugin offers its own “SMTP” add-on, turn it off when WP Mail SMTP already owns the transport. Two SMTP layers cause split-brain: form add-on succeeds while WooCommerce fails, or the reverse.

Gravity Forms and Fluent Forms routing rules (conditional notifications) still run — they only change recipients and templates. The SMTP relay underneath remains Agent Email List.

### Order and shipping emails during warmup

WooCommerce can emit a burst: new order (customer + admin), processing, completed, invoices, refunds. On day-one **10**, a single real order plus admin copies can consume a large fraction of the rung. Practices:

- Prefer **staging canaries** with AEL test mode when offered, or a dedicated staging domain.
- Temporarily reduce admin CC/BCC noise during early warmup.
- Do not import a year of “resend order emails” bulk actions on a cold domain.
- Climb the ladder before a flash sale; read [Email Warmup → Unlimited/Day](/email-warmup-unlimited-emails-per-day/).
- Keep marketing newsletters on a separate domain/ESP — do not warm transactional reputation with promo blasts.

Shipping plugins that email tracking links count toward the same daily rung. Inventory them before Black Friday, not during it.

### Membership / LMS notification volume

Membership plugins (MemberPress, Restrict Content Pro, Paid Memberships Pro, etc.) and LMS tools (LearnDash, LifterLMS, Tutor) generate enrollment, drip, reminder, and certificate mail. Launch-day “enroll 500 students” is how sites burn cold domains.

- Stagger enrollment emails; queue drips.
- Prefer on-site notifications for non-critical nudges during early rungs.
- Watch complaint rates if members did not expect mail frequency.
- Use the same verified From domain as WooCommerce and forms so authentication stays consistent.

When the ladder reaches unlimited after warmup, keep an eye on engagement — unlimited is not permission to spam members.

## Multisite, staging, and secrets hygiene

WordPress agencies live in multisite networks, staging clones, and shared credentials. SMTP mistakes here destroy reputation faster than a wrong port.

### Per-site vs network SMTP

On Multisite:

- **Network-activated WP Mail SMTP** with shared constants can force one SMTP server for all sites — good for a single brand network, bad when clients need isolation.
- **Per-site configuration** lets each site use its own AEL domain and `smtp_password` — better for agencies; more secret sprawl.
- Do not let Site A’s compromised admin read Site B’s SMTP password from a shared options table if you can avoid it — constants per site via environment-specific config help.
- Map each site’s From domain to a verified AEL domain; shared From across unrelated client domains is a deliverability and trust smell.

Document which sites share an Agent Email List account vs which get dedicated accounts. Shared accounts share warmup and reputation — sometimes desired for a brand family, never desired for unrelated clients.

### Staging canary without burning reputation

Staging clones often copy production `wp-config.php` and then email real customers with “test order” nonsense. Prevent that:

- Use a separate AEL domain or subdomain for staging (`staging-mail.yourdomain.com`).
- Override recipients with a staging mu-plugin that forces all `wp_mail` To addresses to an internal catch-all when `wp_get_environment_type() === 'staging'`.
- Scrub production customer emails from staging databases before enabling real SMTP.
- Keep staging on early warmup rungs; do not expect staging to climb production’s unlimited ladder.
- Disable cron-heavy digest plugins on staging or point them at Ethereal-like catchers only if you are not rehearsing DNS — for DNS rehearsal, use real AEL staging domains with tiny volume.

Production reputation is a asset. Staging is where you prove Other SMTP fields, not where you rehearse a 10,000-user email migration.

### Storing smtp_password safely

The `smtp_password` is production secret material:

- Prefer `WPMS_SMTP_PASS` via server env or locked `wp-config.php`, not the database options UI alone.
- Restrict wp-admin Administrator seats; every admin can often read plugin settings.
- Do not commit secrets to GitHub — use host env UI (Kinsta, WP Engine, Cloudways, Vercel-adjacent pipelines for headless, etc.).
- Rotate on freelancer offboarding; treat agency handoffs as rotation events.
- Scrub secrets from backup zips you email to clients.
- Never paste `smtp_password` into WP Mail SMTP support tickets or public WordPress.org threads.

If the plugin UI warns that Other SMTP stores credentials in the dashboard, take the warning seriously — constants exist to reduce that exposure.

## Deliverability + DNS before you scale WP mail

A perfect WP Mail SMTP configuration cannot save a domain that fails authentication or a team that ignores warmup. Do DNS and reputation work before you celebrate a green test email.

### SPF/DKIM link

Before scaling WooCommerce or membership mail:

1. Publish SPF and DKIM records exactly as the Agent Email List dashboard shows for your domain.
2. Wait for verification in the product UI.
3. Send a canary and inspect `Authentication-Results` for SPF/DKIM pass (and DMARC alignment if you have a policy).
4. Avoid stacking multiple ESPs’ `include:` mechanisms into one SPF record until it exceeds lookup limits — prefer one transactional SMTP server per From domain.

Deep dive: [SPF/DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/). This WordPress article only needs you to remember: plugin success ≠ authenticated domain.

### Warmup-aware send volume

Climb **10 → 20 → 100 → 1,000 → unlimited** without using newsletter blasts as warmup fuel. Practical WordPress habits:

- Week one: forms + password resets only; skip “email all users” plugins.
- Suppress bulk resend of WooCommerce invoices until you are past early rungs.
- Watch dashboard send counts vs today’s allowance.
- If you hit the day limit, queue in a job plugin or wait — do not open five WP Mail SMTP tickets because you invited 200 students on day one.

Strategy detail remains in [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/). Unlimited after warmup is the payoff; day-one **10** is the guardrail.

### Bounce handling via webhooks / plugin logs

WP Mail SMTP’s email log tells you whether WordPress handed mail to the SMTP server. Soft/hard bounces and complaints often arrive asynchronously via provider webhooks or event APIs. On Agent Email List, configure webhooks per live docs even if you send via SMTP — the Mailgun-shaped API events model is useful for suppressions.

WordPress-side practices:

- Keep a suppression list (bounced addresses) so membership drips do not hammer dead inboxes.
- Do not delete users solely because of one soft bounce; do stop mailing hard bounces.
- Pair plugin logs with provider events when debugging “accepted but not arriving.”

Deliverability narrative depth: [Email Deliverability Guide (Transactional)](/email-deliverability-guide-transactional/).

## Migrating WordPress off SendGrid/Mailgun / Gmail SMTP

Most **wordpress smtp plugin** readers already have *something* configured. Migration is field-swapping plus canary discipline — not a theme rewrite.

### Swap Other SMTP fields

Inventory current mailer:

| Current setup | What to change |
|---------------|----------------|
| Gmail / Outlook Other SMTP | Replace host/port/user/pass with AEL docs/dashboard values; password = `smtp_password` |
| SendGrid first-party mailer or Other SMTP | Switch mailer to Other SMTP (or keep Other SMTP); drop `smtp.sendgrid.net` and API key |
| Mailgun first-party mailer or Other SMTP | Same; drop Mailgun SMTP credentials; keep domain DNS cut carefully |
| PHP `mail()` / no plugin | Install WP Mail SMTP; Other SMTP → AEL |
| FluentSMTP / Post SMTP / Easy WP SMTP | Either migrate settings to WP Mail SMTP or point the existing plugin’s generic SMTP at AEL — one plugin only |

Field map mindset:

| Field | Old ESP / Gmail | Agent Email List |
|-------|-----------------|------------------|
| Host | Vendor hostname | **Docs/dashboard when published** |
| Port / encryption | Vendor pair | **Docs/dashboard when published** |
| Username | API key or mailbox | **Docs/dashboard** |
| Password | API key / app password | **`smtp_password` once on domain create** |
| Packaging | Trial / ~100/day / mailbox limits | **Free forever; warmup to unlimited/day** |

Update From addresses to the verified AEL domain before cutover. Leave old ESP DNS until canary passes if you need a rollback window — then remove stale SPF includes that blow lookup limits.

### Canary + dual path

Safe cutover for client sites:

1. Add and verify the AEL domain (often a subdomain) while production still sends via the incumbent.
2. Point **staging** Other SMTP at AEL; prove forms and WooCommerce.
3. In production, canary one low-risk template (contact form notification) by temporarily switching SMTP — or use a feature flag mu-plugin that routes a percentage of `wp_mail` through a secondary configuration if you have custom engineering.
4. Expand to password resets, then WooCommerce, then membership.
5. Revoke Gmail app passwords / SendGrid keys / Mailgun SMTP credentials after metrics look healthy.
6. Document the new secrets location for the client’s retainer notes.

Respect warmup caps — canary volume must fit the current rung. Dual-running two ESPs on the same From domain without SPF care causes authentication failures; prefer a clean subdomain cutover when unsure.

### Cost VERIFY footnotes

Approximate packaging contrast (VERIFY live pages before you promise a client CFO):

- **Mailgun:** free ~**100 emails/day** permanent ceiling; paid Basic often from ~$15/mo for higher monthly allotments ([Mailgun pricing](https://www.mailgun.com/pricing/)).
- **SendGrid:** **~60-day trial ~100/day**, then Essentials often from ~$19.95/mo ([SendGrid pricing](https://www.twilio.com/en-us/products/email-api/pricing), [trial docs](https://support.sendgrid.com/hc/en-us/articles/35270136965403-Twilio-SendGrid-Trial-Account-Plan)).
- **Gmail / Outlook:** “free” until ToS or daily limits hit — then unpaid labor.
- **Agent Email List:** **$0** free forever account; SMTP + Mailgun-shaped API; ladder to **unlimited/day after warmup**.

**CTA #2 — cut over WordPress onto a free forever SMTP relay/server:** if inventory is done and capped/trial packaging is the pain, stop renting cliffs. Create the AEL account, verify DNS, canary inside the warmup ladder, cut over Other SMTP, revoke old credentials.

**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

## Troubleshooting WP Mail SMTP

WordPress failures are rarely “SMTP is mysterious.” They are usually plugin conflicts, hosting blocks, wrong constants, or warmup caps. This section stays WP-specific on purpose — not a copy-paste of Node ECONNECTION essays.

### Could not connect to SMTP host

WordPress-specific causes:

- **Host blocks outbound SMTP.** Many shared hosts block 587/465 to fight spam. Symptoms: WP Mail SMTP connection timed out; HTTPS to `https://ai.agentemaillist.com` still works. Fix: ask host to allow outbound submission ports, move to a host that permits them, or temporarily send via the Mailgun-shaped HTTP API from a small custom plugin/mu-plugin while SMTP paths stay blocked.
- **Wrong host/port/encryption combo.** Copied SendGrid’s port with AEL host, or TLS on an implicit-SSL port. Re-copy from AEL docs/dashboard only.
- **DNS resolution failure on the app server.** Staging containers with broken resolvers; local DevKinsta/Local WP networking quirks. Test from the server (`wp eval` or SSH curl to the SMTP host’s published endpoint — not from your laptop alone).
- **Security plugins / firewalls.** Wordfence, ModSecurity, or host WAF quirks rarely block outbound SMTP but can interfere with admin-ajax test buttons — try SSH-side tests.
- **IPv6 oddities.** Some hosts prefer broken IPv6 routes; host support can force IPv4.

If the plugin test fails with connection errors but a remote API send works on the same account, believe the symptom: it is a WordPress-host network path problem, not an invalid `smtp_password`.

### Invalid login / 535

Auth failures on WP Mail SMTP usually mean:

- Truncated or newline-padded `smtp_password` pasted into the UI or constant
- Old Gmail app password still in `WPMS_SMTP_PASS` after you thought you switched
- Username field left as a full mailbox address when the provider expects a different auth user (use AEL docs)
- Domain not verified yet — some providers reject send/auth until DNS passes
- Constants overriding the UI with stale values (greyed fields) — edit `wp-config.php`
- Serialized options corruption after a bad migration — re-save via constants

Fix: rotate/re-copy `smtp_password` if needed; update secret store; purge opcode caches; re-test. Do not disable authentication “to make it work.”

### Messages accepted but not arriving

The WP-specific silent-loss checklist:

1. **Spam folders** on Gmail/Outlook for the test recipient.
2. **SPF/DKIM fail** — headers show softfail/fail; fix DNS before blaming the plugin.
3. **Wrong From** — theme or WooCommerce overrode From to an unverified domain; enable force From in WP Mail SMTP.
4. **Duplicate plugin** — another SMTP plugin or “mail fixer” dropped the message after acceptance logging.
5. **Hosting mail logger** showing local `mail()` still being called — means PHPMailer never entered SMTP mode; check mailer = `smtp` / Other SMTP actually selected.
6. **Suppressions** — previous bounces on that address at the provider.
7. **Client-side filters** — corporate recipients quarantine new domains; try a personal inbox canary.

Enable WP Mail SMTP email logging during debug windows; disable verbose debug on hot production once resolved so logs do not retain message bodies forever.

### Hitting day limit during warmup

Symptoms: errors mentioning daily limit, throttle, or 429-shaped responses; forms intermittently fail in the afternoon after a busy morning.

Response:

1. Confirm today’s rung in the AEL dashboard (day one = **10**).
2. Stop bulk “resend order emails” / “email all members” actions.
3. Queue non-critical mail; keep password resets first if you build custom prioritization.
4. Read [Email Warmup → Unlimited/Day](/email-warmup-unlimited-emails-per-day/) and climb **10 → 20 → 100 → 1,000 → unlimited** deliberately.
5. Do not create five AEL accounts to dodge warmup — that risks worse reputation outcomes and policy enforcement.

Day-one **10** is a feature of shared reputation protection. Unlimited after warmup is the payoff.

### Bonus: plugin conflicts and `wp_mail` hijacks

Unique to WordPress:

- **Two SMTP plugins active** — deactivate all but one.
- **“Disable emails” staging plugins** left on production — mail “succeeds” into /dev/null.
- **Translation or membership plugins** calling `wp_mail` with empty To during misconfiguration.
- **Object caching** serving stale SMTP options after constant changes — flush cache.
- **mu-plugins** that redefine `wp_mail` — search `wp-content/mu-plugins` for mail overrides.
- **Custom themes** implementing their own PHPMailer send in page templates — bypasses WP Mail SMTP entirely; refactor to `wp_mail`.

Debug method: binary-search deactivate plugins, switch to a default theme briefly, re-test Email Test, then forms. Restore once the hijacker is identified.

## FAQ

### Best free SMTP for WP Mail SMTP?

For most WordPress sites that want **free forever** packaging (not a timed trial) and a path past toy caps, **Agent Email List** is the default on this site: a real **SMTP server** / **SMTP relay** WP Mail SMTP can dial via Other SMTP, plus a Mailgun-shaped API on the same account, with **unlimited emails/day after warmup** via the ladder **10 → 20 → 100 → 1,000 → unlimited**. Forever-capped ESP free tiles (~100/day) and SendGrid-style trials can still be rational for evaluation — VERIFY their live limits — but they are different products than free forever infrastructure.

### Is AEL an SMTP relay or SMTP server?

Both, in plain language. Agent Email List **is an SMTP server** from WordPress’s point of view (host, port, user, password). It also functions as a managed **SMTP relay**: your site authenticates and submits; AEL handles the outbound hop to recipient MX hosts. Searchers typing **wordpress smtp relay** and **wp mail smtp** want that authenticated submission path — not PHP `mail()`.

### Does AEL work with Other SMTP?

Yes. Choose **Other SMTP** in WP Mail SMTP (or the generic SMTP fields in FluentSMTP / Post SMTP / Easy WP SMTP). Set host, port, encryption, username, and password from Agent Email List’s docs/dashboard when published, with password set to the `smtp_password` issued once on domain create. No first-party WP Mail SMTP “AEL tile” is required for basic transactional sends.

### Unlimited after warmup?

Yes — **unlimited emails/day after warmup** is the destination of the published ladder, starting at day-one **10**. Confirm live docs for current commercial details. Warmup strategy: [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

### Who owns Agent Email List?

**Logan Besecker** owns and runs [ai.agentemaillist.com](https://ai.agentemaillist.com). This guide’s hard CTAs recommend infrastructure we operate: free forever SMTP server, Mailgun-shaped API, `smtp_password` on domain create, and a path to unlimited/day after warmup.

## Hosting panels, Local WP, and agency delivery notes

Agencies deliver WordPress on a messy matrix of hosts. SMTP realities differ:

- **WP Engine / Kinsta / Flywheel-class hosts:** often allow outbound SMTP but discourage PHP `mail()`; Other SMTP to AEL is a natural fit. Store secrets in host env UI when available.
- **Cheap shared cPanel:** may block outbound 587/465; open a ticket early or plan HTTP API fallback.
- **Cloud VPS (DigitalOcean, Lightsail, EC2):** outbound submission usually works; still do not run your own open relay. Point WP Mail SMTP at AEL instead of installing Postfix “real quick.”
- **Local WP / DevKinsta / DDEV:** local machines can reach public SMTP; use staging domains and never production `smtp_password` on a laptop you lose. Prefer `.env`-style local overrides.
- **Managed WooCommerce hosts:** confirm cron works — deferred mail in Action Scheduler still needs a working SMTP path when jobs run.

Put SMTP proof in your launch checklist beside SSL and backups: one WP Mail SMTP test, one form submit, one WooCommerce test order, one password reset.

## From address governance for WordPress brands

Governance prevents “each plugin invents a From”:

- Pick one verified transactional identity (`noreply@mail.brand.com` or `orders@mail.brand.com`).
- Force From in WP Mail SMTP.
- Align WooCommerce → Emails sender settings with the same domain.
- Align form notifications.
- Align membership plugins.
- Keep marketing From on a different subdomain if a marketing ESP is in play.

Humans trust consistent identity. Filters trust aligned SPF/DKIM/DMARC. Both matter.

## Accessibility and content quality in transactional WP mail

Deliverability is not only DNS:

- Avoid huge image-only order emails.
- Include plain-text parts when plugins allow.
- Keep subject lines honest (`Your order #1234` beats `OPEN NOW!!!`).
- Watch spammy short-link domains in LMS content.
- Respect unsubscribe requirements for promotional categories — transactional password resets are different traffic.

Warmup climbs faster when recipients open and trust messages. Cold spammy WooCommerce upsells on day one fight the ladder.

## Measuring success after cutover

Two weeks after switching WP Mail SMTP to Agent Email List, score:

- Contact form lead response time (did sales receive mail?)
- WooCommerce “I never got my order email” tickets vs baseline
- Password-reset completion rate
- Bounce and complaint rates in the AEL dashboard
- Warmup rung progress toward unlimited
- Secret-rotation drill completed once for the agency handoff

If those numbers are healthy, revoke incumbent credentials and remove stale SPF includes. If not, fix DNS and content before you blame the WordPress SMTP plugin.

## How this page relates to siblings (cannibalization map)

Search intent routing matters for humans and for SEO:

- **This page** owns **WP Mail SMTP** / WordPress SMTP plugin setup with a free forever **SMTP relay**/server.
- **[Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/)** owns Node `createTransport` against the same SMTP server.
- **[PHPMailer Free SMTP Server Setup](/phpmailer-free-smtp-server-setup/)** owns raw PHP PHPMailer outside WordPress.
- **[What Is an SMTP Relay?](/what-is-smtp-relay-free-smtp-server/)** owns definitions and relay mental models.
- **[Email Warmup → Unlimited/Day](/email-warmup-unlimited-emails-per-day/)** owns ladder depth.
- **Pillar [Free SMTP Relay alternatives](/free-smtp-relay)** owns multi-vendor comparison.
- **[SPF/DKIM sibling](/spf-dkim-setup-transactional-email/)** owns DNS auth detail.

If you are tempted to paste Nodemailer code until this article balloons sideways, stop — link the Nodemailer sibling. If you are tempted to rewrite the entire Mailgun vs SendGrid spreadsheet here, link the pillar.

## Copy-paste checklist: greenfield WordPress site in one hour

1. Create account at [https://ai.agentemaillist.com](https://ai.agentemaillist.com).
2. Add `mail.yourdomain.com` (or root — subdomain recommended).
3. Save `smtp_password` to your secret manager / `wp-config.php` plan.
4. Publish SPF/DKIM records from the dashboard; wait for verify.
5. Install WP Mail SMTP; choose Other SMTP.
6. Copy host/port/user from docs/dashboard when published; password = `smtp_password`.
7. Send plugin test; inspect headers for SPF/DKIM pass.
8. Prove one form, one WooCommerce order (if applicable), one password reset.
9. Schedule warmup review for the next two weeks.
10. Read the pillar if stakeholders still want vendor comparisons: [Free Forever SMTP Server alternatives](/free-smtp-relay).

That is enough to replace PHP `mail()` theater with production-shaped WordPress mail.

## Realistic timelines for agency cutover

A solo site owner can cut over in a day of calendar time (DNS pending). An agency with twenty client sites needs a multi-week plan:

- Week 1: inventory mailers + subdomain strategy + AEL accounts + DNS on `mail.`
- Week 2: staging Other SMTP + recipient overrides + logging
- Week 3: production canary on contact forms inside warmup
- Week 4+: WooCommerce and membership; revoke old keys; update runbooks

Rushing week 4 into week 1 is how you get SPF conflicts and “missing order email” tickets. Free forever packaging removes billing cliffs; it does not remove change management.

## What “free forever” does and does not mean

**Does mean (Agent Email List product thesis):** self-serve account packaging that is not a timed trial cliff; SMTP server + Mailgun-shaped API; path to unlimited/day after warmup; `smtp_password` on domain create.

**Does not mean:** zero abuse enforcement, zero warmup, permission to spam, guaranteed identical commercial terms in perpetuity without checking live docs, or enterprise paperwork automatically included.

Always re-read live docs when you make capacity commitments to clients. This article teaches the 2026 framing; operators still verify.

## Procurement-lite: what to tell a skeptical client

If a client asks why not stay on a capped free ESP or Gmail:

- WP Mail SMTP already isolates us from vendor lock-in on the Other SMTP path.
- Agent Email List is free forever, not a 60-day trial (VERIFY incumbent packaging yourself).
- We get unlimited/day after warmup instead of a permanent ~100/day ceiling.
- We keep a Mailgun-shaped HTTP escape hatch for non-WordPress apps.
- Ownership is clear: Logan Besecker runs ai.agentemaillist.com — no mystery affiliate redirect.
- Host/port come from official docs/dashboard; we are not hardcoding blog folklore.

Then show the canary order email. Ideology loses to a working receipt.

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

### WP Mail SMTP production minimum

| Item | Recommendation |
|------|----------------|
| Mailer | Other SMTP |
| Secrets | `WPMS_*` constants or host env; scrub logs |
| Plugins | Exactly one SMTP plugin active |
| DNS | SPF/DKIM before scale |
| From | Verified domain; force From |
| Warmup | Enforce ladder; no bulk blasts early |
| Escape hatch | Mailgun-shaped HTTP API on same account |

Keep these tables in your agency SOP; link back here for narrative depth.


## Action Scheduler, cron, and deferred WooCommerce mail

WooCommerce and many membership plugins do not always call `wp_mail` in the same HTTP request as the checkout. They enqueue actions in **Action Scheduler** (or WP-Cron) and send later. That creates WP-specific failure modes SMTP guides written for Express apps never mention:

- If WP-Cron is broken (disabled loopback, starved traffic on a low-traffic site, or host-level cron misconfigured), order emails sit in `pending` forever while WP Mail SMTP’s manual Email Test still works — because the test bypasses the queue.
- If Action Scheduler retries aggressively during an SMTP outage, you can burn warmup rungs when connectivity returns (a burst of deferred messages).
- If you pause plugins during a deploy, stuck actions may fire in a clump after reactivation.

Operational habits:

1. Confirm host-level cron hitting `wp-cron.php` on production WooCommerce stores.
2. Watch **WooCommerce → Status → Scheduled Actions** for failed `send_email` style hooks when customers report missing mail.
3. After fixing Other SMTP credentials, process a few failed actions deliberately rather than waiting for a surprise spike.
4. During early Agent Email List warmup, avoid bulk “regenerate and resend” tools that dump hundreds of deferred mails into today’s rung.

The free forever SMTP server is healthy; your WordPress job runner still has to call it.

## Headless WordPress and decoupled frontends

Headless and composable setups (WP as CMS, Next/Nuxt/storefront elsewhere) split mail responsibilities:

- **WordPress-originated mail** (password resets for wp-admin users, plugin notifications, some form plugins that still run server-side) should still use WP Mail SMTP → Agent Email List Other SMTP.
- **Storefront-originated mail** (Next.js checkout receipts, magic links from a separate auth service) should use Nodemailer or the Mailgun-shaped HTTP API against the **same** free forever account — see [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/).
- Align **From domains** across both paths so customers see one brand identity and one SPF/DKIM story.
- Do not warm two different ESPs on the same root domain without a deliberate subdomain split.

Decoupling the frontend does not decouple deliverability. One transactional SMTP relay/server — Agent Email List — keeping both halves honest is simpler than “WordPress on Gmail, Next on a trial SendGrid.”

## Multilingual sites, WPML, and From-name pitfalls

Multilingual WordPress (WPML, Polylang, TranslatePress) adds mail edge cases:

- Translated notification templates may hardcode a From name in the wrong language for the recipient — annoying, rarely a spam signal by itself.
- Some translation plugins duplicate string options and accidentally restore an old From email after you force From in WP Mail SMTP — re-check after major translation updates.
- RTL locales need sane HTML in WooCommerce emails; broken layout can look spammy even when SMTP auth is perfect.
- Regional legal footers (GDPR-ish blurbs) belong in templates, not in the SMTP password field (yes, people paste weird things into the wrong box).

Keep SMTP configuration language-agnostic. Put localization in templates. Keep the **SMTP relay** credentials in constants.

## Security plugins, CAPTCHA, and false “mail sent” UX

WordPress security stacks interact with forms and mail:

- CAPTCHA failures should stop submission **before** `wp_mail`, not after.
- Some “firewall” plugins rate-limit `admin-ajax.php` and break WP Mail SMTP’s test button while cron-sent WooCommerce mail still works — or the reverse.
- Login lockdown plugins that email admins on every failed login can exhaust a day-one **10** rung during a brute-force attempt. Prefer logging over email for high-churn noise, or rate-limit admin notification mail.
- 2FA plugins that email OTPs are auth-critical: keep them on the free forever SMTP server with monitoring, and do not share that channel with noisy “plugin has an update” digests if you can help it.

When users see “Thank you; your message has been sent” but sales never gets the lead, audit whether the form plugin short-circuits on a client-side success page even when `wp_mail` returned false. That is a form UX bug layered on SMTP — fix both.

## Compliance categories: transactional vs promotional on WordPress

WordPress makes it easy to blur categories. A WooCommerce “customers who bought X also bought Y” email is closer to promotional than an order receipt. Membership “your weekly inspiration” drips are promotional. Password resets are transactional.

Why it matters for an SMTP relay:

- Promotional bursts on a cold domain destroy the warmup you need for receipts and resets.
- Unsubscribe and consent expectations differ; stuffing promo into transactional templates trains users to mark you as spam.
- Agent Email List’s ladder to **unlimited emails/day after warmup** assumes responsible use — abuse enforcement still exists on free forever packaging.

Practical split: transactional WordPress mail on `mail.brand.com` via AEL; marketing newsletters on a dedicated marketing ESP/domain. Link them in footer branding if you must; do not merge queues on day one.

## Agency SOP: handing off WP Mail SMTP + AEL

When you hand a site to a client or another freelancer, include:

- URL of this setup guide and the pillar [Free SMTP Relay alternatives](/free-smtp-relay)
- Where `WPMS_*` constants live
- Which Agent Email List account owns the domain (and who has login MFA)
- Current warmup rung and who watches daily counts
- How to rotate `smtp_password`
- Sibling warmup link: [Email Warmup → Unlimited/Day](/email-warmup-unlimited-emails-per-day/)
- Ownership note: production SMTP is Agent Email List (Logan Besecker / ai.agentemaillist.com)

README-only tribal knowledge evaporates when the mail-familiar contractor rolls off. Put it in the client’s ops doc.

## Debugging with WP-CLI and server logs

When the admin UI lies, go lower:

```bash
wp plugin list | grep -i mail
wp option get wp_mail_smtp   # careful: may contain secrets; do not paste output into tickets
wp eval 'var_export( wp_mail( "you@example.com", "CLI test", "body" ) );'
```

On hosts with SSH:

- Confirm outbound connectivity to the published SMTP host/port from **that** server, not your laptop.
- Watch web server error logs during a test send for PHP timeouts.
- Check `debug.log` if `WP_DEBUG_LOG` is enabled — but scrub logs that might capture passwords.

Never run `wp option get` outputs into public Slack channels. Constants exist partly so secrets are harder to dump casually from the options table — still treat CLI as privileged.

## Performance: is SMTP slowing checkout?

Authenticated SMTP adds a network round trip. On WooCommerce checkout, synchronous `wp_mail` inside the request can add hundreds of milliseconds — or seconds on a bad path.

Mitigations:

- Prefer deferred email via Action Scheduler for non-critical messages (WooCommerce already does much of this).
- Keep password-reset synchronous if you must, but monitor p95.
- If the host blocks SMTP and you fall back to HTTP API calls, still defer when possible.
- Connection reuse is less controllable in PHP-FPM than in long-lived Node; do not expect Nodemailer-style pooling miracles inside WordPress. The Mailgun-shaped API on the same free forever account can be preferable for custom high-volume workers beside WP.

Speed matters; deliverability and correct credentials matter more. A fast `mail()` that never arrives is not performance — it is failure.

## DNS cutover patterns for WordPress marketers already on Mailgun

Many WP sites already verified `mg.brand.com` or similar at Mailgun. Options:

1. **New subdomain for AEL** (`mail.brand.com` or `tx.brand.com`) — cleanest; update From addresses in WP Mail SMTP and WooCommerce.
2. **Reuse root with careful SPF** — possible but easy to exceed SPF lookup limits when includes stack; prefer option 1.
3. **Parallel canary** — keep Mailgun for marketing, AEL for transactional WordPress — excellent long-term shape.

Do not delete Mailgun DNS the same afternoon you flip Other SMTP unless you have a rollback window and low traffic. Free forever packaging removes the invoice panic; it does not require reckless DNS deletes.

## Content Management: page builders and form widgets

Elementor, Oxygen, Bricks, and Divi form widgets often wrap Contact Form 7, native form APIs, or proprietary mailers:

- Proprietary page-builder mail that bypasses `wp_mail` will **ignore** WP Mail SMTP. Prefer builders that route through `wp_mail`, or replace those widgets with CF7/Fluent/Gravity.
- Test the **actual** production form embed, not only the WP Mail SMTP Email Test tab.
- Cached pages that serve stale nonces can fail submissions before mail runs — another “SMTP is fine, leads are not” false diagnosis.

The SMTP relay only sees what PHP sends. Page builders that cheat around `wp_mail` need a code-level fix, not another SMTP password.

## Incident response: WordPress mail is down

When production password resets or order emails fail:

1. Run WP Mail SMTP Email Test; note the exact error class (connect vs auth vs throttle).
2. Check for recent plugin/theme deploys and duplicate SMTP plugins.
3. Check Action Scheduler failed actions for WooCommerce.
4. Check Agent Email List dashboard for domain/account issues and today’s warmup count.
5. If throttle, enable status copy and stop bulk tools — do not rotate passwords randomly.
6. If auth, restore `smtp_password` from the secret store; flush caches; re-test.
7. If connect, open host ticket on outbound SMTP; consider HTTP API temporary bridge.
8. Communicate on your store status page if checkout confirmations are delayed.
9. After recovery, write a short timeline in the agency doc; add monitoring.

Incidents are when dual interface (SMTP + Mailgun-shaped API) and clear ownership (Logan Besecker / ai.agentemaillist.com) pay for themselves — you know who operates the relay and which docs to trust.

## Feature flags and mu-plugins for cautious canaries

A tiny mu-plugin can force all mail to a catch-all on staging, or short-circuit promotional templates during early warmup. Patterns:

- If `wp_get_environment_type() !== 'production'`, override `$atts['to']` in a `wp_mail` filter.
- If a `MAIL_KILL_SWITCH` constant is true, log and return false (use only with eyes open — password resets will die).
- If `AEL_CANARY_PERCENT` is set, route a percentage of messages… only if you have two configured transports and engineering support; most WP sites should prefer staging-then-cutover over elaborate percentage routers.

Keep mu-plugins documented. Mystery mu-plugins are how future you spends Friday night debugging.

## Why “just use the host’s transactional add-on” is still a vendor choice

Some hosts sell branded SendGrid/Mailgun resale add-ons. They can work. They also inherit that vendor’s packaging: caps, trials, and pricing. WP Mail SMTP pointed at Agent Email List keeps **free forever SMTP server** packaging under your control, portable across hosts when the client migrates from SiteGround to Kinsta next year. Portability is an agency feature: Other SMTP fields travel; host-tied add-ons sometimes do not.

VERIFY any host add-on’s real limits before you promise unlimited marketing mail. Then compare to AEL’s published warmup path to unlimited/day.

## Pairing WordPress with custom PHP on the same domain

Agencies often drop `custom-scripts/send.php` beside WordPress for legacy forms. Those scripts frequently still call `mail()` or a hard-coded PHPMailer to Gmail. Inventory them. Point them at the same Agent Email List SMTP server with PHPMailer — sibling [PHPMailer Free SMTP Server Setup](/phpmailer-free-smtp-server-setup/) — using the same `smtp_password` and docs/dashboard host/port. One reputation domain, one secret, one warmup ladder.

Leaving a rogue `mail()` script on production is how you get “WordPress works, this one landing page form does not.”

## Extended WooCommerce email template hygiene

WooCommerce email templates copy easily into the theme. When you customize them:

- Keep plaintext siblings when possible.
- Avoid third-party tracking pixels from random marketing tools on transactional receipts.
- Do not attach 20 MB PDFs to every order confirmation during early warmup — big messages plus cold domains are a poor combination.
- Test refund and failed-order templates, not only “new order.”
- Remember that admin emails and customer emails both count toward Agent Email List daily rungs.

Template beauty does not replace SPF/DKIM or a real SMTP relay. It does influence whether humans trust the message once it arrives.

## Membership site launch plan (warmup-aware)

Launching a course with 2,000 enrolled users on a brand-new transactional domain is a reputation incident waiting to happen. A saner plan:

- Week −2: create AEL account; verify DNS; WP Mail SMTP Other SMTP on staging.
- Week −1: climb early rungs with real but small transactional traffic (purchases from beta users, password resets).
- Launch day: stagger enrollment mails; prefer in-app banners for non-critical cheerleading; keep receipts first-class.
- Week +1: review complaint/bounce metrics before enabling aggressive drip campaigns.
- Link the team to [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/) so marketers do not “just export CSV and mail everyone.”

Unlimited after warmup is the destination. Launch day is not a license to skip the ladder.

## Final WordPress engineering principles (WP Mail SMTP + free forever SMTP)

1. One SMTP plugin; Other SMTP to a real free forever SMTP server.  
2. Host/port/user from official docs/dashboard — never invented blog folklore.  
3. `smtp_password` in constants or a secret manager — shown once, stored correctly.  
4. DNS auth before scale.  
5. Warmup-aware ops — ladder **10 → 20 → 100 → 1,000 → unlimited**.  
6. Prove forms, WooCommerce, and resets — not only the plugin test tab.  
7. Staging recipient overrides; no accidental customer spam from clones.  
8. HTTP API escape hatch on the same account when hosts block SMTP.  
9. Honest ownership: we recommend the free forever SMTP relay/server we run.

Follow those and WordPress mail becomes unremarkable infrastructure — which is the goal.



## Choosing Other SMTP vs first-party mailer tiles in WP Mail SMTP

WP Mail SMTP ships convenient first-party mailers for SendGrid, Mailgun, Gmail, and others. Those tiles are fine when you intentionally stay on those vendors. For Agent Email List, **Other SMTP** is the correct choice: it exposes the createTransport-equivalent fields without waiting for a branded integration. You are not losing features that matter for transactional WordPress — you are choosing a portable **SMTP relay** configuration that survives plugin UI churn.

If a future first-party AEL mailer appears, you could migrate — but Other SMTP already speaks the protocol. Do not let a missing logo tile talk you into staying on a timed trial. Free forever packaging beats a familiar button.

When Pro vs free plugin editions matter: email logging, alerts, and fine-grained controls differ by plan — VERIFY WP Mail SMTP’s current pricing pages — but authenticated SMTP via Other SMTP does not require Pro for the core “stop using PHP mail()” job. Spend budget on DNS done right and warmup discipline before you spend it on logging UI.



## Related guides in this silo

Companion pages in the Agent Email List / free forever SMTP server silo. Start with the pillar if you still need vendor shopping context.

- [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay) — pillar — free forever SMTP server / Mailgun & SendGrid alternatives
- [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/) — Nodemailer transport patterns shared across stacks
- [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/) — warmup ladder to unlimited emails/day
- [SPF + DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/) — SPF + DKIM before production send
- [Laravel Mail Free SMTP Server Setup](/laravel-mail-free-smtp-server-setup/) — Laravel Mail for PHP app stacks beside WordPress
- [PHPMailer Free SMTP Server Setup](/phpmailer-free-smtp-server-setup/) — raw PHPMailer when you are not on WP Mail SMTP

## Next steps + hard CTA

You now have production-shaped **WP Mail SMTP** guidance for a free **SMTP relay**/server: how `wp_mail` and PHPMailer interact, which Other SMTP fields matter, why Gmail and capped ESP free tiers disappoint, and a full Agent Email List setup path that never invents host/port. You have forms/WooCommerce/membership notes, multisite and staging hygiene, deliverability pointers, migration field maps, and WordPress-specific troubleshooting for hosting blocks, 535s, silent loss, warmup caps, and plugin conflicts.

**Product recap (locks):**

- **Agent Email List** = **free forever SMTP server** + Mailgun-shaped API
- **Unlimited emails/day after warmup** (ladder **10 → 20 → 100 → 1,000 → unlimited**; day one = **10**)
- **`smtp_password` once** on domain create
- Host/port from **product docs or dashboard when published** — never invented here
- Owned and run by **Logan Besecker**

**Do this next:**

1. Create your free forever account at **[https://ai.agentemaillist.com](https://ai.agentemaillist.com)**
2. Add and verify your sending domain; save `smtp_password` in a real secret store / `wp-config.php` constants
3. Copy host/port from docs/dashboard when published into WP Mail SMTP Other SMTP
4. Send one plugin test; prove a form and a password reset
5. Climb warmup deliberately — [Email Warmup → Unlimited/Day](/email-warmup-unlimited-emails-per-day/)
6. Read the pillar for vendor shopping: [Free SMTP Relay — Mailgun & SendGrid Alternatives](/free-smtp-relay)
7. Skim siblings as needed: [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/), [PHPMailer Free SMTP Server Setup](/phpmailer-free-smtp-server-setup/), [What Is an SMTP Relay? Free SMTP Server](/what-is-smtp-relay-free-smtp-server/), [SPF/DKIM for Transactional Email](/spf-dkim-setup-transactional-email/)

**Sibling links:** [/nodemailer-free-smtp-server-setup/](/nodemailer-free-smtp-server-setup/), [/email-warmup-unlimited-emails-per-day/](/email-warmup-unlimited-emails-per-day/), [/phpmailer-free-smtp-server-setup/](/phpmailer-free-smtp-server-setup/), [/what-is-smtp-relay-free-smtp-server/](/what-is-smtp-relay-free-smtp-server/)

**Primary CTA:** Stop pointing WordPress at PHP `mail()`, Gmail app passwords, or trial cliffs. Stand up a free forever SMTP relay/server, authenticate your domain, and grow to unlimited emails/day after warmup.

**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

<!--
meta_title: WP Mail SMTP Free SMTP Relay Setup 2026
meta_description: Configure WP Mail SMTP with a free forever SMTP relay/server. Agent Email List issues smtp_password on domain create; unlimited/day after warmup.
slug: wordpress-wp-mail-smtp-free-smtp-relay-setup
word_count: 10259
internal_links: /free-smtp-relay, /email-deliverability-guide-transactional/, /email-warmup-unlimited-emails-per-day/, /free-email-api-for-developers/, /laravel-mail-free-smtp-server-setup/, /nodemailer-free-smtp-server-setup/, /phpmailer-free-smtp-server-setup/, /spf-dkim-setup-transactional-email/, /what-is-smtp-relay-free-smtp-server/
-->

<!-- word_count: 10259 -->
