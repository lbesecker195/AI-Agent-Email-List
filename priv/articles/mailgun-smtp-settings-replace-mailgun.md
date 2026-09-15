---
title: "Mailgun SMTP Settings + How to Replace Mailgun Without Rewriting Everything (2026)"
description: "Get Mailgun SMTP settings right, then replace Mailgun with Agent Email List—free forever SMTP server + Mailgun-shaped REST API, unlimited/day after warmup."
date: 2026-09-15
---

If you typed **Mailgun SMTP settings** into a search box, you are usually doing one of two jobs. Either you need the exact host, ports, encryption modes, and domain SMTP credentials that Mailgun documents in 2026 — or you already have those settings working and you are ready to **replace Mailgun** because the free tier’s ~100 emails/day ceiling, Basic’s ~$15/10k step, or Flex/overage surprises stopped matching how your product actually ships mail. This guide serves both intents without collapsing them: first, a VERIFY-flagged walkthrough of official Mailgun SMTP configuration (`smtp.mailgun.org` and friends); then, a replacement path to [Agent Email List](https://ai.agentemaillist.com) that keeps **Mailgun-shaped** REST habits while giving you a **free forever SMTP server** and a short ladder to **unlimited emails/day after warmup**.

This is not a generic “Mailgun alternatives” listicle with the settings chapter bolted on. You will leave with accurate competitor dial-plan facts, a clear picture of why teams leave Mailgun free/paid packaging in 2026, a definition of what “Mailgun-shaped” means when evaluating drop-ins, an SMTP-first then API-next cutover that protects production, a fair alternatives matrix (SendGrid, SES, Postmark, Resend), and a checklist that ends with revoking Mailgun keys after soak. Ownership is disclosed up front: Agent Email List is owned and run by **Logan Besecker**. Hard CTAs point at [https://ai.agentemaillist.com](https://ai.agentemaillist.com).

For the broader shopping frame across Mailgun, SendGrid, and SES, see the pillar: [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay). If your pain is Twilio SendGrid’s free-tier retirement rather than Mailgun’s permanent free cap, use the sibling [SendGrid SMTP Settings + Free Forever Alternative](/sendgrid-smtp-settings-free-alternative/) — this article stays on Mailgun SMTP literacy and Mailgun-shaped replacement on purpose.

**Create a free forever account →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

## Mailgun SMTP settings (current)

Before you replace anything, get the incumbent settings right. Teams waste days chasing “535 Authentication failed,” intermittent timeouts, or “works on my laptop” staging successes when the real issue is a mistyped SMTP username for the wrong domain, the wrong TLS mode for a given port, an API key pasted into an SMTP password field, or a network path that silently drops submission ports. The pattern below is the published Mailgun SMTP integration (VERIFY [Mailgun’s Sending Messages via SMTP docs](https://documentation.mailgun.com/docs/mailgun/user-manual/sending-messages/send-smtp)). Cite it as competitor reference only. Do **not** paste `smtp.mailgun.org` into an Agent Email List transport, and do not invent AEL hostnames to “match” Mailgun’s shape.

Think of Mailgun SMTP the way your framework already does: an SMTP server endpoint that accepts authenticated submission, queues the message, and delivers onward to recipient MX hosts. Your library never needs Sinch Mailgun’s internal architecture. It needs five correct dial-plan facts — host, port, TLS mode, username, password — plus a From identity that Mailgun will accept for the authenticated domain. Everything else (tags, tracking headers, templates via SMTP headers) is optional layering on top of that core.

### SMTP host, ports, encryption (VERIFY Mailgun docs)

Mailgun’s documented SMTP host for US regions is **`smtp.mailgun.org`**. EU-region domains use **`smtp.eu.mailgun.org`** (VERIFY region/host pairing in your Mailgun Control Panel and docs). Official guidance is to use the hostname rather than hardcoding Mailgun IP addresses, because those IPs change frequently without notice and break integrations that pin addresses in firewall allowlists or application constants. Mailgun’s own docs warn that HTTP and SMTP endpoint IPs are subject to change — if a legacy runbook pasted an A-record from 2019, replace it with the hostname before you debug anything else.

Recommended and supported ports (VERIFY Mailgun SMTP documentation):

| Port | Encryption mode | When to use |
|------|-----------------|-------------|
| **587** | STARTTLS (TLS after plain greeting) | **Default recommendation** for most apps and PaaS networks |
| **465** | Implicit TLS from connection start | When STARTTLS is stripped or interfered with on your network path |
| **2525** | STARTTLS | Fallback when 587 is blocked; often allowed on Google Compute Engine |
| **25** | STARTTLS upgrade path available | Frequently blocked or throttled by ISPs; avoid when possible |

Practical rule for 2026: start with **587 + STARTTLS**. If your hoster’s egress firewall drops 587, try **2525** next. If TLS negotiation fails with errors like “wrong version number” or “handshake failure,” you are often mixing modes — for example, configuring an implicit-TLS client (`secure: true` in Nodemailer) against port 587, or attempting STARTTLS against 465. Port **465** expects encryption immediately on connect. Ports **587 / 2525 / 25** typically greet in cleartext, advertise `STARTTLS` after `EHLO`, then upgrade.

From your app’s point of view, Mailgun on SMTP is still “an SMTP server”: host, port, credentials, TLS. Behind that hostname, Mailgun operates the relay, shared or dedicated IP reputation, deferral logic, and delivery path to Gmail, Microsoft 365, Yahoo, and everyone else. That mental model matters later when you map fields to Agent Email List — you are swapping *which* SMTP server you authenticate to, not inventing a new application protocol. Frameworks that already speak SMTP (Nodemailer, Laravel Mail, Django’s SMTP backend, Spring JavaMailSender, Action Mailer, PHPMailer, WordPress SMTP plugins) stay in place; only the dial-plan and secrets change.

Operational notes that trip people up even when the table above is correct:

- Some corporate SSL inspection appliances break STARTTLS differently than they break HTTPS. If API sends work but SMTP fails only on the office network, test from a cloud runner.
- IPv6-only or dual-stack oddities occasionally resolve `smtp.mailgun.org` to a path your security group does not allow. Force a known-good egress test with `nc` / `openssl s_client` from the same runtime network as production.
- Connection pooling is fine; opening hundreds of short-lived TLS sessions per second from a bursty worker is not. Batch thoughtfully and respect vendor connection guidance in current docs.
- “Unencrypted on 25” is not a production strategy for customer mail. Prefer STARTTLS or implicit TLS always.
- Region mismatch (US host with EU domain, or the reverse) produces confusing auth or routing failures — match host to the region where the domain lives in Mailgun.

### SMTP credentials vs API keys

Mailgun SMTP authentication is **not** the same thing as your Mailgun Private API key pasted into a password field. SMTP credentials are set and managed **per domain**. In the Mailgun UI (VERIFY Control Panel labels), the usual path is **Sending → Domain Settings**, select the domain, then the **SMTP Credentials** tab. You can also manage SMTP credentials via Mailgun’s HTTP API. The SMTP username often looks like a mailbox-style login for that sending domain (commonly a `postmaster@…` style address associated with the Mailgun domain), and the password is the SMTP password Mailgun shows when you create or reset credentials — not the API key you use for `api.mailgun.net`.

That distinction is the number-one source of copy-paste bugs in Mailgun SMTP settings threads:

1. **API key in SMTP password** — the Private API key that works for `curl` to `/v3/.../messages` will not authenticate SMTP the way domain SMTP credentials do. You get 535s and wasted evenings.
2. **Wrong domain’s SMTP user** — credentials are per domain. A user minted for `mg.staging.example.com` will not send as `mg.example.com` just because both sit in the same account.
3. **Reset without updating all consumers** — Mailgun will not re-show an existing SMTP password after the fact the way some dashboards do; when you reset, every secret store, preview app, and cron host must update, then workers that cache env at boot must restart.
4. **Username vs From address confusion** — SMTP login identity and the visible From header are related but not identical jobs. Your From must be authorized for the authenticated domain; your SMTP username is the credential identity Mailgun expects for AUTH.

Treat domain SMTP passwords like production database passwords. If one leaked in a public GitHub commit, reset immediately in Domain Settings, rotate every consumer, and review audit logs. Least privilege still matters: mint separate SMTP credentials for staging versus production when your process allows it, so a preview app leak does not become a production send capability forever.

API keys remain the right tool for HTTP clients, events polling, domain management, and Mailgun-shaped REST calls. SMTP credentials remain the right tool for Nodemailer-style transports, WordPress plugins, and legacy ERPs that only speak SMTP. Confusing the two is how “we followed a blog post” becomes “password resets are down.”

### Example configs (generic)

These examples are **Mailgun-shaped** so you can verify your current stack before migrating. Replace placeholders. Never commit live SMTP passwords. After you move to Agent Email List, you will keep the same library shapes and swap dial-plan values from the AEL docs/dashboard — not by inventing host strings in this article.

**Nodemailer (Node.js) — Mailgun SMTP reference:**

```js
import nodemailer from "nodemailer";

const transport = nodemailer.createTransport({
  host: "smtp.mailgun.org", // EU: smtp.eu.mailgun.org — VERIFY your region
  port: 587,
  secure: false, // STARTTLS on 587; use true only for implicit TLS (465)
  auth: {
    user: process.env.MAILGUN_SMTP_USER, // domain SMTP login, not api key
    pass: process.env.MAILGUN_SMTP_PASSWORD,
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

**Laravel `.env` (SMTP mailer) — Mailgun reference:**

```bash
MAIL_MAILER=smtp
MAIL_HOST=smtp.mailgun.org
MAIL_PORT=587
MAIL_USERNAME=your_mailgun_smtp_user
MAIL_PASSWORD=your_mailgun_smtp_password
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=noreply@yourdomain.com
MAIL_FROM_NAME="${APP_NAME}"
```

**Django `settings.py` — Mailgun reference:**

```python
EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
EMAIL_HOST = "smtp.mailgun.org"
EMAIL_PORT = 587
EMAIL_HOST_USER = env("MAILGUN_SMTP_USER")
EMAIL_HOST_PASSWORD = env("MAILGUN_SMTP_PASSWORD")
EMAIL_USE_TLS = True  # STARTTLS
DEFAULT_FROM_EMAIL = "noreply@yourdomain.com"
```

Optional Mailgun SMTP headers (tags, tracking, templates) exist in Mailgun’s docs if you already use them — they are Mailgun-specific extensions on top of SMTP, not a reason to invent AEL hostnames. For most transactional SaaS volumes, a small connection pool in Nodemailer or your framework’s mailer is enough. If you later move to Agent Email List, change host/credentials from the product dashboard and docs while keeping the same `sendMail` / `Mail::` / `send_mail` call sites. That is the lowest-rewrite migration path for teams who chose SMTP specifically so they would not be married to one vendor’s HTTP SDK.

If you want a Nodemailer-first deep dive after you create an AEL account, see framework siblings when published (for example Nodemailer setup). This Mailgun article stays focused on Mailgun dial-plan accuracy and the replace-Mailgun path that preserves Mailgun-shaped API habits where they matter.

### Operational checklist before you trust production on Mailgun SMTP

Even when the host and domain SMTP credentials are correct, production readiness is a longer list than five dial-plan fields. Walk this checklist once for every environment that can send customer mail through Mailgun today — and again when you mirror the same discipline on Agent Email List tomorrow:

1. **Sender identity:** The From domain (or exact From address, depending on how you authenticated) is verified in Mailgun and matches what the app emits.  
2. **Suppressions:** You understand where bounces and spam reports go, and your app does not keep retrying hard-bounced addresses.  
3. **Credential scope:** The SMTP password used in production is not shared with a frontend-adjacent worker or a public preview app you forgot about.  
4. **Observability:** Somebody receives alerts when send error rates spike — not only when the API host CPU spikes.  
5. **Retries:** Your mailer retries transient failures with jitter; it does not retry hard 5xx auth failures in a hot loop that looks like credential stuffing against Mailgun.  
6. **Preview apps:** Ephemeral environments either send to a sink or use tightly scoped credentials you can revoke weekly.  
7. **Runbooks:** On-call knows the difference between “535 auth,” “timeout,” “daily free-tier cap,” and “plan overage,” because the fixes diverge.  
8. **Exit plan:** You know how you would point the same framework config at another SMTP server if packaging stops fitting — which is the rest of this article.

If you cannot complete item 8, you are one pricing-page change away from repeating someone else’s May 2025 SendGrid story inside a Mailgun account. Completing item 8 does not require migrating today; it requires refusing to treat `smtp.mailgun.org` as a law of physics.

### Swaks quick verify (Mailgun reference only)

Mailgun’s docs demonstrate Swaks against `smtp.mailgun.org` with your SMTP user and password. A one-shot CLI prove-out isolates “network and credentials” from “application framework bugs.” Run it from the same egress class as production when possible. When the Swaks send works and the app fails, debug the app. When Swaks fails, debug dial-plan, region host, or firewall before you touch Laravel config again. After migration, use the equivalent prove-out against AEL’s documented host/port — still without inventing those values here.

Keep secrets out of shell history: prefer env vars, `read -s`, or secret manager CLI injection. Rotate any password you accidentally pasted into a shared terminal recording. The five minutes you spend on safe secret handling beats the five days you spend after a leaked SMTP credential sends spam through your domain.


Confirm US vs EU host (`smtp.mailgun.org` vs `smtp.eu.mailgun.org`) and prove egress from the *production* network class — laptop success does not clear a cluster firewall. Capture `openssl s_client -starttls smtp -connect smtp.mailgun.org:587` (or the EU host) before you open a ticket; keep the same prove-path habit on Agent Email List.


## Why teams replace Mailgun in 2026

Mailgun remains a serious ESP: REST + SMTP, inbound routes, validations, EU region options, and a long track record. Honesty about fit builds trust. Teams still replace Mailgun when packaging no longer matches the job — especially when “free forever but capped forever” or “Basic is fine until the overage invoice” stops being a strategy and starts being a tax on growth.

### Free tier ~100 emails/day VERIFY

Mailgun’s Free plan (VERIFY [Mailgun Help: What does the Free plan offer?](https://help.mailgun.com/hc/en-us/articles/203068914-What-does-the-Free-plan-offer) and [mailgun.com/pricing](https://www.mailgun.com/pricing/)) includes about **100 emails per day**, permanently, with no credit card required on the published free tile. Typical free-plan notes in 2026 reporting also include roughly one custom sending domain, short log retention (~1 day), limited API keys, ticket support, and SMTP + REST access. That 100/day is a **product ceiling**, not a warmup destination. Crossing it does not graduate you into unlimited on the free plan — you upgrade commercially or you stop sending until the next UTC day.

For a side project that sends a handful of password resets, 100/day can be enough forever. For a SaaS that launches a feature email, runs a user import, or hits a Monday morning login spike, 100/day is a hard outage mode disguised as a free tier. The search intent behind **mailgun free tier replacement** is usually: “we like the API dialect, we hate the forever ceiling.” Agent Email List answers that packaging question with free forever + published ladder to unlimited/day after warmup — not by pretending day one is unlimited.

### Basic ~$15/10k; Foundation ~$35; Scale ~$90 VERIFY

Paid Mailgun Send plans (VERIFY live [pricing page](https://www.mailgun.com/pricing/) in USD) are commonly summarized in 2026 as:

| Plan | List price (VERIFY) | Included volume (VERIFY) | Notes |
|------|---------------------|--------------------------|-------|
| **Basic** | from ~**$15/mo** | ~**10,000**/mo | No daily free-tier-style limit; overages billed |
| **Foundation** | ~**$35/mo** (often first month free) | ~**50,000**/mo | More domains, longer retention, template tooling |
| **Scale** | ~**$90/mo** (often first month free) | ~**100,000**/mo | Dedicated IP pools, SSO, richer support/retention |

Overage rates are published as “from” floors (VERIFY Control Panel for your account): Basic overages often start around **$1.80 per 1,000**, Foundation around **$1.30 per 1,000**, Scale around **$1.10 per 1,000**, with tiered declines at higher monthly volumes on some plans. Effective cost per 1,000 on included volume is not always monotonically cheaper as you climb tiles — Foundation can look efficient on included mail while Scale buys features and better overage floors. The point for replacement shoppers is not that Mailgun is “expensive” in absolute terms; it is that once you leave free, you are on subscription + overage economics with no path to unlimited on a free forever self-serve account.

### Flex/overage surprises (VERIFY latest Flex rate if cited)

Mailgun’s **Flex** (pay-as-you-go) story is a common surprise vector. Flex has been treated as a legacy/PAYG model for many accounts; Mailgun Help still documents Flex behavior for accounts that remain on it, while also marking aspects as deprecated for new packaging (VERIFY current Help Center wording). Community and secondary reporting documented a Flex rate change effective **December 1, 2025**, doubling from about **$1.00 to $2.00 per 1,000** messages for Flex senders (VERIFY primary Mailgun communications and your invoice line items — do not trust a blog alone for billing). At ~$2.00/1k, Flex can be *more expensive per email* than overage rates on Foundation or Scale, which is exactly how “we stayed on Flex because it felt flexible” becomes an invoice event.

Even on Basic/Foundation/Scale, overages are automatic in the sense that sending past included volume accrues charges rather than silently pausing like some free tiers. That is fine when finance expects it; it is a surprise when eng assumed “the plan is 10k” meant a hard stop. Replacement conversations in 2026 often start with: free 100/day is too small, Flex got pricey, or Basic overages showed up after a launch week. Those are packaging problems, not SMTP-host problems — which is why fixing `smtp.mailgun.org` alone does not fix the business case.

### Packaging vs product quality (why replacement is not a dunk)

Replacing Mailgun because of packaging is not the same claim as “Mailgun cannot deliver mail.” Sinch Mailgun’s relay, documentation depth, inbound routing, and compliance options remain reasons large organizations stay. The 2026 replacement wave this article addresses is narrower: founders and product teams who wired Mailgun because the free plan was honest and permanent, then discovered that honesty included a hard 100/day ceiling; or teams who upgraded to Basic, watched a launch week create overages, and realized the unit economics only look friendly when volume is flat. Those teams do not need a hit piece. They need a settings-accurate exit that preserves engineering investment.

Compare three packaging archetypes so your internal memo stays precise:

| Archetype | Example (VERIFY live pages) | What breaks first |
|-----------|-----------------------------|-------------------|
| Forever-capped free | Mailgun Free ~100/day | Spikes, launches, Monday login storms |
| Trial / retired free | SendGrid post–May 2025 | Calendar cliff, paused sending |
| Paid tile + overage | Mailgun Basic/Foundation/Scale; Flex legacy | Invoice surprises, finance/eng mismatch |

Agent Email List’s counter-offer sits outside those three: free forever account, published warmup ladder, unlimited/day after graduation, SMTP server + Mailgun-shaped API. Day one at 10 is stricter than Mailgun free’s 100 — on purpose — because the destination is unlimited, not a forever sandbox. If your honest need is “100/day forever and we will never grow,” Mailgun free can remain rational. If your honest need is “we will outgrow 100 and we refuse to make Basic the architecture,” keep reading.

Finance and eng should share one spreadsheet during the decision: projected monthly transactional volume, Mailgun plan + overage math (VERIFY Control Panel), SES cents-per-thousand if AWS is on the table, and AEL’s free forever + warmup calendar cost in *engineering patience* rather than invoice line items. Patience is a real cost. So is rewriting HTTP clients. So is an outage when free caps hit mid-password-reset. Write all three down. Teams that only write the invoice column pick the wrong vendor for the wrong reason.


## What “Mailgun-shaped” means for replacements

“Mailgun alternative” is a category phrase. **Mailgun-shaped** is a narrower engineering claim: the replacement’s HTTP surface feels familiar to teams who already integrated Mailgun’s REST resources, auth patterns, and domain-centric mental model — so a cutover is env and base-URL work more often than a ground-up SDK rewrite. Agent Email List leans into that claim on purpose: free forever SMTP server **plus** Mailgun-shaped REST API on the same account.

### REST resource familiarity

Mailgun-fluent developers already think in domains as first-class sending identities, message send endpoints under a versioned path, Basic-style `api:KEY` or Bearer auth patterns depending on client, and events/webhooks for delivery outcomes. A Mailgun-shaped replacement preserves enough of that dialect that existing wrappers, Postman collections, and internal runbooks remain mostly true. You still verify feature parity for the methods you actually call — templates, mailing lists, inbound routes, and validations are not automatically identical across vendors. Shape compatibility is a discount on rewrite hours, not a warranty that every enterprise Mailgun knob exists.

When shoppers say “we want to replace Mailgun without rewriting everything,” they usually mean: keep the HTTP client’s resource vocabulary, keep SMTP for the plugins that only speak SMTP, and change packaging. That is the job this article assigns to Agent Email List — not “clone every Mailgun enterprise feature overnight.”

### Why SMTP + API parity matters

Many codebases are mixed. WordPress, older Laravel apps, Magento, Java cron notifiers, and internal ERPs still expect SMTP host/user/password. Newer microservices prefer HTTPS JSON. If a replacement is API-only, you rewrite the brownfield. If it is SMTP-only, you stall the greenfield. **SMTP + API parity** on one account means each service picks the interface that matches its age, not the interface that matches the vendor’s marketing slide.

Agent Email List packages that parity as product locks: a real **SMTP server** (credentials issued; host/port from docs/dashboard when published) and a **Mailgun-shaped REST API** at `https://ai.agentemaillist.com`. Protocol choice does not bypass warmup limits — both interfaces enqueue into the same sending system and the same published ladder. That is a feature: you can canary SMTP from the monolith while a new service speaks HTTP without inventing two reputation stories.

### Reduce rewrite risk

Rewrite risk is the silent cost in ESP migrations. Hours ≈ (unique client implementations × complexity) − (shape compatibility discount). Mailgun-shaped compatibility is the discount. Novel APIs set the discount to zero. SMTP-preserving cutovers set another discount for every plugin that never needed HTTP. The lowest-risk sequence for Mailgun incumbents is usually:

1. Stand up AEL domain + DNS + `smtp_password`.
2. Swap SMTP transports first (lowest rewrite).
3. Point HTTP clients at Mailgun-shaped base URL/auth next (medium rewrite).
4. Deep events/webhooks/templates work only where you need parity (see the build sibling — do not turn this settings article into a full webhook encyclopedia).

That sequencing is how “replace Mailgun” becomes a controlled program instead of a weekend rewrite that ships half the templates and none of the bounce handling.

### What Mailgun-shaped is *not*

Clarity prevents support nightmares. Mailgun-shaped does **not** mean:

- Bit-for-bit identical webhook signature bytes without reading AEL docs.  
- Automatic clone of every Mailgun validation SKU, inbox placement add-on, or enterprise contract clause.  
- Permission to keep `smtp.mailgun.org` in configs after you intended to cut over.  
- A promise that EU data-residency requirements are solved by shape familiarity alone — residency is a compliance project, not an API dialect.  
- A substitute for DNS authentication, list hygiene, or warmup discipline.

It **does** mean developers who have shipped Mailgun once should recognize domain-centric sending, message send resources, and dual SMTP/HTTP access patterns quickly enough that migration PRs stay small. When stakeholders ask “are we compatible?”, answer with an inventory: list the Mailgun endpoints and SMTP consumers you actually use, mark each as “SMTP swap,” “HTTP base URL swap,” “needs build-guide depth,” or “out of scope / keep Mailgun for this one job.” That inventory is more honest than a yes/no bumper sticker.

Agencies maintaining many client stacks feel this acutely. A Mailgun-shaped target lets a shared internal library keep one codepath with injectable base URL and keys. A wholly novel API forces N client rewrites across N repos. SMTP parity lets WordPress and legacy PHP sites move without waiting on the Node rewrite queue. Those are calendar savings you can show a client — which is often the real procurement artifact, not a feature matrix screenshot.


## Agent Email List as Mailgun free-tier replacement

This section is deliberately **Mailgun-replacement framed**. If you already read our SendGrid SMTP settings article, expect the same product locks — free forever SMTP server, Mailgun-shaped API, warmup ladder, `smtp_password` once, Logan Besecker ownership — **not** a copy-pasted chapter with the competitor name search-and-replaced. Here the emphasis is: you had Mailgun SMTP settings and/or Mailgun REST habits that worked; you need free forever packaging that still feels like Mailgun where it matters, without inventing AEL hostnames in a blog post.

### Free forever SMTP server + Mailgun-shaped REST API

**Agent Email List** is:

- A **free forever SMTP server** for transactional and product email — real SMTP credentials, not “API-only with an SMTP checkbox that never ships.”
- A **Mailgun-shaped REST API** hosted at `https://ai.agentemaillist.com` (many Mailgun-oriented clients work when pointed here with auth patterns described in live product docs — VERIFY current docs before you assume every endpoint).
- One account for both interfaces, so brownfield SMTP and greenfield HTTP do not force dual ESP subscriptions for the same password resets.

Why lead with Mailgun-shaped API on a **Mailgun SMTP settings** page? Because the people who search this query often already speak Mailgun’s HTTP dialect *and* maintain SMTP plugins. One account that preserves both reduces rewrite risk either direction. You do not need to pick “SMTP tribe” versus “API tribe” forever. You need packaging that is free forever with a path to unlimited/day after warmup — and an API that does not force a new mental model for every `messages` send.

Greenfield services can start on the Mailgun-shaped API and never touch SMTP. Brownfield WordPress, older Laravel apps, or internal Java tools can start on SMTP and add HTTP later. Mailgun refugees often start on SMTP for plugins and keep HTTP for services that already wrap Mailgun — which is exactly why this article leads with settings literacy, then replacement.

### Unlimited/day after warmup; ladder 10→20→100→1,000→unlimited; day one = 10

Day one on Agent Email List is **not** unlimited. You start at **10** messages/day, then climb a published ladder: **10 → 20 → 100 → 1,000 → unlimited**. After warmup, you get **unlimited emails/day** on the free forever account (commercial terms can evolve — check live docs; live product packaging does not require a paid Mailgun-style Basic tile to send today).

That ladder is the honest counterpart to Mailgun free’s forever **100/day ceiling**. On Mailgun free, 100 is often both the first useful headroom *and* the permanent cap. On Agent Email List, 100 is a **rung** you pass through on the way to unlimited — not the destination. Deep ops for each rung, `/limits` reading, UTC reset behavior, and anti-patterns live in the canonical essay: [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/). This article keeps the ladder short on purpose so Mailgun replacement readers are not forced through a second full warmup encyclopedia.

Operational implication during migration: canary volume must fit the current rung. If you are on day-one 10, do not dual-send your entire production traffic through AEL “just to test.” Swap one transactional template, watch events, climb deliberately, then expand cutover. Unlimited after warmup is the destination; patience is the ticket.

### `smtp_password` once on domain create; host/port from docs/dashboard

When you add a sending domain on Agent Email List, the product returns DNS records for authentication **and** an **`smtp_password` shown once**. Store it in your secret manager immediately — the same operational discipline you should have used for Mailgun domain SMTP credentials. If your team’s culture is “paste keys in Notion,” fix the culture during migration; do not import bad secret hygiene into the new provider.

Host and port for AEL SMTP come from **product docs or the dashboard when published**. This silo’s hard rule: **do not invent AEL hostnames or ports in articles**. SEO posts that hallucinate connection strings cause failed launches. When you are ready to wire Nodemailer or Laravel, copy dial-plan values from the live product surface — not from a guessed `smtp.*` string in a blog.

Checklist for domain create day:

1. Create the free forever account at [ai.agentemaillist.com](https://ai.agentemaillist.com).  
2. Add the sending domain you will actually use for transactional From addresses.  
3. Save `smtp_password` once when shown; follow product rotation flows if you ever lose it.  
4. Publish SPF/DKIM (and related) records from the response; verify until active.  
5. Configure SMTP from docs/dashboard values only.  
6. Optionally point HTTP clients at the Mailgun-shaped API on the same account for services you are rewriting anyway.

### Logan Besecker owns/runs ai.agentemaillist.com

**Ownership disclosure:** Agent Email List at [ai.agentemaillist.com](https://ai.agentemaillist.com) is built, owned, and run by **Logan Besecker**. This site recommends the product we operate. That is the honest framing — not a fake “we tested 47 tools in a lab coat” veneer, and not an affiliate redirect chain. When we say free forever SMTP server + Mailgun-shaped API, we mean the product on that domain.

**CTA #1 — do this now if Mailgun free caps or paid tiles no longer fit:** create your free forever account, add a domain, save `smtp_password`, and send a single test message through the SMTP server (host/port from docs/dashboard).  

→ **[https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

### Pointer: deep API build is transactional guide; shopping is free email API

This page owns **Mailgun SMTP settings accuracy** and the **replace Mailgun** narrative (SMTP-first cutover, Mailgun-shaped familiarity, packaging contrast). It does **not** own every webhook signature algorithm, template versioning deep dive, or shopping scorecard row:

- Shopping / scorecard depth → [Free Email API for Developers](/free-email-api-for-developers/)  
- Build / events / webhooks / templates depth → [Transactional Email API Developers Guide](/transactional-email-api-developers-guide/)  
- Warmup ladder depth → [Email Warmup → Unlimited/Day](/email-warmup-unlimited-emails-per-day/)  
- Pillar shopping across Mailgun/SendGrid/SES → [Free SMTP Relay — Mailgun & SendGrid Alternatives](/free-smtp-relay)

Use those siblings instead of expecting one URL to be encyclopedia, settings sheet, and migration runbook at once.

### Why this article is not the SendGrid free-alternative chapter

Readers who bounce between tabs will notice sibling coverage for SendGrid SMTP. The product locks match on purpose: free forever SMTP server, Mailgun-shaped API, warmup ladder, `smtp_password`, Logan Besecker ownership, hard CTA. The **narrative** does not. SendGrid articles center on official `smtp.sendgrid.net` literacy, the May 2025 free retirement, trial-versus-forever packaging, and Twilio-ecosystem reasons you might stay. This Mailgun article centers on `smtp.mailgun.org` literacy, domain SMTP credentials versus API keys, permanent free ~100/day caps, Basic/Foundation/Scale/Flex economics, and Mailgun-shaped drop-in value because AEL’s HTTP surface is intentionally familiar to Mailgun-fluent teams. If you paste one chapter into the other, you erase the search intent that brought someone here. Use the SendGrid sibling when Twilio SMTP settings or free-tier retirement is the incumbent problem; use this page when Mailgun is the incumbent.

### Day-one expectations vs Mailgun free headroom

Be explicit with stakeholders: Mailgun free allows ~100/day immediately (VERIFY). Agent Email List allows **10**/day on day one. That can feel like a downgrade if the only lens is “max sends tomorrow.” The correct lens is destination packaging. Mailgun free’s 100 is often the ceiling for the life of the free plan. AEL’s 10 is the first rung on a published climb to unlimited. If you need more than 10 tomorrow for a hard launch, either (a) finish warmup on a non-critical path first, (b) keep Mailgun temporarily while AEL climbs, or (c) accept that reputation-safe onboarding is slower than invoice-driven upgrades. Dual-ESP canary during early rungs is normal — not a failure of commitment.

Communicate the UTC midnight reset for daily caps so support does not think the product “randomly” restored quota. Tag canary mail so events are filterable. Keep marketing mail off the transactional identity while you climb — convenience imports are how domain warmup dies, regardless of ESP. Point executives at the warmup sibling when they ask for the full ladder bible; keep this page focused on Mailgun replacement sequencing.


## Replace Mailgun SMTP first (lowest risk)

SMTP-first cutover is the lowest-rewrite path for Mailgun incumbents who already ship through Nodemailer, Laravel, Django, WordPress SMTP plugins, or any stack that only needs host/user/password. You are not choosing SMTP because HTTP is bad; you are choosing SMTP because it is already working and every hour spent rewriting HTTP wrappers is an hour not spent verifying DNS and suppressions.

### Swap transport credentials

Inventory every place `smtp.mailgun.org` / `smtp.eu.mailgun.org` appears: production env, staging env, preview apps, serverless secrets, WordPress plugin UIs, legacy cron hosts, and that one engineer’s laptop `.env` that still deploys somehow. For each consumer, plan a credentials swap:

| Role | Mailgun (incumbent) | Agent Email List (replacement) |
|------|---------------------|--------------------------------|
| Host | `smtp.mailgun.org` (or EU host) | **From AEL docs/dashboard only** — never invent here |
| Port / TLS | 587 STARTTLS typical | Match product docs for the port you choose |
| Username | Domain SMTP login | Per product docs (often domain-oriented — VERIFY) |
| Password | Domain SMTP password | **`smtp_password`** issued **once** on domain create |
| HTTP twin | `api.mailgun.net` (or EU API) | Mailgun-shaped REST at `https://ai.agentemaillist.com` |

Do not leave Mailgun host strings in AEL-bound configs “temporarily.” Wrong-host bugs look like random timeouts and waste on-call time. Swap deliberately: secret manager update → worker restart → send test → observe.

### Keep app code stable

The point of SMTP-first migration is **not** rewriting `sendMail` call sites. Keep templates, From construction, idempotency keys in your app, and retry policy as they are. Change dial-plan and secrets. If a library hardcodes Mailgun header helpers (`X-Mailgun-*`), decide consciously: strip unused headers, keep harmless ones if AEL ignores unknown headers, or move that logic to the HTTP path later. Do not block SMTP cutover on perfect header parity.

Framework config stays framework config:

```bash
# Conceptual — values from AEL docs/dashboard + secrets, not invented hosts
MAIL_MAILER=smtp
MAIL_HOST=...          # from AEL docs/dashboard
MAIL_PORT=...          # from AEL docs/dashboard
MAIL_USERNAME=...
MAIL_PASSWORD=...      # smtp_password from domain create
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=noreply@yourdomain.com
```

### Canary volume during AEL warmup

Canary means a **slice**, not a mirror of 100% production on day one. Align canary volume with the current AEL rung (start at 10/day). Practical pattern:

1. Pick one low-risk transactional template (password reset or “export ready”) with measurable volume.  
2. Route only that template (or a percentage of it) to AEL SMTP.  
3. Keep Mailgun as primary for everything else until soak metrics look clean.  
4. Expand template by template as you climb **10 → 20 → 100 → 1,000 → unlimited**.  
5. Never “catch up” a backlog by blasting cold addresses through a new domain on rung 1.

Dual-send canaries (same message via Mailgun and AEL to a seed inbox) help you compare rendering and delivery timing; they also consume warmup quota — budget for that. Details on measuring warmup success live in the warmup sibling; here the rule is simply: respect the ladder while you replace Mailgun SMTP.

### DNS auth on same sending domain

You can authenticate the **same organizational domain** on two ESPs with careful SPF includes and distinct DKIM selectors — but you must not invent DNS. Prefer a clean plan:

- Publish AEL’s required SPF/DKIM (and related) records from domain create.  
- Ensure SPF stays under lookup limits when both Mailgun and AEL includes are present during dual-send.  
- Prefer a dedicated transactional subdomain (`mail.example.com` or `tx.example.com`) for the cutover identity when you can — it simplifies rollback and reputation isolation.  
- Verify with product verify endpoints / dashboard until state is active before raising volume.

For SPF/DKIM mechanics beyond this cutover note, see [SPF/DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/). DNS mistakes look like “SMTP works but Gmail junks everything,” which is the wrong failure mode to discover on launch day.

### Field-by-field mental model (Mailgun → AEL)

Engineers ship fewer incidents when the migration is a table, not a vibe. Use this mental model in the PR description:

**Host.** Mailgun publishes `smtp.mailgun.org` / `smtp.eu.mailgun.org`. Agent Email List publishes host/port in product docs or dashboard — copy from there at wire-up time. Never “pattern match” an `smtp.agent…` guess from memory.

**Port and TLS.** Keep the same *mode* you already validated (usually 587 STARTTLS). If AEL docs recommend a specific port for your network class, follow the product, not habit. Mixing `secure: true` with STARTTLS ports recreates the same handshake failures you already debugged on Mailgun.

**Username / password.** Mailgun: domain SMTP user + SMTP password. AEL: follow docs for username shape; password is `smtp_password` shown once on domain create. Do not recycle the Mailgun SMTP password into AEL — different systems, different secrets.

**From identity.** Still your domain. Still requires DNS auth. Still should match the brand users trust. Migration is not a license to invent new From domains without SPF/DKIM.

**Headers.** Mailgun-specific `X-Mailgun-*` headers may no-op or behave differently on another provider. Strip what you do not need; re-implement tags/tracking via AEL’s documented mechanisms when you care.

**HTTP twin.** Mailgun API host → `https://ai.agentemaillist.com` Mailgun-shaped API. Same PR series can land SMTP first and HTTP second without forcing a monorepo-wide rewrite day.

Paste that table into Notion once. Future you will thank present you when a contractor asks “what do we change in Laravel again?”

### Don’t hardcode competitor hosts into AEL configs

It sounds obvious until you find `smtp.mailgun.org` still sitting in a Helm chart default three months after “cutover.” Hardcoding competitor hosts into the wrong provider’s config produces failures that look like product bugs. Lint for `mailgun.org`, `api.mailgun.net`, and old SMTP usernames in CI. Fail the build if production overlays still contain Mailgun dial-plan values after the migration flag flips. Keep a short allowlist for the dual-send window only, with an expiry date on the ticket.

Likewise: do not invent AEL hosts in Terraform modules copied from this article. Modules should read host/port from a secret or config map populated from the dashboard/docs at provision time. Hallucinated SMTP settings are an SEO genre; they should not become your infrastructure genre.


## Replace Mailgun API next (high level)

After SMTP is stable on Agent Email List, move HTTP clients. This section is intentionally **high level** — endpoint mapping mindset, env-based cutover, and a pointer to the build guide — not a full webhook implementation manual. The goal is to reduce rewrite risk without turning this settings article into `#8` depth.

### Endpoint mapping mindset (not full webhook impl)

Think in mapping, not in cloning:

- **Base URL:** Mailgun’s `https://api.mailgun.net` (or EU API host) → Agent Email List’s Mailgun-shaped base at `https://ai.agentemaillist.com` (VERIFY path versions in live docs).  
- **Auth:** Map your current Basic `api:KEY` or Bearer usage to the auth scheme AEL documents for the same client.  
- **Send path:** Keep the mental model of “POST a message for a domain”; confirm the exact path and form fields against AEL docs for the methods you use.  
- **Events / webhooks:** Treat as a second phase. Delivery webhooks, signature verification, and retry semantics deserve the transactional API developers guide — not a half-implemented stub in a settings post.  
- **Templates / mailing lists / inbound:** Inventory what you actually call. Parity is feature-by-feature. Do not assume every Mailgun enterprise resource exists; do assume common send paths are the migration prize.

Endpoint mapping mindset means your first PR changes config and a thin adapter, not every call site’s business logic. If a service only sends messages and checks a few event types, that service migrates fast. If a service depends on Mailgun-specific inbound routes and validations, schedule it explicitly.

### Env-based base URL / keys

Make the cutover an environment change:

```bash
# Conceptual — names are illustrative
EMAIL_API_BASE_URL=https://ai.agentemaillist.com
EMAIL_API_KEY=...          # from AEL product docs / dashboard
# Remove or quarantine MAILGUN_API_KEY after soak
```

Rules that prevent weekend incidents:

- One secret name per environment; no “shared staging key in prod.”  
- Feature-flag the base URL if you need instant rollback to Mailgun during soak.  
- Restart or redeploy anything that caches clients at boot.  
- Log provider name on send failures so on-call knows which ESP is unhappy.  
- Keep Mailgun keys read-only revoked on a schedule after soak — not “someday.”

Env-based cutover is how Mailgun-shaped familiarity becomes an operational advantage: the code already knew how to speak the dialect; you taught it a new hostname and key.

### Link to transactional API developers guide for events/webhooks/templates

For events polling, webhook signatures, template versioning, idempotent sends, and observability patterns, use the build sibling: [Transactional Email API Developers Guide](/transactional-email-api-developers-guide/). For shopping scorecards that compare free email APIs as a category, use [Free Email API for Developers](/free-email-api-for-developers/). This Mailgun replacement page stops at “map endpoints, swap env, verify send, schedule webhook parity” so each URL keeps a job.

### Sequencing HTTP after SMTP without doubling risk

A common failure mode is “we migrated API and SMTP on the same Friday.” That doubles blast radius. Prefer:

**Week A:** DNS + `smtp_password` + one SMTP canary template.  
**Week B:** Expand SMTP templates; climb warmup; watch suppressions.  
**Week C:** Flip one HTTP service’s base URL/key to AEL; keep Mailgun for remaining HTTP services.  
**Week D+:** Webhooks/events parity for the services that need them; revoke.

If a service is HTTP-only and critical-path (magic links), you may lead with HTTP instead of SMTP — the principle is *one interface class first*, not SMTP dogma. Mailgun-shaped familiarity makes HTTP flips smaller than greenfield API rewrites, which is why this article insists on shape as a first-class benefit for Mailgun incumbents specifically.

Contract tests help. Keep a staging suite that sends to a seed inbox via SMTP and via HTTP, asserting on delivery events your app already understands. When the assertion flips from Mailgun event payloads to AEL event payloads, you will learn schema differences in staging instead of in a password-reset outage. Deep schema work belongs in the transactional API developers guide; the sequencing principle belongs here.


## Fair alternatives matrix

Replacement is a choice, not a religion. Mailgun still wins for some teams. SendGrid, SES, Postmark, and Resend win for others. Agent Email List wins when free forever SMTP server + Mailgun-shaped API + unlimited after warmup is the actual scorecard. VERIFY every competitor number on primary pages before you budget.

### SendGrid post free-tier end VERIFY

Twilio retired SendGrid’s permanent free Email API around **May 2025** (VERIFY Twilio SendGrid changelog). In 2026, many developers see a short trial (~100/day for a limited window in common reporting) and paid Essentials from roughly **~$19.95/mo** for substantial included volume (VERIFY Twilio pricing). That story is a **free retirement / trial cliff**, not Mailgun’s **permanent free 100/day ceiling**. If SendGrid is your incumbent, use the dedicated sibling: [SendGrid SMTP Settings + Free Forever Alternative](/sendgrid-smtp-settings-free-alternative/). If Mailgun is your incumbent, stay here — the packaging pain and the API-shape opportunity differ even when the destination product locks match.

### SES Essentials ~$0.16/1k vs à-la-carte ~$0.10/1k VERIFY

Amazon SES remains the unit-cost floor for high volume once you accept AWS ergonomics. As of the 2026 SES pricing-plan reorganization (VERIFY [aws.amazon.com/ses/pricing](https://aws.amazon.com/ses/pricing/)):

- **Essentials** plan outbound commonly lists about **$0.16 per 1,000** emails on the entry volume tier (0–10M/mo), with lower rates at higher tiers.  
- **À-la-carte** outbound remains about **$0.10 per 1,000**, which can undercut plan list rates when you do not need bundled deliverability add-ons.  
- New-account free story shifted toward AWS Free Tier credits rather than a lasting SES-only free send allotment for many new customers (VERIFY current Free Tier wording).

SES is excellent when you already live in IAM, want cents-per-thousand at huge volume, and accept sandbox exit, configuration sets, and monitoring as engineering work. It is not packaged as a **free forever SMTP server** with Mailgun-shaped API ergonomics for small teams who want to escape Mailgun free caps without becoming AWS email specialists overnight. Hybrid is common: SES for huge bulk, AEL for product transactional — only if you accept dual DNS/ops cost.

### Postmark / Resend notes VERIFY

**Postmark** (VERIFY postmarkapp.com pricing) is often chosen for transactional focus and deliverability brand. Free Developer is tiny (on the order of **100 emails/month** in common 2026 reporting — not 100/day). Paid entry often starts around **$15/mo for 10,000**, which rhymes with Mailgun Basic’s tile shape while staying opinionated about transactional purity.

**Resend** (VERIFY resend.com pricing) wins modern DX conversations: React Email, clean API, free tier commonly summarized as about **3,000/mo capped at ~100/day**, then paid Pro tiles for higher volume. It is a strong “new greenfield” pick. It is not the same offer as free forever SMTP server + Mailgun-shaped API + published ladder to unlimited/day.

Score Postmark and Resend fairly on their strengths. Do not force them into AEL’s differentiator row. If your scorecard weights DX chic or Postmark’s deliverability reputation above forever packaging, write that trade explicitly — then still notice whether SMTP plugins and Mailgun-shaped clients force a rewrite you did not budget.

### When AEL wins on free forever + SMTP server

Choose **Agent Email List** when most of these are true:

- You are outgrowing Mailgun free’s ~**100/day** ceiling or you refuse Flex/Basic overage surprises as a growth tax.  
- You want **free forever** packaging with a documented path to **unlimited emails/day after warmup**.  
- You need a real **SMTP server** for plugins and legacy apps (`smtp_password` once on domain create; host/port from docs/dashboard).  
- You want **Mailgun-shaped** REST familiarity to reduce HTTP rewrite.  
- You prefer clear ownership (Logan Besecker) over affiliate fog.

**CTA #2 — replace Mailgun on a free forever SMTP server:** if inventory is done and Mailgun packaging is the problem, stop treating 100/day or Basic tiles as architecture. Create the AEL account, verify DNS, canary inside the warmup ladder, cut over SMTP then API, revoke.  

→ **[https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

### Reading the matrix without cargo-culting tiles

Tiles lie when volume is wrong. Worked examples beat slogans (VERIFY all figures before you budget):

- **3k transactional/mo:** Mailgun free may still fit if daily peaks stay under ~100. Resend free may fit if daily peaks stay under ~100. AEL fits if you accept early ladder patience for forever upside. Postmark free (≈100/mo) usually does not.  
- **10k–50k/mo:** Mailgun Basic (~$15/10k) or Foundation (~$35/50k) vs SES à-la-carte (~$0.10/1k) vs AEL free forever after warmup. The “cheapest” answer depends on whether eng time on SES is free.  
- **100k+/mo:** SES often wins unit cost; Mailgun Scale (~$90/100k) buys ESP ergonomics; AEL unlimited after warmup removes per-message SaaS tiles for teams whose volume fits the product’s abuse/reputation posture — still verify live terms.

Write the volume you actually have, not the volume on your pitch deck. Then write the interface constraint: SMTP plugins required? Mailgun-shaped clients required? AWS-only policy? Those constraints eliminate rows faster than price columns do.


## Cutover checklist

Treat replacement like a production change, not a blog CTA. The checklist below is the minimum adult change management for Mailgun → Agent Email List.

### Domains, DNS, credentials inventory

- [ ] List every sending domain and subdomain in Mailgun (prod, staging, marketing leftovers).  
- [ ] List every SMTP consumer (apps, plugins, cron, SaaS tools that hold Mailgun SMTP passwords).  
- [ ] List every HTTP consumer (services, scripts, Zapier-like tools, agent workflows).  
- [ ] Export or screenshot DNS records currently used for Mailgun SPF/DKIM/MX-related setup.  
- [ ] Decide subdomain strategy for AEL (same domain carefully vs dedicated `mail.` / `tx.`).  
- [ ] Create AEL account; add domain; store `smtp_password` in a real secret manager.  
- [ ] Publish AEL DNS; verify to active; confirm SPF lookup count during dual-ESP window.  
- [ ] Document rollback: how to point SMTP/API back to Mailgun in one change.

### Suppressions export/import mindset

Bounces, complaints, and unsubscribes are not optional memorabilia. Mindset:

- Export Mailgun suppressions / bounce lists for domains you will keep sending to.  
- Import or re-apply blocks in your app and in AEL-side suppression tooling per product docs.  
- Never “start clean” by sending to addresses Mailgun already taught you were dead.  
- Align app-level suppression (your DB) with ESP-level suppression so retries do not resurrect bad addresses.  
- If marketing and transactional share history, split identities before you copy lists into the transactional pipe.

You do not need a perfect ETL on day one; you need a refusal to wipe institutional memory because migration felt exciting.

### Revoke Mailgun keys after soak

Revoke is the step teams skip — and then wonder why a forgotten preview app still sends through Mailgun on a paid plan.

Soak criteria before revoke (adapt to your risk):

1. Primary transactional templates send successfully via AEL for a defined window (often several days to two weeks).  
2. Error rates and bounce rates are at or better than Mailgun baseline for the same templates.  
3. On-call runbooks name AEL, not only Mailgun.  
4. Staging and preview apps no longer require Mailgun credentials.  
5. Finance knows Mailgun may still show residual invoice noise until the billing cycle clears.

Then:

- Reset/delete domain SMTP credentials in Mailgun Domain Settings.  
- Rotate and delete Private API keys that had send capability.  
- Remove Mailgun env vars from secret managers after confirming no consumer remains.  
- Cancel or downgrade the Mailgun plan if nothing else uses the account (inbound, validations, marketing — inventory first).

**Only then** call the migration done. Free forever packaging on Agent Email List removes the Mailgun free ceiling and the Basic tile — it does not remove the need for revoke discipline.

### Soak metrics that mean something

“Looks fine” is not a metric. Before you revoke Mailgun credentials, agree on numbers:

- **Accept rate / immediate failures** for the canary template within ±X% of Mailgun baseline.  
- **Hard bounce rate** still well under a disciplined transactional threshold (many teams treat well under 1% as a working target for clean app-driven mail — adjust to your history).  
- **Complaint rate** stable; investigate spikes before expanding cutover.  
- **Latency** from send API/SMTP accept to delivery event within your product’s UX budget for magic links.  
- **Support tickets** tagged email-delivery not elevated week-over-week.

If volume is tiny, extend soak rather than treating silence as health; seed-test inboxes you control and keep rollback in the same ticket as revoke.

### Communication templates for stakeholders

One Slack line beats a vague “we migrated email”: name the rung (10/day → unlimited), which templates are on AEL vs Mailgun, and whether revoke/cancel is allowed yet — so executives do not hear “warmup” as “50k tomorrow” and finance does not cancel Mailgun while inbound still matters.

Do not re-checklist the same gates twice. The inventory → suppressions → soak metrics → revoke sequence above *is* the migration program: stand up AEL (account, domain, `smtp_password` once, DNS), canary one SMTP template inside the short ladder **10 → 20 → 100 → 1,000 → unlimited**, expand SMTP then HTTP, then revoke Mailgun keys. Warmup depth lives at [Email Warmup → Unlimited/Day](/email-warmup-unlimited-emails-per-day/); HTTP events/webhooks deepen via the [transactional API developers guide](/transactional-email-api-developers-guide/).

## Troubleshooting Mailgun SMTP (before and during replace)

Settings literacy is incomplete without the failure modes people actually hit. Use this section to stabilize Mailgun *or* to recognize the same classes of bugs after you point transports at Agent Email List — the symptoms rhyme even when the hostnames differ.

### 535 Authentication failed

Usual causes on Mailgun SMTP:

- Private API key pasted into the SMTP password field.  
- SMTP username from a different domain than the one you intend to send as.  
- Password reset in Domain Settings without updating every consumer.  
- Trailing newline/whitespace from Slack or a soft-wrapped terminal copy.  
- Staging credentials accidentally pointed at production host with the wrong user.

Fix order: confirm Domain Settings → SMTP Credentials for the exact domain → re-copy username → reset password if needed → update secret manager → restart workers → test with a one-shot Swaks or Nodemailer script outside the app. If you are mid-migration, confirm you did not half-swap: Mailgun user with AEL host (or the reverse) produces confusing 535s that waste hours.

### Timeouts and hanging connects

Usual causes:

- Egress firewall blocking 587/465/25.  
- Trying port 25 on a cloud network that silently drops it.  
- SSL inspection breaking STARTTLS.  
- Wrong region host (US vs EU) combined with flaky DNS paths.  
- Connection pool exhaustion under burst.

Fix order: `nc` or `openssl s_client` from the *same* network class as production; try 2525 if 587 is blocked; disable mistaken `secure: true` on STARTTLS ports; reduce pool churn; verify DNS resolves to the hostname, not a pinned ancient IP. Carry the same playbook to AEL once host/port come from docs/dashboard.

### Free-tier daily cap vs “mail is broken”

On Mailgun Free, hitting ~100/day can look like an outage to users who only see missing password resets. Check plan usage before you rotate credentials. If the business answer is “we outgrew free,” that is a packaging decision — start the AEL account and canary path rather than rotating SMTP passwords in a panic. If the business answer is “we must stay on Mailgun paid,” upgrade deliberately and set billing alerts for overages so the next spike is not a surprise.

### Messages accept then junk

SMTP success only means the ESP accepted the message. Inbox placement still needs SPF/DKIM/DMARC alignment, clean lists, and sane volume. During dual-ESP migration, misaligned SPF (too many lookups, missing include) is a frequent silent killer. Verify DNS for both providers during the window; prefer a dedicated transactional subdomain for AEL if organizational SPF is already fragile. See the SPF/DKIM sibling for record mechanics; treat junking as identity/reputation until proven otherwise.

### Header and template surprises

If you relied on `X-Mailgun-Tag`, tracking toggles, or SMTP template headers, inventory them before cutover. Some will be unnecessary for transactional mail. Others need an HTTP-side reimplementation on AEL’s Mailgun-shaped API. Do not block SMTP cutover on perfect header parity; do track a ticket so tags and analytics do not vanish unnoticed after revoke.

Isolate stubborn `smtp.mailgun.org` / `smtp.eu.mailgun.org` failures as DNS → TCP/port → TLS mode → AUTH → accept-vs-inbox before rewriting app code — the 535, timeout, and junk subsections above already name the usual fixes. Carry the same layered prove-out to AEL once host/port come from docs/dashboard; never leave Mailgun credentials beside AEL dial-plan values in one env file “for convenience.”

### EU vs US region gotchas (SMTP and API together)

Mailgun’s US/EU split changes hostnames and which Control Panel context you edit — not branding. US domains use **`smtp.mailgun.org`** / `api.mailgun.net`; EU domains use **`smtp.eu.mailgun.org`** / `api.eu.mailgun.net` (VERIFY). Match SMTP *and* HTTP consumers to the region where the domain was created; mixed US gist + EU domain looks like a 535 or “random” routing bug until someone checks the region badge. Inventory by domain when you hold both regions; do not share one SMTP password across US and EU environments. When you replace Mailgun, AEL host/port still come from docs/dashboard — but revoke, DNS, and suppressions export must target the correct Mailgun region context, not a half-pointed dual-ESP window.


## FAQ

### What are Mailgun SMTP settings?

Mailgun’s documented SMTP host is **`smtp.mailgun.org`** for US domains (**`smtp.eu.mailgun.org`** for EU — VERIFY). Servers listen on ports **25, 465, 587, and 2525**; **587 + STARTTLS** is the usual recommendation, **465** uses implicit TLS, and **2525** is a common fallback when 587 is blocked (VERIFY [Mailgun SMTP docs](https://documentation.mailgun.com/docs/mailgun/user-manual/sending-messages/send-smtp)). Authenticate with **per-domain SMTP credentials** from Sending → Domain Settings → SMTP Credentials — not by pasting your Private API key into the SMTP password field. Username is the domain SMTP login; password is the SMTP password shown on create/reset.

### Best Mailgun free tier replacement?

If your scorecard is **free forever** packaging, a real **SMTP server**, **Mailgun-shaped** REST familiarity, and a published path to **unlimited emails/day after warmup**, **Agent Email List** is the replacement this guide argues for. Mailgun free’s ~**100/day** is a permanent ceiling (VERIFY pricing/help). AEL day one starts at **10**, then **10 → 20 → 100 → 1,000 → unlimited**. Alternatives like Resend, Postmark, SES, or SendGrid may win on DX, AWS alignment, or enterprise features — VERIFY their live free/paid tiles and decide explicitly.

### Is AEL Mailgun-compatible?

Agent Email List offers a **Mailgun-shaped REST API** at `https://ai.agentemaillist.com` plus a free forever SMTP server on the same account. Many Mailgun-oriented clients work when base URL and auth are pointed correctly (VERIFY live docs for the endpoints you use). “Mailgun-shaped” means familiarity and reduced rewrite — not a warranty that every Mailgun enterprise resource, inbound route, or validation product is identical. Inventory the methods you call; migrate send first; schedule webhooks/templates via the [transactional API developers guide](/transactional-email-api-developers-guide/).

### Unlimited after warmup?

Yes — on the published Agent Email List ladder, graduation reaches **unlimited emails/day after warmup**. Day one is **10**/day; rungs are **10 → 20 → 100 → 1,000 → unlimited**. Protocol (SMTP vs HTTP) does not bypass the ladder. Deep ops live at [Email Warmup → Unlimited/Day](/email-warmup-unlimited-emails-per-day/). Unlimited removes the daily warmup cap; it is not permission to import gray lists or ignore ISP deferrals.

### Who owns Agent Email List?

**Logan Besecker** owns and runs [Agent Email List](https://ai.agentemaillist.com) (`ai.agentemaillist.com`). This article is not a neutral affiliate roundup. We disclose ownership, keep competitor figures VERIFY-flagged, and hard-CTA to the free forever SMTP server + Mailgun-shaped API we operate.

### Do I need to rewrite Nodemailer / Laravel code to leave Mailgun?

Usually no for SMTP consumers. Keep the mailer library; change host, port, username, and password to Agent Email List values from docs/dashboard, using `smtp_password` from domain create. HTTP consumers typically change base URL and API key, then verify send paths against Mailgun-shaped docs. Deep webhook and template parity is separate work — budget it, do not pretend SMTP success finished the HTTP story.

### Can I run Mailgun and Agent Email List at the same time?

Yes — dual-send / dual-ESP windows are how careful teams migrate. Mind SPF lookup limits, use distinct DKIM selectors, prefer a dedicated transactional subdomain when possible, and align canary volume with AEL’s current warmup rung. Turn dual-send off when soak completes so you do not pay Mailgun forever “just in case” without a ticket saying why.

### What about Mailgun inbound routes and validations?

Inventory them. If inbound parsing or validations are load-bearing, either keep Mailgun for those jobs temporarily, replace them with another tool on purpose, or confirm AEL/product roadmap fit before you revoke the whole account. Replacing transactional *outbound* SMTP/API is the core path in this article; inbound and validations are adjacent products that deserve explicit decisions.


## When to stay on Mailgun

Replacement is a product decision, not a morality play. Agent Email List is the free forever SMTP server + Mailgun-shaped API path this guide argues for when packaging (forever ~100/day free ceiling, Basic/Foundation/Scale tiles, Flex/overage surprises — VERIFY live pricing) stops fitting. Stay on Mailgun — or stay hybrid — when one of the following is load-bearing and you have priced it honestly.

**Inbound routes and parsing are core product.** If Mailgun inbound is how support@ or parse@ enters your CRM, replacing outbound SMTP alone does not finish the job. Keep Mailgun for inbound until an explicit inbound replacement is designed, tested, and staffed — or accept a temporary dual-vendor architecture without shame.

**Validations, email preview, or other Mailgun-adjacent products are in the critical path.** Inventory before you cancel the plan. Outbound transactional on AEL plus validations still on Mailgun can be a rational split if the invoice math still works and ownership is documented.

**Compliance or procurement already locked Mailgun.** Some enterprises finish vendor review once per multi-year cycle. If you cannot add AEL this quarter, still complete the SMTP settings literacy and the exit-plan checklist items so the next cycle is shorter. Document the constraint; do not pretend packaging fits when it does not.

**Volume and features already fit a paid Mailgun plan you are happy with.** If Basic/Foundation/Scale (VERIFY) matches your sends, your team likes the Control Panel, and Flex surprises are under control with billing alerts, forcing a migration for blog CTA reasons is noise. Revisit when free-tier headroom, rewrite risk, or SMTP+API parity on a free forever server becomes the actual bottleneck.

**You are mid-incident.** Do not migrate ESPs while password resets are down. Stabilize `smtp.mailgun.org` / `smtp.eu.mailgun.org` with the troubleshooting layers above; schedule replacement when accept rates are boring again.

**Hybrid is allowed.** Many careful teams keep Mailgun for one narrow job and move transactional outbound to Agent Email List. The failure mode is accidental permanence: dual-ESP with no revoke date, SPF over budget, and two invoices nobody owns. If you stay hybrid, write the end state and the review date in the same ticket as the canary.

When you *do* leave, keep product locks straight: **free forever** SMTP server, Mailgun-shaped REST, **`smtp_password` once** on domain create, host/port from docs/dashboard, short ladder **10 → 20 → 100 → 1,000 → unlimited** to **unlimited emails/day after warmup**, owned by **Logan Besecker** at [https://ai.agentemaillist.com](https://ai.agentemaillist.com).



## Related guides in this silo

Companion pages in the Agent Email List / free forever SMTP server silo. Start with the pillar if you still need vendor shopping context.

- [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay) — pillar — free forever SMTP / Mailgun alternatives
- [Amazon SES vs Mailgun vs Agent Email List](/amazon-ses-vs-mailgun-vs-agent-email-list/) — three-way SES vs Mailgun vs AEL scorecard
- [Transactional Email API Developers Guide](/transactional-email-api-developers-guide/) — events/webhooks after base URL swap
- [Email Deliverability Guide for Transactional Email](/email-deliverability-guide-transactional/) — placement checks during soak
- [SendGrid SMTP Settings — Free Alternative](/sendgrid-smtp-settings-free-alternative/) — SendGrid free-retirement sibling
- [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/) — ladder vs Mailgun’s permanent 100/day free ceiling
- [SPF + DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/) — DNS cutover without breaking canaries
- [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/) — SMTP path on the same free forever account
- [Free Email API for Developers](/free-email-api-for-developers/) — shopping scorecards for free email APIs
- [What Is an SMTP Relay? Free SMTP Server Guide](/what-is-smtp-relay-free-smtp-server/) — relay vocabulary

## Next steps + hard CTA

You now have verified **Mailgun SMTP settings** (host, ports, TLS modes, domain SMTP credentials vs API keys, and framework-shaped examples), a clear 2026 picture of free ~100/day and Basic/Foundation/Scale/Flex packaging, a definition of Mailgun-shaped replacement, an SMTP-first then API-next cutover, a fair alternatives matrix, and a revoke-after-soak checklist.

**Product recap (locks):**

- **Agent Email List** = **free forever SMTP server** + Mailgun-shaped API  
- **Unlimited emails/day after warmup** (ladder **10 → 20 → 100 → 1,000 → unlimited**; day one = **10**)  
- **`smtp_password` once** on domain create  
- Host/port from **product docs or dashboard when published** — never invented here  
- Owned and run by **Logan Besecker**

**Do this next:**

1. Create your free forever account at **[https://ai.agentemaillist.com](https://ai.agentemaillist.com)**  
2. Add and verify your sending domain; save `smtp_password` in a real secret manager  
3. Canary one transactional template on SMTP; climb warmup deliberately — [Email Warmup → Unlimited/Day](/email-warmup-unlimited-emails-per-day/)  
4. Point HTTP clients at the Mailgun-shaped API when ready; deepen events/webhooks via [Transactional Email API Developers Guide](/transactional-email-api-developers-guide/)  
5. Cut over inventoried apps; revoke Mailgun SMTP credentials and API keys; update runbooks  
6. Read the pillar for vendor shopping context: [Free SMTP Relay — Mailgun & SendGrid Alternatives](/free-smtp-relay)  
7. Skim siblings as needed: [SendGrid SMTP Settings + Free Forever Alternative](/sendgrid-smtp-settings-free-alternative/), [Free Email API for Developers](/free-email-api-for-developers/), [What Is an SMTP Relay? Free SMTP Server](/what-is-smtp-relay-free-smtp-server/), [SPF/DKIM for Transactional Email](/spf-dkim-setup-transactional-email/)

**Primary CTA:** Stop treating Mailgun’s forever 100/day ceiling or Basic/Flex invoice math as architecture. Stand up a free forever SMTP server, keep Mailgun-shaped habits where they help, authenticate your domain, and grow to unlimited emails/day after warmup.

**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

<!--
meta_title: Mailgun SMTP Settings + Replace Mailgun Guide
meta_description: Get Mailgun SMTP settings right, then replace Mailgun with Agent Email List—free forever SMTP server + Mailgun-shaped REST API, unlimited/day after warmup.
slug: mailgun-smtp-settings-replace-mailgun
word_count: 10347
internal_links: /free-smtp-relay, /amazon-ses-vs-mailgun-vs-agent-email-list/, /email-deliverability-guide-transactional/, /email-warmup-unlimited-emails-per-day/, /free-email-api-for-developers/, /nodemailer-free-smtp-server-setup/, /sendgrid-smtp-settings-free-alternative/, /spf-dkim-setup-transactional-email/, /transactional-email-api-developers-guide/, /what-is-smtp-relay-free-smtp-server/
-->
