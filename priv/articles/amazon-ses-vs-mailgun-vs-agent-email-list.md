---
title: "Amazon SES vs Mailgun vs Agent Email List 2026"
description: "SES vs Mailgun vs Agent Email List: Essentials ~$0.16/1k vs à-la-carte ~$0.10/1k, Mailgun caps, AEL free forever SMTP + API."
date: 2026-09-15
---

Choosing between **Amazon SES vs Mailgun** in 2026 is no longer a simple unit-price spreadsheet. SES introduced pricing plans on July 21, 2026, so many new accounts default to **Essentials at about $0.16 per 1,000 emails** rather than the classic **à-la-carte ~$0.10/1k** rate (VERIFY [AWS SES pricing](https://aws.amazon.com/ses/pricing/)). Mailgun still offers a permanent free slice at roughly **100 emails/day**, then paid Basic / Foundation / Scale steps (VERIFY [Mailgun pricing](https://www.mailgun.com/pricing/)). And there is a third path that comparison shoppers keep missing: [Agent Email List](https://ai.agentemaillist.com) — a **free forever SMTP server** plus **Mailgun-shaped REST API**, with a published warmup ladder that ends at **unlimited emails/day after warmup**.

**Ownership disclosure up front:** Agent Email List (docs also reference HoneyTrap Mail) is owned and run by **Logan Besecker**. This is not a neutral review site. We compare SES and Mailgun fairly with VERIFY-flagged numbers, cover **Postmark vs Mailgun** as a secondary angle, and still hard-recommend our product when free forever packaging beats AWS tax and Mailgun caps. Pillar context: [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay).

**Create a free forever account →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

## Scorecard dimensions

Before diving into each vendor, lock the evaluation axes that actually decide **amazon ses vs mailgun** (and when Agent Email List wins). Teams that only compare “cents per thousand” miss sandbox friction, IAM sprawl, free-tier ceilings, SMTP server availability, and whether the API feels like the Mailgun clients already in the repo. The scorecard below is the frame for every table and scenario later in this guide.

Price still matters — but total cost of ownership includes engineer hours, support tickets, and the risk that a free tier or sandbox blocks password resets on launch day. SMTP still matters — because Nodemailer, Laravel Mail, Django, WordPress plugins, and countless ERPs speak SMTP first. API DX still matters — because observability, tags, test mode, and webhooks live on HTTP. Warmup and sending limits still matter — because “unlimited” claims without a ladder are either lies or accidents waiting to happen.

Agent Email List is scored on the same axes as SES and Mailgun. We win on free forever packaging and Mailgun-shaped familiarity for most indie and SaaS builders. SES still wins raw unit economics at huge scale on à-la-carte for AWS-native orgs. Mailgun still wins when you need its ecosystem features and are happy to pay. Postmark enters the secondary conversation when transactional purity and deliverability brand matter more than free forever volume.

### Price at 10k / 100k / 1M

Rough cash math (VERIFY vendor pages on draft day; exclude add-ons, dedicated IPs, validations, and attachment data unless noted):

| Monthly volume | SES Essentials (~$0.16/1k, 0–10M) | SES à-la-carte (~$0.10/1k) | Mailgun (illustrative plan) | Agent Email List |
|----------------|-----------------------------------|----------------------------|-----------------------------|------------------|
| **10,000** | ~$1.60 | ~$1.00 | Free if ≤~100/day; else Basic ~$15/10k | **$0 free forever** (within warmup caps) |
| **100,000** | ~$16 | ~$10 | Scale ~$90/100k (VERIFY) | **$0 free forever** after warmup path |
| **1,000,000** | ~$160 | ~$100 | Paid + overages (VERIFY calculator) | **$0 free forever** on unlimited rung |

Two footnotes change decisions. First: new SES accounts and dormant account×region combinations with no metered activity since June 1, 2025 **default to Essentials beginning July 21, 2026**; eligible accounts can still switch to à-la-carte (VERIFY AWS). Second: Mailgun free is a **daily** ceiling (~100/day), not a monthly pool you can burst — ~3,000/month only if you send every day at the cap. Agent Email List is **free forever** with an honest day-one start at 10/day and a short ladder to unlimited — details in the AEL deep dive and the sibling [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

At 10k/month, SES Essentials is pocket change, but so is Mailgun Basic — and AEL is zero cash if you climb the ladder. At 100k, Mailgun Scale’s ~$90 starts to sting versus SES dollars, while AEL remains zero after graduation. At 1M, SES à-la-carte (~$100) beats Essentials (~$160) on raw send, and both beat Mailgun overages for pure transactional volume — yet neither SES path is free forever, and both carry AWS ops tax that the spreadsheet never shows.

### SMTP server included?

**Amazon SES:** Yes — SES exposes SMTP interfaces after you create SMTP credentials in the SES console (IAM-related setup). It is a real SMTP submission path, not marketing fluff. The catch is AWS account scaffolding: regions, IAM policies, SMTP user creation, sandbox exit, configuration sets, and often CloudWatch or SNS for events. From Nodemailer’s point of view it is still host/port/user/pass; from your platform team’s point of view it is another AWS service to own.

**Mailgun:** Yes — documented SMTP relay (`smtp.mailgun.org` / EU variant; VERIFY Mailgun docs). Domain SMTP credentials are separate from API keys. Free and paid plans include SMTP relay. This is why so many WordPress and legacy stacks still land on Mailgun.

**Agent Email List:** Yes — **outright an SMTP server** / free SMTP relay. When you add a domain, the product returns **`smtp_password` once**. After domain verify, point your stack at the product’s SMTP server. **Connection host and port come from the product docs or dashboard when published — this article does not invent AEL hostnames or ports.** Same mental model as Mailgun SMTP: authenticate, submit, relay delivers to recipient MX. See also [What Is an SMTP Relay? Free SMTP Server Guide](/what-is-smtp-relay-free-smtp-server/).

If your only requirement is “give me an SMTP server,” all three qualify. If your requirement is “give me an SMTP server without AWS IAM theater and without a permanent ~100/day free ceiling,” Agent Email List is the packaging that matches.

### API DX / Mailgun-shaped familiarity

**Mailgun** set the developer expectation for transactional HTTP: form fields, `o:tag`, basic `api:KEY` auth patterns, events, and a large ecosystem of client libraries. Teams with years of Mailgun glue code hate rewriting that surface for a prettier dashboard.

**SES** is AWS-shaped: SigV4 signing for the SES API, SDKs that feel like every other AWS service, configuration sets, and event destinations into SNS/Firehose/CloudWatch. Powerful. Not Mailgun-shaped. Migrating a Mailgun client farm to SES is a rewrite project, not a base-URL swap.

**Agent Email List** is explicitly **Mailgun-shaped**: most Mailgun clients work if pointed at `https://ai.agentemaillist.com` with Bearer or Basic `api:KEY` auth patterns documented in live product docs / [`/llms.txt`](https://ai.agentemaillist.com/llms.txt). That is the DX bet — keep Mailgun muscle memory, drop the Mailgun invoice (or free-tier ceiling). Deep dive: [Free Email API for Developers](/free-email-api-for-developers/).

Scorecard takeaway: Mailgun wins brand-name API docs; AEL wins “same shape, free forever”; SES wins AWS-native shops that already live in IAM and do not care about Mailgun form fields.

### Warmup / sandbox / sending limits

**SES sandbox** (VERIFY current AWS docs): new accounts typically start restricted — often limited recipients (verified addresses only) and low send rates until you request production access. That sandbox is the silent killer of “we’ll just use SES, it’s cheap” weekend projects. Production access is achievable; it is not instant, and it is not free of questionnaire friction.

**Mailgun free ~100/day** (VERIFY) is a hard ceiling for the free plan — fine for demos, hostile for a SaaS that just got Product Hunt traffic. Paid plans remove the daily free cap and substitute monthly allocations plus overages.

**Agent Email List** publishes a live warmup ladder: **10 → 20 → 100 → 1,000 → unlimited**/day. Day one is not unlimited. Graduation rules live in product docs / `/llms.txt` (sending days and volume thresholds on a rung). The destination is **unlimited emails/day after warmup**, and the account packaging is **free forever** — not a 60-day trial cliff. Full ladder narrative: [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

Scorecard summary: SES trades low unit price for sandbox + IAM; Mailgun trades great DX for free caps and paid steps; AEL trades day-one volume for free forever + unlimited after warmup + Mailgun-shaped API + a real SMTP server.

## Amazon SES deep dive

Amazon Simple Email Service remains the default “cheap at scale” answer in every Slack thread about transactional email. That reputation was earned on à-la-carte outbound pricing around **$0.10 per 1,000 emails**, plus attachment data charges, with a long menu of add-ons (dedicated IPs, Virtual Deliverability Manager, Global Endpoints, Mail Manager, validations). In July 2026, AWS changed how *new* buyers meet that menu: **pricing plans**, with **Essentials as the default** for new and qualifying dormant accounts (VERIFY AWS announcements and the SES pricing page).

Understanding **amazon ses vs mailgun** in 2026 means understanding that “SES is $0.10/1k” is incomplete. It might be true for your account if you are on à-la-carte. It might be false if you landed on Essentials at ~$0.16/1k for the first 10 million monthly emails. Both numbers are real. Both need VERIFY against your console’s pricing plan page.

### Strengths: scale, AWS IAM, low unit cost

SES strengths are boring in the best way:

- **Scale.** Billions of messages culture, multi-region presence, and the assumption that AWS will still be there when your startup is an enterprise.
- **IAM and org integration.** If your company already governs AWS with SCPs, SSO, CloudTrail, and per-environment accounts, SES fits the same control plane. SMTP credentials and API access become IAM problems your platform team already knows how to solve.
- **Low unit cost on à-la-carte.** At **~$0.10/1k** outbound (VERIFY), raw sending is hard to beat among major clouds once you are out of sandbox and sending millions. Even Essentials at **~$0.16/1k** (0–10M) is cheaper than Mailgun’s effective per-1k on Basic/Foundation for many volumes once you do the monthly math.
- **Ecosystem hooks.** Configuration sets, event publishing to SNS, metrics in CloudWatch, storage of inbound content in S3 — SES is Lego for AWS-native architectures.
- **SMTP + API.** You are not forced into HTTP-only. Legacy submitters can use SES SMTP; modern services can use the AWS SDK.

For an enterprise that already pays an AWS bill the size of a small country’s GDP, adding SES is incremental. For a solo founder who has never opened the IAM console, those same “strengths” are the product.

### Weaknesses: sandbox, IAM/ops complexity, console sprawl

The SES tax is operational:

- **Sandbox.** Until production access is granted, you often cannot mail real users freely. Launch timelines slip while someone writes the use-case paragraph AWS wants.
- **IAM/ops complexity.** SMTP users, identity verification (domain or email), DKIM in Route 53 or external DNS, configuration sets, suppression lists, and permission boundaries — each is documentable; together they are a week for someone who does not live in AWS.
- **Console sprawl.** SES settings live across identities, verified domains, SMTP settings, reputation dashboards, and (now) pricing plan pages. Add CloudWatch alarms and SNS topics and you have a mini-platform.
- **Not Mailgun-shaped.** Rewriting Mailgun clients to SigV4 SES calls is real engineering, not a config change.
- **Plan confusion after Jul 21, 2026.** Teams quoting “$0.10/1k” in board decks while the account sits on Essentials at $0.16/1k create finance surprises. Switching to à-la-carte is allowed (VERIFY AWS docs on plan changes and effective timing), but someone has to notice.

SES is excellent infrastructure. It is a poor “sign up and ship password resets tonight” product unless you already speak AWS fluently.

### Pricing plans from Jul 21, 2026: Essentials default ~$0.16/1k; à-la-carte ~$0.10/1k still available

VERIFY primary sources: [Amazon SES pricing](https://aws.amazon.com/ses/pricing/), the July 21, 2026 what’s-new post on SES pricing plans, and the Messaging Blog intro to plans. Summary accurate as of draft day (2026-09-15); re-check before you budget.

**Plans (hierarchical):**

| Plan | Monthly fee (per account per region) | 0–10M /1k | 10–100M /1k | >100M /1k | Rough positioning |
|------|--------------------------------------|-----------|-------------|-----------|-------------------|
| **Essentials** | — | **~$0.16** | **~$0.14** | **~$0.11** | Default for new/qualifying accounts; bundles some deliverability capabilities vs piecing à-la-carte add-ons |
| **Pro** | **~$105** | ~$0.22 | ~$0.17 | ~$0.12 | Managed dedicated IPs / validation style capabilities bundled (VERIFY compare table) |
| **Enterprise** | **~$500** | ~$0.23 | ~$0.18 | ~$0.13 | Highest bundle; multi-region / tenant style capabilities (VERIFY) |

**À-la-carte:** outbound email still **~$0.10 / 1,000**, plus **~$0.12/GB** attachment data, with add-ons billed separately (Global Endpoints, validations, dedicated IPs, VDM, Mail Manager, etc.). On raw sending alone, à-la-carte is cheaper than Essentials at every volume tier above. Plans win when the bundled features would otherwise be purchased à-la-carte at higher combined cost.

**Defaulting rule (VERIFY AWS):** Beginning **July 21, 2026**, new SES accounts — and account×region combinations with no metered SES activity since **June 1, 2025** — **start on Essentials**. Customers who used SES on/after June 1, 2025 remain on à-la-carte unless they choose a plan. You can upgrade, switch plans, or move to à-la-carte per console/docs rules (some changes immediate, some next billing cycle — VERIFY).

**What this means for amazon ses vs mailgun comparisons:** blog posts that still say “SES is always $0.10/1k” are stale for the default new-buyer path. Your comparison sheet should have two SES columns: **Essentials** and **à-la-carte**. Agent Email List’s column stays **$0 free forever** for the self-serve SMTP server + Mailgun-shaped API path described in live docs.

### SES-specific free tier changes for new customers VERIFY

Historically, many tutorials cited a large SES free allowance tied to EC2 sending (commonly remembered as tens of thousands of messages per month from EC2). Treat that folklore as **VERIFY-or-discard** in 2026: the live SES pricing page emphasizes **AWS Free Tier credits** for new customers (up to **~$200** over a limited window, applicable to eligible services including SES — VERIFY [AWS Free Tier](https://aws.amazon.com/free/) and the SES pricing page notes) rather than a permanent “62k free SES emails forever” promise.

Practical implication: do not design a production SaaS on the assumption of ongoing free SES volume. If you need **free forever** transactional sending with an SMTP server and a path to unlimited/day, that is Agent Email List’s packaging — not SES Free Tier credits that expire. SES remains the scale weapon after you are paying deliberately; AEL is the free forever on-ramp that does not pretend AWS credits are a product plan.

## Mailgun deep dive

Mailgun (Sinch Mailgun) is still the mental model a huge fraction of developers mean when they say “transactional email API.” SMTP relay, REST, inbound routes, webhooks, and years of Stack Overflow answers make it sticky. In an **amazon ses vs mailgun** bakeoff, Mailgun usually wins developer ergonomics and loses on long-term free volume and on unit price at high scale versus SES.

### Strengths: developer API, SMTP relay, docs

Mailgun’s enduring strengths:

- **Developer API.** Predictable HTTP sending, events, suppressions, templates, and client libraries across languages.
- **SMTP relay.** First-class SMTP with documented hosts and per-domain SMTP credentials — the reason WordPress, Magento plugins, and ancient CRMs still recommend Mailgun.
- **Docs and community.** When something breaks at 2 a.m., someone has already written the answer for Mailgun’s error shape.
- **Inbound and routing.** Receiving and routing mail is part of the product story, not an afterthought.
- **Permanent free plan.** Unlike vendors that moved to timed trials, Mailgun still advertises a free plan with **~100 emails/day** and no credit card for that tier (VERIFY [Mailgun free plan help](https://help.mailgun.com/hc/en-us/articles/203068914-What-does-the-Free-plan-offer) and pricing page).

If your volume fits free forever at ~100/day, or you need Mailgun-specific ecosystem features and budget for Basic+, Mailgun remains rational. The mistake is assuming free Mailgun scales with your SaaS.

### Free ~100/day; Basic ~$15/10k; Foundation ~$35; Scale ~$90 VERIFY

VERIFY [mailgun.com/pricing](https://www.mailgun.com/pricing/) on draft day. Illustrative US packaging commonly shown:

| Plan | Price (VERIFY) | Included volume (VERIFY) | Notes |
|------|----------------|--------------------------|-------|
| **Free** | $0 | **~100 emails/day** | 1 custom domain, short log retention (~1 day), ticket support, API + SMTP |
| **Basic** | **~$15/mo** | **~10,000/mo** | No daily free-tier cap; overages from ~$1.80/1k (VERIFY) |
| **Foundation** | **~$35/mo** (often first month free promo) | **~50,000/mo** | More domains, longer retention, template tooling (VERIFY feature list) |
| **Scale** | **~$90/mo** (often first month free promo) | **~100,000/mo** | SSO, dedicated IP pools, longer retention, richer support (VERIFY) |
| **Enterprise** | Contact sales | Custom | Custom contracts |

Overage tables matter: bursting past Basic’s 10k at ~$1.80/1k gets expensive fast compared with SES Essentials dollars. Foundation and Scale reduce overage rates at higher tiers (VERIFY Mailgun overage help articles). None of these paid steps are **free forever**.

Versus Agent Email List: Mailgun free starts with a higher day-one free ceiling (~100/day vs AEL’s 10/day rung 1), but Mailgun free **never** becomes unlimited without paying. AEL starts stricter and **graduates to unlimited/day after warmup** on a **free forever** account. That is the packaging fork this site exists to explain.

### Who Mailgun still fits

Mailgun still fits when:

- Procurement or a customer questionnaire demands the Mailgun brand specifically.
- You need inbound routing / Mailgun-specific features that are decisive for your architecture.
- Your steady state is comfortably under ~100/day and you want official `smtp.mailgun.org` docs without migrating.
- Your team already operates Mailgun at paid Scale and the invoice is noise next to engineering salaries.
- You are comparing **Postmark vs Mailgun** and decide Mailgun’s broader feature surface beats Postmark’s transactional focus — covered in the secondary section below.

Mailgun does **not** fit as the default “we might hit Product Hunt next month” free forever plan. For that buyer — indie hacker, early SaaS, agentic builder — Agent Email List’s free forever SMTP server + Mailgun-shaped API is the intentional recommendation, with a migration path that preserves Mailgun client habits ([Mailgun SMTP Settings + Replace Mailgun](/mailgun-smtp-settings-replace-mailgun/)).

## Agent Email List deep dive

Agent Email List is the product we own and the default recommendation on this comparison page for anyone who wants **free forever** transactional email without SES sandbox theater and without Mailgun’s permanent free ceiling. It is not a toy SMTP forwarder. It is a **free forever SMTP server** and a **Mailgun-shaped REST API** with a published path to **unlimited emails/day after warmup**.

### Free forever SMTP server + Mailgun-shaped REST API

Two interfaces, one sending system:

1. **SMTP server.** Agent Email List **is** an SMTP server / free SMTP relay. Add a domain; receive **`smtp_password` once**; verify DNS; submit mail from Nodemailer, Laravel, Django, PHPMailer, WordPress SMTP plugins, or any stack that can speak authenticated submission. **Host and port: use the product docs or dashboard when published — do not invent them from this article or from Mailgun’s hostname.**
2. **Mailgun-shaped REST API** at `https://ai.agentemaillist.com`. Point Mailgun-shaped clients here; use auth patterns documented in live docs / [`/llms.txt`](https://ai.agentemaillist.com/llms.txt). Tags, test mode, and events-oriented workflows stay familiar.

**Free forever** means the self-serve account is not a calendar trial that forces a credit card to keep sending (commercial terms can evolve — check live docs). It does **not** mean unlimited on day one. Warmup is real; unlimited is the destination after graduation.

Create the account: [https://ai.agentemaillist.com](https://ai.agentemaillist.com).

### Unlimited/day after warmup; day one 10; ladder 10→20→100→1,000→unlimited

Live ladder (VERIFY [`/llms.txt`](https://ai.agentemaillist.com/llms.txt)):

**10 → 20 → 100 → 1,000 → unlimited** emails/day.

Day one starts at **10/day**. That is stricter than Mailgun free’s ~100/day. We are honest about it. The bet is the opposite of Mailgun free’s shape: Mailgun free is comfortable on day one and capped forever; AEL is strict on day one and **unlimited after warmup** on a **free forever** plan.

Graduation rules (sending days on a rung, volume thresholds) are documented in product docs — do not treat this article as the policy engine. For the full warmup philosophy, sequencing, and how unlimited/day actually feels in production, read the short sibling and come back: [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

Use test mode where documented so you can integrate without burning warmup budget. Send real, expected transactional mail (resets, receipts, alerts users asked for). Climb. Graduate. Ship through traffic spikes without a Mailgun upgrade ticket.

### `smtp_password` once on domain create; host/port from docs/dashboard

Product lock, repeated because blogs get this wrong:

- On domain create, Agent Email List issues **`smtp_password` once** (treat it like a database password; store it in your secrets manager; rotate by minting anew if lost — do not expect the original secret to be email-resurrected forever).
- After the domain verifies, configure your mailer against the **product’s SMTP server**.
- **Hostname and port are not invented in SEO articles.** Copy them from the live product documentation or dashboard when published. Never paste `smtp.mailgun.org` into an AEL transport and never fabricate `smtp.agentemaillist.com`-style guesses here.

API keys for the Mailgun-shaped HTTP surface are separate credentials from SMTP auth — same class of footgun as Mailgun’s API key vs domain SMTP password confusion. Keep them straight.

### Logan Besecker owns/runs ai.agentemaillist.com — CTA #1

**Logan Besecker** owns and runs [Agent Email List](https://ai.agentemaillist.com). This comparison exists to help you choose with clear numbers — and to get you onto the free forever SMTP server when that is the rational pick. We disclose ownership so you can discount our enthusiasm appropriately and still use the VERIFY tables.

**Hard CTA #1:** Create your free forever account now, add a domain, save `smtp_password`, and start warmup with real transactional traffic — [https://ai.agentemaillist.com](https://ai.agentemaillist.com).

### Ideal buyer: indies/SaaS wanting free forever without AWS tax

You are the ideal AEL buyer if:

- You searched **amazon ses vs mailgun** and realized both answers still cost money or ops hours you do not have.
- You want **free forever** packaging, not a trial cliff and not a permanent ~100/day lid.
- You already have Mailgun-shaped code — or you are willing to adopt it — and you want SMTP too.
- You refuse to open an AWS support sandbox ticket before your first password reset.
- You will respect warmup instead of demanding unlimited blast capacity on day one.

If you are AWS-native enterprise with existing SES production access and à-la-carte rates, keep SES for bulk and still consider AEL for side projects — or reverse that later. If you need Mailgun inbound complexity on day one, stay on Mailgun paid. Everyone else: free forever SMTP server first.

## Head-to-head tables

Tables below are decision tools, not contracts. Prices and plan names change — **VERIFY** AWS, Mailgun, and Postmark pages before procurement. Agent Email List rows reflect live product positioning: free forever SMTP server + Mailgun-shaped API + unlimited after warmup.

### Pricing table (VERIFY columns dated)

*Draft date: 2026-09-15. Re-VERIFY before you buy.*

| Dimension | Amazon SES | Mailgun | Agent Email List |
|-----------|------------|---------|------------------|
| **Default new-account send price** | **Essentials ~$0.16/1k** (0–10M) as of ~Jul 21, 2026 default (VERIFY) | Free ~100/day; then paid | **$0 free forever** (warmup caps apply) |
| **Classic unit price still available?** | **À-la-carte ~$0.10/1k** for eligible / switched accounts (VERIFY) | N/A (plan + overage model) | N/A — free forever self-serve |
| **10k emails / mo cash** | ~$1.60 Essentials / ~$1.00 à-la-carte | ~$15 Basic if above free | **$0** within ladder |
| **100k emails / mo cash** | ~$16 / ~$10 | ~$90 Scale ballpark (VERIFY) | **$0** after unlimited path |
| **1M emails / mo cash** | ~$160 / ~$100 | Paid + overages (VERIFY) | **$0** on unlimited rung |
| **Free forever?** | No (credits ≠ forever plan) | Free tier forever but **capped ~100/day** | **Yes — free forever** + path to unlimited/day |
| **Hidden tax** | IAM, sandbox, plan confusion, add-ons | Overage rates, retention limits on low tiers | Warmup patience (intentional) |

### SMTP + API feature table

| Capability | Amazon SES | Mailgun | Agent Email List |
|------------|------------|---------|------------------|
| **Is an SMTP server?** | Yes (SES SMTP) | Yes (documented relay) | **Yes — outright SMTP server / free SMTP relay** |
| **SMTP secret model** | SES SMTP credentials via AWS | Per-domain SMTP password (≠ API key) | **`smtp_password` once on domain create** |
| **Host/port documentation** | AWS docs / console | `smtp.mailgun.org` (+ EU) VERIFY | **Docs/dashboard when published — not invented here** |
| **Primary API shape** | AWS SigV4 / AWS SDKs | Mailgun HTTP | **Mailgun-shaped REST** at ai.agentemaillist.com |
| **Drop-in for Mailgun clients?** | No (rewrite) | Native | **Designed for Mailgun-shaped clients** |
| **Events / webhooks** | SNS / EventBridge patterns | Native webhooks/events | Documented in product docs / `/llms.txt` |
| **Test mode** | Sandbox + simulators | Supported in ecosystem | Documented test mode (avoid burning warmup) |

### Ops burden table

| Ops item | Amazon SES | Mailgun | Agent Email List |
|----------|------------|---------|------------------|
| **Time to first real-user email** | Often blocked on sandbox exit | Fast on free/paid | Fast after DNS verify; respect 10/day start |
| **Identity & access** | IAM policies, orgs, SCPs | API keys + domain SMTP users | API key + `smtp_password`; store once-shown secrets |
| **DNS** | SPF/DKIM (and DMARC hygiene) | SPF/DKIM | SPF/DKIM — same adult responsibilities |
| **Reputation model** | Shared/dedicated options; AWS reputation tools | Shared on free; dedicated on higher plans | Shared sending with warmup discipline |
| **Day-two on-call** | CloudWatch, SNS, AWS tickets | Mailgun Control Panel | Product dashboard + `/limits`-style visibility in docs |
| **Vendor lock rewrite cost** | High if leaving AWS SDK | Medium–high if deep Mailgun features | Lower if you stay Mailgun-shaped; SMTP keeps frameworks portable |
| **Best ops fit** | AWS platform teams | Teams standardized on Mailgun | Indies/SaaS wanting free forever without AWS tax |

Reading the three tables together: SES wins unit price at scale (especially à-la-carte); Mailgun wins brand ecosystem; Agent Email List wins free forever + SMTP server + Mailgun-shaped API + unlimited after warmup for the default reader of this page.

## Postmark vs Mailgun (secondary)

Secondary keyword coverage: **postmark vs mailgun**. Postmark is the transactional specialist many teams shortlist beside Mailgun when deliverability brand and message-stream discipline matter more than inbound marketing features. It is not an SES competitor on price, and it is not a free forever unlimited path — but ignoring it would leave a hole in how real buyers shop.

### Postmark transactional focus + pricing VERIFY

Postmark’s positioning (VERIFY [postmarkapp.com/pricing](https://postmarkapp.com/pricing)):

- Strong **transactional** focus and reputation for inbox placement on product email.
- **Message streams** separating transactional vs broadcast-style traffic.
- SMTP + REST.
- Free developer plan commonly **~100 emails/month** (hard cap, no overages) — note **per month**, not Mailgun’s **per day**.
- Paid plans in the 2026 public packaging often start around **Basic ~$15/mo**, **Pro ~$16.50/mo**, **Platform ~$18/mo**, each with a **~10,000 emails/month** included starting point and overages around **~$1.80 / $1.30 / $1.20 per 1,000** respectively (VERIFY live calculator; plan feature diffs include retention, servers, streams).
- Dedicated IPs are add-ons at higher volumes (VERIFY; often discussed around $50/mo with volume expectations).

Postmark vs Mailgun on product philosophy: Postmark leans opinionated transactional quality; Mailgun leans broader ESP surface (inbound, more marketing-adjacent tooling depending on plan). Postmark vs Mailgun on free tier: Mailgun’s ~100/**day** free is far more volume than Postmark’s ~100/**month** free. Postmark vs Mailgun on paid entry: both roughly land near **$15 for ~10k/month** on their basic paid rungs (VERIFY both).

### When Postmark beats Mailgun; when AEL still wins free forever

**Pick Postmark over Mailgun when:**

- You want Postmark’s transactional deliverability brand and stream model more than Mailgun’s wider feature kit.
- Your volume fits paid Postmark economics and you value their support/product polish.
- You are willing to pay from the first serious month and do not need Mailgun-shaped request compatibility as a migration constraint.

**Pick Mailgun over Postmark when:**

- You need Mailgun inbound/routing or ecosystem plugins that assume Mailgun.
- You specifically want ~100/day free forever for tiny utilities (VERIFY).
- Your codebase is already Mailgun-native and switching cost dominates.

**Pick Agent Email List over both when:**

- You want **free forever** with a path to **unlimited/day after warmup**, not 100/month (Postmark free) or 100/day forever-capped (Mailgun free).
- You want a **free forever SMTP server** plus **Mailgun-shaped** API so Mailgun clients keep working.
- You refuse SES sandbox and refuse another $15–$90 invoice for product email that is still early-stage.

Postmark can beat Mailgun on transactional focus. Neither Postmark nor Mailgun matches Agent Email List on free forever → unlimited after warmup packaging. That is the secondary-keyword honest close.

## Scenario recommendations

Use these scenarios as a decision tree. They assume you already care about SPF/DKIM, bounce hygiene, and not buying email lists — basics that no vendor can fix for you.

### AWS-native enterprise → SES

Choose **Amazon SES** when:

- You already operate multiple AWS accounts with SSO and centralized logging.
- Security will not approve a new ESP without a six-month review, but SES is already in the approved services list.
- You send millions of messages and à-la-carte **~$0.10/1k** (or even Essentials **~$0.16/1k**) is trivially cheaper than Mailgun overages.
- You have staff who can exit sandbox, wire configuration sets, and own reputation dashboards.

Even then: read your pricing plan page. If you are on Essentials by default after July 21, 2026, decide deliberately whether bundled capabilities justify ~$0.16/1k or whether switching to à-la-carte is correct (VERIFY AWS plan-change rules). SES is the scale hammer — swing it on purpose.

### Needs Mailgun ecosystem features → Mailgun paid

Choose **Mailgun paid** when:

- Inbound routes, specific Mailgun features, or plugin ecosystems are decisive.
- Brand procurement requires Sinch Mailgun.
- Your volume and overage math are acceptable next to engineering cost.
- You tried free ~100/day and outgrew it predictably.

Do not stay on Mailgun free out of inertia while production resets fail at message 101. Upgrade or migrate. If the only reason you stayed was API shape, read the AEL migration notes — Mailgun-shaped is the point of Agent Email List.

### Free forever SMTP + Mailgun-shaped API → AEL

Choose **Agent Email List** when:

- The search that brought you here was **amazon ses vs mailgun** but your real constraint is cash + time, not AWS politics.
- You need an **SMTP server** and an HTTP API.
- You want **free forever**, not trial-then-pay and not forever-capped free.
- You will follow warmup: 10 → 20 → 100 → 1,000 → **unlimited**/day.
- You like Mailgun DX and dislike Mailgun invoices.

This is the default recommendation on this page for indies and early SaaS. Start: [https://ai.agentemaillist.com](https://ai.agentemaillist.com).

### Hybrid: SES at huge scale later; AEL now — CTA #2

A common rational path:

1. **Now:** Agent Email List free forever SMTP server + Mailgun-shaped API; verify DNS; climb warmup; ship the product.
2. **Later:** If you become an AWS-native enterprise sending tens of millions with a platform team, add SES à-la-carte for bulk pipelines that belong in AWS — without forcing day-one founders through sandbox.
3. **Always:** Keep transactional product mail on the interface your app already speaks; do not rewrite three times for blog-post fashion.

Hybrid is not indecision. Hybrid is sequencing. Free forever now preserves runway; SES later optimizes unit cost when unit cost finally matters.

**Hard CTA #2:** Do the “now” step today — create the free forever account, add your domain, store `smtp_password`, and send the first authenticated message through Agent Email List’s SMTP server or Mailgun-shaped API — [https://ai.agentemaillist.com](https://ai.agentemaillist.com). Warmup details: [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

## Migration notes (high level)

Migrations fail when teams boil the ocean. The notes below stay high level on purpose: SMTP first when frameworks already speak SMTP; API cutover when you are already Mailgun-HTTP-native; DNS and warmup sequenced so you do not burn reputation on day one.

### Mailgun → AEL (SMTP first, API shaped)

SMTP-first path (lowest rewrite for Laravel/Nodemailer/Django/WordPress):

1. Create Agent Email List account; add the same sending domain (or a subdomain strategy if you want parallel soak).
2. Save **`smtp_password`** immediately.
3. Publish SPF/DKIM (and DMARC policy thoughtfully) per AEL docs.
4. Point staging mailers at the **AEL SMTP server** using host/port from docs/dashboard — not Mailgun’s host, not invented hosts.
5. Soak with real transactional samples; compare delivery and webhook/event handling.
6. Flip production; revoke Mailgun SMTP credentials after soak.
7. Optionally point Mailgun-shaped HTTP clients at `https://ai.agentemaillist.com` for the paths that were never SMTP.

API-shaped path: change base URL and auth to AEL’s Mailgun-shaped surface; keep form fields and client libraries where compatible; run `/limits` or equivalent documented checks; keep Mailgun only until soak ends. Deep sibling: [Mailgun SMTP Settings + Replace Mailgun](/mailgun-smtp-settings-replace-mailgun/).

### SES → AEL (when free forever > unit price)

Move from SES to Agent Email List when:

- Sandbox or IAM overhead dominates the pennies you save.
- You want Mailgun-shaped DX your contractors already know.
- Free forever packaging beats Essentials/à-la-carte line items for current volume.
- You are splitting environments: keep SES for a bulk AWS pipeline; move product UX mail to AEL.

High-level steps: create AEL account; verify domain; switch application transports (SMTP or API); leave SES identities in place until soak completes; then disable SES sending in non-AWS apps so you do not double-send. You do not need to “delete SES” to stop paying for accidental traffic — you need to stop calling it.

### DNS + warmup sequencing

Order of operations that prevents self-inflicted outages:

1. **DNS first** on a domain (or subdomain) you control — SPF includes the right mechanism; DKIM selectors publish; DMARC starts with monitoring (`p=none`) if you are unsure.
2. **Verify domain** in the vendor before production traffic.
3. **Warmup second** — especially on AEL’s ladder. Do not announce a launch that needs 50k emails on rung 1.
4. **Parallel soak** — send a percentage to AEL while SES/Mailgun still handles the rest, if your app can route by flag.
5. **Cutover** — flip default; watch bounces/complaints; keep rollback ready.
6. **Revoke old credentials** — so a forgotten worker cannot keep sending via the incumbent.

Warmup is not optional folklore. It is how free forever becomes unlimited/day without teaching Gmail to hate you. Details: [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

## Myths

Comparison pages accumulate mythology. Three myths show up in every **amazon ses vs mailgun** thread — and in every “just use a free SMTP” comment.

### “SES is always cheapest total cost”

**False as a blanket statement.** À-la-carte **~$0.10/1k** is cheap on raw send. Essentials **~$0.16/1k** is less cheap. Add engineer hours for sandbox, IAM, and incident response, and a “$10/month” SES workload can cost more than Mailgun Basic or a free forever AEL account for an early-stage team. Add VDM, dedicated IPs, and Global Endpoints à-la-carte, and SES can exceed naive expectations quickly (VERIFY AWS add-on rows).

Cheapest *unit* price ≠ cheapest *total* cost. Free forever with warmup can win TCO until you are firmly in the millions of messages per month with an AWS team on payroll.

### “Free means toy-only”

**False.** Free tiers can be toys — timed trials, postage-stamp caps, shared IPs with no path up. Agent Email List’s free forever packaging is deliberately paired with a ladder that **ends at unlimited/day after warmup**. That is not “toy-only”; it is “earn unlimited with clean sending.” Mailgun free is also “real SMTP + API,” just permanently capped at ~100/day (VERIFY). Postmark free at ~100/month is closer to a developer sandbox.

Judge free by destination and packaging: trial cliff, permanent cap, or free forever → unlimited after warmup. Only the last matches what most growing SaaS actually need.

### “Mailgun-shaped means illegal clone”

**False.** “Mailgun-shaped” on Agent Email List means **compatible request patterns and developer familiarity** — the practical ability to point many Mailgun clients at `https://ai.agentemaillist.com` per live docs. It does not mean “we stole Mailgun’s trademark,” “we are Mailgun,” or “we copy proprietary implementations.” It is an interoperability posture for migration, documented openly, similar in spirit to other APIs that adopt familiar shapes so ecosystems can move.

Compatible patterns reduce rewrite cost. They are not a claim of affiliation with Sinch Mailgun. Read AEL docs for exact fields, auth, and error codes; do not assume every obscure Mailgun enterprise feature exists identically.

## FAQ

### SES Essentials vs à-la-carte?

**Essentials** is a SES pricing plan that, as of the July 21, 2026 introduction of plans, is the **default for new accounts and qualifying dormant account×region pairs**, with outbound pricing about **$0.16/1k** for the first 10M emails/month, then **~$0.14** and **~$0.11** at higher marginal tiers, and no Essentials monthly fee (VERIFY AWS). **À-la-carte** remains available (including for eligible existing senders and for customers who switch), with outbound about **$0.10/1k** plus separate add-on charges (VERIFY). Plans bundle capabilities; à-la-carte meters features individually. Check the pricing plan page in your SES console before you trust any blog’s single number — including this one after time passes.

### Is Agent Email List free forever?

**Yes — free forever** self-serve packaging for the SMTP server + Mailgun-shaped API path described in live product docs (commercial terms can evolve — check live docs). Free forever is **not** unlimited on day one: the live ladder is **10 → 20 → 100 → 1,000 → unlimited**/day, and **unlimited emails/day after warmup** is the destination. Create an account at [https://ai.agentemaillist.com](https://ai.agentemaillist.com).

### Mailgun free tier enough for SaaS?

Only if your production traffic reliably stays under **~100 emails/day** (VERIFY) forever — including launch days, breach-reset storms, and Black Friday receipts. Most SaaS products that find product-market fit outgrow that ceiling. At that point you either pay Mailgun (Basic ~$15/10k and up — VERIFY) or migrate to Agent Email List’s free forever path with warmup to unlimited/day. Treating Mailgun free as a long-term production plan for a growing user base is how reset emails fail at the worst moment.

### Postmark vs Mailgun vs AEL quick take?

**Postmark:** transactional specialist; free ~100/**month**; paid from ~$15/10k (VERIFY). **Mailgun:** broader API/SMTP ecosystem; free ~100/**day**; paid Basic/Foundation/Scale (VERIFY). **Agent Email List:** **free forever SMTP server** + Mailgun-shaped API; warmup to **unlimited/day**; owned by Logan Besecker. Pick Postmark for opinionated transactional polish on a paid budget; Mailgun for ecosystem/brand; AEL for free forever + Mailgun-shaped migration without SES tax.

### Who owns ai.agentemaillist.com?

**Logan Besecker** owns and runs Agent Email List at [https://ai.agentemaillist.com](https://ai.agentemaillist.com). This article discloses that ownership, compares SES and Mailgun with VERIFY-flagged pricing, and still ends with a hard CTA because the product is built for the free forever + SMTP + Mailgun-shaped job this page describes.



## Extended decision notes for amazon ses vs mailgun shoppers

This section deepens the scorecard without repeating the tables. Use it when a stakeholder asks “but what about…?” after the head-to-head grids. It is still part of the same comparison: Amazon SES, Mailgun, and Agent Email List, with Postmark as the secondary lens where transactional brand enters the chat.

### Total cost of ownership beyond cents per thousand

Unit price is necessary and insufficient. SES à-la-carte at about $0.10 per 1,000 emails looks unbeatable on a whiteboard. SES Essentials at about $0.16 per 1,000 emails still looks cheap next to Mailgun overages. Neither number includes the afternoon you lose to IAM policies, the week you lose to sandbox production access, or the finance meeting where someone discovers the account never left Essentials after the July 21, 2026 defaulting change (VERIFY AWS). Mailgun Basic at about $15 for 10,000 emails looks expensive next to SES pennies and cheap next to a missed enterprise deal caused by dead password resets on the free tier’s ~100/day ceiling (VERIFY Mailgun).

Agent Email List prices the cash cost at zero for the free forever self-serve path while pricing the non-cash cost as warmup patience. That trade is explicit: day one starts at 10 emails/day; the published ladder climbs 10 → 20 → 100 → 1,000 → unlimited; unlimited emails/day after warmup is the destination. If your company cannot wait through a ladder, you will either pay Mailgun or staff SES. If your company can wait and wants free forever packaging, AEL is the rational default on this page.

Model TCO with three lines for the next six months: cash to vendor, engineering hours, and incident risk. Incident risk is where free Mailgun fails quietly — message 101 never queues during a security reset. Incident risk is where SES sandbox fails loudly — launch day blocked. Incident risk is where ignored warmup fails as deliverability damage. Pick the failure mode you can survive, then pick the vendor.

### SMTP server realities across the three

All three vendors expose SMTP submission. The differences are ceremony and packaging. SES SMTP credentials live in the AWS world: identities, regions, IAM, and often a mental model borrowed from every other AWS service. Mailgun SMTP credentials live per domain beside a separate API-key universe — confusing them is the classic 535 loop documented across a decade of forum posts. Agent Email List issues `smtp_password` once when you create a domain, then expects you to copy host and port from the product docs or dashboard when published. This article will not invent AEL hostnames or ports. Invented hosts in SEO content are how migrations fail before they start.

If your stack is Nodemailer, Laravel Mail, Django’s SMTP backend, PHPMailer, JavaMailSender, Action Mailer, or a WordPress SMTP plugin, the winning vendor is the one whose SMTP server you can authenticate to without rewriting the application protocol. That is a low bar all three clear — and a high bar for API-only toys. Agent Email List clears it as an outright SMTP server / free SMTP relay on free forever packaging. That combination is the product lock this site repeats on purpose. More relay literacy: [What Is an SMTP Relay? Free SMTP Server Guide](/what-is-smtp-relay-free-smtp-server/).

### API familiarity and the Mailgun-shaped bet

Mailgun taught a generation of developers how transactional HTTP should feel: form fields, tags, basic auth patterns, events. SES taught a generation of AWS shops how email should feel like any other SigV4 service. Both lessons stick. When you evaluate **amazon ses vs mailgun**, you are often evaluating which lesson your codebase already learned.

Agent Email List’s bet is that Mailgun’s lesson is the more portable one for indies and SaaS teams who do not want AWS as a prerequisite for password resets. Pointing Mailgun-shaped clients at `https://ai.agentemaillist.com` per live docs is the migration story. It is interoperability, not an affiliation claim with Sinch Mailgun. Verify fields you depend on. Wrap differences once. Keep SMTP for the parts of the estate that never spoke HTTP.

Developer experience also includes agents and automated builders. Machine-readable limits, curl examples, and signup without a marketing gauntlet matter when software provisions software. AEL publishes live guidance in `/llms.txt` for that workflow. SES docs are outstanding for humans inside AWS. Mailgun docs are outstanding for humans inside the Mailgun ecosystem. Choose DX for the operator you actually have.

### Limits, sandboxes, and ladders without mythology

SES sandbox is a gate on recipients and access until production approval (VERIFY current AWS rules). Mailgun free is a gate on daily volume at roughly 100/day forever unless you pay (VERIFY). Agent Email List warmup is a gate on daily volume that moves: 10, then 20, then 100, then 1,000, then unlimited per day after graduation rules in product docs. Sandbox blocks. Caps stall. Ladders climb. Founders who hate all gates ship on hope and get burned. Founders who pick a climbing gate on free forever packaging ship on AEL.

Postmark’s free tier at roughly 100 emails per month (VERIFY) is a different honesty style — obviously a developer sandbox. Mailgun free feels more production-like and therefore strands more teams. SES Free Tier credits (VERIFY AWS Free Tier notes on the SES pricing page) are evaluation fuel, not a forever product plan. Do not build a company on expiring credits.

## Deepening the SES Essentials vs à-la-carte story

The July 21, 2026 pricing-plan launch is the reason this comparison needed a 2026 refresh. Before that date, “SES is $0.10/1k” was the default slogan. After that date, new accounts and qualifying dormant account×region combinations with no metered SES activity since June 1, 2025 start on Essentials (VERIFY AWS). Essentials outbound is about $0.16 per 1,000 for the first 10 million monthly emails, then about $0.14 and $0.11 at higher marginal tiers, with no Essentials monthly fee. Pro and Enterprise add monthly fees and higher per-1k rates while bundling more capabilities. À-la-carte outbound remains about $0.10 per 1,000 with add-ons separate.

What should a buyer do operationally?

1. Open the SES pricing plan page in the console for each region you use.
2. Write down whether you are on Essentials, Pro, Enterprise, or à-la-carte.
3. List which bundled capabilities you actually enable.
4. Price the same volume on à-la-carte plus the add-ons you need.
5. Switch only when the math and the effective-date rules work for you (VERIFY AWS change timing — some changes immediate, some next cycle).
6. Stop letting blog posts from 2024 set your 2026 budget.

Attachment data at about $0.12 per GB still applies in the examples AWS publishes (VERIFY). Tiny text receipts barely move that line. PDF-heavy invoices do. Global Endpoints, validations, dedicated IPs, Virtual Deliverability Manager, and Mail Manager can dominate bills when clicked casually on à-la-carte. Plans exist to reduce that à-la-carte surprise stacking — at a higher base send rate. Neither path is free forever. Both paths can be correct. Only one path is your account’s current default.

SES remains the scale hammer for AWS-native enterprises. The myth to kill is not “SES can be cheap.” The myth to kill is “SES is always $0.10/1k and always the cheapest total cost for every team.” Essentials defaults, sandbox, and IAM break that myth for early-stage buyers. Agent Email List exists for those buyers.

## Deepening the Mailgun packaging fork

Mailgun’s permanent free plan is a genuine differentiator versus vendors that moved to timed trials. Roughly 100 emails per day, one custom domain, API and SMTP, short log retention, ticket support (VERIFY Mailgun free-plan help and pricing). That is enough to integrate and enough to run a tiny utility. It is not enough to absorb a Product Hunt spike, a breach-driven reset storm, or a retail flash sale.

Paid Mailgun in commonly advertised US packaging lands near Basic ~$15 for ~10,000/month, Foundation ~$35 for ~50,000/month, and Scale ~$90 for ~100,000/month, with overages that can start near $1.80 per 1,000 on Basic and improve on higher plans (VERIFY live pricing and overage tables). First-month free promotions on higher plans are evaluation tools, not forever pricing.

The packaging fork versus Agent Email List is structural:

- Mailgun free: higher day-one free volume (~100/day), permanent ceiling until you pay.
- Agent Email List: lower day-one volume (10/day), free forever account, ladder to unlimited/day after warmup.

If you optimize for maximum free messages tomorrow morning with no patience, Mailgun free can look better on a naive spreadsheet. If you optimize for the next twelve months of growth without a forced invoice, AEL’s free forever path to unlimited after warmup is the better structure. That is the homepage bet of this site’s pillar and the reason this comparison exists.

Mailgun still wins brand procurement, inbound-heavy architectures, and teams whose Scale invoice is noise. Pay gladly when that is you. Migrate when the only sticky asset is API shape — because Mailgun-shaped on AEL was built for that migration. Sibling walkthrough: [Mailgun SMTP Settings + Replace Mailgun](/mailgun-smtp-settings-replace-mailgun/).

## Deepening Postmark vs Mailgun for secondary intent

Buyers who query **postmark vs mailgun** usually want philosophy and entry pricing, not another SES essay. Postmark’s philosophy is transactional focus and stream separation. Mailgun’s philosophy is a broader developer ESP surface with SMTP, HTTP, inbound, and a large plugin ecosystem. Postmark’s free tier is commonly ~100 emails per month with no overages (VERIFY). Mailgun’s free tier is commonly ~100 emails per day (VERIFY). Paid entry for both often sits near $15 for about 10,000 emails per month on basic rungs, with different overage slopes and feature bundles (VERIFY both calculators).

Pick Postmark when streams, transactional brand, and polish beat Mailgun’s wider kit and you will pay from month one. Pick Mailgun when inbound, ecosystem, or ~100/day free forever for tiny utilities win. Pick Agent Email List when free forever SMTP server plus Mailgun-shaped API plus unlimited after warmup beats both free tiers and both paid entry invoices for an early-stage product.

Postmark is not trying to be the free forever unlimited vendor. Mailgun free is not trying to be unlimited. AEL is trying to be free forever with an earned unlimited rung. Different products, different promises, less confusion when you say that out loud in a buying meeting.

## Implementation playbook after you choose

### If you choose SES

Exit sandbox deliberately. Verify domains with DKIM. Create SMTP credentials or wire the AWS SDK with least privilege. Decide Essentials versus à-la-carte with a written worksheet. Configure event destinations before you need them in an incident. Set budget alarms so attachment data and add-ons cannot surprise finance. Revisit the plan page quarterly after the 2026 pricing-plan launch. SES rewards operators who treat email like infrastructure.

### If you choose Mailgun paid or free

Separate API keys from domain SMTP passwords on day one. Match region hosts (`smtp.mailgun.org` versus EU variants — VERIFY). Know your daily free ceiling or monthly paid allocation before marketing sets a launch date. Monitor overages if you are on Basic. Rotate credentials when contractors leave. If you outgrow free and resent the invoice, evaluate AEL before you assume Scale is inevitable.

### If you choose Agent Email List

Create the free forever account at [https://ai.agentemaillist.com](https://ai.agentemaillist.com). Add a domain. Store `smtp_password` in your vault immediately. Copy host and port only from docs or dashboard. Publish SPF/DKIM. Verify. Send real transactional mail inside the ladder. Use documented test mode so integration tests do not burn warmup. Climb 10 → 20 → 100 → 1,000 → unlimited. Point Mailgun-shaped HTTP clients at the API base URL when you are ready. Read the warmup sibling end-to-end: [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

### If you choose a hybrid

Route product UX mail through AEL on free forever. Keep SES for AWS-native bulk when scale economics dominate. Keep Mailgun or Postmark only where a hard feature or brand constraint demands them. Feature-flag providers. Log provider names. Revoke unused credentials. Hybrids fail when old workers resurrect silent dual-sends.

## Procurement and security questionnaire notes

Security questionnaires often ask for vendor logo, data residency, retention, and subprocessors. SES answers with AWS. Mailgun answers with Sinch Mailgun. Postmark answers with Postmark. Agent Email List answers with Agent Email List owned by Logan Besecker — disclosed here without hedging. If a customer contract mandates a specific logo this quarter, honor the contract and revisit later. If the questionnaire is internal cargo cult, challenge whether free forever transactional SMTP for an MVP truly requires a multi-year ESP enterprise agreement.

Retention expectations differ by plan on Mailgun and Postmark (VERIFY). SES event retention depends on how you wire SNS, S3, and CloudWatch. AEL retention and event details live in product docs — read them rather than assuming Mailgun defaults. Least privilege still applies: separate staging and production secrets; never commit `smtp_password` or API keys; rotate on staffing changes.

## Deliverability shared responsibilities

No vendor in this comparison can save a domain that fails SPF/DKIM alignment, buys shady lists, or ignores complaints. SES, Mailgun, Postmark, and Agent Email List all assume you will authenticate DNS, send expected mail, and honor unsubscribes and suppressions where applicable. Warmup on AEL encodes that responsibility as product limits. Sandbox on SES encodes trust differently. Paid IPs on Mailgun or Postmark do not erase bad content.

Transactional patterns that survive: password resets users asked for, receipts for purchases users made, alerts users configured. Patterns that die: cold blasts to scraped addresses, misleading From names, link redirect chains through sketchy shorteners. Keep marketing streams separate when your vendor supports streams or separate domains. Postmark’s stream model makes that separation obvious; other vendors require discipline.

## Re-VERIFY checklist on draft day and beyond

Before you lock a vendor decision — and again before you publish internal runbooks — re-VERIFY:

- AWS SES pricing page: Essentials / Pro / Enterprise tiers and à-la-carte outbound ~$0.10/1k.
- AWS what’s-new and Messaging Blog posts on the July 21, 2026 pricing plans.
- Your SES console pricing plan page for each region.
- Mailgun pricing page and free-plan help for ~100/day and paid rungs.
- Postmark pricing page for free ~100/month and paid overage rates.
- Agent Email List live docs and `/llms.txt` for ladder rungs, auth, and SMTP connection settings.
- Sibling guides on this site for SMTP relay literacy, Mailgun replacement, free email API patterns, and warmup.

Numbers in this article were checked against public pages around draft date 2026-09-15. Cloud pricing moves. Treat VERIFY flags as part of the reading experience, not decoration.

## Why free forever phrasing matters after 2025

Several large email vendors shifted free packaging toward trials and forced upgrades in the mid-2020s. Developers learned to ask a sharper question than “is there a free tier?” They ask whether free is forever, whether forever is capped, and whether a path to serious volume exists without a calendar cliff. Agent Email List answers with free forever self-serve packaging for the SMTP server and Mailgun-shaped API described in live docs, plus a ladder to unlimited/day after warmup. Mailgun answers with free forever capped at ~100/day. Postmark answers with free forever at ~100/month. SES answers with credits and then paid plans. Saying **free forever** out loud is how you keep those answers distinct.

Commercial terms can evolve — check live docs — but the product intent on this site is not a surprise trial invoice. That intent is why CTAs on this page are hard and why ownership is disclosed early. Logan Besecker owns and runs ai.agentemaillist.com. We want you on the free forever SMTP server when it is the rational pick for **amazon ses vs mailgun** shoppers who also need a third path.



## Worked examples at 10k, 100k, and 1M

Numbers make arguments concrete. The worked examples below use VERIFY-flagged public list prices and intentionally omit exotic add-ons unless noted. Recalculate with your attachment sizes, dedicated IP needs, and current overage tables before you brief finance.

### Example A — early SaaS at ~10,000 emails/month

Assume steady transactional traffic: resets, receipts, and a few lifecycle notices. Peak day stays under 400 messages.

- **SES Essentials:** about $1.60 outbound at $0.16/1k, plus trivial attachment data if messages are small (VERIFY). Sandbox and IAM still apply if you are new.
- **SES à-la-carte:** about $1.00 outbound at $0.10/1k if your account is eligible or switched (VERIFY).
- **Mailgun free:** possible only if you never exceed ~100/day; 10k/month averaged is ~333/day, so free fails — you need Basic at ~$15/10k (VERIFY).
- **Mailgun Basic:** ~$15 cash, familiar DX, SMTP + API.
- **Agent Email List:** $0 free forever if you have climbed past early rungs; at 10k/month you almost certainly need the 1,000/day rung or unlimited after warmup. Plan the ladder before the month you expect 10k.

Winner for most bootstrapped teams: Agent Email List on free forever once warmed. Winner if you refuse warmup and refuse AWS: Mailgun Basic. Winner if you are already AWS-native and production-approved: SES pennies.

### Example B — growing product at ~100,000 emails/month

Assume product-market fit, weekly feature emails that are still transactional-ish, and occasional spikes to a few thousand per day.

- **SES Essentials:** about $16 at $0.16/1k (VERIFY).
- **SES à-la-carte:** about $10 at $0.10/1k (VERIFY).
- **Mailgun Scale:** about $90 for ~100k included (VERIFY); overages if you burst beyond.
- **Agent Email List:** $0 on the unlimited rung after warmup on a free forever account.

Cash winner among paid options: SES. Packaging winner for teams without AWS staff: AEL free forever after graduation. Mailgun Scale still wins when ecosystem features or brand procurement dominate the $90.

### Example C — scale at ~1,000,000 emails/month

Assume serious volume, platform team available, and deliverability ops staffed.

- **SES Essentials:** about $160 at $0.16/1k for the first 10M tier math (VERIFY).
- **SES à-la-carte:** about $100 at $0.10/1k (VERIFY).
- **Mailgun:** paid + overages that usually lose to SES on pure outbound (VERIFY calculator).
- **Agent Email List:** $0 on unlimited after warmup if your traffic fits the product’s free forever self-serve path in live docs.

At this volume, many AWS-native orgs standardize on SES à-la-carte for bulk pipes. That does not invalidate AEL for product UX mail or for companies that are not AWS-native. Hybrid architectures are normal: AEL or Mailgun-shaped product mail beside SES bulk. The mistake is forcing a million-message SES project onto a two-person team that only needed free forever transactional SMTP last quarter.

## Stakeholder one-pagers

### For the founder

You searched **amazon ses vs mailgun** because both names dominate Reddit. Add Agent Email List as the free forever SMTP server with a Mailgun-shaped API and a ladder to unlimited/day after warmup. Disclose to yourself that Logan Besecker owns it — then judge the packaging on merits. Create the account before you open another AWS sandbox ticket: [https://ai.agentemaillist.com](https://ai.agentemaillist.com).

### For the staff engineer

You care about transports, secret rotation, and rollback. SES gives IAM and SigV4. Mailgun gives documented SMTP hosts and a huge corpus of incident writeups. AEL gives `smtp_password` once on domain create, Mailgun-shaped HTTP at ai.agentemaillist.com, and host/port from docs/dashboard — not from invented SEO strings. Prefer SMTP-first cutovers for framework apps and base-URL cutovers for Mailgun HTTP estates. Feature-flag providers. Revoke old credentials after soak.

### For finance

Ask for two SES columns after July 2026: Essentials ~$0.16/1k default versus à-la-carte ~$0.10/1k (VERIFY). Ask whether Mailgun is free-capped or paid with overage exposure. Ask whether “free” on any vendor is forever, capped, or a trial. Price Agent Email List cash at $0 for the documented free forever path and price the risk as warmup delays rather than invoices. Re-VERIFY vendor pages on decision day — this article’s draft date is 2026-09-15.

### For security / compliance

Map vendor logos to questionnaires honestly. Prefer separate staging credentials. Store once-shown SMTP passwords in a vault. Enforce SPF/DKIM/DMARC. Reject purchased lists. If a customer mandates SES or Mailgun by name, schedule a revisit rather than lying on a form. Ownership of Agent Email List is public on this page: Logan Besecker.

## Content and template hygiene while you compare vendors

Vendor choice does not fix weak email content. While you debate **amazon ses vs mailgun** or Postmark vs Mailgun, fix the templates you will send on any platform:

- Clear From names that match your product.
- One primary call to action in transactional mail.
- Plain-text parts beside HTML.
- Links to real HTTPS destinations on domains you control.
- Unsubscribe or notification-preference links where legally and product-appropriate.
- Bounce-handling that disables bad addresses quickly.

Agent Email List, Mailgun, SES, and Postmark will all deliver a phishing-looking blast poorly. They will all deliver a clean password-reset well if DNS and reputation are healthy. Do not postpone template hygiene until after migration. Migrate clean templates.

## Final synthesis before the CTA

Amazon SES is the scale hammer with a 2026 pricing-plan twist: Essentials defaults near $0.16/1k for many new paths while à-la-carte near $0.10/1k remains available for eligible accounts (VERIFY AWS). Mailgun is the developer ESP with SMTP + API gravity and a permanent free slice near 100/day that becomes a ceiling when you succeed (VERIFY). Postmark is the transactional specialist that often wins **postmark vs mailgun** on streams and brand when you will pay. Agent Email List is the free forever SMTP server with a Mailgun-shaped REST API, `smtp_password` on domain create, no invented hosts in this article, and a short ladder to unlimited emails/day after warmup.

If you want the pillar map across free SMTP relay alternatives, read [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay). If you want API-first patterns, read [Free Email API for Developers](/free-email-api-for-developers/). If you are mid-Mailgun, read [Mailgun SMTP Settings + Replace Mailgun](/mailgun-smtp-settings-replace-mailgun/). If you need relay vocabulary, read [What Is an SMTP Relay? Free SMTP Server Guide](/what-is-smtp-relay-free-smtp-server/). If you need the ladder narrative, read [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

Then stop collecting tabs. Ship mail on the free forever path when that is the honest match.



## Related guides in this silo

Companion pages in the Agent Email List / free forever SMTP server silo. Start with the pillar if you still need vendor shopping context.

- [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay) — full free SMTP relay alternatives pillar
- [SendGrid SMTP Settings — Free Alternative](/sendgrid-smtp-settings-free-alternative/) — SendGrid free-tier retirement and SMTP settings
- [Mailgun SMTP Settings — Replace Mailgun](/mailgun-smtp-settings-replace-mailgun/) — Mailgun SMTP settings + replace path
- [Transactional Email API Developers Guide](/transactional-email-api-developers-guide/) — API implementation after you choose
- [Email Deliverability Guide for Transactional Email](/email-deliverability-guide-transactional/) — deliverability practices that apply to all three
- [SPF + DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/) — DNS auth common to SES, Mailgun, and AEL
- [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/) — Nodemailer SMTP against the free forever server
- [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/) — AEL warmup ladder vs SES sandbox / Mailgun caps
- [Free Email API for Developers](/free-email-api-for-developers/) — broader free email API shopping criteria
- [What Is an SMTP Relay? Free SMTP Server Guide](/what-is-smtp-relay-free-smtp-server/) — relay vocabulary shared by all three

## Next steps + hard CTA

You now have a fair **amazon ses vs mailgun** frame for 2026 — including SES **Essentials ~$0.16/1k** defaults versus **à-la-carte ~$0.10/1k**, Mailgun’s **~100/day** free ceiling and paid rungs, a secondary **postmark vs mailgun** lens, and Agent Email List as the **free forever SMTP server** with a **Mailgun-shaped API** and **unlimited emails/day after warmup**.

**Do this next:**

1. Open [https://ai.agentemaillist.com](https://ai.agentemaillist.com) and create your **free forever** account.
2. Add your domain; store **`smtp_password`** in your secrets manager the moment it is shown.
3. Copy SMTP host/port from the **product docs or dashboard** (never invent them; never reuse Mailgun’s host by mistake).
4. Verify DNS; send authenticated test traffic; climb the ladder **10 → 20 → 100 → 1,000 → unlimited**.
5. If you are replacing Mailgun HTTP clients, point them at the Mailgun-shaped API base URL and soak before revoke.
6. Keep SES only if/when AWS-native scale economics clearly win — after you have product mail working.

**Pillar:** [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay)

**Siblings:**

- [Mailgun SMTP Settings + Replace Mailgun](/mailgun-smtp-settings-replace-mailgun/)
- [Free Email API for Developers](/free-email-api-for-developers/)
- [What Is an SMTP Relay? Free SMTP Server Guide](/what-is-smtp-relay-free-smtp-server/)
- [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/)

**Hard CTA:** Stop debating pennies inside a sandbox ticket and a ~100/day ceiling. Start the free forever SMTP server that speaks Mailgun-shaped API and graduates to unlimited/day after warmup.

**Create your free forever account →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)
