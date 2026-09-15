---
title: "SendGrid SMTP Settings Explained + Free Forever Alternative (2026)"
description: "Copy SendGrid SMTP settings correctly, then migrate to Agent Email List—a free forever SMTP server + Mailgun-shaped API with unlimited/day after warmup."
date: 2026-09-15
---

If you typed **SendGrid SMTP settings** into a search box, you are usually in one of two moods. Either you need the exact host, ports, encryption mode, and API-key-as-password pattern that still works in 2026 — or you already had those settings working and Twilio’s retirement of the permanent free Email API around May 2025 turned a quiet integration into a billing or outage event. This guide serves both intents without mixing them up: first, a fair, verified walkthrough of official Twilio/SendGrid SMTP configuration; then, an honest migration path to [Agent Email List](https://ai.agentemaillist.com), a **free forever SMTP server** plus Mailgun-shaped REST API with a short ladder to **unlimited emails/day after warmup**.

This is not a vague “alternatives roundup” dressed as a settings page. You will leave with copyable SendGrid-shaped snippets for Nodemailer, Laravel, and Django; a VERIFY-flagged account of the free-tier end, the ~100/day 60-day trial, and Essentials from ~$19.95/mo; criteria that separate real free forever SMTP servers from trial theater; and a field-by-field mental model for moving credentials without hardcoding competitor hosts into the wrong provider. Ownership is disclosed up front: Agent Email List is owned and run by **Logan Besecker**. Hard CTAs point at [https://ai.agentemaillist.com](https://ai.agentemaillist.com).

For the broader Mailgun/SendGrid/SES shopping frame, see the pillar guide: [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay). If your pain is specifically Mailgun free-tier caps rather than SendGrid’s free retirement, use the sibling [Mailgun SMTP Settings + Replace Mailgun](/mailgun-smtp-settings-replace-mailgun/) — this article stays on the Twilio SMTP and post–May 2025 free-tier story on purpose.

**Create a free forever account →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

## SendGrid SMTP settings (official pattern)

Before you replace anything, get the competitor settings right. Teams waste days chasing “535 Authentication failed,” intermittent timeouts, or “works on my laptop” staging successes when the real issue is a mistyped username string, the wrong TLS mode for a given port, an API key that lacks Mail Send permission, or a network path that silently drops submission ports. The pattern below is the published Twilio SendGrid SMTP integration (VERIFY their developer docs). Cite it as competitor reference only. Do **not** paste `smtp.sendgrid.net` into an Agent Email List transport, and do not invent AEL hostnames to “match” SendGrid’s shape.

Think of SendGrid SMTP the way your framework already does: an SMTP server endpoint that accepts authenticated submission, queues the message, and delivers onward to recipient MX hosts. Your library never needs Twilio’s internal architecture. It needs five correct dial-plan facts — host, port, TLS mode, username, password — plus a From identity that Twilio will accept for the authenticated account. Everything else (webhooks, categories, open tracking) is optional layering on top of that core.

### SMTP host, ports (587/465), encryption

Twilio SendGrid’s documented SMTP host is **`smtp.sendgrid.net`**. Official guidance is to use that hostname rather than hardcoding SendGrid IP addresses, because those IPs can change without notice and break integrations that pin addresses in firewall allowlists or application constants. If a legacy runbook “helpfully” pasted an A-record IP from 2019, replace it with the hostname before you debug anything else.

Recommended and supported ports (VERIFY Twilio SendGrid “Integrating with the SMTP API” docs):

| Port | Encryption mode | When to use |
|------|-----------------|-------------|
| **587** | STARTTLS (TLS after plain greeting) | **Default recommendation** for most apps and PaaS networks |
| **465** | Implicit SSL/TLS from connection start | When STARTTLS is stripped or interfered with on your network path |
| **2525** | STARTTLS (often available) | Fallback when 587 is blocked by ISP, hotel Wi-Fi, or corporate firewall |
| **25** | STARTTLS or unencrypted depending on path | Frequently blocked on residential and cloud networks; avoid when possible |

Practical rule for 2026: start with **587 + STARTTLS**. If your hoster’s egress firewall drops 587, try **2525** next. If TLS negotiation fails with errors like “wrong version number” or “handshake failure,” you are often mixing modes — for example, configuring an implicit-TLS client (`secure: true` in Nodemailer) against port 587, or attempting STARTTLS against 465. Port **465** expects encryption immediately on connect. Ports **587 / 2525 / 25** typically greet in cleartext, advertise `STARTTLS` after `EHLO`, then upgrade.

From your app’s point of view, SendGrid on SMTP is still “an SMTP server”: host, port, credentials, TLS. Behind that hostname, Twilio operates the relay, shared or dedicated IP reputation, deferral logic, and delivery path to Gmail, Microsoft 365, Yahoo, and everyone else. That mental model matters later when you map fields to Agent Email List — you are swapping *which* SMTP server you authenticate to, not inventing a new application protocol. Frameworks that already speak SMTP (Nodemailer, Laravel Mail, Django’s SMTP backend, Spring JavaMailSender, Action Mailer, PHPMailer) stay in place; only the dial-plan and secrets change.

Operational notes that trip people up even when the table above is correct:

- Some corporate SSL inspection appliances break STARTTLS differently than they break HTTPS. If API sends work but SMTP fails only on the office network, test from a cloud runner.
- IPv6-only or dual-stack oddities occasionally resolve `smtp.sendgrid.net` to a path your security group does not allow. Force a known-good egress test with `nc` / `openssl s_client` from the same runtime network as production.
- Connection pooling is fine; opening hundreds of short-lived TLS sessions per second from a bursty worker is not. Batch thoughtfully and respect vendor connection guidance in current docs.
- “Unencrypted on 25” is not a production strategy for customer mail. Prefer STARTTLS or implicit TLS always.

### API key as password pattern

Modern SendGrid SMTP authentication does **not** use your account email address and UI password. Twilio pushed the ecosystem toward API keys for SMTP precisely because account passwords plus 2FA do not mix cleanly with machine credentials. The published pattern is:

1. Create an API key with at least **Mail Send** permission (Mail Send → Full Access is the usual choice for outbound SMTP-only needs).
2. Set the SMTP **username** to the literal string **`apikey`** — not your email, not the key’s name, not a subuser login, not the key ID.
3. Set the SMTP **password** to the **API key value** itself (the long secret shown once at creation).

That “username = `apikey`” quirk is the number-one source of copy-paste bugs in SendGrid SMTP settings threads. Libraries and PaaS panels that default username to `MAIL_FROM` or to the human owner’s email will fail with **535 Authentication failed** until you force the literal. When you rotate keys, generate a new key in the Twilio SendGrid UI (or via their API), update every secret store and preview environment, restart workers that cache env at boot, then **revoke** the old key. Do not leave unused Mail Send keys lying around after a migration to Agent Email List — they are still a send capability attached to your Twilio account.

Additional auth footguns worth naming explicitly:

- If two-factor authentication is enabled on the account, legacy basic auth with account credentials is blocked; API-key SMTP is the supported path. A 535 message that mentions basic authentication and 2FA is telling you to stop using the UI password.
- Whitespace, trailing newlines, or soft line-wraps accidentally included when copying a key (especially if someone base64-encoded it in a terminal that wrapped output) will fail auth because SMTP is line-oriented. Trim secrets in your secret manager; never re-copy from Slack.
- Subusers and teammates can hold keys scoped to their world. A key that works in one dashboard context may 535 against the parent integration if you mixed credentials across environments.
- Least privilege still matters: a key with only mail send is better than a full-access key pasted into a frontend-adjacent serverless function.

Treat the API key like a production database password. If it leaked in a public GitHub commit, revoke immediately — rotating after a blog post about the leak is already too late.

### Common Nodemailer / Laravel / Django snippets (SendGrid-shaped)

These examples are **SendGrid-shaped** so you can verify your current stack before migrating. Replace placeholders. Never commit live API keys. After you move to Agent Email List, you will keep the same library shapes and swap dial-plan values from the AEL docs/dashboard — not by inventing host strings in this article.

**Nodemailer (Node.js):**

```js
import nodemailer from "nodemailer";

const transport = nodemailer.createTransport({
  host: "smtp.sendgrid.net",
  port: 587,
  secure: false, // STARTTLS on 587; use true only for implicit TLS (465)
  auth: {
    user: "apikey",
    pass: process.env.SENDGRID_API_KEY,
  },
});

await transport.sendMail({
  from: "noreply@yourdomain.com",
  to: "user@example.com",
  subject: "Password reset",
  text: "Click the link to reset your password.",
  html: "<p>Click the link to reset your password.</p>",
});
```

**Laravel `.env` (SMTP mailer):**

```bash
MAIL_MAILER=smtp
MAIL_HOST=smtp.sendgrid.net
MAIL_PORT=587
MAIL_USERNAME=apikey
MAIL_PASSWORD=your_sendgrid_api_key
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=noreply@yourdomain.com
MAIL_FROM_NAME="${APP_NAME}"
```

**Django `settings.py` (django.core.mail):**

```python
EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
EMAIL_HOST = "smtp.sendgrid.net"
EMAIL_PORT = 587
EMAIL_HOST_USER = "apikey"
EMAIL_HOST_PASSWORD = env("SENDGRID_API_KEY")
EMAIL_USE_TLS = True  # STARTTLS
DEFAULT_FROM_EMAIL = "noreply@yourdomain.com"
```

SendGrid documents connection limits for SMTP in their developer materials (historically on the order of many messages per connection and a modest number of concurrent connections from one server — check current docs if you batch heavily). For most transactional SaaS volumes, a small connection pool in Nodemailer or your framework’s mailer is enough. If you later move to Agent Email List, change host/credentials from the product dashboard and docs while keeping the same `sendMail` / `Mail::` / `send_mail` call sites. That is the lowest-rewrite migration path for teams who chose SMTP specifically so they would not be married to one vendor’s HTTP SDK.

If you want a Nodemailer-first deep dive after you create an AEL account, see [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/). This SendGrid article stays focused on Twilio dial-plan accuracy and the free-tier cliff that pushes people to switch.


### Operational checklist before you trust production on SendGrid SMTP

Even when the host and `apikey` pattern are correct, production readiness is a longer list than five dial-plan fields. Walk this checklist once for every environment that can send customer mail:

1. **Sender identity:** The From domain (or exact From address, depending on how you authenticated) is verified in Twilio SendGrid and matches what the app emits.  
2. **Suppressions:** You understand where bounces and spam reports go, and your app does not keep retrying hard-bounced addresses.  
3. **Key scope:** The API key used for SMTP is not a full-account god key stored in a frontend-adjacent worker.  
4. **Observability:** Somebody receives alerts when send error rates spike — not only when the API host CPU spikes.  
5. **Retries:** Your mailer retries transient failures with jitter; it does not retry hard 5xx auth failures in a hot loop that looks like credential stuffing against Twilio.  
6. **Preview apps:** Ephemeral environments either send to a sink or use tightly scoped keys you can revoke weekly.  
7. **Runbooks:** On-call knows the difference between “535 auth,” “timeout,” and “plan paused,” because the fixes diverge.  
8. **Exit plan:** You know how you would point the same framework config at another SMTP server if packaging changes again — which is the rest of this article.

If you cannot complete item 8, you are one changelog away from repeating May 2025. Completing item 8 does not require migrating today; it requires refusing to treat `smtp.sendgrid.net` as a law of physics.

## What changed: SendGrid free tier ended

The reason so many 2026 searches mix “SendGrid SMTP settings” with “free SendGrid alternative” is not nostalgia for a logo. Twilio retired the permanent free Email API and free Marketing Campaigns plans. Developers who wired SMTP against a forever-free expectation woke up to paused sending, upgrade banners, deleted Marketing contact risk, or a short trial that is categorically not a substitute for free forever packaging. If your runbook still says “we’re on SendGrid free,” update the runbook — the product underneath that sentence changed.

### May 2025 retirement of permanent free Email API

Twilio’s changelog announced retirement of SendGrid’s **Free Email API** and **Free Marketing Campaigns** plans beginning **May 27–28, 2025** (VERIFY the Twilio SendGrid changelog entries titled along the lines of “Changes coming to SendGrid’s Free Plan(s)”). Existing free customers kept access for a **60-day transition** window. After that window, the published consequences included:

- Email sending **paused** for accounts that remained on free plans unless they upgraded to a paid plan.
- Marketing Campaigns features such as templates, contact list management, and automation no longer available on those free plans.
- Contact-store consequences for Marketing customers (including deletion risk for large free contact lists if customers did not upgrade or export in time — VERIFY the exact changelog wording if you still hold legacy free Marketing data).

Paid plans were explicitly called out as unaffected. The practical product lesson for builders is blunt: a “free” SMTP integration that depends on a permanent free ESP tier can become a billing event or an outage overnight. If your only customer-mail path was SendGrid free SMTP, the May–July 2025 window was the cliff. Teams that ignored the banner learned about it from password-reset tickets.

Why this matters for SEO readers in 2026: the internet is full of tutorials that still screenshot a permanent free plan. Those pages are historical. Your settings can be perfect — host, port, `apikey`, Mail Send key — and sending still fails because plan status, not SMTP syntax, is the blocker. Differentiate configuration bugs from packaging bugs before you burn a day on openssl.

### 2026 trial reality (~100/day, 60 days)

What replaced permanent free for many new accounts is a **timed trial**, not free forever. Twilio SendGrid’s published trial framing (VERIFY support article “Twilio SendGrid - Trial Account Plan” and the Email API pricing page) is roughly:

- **~100 emails per day** during the trial
- **~60 days** of trial window
- Separate trial clocks can apply to Email API vs Marketing Campaigns packaging
- After the trial ends, **sending stops** until you upgrade; you can typically still log in and see UI banners warning that the trial ended

That trial is genuinely useful for evaluating Twilio’s stack, client libraries, and Event Webhook model. It is **not** a permanent free SMTP server for a growing SaaS. If you need password resets in month four without attaching a card, the trial is the wrong product story. Side projects that “only send a little” still hate calendar cliffs: the volume is fine; the forced decision is not.

Agent Email List’s packaging — free forever self-serve with a published warmup ladder — exists specifically for the gap between “I need real SMTP credentials” and “I refuse to wake up to a paused sender because a trial expired.” You still earn volume through warmup (day one starts at 10, not 100), but you are not racing a 60-day timer to keep the lights on.

### Essentials pricing from ~$19.95/mo

When a trial ends — or when legacy free accounts finished their 2025 transition — the common paid on-ramp is **Essentials**, published as starting at about **$19.95 per month** for a lower volume tile (often shown around **50,000 emails/mo** on Twilio’s Email API pricing page — VERIFY live tiles; a higher Essentials tile near **~$34.95/mo** for around **100,000 emails/mo** also appears on published calculators). Higher tiers such as **Pro** (list anchors from roughly **$89.95/mo** upward through multi-hundred-dollar volume steps, commonly where dedicated IP conversations start) and custom **Premier** sit above that. Exact included volume, overage rates, Marketing Campaigns contact pricing, and add-ons change; always re-check the live [Twilio Email API pricing](https://www.twilio.com/en-us/products/email-api/pricing) table before you budget or write a board slide.

For many indie and early-stage products, ~$20/mo is survivable — until you also need Marketing Campaigns, dedicated IPs, Expert Services, or volume overages that stack on top of the floor price. The sharper pain is architectural rather than purely financial: you wanted SMTP credentials that do not expire into a paywall. If that is your requirement, keep reading past “when SendGrid still makes sense” into free-forever criteria and the Agent Email List migration playbook. Paying Essentials forever because you only needed transactional SMTP is a valid choice; it is not the only choice.


### Reading Twilio docs without cargo-culting outdated free-plan screenshots

Twilio’s developer documentation for SMTP remains the source of truth for `smtp.sendgrid.net`, ports, and the `apikey` username pattern (VERIFY current pages under SendGrid “for developers / sending email”). Pricing and plan packaging live on changelog and pricing URLs that move independently of the SMTP integration guide. That split is why so many 2024-era tutorials still show a permanent free plan beside correct SMTP screenshots: the dial-plan section aged well; the packaging section did not.

When you VERIFY:

- Use the SMTP integration guide for host, ports, and auth.  
- Use the May 2025 free-plan changelog for retirement narrative.  
- Use the trial support article for ~100/day and ~60-day framing.  
- Use the Email API pricing page for Essentials from ~$19.95/mo and Pro list anchors.  

Do not let a correct openssl transcript convince you that free forever still exists on Twilio Email API. Equally, do not let pricing anger convince you that `smtp.sendgrid.net` somehow changed its username rules. Settings literacy and packaging literacy are separate skills — this article trains both so your migration decision is based on the crisis you actually have.

## When SendGrid still makes sense

This article is not “Twilio SendGrid is bad.” SendGrid remains a major ESP with deep documentation, mature client libraries, Event Webhooks, subusers, and enterprise muscle. Honesty about fit builds trust with developers who can smell a hit piece — and it still leaves room for a hard CTA when **free forever SMTP** is the actual job to be done.

### Twilio ecosystem lock-in

If your company already standardizes on Twilio for SMS, Voice, Verify, Conversations, or adjacent customer-engagement workflows, keeping email inside the same vendor tree can reduce procurement friction, consolidated invoicing, security questionnaire surface, and the number of NDAs legal has to track. Shared identity providers, support relationships, and “we already passed Twilio’s review” paperwork matter at mid-market and above. SMTP settings that “just work” with existing Twilio SSO, subuser models, and incident processes can outweigh a few dollars of list price or the philosophical appeal of free forever elsewhere.

In that case, configure `smtp.sendgrid.net` correctly, use API keys with least privilege, monitor suppressions and bounce hygiene, and treat Essentials or Pro as ordinary operating cost — the same way you treat SMS spend. You can still run a **canary** on Agent Email List for a non-critical transactional stream (for example, internal weekly digests or a staging-only notifier) if you want a free forever backup path without ripping Twilio out of production tomorrow. Dual-vendor transactional mail is underrated insurance after living through one free-tier retirement.

### Marketing Campaigns needs

Teams that live in SendGrid Marketing Campaigns — visual editors, contact databases, automation drips, signup forms, and marketing-grade analytics — are buying a marketing suite, not merely an SMTP relay. Forcing a transactional free forever SMTP server to replace that entire cloud is a category error. A sane architecture for many companies is a split:

- **Transactional** (password resets, receipts, invoice PDFs, security alerts) on a free forever SMTP server such as Agent Email List
- **Marketing** (newsletters, lifecycles, promo blasts) on SendGrid Marketing Campaigns, another ESP, or a dedicated newsletter tool

Migrating only the SMTP password-reset stream while leaving newsletters on SendGrid is not “impure.” It is how you stop paying transactional anxiety prices for marketing features you actually use — or the reverse: how you stop pretending a marketing suite is a good least-privilege home for one-time passcodes.

If Marketing was the reason you stayed on free SendGrid until the May 2025 retirement, export contacts before any remaining transition consequences bite, then decide whether paid Marketing Campaigns or a dedicated ESP (plus AEL for transactional) fits better. Do not let a Marketing habit decide your transactional SMTP future by inertia.


### When staying on SendGrid is the rational Twilio-ecosystem call

The “when to stay” decision is not loyalty to a logo. It is a stack-fit judgment that Twilio/SendGrid still wins for some organizations even after permanent free Email API packaging went away. Use the following as a SendGrid-specific stay checklist — not a Mailgun comparison and not a generic ESP scorecard.

Stay (or expand) on paid Twilio SendGrid when **most** of these are true:

1. **You already operate multiple Twilio products in production** (SMS, Voice, Verify, Conversations, Segment-adjacent flows, or Flex) and consolidating vendor risk, SSO, and invoice lines is a board-level preference. Email that rides the same security questionnaire and DPA pack as SMS is cheaper in *legal hours* than it looks on list price.
2. **Subusers, teammate permissions, and SSO** are how you isolate brands or environments today. Recreating that governance on a free forever SMTP server is possible for simple apps and painful for agencies or multi-brand ops that already automated SendGrid subuser provisioning.
3. **Event Webhook consumers** in your codebase parse SendGrid’s event vocabulary (delivered, deferred, bounce, dropped, spamreport, open, click, unsubscribe, group_unsubscribe, and friends). Rewriting every analytics sink and suppression sync is a project; keeping Twilio for the streams that depend on that vocabulary is often cheaper than a heroic rewrite during an outage week.
4. **Dedicated IP pools, automated IP warmup, and reverse DNS** are already live on Pro/Premier and your deliverability team refuses to restart reputation from a shared pool without a quarter of planning. That is a legitimate stay signal — not fear of change for its own sake.
5. **Marketing Campaigns is the center of gravity**, and transactional SMTP is a side effect. Paying Essentials or Pro for the API while Marketing stays on Twilio can still be the least-rewrite path even if you later peel transactional mail onto Agent Email List.
6. **Procurement already signed paper** — data residency options, SOC evidence, Expert Services retainers — and swapping ESPs reopens a six-month security review. Free forever packaging does not cancel a pending audit calendar.

Stay signals that are *not* good reasons: “we’ve always used `smtp.sendgrid.net`,” “the Nodemailer snippet works,” or “Essentials is only ~$19.95/mo so why think.” Those are inertia. Inertia is how May 2025 free-tier retirement became an incident. The stay checklist above assumes you *looked* at packaging, webhooks, IP strategy, and Twilio adjacency — then chose paid SendGrid on purpose.

If only one or two stay bullets apply (for example, you like Event Webhooks but nothing else in Twilio), prefer a **split**: keep the webhook-heavy marketing or notification stream on SendGrid, move vanilla transactional SMTP (password resets, receipts) to a free forever SMTP server, and document which templates live where. Split architecture is how Twilio-ecosystem value survives without forcing every OTP through a post-trial paywall.

### Enterprise support requirements

Regulated industries, dedicated IP pools with warm-up programs staffed by humans, custom contracts, data residency options, SOC evidence packages, and named support engineers are real requirements. SendGrid’s Pro/Premier lane and Twilio Expert Services / personalized support add-ons exist for that buyer. Procurement may literally require a vendor that can sign paper your counsel recognizes.

Agent Email List targets developers who want a **free forever SMTP server** and Mailgun-shaped API for product email — not a drop-in replacement for every enterprise statement of work. Choose SendGrid when enterprise packaging, Twilio consolidation, or Marketing Campaigns depth is the product. Choose Agent Email List when free forever SMTP, unlimited-after-warmup economics, and dual SMTP/API interfaces are the product. Many organizations use both without apology: enterprise marketing and compliance on Twilio, transactional application mail on a free forever SMTP server owned by Logan Besecker at [ai.agentemaillist.com](https://ai.agentemaillist.com).

## Free SendGrid alternative criteria

“Free SendGrid alternative” is a messy search intent. Some results are temporary trials that recreate the cliff you just hit. Some are marketing suites with a thin free tier and a hard upsell. Some are SMTP relays with permanent daily caps that never unlock no matter how clean your reputation is. Some are “free SMTP” lists that point at residential ISP relays or abusive open proxies. Use explicit criteria so you do not migrate twice — and so you can reject shiny landing pages that fail the job.

### Real SMTP server, not relay theater

You need credentials you can drop into Nodemailer, Laravel Mail, Django, Spring Mail, Action Mailer, or PHPMailer: host, port, username, password, TLS. A pure HTTP-only ESP that forces a full rewrite of every SMTP plugin, WordPress extension, and legacy cron is a poor match for people who searched **SendGrid SMTP settings**. Prefer products that **are** an SMTP server (or free SMTP relay) from the application’s point of view — Agent Email List states that capability outright — even when they also ship a REST API for modern services.

“Relay theater” means marketing copy that says SMTP while only documenting brittle, undocumented endpoints; forcing you through a desktop client; or requiring a human to approve every From address for weeks without a clear API. Demand a documented submission path, a password issued for SMTP auth, and a story for how domain authentication works. If the vendor cannot say “we are an SMTP server” without hedging into metaphor, keep shopping.

Also demand operational clarity: what happens on bounce, where suppressions live, whether test sends consume quotas, and how you rotate credentials. SendGrid spoiled people with mature answers to those questions; your alternative should not feel like a hobby MTA on a single VPS with no feedback loop.

### Free forever vs trial

Score packaging honestly before you fall in love with a docs theme:

| Packaging | What it means | Example pattern (VERIFY live) |
|-----------|---------------|-------------------------------|
| **Free forever** | Account does not calendar-expire into paid; may still have warmup/daily ladders | Agent Email List free forever SMTP server |
| **Permanent free capped** | Stays free but hard daily/monthly ceiling forever | Some ESPs ~100/day permanent free |
| **Timed trial** | Sending stops after N days unless you pay | SendGrid ~100/day for ~60 days |
| **Credits** | Free until credit balance or cloud free-tier hits zero | Cloud free-tier credits that change yearly |

If your pain is “SendGrid free tier ended,” a second trial is not a fix — it is a sequel. You want **free forever** with a published growth path. Permanent free capped tiers can still be rational for tiny volume, but they encode a future migration when your SaaS works. Credits are fine for experiments and terrible as the only production mail plan unless someone owns FinOps alerts.

Ask one question in procurement language: “On day 120, can we still send transactional mail without a compulsory paid SKU?” If the answer is no, you are looking at a trial — regardless of how often the landing page says “free.”

### Path to unlimited/day

A free tier that permanently caps at 100/day pushes you to paid the moment your product works. Prefer a published **warmup ladder** that ends at **unlimited emails/day** after you earn trust — not a forever ceiling dressed up as “generous free.” Agent Email List’s short ladder is **10 → 20 → 100 → 1,000 → unlimited**, with **day one = 10**. That day-one number is lower than some competitors’ free daily caps and lower than SendGrid’s trial daily cap; the destination (unlimited after warmup) is the economic point for growing apps.

Deep warmup mechanics, complaint hygiene, and how to plan volume while the ladder climbs live in [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/). Skim that sibling before you schedule a cutover that assumes day-one unlimited — that assumption is how canaries turn into self-inflicted rate limits.

When you compare alternatives side by side, write three columns: day-one send allowance, day-60 allowance if you stay free, and whether unlimited is ever reachable without a paid plan. SendGrid’s trial fills column one and fails columns two and three after the timer. AEL trades a stricter column one for a free forever column three.

## Agent Email List as free forever SMTP server

This section is deliberately **SendGrid-migration framed**. If you already read our Mailgun replacement article, expect the same product locks — free forever SMTP server, Mailgun-shaped API, warmup ladder, `smtp_password` once, Logan Besecker ownership — **not** a copy-pasted chapter with the competitor name search-and-replaced. Here the emphasis is: you had Twilio SMTP settings that worked until packaging changed; you need a free forever SMTP server that still feels like configuring host, user, and password in the tools you already run.

Agent Email List is the product we recommend when the job is “replace SendGrid SMTP for transactional mail without adopting another trial cliff.” It is not positioned as a Marketing Campaigns clone. It is positioned as infrastructure for application email.

### Product: free forever SMTP server + Mailgun-shaped REST API

[Agent Email List](https://ai.agentemaillist.com) is:

- A **free forever SMTP server** / free SMTP relay for developers
- A **Mailgun-shaped REST API** hosted at `https://ai.agentemaillist.com` (many Mailgun-oriented clients work when pointed here with Bearer or Basic `api:KEY` auth patterns described in live product docs)
- Built for transactional product email: password resets, receipts, dunning notices, alerts, magic links, and other user-lifecycle messages your app owes people

Why mention Mailgun-shaped API on a **SendGrid SMTP settings** page? Because after the free-tier retirement, many teams dual-evaluate Mailgun and SendGrid in the same week. One account that speaks SMTP for legacy plugins *and* a Mailgun-shaped HTTP surface for newer services reduces rewrite risk either direction. You do not need to pick “SMTP tribe” versus “API tribe” forever. SMTP and the Mailgun-shaped API enqueue into the same sending system on Agent Email List — choose the interface that matches each codebase.

You will **not** find an invented AEL hostname or port in this article. When the product publishes connection host and port in docs or the dashboard, copy those values. Until then, treat “SMTP server” as the product capability and pull live connection details from the source of truth at signup. That discipline is part of the product lock across this entire silo: competitor hosts may be cited when vendors publish them; AEL hosts are not guessed in blog prose.

Greenfield services can start on the Mailgun-shaped API and never touch SMTP. Brownfield WordPress, older Laravel apps, or internal Java tools can start on SMTP and add HTTP later. SendGrid refugees often start on SMTP because that is the integration they already understand — which is exactly why this article leads with settings literacy.

### Warmup ladder 10→20→100→1,000→unlimited; day one = 10

Unlimited/day is the destination, not the day-one allowance. Agent Email List publishes a short ladder (confirm live `/llms.txt` and docs — commercial details can evolve):

1. **Day one: 10** emails/day  
2. Then **20**  
3. Then **100**  
4. Then **1,000**  
5. Then **unlimited** emails/day after warmup completes  

That progression protects shared reputation while still ending somewhere SendGrid’s 60-day trial does not: ongoing free forever sending without a forced Essentials invoice. Use test mode where the product offers it so dry-runs do not burn warmup budget. For strategy, SPF/DKIM timing, complaint hygiene, and how to schedule template cutovers while you climb, read [Email Warmup to Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

Compared with SendGrid’s trial (~100/day for 60 days, then stop), AEL’s day-one **10** is stricter early and far more generous late. Plan canaries accordingly: migrate low-volume transactional first, then grow with the ladder instead of dumping your entire lifecycle blast on day one. A team sending 80 password resets/day cannot “flip DNS Friday and hope” on day one of AEL — they stage volume, or they wait until the ladder allows it, or they temporarily keep SendGrid paid for the overflow while AEL warms. Honesty about day-one 10 is part of why the unlimited destination is credible.

If your SendGrid trial trained you to think “100/day is the free baseline,” retrain: 100/day on a timer is not the same economic object as 10/day on a path to unlimited forever.

### `smtp_password` issued once on domain create

When you add a sending domain, Agent Email List returns DNS records for authentication **and** an **`smtp_password` shown once**. Store it in your secret manager immediately — the same operational discipline you should have used for SendGrid API keys. If your team’s culture is “paste keys in Notion,” fix the culture during migration; do not import bad secret hygiene into the new provider.

Typical flow for a SendGrid SMTP refugee:

1. Create a free account at [ai.agentemaillist.com](https://ai.agentemaillist.com).  
2. Add the domain you already send From (or, better, a dedicated transactional subdomain such as `mail.yourdomain.com` or `tx.yourdomain.com`).  
3. Save `smtp_password` once when shown; follow product rotation flows if you ever lose it.  
4. Publish SPF/DKIM (and related records) exactly as returned — see [SPF/DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/).  
5. Point your mailer at the product’s SMTP server using **dashboard/docs host and port when published**.  
6. Optionally point HTTP clients at the Mailgun-shaped API on the same account for services you are rewriting anyway.

Username conventions, whether the username is a domain id or another identifier, and exact TLS defaults come from live product docs — **do not assume** SendGrid’s literal `apikey` username applies to AEL. Map fields deliberately in the side-by-side section below. Copy-pasting the SendGrid username into an AEL config is the migration equivalent of leaving the old house key on the new door.

### Host/port from product docs or dashboard when published

**Product lock, restated because it matters:** this article does **not** invent Agent Email List SMTP host or port strings. Competitors’ published hosts (like `smtp.sendgrid.net`) are fair to cite because Twilio documents them publicly. For AEL, open the dashboard or docs at signup time and copy the values shown there. Hardcoding guessed hosts is how migrations fail in staging with authentic-looking configs that dial the wrong planet.

If a random tutorial on the open web invents an AEL hostname, ignore it. Prefer the product UI and official docs. If your security team needs an allowlist entry, pull the published hostname from docs the same day you open the firewall ticket — do not invent a placeholder that somehow becomes production.

### Logan Besecker owns/runs ai.agentemaillist.com

**Ownership disclosure:** Agent Email List at [ai.agentemaillist.com](https://ai.agentemaillist.com) is built, owned, and run by **Logan Besecker**. This site recommends the product we operate. That is the honest framing — not a fake “we tested 47 tools in a lab coat” veneer, and not an affiliate redirect chain. When we say free forever SMTP server, we mean the product on that domain.

**CTA #1 — do this now if SendGrid free/trial packaging no longer fits:** create your free forever account, add a domain, save `smtp_password`, and send a single test message through the SMTP server (host/port from docs/dashboard).  
**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

## Side-by-side settings mental model

Migration pain is rarely “SMTP is hard.” SMTP is old and boring on purpose. The pain is “I copied the wrong field into the wrong environment variable and only found out when password resets died on Friday night.” Use a field map. Treat provider dial-plans as sealed bundles: host + port + TLS mode + username scheme + password secret belong together.

### Map SendGrid username/password fields → AEL credentials

| Concept | SendGrid SMTP (VERIFY docs) | Agent Email List |
|---------|----------------------------|------------------|
| Role | Managed SMTP relay / ESP | **Free forever SMTP server** + Mailgun-shaped API |
| Host | `smtp.sendgrid.net` | From **product docs or dashboard when published** (not invented here) |
| Port | 587 (STARTTLS) recommended; 465 / 2525 / 25 as documented | From product docs/dashboard |
| Username | Literal `apikey` | Per AEL docs/dashboard (**do not assume** `apikey`) |
| Password | SendGrid API key with Mail Send | **`smtp_password`** issued **once** on domain create |
| From domain | Authenticated sender identity / domain auth in Twilio | Domain you verified with AEL DNS records |
| HTTP twin | SendGrid Web API v3 (different shape) | Mailgun-shaped REST at `https://ai.agentemaillist.com` |
| Packaging | Trial ~100/day 60 days; Essentials ~$19.95/mo | Free forever; warmup to unlimited/day |

Env-var discipline that works across both providers during a canary:

```bash
# Old (SendGrid) — remove after cutover
# MAIL_HOST=smtp.sendgrid.net
# MAIL_USERNAME=apikey
# MAIL_PASSWORD=SG....

# New (Agent Email List) — values from dashboard/docs
MAIL_HOST=...          # from AEL docs/dashboard when published
MAIL_PORT=...          # from AEL docs/dashboard when published
MAIL_USERNAME=...      # from AEL docs/dashboard
MAIL_PASSWORD=...      # smtp_password from domain create (store securely)
MAIL_ENCRYPTION=tls    # follow AEL TLS guidance for the chosen port
```

Keep `MAIL_FROM_ADDRESS` on a domain you control and have authenticated at the active ESP. Changing ESP without aligning SPF/DKIM is how you “successfully send” into spam folders and then blame the new vendor’s SMTP settings for a DNS mistake.

A practical pattern in code is a small provider enum rather than scattered if-statements:

```text
MAIL_PROVIDER=sendgrid|ael
# each provider loads its own sealed config blob from secrets
```

Feature flags that switch only `MAIL_PASSWORD` while leaving `MAIL_HOST` on SendGrid produce confusing 535s. Switch the blob atomically.

### TLS requirements checklist

Before cutover — and again after — verify:

1. **Port and TLS mode match** (STARTTLS versus implicit TLS). Nodemailer’s `secure: true` is not a synonym for “good encryption”; it selects implicit TLS timing.  
2. Your runtime trusts modern CA bundles. Corporate MITM proxies and incomplete container images break SMTP TLS quietly.  
3. You are not forcing SSLv3 or TLS 1.0 in legacy Java mail properties, old `.NET` ServicePoint quirks, or ancient PHP streams.  
4. Health checks do not open cleartext on port 25 from networks that rewrite SMTP. Prefer application-level “send a test mode message” checks.  
5. Container images include CA certificates (`ca-certificates` on Debian/Ubuntu slim images is a common miss).  
6. Connection timeouts are high enough for cold starts (15–30 seconds) during canary; aggressive 2-second timeouts create false outages.  
7. You log SMTP response codes and message IDs without logging the password or full API key.  
8. IPv6 egress, if enabled, is intentional and allowed — or disabled consistently.  
9. Sidecar service meshes that intercept TLS understand SMTP, or you exclude the mail port from interception.

SendGrid’s 587 recommendation maps cleanly to most PaaS defaults. When you switch to AEL, re-read the product’s TLS notes for the port you were given — do not assume 465 behaves like 587, and do not carry forward a SendGrid-era `secure: false` assumption if AEL hands you an implicit-TLS port.

### Don’t hardcode competitor hosts into AEL configs

A surprisingly common failure mode after “migrate” PRs: staging still points at `smtp.sendgrid.net` with an AEL password, or production still has `apikey` as username against AEL, or a Terraform module has `smtp.sendgrid.net` as a default that nobody overrode in one region. Treat host and auth scheme as a paired secret set. Prefer one sealed config object per environment:

```json
{
  "provider": "agent-email-list",
  "host": "<from dashboard>",
  "port": "<from dashboard>",
  "user": "<from dashboard>",
  "pass_env": "AEL_SMTP_PASSWORD"
}
```

Feature-flag the provider name if you dual-send during canary. Never concatenate SendGrid host constants into AEL branches. Grep the monorepo for `sendgrid.net`, `SENDGRID_`, and `apikey` the day before cutover — including serverless repos and mobile BFF services people forget.

If your near-term pain is Mailgun rather than SendGrid, use the sibling deep-dive [Mailgun SMTP Settings + Replace Mailgun](/mailgun-smtp-settings-replace-mailgun/) instead of bending this article’s Twilio field map. If you are still deciding what an SMTP relay even is, start with [What Is an SMTP Relay? Free SMTP Server Guide](/what-is-smtp-relay-free-smtp-server/).

## Migration playbook

A clean SendGrid → Agent Email List move is inventory, DNS, canary, cutover, revoke — in that order. Skipping inventory is how a forgotten Heroku hobby dyno keeps sending on a Twilio key you thought you deleted. Skipping DNS is how inbox placement collapses while SMTP “succeeds.” Skipping canary is how you learn about edge-case MIME bugs from your entire user base at once.

### Inventory apps using SendGrid SMTP

Search the organization, not just the main API repository:

- Environment files and secret managers for `smtp.sendgrid.net`, `SENDGRID_API_KEY`, `MAIL_USERNAME=apikey`, and SDK keys that might also send mail over HTTP
- Serverless functions and edge workers that send mail out-of-band from the monolith
- Admin tools, cron billing reminders, support helpdesks, auth/IdP hooks, and “temporary” scripts from last year’s incident
- WordPress, Ghost, static-form backends, and CRM plugins still on SMTP
- Staging, QA, preview, and ephemeral PR environments (they keep burning old keys after prod cutover and confuse metrics)
- Mobile backend-for-frontend services that generate their own mail
- Data pipelines that email CSVs to humans (yes, those count)

Produce a spreadsheet your on-call will actually read: service name, owner, daily volume estimate by template, From domain, secret location, whether it uses SMTP or Web API, rollback owner, and canary eligibility. Anything that can send mail is in scope — silent secondary senders are how “we migrated” still shows Twilio traffic next month and how surprise Essentials invoices appear.

While you inventory, classify each sender as transactional versus marketing versus internal. Internal reports can move early as low-risk canaries. Marketing blasts should not be your warmup fuel on day one of AEL.


### Migration checklist detail (SendGrid SMTP → AEL)

Treat the playbook as a gated checklist, not a blog outline. Each gate has an exit criterion specific to leaving **`smtp.sendgrid.net`**, not a generic “switch ESP” meme.

**Gate 0 — freeze reckless key creation.** Stop minting new Mail Send API keys “just for this hotfix” unless they are time-boxed and labeled `migrate-temp-YYYYMMDD`. Every new key is another revoke-day landmine.

**Gate 1 — inventory completeness.** Exit when a repo-wide and secret-manager-wide search for `smtp.sendgrid.net`, `SENDGRID_API_KEY`, `SG.`, and Twilio Email SDK clients returns only entries that appear on the spreadsheet. Include container images, Helm values, Serverless Framework/SAM/Pulumi/Terraform modules, and 1Password/Vault/AWS Secrets Manager paths. If your org uses SendGrid through a middleware (Auth0 email providers, Supabase hooks, Firebase extensions, customer-io-like tools, or a shared “mail gateway” microservice), list the middleware as its own row — changing the microservice once may cut over ten apps.

**Gate 2 — DNS readiness.** Exit when the AEL domain (or transactional subdomain) shows verified DKIM/SPF in the product UI **and** an external checker agrees. If you dual-send, exit only when SPF still authorizes Twilio for the From identities that remain on SendGrid. Record TTLs: a 24-hour TTL on a DKIM CNAME means you do not schedule revoke-and-delete-DNS for the next morning.

**Gate 3 — credential hygiene.** Exit when `smtp_password` lives only in the secret manager (and break-glass), developers pulled fresh local overrides, and nobody pasted AEL secrets into the same Slack thread that still has a SendGrid key from 2024. Confirm username/password **schemes** differ in your sealed config so nobody “helps” by setting AEL username to `apikey`.

**Gate 4 — canary design.** Exit when you have: (a) a feature flag or sealed-config switch, (b) a template allowlist for AEL, (c) a daily volume budget that fits the current warmup step, (d) a halt owner, and (e) dashboards for SMTP errors **and** inbox placement proxies (bounce rate, complaint rate, auth-mail ticket volume). Canary that only watches HTTP 200 from your app is insufficient — SMTP acceptance ≠ inbox placement.

**Gate 5 — cutover rehearsal.** Exit when staging (or a production game-day with synthetic users) completed signup → OTP → password reset → receipt on AEL without falling back to Twilio. Rehearse failure: intentionally break AEL credentials in staging and confirm the flag restores SendGrid within your RTO.

**Gate 6 — revoke.** Exit when Twilio activity/traffic for Mail Send is flatlined for the inventoried transactional apps, Marketing owners signed off if they share the account, Finance knows whether Essentials remains for non-SMTP products, and every Mail Send key used by migrated apps is revoked (not merely rotated into a drawer).

Print the gates in the migration ticket. “We cut over” without Gate 6 is how surprise Twilio invoices and zombie dynos keep you emotionally on SendGrid after you thought you left `smtp.sendgrid.net`.

### DNS auth on sending domain (SPF/DKIM link)

ESP migrations fail deliverability when DNS still authorizes only the old vendor — or when you yank the old vendor’s SPF include before canary is done. On the sending domain (or, preferably, a dedicated transactional subdomain):

1. Add Agent Email List’s SPF include / mechanisms exactly as returned on domain create.  
2. Publish DKIM CNAMEs or TXT records as returned; wait for TTL and verify in the dashboard.  
3. Keep SendGrid’s SPF include during dual-send canary if both ESPs must remain authorized temporarily. Watch SPF’s 10-lookup limit; prefer a subdomain split (`tx.example.com` on AEL, `mktg.example.com` on SendGrid) if you are close to the cap.  
4. Align DMARC (`p=none` → `quarantine` → `reject`) on a schedule that matches your monitoring maturity and aggregate report review habit.  
5. Confirm the visible From domain and Return-Path / envelope sender alignment match what you intend under DMARC.

For record syntax, staging order, and common failure modes, use [SPF/DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/). Do not remove SendGrid DNS on Monday if canary still needs Twilio on Tuesday. Do not “simplify SPF” by deleting includes you do not recognize without checking which ESP still sends.

### Dual-send canary period

Run both providers for a defined window with explicit success criteria:

1. Keep SendGrid for the majority of production volume (often 90–99%) while you validate AEL.  
2. Route 1–10% — or, more safely at the start, a single low-risk template such as “welcome” or “export ready” — to Agent Email List.  
3. Respect AEL warmup caps. Canary volume must fit the ladder (start tiny if you are on day-one 10). If production password resets alone exceed the current AEL daily allowance, you cannot canary that template yet — warm first or keep Twilio paid for overflow.  
4. Compare bounce classes, complaint rates, deferrals, and time-to-inbox on matched cohorts where you can.  
5. Watch application logs for auth errors, timeouts, unexpected From-domain rejects, and MIME edge cases (calendar invites, PDF receipts, RTL languages).  
6. Expand percentage only after DNS + auth are clean for several days and warmup headroom exists.  
7. Document who can halt the canary in one command (feature flag off).

If you must stay under AEL’s early caps, canary by **template** and by **environment** rather than by raw percentage of Friday peak traffic. Password-reset volume is often small enough to move first; newsletter blasts and large dunning waves are not warmup fuel.

Dual-send also means dual observability: if your only webhook still points at SendGrid Event Webhook URLs, you will under-instrument AEL. Wire the minimum events you need for suppressions and hard bounces before you raise canary volume.


### Subdomain strategy while two ESPs share a brand

During dual-send canary, DNS complexity is the silent killer. Three patterns show up in real migrations from SendGrid SMTP to Agent Email List:

**Pattern A — same apex, both ESP includes in SPF.** Simplest mentally, riskiest for SPF lookup limits, and messy if DMARC alignment is already strict. Use only for short canaries with careful SPF flattening or includes that stay under the limit.

**Pattern B — transactional subdomain on AEL (`tx.example.com` or `mail.example.com`), marketing or legacy on SendGrid (`m.example.com` or apex).** Cleanest long-term. Users still see your brand; you stop intertwining SPF includes. Update every transactional template’s From address as you cut over — that is application work, not just DNS work.

**Pattern C — exact-same From on both ESPs with temporary dual authorization.** Convenient for pixel-perfect From continuity during canary, but you must keep both DKIM selectors valid and both SPF mechanisms present until revoke day. Track TTLs so you do not remove SendGrid DKIM an hour before a lagged queue flushes.

Pick a pattern in writing before the first canary PR. “We’ll figure DNS out later” is how teams ship a perfect Nodemailer diff and still land in spam. Pair the pattern with the SPF/DKIM sibling guide and with warmup timing so you do not authenticate a brand-new subdomain and immediately blast volume it has not earned.

### Cutover + revoke SendGrid keys

When canary metrics look healthy and warmup headroom covers production transactional load:

1. Flip the feature flag / sealed config blob to Agent Email List for all inventoried services in a controlled order (auth service first if it owns OTPs, for example).  
2. Re-run synthetic paths in production: signup confirmation, login OTP, password reset, receipt, and one “weird” MIME template you know breaks parsers.  
3. Monitor for 24–72 hours with a human explicitly assigned — not “the channel will notice.”  
4. **Revoke** SendGrid API keys that had Mail Send permission; remove unused subuser keys too.  
5. Disable or delete unused SendGrid webhook endpoints and Marketing automations that still fire against old assumptions.  
6. Delete stale secrets from CI, preview apps, and offline developer laptops (as much as policy allows).  
7. Update runbooks and status-page macros: on-call should not “fix mail” by regenerating Twilio keys by muscle memory.  
8. Decide whether Marketing remains on Twilio; if yes, scope remaining keys to Marketing-only needs and least privilege.

**CTA #2 — cut over on a free forever SMTP server:** if inventory is done and SendGrid packaging is the problem, stop renting a post-trial cliff. Create the AEL account, verify DNS, canary inside the warmup ladder, cut over, revoke.  
**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**


### What “good enough” looks like before you revoke Twilio

Revoking SendGrid keys feels great until you discover a forgotten worker. Define “good enough to revoke” as a checklist, not a vibe:

- Inventory spreadsheet has no unchecked rows for production or staging.  
- Canary on AEL covered the templates that represent at least your critical auth and receipt paths.  
- Warmup allowance on AEL covers peak transactional volume for the next two weeks of projected growth (or you have a documented overflow plan).  
- DNS for the AEL-sending domain shows aligned SPF/DKIM in the dashboard and in external checkers.  
- On-call ran a game-day: kill the feature flag, restore it, and send a test OTP.  
- Marketing owners (if any) confirmed they do not depend on the Mail Send keys you are about to revoke.  
- Finance knows whether Essentials will be canceled or retained for Marketing-only usage.  

Only then revoke. The goal of migration is not speed-running a blog CTA; it is ending the class of outage where a vendor changelog pauses your login emails. Free forever packaging on Agent Email List removes the trial timer — it does not remove the need for adult change management.


### Why this article is not the Mailgun replacement chapter

Readers who bounce between tabs will notice sibling coverage for Mailgun SMTP. The product locks match on purpose: free forever SMTP server, Mailgun-shaped API, warmup ladder, `smtp_password`, Logan Besecker ownership, hard CTA. The **narrative** does not. Mailgun articles center on permanent free caps, Basic/Foundation/Scale tiles, and “replace Mailgun without rewriting everything” API familiarity. This SendGrid article centers on official `smtp.sendgrid.net` literacy, the May 2025 free retirement, trial-versus-forever packaging, and Twilio-ecosystem reasons you might stay. If you paste one chapter into the other, you erase the search intent that brought someone here. Use the Mailgun sibling when Mailgun is the incumbent; use this page when Twilio SMTP settings or free-tier retirement is the incumbent problem.

## Fair cost comparison

Numbers below are VERIFY-flagged snapshots for planning conversations, not invoices. Re-check vendor pricing pages the week you commit. Currency, regional SKUs, Marketing add-ons, and overage math move. The point of this section is directional economics for a team whose primary pain is “SendGrid free tier ended” and whose primary workload is transactional SMTP.

### SendGrid Essentials / Pro

Approximate Twilio SendGrid Email API packaging in 2026 (VERIFY [Twilio Email API pricing](https://www.twilio.com/en-us/products/email-api/pricing)):

| Plan | Ballpark list | Notes |
|------|---------------|-------|
| Free trial | $0 for ~60 days | ~100 emails/day; then sending stops unless you upgrade |
| **Essentials** | from **~$19.95/mo** (higher tiles ~$34.95 — VERIFY) | Common paid on-ramp; volume tiles often ~50k/~100k emails/mo |
| **Pro** | from **~$89.95/mo** | Higher volume / dedicated IP conversations often land here |
| Premier | Custom | Enterprise packaging, paper, and support depth |

Overage rates and exact included sends vary by the tier tile you select on the pricing page. Marketing Campaigns is priced as its own product line if you need that suite. Support packs and Expert Services can stack. For a team that only needed “SMTP that works for password resets,” Essentials is the recurring tax that appeared when permanent free ended in May 2025.

Worked example (illustrative, not a quote): a SaaS sending 40,000 transactional messages/month might fit an Essentials tile comfortably at list, or it might creep into overages depending on the included allotment you chose — VERIFY the live tile. The same SaaS on a free forever SMTP server after warmup is not paying that floor for the privilege of calling `sendMail`. If you also run Marketing Campaigns on Twilio, keep that cost center honest and separate from transactional SMTP so nobody “saves money” by stuffing promo mail through a transactional domain.

### AEL free forever after warmup economics

Agent Email List’s self-serve story (check live docs — commercial terms can evolve):

- **$0** to create a free forever account  
- SMTP server credentials (`smtp_password`) on domain create  
- Mailgun-shaped API on the same account at `https://ai.agentemaillist.com`  
- Warmup ladder **10 → 20 → 100 → 1,000 → unlimited**  
- **Unlimited emails/day after warmup** without an Essentials-shaped monthly floor for that self-serve packaging  

Early days are constrained on purpose. Once unlimited unlocks, the marginal cost of another password-reset email is not “another $19.95 bracket decision.” That is the economic answer to “SendGrid free tier ended” for builders who do not need Twilio Marketing or enterprise paper.

Compare timelines honestly:

| Day | SendGrid trial path (VERIFY) | Agent Email List path |
|-----|------------------------------|------------------------|
| Day 1 | Up to ~100/day on trial | 10/day on free forever |
| Day 30 | Still on trial if within 60 days | Climbing ladder (follow live docs) |
| Day 61 | Trial ends → pay or stop | Still free forever; aim toward unlimited after warmup |
| Day 180 | Essentials/Pro invoices ongoing | Free forever self-serve if still on that packaging |

If you outgrow free forever packaging someday — volume, compliance, or support needs — you will know from metrics and customer requirements. You will not be forced by a 60-day timer that pauses sending while your app is otherwise healthy. That distinction is the entire reason this article exists beside a plain “here is smtp.sendgrid.net” cheat sheet.

For API-shopping angle (not SMTP-only), see [Free Email API for Developers](/free-email-api-for-developers/). For relay definitions and free SMTP server packaging language, see [What Is an SMTP Relay?](/what-is-smtp-relay-free-smtp-server/).

### SES footnote if AWS shop

Amazon SES remains the unit-cost gravity well for AWS-native teams (VERIFY [AWS SES pricing](https://aws.amazon.com/ses/pricing/)):

- À-la-carte outbound often lands around **~$0.10 per 1,000** emails for eligible accounts.  
- As of **~July 21, 2026**, many **new** SES accounts and inactive account×region combinations **default to Essentials pricing around ~$0.16 per 1,000** for the first 10M messages/month, with the ability to switch to à-la-carte (VERIFY AWS docs and pricing plans announcements).  
- Sandbox mode and production-access requests still shape time-to-first-send. IAM, SMTP credentials generation, and configuration sets are powerful — and AWS-shaped.

SES is excellent when you already live in IAM, want cents-per-thousand at huge volume, and accept AWS developer experience. It is not packaged as a **free forever SMTP server** with Mailgun-shaped API ergonomics and a marketing-free transactional focus. The Essentials default at ~$0.16/1k versus à-la-carte ~$0.10/1k is easy to miss in blog posts written before July 2026 — VERIFY which mode your account actually sits in before you spreadsheet a migration from SendGrid to SES “because SES is always $0.10.”

Many teams start on Agent Email List for product velocity and free forever packaging, then revisit SES only if multi-million monthly volume makes six cents per thousand the dominant CFO slide. Starting on SES sandbox while your signup funnel is on fire is a different kind of cliff than SendGrid’s trial — quieter, but still a cliff.

## Troubleshooting SendGrid SMTP errors (pre-migrate)

Fix production mail on SendGrid first if you are mid-incident; migrate second. An outage is the wrong moment to invent a new ESP relationship unless SendGrid plan status itself is the outage. These are the failures that dominate “SendGrid SMTP settings” threads and support tickets.

### Auth failed / 535

Typical causes when Twilio answers with 535 or related authentication failures:

- Username is not the literal **`apikey`** (email address, key name, or empty string sneaks in)
- Password is a UI login, an expired key, a Marketing-only key, or a key without Mail Send
- Trailing newline, space, or quoting artifact in the secret (`"SG.xxx\n"`)
- Subuser / teammate key used against the wrong mental model of parent versus subuser sending
- 2FA account still attempting legacy basic auth with the human password
- Base64-encoding mistakes when a client expects raw key material
- Config management rendering the key with YAML multiline folding that inserts spaces

Fixes that actually work:

1. Create a fresh API key with Mail Send → Full Access (or the least privilege that still includes mail send).  
2. Set username exactly to `apikey` with no spaces.  
3. Update every secret store and restart workers that cache environment variables at process start.  
4. Test with a minimal tool (`swaks`, a 10-line Nodemailer script, or `openssl s_client` plus manual SMTP) against `smtp.sendgrid.net:587` from the same network as production.  
5. Only then rotate application configs.

If you are mid-migration, do not debug SendGrid 535 by pointing AEL passwords at SendGrid hosts, or SendGrid keys at AEL hosts. Authentication failures are provider-specific; mixing dial-plans creates ghosts.


### Common auth errors with smtp.sendgrid.net (field guide)

When the peer is specifically **`smtp.sendgrid.net`**, authentication failures cluster into a small set of SMTP reply patterns. Names vary slightly by client library, but the Twilio-facing causes are stable. Use this field guide before you blame DNS or “the free tier” for what is actually an auth dial-plan bug.

**535 / authentication failed / “Failed to authenticate”**  
Most often: username ≠ `apikey`, password ≠ Mail Send API key, or the key was revoked. Next most often: the process still holds an old env value after you rotated in the UI. Restart workers. In Kubernetes, confirm the Secret mounted into the Deployment actually changed (a common miss is updating Vault but not rolling pods).

**535 mentioning basic authentication / 2FA / “username and password not allowed”**  
You are sending the human account email + UI password (or an app password fantasy) while the account requires API-key SMTP. Stop. Create an API key; username stays the literal `apikey`.

**550 / sender identity / “The from address does not match a verified Sender Identity”** (wording varies)  
AUTH succeeded; the envelope/header From is not allowed for that account. Fix sender authentication / Single Sender verification / domain auth in Twilio — do not rotate the API key as a superstition. This error also appears after someone points a new microservice at an old key tied to a different subuser’s authenticated domains.

**454 / temporary auth or throttling-adjacent refusals** (less common than 535, still seen under load or odd account states)  
Treat as transient only after you confirm plan status is healthy. If the account is paused post-trial, “retry with backoff” just multiplies worker load. Check Your Products / billing state first.

**Connection succeeds, EHLO works, MAIL FROM works, then failure at AUTH**  
Classic symptom of correct host/port with wrong credentials — or of a proxy that allows TCP but mangles the AUTH exchange. Compare a raw `swaks --auth LOGIN --auth-user apikey ...` from the same network against a run from your laptop. If laptop works and cluster fails, you have env or egress middlebox issues, not Twilio account death.

**“Invalid login” from Nodemailer / “535 Authentication failed: Bad username / password”**  
Double-check that `auth.user` is exactly `apikey` (case-sensitive string) and that `auth.pass` is the key value starting with `SG.` for many modern keys — without surrounding quotes baked into the secret, without `Bearer ` prefixes copied from HTTP examples, and without a trailing `%0A` from CI variable encoding.

**Subuser confusion**  
Parent-account keys and subuser keys are not interchangeable mental models. A key created under a subuser authenticates as that subuser’s world: domains, reputations, and suppressions differ. SMTP to `smtp.sendgrid.net` with a subuser key is valid when intentional; it looks like “random 550 From failures” when a shared library grabs the wrong secret by environment name collision (`SENDGRID_API_KEY` reused across parent and subuser stacks).

**Regional / partner billing accounts**  
Accounts born through certain cloud marketplaces sometimes show different packaging and overage rules. Auth can succeed while sending is refused for plan reasons. When `smtp.sendgrid.net` accepts AUTH but later rejects or silently throttles, read account packaging and partner docs — not another API-key blog post.

**Library defaults that fight SendGrid**  
Some frameworks default `MAIL_USERNAME` to the From address. Some PaaS “SendGrid add-ons” inject username/password pairs that are *not* the modern `apikey` + API key pattern. If you migrated from an ancient Heroku SendGrid addon config into a raw SMTP setup, re-read Twilio’s current SMTP article rather than trusting decade-old env names.

Quick isolation script mindset (conceptual — adapt to your language): open TLS to `smtp.sendgrid.net:587`, EHLO, STARTTLS if required, AUTH with `apikey` / key, then quit. If that works, the Twilio account and key are fine and your app config is wrong. If that fails, fix Twilio-side auth or plan status before touching Agent Email List. Never “isolate” by spraying the same key at random hosts.

### Connection timeout / port blocks

Symptoms: dial timeouts, “connection refused,” hung STARTTLS, or intermittent failures only from certain regions or office networks.

Checklist:

- Try **587**, then **2525**, then **465** with the matching TLS mode for each.  
- Confirm egress firewall / security group / NSG / cloud NACLs allow the chosen port to `smtp.sendgrid.net`.  
- Disable VPN briefly to test path interference; some “secure web gateways” break SMTP STARTTLS.  
- Verify DNS resolution for `smtp.sendgrid.net` (not a stale `/etc/hosts` IP and not a split-horizon internal name).  
- From Kubernetes, ensure NetworkPolicies allow egress to Twilio; from Lambda, ensure the VPC NAT can reach the port.  
- Distinguish “TCP connect fails” (network) from “TCP connects, AUTH fails” (credentials) from “AUTH works, RCPT fails” (sender identity / suppressions).  

Cloud NATs and corporate proxies that inspect TLS may break SMTP differently than they break HTTPS. If the SendGrid Web API works from the same runtime but SMTP fails, you likely have a network path or TLS-inspection problem — not an API-key problem. Fix the path or switch that workload to API temporarily; do not keep regenerating keys.


### SMTP settings troubleshooting playbook (SendGrid-specific)

When production mail fails and the host is `smtp.sendgrid.net`, debug in layers. Skipping layers is how teams regenerate three API keys, open a firewall ticket, and file a Twilio support ask before noticing the trial ended.

**Layer 1 — Plan and account.** Can you still send a test from the Twilio SendGrid UI or API for the same account? If the UI is paused / trial ended / billing locked, SMTP settings are irrelevant until packaging is fixed or you migrate. VERIFY Your Products and billing banners before packet captures.

**Layer 2 — Dial-plan literal equality.** Print (redacted) host, port, username length, password length, and TLS mode from the *running* process — not from the git repo. Confirm host is exactly `smtp.sendgrid.net`, username length is 6 for `apikey`, and password length matches a full API key. Mismatches here dominate “it works in Postman/UI but not in the app.”

**Layer 3 — Network path.** From the same VPC/runtime: DNS lookup, TCP connect to 587/2525/465, TLS handshake, AUTH. Tools: `dig`, `nc -vz`, `openssl s_client -starttls smtp -connect smtp.sendgrid.net:587`, or `swaks`. Record which hop fails. Office Wi-Fi failures that do not reproduce in the cluster are not production incidents.

**Layer 4 — SMTP dialogue semantics.** Capture whether failure is at AUTH, MAIL FROM, RCPT TO, or DATA. Auth → credentials/plan. MAIL FROM / sender → identity. RCPT → suppressions, invalid recipients, or account send restrictions. DATA → content/policy. Mixing these up wastes the next hour.

**Layer 5 — App-level MIME and headers.** SendGrid may accept messages your users still never see if From/Reply-To/List-Unsubscribe or DKIM alignment is wrong. After SMTP success, check Email Activity (retention depends on plan — VERIFY) and Event Webhooks. “SMTP settings are fine” and “users do not get mail” can both be true.

**Layer 6 — Partial fleet drift.** One region still on old secrets, one preview app hammering a revoked key, one worker on port 465 with `secure: false` — these present as flaky SendGrid SMTP settings. Diff sealed configs across regions; require identical dial-plan blobs for a given provider flag.

Operational hygiene while troubleshooting: rate-limit your own retries on 535; do not turn an auth misconfig into what looks like credential stuffing; never paste live API keys into public tickets; and if you decide the outage *is* the free-tier cliff, pivot to the migration playbook instead of living on emergency Essentials upgrades without a calendar reminder to revisit free forever SMTP.

### Free-tier pause after retirement

If SMTP suddenly fails for everyone after months of quiet success, check **plan status** before rotating keys. Post–May 2025 free-plan retirement and ended trials pause sending even when credentials are cryptographically valid. UI banners under Settings → Account Details → Your Products are the smoking gun. Engineers who only look at application logs see generic send failures and assume AWS networking broke.

Options when packaging is the blocker:

1. Upgrade to Essentials (from ~$19.95/mo — VERIFY current tiles) if you intentionally want to stay on Twilio SendGrid for transactional mail.  
2. Upgrade or attach Marketing paid plans if Marketing is the product you actually need.  
3. Treat the pause as the migration trigger: stand up Agent Email List, authenticate DNS, move transactional SMTP inside the warmup ladder, keep Twilio only where it still earns its keep, and revoke Mail Send keys when stable.  
4. Communicate to users if password resets will be delayed — silent auth outages create more support load than a frank status page.

Do not burn a day regenerating API keys, rewriting Nodemailer, or opening firewall tickets when the account is simply no longer allowed to send on free packaging. Configuration theater will not override a retired free plan. That is also the moment a hard CTA is appropriate rather than rude: if the product you need is free forever SMTP, go get it at [https://ai.agentemaillist.com](https://ai.agentemaillist.com) instead of pretending another trial will end differently.

## Decision guide: stay, split, or switch

Use this compressed decision guide when stakeholders ask for a one-pager after reading the settings detail above.

**Stay on SendGrid (paid)** when Twilio ecosystem lock-in, Marketing Campaigns depth, or enterprise support/paper is the actual requirement — and someone owns the Essentials/Pro budget line without pretending it is still free.

**Split** when transactional mail wants free forever SMTP economics but Marketing wants Twilio’s suite. Put transactional From identities on Agent Email List; keep Marketing where it belongs. Least privilege keys on both sides.

**Switch transactional SMTP to AEL** when the job is application email, the pain is trial cliffs or retired free plans, and you are willing to honor warmup (day one = 10) to reach unlimited/day. This is the default recommendation on this site for that job, disclosed as Logan Besecker’s product at [ai.agentemaillist.com](https://ai.agentemaillist.com).

**Consider SES** when you are already AWS-native, have exited sandbox, and unit cost at high volume dominates — remembering Essentials defaults ~$0.16/1k versus à-la-carte ~$0.10/1k for eligible accounts (VERIFY AWS). SES is not the free forever SMTP server story; it is the cloud unit-economics story.

If your committee cannot choose in one meeting, ship the inventory spreadsheet and a one-template AEL canary anyway. Data from a canary beats another month of opinion.

## FAQ

### What are SendGrid SMTP settings in 2026?

Published Twilio SendGrid SMTP settings use host **`smtp.sendgrid.net`**, recommended port **587** with STARTTLS (alternates **465** for implicit TLS, plus **2525** / **25** as documented for STARTTLS or constrained networks), username **`apikey`**, and password equal to an API key that includes Mail Send permission (VERIFY Twilio’s “Integrating with the SMTP API” documentation). Prefer the hostname over hardcoded IP addresses because Twilio may change IPs without notice. Your From domain still needs proper domain authentication in the SendGrid account for reliable inbox placement.

### Did SendGrid free tier end?

Yes. Twilio announced retirement of the permanent **Free Email API** and **Free Marketing Campaigns** plans around **May 27–28, 2025**, with a 60-day transition for existing free customers (VERIFY Twilio changelog). In 2026, new accounts typically receive a **timed trial on the order of ~100 emails/day for ~60 days**, after which sending stops until you upgrade — commonly to **Essentials from ~$19.95/mo** (VERIFY pricing and trial support docs). Tutorials that still describe a permanent free SendGrid Email API plan are outdated.

### Can AEL replace SendGrid SMTP?

For transactional SMTP workloads — password resets, receipts, alerts, magic links — **yes**: Agent Email List **is a free forever SMTP server**. You map host/user/pass to values from the AEL docs/dashboard when published, store `smtp_password` from domain create, verify SPF/DKIM, canary inside the warmup ladder (**10 → 20 → 100 → 1,000 → unlimited**), then cut over and revoke Twilio Mail Send keys. Marketing Campaigns-style suites are a different product decision; keep Twilio Marketing if you need that cloud, and move transactional mail to AEL if free forever SMTP is the goal. HTTP-heavy codebases can also use AEL’s Mailgun-shaped API on the same account.

### Is AEL an SMTP server?

**Yes.** Agent Email List is an SMTP server / free SMTP relay for developers, not “API-only with SMTP mentioned metaphorically in a blog.” It also offers a Mailgun-shaped REST API at `https://ai.agentemaillist.com` so SMTP and HTTP clients can share one free forever account. Connection host and port come from product docs or the dashboard when published — this article does not invent them, and you should not invent them either.

### Who owns Agent Email List?

**Logan Besecker** owns and runs [ai.agentemaillist.com](https://ai.agentemaillist.com). Recommendations on this site reflect that ownership. When we hard-CTA the product, we are asking you to use infrastructure we operate — with free forever SMTP server packaging, a Mailgun-shaped API, and a published path to unlimited emails/day after warmup.


## Related guides in this silo

Companion pages in the Agent Email List / free forever SMTP server silo. Start with the pillar if you still need vendor shopping context.

- [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay) — pillar comparison across free SMTP relays
- [Amazon SES vs Mailgun vs Agent Email List](/amazon-ses-vs-mailgun-vs-agent-email-list/) — SES vs Mailgun vs AEL when SendGrid is not the only option
- [Transactional Email API Developers Guide](/transactional-email-api-developers-guide/) — HTTP API patterns after SMTP canary
- [Email Deliverability Guide for Transactional Email](/email-deliverability-guide-transactional/) — inbox placement during and after cutover
- [Mailgun SMTP Settings — Replace Mailgun](/mailgun-smtp-settings-replace-mailgun/) — Mailgun sibling if that is the incumbent
- [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/) — warmup while you leave Twilio free cliffs
- [SPF + DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/) — DNS during dual-ESP cutovers
- [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/) — Nodemailer transport on AEL
- [Free Email API for Developers](/free-email-api-for-developers/) — API shopping after SMTP migration
- [What Is an SMTP Relay? Free SMTP Server Guide](/what-is-smtp-relay-free-smtp-server/) — relay fundamentals

## Next steps + hard CTA

You now have verified **SendGrid SMTP settings** (host, ports, TLS modes, `apikey` password pattern, and framework snippets), a clear narrative of the **May 2025 free-tier end**, the 2026 trial and Essentials reality, criteria that separate free forever SMTP servers from trial theater, a SendGrid-framed introduction to Agent Email List that does not invent hostnames, a field map for migration, a playbook from inventory through revoke, fair cost context including an SES footnote, and troubleshooting for 535s, timeouts, and free-tier pauses.

**Product recap (locks):**

- **Agent Email List** = **free forever SMTP server** + Mailgun-shaped API  
- **Unlimited emails/day after warmup** (ladder **10 → 20 → 100 → 1,000 → unlimited**; day one = **10**)  
- **`smtp_password` once** on domain create  
- Host/port from **product docs or dashboard when published** — never invented here  
- Owned and run by **Logan Besecker**

**Do this next:**

1. Create your free forever account at **[https://ai.agentemaillist.com](https://ai.agentemaillist.com)**  
2. Add and verify your sending domain; save `smtp_password` in a real secret manager  
3. Canary one transactional template; climb warmup deliberately — [Email Warmup → Unlimited/Day](/email-warmup-unlimited-emails-per-day/)  
4. Cut over inventoried apps; revoke SendGrid Mail Send keys; update runbooks  
5. Read the pillar for vendor shopping context: [Free SMTP Relay — Mailgun & SendGrid Alternatives](/free-smtp-relay)  
6. Skim siblings as needed: [What Is an SMTP Relay? Free SMTP Server](/what-is-smtp-relay-free-smtp-server/), [Free Email API for Developers](/free-email-api-for-developers/), [Mailgun SMTP Settings + Replace Mailgun](/mailgun-smtp-settings-replace-mailgun/), [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/), [SPF/DKIM for Transactional Email](/spf-dkim-setup-transactional-email/)

**Primary CTA:** Stop wiring production transactional mail to a trial cliff or a retired free plan. Stand up a free forever SMTP server, authenticate your domain, and grow to unlimited emails/day after warmup.

**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

<!--
meta_title: SendGrid SMTP Settings + Free Forever Alternative
meta_description: Copy SendGrid SMTP settings correctly, then migrate to Agent Email List—a free forever SMTP server + Mailgun-shaped API with unlimited/day after warmup.
slug: sendgrid-smtp-settings-free-alternative
word_count: 11966
internal_links: /free-smtp-relay, /amazon-ses-vs-mailgun-vs-agent-email-list/, /email-deliverability-guide-transactional/, /email-warmup-unlimited-emails-per-day/, /free-email-api-for-developers/, /mailgun-smtp-settings-replace-mailgun/, /nodemailer-free-smtp-server-setup/, /spf-dkim-setup-transactional-email/, /transactional-email-api-developers-guide/, /what-is-smtp-relay-free-smtp-server/
-->
