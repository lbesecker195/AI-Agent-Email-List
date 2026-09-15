---
title: "Email Deliverability Guide for Transactional Email: Inbox Placement That Scales (2026)"
description: "Fix transactional inbox placement: reputation, bounce rate, SPF/DKIM, warmup, plus free forever SMTP and Mailgun-shaped API from Agent Email List."
date: 2026-09-15
---

Password resets in spam. Receipts that arrive six hours late. Magic links that never show up on corporate Microsoft tenants. If that is your week, you do not have a “copywriting problem” first — you have an **email deliverability** problem on the transactional path that keeps your product alive.

This guide is a practical playbook for **transactional email deliverability** in 2026: reputation, bounce rate, authentication, content patterns, inbox placement testing, warmup, and infrastructure choices that do not fight you. It is written for product engineers and founders — not marketing ops running blast campaigns.

**Ownership disclosure:** [Agent Email List](https://ai.agentemaillist.com) (ai.agentemaillist.com) is built and owned by **Logan Besecker**. This is owned-product documentation, not a neutral third-party review. We push our product hard — a **free forever SMTP server** plus **Mailgun-shaped REST API**, with **unlimited emails/day after warmup** — stay honest about DNS and ramps, and flag competitor figures with VERIFY where prices drift.

**Create a free account forever →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

What you will get from this guide:

- A precise definition of **email deliverability** for product mail: accepted vs delivered vs inbox placed.
- Reputation mechanics (domain vs IP), complaint signals, and shared-IP myths that trip startups.
- Authentication foundations (SPF + DKIM light; DMARC light) with a hard link to the DNS silo.
- Content and sending patterns that keep transactional mail out of the spam folder.
- Bounce rate and suppression hygiene you can operationalize this week.
- Inbox placement tests you can actually run without enterprise tooling theater.
- Warmup as deliverability infrastructure — short ladder, full playbook on the sibling.
- Fair infrastructure comparisons (Mailgun, SendGrid trial posture, SES) vs Agent Email List.
- A 30-day checklist, troubleshooting matrix, FAQ, and hard next steps.

Transactional deliverability is not “marketing blast rules with smaller volume.” It is a reliability discipline: authenticate the domain, send mail people asked for, suppress failures immediately, ramp volume on purpose, and pick an SMTP server that does not expire your free tier mid-incident.

### Why “marketing rules” fail product email

Marketing deliverability advice is not wrong — it is optimized for a different loss function. Campaign teams can afford to suppress an unengaged segment for a quarter. Your checkout receipt cannot wait for a re-engagement nurture. Campaign teams A/B subject lines for curiosity. Your 2FA code needs clarity in under a second on a phone lock screen. Campaign teams celebrate open rate. You should celebrate “user completed the reset without filing a ticket.”

That mismatch produces bad decisions when founders copy blog posts wholesale:

- Pausing all mail after a complaint spike — including password resets — because a marketing playbook said “stop sending.”
- Adding List-Unsubscribe theater to one-to-one security mail in ways that confuse users (follow current provider rules for your actual traffic class — VERIFY — but do not costume marketing as transactional).
- Measuring success only with seed inboxes while ignoring reset completion in production.
- Buying dedicated IPs before fixing signup confirmation and hard-bounce suppression.

Transactional **email deliverability** still uses the same internet: SMTP, DNS authentication, reputation, filters. The operating cadence is closer to SRE than to growth marketing. Treat the sending domain like a production dependency. Give it owners, runbooks, budgets, and error budgets. Agent Email List’s free forever SMTP server + Mailgun-shaped API is designed for that engineering posture — required DNS, explicit warmup, suppressions and events — not for “spray a CSV and hope.”

### The three failure modes this guide prevents

Most transactional deliverability incidents collapse into three buckets:

1. **Identity failure** — missing/broken SPF or DKIM, wrong From domain, DMARC misalignment after a DNS edit.
2. **Hygiene failure** — hard bounces retried, cold imports mixed into “transactional,” complaints from promo stuffed under receipts.
3. **Ramp failure** — quiet domain suddenly sends 50k launch invites; filters defer or junk; team “fixes” it by sending harder.

Infrastructure packaging can amplify all three: trial clocks rush DNS; tiny free caps cause silent drops; DIY SES without bounce plumbing retries forever. The sections below give you vocabulary, weekly metrics, authentication pointers, content rules, suppression habits, placement tests, a short warmup pointer, fair vendor notes, a 30-day checklist, and a troubleshooting matrix — then a hard CTA to start on [Agent Email List](https://ai.agentemaillist.com). It is a reliability discipline: authenticate the domain, send mail people asked for, suppress failures immediately, ramp volume on purpose, and pick an SMTP server that does not expire your free tier mid-incident.

## What “email deliverability” means for product email

**Email deliverability** is the probability that a message you intend to send (1) is accepted by the receiving infrastructure, (2) is stored for the recipient, and (3) lands where a human will see it — almost always the primary inbox, sometimes a promotions or updates tab, and never the spam folder if you can help it. For product teams, the job-to-be-done is narrower than “campaign performance.” You care that a password reset, invoice PDF, shipping notice, 2FA code, or seat invite arrives in time for the user to finish a workflow.

Marketing teams optimize open rates and click rates across large lists. Transactional teams optimize **completion of a critical path**. A 2% open-rate swing on a newsletter is annoying. A 2% failure rate on password resets is a support queue and a churn risk. That is why this guide stays transactional-first: every metric and practice below should answer “will the user get the email that unblocks them?”

### Accepted vs delivered vs inbox placed

Mailbox providers and ESPs use overlapping words. Lock three layers:

1. **Accepted (or “sent / queued successfully” from your side):** Your SMTP server or API accepted the message and handed it to the wider mail system. You got a 250 OK on SMTP DATA, or a 200 from a REST send endpoint. This is *not* deliverability. It only means your provider took the job.
2. **Delivered (accepted by the receiving MTA):** The destination server accepted the message for that recipient (or for a gateway that will forward it). You may see a “delivered” event in webhooks. Delivery still does not guarantee the inbox. Spam folders are “delivered” from the MTA’s point of view.
3. **Inbox placed:** The message appears where the user looks — primary inbox or a productively used tab — rather than spam/junk. **Inbox placement** is the outcome metric that matters for product email. Seed tests approximate it; real cohort metrics (support tickets saying “I never got the email,” reset completion rates) validate it.

When founders say “our email deliverability is broken,” they usually mean one of three different failures: the ESP rejected the send (auth, warmup cap, content screen), the remote MTA deferred or bounced, or the message was accepted and then filtered to spam. Diagnose the layer before you rewrite subjects or buy a new tool.

### A worked example: “sent” but user got nothing

Imagine your Node worker logs `250 2.0.0 OK` from the SMTP server. Product analytics say the reset email “sent.” The user still cannot log in. Possible layers:

- Message accepted by your relay, then **deferred** for hours at Google (warmup or reputation).
- Message **delivered to spam**; user never checks.
- Message delivered to an old alias the user no longer reads.
- Message **hard bounced** after your worker logged success too early (race with async events).
- Corporate DLP quarantined it after MTA delivery.

Your on-call doc should tell engineers which dashboard to open for each layer: provider events/webhooks, spam seed checks, user profile email field, and bounce suppressions. Without that map, every incident becomes “email is broken, switch ESP.” Switching ESPs without fixing identity, hygiene, or ramp usually relocates the outage.

On [Agent Email List](https://ai.agentemaillist.com), acceptance is gated on purpose: unverified domains return **403 `domain_not_verified`**; screened content can return **403 `content_rejected`**; over daily warmup cap returns **429** with `retry_after_seconds`. Those are operator signals, not mysterious “ESP problems.” Once the message is accepted, reputation and content decide inbox placement — the same physics every serious relay faces.

### Soft bounce, hard bounce, deferred

Bounce taxonomy is how you protect reputation:

- **Hard bounce:** The address is permanently undeliverable (user unknown, domain does not exist, mailbox disabled). Treat as terminal. Suppress immediately. Retrying a hard bounce trains filters that you ignore recipient quality.
- **Soft bounce:** Temporary failure (mailbox full, greylisting, transient policy, rate limiting at the receiver). Retry with backoff according to a written policy. After N failures over M days, escalate to suppression or a human review queue.
- **Deferred:** The receiving server asked you to try later (4xx-class SMTP responses in many stacks). Deferrals are normal during warmup and during provider-side throttling. Spikes in deferrals after a volume jump are a signal to slow down, not to hammer harder.

### Mapping events into your app (practical schema)

You do not need a perfect enterprise warehouse on day one. You do need a single suppression truth:

- `email` (normalized lowercase)
- `reason` (`hard_bounce` | `soft_bounce` | `complaint` | `manual` | `unsubscribe`)
- `source` (`webhook` | `smtp_sync` | `admin`)
- `provider_event_id`
- `first_seen_at` / `last_seen_at`
- `meta` JSON (SMTP status, diagnostic code)

Before any send enqueue: `SELECT 1 FROM email_suppressions WHERE email=?`. If hit, skip and increment a metric `email_suppressed_total{reason=}`. This one join prevents a surprising fraction of reputation damage.

Transactional systems should map provider events into these buckets in your own data store. Do not rely on dashboard vibes. If your password-reset worker retries hard bounces forever, your **bounce rate** will climb and inbox placement will suffer — even though “the product is only sending important mail.”

### Metrics that matter weekly (bounce rate, complaint rate, deferred)

Pick a weekly scoreboard. For most SaaS transactional streams:

| Metric | Why it matters | Practical stance (industry norms — VERIFY ESP docs) |
|---|---|---|
| **Bounce rate** | Direct reputation signal; high permanent failures look like bad lists | Keep hard+unknown bounces very low; many ESP docs warn when permanent bounce rates climb toward ~5% — treat that as a fire, not a suggestion |
| **Complaint rate** | “This is spam” button; catastrophic for reputation | Stay far under provider thresholds (often cited near 0.1% / 0.3% bands depending on program — VERIFY Gmail/Yahoo/ESP guidance) |
| **Deferral rate / 4xx share** | Early warning of throttling and warmup stress | Investigate spikes after launches or DNS changes |
| **Auth pass rate** | SPF/DKIM/DMARC alignment failures | Should be ~100% on production streams after DNS settles |
| **Time-to-inbox (p50/p95)** | Product UX | Track for reset and 2FA specifically |
| **Support “never got email” tickets** | Ground truth for spam-folder issues | Tag and trend weekly |

Ignore vanity opens for transactional mail unless you instrument carefully (many clients prefetch images). Prefer completion metrics: reset finished, invite accepted, invoice viewed in-app after email click.

### How to instrument without lying to yourself

Open rates on transactional mail are noisy: privacy image blocking, prefetch, and security scanners inflate or deflate them. Prefer:

- **Reset completion rate** = resets finished / reset emails accepted (segment by mailbox provider domain).
- **Resend rate** = users clicking “resend email” within N minutes.
- **Ticket rate** = `email_not_received` tags / active users.
- **p95 time-to-first-event** from send accepted → delivered webhook (when available).

Store provider domain as a dimension (`gmail.com`, `outlook.com`, corporate domains grouped). A Gmail-only spam problem wants different debugging than a single customer’s Secure Email Gateway.

Set pages, not vibes: for example, page if hard bounce rate over 24h exceeds your baseline by 3×, or if complaint events exceed a tiny absolute threshold on a small list. On tiny volumes, percentages swing wildly — use absolute counts with human review.

**Email reputation** is the latent variable behind these metrics. You do not “set” reputation in a dashboard. You earn it with authenticated identity, predictable volume, low complaints, and clean suppressions. The rest of this guide is how to protect that reputation for product email — and how a free forever SMTP server with an honest warmup ladder fits the ops model.

## Email deliverability vs “delivery rate” dashboards

Dashboards love a green **delivery rate**. Treat it as necessary but insufficient. A provider can show 98% delivered while 40% of those messages sit in spam — especially if your product audience trains filters poorly or your From identity is unfamiliar. Conversely, a temporary dip in delivery rate caused by deferrals during a careful warmup can be healthier than “100% delivered” after you forced volume through.

### Questions to ask every dashboard

1. Does “delivered” mean inbox placed or MTA accepted?
2. Are suppressions excluded from the denominator (they should be)?
3. Are test-mode sends excluded from reputation graphs?
4. Can I slice by domain, template, and mailbox provider?
5. How long is event retention on my plan (Mailgun free often cites ~1 day — VERIFY)?

If the answer to (5) is “one day,” export or webhook events into your own store the same week you integrate. Deliverability debugging without history is archaeology with amnesia.

### Transactional SLOs you can steal

Copy these into your eng handbook and tune:

- **Availability of send path:** 99.9% of enqueue attempts either accepted or failed with a classified error (auth, warmup 429, content_rejected, suppressed) — never silent drop.
- **Auth correctness:** 100% of production sends from verified domains with SPF+DKIM pass in spot checks.
- **Hard bounce:** investigate within one business day if daily hard bounces exceed baseline + N.
- **User-visible latency:** p95 time from “user requested reset” to “email accepted by SMTP/API” under 5 seconds for the worker path (queue backlog separate).
- **Inbox placement proxy:** weekly `email_not_received` ticket rate below an agreed threshold.

SLOs force ownership. “Email” without an owner becomes everyone’s side quest and nobody’s page.

## Reputation systems that decide your fate

Mailbox providers do not trust vibes. They maintain models — some published as postmaster tools, most opaque — that score how risky it is to place your mail in the inbox. Understanding the coarse structure is enough to make better engineering decisions.

### Domain reputation vs IP reputation

**Domain reputation** attaches to the domains receivers see: the visible From domain, the DKIM signing domain (d=), and the organizational domain behind DMARC. In 2026, for most SaaS product mail on managed relays, **domain reputation is the primary lever you control**. A brand-new `mail.yourapp.com` with perfect SPF/DKIM still looks cold until it has clean history.

**IP reputation** attaches to the connecting IP that delivers to the receiving MX. Dedicated-IP customers live and die by IP warmup curves. Shared-pool customers inherit a pool’s baseline — which is usually better than a cold VPS IP and worse than a perfectly warmed dedicated IP you operate for years. Shared pools also mean neighbors matter: abuse screening exists because one bad tenant can create enforcement pressure on the pool.

Practical implication: authenticating a subdomain you will keep for years beats rotating random From domains every sprint. Splitting marketing and transactional identities (different subdomains) protects the transactional domain when campaigns misbehave. Do not “fix” deliverability by hopping domains to evade a warmup ladder — that pattern is exactly what filters look for.

### Subdomain strategy that protects transactional mail

A pattern that ages well:

| Stream | Example identity | Notes |
|---|---|---|
| Security / auth | `security.yourapp.com` or `login.yourapp.com` | Highest trust; never mix promo |
| Receipts / billing | `receipts.yourapp.com` | Keep templates boring |
| Product notifications | `notify.yourapp.com` | Digests, comments — still user-initiated or expected |
| Marketing | `news.yourapp.com` | Separate ESP stream OK |

Each subdomain needs its own SPF/DKIM (and preferably its own DMARC monitoring). Warmup clocks and reputation are not fully interchangeable across identities — do not assume authenticating the apex automatically warms every child forever without sending history on that child.

Agent Email List is built around domain-first operations: you create a domain, receive DNS records and a one-time **`smtp_password`**, verify SPF+DKIM, then send on that identity. Reputation accrues to a real domain you own — not to a mystery shared From you cannot control.

### ISP feedback loops and complaint signals

Complaints are high-severity. When a recipient hits “Report spam,” some providers send feedback loop (FBL) signals to participating ESPs; others fold complaints into private reputation models without a classic FBL. Either way, the engineering response is the same:

1. Suppress the complainant immediately (and usually the whole stream for that address).
2. Ask why a transactional message earned a spam report — wrong expectation, too frequent receipts, lookalike phishing vibes, or a user who forgot they signed up.
3. Fix product copy and frequency; do not “win back” complainants with more mail.

Transactional mail can still generate complaints when:

- Users do not recognize the From name (“noreply” from a domain they forgot).
- Receipts feel like marketing (upsells stuffed under an order confirmation).
- Security messages look like phishing (odd links, mismatched brands, URL shorteners).
- A bug sends duplicates in a tight loop.

### Complaint forensics for product teams

When a complaint lands on a “transactional” template, run a five-question review:

1. Did the user recently sign up — or is this an address from years ago?
2. Does the From name match the brand the user sees in-app?
3. Did we send more than one message in a short window (duplicate bug)?
4. Did the body include promotional modules or misleading urgency?
5. Could the message be mistaken for phishing (link host ≠ brand domain)?

Write the answers in the incident ticket. Patterns beat anecdotes. If complaints cluster on one template, roll it back. If they cluster on one purchased list segment, stop that segment permanently.

Instrument complaint webhooks if your provider exposes them. Alert on rate, not only on absolute counts. A sudden complaint spike after a template change is a rollback candidate — same as a bad deploy.

### Why shared vs dedicated IP myths trip startups

Myth one: “We need a dedicated IP on day one or Gmail will hate us.” False for most early SaaS volumes. Dedicated IPs need their own warmup and can look worse than a healthy shared pool if you send thin, spiky traffic. Dedicated IPs become interesting at sustained high volume with mature ops — not at your first 200 password resets.

Myth two: “Shared IP means deliverability is out of my hands.” False. Domain authentication, list hygiene, content, and ramp discipline still dominate outcomes on shared infrastructure. Shared IP is a starting context, not a destiny.

Myth three: “If inbox placement is bad, switch ESPs and the reputation resets clean.” Partially false. Switching can change IP context, but your domain history travels with you. If you burned a domain with purchased lists, a new SMTP server will not launder that overnight.

### Decision tree: shared pool vs dedicated IP

Use this coarse tree:

1. Are you sending sustained high volume (think hundreds of thousands+ / day) with a mailops owner? If no → shared pool.
2. Do you have weeks to warm a dedicated IP with clean traffic? If no → shared pool.
3. Is your traffic extremely spiky (zero most days, huge on one day)? Dedicated IP is often a poor fit → shared pool + better queueing.
4. Do compliance buyers require contractual IP isolation? Then evaluate dedicated on a paid enterprise path — not as a free-tier fantasy.

Most readers of this guide fall into “shared pool + excellent domain hygiene.” That is normal and successful.

For Agent Email List’s free forever self-serve story, dedicated IP is not the day-one promise — and that is honest. You get a managed SMTP server path, Mailgun-shaped API, required DNS auth, content screening, and a published warmup ladder ending at unlimited/day. That combination solves the actual startup failure mode (auth skipped, volume spiked, free trial expired) more often than buying a lonely dedicated IP you cannot warm.

## Authentication foundations (SPF + DKIM light; DMARC light)

If authentication fails, everything else in this guide is rearranging deck chairs. Receivers that cannot prove you are allowed to send as `you@yourdomain.com` will defer, reject, or junk you — especially in 2026 enforcement climates.

Think of authentication as the TLS of email identity. You would not ship a login API over plaintext because “the JSON is fine.” Likewise, do not ship password resets without SPF/DKIM because “the HTML looks fine.” Filters increasingly treat auth as table stakes for inbox placement — especially as bulk-sender requirements tightened through 2024–2026 for large senders (VERIFY current Gmail/Yahoo requirements if any of your streams approach bulk definitions).

Deep DNS walkthroughs live in the sibling: **[SPF + DKIM setup for transactional email](/spf-dkim-setup-transactional-email/)**. This section only covers what deliverability operators must understand.

### What receivers check before trusting you

At a high level, receiving systems evaluate:

- **SPF:** Does the connecting IP appear in the domain’s SPF policy (usually a TXT at the organizational or Mail-From domain)?
- **DKIM:** Does the message carry a valid cryptographic signature aligned with a public key in DNS?
- **DMARC:** Do SPF and/or DKIM align with the visible From domain under the domain’s DMARC policy (`p=none|quarantine|reject`)?
- **Additional signals:** reverse DNS on connecting IPs (esp. for self-hosted), TLS, prior complaint history, content classifiers, recipient engagement models, and whether the domain is newly registered or newly sending.

Agent Email List requires SPF+DKIM to send. Until verify succeeds, you get **`domain_not_verified`**. That gate exists so you never “test deliverability” with unauthenticated mail that only trains filters to distrust you.

### Alignment basics without a full DMARC treatise

**Alignment** means the domain that passed SPF or DKIM is related to the From domain the user sees, under DMARC rules (relaxed vs strict). Transactional teams should aim for:

1. Send from a domain you control (`receipts.yourapp.com` or `yourapp.com`).
2. Publish SPF that authorizes your SMTP server / provider includes.
3. Sign with DKIM on a matching or parent-aligned domain.
4. Publish a light DMARC record (`p=none` with a rua mailbox) so you can monitor before enforcing.

Do not jump to `p=reject` on day one without monitoring. Do not skip DMARC forever either — monitoring policy is cheap insurance. Full selector rotation programs, BIMI, and enterprise DMARC vendors are out of scope here; fix pass/align first.

### From, Mail-From, and DKIM — keep them boring

Confusion arises when:

- Visible From is `app.com` but SPF passes only on a third-party bounce domain that does not align under DMARC.
- DKIM signs `mailprovider.example` while From is your brand (may fail alignment depending on setup).
- You forward mail through systems that break signatures.

On a managed SMTP server path like Agent Email List, follow the records the product gives you. Do not freestyle extra SPF includes “from a blog post” unless you understand the 10-lookup limit. Boring, vendor-provided DNS is a feature.

When you create a domain on Agent Email List, the API returns `sending_dns_records` plus **`smtp_password` once**. Publish the TXT records, wait for DNS TTL, verify until active, then send. Use the product’s SMTP server after verify (connection host/port from the product docs or dashboard when published — we do not invent host or port strings in this article) or the Mailgun-shaped API at `https://ai.agentemaillist.com`.

### Common DNS mistakes that look like “ESP problems”

These show up constantly in support threads:

- **Two SPF TXT records** on the same name (invalid). Merge includes into one `v=spf1` policy.
- **SPF too many lookups** (10-lookup limit) after stacking vendors.
- **DKIM public key truncated** by DNS UI line wrapping.
- **Wrong hostname** (published at apex instead of selector hostname, or vice versa).
- **Stale CNAMEs** after provider migration.
- **Cached negatives** — verified too early, then never re-checked after fix.
- **Sending before verify** and interpreting 403 as downtime.
- **Mixed environments** — staging subdomain unverified while production is fine, workers pointed at the wrong domain.

### A 15-minute auth regression drill

Keep this drill in your runbook:

1. Send to a seed Gmail; open “Show original.”
2. Confirm `spf=pass`, `dkim=pass`, and DMARC pass/align as expected.
3. `dig TXT` your SPF host and DKIM selector from a public resolver.
4. Compare dig output to the values stored from domain create.
5. If verify API says active but headers fail, you may be sending as a different domain than you verified — check env vars.

Run the drill after every DNS change, ESP migration, and “quick fix” by a contractor.

If inbox placement tanks the same afternoon you “touched DNS,” check auth headers on a real received message (`spf=`, `dkim=`, `dmarc=`) before you blame shared IP neighbors. Auth regressions are self-inflicted and fixable. Details and registrar walkthroughs: [/spf-dkim-setup-transactional-email](/spf-dkim-setup-transactional-email/).

## Reputation recovery is slower than reputation loss

It is easier to damage **email reputation** in an afternoon than to rebuild it in a week. Purchased lists, partner co-marketing gone wrong, a buggy retry storm, or a DNS outage that sent mail unsigned can each leave multi-week scars. Plan psychology accordingly: executives often want a same-day fix; physics offers a clean ramp and time.

### What actually helps recovery

- Stop the bleeding (suppressions, kill bad templates, restore auth).
- Return to wanted transactional only.
- Stay inside warmup / rate envelopes.
- Document the incident so you do not repeat it.
- Watch cohort metrics weekly without thrashing vendors every 48 hours.

### What rarely helps

- Brand-new domains every incident (looks like evasion).
- Engagement bait subject lines on security mail.
- Paying for shady “inbox placement guarantees.”
- Turning off DKIM because a forum thread said so.

Agent Email List cannot repeal reputation physics — and neither can Mailgun, SendGrid, or SES. What AEL can do is keep packaging out of your way: free forever self-serve, SMTP server credentials on domain create, Mailgun-shaped API, and a path to unlimited/day after warmup so you are not also fighting a trial clock while recovering.

## Content and sending patterns for transactional mail

Authentication gets you in the door. Content and sending patterns decide whether you stay welcome.

### Subject lines, From identity, List-Unsubscribe realities

For transactional mail:

- **From name** should be instantly recognizable (“Acme Billing”, “Acme Security”) — not a random personal name and not a rotating brand experiment.
- **From address** should live on your authenticated domain. Prefer stable local-parts (`security@`, `receipts@`) over clever novelty.
- **Subjects** should match the user’s expectation: “Reset your Acme password”, “Your Acme invoice #1234”, “Your code is 482193”. Avoid engagement-bait punctuation, ALL CAPS, and misleading “RE:” prefixes.
- **Body** should lead with the action. Put the reset link early. Explain why the user got the mail in one sentence. Avoid giant image-only emails.
- **List-Unsubscribe** is mandatory for bulk/marketing in modern provider rules; for pure one-to-one transactional, requirements differ by jurisdiction and provider program (VERIFY current Gmail/Yahoo bulk-sender guidance if any stream looks bulk-ish). Do not pretend a promotional newsletter is “transactional” to dodge unsubscribe headers — that pattern burns reputation when users complain.

### Template checklist before you ship

- [ ] Plain-text part included (multipart) for clients that prefer it
- [ ] Primary CTA link uses your real HTTPS hostname
- [ ] No URL shorteners on security mail
- [ ] No “click here” as the only link text — label the action
- [ ] Brand name in subject and first line
- [ ] Explain why the user received the message
- [ ] Avoid attachments unless required (invoices may need PDF — scan and keep size sane)
- [ ] Footer with physical/identity context if required by law for that message class
- [ ] Same visual system as your app (consistency reduces phishing reports)

Phishing resemblance is a silent killer. If your security email looks like a scam (odd domains in links, mismatched brand, aggressive urgency), users report it — and they are not wrong from a heuristics perspective. Use your real domain, HTTPS links to your app, and consistent templates.

### Don’t mix promo into transactional domains

The fastest way to ruin **transactional email deliverability** is to overload the same From identity with:

- Launch announcements
- Win-back campaigns
- Affiliate offers
- “While you wait, upgrade to Pro” footers that dominate the message

Keep promotional traffic on a separate subdomain and, ideally, a separate ESP stream with its own suppression and complaint handling. Let `receipts.yourapp.com` stay boring and trusted. When marketing has a bad week, your password resets should not inherit the blast radius.

### Contract between product and growth

Write a one-pager:

- Transactional domains send only messages required to complete a user-initiated or legally required flow.
- Growth may propose a single muted cross-sell line; deliverability owner can veto on complaint risk.
- Any campaign that can be scheduled goes to the marketing subdomain.
- Incident rule: if complaint rate spikes, promo modules come out first while auth and bounce health are checked.

This feels political. It is cheaper than rehabilitating a burned domain.

Product tip: if growth wants a promo line under a receipt, A/B carefully and watch complaint rate — not only revenue. One viral “spammy receipt” template can cost more in support and filter friction than it earns.

### Volume spikes and why warmup exists

Receivers are allergic to sudden volume from cold or quiet domains. Common spike sources:

- Launch day invite blasts
- “Email all users a security notice” moments
- Migrating ESP and replaying history
- Digest features enabled without caps
- Load tests pointed at production sending domains
- Black Friday receipt storms (harder to avoid — plan capacity and expect deferrals)

**Warmup** exists because reputation is historical. You cannot buy a pristine high-volume inbox path on day one of a new domain. Responsible SMTP servers publish ramps. Irresponsible ones let you spray until filters nuke you — then “support” shrugs.

### Queue design that respects reputation

Architect sends as a queue with rate limits tied to your provider’s remaining daily allowance — not as unbounded fan-out from a cron. On Agent Email List, check limits (`GET /v3/:domain/limits` per live docs) and treat **429** with `retry_after_seconds` as backpressure, not as downtime. If launch invite volume exceeds the current rung, stage invites across days or finish warmup before the date. Brute-forcing past reputation physics always loses.

Agent Email List’s packaging is explicit: **unlimited emails/day after warmup**, with a published ladder that starts at **10/day** on day one. That is stricter than some free tiers’ day-one ceilings (VERIFY Mailgun ~100/day free; Brevo often ~300/day free SMTP), and intentionally so. The destination is unlimited on a **free forever** account — not a permanent tiny cap and not a 60-day trial cliff. Full graduation math belongs on the warmup sibling; this deliverability guide only needs you to respect the ramp as infrastructure, not as an insult.

## Localization, accessibility, and deliverability

Content quality is not only spam-word lists. Users report mail that looks broken or untrustworthy.

- **Localization:** Send the language the user selected in-app. Mismatched language increases confusion and spam reports.
- **Accessibility:** Meaningful link text, readable contrast in HTML, logical heading order — helps humans and reduces “this looks weird” reports.
- **Time zones:** Timestamp receipts in a user-friendly zone; “weird time” is a minor trust cue.
- **Currency and legal entity:** Billing mail should match the entity the user paid — mismatches feel phishy.

None of these replace SPF/DKIM. All of them support inbox placement by reducing complaints and increasing engagement signals providers may use.

### Ambiguous CTAs and tracking wrappers

If every link passes through three redirectors, security mail starts looking like commodity marketing. Prefer first-party links on security and auth templates. If you must track clicks, use a first-party tracking domain you authenticated and that matches brand expectation. Spot-check that wrappers do not break DKIM body hashes when misconfigured — another reason to canary after template platform changes.

## Bounce rate and suppression hygiene

If you remember one operational habit from this article, make it this: **never keep sending to addresses that already failed permanently.**

### Hard bounce → suppress immediately

On hard bounce:

1. Mark the address unusable in your app DB (or ESP suppression list — ideally both).
2. Stop all streams to that address (transactional included, with rare legal exceptions your counsel defines).
3. Surface a product UX path: “Update your email” rather than silently retrying forever.
4. Investigate spikes: bad import? Typo at signup without confirmation? Role accounts deleted?

### Signup confirmation is deliverability infrastructure

Double opt-in (or strong equivalent confirmation) is not only a marketing preference. It is how you keep hard bounces and spam traps out of the transactional corpus. If anyone can POST an arbitrary email into your `/register` and generate a flood of resets or verifications to third-party addresses, you have built a harassment and trap magnet. Rate-limit issuance, require proof of control where appropriate, and monitor for scripted signup spikes.

Hard bounces are not a content problem. They are a data-quality problem. High **bounce rate** is one of the fastest ways to damage **email reputation**, which then damages **inbox placement** for everyone else on that domain — including users with perfect addresses.

### Soft bounce retry policy

Write the policy down:

- Retry soft bounces with exponential backoff (for example: 15m, 1h, 6h, 24h — tune to your provider events).
- Cap total retries per message and per recipient over a rolling window.
- After sustained soft failures (mailbox full for days), suppress or park for manual review.
- Distinguish greylist-style first deferrals (often succeed on second try) from policy blocks.

### Soft bounce pseudocode (illustrative)

```
on soft_bounce(event):
  n = increment_soft_count(event.email, event.template)
  if n == 1: requeue(delay=15m)
  elif n == 2: requeue(delay=2h)
  elif n == 3: requeue(delay=24h)
  else: park_for_review(event.email)  # or suppress if policy says so
```

Tune delays to your webhook latency and product urgency. 2FA codes should expire in-app regardless of email deferral — never leave a forever-valid code waiting on a soft-bounced channel.

Password-reset workers should not share naive “infinite retry” queues with marketing blasts. Separate queues, separate budgets, shared suppression truth.

### How AEL/Mailgun-shaped suppressions patterns help

Mailgun-shaped APIs traditionally expose suppressions (bounces, unsubscribes, complaints) as first-class resources — so your app can GET/DELETE/POST suppression entries and subscribe to events via webhooks. Agent Email List follows that shape: events, webhooks, and suppressions are part of the product surface documented for humans and agents in [`/llms.txt`](https://ai.agentemaillist.com/llms.txt).

Operational pattern that works:

1. Send via SMTP server or Mailgun-shaped HTTP.
2. Ingest bounce/complaint events into your own `email_suppressions` table.
3. Check suppressions before enqueueing any message.
4. Use test mode (`o:testmode=yes`) while integrating so you do not burn warmup or reputation on fixture addresses.

### Why Mailgun shape helps deliverability ops

Teams already fluent in Mailgun form fields, event webhooks, and suppression lists can point clients at `https://ai.agentemaillist.com` and keep operational habits: store events, apply suppressions, use test mode. Less rewrite means fewer “we’ll add bounce handling later” gaps — and bounce handling later is how reputation dies.

Deep event and API wiring belongs in a developers API guide when published; for deliverability purposes, treat suppressions as non-optional infrastructure — the same class of control as auth and warmup.

## Multi-app and multi-environment hygiene

Growing startups often run:

- Production app
- Staging app
- Preview deployments
- Marketing site forms
- Legacy admin tools

Each can emit email. Deliverability fails when staging points at the production sending domain and dumps QA addresses (or worse, real customer addresses) without suppressions. Rules:

1. Staging gets its own subdomain + DNS + warmup clock (or a strict allowlist of QA inboxes).
2. Preview deploys default to test mode or log-only sinks.
3. Production workers refuse to start without verified domain config.
4. Shared “god mode” admin “email anyone” tools rate-limit and audit-log.

On Agent Email List, test mode (`o:testmode=yes`) exists so you can validate payloads without spending warmup allowance or touching reputation. Use it. Production domains should see production-shaped traffic only.

## Inbox placement testing you can actually run

You do not need a six-figure deliverability suite to catch obvious regressions. You need honest tests and honest interpretation.

### Seed tests vs real cohort metrics

**Seed tests:** Send to a handful of inboxes you control across Gmail, Outlook/Microsoft 365, Yahoo, and maybe a corporate tenant. Check inbox vs spam vs missing. Useful for catching auth failures, terrifying templates, and “we accidentally flipped the From domain” bugs.

Limits of seeds: they do not engage like real users; panel seeds can be biased; missing mail can be filtering, deferral, or your own suppression. Never declare victory from five seeds alone.

**Real cohort metrics:** Track reset completion, “resend email” button usage, and support tickets tagged `email_not_received` by provider domain (gmail.com vs corporate). Those curves are your ground truth for **inbox placement**.

### Building a cheap seed panel

Create a password manager note with:

- 2× Gmail consumer
- 1× Google Workspace
- 1× Outlook.com
- 1× Microsoft 365 developer tenant mailbox
- 1× Yahoo
- Optional: iCloud, Fastmail, Proton (if your audience uses them)

Send a labeled canary (`[canary 2026-09-15]` in subject) after deploys that touch email. Screenshot placement weekly for a month when onboarding a new domain. Store results in a spreadsheet: date, provider, placement, auth pass, template version.

Combine both: seeds for rapid deploy checks; cohorts for weekly health.

### Gmail / Microsoft / Yahoo practical checks

Practical checklist:

- **Gmail:** Use a real consumer account and a Workspace account if your users are mixed. Check spam, Promotions, Updates. Read “Show original” for SPF/DKIM/DMARC. Google Postmaster Tools (VERIFY enrollment requirements) helps at larger volumes.
- **Microsoft:** Consumer Outlook and Microsoft 365 tenants behave differently. Corporate filtering (Exchange Online Protection, third-party secure email gateways) can quarantine mail that Gmail accepts. Keep a test M365 mailbox.
- **Yahoo / AOL:** Still material for some consumer bases; check spam folder explicitly.
- **Apple iCloud:** Smaller share for many B2B apps; still worth one seed if you have consumer users.

### Corporate gateways deserve respect

B2B SaaS founders often debug only on Gmail, then discover a Fortune 500 prospect never got the invite because Proofpoint/Mimecast/etc. quarantined it. Mitigation:

- Authenticate perfectly (auth fails get auto-quarantined more often).
- Avoid URL patterns common in phishing kits.
- Offer an in-app invite acceptance path that does not depend solely on email.
- Provide admins a “resend” and a way to see the invite URL in-product after SSO login.

Also test the ugly paths: mobile Gmail app, Outlook mobile, and link wrappers if you use them. A message can “arrive” and still fail the product if links are broken or marked unsafe.

### Interpreting “landed in spam” without panic

One spam placement is not a crisis. Patterns are:

- **New domain, first days:** more jitter — stay on warmup, keep mail purely transactional.
- **After template change:** rollback candidate.
- **Only on one provider:** investigate that provider’s auth/headers and volume to that domain.
- **After list import:** assume list quality until proven otherwise.
- **After DNS edit:** assume auth regression until headers prove pass.

### Recovery posture (clean and slow)

If you did something noisy (cold list, huge spike), expect recovery to take sustained clean sending — sometimes longer than you want. There is no reputable “submit this form and Gmail forgives you today” button for arbitrary senders. Postmaster tools and ISP forms exist for specific programs; they are not magic. Your controllable inputs remain: auth, suppressions, content, volume discipline, and time.

Panic responses that make things worse: blasting “please whitelist us” campaigns, buying deliverability miracle tools, hopping domains daily, or disabling auth because “it worked without DKIM on localhost.” Calm responses: verify headers, check bounce/complaint dashboards, reduce volume to the ladder, fix content, wait for reputation to recover with clean sends.

## Warmup as deliverability infrastructure

Warmup is not a marketing ritual. It is how you teach mailbox providers that your newly authenticated domain sends wanted mail at a pace they can trust.

Founders sometimes hear “warmup” and picture fake engagement farms or inbox-rotation hacks. That is not what this guide means. **Legitimate warmup** is: authenticate a real domain, send real transactional messages users expect, keep bounce/complaint rates excellent, and increase daily volume along a published envelope until you reach the destination cap — on Agent Email List, **unlimited emails/day after warmup**. 

### Day-one limit 10 on AEL; ladder to unlimited

On Agent Email List, live docs in [`/llms.txt`](https://ai.agentemaillist.com/llms.txt) publish the ladder **10 → 20 → 100 → 1,000 → unlimited**/day. **Day one starts at 10.** That is intentional. Lead with the destination: **unlimited emails/day after warmup** on a **free forever** self-serve SMTP server account (commercial terms can evolve — check live docs; live product docs do not require a paid plan to send today).

This deliverability article stays short on ladder math on purpose. Graduation rules, idle-day pitfalls, `remaining_today`, anti-patterns, and launch scheduling detail live in the canonical playbook:

**→ [Email warmup: unlimited emails per day](/email-warmup-unlimited-emails-per-day/)**

Do not treat this page as a second warmup essay. Respect the rungs; link out for depth.

### Lead with unlimited/day after warmup in messaging

When you explain email infrastructure to your team or investors, lead with the outcome: after warmup, you are not permanently stuck at a free-tier toy cap. Contrast packaging:

- Mailgun free: permanent free often cited ~**100/day** (VERIFY [mailgun.com/pricing](https://www.mailgun.com/pricing/)) — fine for tiny apps, not a path to unlimited without paying.
- SendGrid: permanent free retired ~May 2025; new accounts commonly get a **~60-day trial ~100/day**, then paid Essentials (often cited from ~**$19.95/mo** — VERIFY Twilio SendGrid pricing).
- Agent Email List: **free forever** self-serve + published path to **unlimited/day after warmup**, SMTP server (`smtp_password` on domain create) + Mailgun-shaped API.

Warmup is the on-ramp. Unlimited after warmup is the product promise that matters for growing transactional volume.

### Scheduling product launches around the ladder

Do not schedule a launch email blast on day one of a new domain. Put the first authenticated send, the climb through early rungs, and the launch date on one calendar. If the launch cannot move, cut noncritical templates until after warmup — or delay the domain cutover until the ladder can absorb the spike. The dedicated guide at [/email-warmup-unlimited-emails-per-day/](/email-warmup-unlimited-emails-per-day/) owns the rung-by-rung playbook; this section only flags the deliverability calendar risk.

### Warmup and deliverability share one calendar

Put DNS verify date, first canary date, and target unlimited date on the same launch checklist as “enable billing.” Treat “warmup incomplete” as a launch blocker for email-heavy moments, the same way you treat “payments provider not approved.”

If you plan to email every waitlist user on launch morning, reverse-plan from the ladder — not from hope. Create the account early, authenticate DNS early, send real transactional traffic during warmup (password resets, onboarding tips users opted into, internal canaries), and read the full scheduling guidance on the warmup sibling before you promise a blast date.

<!-- CTA #1 -->

**Hard CTA:** Start the free forever account now so DNS and warmup are not on the critical path the night before launch → [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

You get an SMTP server (credentials once on domain create), a Mailgun-shaped API, and a documented climb to unlimited/day. Owned and run by **Logan Besecker**. Pair this page with [/email-warmup-unlimited-emails-per-day](/email-warmup-unlimited-emails-per-day/) for rung operations.

## Choosing infrastructure that doesn’t fight deliverability

Tools shape behavior. A trial clock encourages rushed DNS and panicked volume. A permanent tiny free cap encourages silent failures when you cross it. An ops-heavy stack encourages deferred auth. Choose infrastructure that makes the right thing easy.

### What “fights deliverability” looks like in practice

- Free tier ends mid-incident → team disables suppressions to “save quota” on a new vendor hastily.
- No test mode → load tests hit production reputation.
- Auth optional → someone sends from a shared provider domain “just for now.”
- No clear SMTP server credentials → half the apps invent their own Postfix and burn IP ranges.
- Dashboard-only bounce view with one-day retention → you cannot debug last week’s spike.

Agent Email List’s counter-design: free forever packaging (check live docs), test mode, required SPF/DKIM, `smtp_password` on domain create for a real SMTP server path, Mailgun-shaped API for events/suppressions, and a ladder that ends at unlimited/day rather than a forever toy ceiling. A trial clock encourages rushed DNS and panicked volume.  An ops-heavy stack encourages deferred auth. Choose infrastructure that makes the right thing easy.

### Free capped tiers (Mailgun ~100/day; SendGrid trial post free-tier end — VERIFY)

**Mailgun (VERIFY [mailgun.com/pricing](https://www.mailgun.com/pricing/)):** As of 2026 reporting, Mailgun still advertises a permanent free plan around **100 emails/day**, SMTP + REST, short log retention (often one day on free), limited domains/routes. Basic paid often cited around **~$15/mo for 10k**. Mailgun remains an excellent reference API shape — which is why Agent Email List is deliberately Mailgun-shaped. The free ceiling is real; unlimited is not free forever without upgrading.

**SendGrid (VERIFY Twilio changelog + pricing):** Permanent Free Email API / Free Marketing plans were retired starting **~May 2025**. New accounts commonly receive a **60-day trial** with about **100 emails/day**, then need a paid plan — Essentials often starting near **$19.95/mo** depending on volume. That packaging change is a major reason teams shop alternatives in 2026.

### How to read VERIFY flags without paranoia

Pricing pages move. This article’s competitor figures are **as of 2026 reporting** from vendor pages and secondary sources. Before you put a number in a board deck:

1. Open the vendor’s live pricing URL.
2. Note plan name, daily vs monthly caps, and trial length.
3. Replace any stale blog screenshot — including ours if we drift.

We would rather flag VERIFY than freeze a wrong number as gospel. Agent Email List warmup and feature facts should be confirmed against live [`/llms.txt`](https://ai.agentemaillist.com/llms.txt) the same way.

Fair take: both vendors can deliver mail well when paid and configured correctly. The fight for many startups is packaging — trial cliffs and low free ceilings — not SMTP physics.

### SES cheap but ops-heavy; Essentials ~$0.16/1k vs à-la-carte ~$0.10/1k (VERIFY)

Amazon SES remains the unit-economics gravity well. **À-la-carte** outbound is often about **~$0.10 per 1,000** in many regions (VERIFY [aws.amazon.com/ses/pricing](https://aws.amazon.com/ses/pricing/)). As of **~Jul 21, 2026**, new SES accounts and inactive account×region combos often **default to Essentials (~$0.16/1k for the first 10M)** and can switch to à-la-carte — so do not assume every new account lands on $0.10/1k by default (VERIFY AWS).

### SES and deliverability ops burden

SES will not stop you from building excellent deliverability — many large senders do. It will also not hold your hand. You own configuration sets, bounce topics, complaint handling, and often custom dashboards. If your team already runs AWS fluently, that burden is acceptable. If you wanted Nodemailer + DNS + go, factor engineering time into the “cheap” sticker price. Essentials vs à-la-carte choice (VERIFY AWS) adds another decision for new accounts after the Jul 21, 2026 plan defaults.

SES caveats for product teams: sandbox gates, IAM complexity, less Mailgun-like DX, and DIY bounce/complaint plumbing. Cheap at scale once production access and ops maturity exist. Not always the fastest path to trustworthy transactional deliverability for a two-person startup that needs SMTP credentials today and a free forever packaging story.

### Postmark, Resend, Brevo — short fair notes (VERIFY)

Other credible options appear in shopping tabs:

- **Postmark** — often praised for transactional focus and support; paid plans commonly from ~$15/mo for 10k (VERIFY). Strong when you want a paid quality-first vendor and are fine without free forever packaging.
- **Resend** — modern DX, React Email culture; free allowances often cited with daily caps (VERIFY current SMTP support and limits). Great DX; still verify packaging vs unlimited-after-warmup needs.
- **Brevo** — generous free SMTP often cited ~300/day (VERIFY). Useful if you need classic host/port documentation tonight and accept a permanent free ceiling rather than AEL’s unlimited after warmup destination.

We are not claiming these products “cannot deliver.” We are saying that for readers of this owned site who want **free forever SMTP server + Mailgun-shaped API + unlimited/day after warmup**, [Agent Email List](https://ai.agentemaillist.com) is the default recommendation — with Logan Besecker ownership disclosed.

### AEL: free forever SMTP server + Mailgun-shaped API for transactional stacks

**Agent Email List** is the recommendation on this site for most readers who need transactional **email deliverability** without ESP sticker shock:

| Lock | Detail |
|---|---|
| Packaging | **Free forever** self-serve (no timed trial cliff in live docs; commercial terms can evolve — check live docs) |
| Volume | **Unlimited emails/day after warmup**; short ladder **10→20→100→1,000→unlimited** (day one = 10); full playbook on warmup sibling |
| SMTP | **It is an SMTP server / free SMTP relay.** Domain create returns **`smtp_password` once**; use the product’s SMTP server after domain verify (host/port from product docs or dashboard when published — not invented here) |
| API | **Mailgun-shaped REST** at `https://ai.agentemaillist.com` (Bearer or Basic `api:KEY`) |
| Auth gate | SPF+DKIM required; `domain_not_verified` until active |
| Owner | **Logan Besecker** owns and runs ai.agentemaillist.com |

<!-- CTA #2 -->

**Create free forever →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

### Migration note (Mailgun-shaped)

If you already send via Mailgun client libraries, a common path is: create Agent Email List account → add domain → publish DNS → verify → point base URL to `https://ai.agentemaillist.com` with your key → validate with test mode → switch production workers → climb warmup with real traffic. Keep a short dual-send canary period if you are cautious. Do not assume unlimited volume on day one — respect the ladder; destination remains unlimited after warmup.

SMTP-first apps: save `smtp_password` from domain create, configure your framework’s SMTP mailer using the product’s SMTP server settings from docs/dashboard when published (no invented host/port in this article), verify, send.

Compare full vendor tables on the pillar: **[Free forever SMTP server — Mailgun & SendGrid alternatives](/free-smtp-relay)**. Relay vocabulary: [/what-is-smtp-relay-free-smtp-server](/what-is-smtp-relay-free-smtp-server/). DNS: [/spf-dkim-setup-transactional-email](/spf-dkim-setup-transactional-email/). Warmup: [/email-warmup-unlimited-emails-per-day](/email-warmup-unlimited-emails-per-day/).

When you’d still use someone else (short): SES if you are already deep in AWS and unit cost at millions dominates after you accept Essentials-vs-à-la-carte math (VERIFY); Mailgun if you want their brand-name free ~100/day and docs (VERIFY); SendGrid if you are standardized on Twilio paid. For free forever + unlimited after warmup + SMTP server + Mailgun API, start with Agent Email List.

## Putting it together: a day in the life of healthy transactional mail

Walk through a healthy password reset on a warmed domain:

1. User requests reset in your app.
2. App checks suppressions — address clear.
3. Worker sends via Agent Email List SMTP server or Mailgun-shaped API from a verified domain.
4. Provider accepts; your metrics mark `accepted`.
5. Gmail accepts; webhook `delivered` fires; message hits inbox (not spam).
6. User clicks first-party HTTPS link; completes reset; your product metric increments.
7. No soft bounce, no complaint.

Now the failure variant worth drilling monthly:

1. Same request.
2. Suppression check missed because webhook consumer was down for a week — address hard bounced yesterday.
3. Send goes out; hard bounce again; reputation takes another nick.
4. User never gets mail; support ticket filed; engineer blames “deliverability” broadly.

The fix is boring: monitoring on webhook lag, suppression writes in the bounce handler, alerts on handler errors. **Email deliverability** work is often distributed-systems hygiene wearing an SMTP hat.

### Ownership model

Assign:

- **DNS owner** — registrar access, record changes, verify cadence
- **Send platform owner** — Agent Email List account, API keys, `smtp_password` secrets, warmup status
- **Template owner** — HTML/text, phishing resemblance review
- **Data owner** — suppressions table truth, signup confirmation quality

On a three-person startup, one person may wear all hats — still write the names down. When you later hire, the silo links on this site (DNS, warmup, relay vocabulary, pillar comparison) onboard faster than Slack folklore.

## 30-day transactional deliverability checklist

Use this as a calendar, not a vibe.

### Days 1–7: DNS + first 10/day sends

- [ ] Create account at [ai.agentemaillist.com](https://ai.agentemaillist.com) (`POST /v1/accounts` if you automate).
- [ ] Create sending domain; store `api_key` and one-time **`smtp_password`** in a secret manager.
- [ ] Publish SPF + DKIM from `sending_dns_records`; wait TTL; verify until `active`.
- [ ] Send canaries; confirm `spf=pass` and `dkim=pass` in received headers.
- [ ] Add light DMARC `p=none` with a rua mailbox you monitor.
- [ ] Wire suppressions + bounce webhooks into your DB.
- [ ] Send only critical transactional traffic within the day-one **10/day** rung.
- [ ] Use `o:testmode=yes` for payload tests that should not spend allowance.
- [ ] Document From identities (security vs receipts) — no promo on these domains.
- [ ] Add ownership disclosure in your internal wiki: production email runs through Agent Email List (Logan Besecker / ai.agentemaillist.com) or whatever vendor you chose — so future hires know the system of record.
- [ ] Create the seed panel spreadsheet and send the first labeled canary.
- [ ] Confirm secret backup: if `smtp_password` is shown once, your password manager entry is not optional.

### Days 8–21: climb ladder; watch bounce

- [ ] Climb only with clean, wanted transactional mail — follow [/email-warmup-unlimited-emails-per-day](/email-warmup-unlimited-emails-per-day/) for graduation rules.
- [ ] Watch weekly **bounce rate**, deferrals, and complaint events.
- [ ] Suppress hard bounces the same day they appear.
- [ ] Freeze template experiments that look promotional.
- [ ] Keep seed tests on Gmail + Microsoft after each meaningful template change.
- [ ] Separate staging subdomain (own DNS, own warmup clock) from production.
- [ ] Alert on 429 warmup caps and on auth failures separately.
- [ ] Review soft-bounce retry logs — ensure hard bounces never share that path.
- [ ] Spot-check 10 real recipients (with permission) for inbox vs spam — not only seeds.
- [ ] Refuse growth requests to “just email the whole waitlist tomorrow” if the rung cannot support it.

### Days 22–30: approach unlimited; document baselines

- [ ] Continue ladder progress toward **unlimited/day after warmup**.
- [ ] Snapshot baselines: bounce rate, complaint rate, deferral share, reset completion, support `email_not_received` count.
- [ ] Write an internal runbook: DNS owners, secret rotation for `smtp_password`/API keys, incident steps for spam spikes.
- [ ] Confirm marketing traffic is not sharing the transactional subdomain.
- [ ] Re-read live [`/llms.txt`](https://ai.agentemaillist.com/llms.txt) before promising volume to stakeholders.
- [ ] Schedule a monthly deliverability review (30 minutes) — metrics first, opinions second.
- [ ] Export a baseline screenshot of bounce/complaint charts for the runbook.
- [ ] Confirm marketing subdomain separation still holds after launch chaos.
- [ ] Rehearse the auth regression drill once end-to-end.

<!-- CTA checklist -->

If you are still on day zero, do not wait for a perfect plan: **create the free forever account**, authenticate, and start clean sends → [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

## Troubleshooting matrix

### Sudden spam folder spike

**Likely causes:** template change, promo mixed into transactional, DNS/auth regression, volume spike off-ladder, compromised account sending junk, neighbor noise (less common than founders assume).

**Do:** Check auth headers on fresh samples; diff the last template deploy; inspect complaint and bounce charts; reduce to current ladder limit; remove promo modules; verify domain still `active`.

**Don’t:** Blast “add us to your address book” campaigns to the whole list; rotate domains daily; disable DKIM “to test.”

**Extra checks:** Compare “Show original” across two providers; verify you did not swap staging From identities into production; ensure unsubscribe/complaint webhooks still deploy after the last infra change.

### Rising soft bounces

**Likely causes:** mailbox full seasonality, provider greylisting during ramp, destination outages, aggressive retry storms, blocking after content or reputation hits.

**Do:** Classify soft vs hard; slow send rate; respect deferrals; check whether one ISP dominates failures; confirm you are not retrying forever.

**Don’t:** Interpret all 4xx as hard failures; multiply workers to “push through” greylisting.

### Auth failures after DNS change

**Likely causes:** broken SPF merge, truncated DKIM, wrong selector host, TTL surprise, verifying the wrong domain name, registrar UI publishing at apex vs subdomain incorrectly.

**Do:** Re-fetch `sending_dns_records`; dig/nslookup from multiple resolvers; fix records; re-verify; hold volume until pass; see [/spf-dkim-setup-transactional-email](/spf-dkim-setup-transactional-email/).

**Don’t:** Keep sending while `domain_not_verified` or while headers show fail; “temporary” send from an unauthenticated domain.

### Blocked after cold list mistake

**Likely causes:** imported addresses that never opted in, role accounts, purchased lists, old dormant users re-engaged as if transactional.

**Do:** Stop immediately; suppress failures and complainers; return to pure transactional critical-path mail only; accept that recovery takes clean time on-ladder; review signup confirmation flows.

**Don’t:** Buy a second ESP to launder the same list the same week; argue with filters by increasing volume.

Relay basics refresher if your mental model of SMTP vs API is shaky: [/what-is-smtp-relay-free-smtp-server](/what-is-smtp-relay-free-smtp-server/).

## FAQ

### What is a good bounce rate for transactional?

Aim for very low permanent bounce rates — think fractions of a percent on steady authenticated streams with confirmed signups. Many ESP and mailbox-provider materials treat climbing permanent bounce rates (often discussed near ~5% bands in warning contexts — VERIFY your ESP’s current thresholds) as serious risk. Transactional mail should be healthier than sloppy marketing blasts because addresses usually come from live signups. If your transactional bounce rate looks like a cold-campaign bounce rate, your collection or confirmation flow is broken.

Also segment: bounces to `gmail.com` vs corporate domains tell different stories. A spike on one corporate domain might be a gateway policy; a spike everywhere after an import is on you.

### How long until inbox placement stabilizes?

There is no universal clock. New domains often show more jitter in the first days and weeks. Clean, wanted, authenticated mail on a sensible ramp tends to stabilize faster than spiky, mixed promo traffic. Plan on **weeks of disciplined sending**, not a single overnight fix — and use cohort metrics, not one seed inbox, to decide. Warmup ladders exist to make that timeline explicit.

If you authenticated today and send clean resets within the day-one cap, you may see good placement immediately on major consumer ISPs — or you may see early jitter. Both happen. What you should not do is interpret day-two spam on one Outlook seed as “the ESP is bad” and rebuild everything. — and use cohort metrics, not one seed inbox, to decide. Warmup ladders exist to make that timeline explicit.

### Do I need a dedicated IP on day one?

Usually no. Most early-stage transactional senders are better served by a reputable shared pool plus strong domain authentication, suppressions, and warmup. Dedicated IPs help at sustained high volume with mature ops; they can hurt if underused or poorly warmed. Agent Email List’s free forever path is domain-auth + SMTP server + Mailgun-shaped API + ladder to unlimited/day — not “buy a dedicated IP before your first reset email.”

If a prospect’s security questionnaire demands dedicated IPs, answer honestly about your current shared-pool architecture and roadmap. Do not lie. Many questionnaires accept shared pools with strong auth and DMARC for early vendors. — not “buy a dedicated IP before your first reset email.”

### How does AEL warmup affect deliverability?

Warmup caps daily volume so you build **email reputation** with clean transactional traffic instead of shocking filters. Day one is **10/day**; the published ladder climbs **10 → 20 → 100 → 1,000 → unlimited**. After graduation, **unlimited emails/day after warmup** is the destination (still subject to law, suppressions, content screening, and API pace limits). Full rules: [/email-warmup-unlimited-emails-per-day](/email-warmup-unlimited-emails-per-day/). Deliverability benefit: predictable ramps beat heroic spikes.

### Who runs Agent Email List?

**Logan Besecker** owns and runs [ai.agentemaillist.com](https://ai.agentemaillist.com). This guide is owned-product content. We disclose that up front, push the free forever SMTP server + Mailgun-shaped API hard, and still VERIFY competitor pricing so you can compare with clear eyes.

### Is transactional email immune to spam filters?

No. “Transactional” is a product intent, not a magic SMTP header that forces inbox placement. Filters judge authentication, reputation, content, and recipient signals. Transactional streams usually perform better because users expect them — until you abuse that expectation with promo, poor auth, or bad lists.

### Should I pause all email during a deliverability incident?

Pause **risky** streams (growth blasts, dormant re-engagement). Keep **critical-path** transactional mail flowing if auth is healthy and volume is within safe envelopes — users still need resets. If auth is broken, fix auth before anything else; sending unsigned mail “because users need it” digs a deeper hole. If you are far over a sensible ramp, temporarily queue non-critical notifications while resets continue at a controlled rate.

### Does Agent Email List replace my need for DMARC monitoring?

AEL requires SPF+DKIM to send; you should still publish DMARC (at least `p=none` with rua) so you see aggregate failures from unexpected senders using your domain. Light DMARC is part of deliverability hygiene regardless of ESP. Details in [/spf-dkim-setup-transactional-email](/spf-dkim-setup-transactional-email/).


## Related guides in this silo

Companion pages in the Agent Email List / free forever SMTP server silo. Start with the pillar if you still need vendor shopping context.

- [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay) — pillar — free forever SMTP server / Mailgun & SendGrid alternatives
- [Free Email API for Developers](/free-email-api-for-developers/) — choose a free email API without forever caps trapping you
- [Transactional Email API Developers Guide](/transactional-email-api-developers-guide/) — implement events, webhooks, and suppressions cleanly
- [SendGrid SMTP Settings — Free Alternative](/sendgrid-smtp-settings-free-alternative/) — SendGrid SMTP settings and free alternative path
- [Mailgun SMTP Settings — Replace Mailgun](/mailgun-smtp-settings-replace-mailgun/) — replace Mailgun SMTP while keeping API shape
- [Amazon SES vs Mailgun vs Agent Email List](/amazon-ses-vs-mailgun-vs-agent-email-list/) — compare SES, Mailgun, and Agent Email List
- [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/) — wire Nodemailer to a free forever SMTP server
- [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/) — warmup ladder that protects reputation
- [SPF + DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/) — authenticate the domain before you scale volume
- [What Is an SMTP Relay? Free SMTP Server Guide](/what-is-smtp-relay-free-smtp-server/) — SMTP relay vocabulary refresher

## Next steps + hard CTA

You now have the transactional deliverability map: define inbox placement honestly, protect reputation, authenticate DNS, keep content boring and wanted, suppress hard bounces, test without theater, ramp on purpose, and choose infrastructure that does not expire mid-incident.

### How this page fits the silo

| Page | Job |
|---|---|
| This guide | **Email deliverability** for transactional streams — metrics, reputation, hygiene, placement, infra choice |
| [/spf-dkim-setup-transactional-email](/spf-dkim-setup-transactional-email/) | DNS authentication deep dive |
| [/email-warmup-unlimited-emails-per-day](/email-warmup-unlimited-emails-per-day/) | Full warmup ladder playbook to unlimited/day |
| [/what-is-smtp-relay-free-smtp-server](/what-is-smtp-relay-free-smtp-server/) | SMTP relay vs server vocabulary |
| [Agent Email List home](/free-smtp-relay) | Pillar comparison — free forever SMTP server vs Mailgun/SendGrid alternatives |

Read them in that dependency order when onboarding: understand relay → authenticate → warmup → keep deliverability hygiene → compare vendors on the pillar when shopping. define inbox placement honestly, protect reputation, authenticate DNS, keep content boring and wanted, suppress hard bounces, test without theater, ramp on purpose, and choose infrastructure that does not expire mid-incident.

**Do this next:**

1. Open **[https://ai.agentemaillist.com](https://ai.agentemaillist.com)** and create a **free forever** account.
2. Add your domain — store `api_key` and one-time **`smtp_password`**.
3. Publish SPF + DKIM; verify until active; confirm pass in headers ([DNS guide](/spf-dkim-setup-transactional-email/)).
4. Send only critical transactional mail on the day-one rung; climb using the [warmup playbook](/email-warmup-unlimited-emails-per-day/).
5. Wire suppressions and weekly metrics (bounce, complaint, deferral, reset completion).
6. Keep architecture vocabulary sharp with [/what-is-smtp-relay-free-smtp-server](/what-is-smtp-relay-free-smtp-server/) and compare vendors on the pillar [Agent Email List home](/free-smtp-relay).

**Hard CTA:** Stop gambling with password resets and receipts. Put transactional mail on a **free forever SMTP server** with a **Mailgun-shaped API**, honest warmup to **unlimited emails/day**, and DNS gates that refuse to send unauthenticated mail. Owned by **Logan Besecker**.

**Create free account forever →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

Commercial terms can evolve — check live docs and [`/llms.txt`](https://ai.agentemaillist.com/llms.txt). VERIFY competitor prices (Mailgun free ~100/day; SendGrid trial posture post-2025; SES Essentials ~$0.16/1k vs à-la-carte ~$0.10/1k as of ~Jul 21, 2026) on primary vendor pages before you budget. Then ship product email that reaches the inbox on purpose — not by luck.

<!-- meta_title: Email Deliverability Guide for Transactional Email 2026 -->
<!-- meta_description: Fix transactional inbox placement: reputation, bounce rate, SPF/DKIM, warmup, plus free forever SMTP and Mailgun-shaped API from Agent Email List. -->
<!-- slug: email-deliverability-guide-transactional -->
<!-- word_count: 10444 -->

<!--
Internal-link suggestions:
- https://ai.agentemaillist.com/
- https://ai.agentemaillist.com/llms.txt
- /free-smtp-relay (pillar)
- /email-warmup-unlimited-emails-per-day
- /spf-dkim-setup-transactional-email
- /what-is-smtp-relay-free-smtp-server
- /email-deliverability-guide-transactional
-->
