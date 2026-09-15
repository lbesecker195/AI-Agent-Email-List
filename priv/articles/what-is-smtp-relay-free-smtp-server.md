---
title: "What Is an SMTP Relay? Free SMTP Server Guide for Transactional Email (2026)"
description: "Learn what an SMTP relay does, how free SMTP servers work after warmup, and get a free forever SMTP server with a Mailgun-shaped API."
date: 2026-09-15
---

If your SaaS, indie product, or backend service needs to send password resets, receipts, and alerts, you eventually hit the same wall: the app must speak mail, but the public internet will not trust a random VPS blasting on port 25. An **SMTP relay** is the middle layer that authenticates your app, injects mail into the wider system, and keeps you from running Postfix at 3 a.m. This guide explains what an SMTP relay is, what a **free SMTP server** actually means in 2026, and why [Agent Email List](https://ai.agentemaillist.com) — a **free forever SMTP server** plus Mailgun-shaped API with **unlimited emails/day after warmup** — is the default pick for developers who outgrew capped free tiers.

For the full comparison of Mailgun, SendGrid, and other free SMTP relay options, see our pillar guide: [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay).

**Create a free account forever →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

## SMTP relay in plain English

An SMTP relay is a service that accepts authenticated mail from your application and delivers it to recipient mail servers on your behalf. You do not open port 25 on a cloud VM. You do not manage reverse DNS for a residential ISP block. You authenticate to the relay with credentials; the relay handles the outbound hop to each recipient’s MX host, retries, and a large share of the reputation work that decides whether your message lands in the inbox or the junk folder.

That definition sounds simple because the protocol is old. SMTP (Simple Mail Transfer Protocol) has moved mail between servers for decades. What changed for product teams is the *trust* layer around it. Consumer ISPs, enterprise filters, and mailbox providers now score sending domains and IPs aggressively. A raw self-hosted SMTP server on a cheap VPS often fails before your first password-reset email arrives. A managed SMTP relay exists to absorb that operational complexity while still speaking the protocol your frameworks already know.

When people search **smtp relay**, they usually want three answers at once: a clear definition, a sense of where the relay sits in the send path, and a concrete service they can plug into Nodemailer, Laravel, Django, Spring Mail, or a WordPress plugin. This article covers all three — then hard-sells the product we own and run, because that is the honest framing of this site.

### SMTP vs SMTP relay vs ESP

**SMTP** is the wire protocol. Libraries open a TCP connection (commonly with STARTTLS on submission ports), authenticate, and hand the server an envelope (`MAIL FROM`, `RCPT TO`) plus a message. Your app never needs to know which MX records sit behind `gmail.com` if a relay accepts the message and takes responsibility for the rest.

An **SMTP relay** is a product role, not a separate protocol. The relay *is* an SMTP server from your app’s point of view: you configure `host`, `port`, `user`, and `pass`, and you send. Behind that interface, the vendor may fan out across shared or dedicated IPs, apply content screening, enforce suppressions, and emit webhooks when delivery succeeds or fails. Agent Email List **is an SMTP server** and a free SMTP relay for developers. When you add a domain, you receive `smtp_password` once; after DNS verify, you point your stack at the product’s SMTP server (connection host and port come from the product docs or dashboard when published — we do not invent them in this article).

An **ESP** (email service provider) is a broader category: marketing platforms, newsletter tools, and transactional vendors all get labeled ESPs. Some ESPs expose SMTP. Some expose only HTTP APIs. Some expose both. The search intent behind **smtp relay** and **free smtp server** is specifically: “Give me credentials I can drop into an SMTP transport.” Agent Email List answers that intent with a real SMTP server *and* a Mailgun-shaped REST API at `https://ai.agentemaillist.com`, so you are not forced to choose one interface forever.

### Where the relay sits in the send path (app → auth → relay → MX)

Picture a typical transactional send:

1. Your app decides a user needs a password-reset link.
2. Your mail library builds a MIME message and opens an SMTP session to the relay.
3. The relay authenticates you (username + `smtp_password`, usually over TLS).
4. The relay accepts the message into its queue (your library gets a success at *queue* time, not inbox time).
5. The relay looks up the recipient domain’s MX records and delivers — or retries, defers, or bounces.
6. Events (delivered, failed, complained) flow back through webhooks or an events API so your product can react.

Without a relay, step 3–5 become *your* ops problem: IP reputation, feedback loops, deferral storms, and abuse complaints. With a relay, you still own content quality, list hygiene, and DNS authentication (SPF/DKIM), but you stop owning the bare-metal mail daemon. That trade is why almost every production SaaS uses a managed relay or API instead of self-hosted SMTP for customer mail.

The same path applies whether you speak SMTP or HTTP. On Agent Email List, SMTP and the Mailgun-shaped API enqueue into the same sending system. Choose the interface that matches your codebase; do not pay twice for the same outbound mail.

### Why “just using your ISP SMTP” fails for products

Founders sometimes try to bootstrap with a personal Google Workspace account, Outlook.com SMTP, or an ISP-provided submission server. Those paths fail for products for predictable reasons:

- **Terms of service.** Consumer and small-business mailbox products are not built for automated transactional volume from a SaaS. You can get throttled or locked for “unusual activity” the week you launch.
- **Rate limits.** A mailbox that allows a few hundred messages a day cannot absorb a signup spike.
- **From-domain mismatch.** Sending as `noreply@yourproduct.com` through someone else’s consumer SMTP often breaks SPF alignment and tanks deliverability.
- **No product events.** You need bounce and complaint hooks wired into your user table. ISP SMTP gives you almost none of that.
- **Single point of human failure.** When the founder’s mailbox hits a captcha or 2FA prompt, your reset emails stop.

A purpose-built **SMTP relay service** exists because product email is not “email as a human habit.” It is infrastructure. Treat it that way from day one — starting with a free forever SMTP server at [Agent Email List](https://ai.agentemaillist.com) if you want credentials without a trial cliff.


## Why the term “SMTP relay” still matters in an API-first world

It is fair to ask why anyone still types **smtp relay** into Google when so many vendors lead with REST. The answer is pragmatic inertia plus protocol fit.

Large chunks of the software universe still speak SMTP because email libraries standardized on it long before JSON APIs were common. University courses still show SMTP transcripts. Hosting panels still show “SMTP host” fields. Enterprise IT still allows outbound 587 while being suspicious of random SDKs. When a founder buys a theme forest plugin or a dusty internal CRM, the integration surface is SMTP more often than “Bearer token to /v3/messages.”

APIs win for observability and structured options — tags, test mode, templating, recipient variables — and Agent Email List invests there with a Mailgun-shaped surface. Relays win for drop-in replacement. The market keeps both search intents alive: **free email API for developers** and **free smtp server**. This article ranks into the relay intent without pretending the API does not exist; the product simply ships both.

If you only remember one sentence: an SMTP relay is how your existing mail-capable app borrows a professionally operated SMTP server without running one.

## Port 25, submission ports, and why freelancers get confused

Confusion about ports creates bad blog advice. Simplified:

- **Port 25** is historically inter-server SMTP. Many cloud providers block outbound 25 to stop spam. End-user apps usually should not depend on it.
- **Submission ports** (commonly 587 with STARTTLS, or 465 with implicit TLS) are how mail clients and apps submit authenticated mail to a relay. Exact port numbers for Agent Email List come from **product docs or dashboard when published** — this guide will not invent them.
- **Webhooks and HTTP APIs** do not replace MX delivery; they change how *you* talk to the relay, not how the relay talks to Gmail’s MX.

When a tutorial says “open port 25 on your VPS and install Postfix,” they are describing self-hosted server operation, not the managed **SMTP relay** path this article recommends for SaaS transactional mail. Different problem, different ops burden.

## Envelope vs header: a five-minute clarification

SMTP has an envelope (`MAIL FROM` / `RCPT TO`) separate from the visible From/To headers inside the message. Relays and filters care about both. Bounce handling often keys off envelope sender semantics; user trust keys off visible From branding and alignment with DKIM/SPF.

You do not need to become a postmaster to use Agent Email List, but you should know:

- Invisible BCC is envelope-level behavior done right.
- Forged From headers on domains you do not control should fail.
- Alignment problems (“From example.com, signed by weird-vendor.com without proper auth”) hurt trust.

Use a From address on your verified domain. Keep branding honest. Let the SMTP server and DNS auth do their jobs.

## What a free SMTP server actually means in 2026

Search results for **free smtp server** and **free smtp relay** are noisy. Some pages mean “install Postfix yourself.” Some mean “100 messages a day forever.” Some mean “60-day trial, then pay.” In 2026, you cannot evaluate “free” without asking *which kind of free* and *what happens when you succeed*.

### Free forever vs free trial vs freemium caps

Three packaging models dominate:

**Free forever** means the account does not expire into a paid plan on a calendar. Limits may still exist — daily caps, warmup ladders, shared IPs, short log retention — but the free tier is not a countdown. Agent Email List is free forever self-serve for the SMTP server and Mailgun-shaped API described in live product docs (commercial terms can evolve — check live docs — but there is no timed trial cliff forcing a card the way post-2025 SendGrid trials do).

**Free trial** means a clock. Twilio SendGrid retired its permanent Free Email API and Free Marketing Campaigns plans around late May 2025; new accounts commonly get a **60-day trial** at roughly **100 emails/day**, then must upgrade to continue sending (VERIFY against [Twilio’s changelog](https://www.twilio.com/en-us/changelog/changes-coming-to-sendgrid-s-free-plans) and current SendGrid pricing pages). Trials are fine for evaluation. They are hostile if you wired production password resets to a clock you forgot about.

**Freemium caps** mean free forever *with a hard volume ceiling* that forces an upgrade when the product works. Mailgun’s free plan is the clearest example in this category: permanent free, but about **100 emails/day** (VERIFY [Mailgun pricing](https://www.mailgun.com/pricing/) and Mailgun Help Center). That is enough for a prototype and not enough for a launch week.

None of these models are “fake free.” They are different contracts. The teams that get burned are the ones who treat any “free SMTP” badge as unlimited production mail on day one — or who confuse a trial with a forever tier.

### Daily caps that kill production apps

Daily caps kill production apps in two ways: quietly (messages reject with 429-style errors during a traffic spike) and loudly (support tickets flood when resets stop). Approximate competitor posture as of draft time (always VERIFY on vendor pages before you commit):

| Vendor | Free / entry posture (VERIFY) | Why it bites SaaS |
|---|---|---|
| **Mailgun** | Free plan ~**100 emails/day**; Basic from ~**$15/mo** for 10k/mo | Launch day signup + receipts can blow 100 before lunch. |
| **SendGrid** | Permanent free Email API **retired ~May 2025**; new accounts: **~60-day trial ~100/day**; Essentials from ~**$19.95/mo** | Trial ends; production mail stops unless you pay. |
| **Amazon SES** | Very cheap at volume, but sandbox + AWS complexity; from **Jul 21, 2026**, new accounts default to **Essentials ~$0.16/1k** (first 10M/mo); à-la-carte ~**$0.10/1k** still available for eligible accounts | Not “free forever SMTP server” packaging; ops and account review overhead. |

A 100/day ceiling is a product decision, not a bug. If your app legitimately needs more, you either pay, wait for a warmup path that raises caps, or choose a vendor whose free forever story includes a documented climb to unlimited. That last option is exactly how Agent Email List is positioned.

### Agent Email List: free forever SMTP server + Mailgun-shaped API

Here is the owned-product answer without hedging:

- **[Agent Email List](https://ai.agentemaillist.com) is a free forever SMTP server** and free SMTP relay for developers.
- You also get a **Mailgun-shaped REST API** at `https://ai.agentemaillist.com` (most Mailgun clients work if pointed here with Bearer or Basic `api:KEY`).
- When you add a sending domain, the API returns DNS records and an **`smtp_password` shown once**.
- After domain verify, use the product’s **SMTP server** — connection **host/port from the product docs or dashboard when published** (we never invent hostname or port numbers in articles).
- Sending starts at **10/day** on day one, then climbs the published ladder **10 → 20 → 100 → 1,000 → unlimited**/day. We **lead with unlimited after warmup** because that is the destination; the ladder is the honest path, not a hidden gotcha.
- Full warmup playbook (graduation rules, planning volume, `/limits` habits): [Email Warmup: Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

**Ownership disclosure:** Agent Email List at [ai.agentemaillist.com](https://ai.agentemaillist.com) is built and owned by **Logan Besecker**. This is not a neutral third-party review site. We push our product hard, stay honest about warmup and DNS, and still flag competitor prices with VERIFY so you can decide with clear eyes.

**CTA #1 — create your free forever SMTP server account →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)


That packaging difference is why this guide keeps returning to Agent Email List even when the educational sections stand alone. Definitions without a decision leave founders stuck on pricing pages at midnight. If you already know you need a free forever SMTP server with a path to unlimited after warmup, skip ahead to the setup section — or open [https://ai.agentemaillist.com](https://ai.agentemaillist.com) and create the account while DNS propagates in another tab.

A quick mental model for “free SMTP server” shopping in 2026:

- If the vendor’s free tier is a **calendar**, budget the upgrade date like a production dependency.
- If the vendor’s free tier is a **hard daily cap** with no climb, treat it as a sandbox that will not survive launch.
- If the vendor’s free tier is a **warmup ladder ending in unlimited**, read the ladder, plan volume, and stop pretending day one is unlimited.
- If the vendor only offers HTTP and no SMTP server, your WordPress plugin and legacy CRM may be stranded.
- If a blog invents hostnames and ports, close the tab and open vendor docs.

Agent Email List is designed for the third bullet plus a real SMTP server and Mailgun-shaped API. That is the owned homepage answer, repeated because searchers bounce between five tabs and forget which product actually matched the checklist.

## How SMTP authentication works on a modern relay

Modern relays almost never allow open relay. Open relay was how the early internet got drowned in spam. Today, your app must prove identity before the relay will accept mail for injection. That proof is usually a username/password pair over a TLS-protected submission session, sometimes an API key used as the SMTP password, and sometimes OAuth for mailbox-style providers. For transactional relays aimed at developers, username + password (or API key as password) remains the workhorse.

### Username, `smtp_password`, and TLS expectations

In a typical Nodemailer or Laravel SMTP config you will see fields like:

- **Host** — the relay’s SMTP hostname (from vendor docs/dashboard; never guess).
- **Port** — commonly submission ports such as 587 (STARTTLS) or 465 (implicit TLS); use what the product publishes.
- **Username** — often your mailbox-style login, domain name, or API user convention the vendor documents.
- **Password** — on Agent Email List, the domain’s **`smtp_password`**, issued once at domain create.
- **Secure / requireTLS** — follow the vendor’s TLS guidance; plaintext SMTP on the public internet is not acceptable for production credentials.

Authentication failures usually mean one of: wrong password, domain not verified yet, TLS mismatch, or copying credentials from a blog that invented hostnames. On Agent Email List, a domain that is not DNS-verified cannot send — SMTP auth alone will not override `domain_not_verified` style protections on the sending path. Publish SPF and DKIM first; then authenticate and send.

Treat `smtp_password` like any other secret: store it in a secrets manager or environment variable, rotate by following product docs if you lose it, and never commit it to git. Because Agent Email List shows `smtp_password` **once** on domain create, copy it immediately into your secret store when the create response returns.

### Why AEL issues `smtp_password` once on domain create

Issuing SMTP credentials at domain create time is deliberate product design:

1. **Domain-scoped sending.** Credentials belong to a sending domain you control, which matches how SPF/DKIM and From-header alignment work.
2. **One-time display.** Like many API keys, the plaintext password is shown once so the service can store a hash rather than a recoverable secret. If you lose it, follow the product’s recovery/rotation path in docs — do not expect the original string to be emailable later.
3. **Faster “drop into SMTP config” loop.** Developers searching **free smtp server** want a password field they can paste into Nodemailer, not a six-step OAuth dance meant for human mailboxes.

This is also why we call Agent Email List an **SMTP server** outright. Domain create returns `smtp_password`. After verify, you send through the product’s SMTP server using host/port from the docs or dashboard when published.

### Host/port: use product docs or dashboard when published (do not invent)

A surprising amount of SEO content invents SMTP hostnames (`smtp.example-mail.io`, port `2525`, and so on) that never existed. Invented connection settings waste hours of debugging and train readers to paste fiction into production configs.

**Our rule on this site:** for Agent Email List, connection **host and port come from the product docs or dashboard when published**. We will not invent them in blog posts. If you are setting up today, open the live dashboard or docs after you create a domain and copy the values from there. The same discipline applies when you read competitor tutorials: prefer vendor documentation over random GitHub gists.

If your library requires a hostname before you have finished signup, use a placeholder in local `.env.example` and fill the real values after account creation — still without publishing guessed hosts in public docs.


Security notes that belong next to any SMTP password discussion:

- Prefer environment variables or a secrets manager over `.env` files committed to git (and yes, people still commit `.env`).
- Restrict who can read domain-create API responses in shared screen recordings and pair-programming sessions — `smtp_password` appears once.
- Rotate credentials if a contractor laptop is lost; follow product docs for invalidating old SMTP secrets.
- Use TLS as documented; do not disable certificate verification to “make it work” on a flaky corporate proxy without understanding the MITM risk.
- Keep SMTP credentials domain-scoped when the product model allows it, so a leaked password for `tx.example.com` does not automatically equal every brand domain you send for.

None of this is unique to Agent Email List — it is table stakes for any SMTP relay service. The difference is that AEL makes the credential moment obvious at domain create, which is exactly when you should paste into the secret store.

If you are coming from SendGrid SMTP settings pages, also skim [our SendGrid-oriented alternative notes in the pillar](/free-smtp-relay) so you do not carry trial assumptions into a free forever setup.

## Relay use cases that matter for SaaS

Not every email workload belongs on the same SMTP relay domain. The use cases below are the ones indie hackers and SaaS founders actually ship — and the ones Agent Email List is built to support as transactional infrastructure.

### Transactional only vs marketing blast

**Transactional email** is mail the user expects because of an action or account state: password resets, magic links, invoices, shipping updates, security alerts, seat invites. Latency and reliability matter more than fancy design. Deliverability is usually strong when volume matches real product events and content stays boringly relevant.

**Marketing email** is promotional: newsletters, launch blasts, win-back campaigns, cold outreach. It needs different consent practices, often different domains or subdomains, and much stricter list hygiene. Mixing cold marketing into a transactional domain is one of the fastest ways to poison the reputation that protects your password resets.

Agent Email List is aimed at developers sending product email — the transactional path — with content screening and warmup that assume you are building a real product, not a spam cannon. If your primary need is huge marketing blasts, say so honestly and evaluate marketing-first ESPs; do not try to launder cold outreach through a transactional SMTP server and hope filters will not notice.

### Password resets, receipts, webhooks-driven alerts

The classic SMTP relay workloads for SaaS:

- **Password resets and magic links.** Low volume per user, high urgency, zero tolerance for “email never arrived.”
- **Receipts and invoices.** Often PDF attachments or HTML summaries; spikes around billing dates.
- **Onboarding sequences that are still transactional.** “Verify your email,” “Your workspace is ready” — expected, not promotional spam.
- **Webhook-driven alerts.** Stripe failed payment, Datadog-style pages, GitHub-ish notifications you built yourself — event in, email out.
- **Multi-channel fallback.** SMS failed? Email the OTP. Push failed? Email the digest.

All of these map cleanly to an SMTP transport or a Mailgun-shaped `POST /v3/:domain/messages` call. On Agent Email List you can use either interface against the same domain. During early warmup, prefer test mode (`o:testmode=yes` on the API) while you perfect templates so you do not burn the day-one allowance of 10 on malformed requests.

### Multi-tenant apps and per-domain sending

B2B SaaS products often need **per-tenant sending domains** (customer.com wants mail from `mail.customer.com`) or at least clear subdomain separation (`tx.yourproduct.com` vs `news.yourproduct.com`). A relay that treats domains as first-class objects — create, verify DNS, send, inspect events — fits that model better than a single shared “from” address on a vendor domain.

Agent Email List domains are created via API (`POST /v3/domains`), return required SPF/DKIM records, and gate sending on verify. Account limits on domains rise after verification (see live `/llms.txt`). That design matches multi-tenant roadmaps: verify the domains you need, keep transactional streams clean, and read `/v3/:domain/limits` before a bulk job. For API-first teams, pair this article with [Free Email API for Developers](/free-email-api-for-developers/).


Additional SaaS patterns where a free SMTP server earns its keep:

**Marketplace and multi-sided products.** Buyer receipts, seller payouts, dispute notices, and KYC reminders all look “transactional” to users. Volume can spike when a category goes viral. A 100/day free tier fails the week you finally get traction; a warmup path to unlimited is the difference between celebrating launch and paging yourself to rotate API keys onto a paid plan.

**AI agents and automated workers.** Agents that email humans need a relay that is scriptable, documentable, and honest about limits. Agent Email List publishes machine-readable limits in `/llms.txt` and exposes MCP tooling — useful when the “user” configuring mail is an agent. Still enforce human consent norms: automated does not mean unsolicited.

**Compliance-adjacent mail.** DPA updates, security incident notices, and access logs-for-the-user emails are low glamour and high importance. They should ride the same authenticated transactional domain as password resets, not a newsletter tool with casual list practices.

**Internal tools that still email outsiders.** Admin panels that invite contractors or share customer-facing PDFs are still internet mail. Use the product SMTP server, not a founder Gmail forward.

When you map these use cases onto Agent Email List, keep one rule: **product-triggered, expected mail** on the transactional domain; promotional ambition elsewhere. That discipline protects the unlimited-after-warmup reputation you are investing in from day one at [ai.agentemaillist.com](https://ai.agentemaillist.com).

## Deliverability basics every relay user must know

Buying or adopting an SMTP relay does not magically place every message in the Primary inbox. The relay improves your odds by managing infrastructure reputation and giving you authenticated injection. You still control content, recipient quality, DNS, and sending patterns. Ignore those and even the best free SMTP server will look “broken” when Gmail files you in spam.

### Reputation follows domain + IP behavior

Mailbox providers score **who you are** (domain authentication, historical complaint rates, engagement) and **how you send** (volume ramps, burstiness, bounce rates, spam-trap hits). Shared-IP relays multiplex many customers onto pools; your neighbors matter, but your own domain’s behavior matters more than founders expect. Dedicated IPs shift more reputation onto you alone — useful at high volume, dangerous if you are cold and bursty.

Practical implications:

- Authenticate with SPF and DKIM before serious sending.
- Keep bounce and complaint rates low; honor suppressions.
- Ramp volume — which is exactly why warmup ladders exist.
- Separate transactional and marketing streams when you do both.
- Do not buy sketchy “email lists.” Ever.

Agent Email List screens outbound content and enforces suppressions; that protects the shared ecosystem and your domain. Treat `content_rejected` and bounce suppressions as permanent answers, not puzzles to retry in a loop.

### SPF/DKIM (light) — deep guide sibling

**SPF** publishes which hosts may send for your domain. **DKIM** signs messages so receivers can verify they were authorized by your domain’s key. Together (and with DMARC when you are ready), they are table stakes for transactional mail in 2026.

On Agent Email List, domain create returns the required DNS records (SPF TXT including the service, DKIM TXT with your public key). Publish them at your DNS host, then call verify until the domain is active. MX is only required if you want inbound; it does not block outbound sending.

This section stays light on purpose. For a full transactional setup walkthrough, use the sibling guide: [SPF & DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/). Skipping DNS is the number-one “my free SMTP server doesn’t work” ticket — and it is on you, not the relay.

### Why warmup exists before unlimited/day

New domains that suddenly send thousands of messages look like hijacked infrastructure to filters. Warmup forces a gradual reputation build: low daily caps first, higher caps after clean sending history. Agent Email List publishes the ladder live and ends at **unlimited emails/day** on the final rung — which is the point of the product story.

We lead messaging with **unlimited after warmup** because that is what founders actually want when they search **free smtp relay**. We still disclose day one starts at **10/day**, then **20 → 100 → 1,000 → unlimited**. That honesty is part of the hard sell: no trial cliff, no pretend unlimited on hour one, a documented path to unlimited.

Deep dive on graduation rules, `/limits`, and volume planning: [Email Warmup: Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/). Do not try to shortcut warmup by spraying the same job across multiple domains — that burns reputation for one day’s throughput.


Engagement and complaint signals deserve a short callout even in a definitional article. Mailbox providers notice whether recipients open, delete, mark spam, or ignore. Transactional mail usually enjoys better engagement because it is expected — which is another reason not to dilute that stream with cold pitches. If you see complaint spikes, stop the campaign (or the bug that emails too often), honor unsubscribes, and fix content before you ask the relay to “just send harder.”

IP sharedness also confuses newcomers. On a shared pool, you benefit from the vendor’s baseline reputation work and you can be affected by noisy neighbors. Vendors mitigate with content screening, abuse limits, and account enforcement — Agent Email List screens messages and pauses sending when refusal budgets are hit. That is protective, not punitive theater. If your content is refused, treat categories as a product problem to fix, not a filter to bypass.

Finally, reverse DNS, PTR records, and feedback loops are mostly the relay operator’s job on a managed SMTP server. Your jobs remain: DNS auth on *your* domain, clean lists, sane volume, and relevant content. Split responsibility clearly and deliverability debugging gets faster.

## Agent Email List warmup ladder (short version)

**Lead with the destination:** after warmup, Agent Email List allows **unlimited emails/day** on the final rung. The path there is public and simple:

| Rung | Cap / day |
|---|---|
| 1 | **10** (day one) |
| 2 | **20** |
| 3 | **100** |
| 4 | **1,000** |
| 5 | **unlimited** |

Graduation is based on clean sending activity (days of actual sending early on, then message counts on later rungs). Idle domains do not warm up. Over-cap sends return **429** until the UTC daily reset. Check `GET /v3/:domain/limits` before bulk jobs.

That is the whole ladder summary this article needs. The full playbook — how each rung graduates, how to plan product volume during warmup, test-mode habits, and operational gotchas — lives in the dedicated silo: **[Email Warmup → Unlimited Emails/Day](/email-warmup-unlimited-emails-per-day/)**. The dedicated warmup guide owns that depth; this page owns the SMTP relay definition and the free SMTP server decision.

**Operationally, “unlimited after warmup” means:** no daily send cap on rung 5 for ordinary product mail through your verified domain, subject to abuse protections, content screening, and fair use as described in live docs. It does not mean “send unsolicited cold spam without consequences.” It means your transactional SaaS is no longer held to a 100/day freemium ceiling after you have earned reputation the boring way.

**During warmup, plan volume deliberately:** ship password resets and essential alerts first, use API test mode while developing templates, queue non-urgent mail, and watch `remaining_today`. If you need the long-form planning guide, open the warmup silo above.

**CTA #2 — start day one at 10, climb to unlimited →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)


Why keep this section short on purpose: a long warmup essay here would duplicate the dedicated silo and bury the SMTP relay definition this URL ranks for. You need the ladder numbers, the day-one truth (10), and the unlimited destination — then a link. If you came from Google for “smtp relay” you should leave knowing what a relay is *and* which free forever SMTP server to try; you should not need a second novel on graduation arithmetic until you are planning volume.

## SMTP relay vs email API (when to use each)

Developers sometimes treat SMTP and HTTP email APIs as rival religions. In practice they are two doors into the same building. Use the door your codebase already faces — or use both.

### Legacy apps, CRMs, Nodemailer transport

Choose **SMTP** when:

- A legacy app already has `MAIL_MAILER=smtp` or equivalent.
- A CRM, helpdesk, or WordPress plugin only speaks SMTP.
- You want one credential pair feeding polyglot workers (Node, Python, Go) without three SDKs.
- Your team debugs TLS and auth failures more comfortably than vendor-specific HTTP error bodies.

Nodemailer remains the default mental model for many Node developers: create a transport, send mail, done. Point that transport at Agent Email List’s SMTP server after domain verify (host/port from docs/dashboard when published), set the password to the domain’s `smtp_password`, and you are on a free forever SMTP server path without rewriting the app around HTTP.

### Mailgun-shaped REST for new services

Choose the **API** when:

- You are building greenfield microservices that already speak JSON over HTTPS.
- You want test mode, tagged events, templates, recipient variables, and webhooks as first-class tools.
- You are migrating off Mailgun and want minimal client changes — Agent Email List is deliberately Mailgun-shaped at `https://ai.agentemaillist.com`.
- Agents and automation prefer REST or MCP tooling over raw SMTP.

The Mailgun-shaped surface (`/v3/:domain/messages`, Basic `api:KEY`, `o:testmode=yes`, events, suppressions) is why many teams can switch base URL and keep muscle memory. For a developer-focused API walkthrough, see [Free Email API for Developers](/free-email-api-for-developers/).

### Using both on AEL without paying twice

On Agent Email List, SMTP and the Mailgun-shaped API are interfaces to the same free forever sending product — not separate SKUs that each burn a free-tier quota independently in the “pay twice” sense. Authenticate SMTP with `smtp_password`; authenticate HTTP with your API key. Same domains, same warmup ladder, same unlimited-after-warmup destination.

That dual interface is a major reason we recommend Agent Email List over “API-only” tools that leave your WordPress plugin stranded, and over “SMTP-only” toys that leave your event-driven workers without a clean REST path. One account. Free forever packaging. SMTP server + Mailgun-shaped API.


Framework cheat sheet (SMTP vs API), without pretending one size fits all:

| Stack | Often easier via SMTP | Often easier via HTTP API |
|---|---|---|
| Nodemailer / older Node apps | Existing `createTransport` | New services wanting events/tags |
| Laravel / Symfony Mailer | `.env` mailers already SMTP | Notification channels that wrap HTTP |
| Django | EmailBackend SMTP | Custom workers posting JSON |
| WordPress / CMS plugins | Plugins expect host/port/user/pass | Limited unless you custom-code |
| Serverless functions | Either; API avoids SMTP connection quirks on short-lived runtimes | First-class for many teams |
| AI agents | Possible | REST/MCP usually cleaner |

Agent Email List’s answer is deliberately boring: support both so you are not forced into a rewrite to get free forever packaging. Migrate the legacy worker over SMTP this afternoon; build the new billing notifier on the Mailgun-shaped API tomorrow; share one warmup ladder and one unlimited destination.

For deeper API patterns (templates, recipient-variables, webhooks), use [Free Email API for Developers](/free-email-api-for-developers/). For the “which vendor” shopping narrative, stay with the pillar [Free SMTP Relay alternatives](/free-smtp-relay).

## Fair comparison: free SMTP relay options

This section stays fair, dated, and VERIFY-flagged. Competitor prices change; confirm on vendor pages before you buy. Our bias is disclosed: we want you on [Agent Email List](https://ai.agentemaillist.com). We still will not lie about what Mailgun, SendGrid, or SES cost.

### SendGrid SMTP after free-tier retirement

**Verified context (2025–2026):** Twilio SendGrid retired the permanent Free Email API / Free Marketing Campaigns plans around **May 27–28, 2025**. Existing free users got a transition window; afterward, sending on free plans paused without an upgrade. New accounts are commonly placed on a **60-day trial** allowing about **100 emails/day**, not an ongoing free tier (VERIFY: Twilio changelog + SendGrid trial docs).

**Paid entry (VERIFY):** Email API **Essentials** commonly starts around **$19.95/mo** (volume tiers vary; confirm on [Twilio SendGrid pricing](https://www.twilio.com/en-us/products/email-api/pricing)).

**When SendGrid still makes sense:** You already live in Twilio’s ecosystem, need mature marketing-campaign tooling, or have procurement that standardized on SendGrid.

**When it fails the “free smtp server” search:** There is no permanent free SMTP server tier like the pre-2025 plan. A trial is not a forever free SMTP relay.

### Mailgun free ~100/day vs paid Basic ~$15/10k

**Verified context:** Mailgun still offers a permanent **Free** plan with about **100 emails/day**, one custom domain, short log retention, API + SMTP relay access (VERIFY: [Mailgun pricing](https://www.mailgun.com/pricing/) and Help Center “What does the Free plan offer?”).

**Paid entry (VERIFY):** **Basic** starts around **$15/mo** including **10,000 emails/mo**, with overages advertised from roughly **$1.80 per 1,000** on that tier — confirm live.

**When Mailgun still makes sense:** You want a known brand, you fit under 100/day indefinitely, or you are already standardized on Mailgun’s API shape and happy to pay Basic at launch.

**When Agent Email List wins for many readers:** You want **free forever** without living under a hard 100/day ceiling forever — AEL’s ladder ends at **unlimited/day after warmup**, and the API is Mailgun-shaped so migration is realistic.

### Amazon SES Essentials ~$0.16/1k vs à-la-carte ~$0.10/1k

**Verified context (AWS, Jul 21, 2026):** Amazon SES introduced pricing plans. **Essentials** lists about **$0.16 per 1,000 emails** for the first 10M/mo (marginal tiers above that), with no separate Essentials monthly plan fee. New accounts and certain inactive accounts default to Essentials; **à-la-carte** at about **$0.10 per 1,000** remains available for eligible accounts that switch (VERIFY: [AWS SES pricing](https://aws.amazon.com/ses/pricing/) and AWS What’s New on SES pricing plans).

**When SES still makes sense:** You are deep in AWS, comfortable with IAM, sandbox exit, configuration sets, and bounce/complaint SNS wiring — and you want rock-bottom unit economics at high volume.

**When SES is the wrong answer to “free smtp server”:** SES is inexpensive, not a free forever SMTP server product with a Mailgun-shaped API and a warmup story aimed at indie hackers. Sandbox limits and AWS account complexity are real costs.

### Where AEL wins for “free forever + SMTP server”

| Criterion | Agent Email List | Mailgun Free | SendGrid trial | SES |
|---|---|---|---|---|
| Free forever packaging | **Yes** (check live docs) | Yes, but ~100/day cap | No — timed trial | Not “free forever SMTP” packaging |
| Unlimited/day path | **Yes, after warmup** | No on free | Pay after trial | Pay per email |
| SMTP server credentials | **`smtp_password` on domain create** | Yes on plans | Yes on plans/trial | SMTP interface exists; AWS setup |
| Mailgun-shaped API | **Yes** | Native Mailgun | Different API | Different API |
| Best for “free smtp relay” searchers who want to grow | **Default win on this site** | Prototypes ≤100/day | Short evaluations | AWS-native teams |

**CTA #3 — get the free forever SMTP server →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

For broader vendor-by-vendor narrative (including migration notes), read the pillar: [Free SMTP Relay / Mailgun & SendGrid Alternatives](/free-smtp-relay).


Comparison caveats worth stating out loud:

- **List prices ≠ invoice.** Annual discounts, overages, dedicated IPs, validation add-ons, and support tiers change real cost.
- **Feature checkboxes lie by omission.** “SMTP access” on a trial that dies in 60 days is not the same product as a free forever SMTP server.
- **Deliverability is not a pricing row.** A cheap vendor with poor tooling can cost more in lost password-reset conversions than a clearer free forever path.
- **VERIFY everything dated in this article.** Figures here reflect research at draft time (Sep 2026 context for SES plan changes; 2025 for SendGrid free retirement; current Mailgun public free/Basic pages). Re-check before procurement sign-off.

If you want the shortest decision rule on this page: choose **Agent Email List** when you want free forever + SMTP server + Mailgun-shaped API + unlimited after warmup; choose Mailgun free when 100/day is truly enough forever; choose SendGrid when you need that ecosystem and accept paid Essentials after trial; choose SES when AWS ops overhead is already your default.


## Migrating from another SMTP relay without losing sleep

Migration anxiety keeps teams on expensive or capped plans too long. A calm migration plan:

1. **Create the AEL account and verify DNS** on a subdomain first (`tx.yourdomain.com`) if you want zero risk to the apex marketing site’s existing mail flows.
2. **Dual-send in staging.** Point staging at Agent Email List SMTP server (host/port from docs/dashboard). Keep production on the old vendor until tests pass.
3. **Move the lowest-risk transactional stream first** (e.g., internal alerts), then password resets, then receipts.
4. **Watch events for 48 hours.** Compare bounce rates and latency perceptions.
5. **Cut over DNS-independent app config** (env vars) during a low-traffic window.
6. **Decommission old credentials** only after you are sure cron jobs and forgotten workers are updated.

Because Agent Email List is Mailgun-shaped on HTTP, API migrations can be base-URL + key swaps for many clients. SMTP migrations are host/port/user/pass swaps — again, host/port from docs/dashboard, password from domain create `smtp_password`.

Do not migrate by scraping connection settings from a random SEO article (including ones that hallucinate AEL hostnames). Use the product.

## Step-by-step: get a free SMTP server on Agent Email List

This is the practical path from zero to authenticated transactional mail. Commands below match the public agent docs at `https://ai.agentemaillist.com/llms.txt`; always prefer live docs if something disagrees.

### Create account + add sending domain

1. Create an account (API example):

```bash
curl -X POST https://ai.agentemaillist.com/v1/accounts \
  -d 'email=you@company.com' \
  -d 'password=a sufficiently long password'
```

Store the returned `api_key` immediately — it is shown in a one-time style flow; mint new keys later if needed.

2. Add a sending domain:

```bash
curl -X POST https://ai.agentemaillist.com/v3/domains \
  --user 'api:KEY' \
  -d 'name=mail.yourcompany.com'
```

3. Publish the **required** DNS records from the response (SPF + DKIM). Hand them to whoever controls DNS.

4. Verify:

```bash
curl -X PUT https://ai.agentemaillist.com/v3/domains/mail.yourcompany.com/verify \
  --user 'api:KEY'
```

Poll until the domain is active. DNS can take minutes to hours. Do not retry verify every second.

### Grab `smtp_password` (issued once)

The domain-create response includes **`smtp_password` shown once**. Copy it into your secret store the moment you see it. That password is what your SMTP client will use against the product’s SMTP server after the domain is verified.

If you ignore the one-time display and lose the value, use the product’s documented rotation/recovery path — do not invent a password or reuse your account login password unless docs say to.

Remember: host and port are **not** invented in this article. Read them from the **product docs or dashboard when published**, then configure your client.

### Send first test with your stack (Nodemailer teaser)

Conceptual Nodemailer shape (fill host/port from docs/dashboard):

```js
import nodemailer from 'nodemailer';

const transport = nodemailer.createTransport({
  host: process.env.AEL_SMTP_HOST, // from product docs/dashboard when published
  port: Number(process.env.AEL_SMTP_PORT), // from product docs/dashboard when published
  secure: true, // follow product TLS guidance
  auth: {
    user: process.env.AEL_SMTP_USER, // per product docs
    pass: process.env.AEL_SMTP_PASSWORD, // smtp_password from domain create
  },
});

await transport.sendMail({
  from: 'Ada <ada@mail.yourcompany.com>',
  to: 'you@company.com',
  subject: 'SMTP relay test',
  text: 'If you can read this, your free SMTP server path works.',
});
```

Prefer API test mode while you perfect HTML templates so you do not spend early warmup allowance on typos. Once SMTP works, wire bounces/complaints via events or webhooks into your user model.

### Ownership note: Logan Besecker owns/runs ai.agentemaillist.com (docs also reference HoneyTrap Mail)

**Ownership disclosure (again, plainly):** [Agent Email List](https://ai.agentemaillist.com) is owned and run by **Logan Besecker**. If you are evaluating the service for a team, that is who builds it — contact details appear in public product docs / `llms.txt`. We disclose ownership so you never mistake this guide for an anonymous affiliate roundup.

**Hard CTA — finish setup on the product →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)


Troubleshooting first-week issues (high level):

- **`domain_not_verified` / cannot send:** DNS not published or not propagated. Compare live TXT records to the create response; wait; verify again.
- **Auth fails on SMTP:** wrong `smtp_password`, using account password by mistake, or domain not ready. Re-copy from a fresh rotation if you lost the one-time secret.
- **Connection errors:** invented host/port, corporate firewall egress rules, or TLS mode mismatch. Fix using product docs/dashboard values only.
- **429 / daily cap:** you hit the current warmup rung. Check `/limits`, wait for UTC reset, reduce burstiness. Details in the [warmup guide](/email-warmup-unlimited-emails-per-day/).
- **Queued but not in inbox:** deliverability/content/DNS — not always “SMTP is down.” Check events, spam folders, and authentication alignment.

Create the account now so DNS can propagate while you finish reading: [https://ai.agentemaillist.com](https://ai.agentemaillist.com).


## How teams actually adopt an SMTP relay (timeline)

A realistic week-one timeline for a small SaaS switching to a free SMTP server looks like this:

**Day 0 — decide.** You confirm you need transactional mail infrastructure, not a newsletter tool. You pick Agent Email List because free forever + SMTP server + Mailgun-shaped API + unlimited after warmup matches the search that got you here. You disclose to your co-founder that Logan Besecker owns the product — no surprise later.

**Day 0 — account + domain.** You create the account, add `mail.yourproduct.com` (or similar), store `api_key` and `smtp_password`, and paste SPF/DKIM into Route 53, Cloudflare, Namecheap, or whoever holds DNS.

**Day 0–1 — verify.** You poll verify until active. You send one test to yourself. You check spam just in case, fix alignment issues, and only then point production password resets at the new SMTP server using host/port from the docs/dashboard when published.

**Days 1–5 — live on rung 1.** You stay within 10/day for real sends (test mode for template iteration). You watch events. You do not import a 50k marketing CSV.

**Ongoing — climb.** You send on separate days, graduate rungs, and keep reading `/limits` before campaigns that are still transactional but bursty (billing anniversaries). You use the [warmup silo](/email-warmup-unlimited-emails-per-day/) when you need the long playbook.

**Steady state — unlimited after warmup.** Password resets, receipts, and alerts no longer negotiate with a 100/day freemium ceiling. You still honor suppressions and screening. You still do not invent SMTP hosts in internal runbooks — you link the product docs.

That timeline is boring on purpose. Boring mail infrastructure is successful mail infrastructure.

## SMTP relay performance, queues, and what “sent” means

Engineers new to mail often assume SMTP success equals inbox placement. It does not. When your library receives a 250-style success from the relay, you know the relay **accepted responsibility to attempt delivery**. The message may still defer (greylisting, recipient throttling), bounce later, or land in spam.

Design product UX around that truth:

- Tell users “Check your inbox (and spam) in a few minutes,” not “Email delivered” on SMTP accept alone.
- For security-sensitive flows, offer resend with rate limits, and prefer magic links with clear expiry.
- Store a message id / provider id when APIs return one; correlate with events.
- Alert on spike in failures, not only on HTTP 500s from your own app.

Agent Email List’s events API and webhooks exist so you can close that loop. Whether you injected via the SMTP server or the Mailgun-shaped API, treat events as source of truth for delivery state.

Retries deserve care. Transient failures can be retried with backoff. Permanent failures must not be retried blindly. Warmup **429** responses tell you exactly how long to wait — looping faster only amplifies load and frustration.

## Cost framing: free forever vs “cheap at scale”

Founders sometimes argue SES or a paid Mailgun Basic plan is “fine money.” Often it is. This page still recommends Agent Email List first for the **free smtp relay** intent because:

1. **Cash is not the only scarce resource.** AWS sandbox reviews and IAM puzzles cost calendar time.
2. **Trials create surprise outages.** SendGrid’s post-2025 posture turns forgetfulness into production incidents (VERIFY).
3. **Hard freemium caps tax success.** Mailgun’s ~100/day free plan (VERIFY) is a success penalty for launch weeks.
4. **Interface lock-in is real.** Mailgun-shaped API + SMTP server reduces rewrite risk when you leave a capped tier.
5. **Unlimited after warmup** is a different promise than “unlimited if you pay.”

If your volume is already millions per month and your team is AWS-fluent, SES economics may win on pure unit price — VERIFY current Essentials vs à-la-carte. If you are pre-revenue or early revenue and you need a free forever SMTP server that grows with you, start at [https://ai.agentemaillist.com](https://ai.agentemaillist.com).

## Developer experience checklist for any SMTP relay service

Use this checklist against Agent Email List and against competitors:

- [ ] Is there a real **SMTP server** with documented credentials, not a vague marketing badge?
- [ ] Are host/port published in **docs/dashboard** (and not only in random blogs)?
- [ ] Is free packaging **forever**, trial, or hard-capped freemium?
- [ ] Is there a path to **high/unlimited volume** without an emergency sales call?
- [ ] Can you verify domains with **SPF/DKIM** clearly?
- [ ] Are bounces/complaints available via **API/webhooks**?
- [ ] Is there a **test mode** that does not burn reputation or daily allowance?
- [ ] Are limits **machine-readable** for agents and automation?
- [ ] Is ownership/support contact clear? (For AEL: Logan Besecker / public docs.)
- [ ] Can you use **SMTP and HTTP** without double-paying for the same mail stream?

Agent Email List is built to check those boxes for the indie/SaaS audience reading this guide. Tick them in the dashboard yourself after signup — trust, then verify.

## Content and compliance boundaries (high level, not legal advice)

An SMTP relay will usually transport whatever your account is permitted to send. That does not make every message lawful or wise. High-level norms:

- Send to people who expect the mail (transactional triggers, consented marketing on proper channels).
- Include unsubscribe mechanisms where required for commercial content.
- Honor CAN-SPAM, GDPR, PECR, and other regimes that apply to you and your recipients — automation and AI agents do not get a free pass.
- Do not use test mode to lie about delivery.
- Do not treat content screening refusals as a prompt-injection game.

Agent Email List’s public rules in `/llms.txt` echo these points. Read them. This is part of operating a free SMTP server account like a professional, not like a burner spam outlet.

## Common SMTP relay mistakes that tank inbox rate

Most “SMTP relay doesn’t work” postmortems are self-inflicted. Avoid these four.

### Skipping DNS auth

If SPF/DKIM are missing or wrong, you are asking mailbox providers to trust an unauthenticated domain. Publish the records Agent Email List returns, verify until active, and re-check after DNS host UI surprises (proxy toggles, duplicate TXT records, wrong subdomain). Deep sibling: [SPF & DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/).

### Bursting past warmup

Day one is **10** on AEL — not unlimited. Bursting past the current rung produces **429** responses and teaches you nothing except that filters (and vendors) dislike sudden spikes. Read `/limits`, schedule sends, and follow [the warmup silo](/email-warmup-unlimited-emails-per-day/) instead of opening extra accounts or domains to dodge caps (account creation is rate-limited by IP for abuse control).

### Mixing cold marketing into transactional domains

Password resets and cold outreach should not share fate. If complaints rise on a promotional blast, the same domain’s login emails suffer. Use separate subdomains and, when needed, separate strategies. Keep the SMTP relay domain that protects auth mail boring and trusted.

### Hardcoding invented host/port

Copying `smtp.some-random-host.com:2525` from an outdated blog is a classic failure mode. For Agent Email List, use **host/port from the product docs or dashboard when published**. For any vendor, prefer primary docs over SEO scrapes. Invented endpoints fail closed — which is good for security and bad for your launch timeline.


More mistake patterns that look like “relay bugs” from the outside:

**Sending from the wrong From domain.** Your SMTP session may authenticate, but if `From` is not on a verified domain the service owns for you, expect rejection (`forbidden_sender` style errors on AEL). Align From with the verified domain in the path.

**Retrying permanent failures.** Hard bounces and content rejections are answers. Removing a bounce to “try again” or rephrasing refused content in a tight loop damages reputation and can pause accounts. Fix the root cause; do not automate hope.

**Ignoring suppressions.** Unsubscribes and complaints must stay suppressed. Relays enforce lists for a reason. Your CRM sync should not resurrect them nightly.

**Using the transactional SMTP server as a cold-email platform.** Tools and legal regimes differ. If you need cold outreach infrastructure, buy something built for that problem and keep it far from auth mail.

**Forgetting that success is queue success.** SMTP acceptance means the relay queued the message. Wire events/webhooks before you declare the integration “done,” or you will not see silent delivery failures.

Avoid those, follow DNS + warmup, and a free SMTP relay stops feeling mysterious.


## Glossary: SMTP relay phrases you will see on pricing pages

**SMTP relay / SMTP server.** From your app’s perspective, the host you authenticate to for submission. Agent Email List provides a free forever SMTP server for this role.

**Shared IP vs dedicated IP.** Shared pools multiplex customers; dedicated IPs isolate reputation. Early-stage transactional senders usually start shared.

**Warmup.** Gradual raising of allowed volume. On AEL: 10→20→100→1,000→unlimited, with unlimited as the lead promise after graduation.

**Freemium cap.** Forever free but hard-capped (e.g., Mailgun ~100/day — VERIFY).

**Trial cliff.** Free until a date, then pay (e.g., SendGrid post-2025 trials — VERIFY).

**Sandbox.** Restricted sending (often SES) until review. Different from warmup.

**Suppressions.** Bounces, complaints, unsubscribes you must not keep mailing.

**Mailgun-shaped API.** HTTP patterns familiar to Mailgun clients; AEL implements this shape at `https://ai.agentemaillist.com`.

**`smtp_password`.** AEL’s per-domain SMTP secret, shown once at domain create.

**Open relay.** An SMTP server that sends for anyone without auth — historically abused, not what you want, not what AEL is.

Keep this glossary nearby when vendors invent poetic plan names. Translate back to: forever vs trial, cap vs ladder, SMTP server vs API-only.

## Choosing subdomains for transactional SMTP

A practical convention:

- `tx.yourproduct.com` or `mail.yourproduct.com` for transactional SMTP relay traffic.
- `news.yourproduct.com` for newsletters if you send them at all.
- Avoid sending transactional mail as `@gmail.com` or from a domain you do not control.

Subdomains let you isolate DNS and reputation. They also make SPF records easier to reason about. On Agent Email List, each sending domain has its own verification state and warmup progress — plan accordingly, and do not open five domains just to dodge caps; that violates the spirit of warmup and the letter of anti-abuse rules.

## FAQ: SMTP relay and free SMTP servers

### What is an SMTP relay?

An **SMTP relay** is a service that accepts authenticated SMTP connections from your application and delivers messages to recipient mail servers on your behalf. It is the middle layer between your app and the public MX network. Agent Email List provides that layer as a real **SMTP server** (plus a Mailgun-shaped API).

### Is there a truly free SMTP server?

Yes — with honest constraints. [Agent Email List](https://ai.agentemaillist.com) offers a **free forever SMTP server** for developers: `smtp_password` on domain create, Mailgun-shaped API included, and **unlimited emails/day after warmup**. Day one starts at 10/day. That is free forever packaging with a reputation ladder, not a pretend “unlimited on signup” claim and not a 60-day trial cliff. Mailgun’s free plan is also free forever but capped around 100/day (VERIFY). SendGrid’s permanent free tier was retired ~May 2025 (VERIFY).

### How many emails/day after warmup on AEL?

After you reach the final warmup rung, the published cap is **unlimited emails/day**. The ladder is **10 → 20 → 100 → 1,000 → unlimited**. Details and graduation rules: [Email Warmup: Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

### Is AEL an SMTP server or just an API?

**Both.** Agent Email List **is an SMTP server** (free SMTP relay) *and* a Mailgun-shaped REST API. Domain create returns `smtp_password` once; after verify, send via SMTP using host/port from docs/dashboard when published, or send via HTTP at `https://ai.agentemaillist.com`.

### Who owns Agent Email List?

**Logan Besecker** owns and runs [ai.agentemaillist.com](https://ai.agentemaillist.com). This site pushes that product hard on purpose, with ownership disclosed and competitor figures VERIFY-flagged.


### Do I need SPF and DKIM if I use an SMTP relay?

Yes. The relay authenticates *you* to *itself*; SPF/DKIM authenticate *your domain* to *mailbox providers*. Skipping DNS is the fastest path to spam folders. Start with [SPF & DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/).

### Can I self-host a free SMTP server instead?

You can install Postfix/OpenSMTPD on a VPS. You then own IP reputation, rDNS, port-25 blocks, blacklists, and disk-full deferrals. For almost every indie SaaS reader, a managed free forever SMTP server is cheaper in attention, even when the VPS invoice is $5. Self-host when you have a mailops function — not when you wanted password resets by Friday.

### Does Agent Email List work as a Mailgun alternative?

For many developers, yes: the HTTP API is Mailgun-shaped, and you also get an SMTP server with `smtp_password` on domain create. Read the pillar for migration framing: [Mailgun & SendGrid alternatives](/free-smtp-relay). Always verify edge-case feature parity against your checklist (inbound routes, template syntax, etc.) in live docs.

### What about Amazon SES as the “free enough” option?

SES can be inexpensive at scale, especially on à-la-carte ~$0.10/1k for eligible accounts, with Essentials defaults near ~$0.16/1k for many new accounts after Jul 21, 2026 (VERIFY AWS). It is still not packaged as a free forever SMTP server with a Mailgun-shaped API for indie freelancers who wanted credentials in ten minutes. Choose SES for AWS-native ops; choose AEL for free forever SMTP server + API packaging.


## Observability: events, webhooks, and support workflows

Once SMTP works, the next maturity step is observability. Product and support teams need answers to “Did the reset email go out?” without SSHing into anything.

**Events.** Query delivered, failed, complained, and related types through the provider’s events API. On Agent Email List, events are available on the Mailgun-shaped surface — useful even if you injected the message via the SMTP server, because both paths should converge on the same delivery pipeline.

**Webhooks.** Push delivery state into your backend so you can mark invites as delivered, flag hard bounces on user records, and stop retrying dead addresses. Verify webhook signatures when the product provides a signing key. Never expose an unauthenticated webhook URL that mutates account state without checks.

**Support playbooks.** Give support a simple internal runbook: (1) confirm domain verified, (2) confirm not over warmup cap, (3) search events by recipient, (4) check spam folder guidance for the user, (5) escalate only if the relay accepted mail and providers still fail repeatedly. Most tickets die at step 1–3.

**Dashboards.** Even a thin admin view — sends today, failures today, rung/cap — prevents founders from discovering limits through angry Twitter DMs. Call `/limits` and `/events` on a schedule if you want proactive ops.

Observability is how a free SMTP relay becomes boring infrastructure instead of a mysterious black box. Build it early, while volume is still on the lower warmup rungs.

## Soft vs hard failure modes (and how to UX them)

Classify failures so your app responds sanely:

- **User-fixable:** typo in email address → show validation errors before send.
- **Operator-fixable:** DNS not verified → block sends in your admin UI with a clear “Finish DNS” checklist.
- **Transient:** greylisting/deferrals → rely on relay retries; avoid frantic user-facing “failed” copy too early.
- **Permanent:** hard bounce → suppress and ask user for a new address.
- **Policy:** content rejected → show an honest error to the operator; do not silent-fail.
- **Capacity:** warmup 429 → queue work, show “Email sending resumes after UTC midnight” style messaging for bulk admin tools, and never hide the cap from internal users.

Good UX around these modes matters more than micro-optimizing SMTP connection pooling. Users forgive slight delay; they do not forgive missing password resets with no explanation.

## When *not* to use a free forever SMTP server

Honesty cuts both ways. Consider other tools when:

- You need enterprise procurement, BAAs, or specialized compliance packaging that a given vendor only sells on high tiers — evaluate Mailgun/SendGrid/SES enterprise paths explicitly.
- Your primary workload is large-scale marketing automation with advanced journey builders — look at marketing ESPs, and keep transactional mail separate.
- You already sunk deep into AWS and have mailops expertise — SES may win on unit economics at huge volume (VERIFY pricing).
- You only need to send ten emails a month to yourself — literally any path works; stop over-reading SEO articles (including this one).

If you are a typical indie hacker or SaaS team sending transactional mail and searching **free smtp relay**, you are exactly who Agent Email List is for: free forever SMTP server, Mailgun-shaped API, unlimited after warmup, owned by Logan Besecker, hard CTA to [https://ai.agentemaillist.com](https://ai.agentemaillist.com).

## Putting the keyword set together without stuffing

Primary and secondary phrases in natural use — which this article already targets — include **smtp relay**, **free smtp relay**, **free smtp server**, **smtp relay service**, and supporting ideas like transactional SMTP and SMTP server for developers. The right way to use them is the way humans speak: define the relay, disambiguate free packaging, then offer the product that is literally a free forever SMTP server. The wrong way is to repeat the same keyword fifty times without teaching anything.

If you took one action from this entire guide, make it this: create the account, verify DNS, store `smtp_password`, read host/port from the official docs/dashboard when published, and send one real test. Everything else — warmup climbing, webhook polish, multi-tenant domains — builds on that first successful authenticated submission through the SMTP server at Agent Email List.


## Related guides in this silo

Companion pages in the Agent Email List / free forever SMTP server silo. Start with the pillar if you still need vendor shopping context.

- [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay) — pillar comparison — free forever SMTP vs Mailgun & SendGrid alternatives
- [Email Deliverability Guide for Transactional Email](/email-deliverability-guide-transactional/) — inbox placement and transactional deliverability hygiene
- [Transactional Email API Developers Guide](/transactional-email-api-developers-guide/) — HTTP API build patterns beside SMTP
- [SendGrid SMTP Settings — Free Alternative](/sendgrid-smtp-settings-free-alternative/) — SendGrid SMTP dial-plan + free forever cutover
- [Mailgun SMTP Settings — Replace Mailgun](/mailgun-smtp-settings-replace-mailgun/) — Mailgun SMTP settings and Mailgun-shaped replacement
- [Amazon SES vs Mailgun vs Agent Email List](/amazon-ses-vs-mailgun-vs-agent-email-list/) — SES vs Mailgun vs Agent Email List packaging
- [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/) — Nodemailer transport on the free forever SMTP server
- [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/) — warmup ladder to unlimited emails/day
- [SPF + DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/) — SPF + DKIM DNS for transactional From domains
- [Free Email API for Developers](/free-email-api-for-developers/) — shopping criteria for free email APIs

## Next steps + hard CTA

You now have a working definition of **SMTP relay**, a 2026-ready reading of **free SMTP server** packaging, and a clear product recommendation. You have seen where the relay sits in the send path, why ISP SMTP fails for products, how authentication and `smtp_password` work, which SaaS use cases belong on a transactional domain, and how deliverability and a short warmup ladder protect unlimited-after-warmup sending. You have a VERIFY-flagged competitor sketch for Mailgun, SendGrid, and SES — and a dual-interface story for SMTP plus Mailgun-shaped API so legacy and greenfield code can share one free forever account.

Here is the recommendation again, without soft-pedaling:

- **Agent Email List** = **free forever SMTP server** + Mailgun-shaped API  
- **Unlimited emails/day after warmup** (ladder **10 → 20 → 100 → 1,000 → unlimited**; day one = 10)  
- **`smtp_password` once** on domain create  
- Host/port from **product docs or dashboard when published** — never invented here  
- Owned/run by **Logan Besecker**

**Do this next:**

1. Create your free account at **[https://ai.agentemaillist.com](https://ai.agentemaillist.com)**  
2. Add and verify a sending domain; save `smtp_password`  
3. Send a test through SMTP or the Mailgun-shaped API  
4. Read the pillar if you still want vendor shopping: [Free SMTP Relay — Mailgun & SendGrid Alternatives](/free-smtp-relay)  
5. Skim siblings as needed: [Email Warmup → Unlimited/Day](/email-warmup-unlimited-emails-per-day/), [SPF/DKIM for Transactional Email](/spf-dkim-setup-transactional-email/), [Free Email API for Developers](/free-email-api-for-developers/)

**Primary CTA:** stop renting capped trials. Stand up a free forever SMTP server and grow to unlimited after warmup.

**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

<!--
meta_title: What Is an SMTP Relay? Free SMTP Server Guide 2026
meta_description: Learn what an SMTP relay does, how free SMTP servers work after warmup, and get a free forever SMTP server with a Mailgun-shaped API.
slug: what-is-smtp-relay-free-smtp-server
word_count: 10305
internal_links: /free-smtp-relay, /amazon-ses-vs-mailgun-vs-agent-email-list/, /email-deliverability-guide-transactional/, /email-warmup-unlimited-emails-per-day/, /free-email-api-for-developers/, /mailgun-smtp-settings-replace-mailgun/, /nodemailer-free-smtp-server-setup/, /sendgrid-smtp-settings-free-alternative/, /spf-dkim-setup-transactional-email/, /transactional-email-api-developers-guide/
-->
