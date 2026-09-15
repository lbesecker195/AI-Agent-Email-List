---
title: "Email Warmup Guide: Climb to Unlimited Emails Per Day Without Killing Reputation (2026)"
description: "Learn email warm up and domain warmup limits: day one starts at 10, then 20→100→1,000→unlimited. Free forever SMTP server + Mailgun-shaped API on Agent Email List."
date: 2026-09-15
---

**Email warmup** is how you earn the right to send at scale without torching domain reputation on day one. This page is the canonical ladder essay for Agent Email List: after you graduate warmup, you get **unlimited emails/day** on a **free forever SMTP server** with a **Mailgun-shaped API** at [https://ai.agentemaillist.com](https://ai.agentemaillist.com). Day one is not unlimited — you start at **10**/day — then you climb **10 → 20 → 100 → 1,000 → unlimited**. If you only remember one sentence from this guide, make it that.

**Ownership disclosure:** Agent Email List is built and owned by **Logan Besecker**. This is not a neutral third-party review. We own the product hard, stay honest about DNS and reputation, and still flag competitor numbers with VERIFY so you can re-check primary pricing pages.

**Create a free account forever →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

What you will get from this guide:

- What **email warmup**, **email warm up**, and **domain warmup** actually mean in 2026 — reputation ramping, not a magic “warmth score.”
- Why **sending limits** exist (ISP rate limits vs ESP monetization vs healthy ladders).
- The full Agent Email List ladder playbook: **unlimited after warmup**, day one = 10, then **10 → 20 → 100 → 1,000 → unlimited**, how to read `/limits`, and how to operate each rung.
- DNS/identity checklist, measurement targets, anti-patterns, SMTP setup during warmup (`smtp_password` once on domain create), and fair VERIFY comps vs SendGrid, Mailgun, and SES.
- Hard CTAs back to the free forever SMTP server + Mailgun-shaped API — and links to the [pillar](/free-smtp-relay) plus siblings on [SMTP relay basics](/what-is-smtp-relay-free-smtp-server/), [SPF/DKIM](/spf-dkim-setup-transactional-email/), and [deliverability](/email-deliverability-guide-transactional/).

If you already know you want unlimited after warmup on a free forever account, create the account now and keep this tab open as your ops bible: [ai.agentemaillist.com](https://ai.agentemaillist.com).


This page deliberately goes deep on operations. If you only need a product one-liner, here it is again: **Agent Email List is a free forever SMTP server with a Mailgun-shaped API; day one starts at 10 messages; the live ladder is 10 → 20 → 100 → 1,000 → unlimited; unlimited emails/day after warmup is the destination.** Everything below exists so your team can execute that sentence without improvising a reputation disaster. When other articles in this silo mention warmup, they should point here rather than re-litigating the ladder.


## What email warmup actually is

**Email warmup** (also spelled **email warm up**) is the deliberate practice of starting a new sending identity at low volume and raising volume only after receivers have evidence that your mail is wanted, authenticated, and low-complaint. It is not a product feature you “turn on.” It is not a vendor dashboard badge. It is an operational discipline that ISPs, mailbox providers, and responsible relays enforce — sometimes with published ladders, sometimes with opaque throttles.

When founders search **email warmup**, they usually mean one of three jobs:

1. “How do I stop Gmail from junking my brand-new domain?”
2. “How do I **increase email sending limit** without getting deferred?”
3. “What does this ESP’s warmup / **smtp warmup** ladder actually require?”

This article answers all three for Agent Email List as the primary path, and still explains the underlying mechanics so you can evaluate any provider. Other silo pages will short-link here for ladder depth; treat this essay as canonical when you need the full **10 → 20 → 100 → 1,000 → unlimited** playbook.

Warmup sits between two extremes that both fail. Extreme A: send nothing until “someday,” then blast. Extreme B: treat day-one free credentials as infinite production capacity. Healthy **email warm up** is the middle path — authentic mail, measured volume, published graduation where the vendor offers it.

### Reputation ramping, not a magic “warmth score”

There is no universal “warmth score” that every mailbox provider publishes for your domain. What exists instead is a collection of signals that accumulate over time:

- **Authentication success** — SPF and DKIM aligned with the From domain (and preferably DMARC policy progressing toward enforcement).
- **Volume trajectory** — sudden spikes from a cold identity look like hijack or spam campaigns; smooth ramps look like real products growing.
- **Engagement proxies** — opens and clicks matter less than they used to for many filters, but hard bounces, spam complaints, and “mark as spam” rates still move reputation fast.
- **Complaint and bounce hygiene** — suppressions honored, dead addresses retired, no list bombing.
- **Content and link patterns** — phishing-shaped copy, malware-looking attachments, and sketchy redirect chains get screened even when volume is tiny.
- **Historical consistency** — a domain that sent cleanly at 20/day for weeks is safer to raise than a domain that sent nothing for a month then blasted 5,000.
- **Recipient diversity and consent** — mail to people who just took an action in your product beats mail to strangers who never heard of you.

**Email warmup** is the process of feeding those signals in the right order. You authenticate first. You send real, wanted mail at a volume receivers can absorb. You watch deferrals and bounces. You raise volume when the evidence supports it. You do not buy a “warmup service” that manufactures fake opens from bot networks — that is an anti-pattern covered later, and it can burn the exact reputation you are trying to build.

Think in phases, not vibes:

1. **Prove you are you** (DNS auth).
2. **Prove you send wanted mail** (low-volume transactional).
3. **Prove you can raise volume without complaints** (ladder climb).
4. **Operate at scale without reintroducing cold-domain habits** (unlimited with hygiene).

Agent Email List encodes this discipline as a published ladder rather than a mystery throttle. Live limits in [`/llms.txt`](https://ai.agentemaillist.com/llms.txt) and `GET /v3/:domain/limits` tell you the rung, today’s cap, remaining allowance, and what graduates you. That transparency is the product difference: **smtp warmup** you can plan against, not guess against.

### Domain warmup vs IP warmup

**Domain warmup** and **IP warmup** are related but not identical.

**IP warmup** is the older story: a new dedicated IP has no positive history, so mailbox providers rate-limit it until volume and complaint rates look healthy. Shared-pool senders still care about IP health, but they share reputation context with neighbors — which is why abuse screening exists on free forever SMTP servers like Agent Email List. If a neighbor behaves badly, providers defend the pool; if you behave badly, you endanger yourself and invite enforcement.

**Domain warmup** (and subdomain identity warmup) is what most SaaS founders actually need in 2026. Even on a mature shared IP pool, a brand-new From domain with no authenticated history looks cold. Receivers evaluate the domain in the visible From address, the DKIM signing domain, and the organizational domain behind DMARC. A new `mail.yourstartup.com` that suddenly sends thousands of password resets can still get deferred or junked if the ramp is reckless — shared IP or not.

On Agent Email List you warm the **domain** through the ladder. The service manages relay infrastructure; you manage identity, DNS, content quality, and volume discipline. That split is intentional. You cannot “buy” a hot domain by skipping SPF/DKIM. You cannot graduate by idling. You climb by sending clean mail on separate calendar days (rung 1) and then by message counts on later rungs — details in the ladder section below.

If you later move to dedicated IPs on any vendor, you will still do IP warmup *in addition to* domain hygiene. Do not confuse the two. Most readers of this page should obsess over **domain warmup** first: authenticate, send critical-path mail only, climb the published ladder, graduate to **unlimited emails/day**.

**Quick comparison**

| Concern | Domain warmup | IP warmup |
|---|---|---|
| Primary audience | Almost every SaaS on shared relay | High-volume senders on dedicated IPs |
| What you control | DNS, From identity, content, volume | Plus IP pool assignment and IP-specific ramps |
| AEL focus | Published per-domain ladder | Shared infrastructure managed for you |
| Failure mode | Cold domain spam folder / deferrals | Cold IP deferrals even with known domain |

### Why cold domains fail hard sends

Cold domains fail hard sends for boring, mechanical reasons:

1. **No positive history.** Filters have nothing good to remember about you. Absence of history is not neutrality; it is risk.
2. **Spam campaigns love new domains.** Compromised registrars, throwaway brands, and phishing kits rotate domains constantly. Defenders therefore treat sudden volume from unknowns as hostile until proven otherwise.
3. **Authentication gaps amplify suspicion.** Missing or broken SPF/DKIM is a gift to spam folders. On Agent Email List, unverified domains cannot send at all — you get **403 `domain_not_verified`** until DNS is correct. That is a feature.
4. **List quality disasters.** Importing a scraped “cold list” into transactional SMTP is the fastest way to convert a cold domain into a burned domain. Hard bounces and complaints arrive in hours, not weeks.
5. **Content that looks like onboarding spam.** “Confirm your account / claim your credits / limited time” templates copied from growth blogs often trip content screening and user spam buttons at the same time.
6. **Infrastructure novelty stacked with identity novelty.** New domain + new ESP + new template + huge list is four novel signals at once. Warmup reduces how many novelties you introduce simultaneously.

The fix is not “send harder.” The fix is **email warm up** as operations: verify DNS, start at 10/day on Agent Email List, send only mail people asked for, measure, climb. Destination: **unlimited emails/day after warmup** on a free forever account — not a trial clock.

**Start the free forever account and add your domain →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

## Why sending limits exist

**Sending limits** exist for three overlapping reasons: mailbox-provider defense, shared-pool protection, and (on many ESPs) monetization packaging. Good limits feel like guardrails. Bad limits feel like a paywall wearing a deliverability costume. You need to tell them apart — especially when your search intent is **increase email sending limit** and every vendor pretends their ceiling is purely altruistic.

### ISP rate limits and sudden volume

Gmail, Microsoft, Yahoo, and other mailbox providers apply rate limits and reputation windows that punish sudden volume. A domain that sent 50 messages yesterday and 8,000 today looks anomalous. Defenses include:

- **Deferral (4xx)** — “try again later,” which queues mail and slows your pipeline.
- **Throttling** — accepting only a fraction of connection or message rate.
- **Junk placement** — accepted but not inbox.
- **Blocks (5xx)** — permanent or long-lived refusal for some paths.
- **Complaint feedback amplification** — once users smash spam, future mail faces a higher bar.

None of these require your ESP to be “evil.” They are the internet’s immune system. Responsible relays therefore expose **sending limits** that keep customers inside envelopes receivers will tolerate while history builds. That is the healthy theory behind **email warmup**.

Agent Email List’s ladder is designed around that theory with numbers you can read live: start at 10/day, climb through 20, 100, and 1,000, then **unlimited**/day on rung 5. Exceeding today’s cap returns **429** with `retry_after_seconds`; the allowance resets at UTC midnight. Plan bulk jobs against `remaining_today` before you start — not after the first refusal.

ISP limits also explain why **smtp warmup** advice from 2014 (“double volume every day on a new dedicated IP”) is incomplete for 2026 shared-relay SaaS. You still avoid spikes, but your primary artifact is domain reputation on a managed pool — and your primary control surface is the provider’s published ladder plus your own list hygiene.

### ESP free-tier caps as fake “warmup”

Not every daily cap is a reputation ladder. Many free tiers are commercial ceilings dressed up as protection.

**Mailgun (VERIFY [mailgun.com/pricing](https://www.mailgun.com/pricing/)):** as of 2026 reporting, the permanent Free plan includes about **100 emails/day**, one custom domain, short log retention (~1 day), and ticket support. That 100/day is a free-tier product limit. Paid Basic starts around **$15/mo for 10k**/mo (VERIFY). Crossing free does not “graduate” you into unlimited on the free plan — you upgrade commercially.

**SendGrid (VERIFY [Twilio SendGrid pricing](https://www.twilio.com/en-us/products/email-api/pricing)):** the permanent free plan was retired around May–July 2025. New accounts commonly get a **60-day trial** at roughly **100 emails/day**, then need paid Essentials (often cited from about **$19.95/mo** depending on volume — VERIFY). That trial cap is a clock, not a transparent path to unlimited on free forever packaging.

Those caps matter. They are real constraints. They are not the same thing as Agent Email List’s published graduation math ending at **unlimited emails/day after warmup** on a **free forever** self-serve account (commercial terms can evolve — check live docs; live product docs do not require a paid plan to send today).

When a pricing page says “100/day free,” ask: is there a documented ladder to unlimited without a credit card? Or is 100 the ceiling until you pay? For Mailgun free and SendGrid trial, VERIFY the live pages — the packaging is free-tier / trial, not “free forever → unlimited after warmup.”

**Questions that expose fake warmup**

- What exact events graduate me to a higher free cap?
- Is the next step “pay us” or “send cleanly for N days / M messages”?
- Do idle days count?
- What error do I get at the cap, and when does it reset?
- Is unlimited available without a sales call?

If answers are fuzzy, you are probably looking at monetization packaging — fine as commerce, misleading as deliverability education.

### Healthy limits vs arbitrary monetization

Use this litmus test:

| Signal | Healthy reputation limit | Monetization cap |
|---|---|---|
| Published graduation rules | Yes (days + message counts) | Rarely; “contact sales” |
| Destination on free packaging | Unlimited after clean history (AEL) | Stay capped or forced paid |
| Error semantics | Clear 429 + reset time | Soft fail, support ticket, or upgrade wall |
| Idle behavior | Must send to progress (AEL rung 1) | Cap unchanged whether you send or not |
| Honesty in docs | Ladder table in `/llms.txt` | Marketing adjectives only |

Agent Email List aims for the left column. Day one at 10 feels strict compared with some competitors’ free daily allowances (VERIFY each vendor). The trade is honesty: you know the climb, you know unlimited is the top rung, and the account packaging is **free forever** rather than a 60-day cliff.

If you want the full product comparison across relays and APIs, read the homepage pillar: [Free forever SMTP server — Mailgun & SendGrid alternatives](/free-smtp-relay). This page owns the **email warmup** ladder narrative in depth.

## Agent Email List ladder (canonical)

This section is the canonical source for the Agent Email List warmup ladder. Sibling articles should short-link here rather than re-deriving the playbook. Numbers below match live service docs in [`/llms.txt`](https://ai.agentemaillist.com/llms.txt) as of draft time — always re-read the live file before you promise a customer a volume.

### Lead: unlimited emails/day after warmup

**After warmup, Agent Email List’s top rung is unlimited emails/day.** That is the headline. Warmup is the on-ramp, not the product forever. Rung 5 has no daily send cap in the published ladder. You still obey law, suppressions, content screening, and API pace limits (600 requests/minute per account — a pace limit, not a daily send cap). “Unlimited/day” means no daily warmup ceiling on messages once graduated — not “no rules, no screening, no physics.”

Why lead with unlimited? Because most **email warmup** content online stops at vague advice (“start small, increase slowly”) without a destination. Founders shopping **increase email sending limit** deserve a concrete end state. Ours is: graduate the ladder on a **free forever SMTP server** + **Mailgun-shaped API**, then send without a daily warmup cap.

Contrast that with trial cliffs and permanent free ceilings. Unlimited after warmup on free forever packaging is why this page exists — and why the hard CTA is always the same signup URL. Sibling articles in this silo should deep-link here when they mention the ladder; they should not invent alternate rung tables.

**What “after warmup” means in one paragraph**

You authenticated a domain, survived rung 1’s five sending days, sent 1,000 messages on rung 2, 1,000 on rung 3, and 10,000 on rung 4 — always inside each day’s cap, always with clean enough metrics that you did not pause yourself via screening or complaints. Then rung 5 removes the daily warmup ceiling. That sequence is the product promise behind **email warmup** on Agent Email List.

**Graduate toward unlimited on free forever →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

### Day one starts at 10

New verified domains start at **10 messages per day**. That is intentional and non-negotiable in the live ladder. If your job is “send this to 400 people today,” it will not happen on day one of a new domain — and discovering that mid-blast is worse than planning now.

Why 10?

- Receivers punish cold-domain spikes.
- Ten real transactional messages (signup confirms, password resets, receipts) are enough to exercise DNS, templates, and event webhooks without looking like a spam cannon.
- Test mode (`o:testmode=yes`) spends **no** warmup allowance — so you can shape requests all day without burning the ten.
- Support and agents can explain a single digit without a pricing PDF.

Burning three of ten on malformed API calls is an expensive typo. Always get a **200 in test mode** before real sends. Use `GET /v3/:domain/limits` before any bulk plan.

Day one = 10 does not mean the product is “only 10 forever.” It means honesty about **domain warmup**. The destination remains **unlimited emails/day after warmup**. If a competitor’s free tier starts at 100/day, ask whether that 100 graduates to unlimited on free forever packaging or simply sits there until a credit card appears (VERIFY their pricing). Comfort on day one is not the same as ownership of the ladder narrative — this page owns the latter.

### Ladder 10 → 20 → 100 → 1,000 → unlimited

The ladder in force (verify live `/llms.txt`):

| Rung | Cap a day | Graduates when |
|---|---|---|
| 1 | **10** | after sending on **5 separate days** |
| 2 | **20** | after **1,000** more messages sent while on this rung |
| 3 | **100** | after **1,000** more messages sent while on this rung |
| 4 | **1,000** | after **10,000** more messages sent while on this rung |
| 5 | **unlimited** | nothing; this is the last rung |

Two rules catch people out:

1. **“Days of sending” means days the domain actually sent on.** Idle weeks do not warm rung 1. You cannot wait out the first rung; you have to send through it.
2. **Each rung’s graduation count is its own allowance, not a running total from account birth.** Leaving rung 2 takes 1,000 messages *while on rung 2*; leaving rung 3 takes another 1,000 *while on rung 3*; leaving rung 4 takes 10,000 *while on rung 4*. Absolute calendar time depends on how hard you send within each daily cap.

Practical planning math (illustrative, not a promise — live counters win):

- **Rung 1:** minimum five calendar days with at least one real send each day (cap 10/day). Many teams send ~5–10 critical-path messages/day for five days.
- **Rung 2:** at 20/day, 1,000 messages implies on the order of ~50 full days if you max the cap every day — more if you undersend. Plan weeks, not hours.
- **Rung 3:** at 100/day, 1,000 messages can clear in ~10 full days of max sending.
- **Rung 4:** at 1,000/day, 10,000 messages is ~10 full days of max sending — often longer in real apps that do not flatline the cap.
- **Rung 5:** **unlimited**/day after warmup.

**Worked example (optimistic flatline, clean mail only)**

Assume you always send exactly the daily cap with zero rejects:

- Days 1–5: rung 1 at 10/day → graduate after day 5’s send.
- Next ~50 days: rung 2 at 20/day → 1,000 on-rung messages.
- Next ~10 days: rung 3 at 100/day → 1,000 on-rung.
- Next ~10 days: rung 4 at 1,000/day → 10,000 on-rung.
- Then: rung 5 unlimited.

That optimistic path is on the order of **two to three months** of disciplined flatlining — not “unlimited tomorrow,” and not “stuck at 10 forever.” Real apps undersend some days and stretch the calendar; that is expected. What matters is that the destination is published: **unlimited emails/day after warmup**.

**Worked example (sparse B2B SaaS)**

- Rung 1: five days of real verifications (easy).
- Rung 2: only ~8 messages/day average → 1,000 messages takes ~125 calendar days.
- Rung 3–4: accelerate as the product grows.

Sparse climbing is still climbing. Do not cheat with cold lists to “finish faster.”

Do not open a second account or second domain to dodge caps. Accounts are limited by IP; spreading one blast across domains to evade warmup trades long-term reputation for one day’s throughput — forbidden by the product rules and stupid for deliverability.

When you exceed today’s cap: **429** with `retry_after_seconds`; reset at **UTC midnight**. Report to your user how many went out, how many did not, and when the rest can go.

**Agent-friendly planning algorithm**

1. Call `/limits`.
2. If `remaining_today` < job size, split the job and state the schedule before sending.
3. Prefer one request with `recipient-variables` for multi-recipient template sends.
4. After each slice of ~10 accepts on long runs, report progress (the product docs recommend not going quiet for minutes).
5. On 429, wait; on `content_rejected`, stop; on `domain_not_verified`, fix DNS.

### How to read your current step in the dashboard

Programmatic source of truth:

```bash
curl https://ai.agentemaillist.com/v3/mail.yourcompany.com/limits --user 'api:KEY'
```

Expect fields that answer: which rung, today’s cap, how much is left today, what graduates the rung, and stage progress (`sent_this_stage` / `remaining_this_stage` style counters as documented live). Read this **before** a bulk job. Agents and humans both fail when they discover the cap mid-loop.

Operational checklist each morning of a climb:

1. `GET /v3/:domain/limits` — note `remaining_today` and graduation remainder.
2. Decide today’s send set ≤ remaining.
3. Prefer one batched request with `recipient-variables` over N serial sends when fan-out is required (batching still counts as N messages against the daily allowance).
4. Watch events for bounces/complaints; never remove hard bounces to “try again.”
5. If you hit 429, wait the stated seconds — do not retry loops, do not mint sibling accounts.
6. Skim screening rejects and complaint events before enabling any new template class.

**Human dashboard vs API**

If the product UI shows a progress widget, treat it as convenience UX. For automation, CI, and agent builders, `/limits` wins. When the two ever disagree in your notes, re-query the API and file the UI mismatch — do not “split the difference” by sending hope.

Dashboard UX may evolve; the API contract in `/llms.txt` is what agents should trust. If you are a human clicking around, still verify with `/limits` before promising marketing a blast size.

**Reporting template for stakeholders**

> Domain X is on rung R with cap C. Remaining today: N. Remaining to graduate stage: M. Blockers: none / DNS / bounce spike. Today’s plan: send ≤ N critical-path messages only.

That five-line status prevents executives from hearing “warmup” and translating it into “marketing can have 50k tomorrow.”

### Ownership: Logan Besecker owns/runs ai.agentemaillist.com

**Logan Besecker** owns and runs [Agent Email List](https://ai.agentemaillist.com) (docs also reference HoneyTrap Mail). Contact paths published in product docs include me@LoganBesecker.com and lbesecker195@gmail.com for domain-verify failures, delivery issues, limit questions, or serious-use conversations.

We are not pretending to be an affiliate blog. We sell the **free forever SMTP server** and **Mailgun-shaped API** with a transparent ladder to **unlimited emails/day after warmup**. Sibling and pillar pages reinforce the same product; this page owns the ladder depth. If you evaluate vendors on trust, ownership disclosure is part of the package — you know who operates the relay your password resets will ride.

**CTA #1 — Create your free forever account and start rung 1 today:** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

## Day-by-day operational playbook

Theory without ops is how domains get burned. This playbook is how to climb **10 → 20 → 100 → 1,000 → unlimited** without turning transactional mail into a reputation incident. Adjust volumes downward if complaint or bounce rates spike; never adjust upward past the live cap. Sibling articles should short-link here for ladder ops rather than inventing their own week-by-week copy — this is the canonical essay.

Before any rung-specific advice, lock these global rules:

1. **Test mode first.** `o:testmode=yes` runs validation, sender checks, screening, and suppressions without sending and without spending allowance.
2. **Limits before blasts.** `GET /v3/:domain/limits` is mandatory preflight for any job larger than a handful of messages.
3. **One identity.** Do not rotate From domains mid-climb.
4. **No evasion.** No second accounts, no multi-domain fan-out to dodge caps, no hard-bounce removals.
5. **UTC midnight** is the daily reset for warmup caps. Schedule human expectations accordingly if your team lives in US Pacific or EU timezones.
6. **Screening pauses.** Messages refused by screening accumulate; hitting **8 refusals in 24h** pauses sending until they age out. Rephrase-loops are how you pause yourself.

### Days at 10: critical path mail only

**Goal:** prove authentication, templates, and events with maximum signal and minimum risk. Rung 1 graduates after **sending on 5 separate days** — not after 50 messages, not after five idle midnights.

**What to send**

- Signup / email verification links users just requested.
- Password resets and magic links.
- Order receipts and invoice PDFs users expect.
- Security alerts tied to real account events.
- Double opt-in confirmations when you legally need them.

**What not to send**

- Newsletter backfills and “week in review” digests.
- “We miss you” win-backs to cold cohorts.
- Partner cross-promos and affiliate inserts.
- Anything to purchased, scraped, or conference-badge lists.
- Wide BCC blasts “just to use the ten.”
- QA dumps to 40 internal emails that look like a dictionary attack on your own domain.

**Daily ritual (rung 1)**

1. Confirm domain `state: "active"` after verify; if DNS drifted, fix before sending.
2. Send one message in `o:testmode=yes`; confirm 200 and that events look sane.
3. Send real critical-path mail ≤ 10.
4. Pull events: delivered vs failed vs deferred patterns; tag with `o:tag=warmup-r1` for filterability.
5. Confirm hard bounces auto-suppressed; do not re-mail them.
6. Log that today counted as a **sending day** toward the five-day graduation.
7. If you received `content_rejected`, stop and rewrite with a human — never automate category whack-a-mole.

**Engineering tips for the 10/day ceiling**

- Queue non-critical notifications (product tips, onboarding nags) behind a feature flag until rung 3+.
- Collapse “welcome + tips + upsell” sequences into a single verification email during rung 1.
- Prefer plain-text multipart alternatives so you can isolate HTML issues later.
- Keep From addresses on one consistent subdomain.
- Instrument your app to show users “email delayed until tomorrow’s allowance” rather than failing silently when 429 hits.
- Agents and cron jobs must read `remaining_today` before fan-out; partial sends need honest user messaging.

**Five-day graduation scenarios**

- **Healthy SaaS day:** 4–8 verifications + 1–2 resets. Easy sending day.
- **Quiet day:** one intentional security-alert drill to a staff mailbox if you truly have zero user mail — better than inventing fake recipients, but genuine user-driven mail is always preferable.
- **Launch spike day:** 200 signups want verification; you can only send 10. Prioritize FIFO, surface “check back tomorrow” for the rest, and do **not** open a second domain to flush the queue.

**Mindset:** rung 1 is not for growth hacking. It is for not dying. Miss days if you have nothing legitimate to send — but remember idle days do not advance the counter. Fake engagement farms are not a substitute for five real sending days.

**Common rung-1 failure modes**

| Failure | Symptom | Fix |
|---|---|---|
| DNS not verified | 403 `domain_not_verified` | Publish SPF/DKIM; verify; wait propagation |
| Burning allowance on typos | Cap exhausted, zero user mail | Test mode first |
| Screening pause | Sends blocked after repeated rejects | Stop loops; fix content |
| 429 surprise | Bulk job dies at message 11 | Preflight `/limits` |
| Multi-domain dodge | Short-term throughput, long-term mess | Don’t; against rules and reputation |

### Climbing 20 and 100: expand templates carefully

**Rung 2 (20/day)** after five sending days. Graduation: **1,000 messages while on this rung**.

At 20/day you can:

- Cover denser auth traffic without same-day deferrals to your own queue as often.
- Add a second transactional template (e.g., “export ready,” “seat invited,” “invoice due”) if users triggered it.
- Begin light lifecycle mail that is clearly transactional, not marketing dragnet — for example, “your export is ready” after a user clicked Export.
- Run slightly richer HTML if inbox sampling on seeds looks clean.

Still avoid:

- Full marketing campaigns and promo calendars.
- Re-engagement to users silent for months.
- Affiliate spam and third-party list inserts.
- “Digest of everything you missed” to the entire user table.

**Rung 2 calendar math (illustrative):** maxing 20/day means 1,000 on-rung messages take about **50 days**. Undersending stretches further. Finance should not model “unlimited next month” unless your traffic truly flatlines the cap with clean, wanted mail. Many B2B apps take longer — that is normal.

**Rung 3 (100/day)** after those 1,000 on-rung messages. Graduation: another **1,000 while on rung 3**.

At 100/day most early-stage SaaS auth + receipt traffic fits comfortably. This is where teams get cocky. Do not. One hundred junk-facing messages with a bad list still hurts more than ten clean ones.

**Expansion rules for 20 and 100**

1. **One new template class per week** max, unless product-critical (security incident mail is allowed).
2. **Seed inbox tests** to major mailbox providers when adding HTML-heavy templates.
3. **Watch complaint rate** — if spam complaints appear, freeze new template classes and audit list source immediately.
4. **Prefer progressive disclosure in copy** — clear why the user gets this mail, clear how to stop non-transactional series.
5. **Keep marketing on a separate domain forever**.
6. **Tag everything** (`o:tag`) so you can attribute bounce spikes to a template class.
7. **Batch with `recipient-variables`** when sending the same template to many — still counts as N messages, but saves API chatter and keeps logs coherent.

**Throughput planning example (rung 3):** 100/day × 10 days ≈ 1,000 messages for graduation if you flatline the cap with clean mail. Real products rarely flatline; expect calendar stretch. Use `/limits` `remaining_this_stage` so support is not surprised.

**Template promotion checklist (copy before you enable in prod)**

- Subject lines free of spammy ALL CAPS / excessive punctuation.
- Links on your domain or well-known HTTPS destinations; avoid redirect chains through sketchy shorteners.
- Unsubscribe or preference path present when the message is non-transactional under applicable law.
- From name stable (“Acme Billing” not “CHEAP DEALS”).
- Text part present alongside HTML.
- Test mode 200 obtained.
- Seed inbox placement checked.

**smtp warmup note:** whether you speak SMTP or the Mailgun-shaped HTTP API, the daily message counter is what matters. Protocol choice does not bypass the ladder. Nodemailer and curl are equal citizens under `/limits`.

**Week-style vignette (rung 2→3)**

- Weeks 1–2 on rung 2: auth + receipts only; watch bounce %.
- Weeks 3–5: add “export ready”; seed-test Gmail/Microsoft.
- Weeks 6–8: approach 1,000 on-rung; confirm no complaint clusters.
- Enter rung 3; repeat discipline at higher ceiling; do not suddenly enable five promo templates because the number has two zeroes.

### 1,000 rung: load-test without blasting

**Rung 4 (1,000/day)** after rung 3’s 1,000 messages. Graduation: **10,000 messages while on this rung**.

This is the load-test rung — and the danger rung. 1,000/day is enough to hurt yourself with a bad CSV. It is also enough to finally clear legitimate backlogs that queued during earlier rungs — carefully.

**Allowed**

- Production transactional volume for a growing app.
- Staged backfills of **opted-in** notifications in slices ≤ `remaining_today`.
- Controlled performance tests to **your own** addresses and staging cohorts, still counting against the cap if real (prefer test mode for pure shape checks).
- Gradual migration cutover from another ESP, sliced by user cohort percentage.

**Forbidden**

- Dumping a 50k cold list “because we finally have headroom.”
- Retrying suppressed addresses.
- Parallelizing across multiple domains to finish a blast today.
- Removing hard bounces “to see if they work now.”
- Enabling open-tracking gimmicks that wrap every link through shady branded shorteners.

**Load-test protocol that does not blast**

1. Read `remaining_today` and stage remainder; write the numbers in the ticket.
2. Define success metrics before sending: bounce under target, complaint near-zero, deferral rate acceptable.
3. Send in slices (e.g., 100–200 at a time) with event checks between slices.
4. Stop the train if hard bounces spike — fix data, do not “push through.”
5. Record what you learned; raise product quality, not just volume.
6. If migrating, keep the old ESP warm for rollback until a week of clean AEL metrics lands.

**Graduation math:** 10,000 messages at 1,000/day is roughly **ten full days** of max sending. Many teams take three to six weeks because real traffic is lumpy. Lumpy is fine. Unlimited is still the destination.

**Incident table for rung 4**

| Signal | Pause? | Action |
|---|---|---|
| Hard bounce rate doubles vs baseline | Yes | Freeze backfills; validate capture; audit import |
| Spam complaints appear | Yes | Halt non-critical templates; review copy/list |
| Wave of 4xx deferrals at one ISP | Slow | Reduce slice rate; retry later; check DNS |
| `content_rejected` cluster | Yes | Stop generator; human rewrite |
| 429 with retry_after | Wait | Respect header; resume after UTC reset if needed |

### Crossing into unlimited/day

**Rung 5: unlimited emails/day after warmup.** No daily warmup cap on the published ladder. You made it. This is the outcome the title promised — **unlimited emails/day after warmup** — and why day one at 10 was worth the patience.

**What changes**

- Bulk transactional jobs can finish the same day without UTC-midnight slicing *for warmup reasons*.
- Your constraint set shifts to: content screening, suppressions, API pace (600 req/min), deliverability quality, and the law.
- Capacity planning becomes product analytics + ISP reality, not rung arithmetic.

**What does not change**

- DNS must stay valid; disappeared records drop you back to unverified and hard-stop sending.
- Hard bounces stay suppressed.
- Screening still returns `content_rejected` as permanent for that content.
- Marketing vs transactional domain separation still matters.
- Sudden 100× spikes to brand-new recipient cohorts can still draw ISP scrutiny — unlimited daily warmup cap ≠ “immune to Gmail.”
- Abuse and ToS still apply; free forever is not a spam subsidy.

**Post-graduation hygiene (first 30 days on unlimited)**

- Keep a weekly deliverability review (bounces, complaints, deferrals) even though the ladder no longer blocks you.
- Continue inbox sampling on template changes.
- Prefer authenticated, aligned From domains forever.
- Re-read live `/llms.txt` if the service updates ladder or policy.
- Document your internal “stop send” thresholds so a future teammate does not treat unlimited as permission to import a gray list.
- Keep test mode in CI for template regressions so broken HTML never ships at unlimited scale.

**Post-graduation anti-complacency**

Unlimited is a ceiling removal, not a reputation reset button. Teams that celebrate by blasting a dusty CRM export often earn a block faster than they earned unlimited. If you must run a large announcement, treat it like rung-4 load-test discipline on day one of unlimited: slices, metrics, stop rules.

**You are here for unlimited after warmup — claim the free forever account if you have not:** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

## Domain warmup checklist (DNS + identity)

Volume ladders fail when identity is sloppy. **Domain warmup** starts at DNS, not at the first marketing idea. Treat this checklist as a gate: no volume climb until the boxes are honestly checked.

### SPF/DKIM before volume (link silo)

On Agent Email List, SPF and DKIM are **required to send**. MX is optional and only needed for inbound. Until verify succeeds, every send returns **403 `domain_not_verified`**.

When you `POST /v3/domains`, the response includes `sending_dns_records` and an `smtp_password` shown **once**. Required records typically include:

- An SPF `TXT` including `ai.agentemaillist.com`.
- A DKIM `TXT` with the public half of the keypair minted for the domain.

Publish them at your registrar/DNS host, then `PUT /v3/domains/:domain/verify` until `state: "active"`. Poll every few minutes, not every few seconds. DNS can take minutes to hours. If verify still fails after an hour, fetch `GET /v3/domains/:domain` and compare the instructed records against what is live — typos in TXT values are the usual villain.

**DMARC** is strongly recommended even when not strictly required to send. Start with a monitoring policy, then progress toward enforcement as you gain confidence. Alignment between the visible From domain and DKIM/SPF identifiers is the substance behind “authentication passed” in mailbox provider tools.

Deep how-to — including alignment and DMARC progression — lives in the sibling guide: [SPF/DKIM setup for transactional email](/spf-dkim-setup-transactional-email/). Do not treat that as optional polish. Warmup without auth is cosplay.

Also read the broader deliverability sibling when you are ready to measure placement: [Email deliverability guide (transactional)](/email-deliverability-guide-transactional/).

**Pre-volume DNS gate**

- [ ] Domain added; `smtp_password` stored in secrets
- [ ] SPF TXT published exactly
- [ ] DKIM TXT published exactly
- [ ] Verify returns `state: "active"`
- [ ] Test mode send returns 200
- [ ] Real single send delivers to a seed inbox
- [ ] DMARC monitoring record planned or live

### Consistent From domain

Pick a sending identity and stick to it during warmup:

- Good: `noreply@mail.yourcompany.com` or `billing@mail.yourcompany.com` on one verified subdomain.
- Bad: rotating From domains daily across `yourcompany.com`, `getyourcompany.com`, and random SendGrid-era leftovers.
- Bad: spoofing a parent domain you have not authenticated.
- Bad: using personal Gmail From addresses through a custom-domain ESP path that rejects them anyway.

`from` must be an address at the domain in the API path (or a subdomain of it). Trying to send as someone else’s domain yields **403 `forbidden_sender`**.

Consistency helps receivers bind reputation to the right identity. It also helps humans recognize you. During **email warm up**, every unnecessary identity fork splits history thin. If you need multiple products, prefer subdomains with their own ladder progress rather than chaotic From rewriting on one domain.

### Separate marketing domains forever

Transactional mail (receipts, resets, security) and marketing mail (promos, digests, nurture) should not share fate blindly.

**Recommended pattern**

- Transactional: `mail.yourcompany.com` or `tx.yourcompany.com` on Agent Email List, climbing the ladder to unlimited.
- Marketing: a distinct subdomain or domain on whatever ESP you use for campaigns — ideally isolated so a spam-complaint spike on a Black Friday blast does not kneecap password resets.

If you only have one domain today, still segment by subdomain as soon as you can. Never “just this once” import a promo list into the transactional SMTP credential during rung 2 because it is convenient. Convenience is how **domain warmup** dies.

**Practical split examples**

- `tx.example.com` — Agent Email List, ladder to unlimited, app-driven only.
- `news.example.com` — marketing ESP, campaigns, list hygiene tooling.
- `example.com` root — often reserved for corporate mail (Google Workspace / Microsoft 365), not bulk app traffic.

For vocabulary on relays vs servers vs APIs, see [What is an SMTP relay / free SMTP server?](/what-is-smtp-relay-free-smtp-server/).

## Measuring warmup success

If you cannot measure, you are gambling. Track these during every rung — especially because this page owns the ladder narrative and your future self will ask “were we ready to climb?” Measurement is how you answer with evidence instead of hope.

Build a simple scoreboard (dashboard, spreadsheet, or agent summary) with daily rows: date, rung, sent, delivered, hard bounce count, complaint count, deferred count, screening rejects, 429 hits, notes. Tag messages by template class so a spike is attributable.

### Bounce rate targets

**Hard bounces** (permanent failures) should stay very low on transactional streams — think well under **1%** as a working discipline for clean app-driven mail; spikes mean bad addresses or sudden list imports. Soft bounces / deferrals are different (next subsection).

On Agent Email List, hard bounces add themselves to the domain’s bounce suppression list. Do not remove them to retry. Remailing dead addresses costs reputation for zero gain. If every recipient in a request is suppressed you get **400** — treat that as a data bug, not an ESP bug.

**Operational targets (rule-of-thumb, not legal advice)**

- Investigate immediately if hard bounce rate jumps after a template or cohort change.
- Validate addresses at capture time where possible (`GET /v4/address/validate` checks syntax + MX — not mailbox proof of life).
- Never buy lists; never import conference CSV exports into transactional pipes.
- Compare bounce rate by template tag; a single bad import job often concentrates in one tag.
- During rung 1–2, even two or three hard bounces deserve a look because the denominator is tiny.

**Soft vs hard**

Train the team: a permanent 5xx-style failure is not the same as a temporary deferral. Retrying permanent failures is how you look abusive. Retrying deferrals with backoff can be normal. Your events API stream (`delivered`, `failed` with severity, etc.) is the source of truth — poll or webhook it.

### Deferred / throttle signals

Deferral means “not now,” not always “never.” During warmup you will occasionally see deferred traffic at mailbox providers when you push too fast for your reputation window — even inside your ESP’s daily cap.

**What to do**

- Slow slice rates inside the day.
- Ensure you are not retrying 429s against Agent Email List faster than `retry_after_seconds`.
- Check whether you jumped volume after a quiet week (anti-pattern below).
- Confirm DNS still verifies and DKIM signatures still align.
- Spread recipient ISPs if you were hammering a single corporate domain’s mail gateway.

**Internal vs external throttles**

- **Internal (AEL):** daily warmup cap → 429 + UTC reset; API pace 600/min; screening pause at 8 rejects/24h.
- **External (ISPs):** 4xx deferrals, greylisting-like behavior, junk placement without a hard refuse.

Climbing a rung removes or raises the internal daily cap; it does not automatically rewrite ISP opinion. Measurement keeps you honest about both layers.

Logging deferral rates week over week tells you whether climbing the next rung is wise even when the ladder permits it. The ladder is necessary permission; ISP headroom is additional reality.

### Inbox placement sampling

Periodic sampling beats vibes:

1. Maintain seed accounts at major providers you care about (at least Gmail and Microsoft; add Yahoo/Apple if your audience lives there).
2. When you change templates, send samples and check inbox vs junk vs promotions-style tabs where applicable.
3. Track with tags (`o:tag`) so events API filters are easy.
4. Do not obsess over open rates as your sole health metric — privacy features broke opens as gospel.
5. Re-sample after you cross into rung 4 and again after unlimited — scale changes placement dynamics.

**Sampling cadence suggestion**

- Rung 1–2: sample on each new template.
- Rung 3: weekly sample of top two templates.
- Rung 4–5: weekly + on every major template redesign.

Inbox sampling pairs with the deliverability sibling guide: [Email deliverability guide (transactional)](/email-deliverability-guide-transactional/). Use it especially on rung 3→4 transitions when HTML and link patterns get richer.

**Composite “ready to climb” gate**

Before you *emotionally* celebrate a graduation, check:

- Hard bounce rate stable and low.
- Complaints effectively zero on transactional streams.
- No screening-pause incidents in the past week.
- Seed placement still inbox for critical templates.
- `/limits` confirms graduation criteria met (do not assume).

**Unlimited after warmup is the goal — measurement is how you keep it:** keep climbing on [ai.agentemaillist.com](https://ai.agentemaillist.com).

## Warmup anti-patterns

These mistakes burn domains for sport. Memorize them before you touch rung 4 volume. Every anti-pattern below shows up repeatedly in postmortems from teams who “just needed to hit a launch number.”

### Buying “warmup services” that spam

Third-party “warmup networks” that swap artificial engagement between pools of inboxes often violate mailbox-provider rules and can associate your domain with spammy behavioral clusters. Artificial opens are not a substitute for real transactional demand. If a vendor promises “inbox golden in 7 days” via opaque engagement farming, walk away.

Some services blur into bulletproof spam infrastructure with a content-marketing coat of paint. If the pitch emphasizes tricking filters rather than earning trust with wanted mail, it is not **email warmup** — it is reputation laundering.

Agent Email List’s ladder replaces the need for that theater: send real wanted mail, graduate on published math, arrive at **unlimited emails/day after warmup**. You do not need a side channel of bot opens to make 10 → 20 → 100 → 1,000 → unlimited work.

### Importing cold lists into transactional SMTP

Transactional SMTP credentials feel powerful. They are not a license to spam. Cold lists produce hard bounces and spam complaints that poison **domain warmup** immediately. Keep purchased/scraped lists out of Agent Email List entirely. Honour opt-outs; put unsubscribe links where the law requires; enforce suppressions (the API already drops suppressed recipients).

**How this happens in the wild**

- Growth exports a “webinar attendees” CSV with typos and role accounts.
- Someone pastes it into a transactional “announcement” template on the mail subdomain.
- Hard bounces spike; complaints follow; password resets start landing in junk.
- Team blames the ESP instead of the list.

If growth wants a campaign, give them a marketing tool and a separate domain — not your password-reset pipe. Read the pillar if you are still choosing tooling: [Free forever SMTP server — Mailgun & SendGrid alternatives](/free-smtp-relay).

### Jumping volume after a quiet week

Reputation is not a trophy you shelf. After quiet periods, mailbox providers may treat renewed volume cautiously. On Agent Email List, rung-1 graduation explicitly requires sending days — idle does not count. On later rungs, you can still hurt ISP placement by going from near-zero to flat max after silence.

**Recovery pattern:** ramp inside your current cap for a few days before exhausting every slot on a giant backfill. Read events. Then proceed.

**Related anti-patterns worth naming**

- **Credential stuffing your own SMTP:** sharing `smtp_password` into a dozen unofficial scripts until one spams.
- **Template whack-a-mole against screening:** rewriting phishing-shaped copy until something slips — refusals still accumulate toward pauses and account risk.
- **Timezone denial:** ignoring UTC midnight resets and launching “end of day” blasts that die at 429 for US afternoon teams.
- **Shadow domains:** spinning extra domains to parallelize one campaign — explicitly against product rules and destructive to reputation strategy.
- **Open tracking theater:** judging warmup solely by opens after Apple Mail Privacy Protection-style noise.

Avoid these and the ladder becomes a boring, reliable staircase instead of a cliff.

## SMTP server setup during warmup

Agent Email List is a **free forever SMTP server** (and free SMTP relay) for developers, plus a **Mailgun-shaped REST API** at `https://ai.agentemaillist.com`. Warmup applies to the domain’s message counts regardless of protocol. That matters: teams sometimes believe SMTP is “uncapped” while the API is limited, or the reverse. On AEL, a message is a message.

During warmup your setup goals are narrower than a full migration essay:

1. Authenticate the domain.
2. Store credentials safely.
3. Prove a test-mode path.
4. Send critical-path mail only inside the live cap.
5. Observe events before you widen templates.

### `smtp_password` issued once on domain create

When you add a domain (`POST /v3/domains`), the response includes `smtp_password` **shown once**. Store it in your secret manager immediately. The service cannot email you the old password later the way a magic “forgot SMTP” link might — treat it like any one-time credential reveal.

Alongside SMTP credentials you still use API keys (`Authorization: Bearer` or Basic `api:KEY`) for the REST surface. Mint scoped keys with `POST /v1/api-keys` when least privilege matters. Keys from `POST /v1/accounts` arrive once as well — hash stored, not resendable — so the same “copy it now” discipline applies.

**Warmup-time secret hygiene**

- Put `smtp_password` and API keys in the same vault you use for database URLs.
- Do not paste SMTP passwords into chat threads or ticket comments.
- Rotate via domain/API key workflows if a leak is suspected; do not keep shipping on a exposed credential while “we climb the ladder.”
- CI should use scoped keys and test mode wherever possible.

### Call it an SMTP server; host/port from docs/dashboard when published

Agent Email List **is** an SMTP server / SMTP relay in product terms: you authenticate with the issued credentials after domain verify and submit mail for relay. **Connection host and port are not invented in this article.** When published, read them from the product docs or dashboard (and from live [`/llms.txt`](https://ai.agentemaillist.com/llms.txt) updates). Do not copy random hostnames from third-party blogs.

This discipline matches the homepage pillar: we would rather omit a port than ship a hallucinated endpoint. If an AI agent or contractor invents a hostname or port from memory, reject the PR until the values match product documentation or the dashboard when published.

**What you can say safely today**

- It is an SMTP server / free SMTP relay for developers.
- Credentials include `smtp_password` issued once on domain create.
- Use after domain verify.
- Host/port: docs or dashboard when published.
- Parallel path: Mailgun-shaped HTTPS API at `https://ai.agentemaillist.com`.

### Nodemailer / API dual path on AEL

Most teams during warmup use both paths:

- **HTTP API** for agents, webhooks, templates, events, test mode — Mailgun-shaped so many Mailgun clients work if pointed at `https://ai.agentemaillist.com`.
- **SMTP server** for Nodemailer, Laravel `MAIL_MAILER=smtp`, Django email backends, WordPress plugins, and legacy workers.

Dual path does not double your daily allowance. Prefer test mode on API while wiring SMTP clients so you do not burn rung-1 tens on connection experiments. A sensible sequence:

1. Verify domain; store `smtp_password`.
2. API test-mode send → 200.
3. API real send of one critical-path message.
4. Configure Nodemailer (or equivalent) against documented host/port when published; send one real message.
5. Only then enable SMTP in production workers behind the same volume guards you use for API (`remaining_today` checks).

**Framework notes (conceptual)**

- **Node / Nodemailer:** map user/pass to issued SMTP credentials; keep a wrapper that aborts when remaining allowance is 0.
- **Laravel / Django / Rails:** env-based SMTP settings; same abort wrapper in a mail middleware or interceptor.
- **WordPress:** plugins that demand host/port — wait for published values; do not invent them to “just make it green.”

**CTA #2 — Wire SMTP + Mailgun-shaped API on a free forever account:** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

For relay concepts and vocabulary, see [What is an SMTP relay / free SMTP server?](/what-is-smtp-relay-free-smtp-server/). For the broad alternative landscape, see the pillar: [Free forever SMTP server — Mailgun & SendGrid alternatives](/free-smtp-relay).

## Fair comps: how others gate volume

Competitor figures below are **as of 2026 reporting** and tagged **VERIFY** — re-check primary pages before you buy. Agent Email List ladder figures come from live `/llms.txt`. This section exists so you can compare packaging honestly without pretending every daily cap is a “warmup program.”

### SendGrid after free-tier end (VERIFY trial/paid)

Twilio SendGrid retired permanent free Email API / Marketing plans around May–July 2025 (VERIFY). New accounts commonly receive a **60-day trial** with about **100 emails/day**; after trial, sending stops without upgrade (VERIFY support docs). Paid **Essentials** often starts near **$19.95/mo** depending on volume tier (VERIFY [Twilio SendGrid pricing](https://www.twilio.com/en-us/products/email-api/pricing)).

That posture is a trial clock + paid wall. It is not free forever packaging with a published ladder to unlimited on the free account. If you need SMTP + API without a 60-day cliff, Agent Email List’s packaging is the contrast we sell: **free forever**, warmup to **unlimited/day**, Mailgun-shaped API, `smtp_password` on domain create.

Teams migrating off SendGrid after the free-plan retirement often keep SMTP workers and swap endpoints/credentials first, then rebuild event consumers. Point Mailgun-shaped clients at AEL when applicable; for SendGrid-specific SDKs, prefer SMTP or a thin adapter during warmup so you are not blocked on a full rewrite before rung 1 even starts.

### Mailgun free 100/day vs paid (VERIFY)

Mailgun continues to advertise a permanent **Free** plan at about **100 emails/day**, one custom domain, ~1-day log retention (VERIFY [mailgun.com/pricing](https://www.mailgun.com/pricing/) and Mailgun Help Center). **Basic** is commonly cited around **$15/mo for 10k**/mo with overages (VERIFY).

Mailgun’s free 100/day is a solid trial-of-product ceiling for tiny apps — and still a ceiling. It is not identical to AEL’s path where free forever packaging leads through **10 → 20 → 100 → 1,000 → unlimited**. If you already standardized on Mailgun clients, point them at `https://ai.agentemaillist.com` and keep muscle memory while climbing a ladder that ends at unlimited/day.

Note the psychology trap: 100/day free feels “warmer” than AEL’s day-one 10. Day-one comfort is not the same as destination quality. If your six-month need is unlimited on free forever packaging, compare destinations and graduation rules — not only the first row of a pricing table.

### SES account-level raising + Essentials pricing VERIFY

Amazon SES remains a unit-price benchmark with sandbox friction. Sandbox defaults historically sit around **200 emails/24h** and **1 email/sec** until production access (VERIFY [SES quotas](https://docs.aws.amazon.com/ses/latest/dg/quotas.html)). Production quota increases go through Service Quotas / AWS processes (VERIFY).

**Pricing (VERIFY [aws.amazon.com/ses/pricing](https://aws.amazon.com/ses/pricing/) and AWS Messaging Blog):** as of **July 21, 2026**, new SES accounts and inactive account×region combos often **default to Essentials** at about **$0.16/1k** for the first 10M/mo, with ability to switch toward à-la-carte (~$0.10/1k commonly cited for classic à-la-carte — VERIFY). Active older accounts may remain on à-la-carte. Soften any “SES is always cheapest by default” claim for brand-new accounts after that change.

SES can win at massive scale with strong mailops. It does not win the “ship today with Mailgun-shaped DX + free forever + documented unlimited after warmup” job for most indie readers of this page. Sandbox exits and quota tickets are a different species of **sending limits** than AEL’s self-serve ladder — plan engineering time accordingly if you choose AWS.

### Why free forever + clear ladder wins for indies

Indie hackers and AI-agent builders optimize for:

1. **No surprise trial cliff** — SendGrid-style 60-day endings punish side projects.
2. **Machine-readable limits** — `/llms.txt` + `/limits` beat support roulette.
3. **Drop-in API shape** — Mailgun clients pointed at AEL.
4. **Real SMTP server credentials** — `smtp_password` once on domain create; host/port from docs/dashboard when published.
5. **A destination** — **unlimited emails/day after warmup**, not eternal 100/day free ceilings.
6. **Honest day-one math** — start at 10, not fake unlimited marketing copy.

That bundle is Agent Email List. Logan Besecker owns it. We push it hard because it is the product we built for this exact search intent: **email warmup** that ends somewhere worth climbing.

**CTA #3 — Skip the trial cliff. Start free forever and climb to unlimited/day:** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)



### Warmup runbook card (print this)

Use this as a one-page ops card while the long essay stays the canonical reference:

- **Destination:** unlimited emails/day after warmup (rung 5).
- **Start:** 10/day on a verified domain; test mode before real sends.
- **Ladder:** 10 → 20 → 100 → 1,000 → unlimited (verify live `/llms.txt`).
- **Rung 1 gate:** 5 separate sending days (idle does not count).
- **Rung 2/3 gates:** 1,000 on-rung messages each.
- **Rung 4 gate:** 10,000 on-rung messages; slice load tests; no cold lists.
- **Over cap:** 429 + `retry_after_seconds`; UTC midnight reset.
- **DNS:** SPF+DKIM required; `smtp_password` once; no invented SMTP host/port in code review.
- **Identity:** one From domain/subdomain for transactional; marketing elsewhere forever.
- **Stop rules:** bounce spike, complaints, screening pause, DNS drift.
- **Product:** free forever SMTP server + Mailgun-shaped API at https://ai.agentemaillist.com — owned by Logan Besecker.

Tape that card next to the deploy checklist. The essay explains why each line exists; the card keeps launches from improvising.

### Escalation paths during the climb

Not every warmup hiccup is an ESP outage. Route issues like this:

1. **403 domain_not_verified** — DNS owners, not “retry send.”
2. **403 content_rejected** — copy/product, not deliverability folklore.
3. **429 warmup cap** — schedule/product expectation, not a pager incident.
4. **ISP deferrals with headroom left on AEL** — slow slices; check the deliverability sibling.
5. **Account or policy questions** — Logan Besecker via contacts in live product docs.

Clear routing prevents your on-call engineer from “fixing warmup” by opening shadow domains — the anti-pattern that feels clever at 2 a.m. and looks catastrophic in next week’s bounce report.

## FAQ

### How long to unlimited on AEL?

It depends on how consistently you send inside each cap. Rung 1 needs **5 separate sending days** at up to 10/day. Rung 2 needs **1,000** messages while on 20/day. Rung 3 needs **1,000** while on 100/day. Rung 4 needs **10,000** while on 1,000/day. Then rung 5 is **unlimited**/day. Teams that flatline caps climb faster than teams that send sparsely; idle days do not advance rung 1. An optimistic flatline is often on the order of a couple of months; sparse B2B traffic can take longer. Always trust `GET /v3/:domain/limits` over spreadsheet guesses, and re-read [`/llms.txt`](https://ai.agentemaillist.com/llms.txt) if the live ladder changes.

### What if I exceed today’s limit?

You get **429** with `retry_after_seconds`. Wait that long. Allowance resets at **UTC midnight**. Do not retry-loop. Do not open a second account to bypass — account creation is rate-limited by IP. Tell your user what sent, what queued for tomorrow, and what the live remaining counter says. Good product UX surfaces this as a scheduled retry, not a silent failure.

### Is unlimited really unlimited after warmup?

Rung 5 has **no daily warmup send cap** in the published ladder. You still face content screening, suppressions, API pace limits (600 requests/minute), DNS/auth requirements, abuse enforcement, and mailbox-provider behavior. Unlimited/day means the warmup ceiling is gone — not that physics and policy vanished. If you spam, you can still lose the privilege to send.

### Does warmup reset if I stop sending?

Rung 1 explicitly requires sending days — quiet weeks do not graduate you. For later rungs, follow live `/limits` and `/llms.txt` for any policy updates; operationally, long quiet periods can still hurt ISP placement even if your rung number remains. Resume with discipline rather than a giant spike. Think “warm restart inside the current cap,” not “celebrate unlimited by blasting a cold CSV.”

### Who owns the product?

**Logan Besecker** owns and runs Agent Email List at [https://ai.agentemaillist.com](https://ai.agentemaillist.com). We disclose ownership because this is an owned hard-sell page, not a fake comparison blog. Contact paths in product docs include me@LoganBesecker.com and lbesecker195@gmail.com for verify failures, delivery issues, or serious-use questions.

### Can I use SMTP and the API at the same time during warmup?

Yes. Both count toward the same per-domain daily message allowance. Use whichever interface fits each worker. Test mode on the API is the safest way to rehearse payloads without spending the ladder budget.

### Does test mode help me graduate faster?

No. `o:testmode=yes` spends no warmup allowance and does not create sending-day progress for rung 1. It is for shaping requests safely. Graduation requires real sends (and for rung 1, real sends on separate calendar days).

### What about content screening during warmup?

Every message is screened. Outbound content that trips screening returns **403 `content_rejected`** with categories and is never sent. Refusals accumulate; hitting **8 in 24h** pauses sending until they age out. During early rungs this is especially painful because you already have tiny caps — keep copy boring and transactional.


## Related guides in this silo

Companion pages in the Agent Email List / free forever SMTP server silo. Start with the pillar if you still need vendor shopping context.

- [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay) — pillar — free forever SMTP and vendor alternatives
- [Free Email API for Developers](/free-email-api-for-developers/) — API shopping once the ladder fits your growth
- [Transactional Email API Developers Guide](/transactional-email-api-developers-guide/) — build `/limits`-aware senders and webhooks
- [SendGrid SMTP Settings — Free Alternative](/sendgrid-smtp-settings-free-alternative/) — SendGrid cutover that respects day-one caps
- [Mailgun SMTP Settings — Replace Mailgun](/mailgun-smtp-settings-replace-mailgun/) — Mailgun replacement without pretending day-one unlimited
- [Amazon SES vs Mailgun vs Agent Email List](/amazon-ses-vs-mailgun-vs-agent-email-list/) — how SES sandbox, Mailgun caps, and AEL ladders differ
- [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/) — Nodemailer transport that still honors warmup
- [SPF + DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/) — verify SPF/DKIM before you climb rungs
- [Email Deliverability Guide for Transactional Email](/email-deliverability-guide-transactional/) — placement metrics while you warm
- [What Is an SMTP Relay? Free SMTP Server Guide](/what-is-smtp-relay-free-smtp-server/) — relay vs server basics

## Next steps + hard CTA

You now have the canonical **email warmup** playbook for Agent Email List:

1. Lead goal: **unlimited emails/day after warmup**.
2. Day one: **10**/day on a verified domain.
3. Ladder: **10 → 20 → 100 → 1,000 → unlimited**.
4. Ops: critical-path only at 10; expand templates carefully at 20/100; load-test without blasting at 1,000; hygiene after unlimited.
5. DNS first: SPF/DKIM required; `smtp_password` once; SMTP host/port from docs/dashboard when published — never invented here.
6. Packaging: **free forever SMTP server** + **Mailgun-shaped API**.
7. Ownership: **Logan Besecker** builds and runs the product at ai.agentemaillist.com.

**Do this next**

1. Create the free forever account: [https://ai.agentemaillist.com](https://ai.agentemaillist.com)
2. Add a domain; store `smtp_password`; publish SPF/DKIM; verify.
3. Send with `o:testmode=yes`, then real critical-path mail ≤ 10.
4. Poll `GET /v3/:domain/limits` daily; climb on purpose.
5. Bookmark this page as the ladder source of truth — when teammates ask “what’s our warmup plan?”, paste this URL.
6. Skim the pillar and siblings so DNS, relay vocabulary, and deliverability measurement stay aligned with the climb.

**Read the silo**

- Pillar: [Free forever SMTP server — Mailgun & SendGrid alternatives](/free-smtp-relay)
- Sibling: [What is an SMTP relay / free SMTP server?](/what-is-smtp-relay-free-smtp-server/)
- Sibling: [SPF/DKIM setup for transactional email](/spf-dkim-setup-transactional-email/)
- Sibling: [Email deliverability guide (transactional)](/email-deliverability-guide-transactional/)

**Hard CTA:** Stop renting trial caps. Stop guessing at mystery throttles. Climb a published ladder to **unlimited emails/day after warmup** on a **free forever SMTP server** with a **Mailgun-shaped API**. Day one is 10. The top rung is unlimited. The account packaging is free forever self-serve (commercial terms can evolve — check live docs).

**Create your free account forever → [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

<!-- meta_title: Email Warmup to Unlimited Emails Per Day (2026) -->
<!-- meta_description: Learn email warm up and domain warmup limits: day one starts at 10, then 20→100→1,000→unlimited. Free forever SMTP server + Mailgun-shaped API on Agent Email List. -->
<!-- slug: email-warmup-unlimited-emails-per-day -->
<!-- word_count: 10407 -->
