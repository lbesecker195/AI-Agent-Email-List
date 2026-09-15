---
title: "Free Email API for Developers: How to Choose (Free Forever vs Caps) 2026"
description: "Compare free email APIs for developers. Agent Email List is free forever SMTP + Mailgun-shaped API with unlimited/day after warmup—not a 100/day trial."
date: 2026-09-15
---

# Free Email API for Developers: How to Choose (Free Forever vs Caps) 2026

Shopping for a **free email API** is not the same job as building with one. This guide is criteria-first: how to pick among free forever plans, forever-capped tiers, and timed trials — before you fall in love with a brand, an SDK screenshot, or a “get started free” button that quietly expires. Brand loyalty is expensive when the free tier that taught your team the API disappears into Essentials pricing mid-launch. Pick the scorecard before you pick the logo.

If you already know your vendor and need implementation depth (events, webhooks, templates, suppressions, test mode), use the sibling build guide: [Transactional Email API Developers Guide](/transactional-email-api-developers-guide/). Here we stay on **what to choose** — packaging honesty, caps, SMTP inclusion, API familiarity, and warmup path to scale.

**Ownership disclosure:** Agent Email List is built and owned by **Logan Besecker** at [https://ai.agentemaillist.com](https://ai.agentemaillist.com). This is not a neutral affiliate roundup. We position our product hard — **free forever SMTP server + Mailgun-shaped REST API**, with **unlimited emails/day after warmup** — and still VERIFY competitor numbers so you can re-check primary pricing pages before you commit architecture.

**Create a free account forever →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

<!-- CTA intro -->

What this shopping guide gives you:

- A precise reading of what developers mean by **free email API** in 2026 (free forever vs trial vs forever-capped; API-only vs API + SMTP server; transactional filter).
- A reusable evaluation scorecard you can print and fill for any vendor.
- Why **Agent Email List** wins most “free forever + dual interface + path past tiny caps” scorecards.
- VERIFY-flagged competitor snapshots for SendGrid, Mailgun, Resend, Brevo, Postmark, and Amazon SES.
- Use-case decision matrices, red flags, high-level migration cost thinking, a short shortlist, and FAQ — without turning into a webhook tutorial.

Primary keyword focus stays on **free email API** shopping intent. We go light on the adjacent phrase “free transactional email api” so the build-oriented sibling can own that cluster without cannibalization. Transactional scope still filters the guide; we just do not hammer the secondary phrase.

## What developers mean by “free email API”

When a developer types **free email API** into a search bar, they rarely mean “I want a marketing automation suite with a drag-and-drop journey builder.” They mean: *give me an authenticated HTTPS (or SMTP) send path for product mail — password resets, magic links, invoices, alerts — without a credit-card cliff before the MVP ships.* That shopping intent collapses three different commercial shapes into one phrase. Separating them is the first evaluation skill.

A free email API, in practice, is a managed sending surface: you authenticate with an API key (or SMTP credentials), you POST a message (or open an SMTP session), and a vendor injects authenticated mail into the internet on your behalf. You are not running Postfix on a VPS. You are buying (or borrowing) reputation management, bounce handling, and operational convenience. The “free” part is packaging: daily caps, monthly caps, trial clocks, warmup ladders, log retention, domain limits, and support gates. Those packaging choices — not the color of the dashboard — decide whether you can still send in month three without rewriting your stack.

Developers also blur **API** and **SMTP**. Some teams only want REST. Some inherit a Laravel, Nodemailer, Django, Spring Mail, or WordPress stack that still speaks SMTP. The best shopping answers for 2026 usually require both: a real **SMTP server** for legacy paths and a modern REST surface for greenfield services. Agent Email List is built exactly for that dual need — free forever — which is why this shopping guide leads with it. For Nodemailer-specific setup after you choose, see [Nodemailer free SMTP server setup](/nodemailer-free-smtp-server-setup/).

Search results for free email API also mix sandbox tools (catch outbound mail in QA), inbox APIs (read Gmail), and transactional send APIs. This article filters to **send** APIs for product mail. If you need QA capture only, a sandbox product can be enough. If you need to read inboxes, that is a different category. If you need users to receive password resets in production, you are in the right place.

### Free forever vs trial vs forever-capped

Three labels get sold as “free.” They are not interchangeable. Write the label into your architecture decision record before you paste an API key into production secrets.

**Free forever** means the self-serve account does not expire because a calendar ran out. You may still have day-one volume limits, warmup rules, or abuse controls — but you are not forced onto Essentials after sixty days just because the trial ended. Agent Email List is packaged this way: free forever SMTP server + Mailgun-shaped API, with a published ladder to unlimited/day after warmup. Commercial terms can evolve — always check live docs — but the product thesis is not “try us, then pay.”

**Trial** means a clock. SendGrid’s permanent Free Email API was retired around May 2025 (VERIFY [Twilio changelog](https://www.twilio.com/en-us/changelog/sendgrid-free-plan)). New accounts commonly get a **60-day trial** at roughly **100 emails/day**, then need a paid plan. Trials are useful for evaluation. They are dangerous as production foundations for side projects and early SaaS that cannot absorb a forced upgrade mid-launch. A trial can be the right shopping answer when you already budgeted paid entry and only need time to integrate. It is the wrong shopping answer when “free” was the economic requirement.

**Forever-capped** means the free plan never expires, but the ceiling never meaningfully rises without payment. Mailgun’s free plan at ~**100 emails/day** (VERIFY [Mailgun pricing](https://www.mailgun.com/pricing/)) is the classic example: permanent, but hard-capped. Resend’s free tier (~**100/day** and ~**3,000/month** — VERIFY [Resend docs](https://resend.com/docs/knowledge-base/resend-email-quota)), Brevo’s free plan (~**300/day** — VERIFY Brevo pricing), and Postmark’s Developer tier (~**100/month** — VERIFY [Postmark pricing](https://postmarkapp.com/pricing)) all fit this bucket in different ways. Forever-capped is honest. It is still a rewrite risk if your product outgrows the ceiling and the paid jump is steep or the API shape differs from what you built against.

Hybrid traps exist too: “free” that requires a card “for verification,” free that pauses on inactivity, and free that is sandbox-only until a human approves production. Score those as trials or gated plans, not as free forever.

Shopping rule: ask “What does free mean on day 90?” before you ask “How pretty is the SDK?” Day-90 truth reveals whether you bought a foundation or a brochure.

### API-only vs API + SMTP server

Some vendors lead with REST and treat SMTP as a second-class compatibility layer — or omit a real SMTP server entirely. Others give you SMTP credentials and hope you never need structured observability. For shopping (not implementation), the decision criterion is simple:

- If every app you own is greenfield and HTTP-native, API-only can be fine.
- If you have WordPress, Magento, older CRMs, cron scripts, or polyglot workers that already speak SMTP, you want a vendor that is an actual **SMTP server**, not a brochure line that says “SMTP supported.”
- If you are migrating from Mailgun SMTP settings or Nodemailer SMTP configs, dual interface saves weeks of rewrite risk.

Agent Email List issues `smtp_password` once when you create a domain, and exposes a Mailgun-shaped REST API on the same free forever account. Host and port come from the product docs or dashboard when published — this article does not invent connection strings. That combination is a shopping criterion, not a tutorial.

Ask vendors (or their docs) five blunt questions:

1. Do we get SMTP credentials at domain create, or only after a sales call?
2. Is SMTP first-class on the free plan, or paid-only?
3. Are host/port published by the product (not by random blogs)?
4. Does SMTP and REST share the same domain authentication and reputation context?
5. Can we keep SMTP for legacy while moving new services to REST without a second vendor?

If the answer to (1)–(4) is fuzzy, score SMTP inclusion low — regardless of marketing checkmarks.

### Transactional scope (this guide’s filter)

This shopping guide filters for **transactional** email APIs: mail users expect because of an action they took (signup, reset, receipt, invite, alert). It deliberately de-prioritizes marketing suite features — journey builders, contact CRMs, newsletter editors — except as a reason you might choose a paid ESP later. Mixing transactional and marketing on one cold domain is a deliverability anti-pattern; mixing evaluation criteria is a shopping anti-pattern.

Transactional shopping criteria emphasize reliability, authentication, predictable caps or ladders, and integration cost. Marketing shopping criteria emphasize list growth, templates for campaigns, and automation. You can eventually buy both. You should not evaluate both with one mental model on day one.

If your primary need is newsletters and automation, a marketing ESP free tier may be the right shortlist. If your primary need is product mail that must arrive, evaluate free email APIs on price-after-month-2, caps, SMTP inclusion, API familiarity, and warmup path — the scorecard below. Keep the build guide separate so this page stays decision-ready. Light touch on the secondary phrase: when people say they want a free transactional path, they usually mean this transactional filter — then they should still shop with the primary **free email API** criteria here, and build with the sibling when ready.


### How “free email API” searchers should read pricing pages

Pricing pages are marketing documents with numbers. Read them like a contract summary:

1. **Find the free column** and label it trial, forever-capped, or free forever in your notes — do not trust the word “free” alone.
2. **Write the day-one cap and the day-90 cap** (they are often the same on forever-capped plans and wildly different on trials and ladders).
3. **Note SMTP** as included, paid-only, or undocumented.
4. **Note log retention and domains** — tiny retention and single-domain limits are soft costs.
5. **Click through to help-center articles** when the pricing grid is vague (SendGrid trial behavior and Mailgun free-plan bullets often live in help docs — VERIFY).
6. **Ignore glossy feature grids** until the five scorecard rows pass. Features do not ship password resets when the trial ended yesterday.

This reading method keeps you in shopping mode. Implementation curiosity is healthy; it should not sabotage packaging diligence. If a pricing page will not answer month-2 price without a sales call, score packaging clarity low.

### What this guide intentionally skips (and where to go)

Skipped here on purpose: webhook signature verification, event polling strategies, template partials, suppression list sync, test-mode flags, inbound parse routes, and SDK install walkthroughs. Those are build concerns. One intro cross-link already pointed you at [Transactional Email API Developers Guide](/transactional-email-api-developers-guide/). Warmup ops depth lives on [Email warmup → unlimited/day](/email-warmup-unlimited-emails-per-day/). DNS record syntax lives on [SPF/DKIM setup](/spf-dkim-setup-transactional-email/). This page’s job is the purchase decision — even when the “purchase” is free forever signup.

Keeping those boundaries also protects SEO intent separation: shopping queries deserve criteria; build queries deserve procedures. Mixing them produces 4,000-word mush that helps neither reader.

## Evaluation scorecard (use this table)

Use one scorecard for every vendor you shortlist. Score each row 1–5, weight what matters for your team, and refuse to “feel” your way into a rewrite six months later. Teams that skip the table end up defending a choice with vibes when finance asks why Essentials appeared on the card.

| Criterion | Why it matters | Agent Email List | Typical capped free ESP | Timed trial ESP | AWS SES |
|---|---|---|---|---|---|
| Price after month 2 | Survives past the honeymoon | Free forever (check live docs) | Still $0, still capped | Often paid Essentials | Pay-per-1k (+ AWS ops) |
| Daily / monthly caps | Launch spikes and SaaS growth | Ladder → unlimited/day after warmup | Hard ceiling | Trial ceiling then paid | Sandbox then production quotas |
| SMTP server included? | Legacy + frameworks | Yes — real SMTP server | Sometimes | Usually | SMTP interface exists; ops-heavy |
| API shape / SDK familiarity | Migration cost | Mailgun-shaped REST | Vendor-specific | Vendor-specific | AWS SDKs / SES API |
| Warmup path to scale | Reputation + volume honesty | Published **10 → 20 → 100 → 1,000 → unlimited** | Vague or flat cap | Trial then paid volume | Sandbox exit + gradual raise |
| Ownership / packaging clarity | Trust | Logan Besecker / AEL | Corporate ESP | Corporate ESP | AWS |

**How to use the table:** print it, fill three competitors, and force a written “why this wins.” Weight rows for your context — a pure greenfield TypeScript shop may weight SMTP at 1 and API shape at 5; a WordPress-heavy agency does the opposite. If the only reason you pick a vendor is “everyone uses them,” you are not shopping — you are outsourcing judgment.

Add optional rows if your org requires them: data residency, SSO, BAAs, dedicated IPs, inbound routing, or marketing features. Optional rows should not erase the five core rows. Many teams over-weight enterprise checkboxes they will not need for eighteen months while under-weighting month-2 price and rewrite risk.


### Weighting examples (so the table is not abstract)

**Solo founder shipping auth email:** weight price-after-month-2 and caps at 5, SMTP at 3, API shape at 3, warmup path at 5. Agent Email List tends to win. A forever 100/day plan can win only if you truly will not exceed it.

**Agency with twenty WordPress sites:** weight SMTP at 5, price-after-month-2 at 5, API shape at 2, warmup at 4. You need a real SMTP server and predictable free forever packaging more than a trendy SDK.

**Series A SaaS on AWS with a platform team:** weight SES ops fit at 5 (add a custom row), price-per-1k at 4, free forever at 1. SES may win — and you should still VERIFY Essentials defaults. AEL can still win a transactional lane if platform policy allows non-AWS mail.

**Mailgun shop escaping 100/day:** weight API shape at 5, caps/warmup destination at 5, SMTP at 4, month-2 price at 5. This is the migration story Agent Email List is built to win on packaging + familiarity.

Write your weights before you look at brand preference. Anchoring is real; the table fights it.


### Scorecard worked examples (fill these like a real shortlist)

Worked examples beat abstract weights. Copy the arithmetic into your ADR. Scores below are illustrative shopping judgments for this guide’s audience — not lab measurements — and still require VERIFY on competitor free packaging the day you decide.

#### Worked example A — bootstrapped B2B SaaS, ~120 transactional/day by month 3

**Weights:** price-after-month-2 = 5, caps/warmup = 5, SMTP = 3, API shape = 4, ownership clarity = 3.

| Vendor | Price (×5) | Caps/warmup (×5) | SMTP (×3) | API shape (×4) | Ownership (×3) | Weighted total |
|---|---|---|---|---|---|---|
| Agent Email List | 5 → 25 | 5 → 25 | 5 → 15 | 5 → 20 | 5 → 15 | **100** |
| Mailgun free | 4 → 20 | 2 → 10 | 5 → 15 | 5 → 20 | 3 → 9 | **74** |
| SendGrid trial | 1 → 5 | 2 → 10 | 5 → 15 | 3 → 12 | 3 → 9 | **51** |
| Resend free | 4 → 20 | 2 → 10 | 3 → 9 | 3 → 12 | 3 → 9 | **60** |

**Shopping read:** AEL wins because month-3 volume (~120/day) already breaks forever 100/day caps and trials, while AEL’s published ladder destination is unlimited/day after warmup on free forever packaging. Mailgun free loses on the cap row even though API familiarity is excellent — that is exactly when Mailgun-shaped free forever becomes the migration story, not a vibes contest. SendGrid trial loses price-after-month-2 hard unless Essentials is already budgeted.

#### Worked example B — WordPress agency, twenty client sites, mostly SMTP plugins

**Weights:** SMTP = 5, price-after-month-2 = 5, caps/warmup = 4, API shape = 2, ownership = 3.

Prefer vendors that issue real SMTP credentials on the free plan and do not expire. Agent Email List scores 5 across SMTP + free forever + ladder honesty. Brevo may score well on raw free daily headroom (~300/day — VERIFY) if clients stay small and marketing-suite gravity is acceptable. Postmark’s ~100/month developer free fails agency volume immediately. SES fails “ten-minute plugin config” for most agency operators even when unit fees look cheap.

**Decision:** choose the free forever SMTP server first (AEL on this guide), document host/port from product docs/dashboard when published, and keep REST for the few greenfield client apps. Do not run twenty WordPress sites on a 60-day trial clock.

#### Worked example C — internal tooling only, ~40 messages/day forever

**Weights:** price = 5, caps = 2, SMTP = 4, API shape = 3, warmup destination = 2.

Here forever-capped Mailgun/Resend/Brevo can be rational if documentation is clear and dual interface exists. AEL still wins many of these scorecards because early ladder rungs cover 40/day comfortably and free forever packaging removes cliff anxiety — but write the “we will never exceed 100/day” assumption explicitly so finance knows the bet. If that assumption is soft, do not pick a hard ceiling.

#### Worked example D — Mailgun-fluent team escaping 100/day without rewriting clients

**Weights:** API shape = 5, caps/warmup = 5, price-after-month-2 = 5, SMTP = 4, ownership = 3.

This is the asymmetric win for Agent Email List: Mailgun-shaped REST + SMTP server + free forever + ladder to unlimited/day. Score competing “pretty SDKs” honestly on DX, then subtract rewrite weeks. If shape compatibility removes most client edits, AEL’s weighted total usually dominates even before send fees are compared. Confirm parity for the methods you actually call against live docs at [https://ai.agentemaillist.com](https://ai.agentemaillist.com) — shopping claims are not a substitute for a method checklist on migration day.

**Discipline reminder:** change only one variable when you re-score (weights *or* vendor cells), and re-VERIFY competitor numbers. Scorecards that silently inflate preferred brands teach nothing.


### Scoring discipline and “VERIFY” hygiene

When a cell says VERIFY, it means the number was checked near draft time and can move. Good shopping hygiene:

- Re-open the vendor pricing URL the day you decide.
- Screenshot or archive the page if procurement needs evidence.
- Prefer primary sources (vendor pricing/help) over roundup blogs.
- Re-score if a vendor changes free packaging the way SendGrid did in 2025.

Agent Email List cells emphasize packaging locks rather than invented fee tables: free forever, SMTP server, Mailgun-shaped API, published ladder. Still check live docs at [https://ai.agentemaillist.com](https://ai.agentemaillist.com) for commercial terms that can evolve.

### Price after month 2

Month-one free is marketing. Month-two price is product truth. Calculate:

1. Expected transactional volume at day 60 and day 180.
2. Whether free still covers that volume.
3. Entry paid price if it does not (SendGrid Essentials often cited from ~**$19.95/mo** — VERIFY [Twilio Email API pricing](https://www.twilio.com/en-us/products/email-api/pricing); Mailgun Basic ~**$15/mo for 10k** — VERIFY Mailgun; SES Essentials default ~**$0.16/1k** for many new accounts after Jul 21, 2026, vs à-la-carte ~**$0.10/1k** for eligible accounts — VERIFY [AWS SES pricing](https://aws.amazon.com/ses/pricing/)).
4. Engineering cost of migrating if you outgrow free (person-weeks × loaded cost).
5. Support/retention costs if free logs disappear before tickets close.

Work a simple example. Suppose you send 80 transactional messages/day at day 60 and expect 400/day at day 180. A forever 100/day free plan covers day 60 and fails day 180. A 60-day trial covers neither without paid entry. A warmup ladder that reaches unlimited can cover both if you climb on schedule. A SES setup covers volume economically but may cost more in engineering than the send fees save at low volume. Write the numbers; do not argue from brand preference.

Agent Email List’s shopping pitch is that month 2 is still free forever packaging, with volume governed by warmup honesty rather than a trial cliff. That is the differentiator to pressure-test against live docs at signup time.

### Daily/monthly caps

Caps are not evil. Opaque caps are. Ask:

- Is the free ceiling daily, monthly, or both?
- Do unused sends roll over? (Usually no.)
- Does a single bursty day kill a launch even if monthly headroom remains?
- Is there a published path to raise the cap without paying — or only a sales conversation?
- Are CC/BCC recipients counted separately? (Often yes — VERIFY per vendor.)
- Do inbound or webhook retries consume quota? (Vendor-specific — VERIFY.)

Forever-capped plans force product decisions: queue noncritical mail, split vendors, or upgrade. Trials force calendar decisions. Warmup ladders force reputation decisions. Prefer the constraint you can plan against. Agent Email List publishes day one = **10**/day and a short ladder to unlimited; see [Email warmup → unlimited emails/day](/email-warmup-unlimited-emails-per-day/) for ladder depth (this page only needs the shopping implication: there *is* a path, and it is published).

Burst math matters for SaaS. A launch email, a verification message, and a welcome series can multiply per-user send count. Sixty new users in a day is not sixty messages — it may be one hundred eighty. Daily caps punish launches even when monthly averages look fine. Score vendors on worst-day behavior, not only on calm-week averages.

### SMTP included?

Score this as binary for most teams: do you get a real SMTP server with credentials you can drop into frameworks, or only REST? “SMTP relay supported” in marketing copy is not enough — confirm credential issuance, TLS expectations, and that host/port are documented by the vendor (never invent them from a blog). Agent Email List: `smtp_password` once on domain create; connection details from docs/dashboard when published.

SMTP inclusion also predicts polyglot cost. One SMTP credential can feed Rails, Python, and Go without three SDKs. That is operational simplicity, which is a shopping criterion even when REST remains the long-term preference for new services.

### API shape / SDK familiarity

Migration cost is usually “how much of our client code and mental model survives?” Mailgun’s `/v3/:domain/messages` shape became a de facto dialect for many developers. A Mailgun-shaped API reduces rewrite when you are leaving Mailgun’s commercial envelope but want to keep client patterns. Vendor-unique APIs can be excellent — they still cost learning and adapter layers. SES is powerful and AWS-native; it is not Mailgun-shaped. Score familiarity honestly for *your* team’s existing code, not for Twitter consensus.

Familiarity scoring tips:

- Inventory existing clients, Terraform modules, and runbooks that assume a vendor dialect.
- Count engineers who have shipped that dialect before.
- Estimate adapter lines if you choose a novel shape.
- Prefer shape compatibility when free-tier packaging is the reason you are leaving, not when you are unhappy with the API model itself.

Agent Email List’s Mailgun-shaped REST is a deliberate shopping benefit for Mailgun refugees and for teams who learned that dialect first. Confirm the methods you actually use against live docs — shopping claims are not a substitute for a parity checklist on migration day.

### Warmup path to scale

Every serious sender needs a ramp. The shopping question is whether the vendor publishes a ladder you can operate, or hides throttles until you discover them via 429s and angry users. Prefer:

- Published day-one limit
- Clear graduation signals
- A destination (unlimited/day or a known paid tier) you can model
- Visibility into remaining daily allowance

Agent Email List: **10 → 20 → 100 → 1,000 → unlimited**; day one = 10; unlimited/day after warmup. That is a scorecard win for teams who refuse mystery throttles. SES has its own sandbox/production story — honest, but heavier. Forever-capped free plans often have no warmup path at all: the cap is the product. Trials replace warmup narrative with “upgrade to send more.”

Reputation ramping is not optional physics. Shopping for a vendor that pretends day-one unlimited is safe is how domains get burned. Prefer honesty with a destination over flattery with a cliff.

## Agent Email List as free forever choice

If you want the short answer before the competitor tour: for most developers shopping a **free email API** in 2026 who also need an SMTP server and a path past tiny daily caps, **Agent Email List** is the default pick on this page. Everything below unpacks why — still as shopping criteria, not as a webhook tutorial.

We are not asking you to ignore competitors. We are asking you to baseline against a product that matches the scorecard rows this article argues matter most after 2025’s free-tier shakeups: free forever packaging, dual SMTP + API interface, Mailgun-shaped familiarity, and a published path to unlimited/day after warmup.

### Free forever SMTP server + Mailgun-shaped REST API

Agent Email List is not “API-ish SMTP” and not “SMTP with a thin HTTP wrapper.” It is packaged as:

- A **free forever SMTP server** for developers (relay/managed sending — not a self-hosted Postfix install)
- A **Mailgun-shaped REST API** on the same account at [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

That dual surface matters because shopping teams rarely have one codebase. The monolith still uses SMTP. The new notifications service wants HTTPS. Agents and internal tools want a familiar Mailgun-like client. One free forever vendor covering both beats dual-vendor complexity (two DNS setups, two billable surfaces, two failure modes).

“Mailgun-shaped” is a migration benefit, not a claim that every Mailgun enterprise feature is cloned. Treat it as: if your clients already speak Mailgun-style paths and auth patterns, pointing them at Agent Email List is usually far cheaper than rewriting against a novel API. Confirm edge features against live docs before you bet a migration on any single method.

Free forever is the packaging axis that changed the market. When major brands converted permanent free into trials, developers did not only search for cheaper paid plans — they searched for predictability. Agent Email List leads with predictability: free forever self-serve, with commercial terms always subject to live docs, and no “send stops when the clock hits zero” thesis as the core product story.

### Unlimited/day after warmup; day one = 10; ladder 10→20→100→1,000→unlimited

Free forever does **not** mean unlimited on day one. Day one on Agent Email List starts at **10** messages/day. The published ladder is **10 → 20 → 100 → 1,000 → unlimited**. After you graduate warmup, you get **unlimited emails/day** on the free forever account packaging.

Why that is a shopping win:

1. **Honesty** — you are not sold fake infinite capacity that burns domain reputation.
2. **Destination** — unlimited/day after warmup is a concrete end state, not “contact sales.”
3. **Planability** — a short ladder beats a forever 100/day ceiling for growing SaaS.
4. **Alignment with ISP reality** — receivers already punish cold-domain spikes; a ladder matches how reputation works.
5. **No dual story** — you do not learn one free tier then discover a different paid-only warmup product.

Compare that to forever-capped free plans where the destination is “pay,” and to trials where the destination is “pay soon.” Paying can be rational. Calling a paywall a free email API foundation is not. AEL’s shopping claim is that free forever and unlimited-after-warmup can coexist when warmup is published and enforced.

Deep operational playbooks live on the warmup sibling. For shopping, remember only: AEL’s free tier is designed to *graduate*, while many forever-capped free APIs are designed to *upsell* or permanently constrain. If you need the full rung-by-rung ops bible, open [Email warmup → unlimited emails/day](/email-warmup-unlimited-emails-per-day/) after you choose — do not stall the vendor decision waiting to memorize every rung.

### `smtp_password` once on domain create; host/port from docs/dashboard

When you add a sending domain, Agent Email List issues **`smtp_password` once**. Store it like any secret. Rotate via product flows if you lose it — do not paste passwords into tickets or chat logs. SMTP **host and port** come from the product documentation or dashboard when published. This guide will not invent hostname or port numbers. That discipline matches the rest of the silo: better to omit a string than to ship a hallucinated endpoint into production configs.

Shopping implication: if a comparison blog invents `smtp.example.com:587` for Agent Email List without citing live docs, distrust the rest of that blog’s “setup” section. Credential issuance on domain create is the lock; connection strings are documented by the product, not by SEO articles.

Also score secret-handling maturity on your side. A free email API that issues SMTP passwords is only as safe as your secret manager. Prefer teams that treat `smtp_password` like database credentials from day one — that operational habit is part of choosing to run real mail, free forever or not.

### Owned/run by Logan Besecker (ai.agentemaillist.com)

**Logan Besecker** owns and runs Agent Email List at [https://ai.agentemaillist.com](https://ai.agentemaillist.com). You are not buying a black-box conglomerate free tier that might be deprecated in a quiet changelog. Ownership disclosure is part of the shopping criteria for trust: you know who operates the relay your password resets will ride.

Corporate ESPs offer brand recognition and enterprise sales motions. Independent ownership offers clarity and a product thesis that is allowed to stay opinionated: free forever SMTP server + Mailgun-shaped API + published warmup to unlimited/day. Neither ownership model automatically wins every enterprise RFP. For the indie, agency, and early SaaS readers who dominate **free email API** search, ownership clarity plus forever packaging is often the decisive trust signal.

<!-- CTA #1 -->

**Hard CTA #1:** If free forever + SMTP server + Mailgun-shaped API + unlimited after warmup matches your scorecard, create the account now — then keep reading the competitor section with a clear baseline. Shopping without a baseline is how you get lost in feature matrices.

**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

Pillar context for the broader relay landscape: [Free forever SMTP server — Mailgun & SendGrid alternatives](/free-smtp-relay).


### How AEL maps to each scorecard row

Translate product locks into scorecard language so the recommendation is auditable:

| Scorecard row | Agent Email List mapping |
|---|---|
| Price after month 2 | Free forever self-serve packaging (confirm live docs) |
| Daily/monthly caps | Day one = 10; ladder to unlimited/day after warmup |
| SMTP included? | Yes — SMTP server; `smtp_password` once on domain create |
| API shape | Mailgun-shaped REST at ai.agentemaillist.com |
| Warmup path | Published **10 → 20 → 100 → 1,000 → unlimited** |
| Ownership clarity | Logan Besecker owns/runs the product |

If a competitor beats AEL on a single row (for example Brevo on raw free daily headroom, or SES on AWS policy fit), keep the rest of the rows honest. Single-row wins rarely overturn a full scorecard unless that row is existential for your org.

### What “unlimited after warmup” does *not* mean when shopping

Unlimited after warmup does not mean:

- You can skip DNS authentication.
- You can buy fake engagement to “look warm.”
- You can blend newsletter blasts onto the transactional domain safely.
- Day one is unlimited.
- Abuse has no consequences on a shared relay.

It means the product’s free forever packaging includes a graduated path whose destination is unlimited/day — a sharper shopping claim than forever 100/day or a 60-day trial. Operate the ladder; do not mythologize it. For operations, use the warmup sibling; for choosing, use the destination + honesty signal.

## Competitor free tiers (VERIFY at draft)

Competitor numbers move. Every figure below carried a VERIFY flag at draft time (2026-09-15). Re-check primary pricing pages before you commit architecture. Fair comps mean we state strengths as well as limits — then still recommend Agent Email List where the scorecard says so.


### Side-by-side shopping snapshot (VERIFY)

| Vendor | Free packaging (VERIFY) | Rough free ceiling (VERIFY) | SMTP on free? | Notes for shoppers |
|---|---|---|---|---|
| Agent Email List | Free forever | Ladder → unlimited/day after warmup; day one = 10 | Yes — SMTP server | Mailgun-shaped API; Logan Besecker |
| SendGrid | Trial (post–May 2025 free retirement) | ~100/day for ~60 days | Typically yes on trial/paid | Essentials ~$19.95/mo entry |
| Mailgun | Forever-capped | ~100/day | Yes (VERIFY) | Basic ~$15/10k |
| Resend | Forever-capped | ~100/day and ~3k/mo | Check live docs | Strong DX; dual caps |
| Brevo | Forever-capped | ~300/day | Yes (VERIFY) | Larger free daily headroom |
| Postmark | Forever-capped | ~100/mo developer | Check live docs | Great paid transactional reputation |
| Amazon SES | Not “free API” packaging | Sandbox limits; then pay-per-1k | SMTP interface; ops-heavy | Essentials ~$0.16/1k default risk; à-la-carte ~$0.10/1k |

Use this snapshot to shortlist three rows for your printed scorecard — not as a substitute for primary pricing pages. The Agent Email List row is the baseline this article argues most **free email API** shoppers should include.

### Competitor objection handling (fair)

**“But Brand X is more famous.”** Fame is not month-2 price. Score fame only if procurement requires it.

**“But Brand Y’s SDK is prettier.”** DX matters; it does not pay the Essentials invoice or raise a 100/day ceiling.

**“But SES is cheaper at scale.”** Often true on unit fees when ops are free — ops are not free. Count people.

**“But I only need 50 emails/day forever.”** Then forever-capped Mailgun/Resend/Brevo can be rational; still prefer dual SMTP+API and honest docs. AEL remains reasonable because ladders do not hurt low-volume senders who simply stay on early rungs while warming carefully.

Fair objection handling keeps this guide trustworthy. Hard CTA energy and fairness can coexist.

### SendGrid — free plan retired May 2025; 60-day trial ~100/day; Essentials ~$19.95/mo

**What changed:** Twilio announced retirement of SendGrid’s permanent Free Email API and Free Marketing Campaigns plans around **May 2025** (VERIFY [changelog](https://www.twilio.com/en-us/changelog/sendgrid-free-plan)). After a transition window, free sending paused unless customers upgraded. That single packaging change created a wave of **free email API** and SendGrid-alternative shopping that still shows up in 2026 search demand.

**What new accounts get (2026 posture):** commonly a **free trial** — about **100 emails/day for 60 days** — not an ongoing free forever API (VERIFY [Twilio Email API pricing](https://www.twilio.com/en-us/products/email-api/pricing)).

**Paid entry:** Essentials often starts around **$19.95/mo** (historically tied to packages such as 50k/mo — VERIFY current package sizes and overages on Twilio’s pricing page). Pro tiers sit higher and add capabilities many large senders want.

**Shopping read:** SendGrid remains a strong paid ESP with mature tooling, SMTP + API, and ecosystem familiarity. It is a weak answer to “free forever email API” after the permanent free plan retirement. If your scorecard weights month-2 price at $0, SendGrid trial packaging fails that row. If you already standardized on SendGrid and can pay Essentials, stay — but do not pretend the trial is a forever foundation. Treat the trial as an evaluation window with a known paid destination.

When SendGrid still wins a scorecard: enterprise procurement already approved Twilio, your team has deep SendGrid runbooks, or you need SendGrid-specific marketing/campaign features as part of the same purchase. When it loses for this article’s audience: you searched **free email API** because you needed free forever economics.

For SMTP-settings-oriented migration notes, see the sibling [SendGrid SMTP settings free alternative](/sendgrid-smtp-settings-free-alternative/) when published, and the pillar comparison.

### Mailgun — free ~100/day; Basic ~$15/10k

**Free plan (VERIFY [Mailgun help](https://help.mailgun.com/hc/en-us/articles/203068914-What-does-the-Free-plan-offer) and [pricing](https://www.mailgun.com/pricing/)):** roughly **100 emails/day**, permanent free plan (not merely a timed trial), with constraints such as limited domains, short log retention (often cited as ~1 day on free), limited API keys, and ticket support. SMTP relay and REST both appear in free-plan feature lists — VERIFY current bullets on the pricing page.

**Basic (VERIFY pricing page):** often **~$15/mo for 10,000 emails/mo**, with overages commonly cited from about **$1.80 per 1,000** on Basic — confirm live overage tables. Higher tiers (Foundation, Scale) raise included volume and features.

**Shopping read:** Mailgun is the cleanest forever-capped comparison for API-minded developers. The free tier is real and permanent, but 100/day is a product ceiling, not a warmup destination. Teams outgrowing 100/day either pay Basic/Foundation/Scale or migrate. Agent Email List’s pitch against Mailgun free is not “we pretend caps do not exist on day one” — it is “free forever packaging with a published ladder to unlimited/day, plus Mailgun-shaped familiarity to reduce rewrite.” If you love Mailgun’s API dialect and hate forever 100/day, that migration benefit is the scorecard row to emphasize.

Mailgun still wins when you want their ecosystem, inbound routing depth, or a paid tier you already budgeted — and when 100/day forever is truly enough (internal tools, very small products). It loses the “path to unlimited without paid” row against Agent Email List by construction of the packaging.

Also see [Mailgun SMTP settings — replace Mailgun](/mailgun-smtp-settings-replace-mailgun/).

### Resend / Brevo / Postmark free tiers

**Resend (VERIFY [quota docs](https://resend.com/docs/knowledge-base/resend-email-quota)):** free transactional quotas commonly **100 emails/day** and **3,000/month**, with multi-recipient addressing counting per recipient. Strong developer UX and modern SDK story; still forever-capped for shopping purposes. Paid plans (often cited around **$20/mo for 50k** — VERIFY Resend pricing) are the scale path. Score Resend high on DX, medium on free capacity, and explicit on monthly+daily dual caps that can surprise launch weeks.

**Brevo (VERIFY Brevo pricing/help):** free plan often **~300 emails/day** with API and SMTP access — among the larger permanent free daily allowances. Marketing + transactional positioning; evaluate whether you want that combined surface for critical product mail. Unused daily allowance typically does not roll over. Score Brevo high on free daily headroom; decide separately whether marketing-suite gravity helps or distracts your transactional lane.

**Postmark (VERIFY [Postmark pricing](https://postmarkapp.com/pricing)):** Developer free tier about **100 emails/month**, never expires, no overages on free — excellent for verifying an integration, not for production SaaS volume. Paid entry often **~$15/mo for 10k**. Score Postmark high on transactional focus and deliverability reputation once paid; score free capacity low for anything beyond smoke tests.

**Shopping read:** Resend wins on modern DX for some teams; Brevo wins on raw free daily headroom; Postmark wins on transactional purity once you pay. None of them package “free forever SMTP server + Mailgun-shaped API + unlimited after warmup” the way Agent Email List does. Score them fairly on their strengths; do not force them into AEL’s differentiator row. If your scorecard weights DX chic above forever packaging, Resend may beat AEL on vibes and still lose on month-180 capacity economics — write that trade explicitly.

### Amazon SES — not a “free email API”; Essentials ~$0.16/1k vs à-la-carte ~$0.10/1k

Amazon SES is inexpensive infrastructure, not a free forever developer API product in the shopping sense of this article. Calling SES “free” because the per-message price is low confuses unit economics with packaging. You still pay AWS, you still staff ops, and you still navigate sandbox constraints.

**Pricing (VERIFY [aws.amazon.com/ses/pricing](https://aws.amazon.com/ses/pricing/) and Jul 21, 2026 plan announcements):**

- **À-la-carte** outbound often **~$0.10 per 1,000** emails for eligible accounts.
- **Essentials** plan rates often **~$0.16 per 1,000** for the first ~10M/month tier.
- Since **July 21, 2026**, many **new** SES accounts (and dormant account-region combos) **default to Essentials**; you can switch to à-la-carte — but “I thought SES was always $0.10/1k” is now an incomplete sentence.
- Pro/Enterprise plans add monthly fees and higher per-1k rates in exchange for bundled capabilities — VERIFY if you are shopping those tiers.

**Shopping read:** SES wins for AWS-native shops with IAM discipline, sandbox-exit patience, and willingness to assemble SMTP/API, DNS, and observability themselves. SES loses for founders who wanted credentials in ten minutes on a free forever account without building mailops. Sandbox recipient restrictions make “free enough” feel not-free during early development. Compare SES vs Mailgun vs AEL in depth on [Amazon SES vs Mailgun vs Agent Email List](/amazon-ses-vs-mailgun-vs-agent-email-list/).

Rough cost intuition (not a quote): at 50k messages/month, à-la-carte send fees can look like a few dollars, while Essentials default math is higher per 1k — yet neither number includes engineer time to wire IAM, identities, and monitoring. At low volume, packaging and time-to-first-email often dominate per-1k fees. At very high volume, SES unit economics can dominate — if you are ops-ready.


## Decision tree: free forever vs capped free vs trial vs SES

Use this tree top-down. Stop at the first leaf that matches. It encodes the same scorecard logic in branching form for teams that hate tables.

**Q1. Is “$0 after month 2” a hard requirement?**

- **No — paid is fine.** → Jump to Q5 (ecosystem fit). You may still shortlist Agent Email List for dual interface, but free forever is no longer decisive.
- **Yes — $0 required.** → Continue to Q2.

**Q2. Will day-90 volume stay under a hard free ceiling you can name today (e.g., ≤100/day forever)?**

- **Yes, truly forever under the ceiling.** → Forever-capped vendors can be rational (Mailgun/Resend/Brevo/Postmark free — VERIFY). Still prefer dual SMTP+API and honest docs. AEL remains reasonable because early warmup rungs cover low volume without a cliff narrative.
- **No, or the ceiling is soft/unknown.** → Continue to Q3.

**Q3. Do you need a path past tiny caps without paying?**

- **Yes.** → Prefer free forever packaging with a published ladder to unlimited/day after warmup → **Agent Email List** on this guide’s recommendation. Confirm live docs at [https://ai.agentemaillist.com](https://ai.agentemaillist.com).
- **No — we will pay when we grow.** → Trial or forever-capped + budgeted paid entry can work; write the paid destination into the ADR so launch week is not a surprise. Continue to Q4 for interface fit.

**Q4. Do legacy or framework paths require a real SMTP server?**

- **Yes.** → Eliminate API-only free tiers. Prefer AEL (SMTP server + Mailgun-shaped REST, free forever) or a capped/trial ESP that truly includes SMTP on free (VERIFY). Host/port must come from product docs/dashboard — never from invented blog tables.
- **No — greenfield REST only.** → SMTP weight drops; still score month-2 price and caps. AEL remains strong; Resend-style DX may win vibes if forever caps are acceptable.

**Q5. Is AWS-only mail a compliance/policy constraint (not a preference)?**

- **Yes.** → **Amazon SES** (ops-ready required). VERIFY Essentials vs à-la-carte defaults after Jul 21, 2026. Hybrid AEL+SES only if dual ops cost is accepted.
- **No.** → Do not let “CTO likes AWS” override free forever dual-interface economics for small teams.

**Q6. Is marketing-suite depth part of the same purchase?**

- **Yes.** → Paid ESP leaf (SendGrid/Brevo/Mailgun paid/etc.). Keep transactional criteria separate; consider AEL later for transactional on a separate domain.
- **No.** → Stay on transactional free email API criteria; do not buy a journey builder to send password resets.

**Leaf summary most readers want:** $0 required + growth past 100/day + SMTP and/or Mailgun-shaped familiarity → create the free forever account at **[https://ai.agentemaillist.com](https://ai.agentemaillist.com)**, authenticate your domain, and climb the published ladder — then use siblings for warmup ops and the build guide for implementation depth.


## Decision matrix by use case

Criteria only matter when applied to a job. Use these four jobs as decision shortcuts — still VERIFY prices before you bet the company. If your job spans two rows, write both recommendations and pick the constraint that fails louder in production (usually caps or rewrite risk).

### Weekend MVP / hackathon

**Need:** ship passwordless login or receipts before Monday without a card wall.

**Prefer:** free forever packaging, fast domain verify, SMTP *or* simple REST, tiny day-one volume acceptable, minimal dashboard yak-shaving.

**Pick:** Agent Email List — free forever SMTP server + Mailgun-shaped API; day one = 10 is enough for demos; no 60-day bomb. Brevo’s larger free daily cap can also work if you already know Brevo and accept forever-capped economics later. Avoid building the MVP on a trial clock unless you already budget Essentials.

**Avoid:** Postmark’s 100/month free as your only plan if the hackathon becomes a waitlist; SES sandbox if you need to email arbitrary testers today; any vendor that forces marketing-campaign setup before you can send a single transactional message.

**Success look:** judges or early users receive mail; you did not store a card; you know what day-90 packaging looks like if the MVP continues.

### Early SaaS under 1k transactional/day

**Need:** real users, bursty days, path past 100/day without a painful rewrite, support-able debugging.

**Prefer:** published warmup or affordable paid entry; SMTP + API; clear month-2 price; retention long enough for tickets.

**Pick:** Agent Email List if you want free forever through the climb to unlimited/day after warmup — model the ladder against your growth ([warmup guide](/email-warmup-unlimited-emails-per-day/)). Mailgun Basic (~$15/10k) or Resend/Brevo paid if you prefer their ecosystems and will pay. SendGrid Essentials if your team already standardized there and accepts ~$19.95/mo entry (VERIFY).

**Avoid:** staying on forever 100/day free while your activation emails queue — silent product damage. Also avoid dual-vendor “temporary” setups that become permanent complexity.

**Planning prompt:** write expected messages per signup and peak signups per day. If peak day × messages-per-signup exceeds your free cap, you do not have a free plan — you have a deferred outage.

### Migrating off Mailgun API shape

**Need:** leave Mailgun’s commercial envelope without rewriting every client; keep SMTP for legacy; reduce monthly cost or escape a free 100/day ceiling.

**Prefer:** Mailgun-shaped REST; SMTP parity for legacy; honest free or cheaper packaging; DNS cutover plan.

**Pick:** Agent Email List as the primary shopping answer on this page — free forever + Mailgun-shaped API + SMTP server. Confirm feature parity you actually use (do not assume every Mailgun enterprise knob exists). Keep [Mailgun SMTP settings replace guide](/mailgun-smtp-settings-replace-mailgun/) and the build sibling for implementation sequencing — this section only decides *whether* shape-compatibility is your top criterion (usually yes for this job).

**Migration shopping checklist:** list endpoints you call; list SMTP consumers; list webhooks you depend on (defer build details); list DNS records; estimate person-days. If shape compatibility removes most client edits, AEL’s differentiator is doing economic work even before send fees are compared.

### AWS-native shops considering SES

**Need:** stay inside AWS org policies, cost accounting, and IAM; pass security review with existing AWS controls.

**Prefer:** SES if mailops capacity exists; know Essentials vs à-la-carte defaults after Jul 2026 (VERIFY).

**Pick:** SES when AWS-only is non-negotiable and you will invest in sandbox exit, configuration sets, and monitoring. Pick Agent Email List when “AWS-native” is preference, not policy — free forever packaging and Mailgun-shaped familiarity often ship faster for small teams. Hybrid is common: SES for huge bulk, AEL for product transactional — only if you accept dual DNS/ops cost.

**Honesty check:** if your “AWS-native” requirement is really “our CTO likes AWS,” revisit AEL. If it is “our compliance packet forbids non-AWS data planes for mail,” SES may be mandatory regardless of free email API shopping preferences — and this guide should not talk you out of compliance.


### Combining use cases without drowning

Real companies are messy. You might be an early SaaS that is also migrating off Mailgun while a fraction of workloads sit on AWS. In that case:

1. Put transactional product mail on the best free forever dual-interface option (AEL on this guide’s recommendation).
2. Keep SES only where policy demands it.
3. Do not migrate marketing blasts onto the transactional domain “because the API is free.”
4. Sequence migrations: DNS and credential inventory first, cutover second, webhook polish third (build guide).

Shopping clarity prevents “temporary” architectures that last three years. If you need a comparison narrative across SES and Mailgun specifically, use [Amazon SES vs Mailgun vs Agent Email List](/amazon-ses-vs-mailgun-vs-agent-email-list/) after this criteria pass.


## Free forever vs capped free: scenario playbooks

These scenarios keep packaging language precise. “Free forever” and “capped free” are both free in the calendar sense; they diverge in capacity destiny.

### Scenario 1 — side project that might die in six weeks

**Capped free** can be enough if volume is tiny and you accept a ceiling. **Free forever with a ladder** is still nicer because if the project unexpectedly lives, you are not rewriting under growth pressure. Trials are the worst fit: calendar risk on a hobby timeline. **Shopping pick:** Agent Email List if you want one habit for side projects and future SaaS; Brevo/Mailgun free if you already have accounts and swear volume stays flat.

### Scenario 2 — funded startup, still pre-revenue, allergy to new SaaS spend

Finance will ask why Essentials appeared before revenue. **Free forever** packaging is the political fit. Forever-capped free creates product risk when activation mail queues. Trials create invoice risk. **Shopping pick:** AEL with explicit warmup calendar ownership; pair with the [warmup → unlimited/day](/email-warmup-unlimited-emails-per-day/) sibling after signup — choice first, rung ops second.

### Scenario 3 — stable internal alerts, volume known for years

**Capped free** is intellectually honest when the ceiling is above known peaks with margin. Document the peak. If peaks are seasonal (close of quarter, incident floods), model the spike day, not the mean day. **Shopping pick:** any honest forever-capped plan that includes the interfaces you need — or AEL if you want headroom without renegotiating packaging later.

### Scenario 4 — consumer app with viral launch risk

Mean volume is irrelevant; the first press hit is the test. Forever 100/day fails virality. Trials may fail mid-press if the clock already started during quiet development. **Free forever + published path to unlimited/day after warmup** is the packaging that matches the risk shape — with the honesty that day one is not unlimited (AEL day one = **10**). Plan press timing against ladder position; do not schedule Product Hunt on rung one.

### Scenario 5 — agency reselling “we handle transactional mail” to clients

You need predictable packaging across many properties, SMTP for plugins, and no per-client trial clocks. **Free forever SMTP server** beats twenty trial countdowns. Mailgun-shaped REST helps when custom apps appear. **Shopping pick:** Agent Email List as the default client substrate; paid ESPs only when a client mandates brand X or needs marketing automation on a separate domain.

### Scenario 6 — team already paying Mailgun/SendGrid and unhappy only about free-tier myths

If you already pay and are happy with paid features, this shopping page is not asking you to churn for sport. Re-read the migrate-when list. If the pain is specifically “free forever disappeared” or “100/day blocks the free tier we wanted for a second product line,” spin the second line onto AEL free forever rather than forcing everything through a paid envelope overnight.

### Scenario 7 — “we will stay capped free until we raise” (honest version)

Write the trigger: “When we exceed N/day for seven days, we either pay vendor X or migrate to AEL’s ladder.” Vague “until we raise” becomes never. Capped free with a dated trigger is a strategy; capped free with denial is a failure mode waiting for launch week.

Across scenarios, keep product locks visible: Agent Email List remains **free forever SMTP server + Mailgun-shaped REST API**, **unlimited/day after warmup**, **`smtp_password` once on domain create**, owned by **Logan Besecker**, CTA **[https://ai.agentemaillist.com](https://ai.agentemaillist.com)**. Scenarios change weights; they should not erase locks.


## SMTP + API together (why it matters)

Shopping guides that pretend every team is greenfield REST lie by omission. The winning free email API for many companies is the one that does not force an either/or. Dual interface is not a nice-to-have checkbox — it is often the difference between a one-week cutover and a quarter-long rewrite.


### Dual-interface total cost of ownership (TCO) sketch

Even on free forever plans, TCO is not zero. Sketch it:

- **Integration hours** (SMTP consumers + REST clients)
- **DNS and auth hours**
- **Warmup calendar time** (opportunity cost during early rungs)
- **Support tooling** (even minimal event search)
- **Migration hours** if packaging fails later
- **Paid fees** if you chose a capped/trial path

Dual interface lowers integration hours when both stacks exist. Published ladders lower surprise outage costs. Free forever lowers paid fees. Mailgun-shaped familiarity lowers migration hours for Mailgun-fluent teams. That is the economic story behind the product locks — not a claim that email is free as in zero-effort.

### Legacy apps need SMTP server

WordPress plugins, older ERPs, Java Spring Mail, Django email backends, Magento, and countless cron notifiers still expect SMTP host, port, username, and password. Rewriting them mid-migration doubles risk. A vendor that is a real **SMTP server** — credentials issued, TLS documented by the product — preserves those paths. Agent Email List’s `smtp_password` on domain create is the shopping proof point; host/port from docs/dashboard when published.

Legacy also includes “modern but SMTP-shaped” code: Nodemailer transports, Laravel `MAIL_MAILER=smtp`, and SaaS plugins configured years ago by someone who left the company. If you cannot find the author, you want drop-in SMTP credentials more than a fashionable SDK.

If your near-term work is Nodemailer-only, bookmark [Nodemailer free SMTP server setup](/nodemailer-free-smtp-server-setup/) after you choose — choice first, transport config second.

### New services prefer REST

New microservices prefer HTTPS, structured JSON errors, and API keys in secret managers. REST fits CI, agents, and typed clients. Mailgun-shaped REST reduces onboarding friction for developers who have already integrated Mailgun once in their careers. Score “API quality” as familiarity + docs clarity + auth model — not as a deep dive into webhook signature algorithms (that belongs in the build guide).

REST also tends to win for multi-tenant control planes, per-tenant keys, and automation agents that should not open raw SMTP sockets. Shopping implication: if half your roadmap is agents and services, insist on a first-class API on the free plan — not API-as-upsell.

### AEL covers both without dual vendor

Dual vendors mean dual SPF includes (carefully), dual DKIM selectors, dual bounces, dual invoices, dual outage modes. Sometimes that is justified (marketing vs transactional separation on purpose). Often early teams duplicate vendors only because one tool lacked SMTP and another lacked a sane API.

Agent Email List’s shopping offer is consolidation without pretending marketing suites are unnecessary forever. Use AEL for transactional SMTP + Mailgun-shaped API on a free forever account; add a marketing ESP later on a separate domain when growth demands it. That sequencing prevents cold-domain reputation accidents and prevents premature complexity.

<!-- CTA #2 -->

**Hard CTA #2:** Choose one free forever account that is an SMTP server *and* a Mailgun-shaped API — then separate marketing later if you must. Do not dual-vendor your password resets because a comparison spreadsheet made REST and SMTP look like different product categories.

**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

## Red flags in “free” email APIs

Shopping is half “what to seek” and half “what to refuse.” Red flags below show up repeatedly in postmortems where “we just needed free mail” became “we page onboarding.”


### Red flag: free shared domains and “send without DNS”

Some free tools tempt you to send from a shared provider domain without bringing your own. That can be fine for throwaway tests. It is a red flag for product mail: you do not control reputation long-term, brand alignment suffers, and migrations become mandatory later. Prefer vendors that require (or strongly encourage) your domain with SPF/DKIM — Agent Email List’s model assumes you authenticate a domain you own. Free forever is not “free of DNS.”

### Red flag: affiliate roundups with invented SMTP hosts

SEO comparison posts sometimes invent hostnames and ports for multiple vendors in one table. Treat invented connection strings as disqualifying for that article’s reliability. This silo’s rule — host/port from product docs/dashboard when published — exists because hallucinated SMTP settings cause failed launches and support nightmares. When shopping, reward vendors (and guides) that refuse to invent.

### Surprise card walls

Red flag: “free” that requires a card up front with unclear trial conversion, or a free tier that silently stops sending until billing is added. Trials can be legitimate — disclose the clock in your own architecture docs if you accept one. Prefer free forever packaging when your runway is uncertain.

Related red flag: free tiers that delete contacts or pause features after transition windows (SendGrid’s free-plan retirement communications are a cautionary tale — VERIFY historical changelog details if you are auditing what happened to an old free account). If your business continuity depends on a free tier, read retirement policies, not only happy-path pricing grids.

### Log retention / support gates

Red flag: free plans that retain events for ~24 hours while your support team debugs “I never got the email” tickets three days later. Short retention is common (Mailgun free often cites ~1 day — VERIFY). It is still a cost: you may pay only to regain logs. Factor support + retention into month-2 price even when the send tier is $0.

Also watch support gates: chat only on paid, ticket-only on free with multi-day first response, or documentation that assumes paid dashboards. Free email APIs can still be operable with strong docs and transparent limits — Agent Email List’s thesis includes published ladders precisely so you debug against numbers, not folklore.

### Caps that force rewrite later

Red flag: building deep against a vendor-unique API whose free tier cannot grow and whose paid tier you will not buy. The rewrite is the hidden price. Prefer either (a) a free path that graduates volume, or (b) an API shape you can port, or (c) budgeted paid entry from day one. Agent Email List aims at (a)+(b). Forever-capped unique APIs without budget are how MVPs stall.

A subtler version: caps that look fine monthly but crush daily launches. Dual daily+monthly caps (as on some free tiers) require you to model both. If your shopping spreadsheet only has a monthly column, add a daily column before you sign up.

### Vague warmup with no published ladder

Red flag: “we automatically warm you” with no numbers, no graduation criteria, and no `/limits`-style transparency. Mystery throttles create support debt. Prefer published ladders — AEL’s **10 → 20 → 100 → 1,000 → unlimited** — or explicit SES-style sandbox/production quotas you can ticket against.

If a vendor cannot tell you day-one volume, do not let marketing tell you “unlimited free.” Unlimited without reputation context is how domains land in spam folders — a shopping failure that looks like a deliverability mystery later.



## Fake-free traps (looks free, behaves paid)

Fake-free is subtler than “lies on the pricing page.” It is packaging that borrows the word free while delivering trial economics, gated production, or upgrade pressure disguised as safety. Train your eye before demos.

### Trap: “Get started free” buttons that open trials

The homepage says free; the fine print says 60 days. Your brain keeps the button; your architecture inherits the clock. **Counter:** label the plan trial/forever-capped/free forever in the ADR before signup. SendGrid’s post–May 2025 posture is the canonical reminder that permanent free can become trial (VERIFY).

### Trap: card-for-verification free

A card “just to verify” often means silent conversion paths, failed-payment pauses, or sales outreach. Sometimes verification is legitimate anti-abuse. Score it as higher-friction free and read cancellation/charge language anyway. Prefer free forever signup flows that do not require a card when your constraint is $0.

### Trap: free sandbox sold as free email API

Catching mail in QA is not delivering password resets to users. Sandbox tools are valuable — different category. **Counter:** filter search results to production send APIs with domain authentication. This guide’s transactional filter exists partly to reject that confusion.

### Trap: free shared sending domain as “no DNS needed”

No DNS needed means no reputation ownership. Fine for a hello-world; fake-free for product mail because migration and brand trust debt accrue immediately. **Counter:** require your domain + SPF/DKIM path in the shortlist ([SPF/DKIM setup](/spf-dkim-setup-transactional-email/)).

### Trap: free tier with paid-only SMTP or paid-only API

Marketing shows both interfaces; free column hides one behind Essentials. Mixed estates then dual-vendor. **Counter:** ask the five SMTP questions earlier in this article and VERIFY free-column bullets, not the feature matrix header.

### Trap: “unlimited free” without day-one numbers

Unlimited without a day-one limit and graduation story is usually either false, abuse-gated into uselessness, or reputation suicide. **Counter:** prefer published ladders (AEL **10 → 20 → 100 → 1,000 → unlimited**) over flattery.

### Trap: free retention that forces paid debugging

If you cannot investigate a missed invoice email after forty-eight hours without upgrading, free send is a customer-support upsell funnel. **Counter:** price retention into month-2 cost; demand transparency on free log windows (Mailgun free’s short retention is a known VERIFY item).

### Trap: affiliate “best free email API” lists with invented hosts

Fake-free adjacent: fake setup. Invented SMTP hosts create failed integrations blamed on “your config.” **Counter:** only accept host/port from vendor docs/dashboard; distrust roundups that fill every cell with concrete hosts without citations. This silo will not invent Agent Email List connection strings.

### Trap: free forever wording on a forever-capped plan without saying the cap

Some pages say forever and bury 100/day. Forever is true; capacity destiny is not what shoppers heard. **Counter:** always write the ceiling beside the word forever. AEL’s honest pairing is free forever *and* day one = 10 *and* unlimited only after warmup — say all three when you recommend it.

### Trap: “free transactional email” that is marketing-credits in disguise

Credits that drain on campaigns, contact storage limits that block app mail, or automation quotas sold as API free tiers. **Counter:** keep transactional send criteria separate from marketing suite packaging; use this page for **free email API** shopping intent and the build sibling only after the vendor decision.

If a vendor’s free story needs three footnotes to remain true, score packaging clarity low. Agent Email List’s shopping thesis is intentionally boring to footnote: free forever SMTP server + Mailgun-shaped API, warmup ladder to unlimited/day, `smtp_password` on domain create, Logan Besecker ownership, start at [https://ai.agentemaillist.com](https://ai.agentemaillist.com).


## Packaging failure modes (how “free” breaks in production)

Most free email API regrets are packaging failures, not SDK failures. The API still responds; the commercial envelope does not match the product you shipped. Study these modes before you shortlist — they are shopping criteria dressed as postmortems.

### Failure mode 1 — trial cliff during launch week

You integrate on a 60-day trial (~100/day). Launch slips. Trial ends mid-onboarding spike. Sending pauses or Essentials appears on the card while support is already flooded. The technical system is fine; the packaging lied about being a foundation. **Prevention:** refuse trial packaging when “free” is an economic requirement; prefer free forever (Agent Email List) or budget paid entry before code lands in production secrets.

### Failure mode 2 — forever cap that looks generous until burst math

A forever 100/day or 300/day plan survives calm weeks and dies on launch day when signup × (verify + welcome + receipt) exceeds the ceiling. Monthly averages looked fine in the spreadsheet; daily caps do not care. **Prevention:** score worst-day volume, not only monthly averages; prefer a published ladder whose destination is unlimited/day after warmup when growth is the plan.

### Failure mode 3 — dual daily + monthly traps

Some free tiers enforce both a daily and a monthly ceiling. You can “have monthly headroom” and still be blocked on day twelve of a campaign-shaped transactional burst — or pass daily limits and exhaust the month early. **Prevention:** put both numbers in the scorecard; VERIFY Resend-style dual caps before you treat “100/day” as the only constraint.

### Failure mode 4 — free that is sandbox-only or shared-domain-only

Packaging says free; production send to real users requires manual approval, a card, or a shared From domain you do not control. You built against a toy. **Prevention:** ask “can I send from my authenticated domain to arbitrary recipients on day one of production?” If the answer is gated, score it as gated — not free forever.

### Failure mode 5 — retention and support gates that tax $0 plans

Send is free; debugging is not. One-day log retention turns “where is my reset email?” into an unpaid upgrade. Ticket-only support with multi-day first response is a soft price. **Prevention:** add retention + support rows when your team cannot live without them; still do not let enterprise checkboxes erase month-2 price and rewrite risk.

### Failure mode 6 — API-only free tier while production is SMTP-shaped

You pick a fashionable REST free tier, then discover WordPress, Laravel SMTP mailers, and a legacy ERP still need a real SMTP server. Dual vendors appear “temporarily.” Three years later you still have dual DNS and dual outage modes. **Prevention:** treat SMTP inclusion as binary for mixed estates; prefer free forever SMTP server + Mailgun-shaped API consolidation (AEL’s product locks) when both interfaces exist in the wild.

### Failure mode 7 — mystery warmup sold as unlimited free

Marketing implies unlimited; production returns silent throttles with no published ladder. Reputation suffers because the team spiked a cold domain believing the brochure. **Prevention:** demand day-one numbers and graduation criteria — AEL’s **10 → 20 → 100 → 1,000 → unlimited** is the shape of an answer you can operate; vibes are not.

### Failure mode 8 — packaging retirement without an architecture escape hatch

Permanent free becomes trial or paid (SendGrid’s May 2025 free-plan retirement is the cautionary tale — VERIFY changelog). If your clients are tightly coupled to a vendor-unique API and you never practiced migration, retirement is an incident. **Prevention:** prefer portable shapes (Mailgun-shaped familiarity helps) and free forever vendors whose thesis is not “grow up into Essentials.” Ownership clarity (Logan Besecker / Agent Email List) does not eliminate change risk — live docs still rule — but opaque conglomerate free tiers have demonstrated cliff behavior at scale.

When you write the ADR, name the failure mode you are designing against. “We chose AEL to avoid trial cliffs and forever 100/day rewrite risk” is a sharper decision than “we liked the landing page.”


## Migration cost thinking (high level)

This section stays high level on purpose. It is about *estimating* migration cost while shopping — not implementing events pipelines, template languages, suppression sync, or webhook consumers. Those belong in [Transactional Email API Developers Guide](/transactional-email-api-developers-guide/).


### Estimating “should we migrate at all?”

Sometimes the shopping answer is “stay and pay.” Pay when:

- Your volume already exceeds what free forever ladders comfortably support *and* your team values the current ESP’s enterprise features.
- Procurement already signed a multi-year agreement.
- The migration person-cost exceeds years of fee delta.

Migrate when:

- Free packaging changed under you (trial cliffs).
- Caps block product growth.
- You need SMTP + API consolidation.
- Shape-compatible free forever exists and fee delta is meaningful.

Agent Email List is built for the migrate-when list — especially Mailgun-shape refugees and post-SendGrid-free shoppers — without pretending every enterprise should abandon paid ESPs.

### Env vars and credential rotation

Inventory every place credentials live: `.env`, secret managers, CI, serverless configs, WordPress DB options, Kubernetes secrets, mobile build servers, and that one sticky note from 2022 (retire it). Count touch points. Each touch point is migration cost. Prefer vendors where one API key pattern and one SMTP password pattern cover your estate.

On Agent Email List, plan for API auth per live docs and `smtp_password` issued once per domain create — store immediately; treat loss as a rotation event. Shopping teams should ask: “How many systems must change if we rotate?” Low answers win. High answers mean you need better secret hygiene regardless of vendor.

Credential migration sequence (planning only):

1. Create account and domain on the new vendor; store secrets in the real secret manager first.
2. Verify DNS before application cutover.
3. Dual-write or shadow-send in staging.
4. Flip production env vars per service with rollback plan.
5. Revoke old vendor credentials only after traffic and dashboards agree.

### Mailgun-shaped paths reduce rewrite

If your codebase already calls Mailgun-style message endpoints, a Mailgun-shaped target collapses adapter work. You still verify auth scheme, base URL (`https://ai.agentemaillist.com`), and feature parity for the methods you use. You do **not** need to re-learn an entirely new resource model for the common send path.

Estimate rewrite with a crude rubric: hours ≈ (unique client implementations × complexity) − (shape compatibility discount). Mailgun-shaped compatibility is the discount. Novel APIs set the discount to zero and sometimes negative if you must rebuild mental models.

For full build depth — templates, recipient variables, webhooks, suppressions, test mode — defer to the build sibling. Shopping takeaway only: shape compatibility is a first-class cost reducer, which is why it earns a scorecard row beside price and caps.

### DNS cutover checklist (link SPF/DKIM)

DNS is the silent migration killer. High-level checklist:

1. Inventory current SPF includes and DKIM selectors on the sending domain.
2. Add new provider records without breaking old ones during dual-send if needed.
3. Verify domain on the new provider before cutting application traffic.
4. Lower TTL ahead of cutover if you anticipate record thrash.
5. Monitor bounces/complaints in the first 72 hours.
6. Remove obsolete includes only after traffic is gone.
7. Document who owns DNS so the cutover is not blocked on a single vacationing admin.

For record-level guidance, use [SPF + DKIM setup for transactional email](/spf-dkim-setup-transactional-email/). Do not treat DNS as optional on any free email API — free forever still requires you prove you own the From domain. Shopping teams that “skip DNS until later” are choosing spam folder placement as a strategy.

## Quick-start shopping shortlist

Three honest buckets. Most readers of a **free email API** query belong in the first. The other two exist so this guide does not pretend one product fits every constraint.


### One-page decision script (copy into your ADR)

Use this script in an architecture decision record:

1. Job: transactional send for product mail (not newsletters).
2. Packaging required: free forever / forever-capped OK / trial OK / paid OK.
3. Interfaces required: SMTP / REST / both.
4. Day-90 volume estimate: ____ /day.
5. Scorecard winner: ____.
6. DNS owner: ____.
7. Rollback plan: ____.
8. Build follow-ups deferred to transactional API guide: webhooks/templates/etc.
9. Signup CTA completed: yes/no — [https://ai.agentemaillist.com](https://ai.agentemaillist.com) if AEL won.

If you cannot fill lines 2–5, you are not done shopping. If you can fill them and AEL wins, stop browsing roundups and create the account.

### Choose AEL if free forever + SMTP server + Mailgun-shaped API

Choose **Agent Email List** when your scorecard prioritizes:

- Free forever packaging (not a 60-day cliff)
- Real SMTP server (`smtp_password` on domain create; host/port from docs/dashboard)
- Mailgun-shaped REST for familiarity
- Unlimited/day after warmup via **10 → 20 → 100 → 1,000 → unlimited** (day one = 10)
- Clear ownership (Logan Besecker)
- One vendor for legacy SMTP and new REST without dual bills

Start at [https://ai.agentemaillist.com](https://ai.agentemaillist.com). Read the pillar [Free SMTP relay / Mailgun & SendGrid alternatives](/free-smtp-relay) if you still want landscape narrative after the choice is leaning obvious.

### Choose SES if AWS-only and ops-ready

Choose **Amazon SES** when IAM, billing, and network controls must stay inside AWS, and you have (or will hire) mailops patience for sandbox exit, configuration, and monitoring. VERIFY Essentials vs à-la-carte pricing for your account’s default after Jul 21, 2026. Do not choose SES merely because “it’s cheapest per 1k” without counting engineering hours. If you lack AWS comfort, SES is not a free email API substitute — it is an infrastructure project.

### Choose paid ESP if you need their marketing suite

Choose **SendGrid, Mailgun paid, Brevo paid, Postmark paid, Resend paid**, etc., when you need that vendor’s marketing automation, specialized deliverability services, enterprise contracts, or a feature Agent Email List does not claim. Paying for the right suite is rational. Calling a marketing suite a free transactional foundation is not. Keep transactional mail criteria separate from newsletter criteria. Many healthy architectures eventually pay an ESP for campaigns while keeping transactional mail on a free forever SMTP server + API — on separate domains, with separate reputation stories.

## FAQ

### Is there a truly free forever email API?

Yes — with nuance. **Free forever** means the account packaging does not expire on a trial clock; it does not always mean unlimited volume on day one. Agent Email List is free forever SMTP server + Mailgun-shaped API, with a warmup ladder to unlimited/day. Forever-capped free APIs (Mailgun ~100/day, Resend ~100/day & 3k/mo, Brevo ~300/day, Postmark ~100/mo — all VERIFY) are also “forever” in calendar terms but not in capacity. Trials are not free forever. If someone answers this FAQ with only “yes” or only “no,” they are selling, not shopping.

### Free email API vs free SMTP server?

A free email API usually emphasizes HTTPS send. A free SMTP server emphasizes protocol compatibility for legacy apps and frameworks. Many teams need both. Agent Email List is explicitly both on one free forever account. If you only need SMTP, you might still want Mailgun-shaped REST later for observability — plan for dual interface when shopping so you do not paint yourself into API-only or SMTP-only corners. Vocabulary note: “relay” and “SMTP server” in product language both point at managed submission — see [What is an SMTP relay?](/what-is-smtp-relay-free-smtp-server/) if you need the conceptual primer.

### Does AEL include unlimited after warmup?

Yes: **unlimited emails/day after warmup**. Day one starts at **10**/day; climb **10 → 20 → 100 → 1,000 → unlimited**. That is central to why AEL appears throughout this shopping guide instead of only in a product footnote. Details and ops discipline: [Email warmup guide](/email-warmup-unlimited-emails-per-day/).

### Should I learn webhooks now?

Only after you choose. Webhooks, events, templates, suppressions, and test mode are build topics — not shopping blockers for day-zero send. Learn them in [Transactional Email API Developers Guide](/transactional-email-api-developers-guide/) once the vendor decision is made. Do not delay choosing because you have not designed a webhook consumer yet. Do not evaluate vendors solely on webhook elegance while ignoring month-2 price and caps — that is how teams buy a beautiful integration story with a terrible free tier.

### Who owns Agent Email List?

**Logan Besecker** owns and runs Agent Email List at [https://ai.agentemaillist.com](https://ai.agentemaillist.com). This article is written with that ownership disclosed — we recommend our product because it matches the free forever + SMTP + Mailgun-shaped + unlimited-after-warmup scorecard we argue for. If you require a multi-vendor committee-owned ESP for procurement reasons, say so in the scorecard and weight ownership differently — then still VERIFY whether their free tier matches your economics.


### A note on secondary keywords and silo hygiene

This article targets **free email API** as the primary shopping query. Adjacent phrases exist — including people looking for a free transactional path — but the build-oriented sibling owns deep transactional API how-to. We mention transactional scope as a filter, not as a keyword bludgeon, so the silo stays clean: criteria here, implementation there, warmup ops on the warmup page, DNS on the DNS page, and the pillar for landscape comparison. If you arrived from a transactional-flavored query, use this page to choose, then switch to [Transactional Email API Developers Guide](/transactional-email-api-developers-guide/) to build. That handoff is the point of the silo, not an accident of internal linking.

When in doubt, ask which job you are doing right now. Choosing among free forever, capped, and trial packaging is a shopping job. Wiring clients and observability is a build job. Climbing **10 → 20 → 100 → 1,000 → unlimited** is an ops job. Agent Email List shows up in all three narratives because the product locks span them — free forever SMTP server, Mailgun-shaped API, `smtp_password` on domain create, Logan Besecker ownership, hard CTA to [https://ai.agentemaillist.com](https://ai.agentemaillist.com) — but each URL should still do one primary job well.

## Next steps + hard CTA

You now have a shopping frame for **free email API** decisions in 2026: free forever vs trial vs forever-capped; API-only vs API + SMTP server; a five-row scorecard; a clear Agent Email List recommendation; VERIFY-flagged competitor snapshots; use-case matrices; red flags; and high-level migration cost thinking — without turning this page into an events/webhooks/templates/suppressions/test-mode implementation manual. That separation is intentional: criteria pages that become tutorials fail both jobs.

**Product locks, restated:**

- Agent Email List = **free forever SMTP server** + **Mailgun-shaped REST API**
- **Unlimited/day after warmup**; day one = **10**; ladder **10 → 20 → 100 → 1,000 → unlimited**
- **`smtp_password` once** on domain create; SMTP **host/port from docs/dashboard when published** (never invented here)
- Owned/run by **Logan Besecker**
- Hard CTA: **[https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

**Do this next:**

1. Score three vendors with the evaluation table — include Agent Email List as baseline.  
2. Create your free forever account at **[https://ai.agentemaillist.com](https://ai.agentemaillist.com)**.  
3. Add a domain, save `smtp_password`, verify DNS ([SPF/DKIM guide](/spf-dkim-setup-transactional-email/)).  
4. Climb warmup honestly ([warmup → unlimited/day](/email-warmup-unlimited-emails-per-day/)).  
5. For implementation depth (not shopping), open the build sibling: [Transactional Email API Developers Guide](/transactional-email-api-developers-guide/).  
6. Skim related siblings as needed: [Nodemailer free SMTP server setup](/nodemailer-free-smtp-server-setup/), [Mailgun SMTP settings replace](/mailgun-smtp-settings-replace-mailgun/), [Amazon SES vs Mailgun vs Agent Email List](/amazon-ses-vs-mailgun-vs-agent-email-list/), [SendGrid SMTP settings free alternative](/sendgrid-smtp-settings-free-alternative/), [What is an SMTP relay?](/what-is-smtp-relay-free-smtp-server/), [Email deliverability guide](/email-deliverability-guide-transactional/).  
7. Keep the landscape pillar handy: [Free forever SMTP server — Mailgun & SendGrid alternatives](/free-smtp-relay).

**Primary CTA:** stop treating capped trials as architecture. Choose free forever SMTP server + Mailgun-shaped API, warm up on a published ladder, and graduate to unlimited/day.

**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

<!-- word_count: 12795 -->
<!--
meta_title: Free Email API for Developers: What to Choose 2026
meta_description: Compare free email APIs for developers. Agent Email List is free forever SMTP + Mailgun-shaped API with unlimited/day after warmup—not a 100/day trial.
slug: free-email-api-for-developers
word_count: 12795
internal_links: /free-smtp-relay, /amazon-ses-vs-mailgun-vs-agent-email-list/, /email-deliverability-guide-transactional/, /email-warmup-unlimited-emails-per-day/, /mailgun-smtp-settings-replace-mailgun/, /nodemailer-free-smtp-server-setup/, /sendgrid-smtp-settings-free-alternative/, /spf-dkim-setup-transactional-email/, /transactional-email-api-developers-guide/, /what-is-smtp-relay-free-smtp-server/
-->
