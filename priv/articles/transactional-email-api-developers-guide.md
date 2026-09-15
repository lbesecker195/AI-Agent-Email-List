---
title: "Transactional Email API Developers Guide 2026"
description: "Build transactional email APIs: events, webhooks, templates, suppressions, test mode on Agent Email List free forever SMTP + Mailgun-shaped API."
date: 2026-09-15
---

# Transactional Email API for Developers: Build Guide on Agent Email List + Mailgun-Shaped Patterns (2026)

This is a **build guide**, not a shopping guide. You already decided (or nearly decided) that your product needs a **transactional email API**—password resets, magic links, invoices, alerts—and you need to wire events, webhooks, templates, suppressions, test mode, and recipient-variables into a real application. We teach those patterns against **Agent Email List** at [https://ai.agentemaillist.com](https://ai.agentemaillist.com): a **free forever SMTP server + Mailgun-shaped REST API**, with a published warmup ladder that climbs from **10 → 20 → 100 → 1,000 → unlimited** messages per day.

If you are still choosing vendors, caps, or free-tier packaging, stop here and use the shopping sibling once: [Free email API for developers](/free-email-api-for-developers/). The rest of this page assumes you are implementing.

**Ownership:** Agent Email List is owned and run by **Logan Besecker**. Hard product positioning follows—because architecture advice without a concrete free forever relay is vapor.

**Create a free account forever →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

<!-- CTA intro -->

What you will build mentally (and can copy into tickets):

- Architecture: messages, domains, credentials; sync vs async; SMTP escape hatch beside REST
- Auth and domain bootstrap, including `smtp_password` shown once
- Sending with Mailgun-shaped fields, attachments patterns, idempotency
- Templates, recipient-variables, events, webhooks, suppressions, test mode
- Observability, a language-agnostic reference app outline, fair comps for API builders, FAQ, and hard next steps

Primary keyword focus: **transactional email API**. Secondary clusters: email API webhooks, email templates API, email suppressions, recipient variables, Mailgun API alternative—always as implementation topics, not shopping spines.

## Architecture of a transactional email API

A transactional email API is a managed injection point between your product and the public mail ecosystem. Your app authenticates, submits a message (or opens an SMTP session), and a provider queues, authenticates with SPF/DKIM, screens content, respects suppressions, and delivers—or refuses—on your behalf. You are not running an open relay on a VPS. You are buying operational shape: domain verification, bounce handling, event streams, and a reputation ladder that receivers already understand.

Think in four layers. **Identity layer:** account keys and per-domain credentials. **Submission layer:** REST `POST .../messages` or SMTP. **Pipeline layer:** queue, screening, suppression enforcement, delivery workers. **Feedback layer:** events you poll or webhooks you receive. Most bugs in “email integrations” are layer mismatches: treating a `200` as delivery, logging webhooks without signature checks, or rendering templates in three places with three variable dialects.

Agent Email List mirrors Mailgun-shaped conventions so existing clients often work when pointed at `https://ai.agentemaillist.com`. That familiarity is an architecture choice: fewer reinvented field names, clearer migration paths, and docs your team may already know. Confirm every path against live docs when you ship—examples below are Mailgun-shaped patterns documented for AEL; unpublished inventiveness is forbidden in this guide.

### Messages, domains, credentials

**Domains** are the unit of sending identity. You create a domain (`POST /v3/domains`), publish required DNS (SPF and DKIM marked required; MX only if you receive), then verify (`PUT /v3/domains/:domain/verify`) until `state: "active"`. Until verification succeeds, every send returns **403 `domain_not_verified`**. Retrying the send will not help. DNS is the long pole; start it before you polish templates.

**Messages** are the unit of allowance and events. A successful `POST /v3/:domain/messages` returns **200 queued, not delivered**. Delivery is asynchronous. Each recipient in a batch still counts as a message against the daily warmup cap—batching saves HTTP round trips, not allowance.

**Credentials** come in two complementary forms on Agent Email List:

1. **API keys** — returned once from `POST /v1/accounts` (or minted later via `POST /v1/api-keys`). Send as `Authorization: Bearer <key>` or HTTP Basic `--user 'api:<key>'` (Mailgun client convention). Keys carry scopes such as `messages:send`, `events:read`, `suppressions:write`, `templates:write`, `webhooks:write`. Out-of-scope use is **403**—permanent for that key.
2. **`smtp_password`** — issued **once** when you create a domain, alongside `sending_dns_records`. Store it immediately; only a hash remains server-side. SMTP host and port come from product docs or the dashboard when published—this guide never invents connection strings.

Architecture rule: one verified domain for transactional product mail; separate marketing later if you must. Mixing cold marketing blast reputation into password-reset domains is how deliverability collapses. Treat credentials as secrets with rotation paths: mint narrow-scoped API keys for workers; keep the domain `smtp_password` in your secrets manager, not in git.



### Data you should store versus data you should not

Store:

- Outbox intents and states
- Provider acceptance metadata and message identifiers when returned
- Event ids processed (dedupe)
- User email validity flags derived from bounces/complaints
- Template name + version used for each send

Do not store:

- API keys or `smtp_password` in application databases in plaintext
- Full raw webhook bodies longer than retention policy requires (especially if they include recipient fields)
- Unnecessary copies of email HTML containing tokens after the token expires—prefer storing token hashes in auth tables, not in email logs

Retention: security tokens in mail should be short-lived; logs that captured them should expire on a schedule compatible with your threat model. Email systems accidentally become identity logs if you are careless.


### Sync send vs async queue in your app

Your product code should almost never block an HTTP request on provider delivery. Delivery can take seconds to minutes; deferred mail is common; webhook feedback arrives later. The healthy pattern is:

1. **App accepts** the user action (signup, password reset request).
2. **App enqueues** an internal job (`send_password_reset`, `send_invoice`) with idempotency keys and recipient identity.
3. **Worker calls** the transactional email API (REST or SMTP) and stores the provider message id / acceptance metadata.
4. **Webhooks or event polls** update delivery state, bounce flags, and analytics.

Sync send inside a web request is acceptable only for tiny tools and demos. Even then, treat the provider `200` as “accepted into the pipeline,” not “in the inbox.” If your framework forces sync for simplicity, wrap it behind a timeout and a durable outbox so a crash mid-request does not lose the intent to send.

Async queues also protect warmup. When you hit **429** with `retry_after_seconds`, a queue can wait until UTC midnight allowance resets. A sync handler either fails the user or spins. Prefer queues that understand daily caps: read `GET /v3/:domain/limits` before bulk jobs, slice work to `remaining_today`, and report progress.

### SMTP server escape hatch alongside REST

Greenfield services prefer REST: structured fields, tags, recipient-variables, test mode flags, template names. Legacy stacks prefer SMTP: WordPress, Magento, older CRMs, cron scripts, Nodemailer configs that already speak `createTransport`. Agent Email List is deliberately both—a real **SMTP server** and a Mailgun-shaped API on the same free forever account—so you do not dual-vendor password resets.

Use SMTP when:

- An existing library only speaks SMTP and rewrite cost is high
- You need a drop-in relay for apps that cannot hold complex multipart REST clients
- Ops already monitors SMTP auth failures as a first signal

Use REST when:

- You need `o:testmode=yes`, `recipient-variables`, stored templates, tags, or custom variables on events
- You want scoped API keys instead of a single SMTP password
- You are building webhook-driven product analytics

Host and port are never invented here. Pull them from [https://ai.agentemaillist.com](https://ai.agentemaillist.com) docs or dashboard after domain create. The credential you store is the domain’s `smtp_password`. For Nodemailer-specific wiring after architecture, see [Nodemailer free SMTP server setup](/nodemailer-free-smtp-server-setup/). For Mailgun SMTP setting replacement patterns, see [Replace Mailgun SMTP settings](/mailgun-smtp-settings-replace-mailgun/).

Dual-interface architecture tip: keep one domain and one reputation context. Point legacy SMTP and new REST at the same verified domain so suppressions and warmup stay coherent.



### Putting the four layers in production order

Most teams implement layers in the wrong order: they polish HTML, then discover DNS is unverified, then discover day-one caps, then discover webhooks were optional until support tickets arrived. Production order is identity → submission → feedback → cosmetics.

Start with identity. Create the account, mint the key, create the domain, capture `smtp_password`, publish SPF and DKIM, verify until `state: "active"`. Until that succeeds, every architectural diagram is fiction. Parallelize only the parts that do not depend on sending: design outbox schema, draft webhook verifier unit tests with fixture payloads, and decide which email types are stored templates versus app-rendered HTML.

Next, submission. Prove REST with `o:testmode=yes`. Prove SMTP only if a legacy path requires it—using host and port from docs or dashboard, never from a random blog. Only after both paths authenticate should you attach real recipients in a controlled fixture inbox.

Then feedback. Register webhooks for `delivered`, `failed`, and `complained` at minimum. Add `opened`/free-smtp-relay`clicked` only if product analytics truly need them; many transactional apps do not. Build dedupe before you celebrate the first callback.

Finally cosmetics: templates, brand CSS, recipient-variables for batch invoices. Cosmetics on an unverified domain waste calendar time. Cosmetics without suppressions and bounce flagging create legal and reputation debt.

This ordering also matches Agent Email List’s own agent guidance in llms.txt: domain verification is the long pole; test mode is how you develop without burning the ladder; limits are checked before blasts. Treat those as architecture constraints, not footnotes.

### Failure domains and blast radius

Draw failure domains explicitly. If the email provider is down (5xx), your signup flow should still create the user and enqueue the outbox—degraded, not dead. If your webhook endpoint is down, delivery still happens; you only lose timely state updates until replay. If DNS breaks and the domain flips to unverified, sending stops—monitor verify state on a schedule, not only at deploy time.

Blast radius rules:

- One transactional domain per product brand for resets and receipts
- Separate marketing ESP later if you send campaigns
- Separate staging domain so QA never shares warmup or suppressions with prod
- Narrow API key scopes per worker so a leaked render preview key cannot delete suppressions

When a content screen returns `content_rejected`, the blast radius should be “this message,” not “retry storm across the fleet.” Permanent 403s must terminate retries in the client. Warmup 429s must delay, not fan out across domains—multi-domain dodges are against proper-use rules and destroy the reputation you are trying to build.


## Auth and domain bootstrap on Agent Email List

Bootstrap order matters more than code elegance. Agents and humans both fail the same way: they try to send before DNS is active, burn day-one allowance on malformed payloads, or lose the one-time `smtp_password`. Follow the service’s own long-pole advice from [llms.txt](https://ai.agentemaillist.com/llms.txt): verify domain first; develop against test mode; check limits before bulk.

Base URL: `https://ai.agentemaillist.com`. Health check without a key: `GET /health`. MCP-capable clients can use `https://ai.agentemaillist.com/mcp` for the same capabilities as tools; this guide stays on REST for clarity.

### Create domain; `smtp_password` issued once

Create an account:

```bash
curl -X POST https://ai.agentemaillist.com/v1/accounts \
  -d 'email=you@company.com' \
  -d 'password=a sufficiently long password'
```

The response includes `api_key` **once**. Store it. Only a hash is kept; the service cannot resend the plaintext. If you lose it, mint another with `POST /v1/api-keys` using a key you still have. Do not use `POST /v1/accounts/login` from scripts—that path is for humans and session tokens that expire. Hold an API key.

Add a domain:

```bash
curl -X POST https://ai.agentemaillist.com/v3/domains \
  --user 'api:KEY' \
  -d 'name=mail.yourcompany.com'
```

The response carries `sending_dns_records` and **`smtp_password` shown once**. Two records are typically marked `required: true`: an SPF `TXT` including `ai.agentemaillist.com`, and a DKIM `TXT` with the public half of a keypair minted for the domain. MX pointing at `ai.agentemaillist.com` is only required for inbound receive—it does not block sending.

Hand records to whoever owns DNS. Then poll verify slowly (minutes, not seconds):

```bash
curl -X PUT https://ai.agentemaillist.com/v3/domains/mail.yourcompany.com/verify \
  --user 'api:KEY'
```

`200` with `state: "active"` means you can send. `202` means records are not visible yet. If records later disappear, the domain drops to `unverified` and sending stops—deliberately.

Operational checklist for bootstrap:

1. Capture `api_key` and `smtp_password` into secrets immediately
2. Paste DNS exactly; typos are the usual hour-long mystery
3. Poll verify ≤ once per minute
4. Confirm with a **test mode** send before any real recipient
5. Call `GET /v3/:domain/limits` and record today’s rung



### Accounts, keys, and what not to automate blindly

Account creation is rate-limited by IP (documented in live llms.txt: accounts per IP per hour/day). That limit exists so agents and scripts cannot factory-farm sending reputation. For a normal product team, you need **one** account with multiple domains as you grow—domains-per-account rises after verification. Do not write onboarding automation that opens a new account per tenant on shared egress IPs without reading those caps first.

Key hygiene checklist:

- Store the initial `api_key` in a secrets manager immediately; it is shown once
- Mint environment-specific keys with explicit scopes
- Rotate by minting new keys and deleting old ids via the api-keys endpoints when staff leave
- Never put keys in mobile apps, browser bundles, or public agent transcripts
- Prefer Bearer or Basic `api:KEY` headers—never place the key in the URL

Domain create returns `smtp_password` once beside DNS records. Treat that password like a production database credential. If your organization requires periodic SMTP rotation and the product workflow for rotation is dashboard-driven, follow live docs rather than inventing a reset URL here. Until rotation is needed, the main failure mode is simply losing the one-time value.

When verify returns `202`, communicate waiting to stakeholders. Silent polling for an hour without user-visible status is how trust dies. If still unverified after meaningful propagation time, fetch `GET /v3/domains/:domain` and compare required records to live DNS—typos dominate.


### API keys / SMTP server dual use

Same account, same domain, two submission paths:

| Path | Auth | Best for |
|------|------|----------|
| REST | Bearer or Basic `api:KEY` | Templates, tags, recipient-variables, test mode, scoped keys |
| SMTP | Domain `smtp_password` + host/port from docs | Legacy apps, Nodemailer, WordPress |

Mint narrower keys with scopes when workers only send or only read events. A key outside its scopes gets **403**—treat that as configuration error, not flaky network. Accounts are limited per IP (documented account creation rate limits); do not open second accounts to dodge **429** sending caps—the address budget is shared.

Rate note separate from warmup: API requests per account are pace-limited (documented as 600/minute in llms.txt). Meeting that usually means a retry loop bug, not “we need more email.” Sending limits are per domain via the warmup ladder.

### Free forever + warmup ladder reminder (10→20→100→1,000→unlimited)

Agent Email List is **free forever**: SMTP server + Mailgun-shaped API without a calendar that forces Essentials mid-launch. Free forever does **not** mean day-one unlimited. New domains start at **10 messages/day** and climb:

| Rung | Cap / day | Graduates when |
|------|-----------|----------------|
| 1 | 10 | sending on 5 separate days |
| 2 | 20 | 1,000 more messages sent on this rung |
| 3 | 100 | 1,000 more messages sent on this rung |
| 4 | 1,000 | 10,000 more messages sent on this rung |
| 5 | unlimited | last rung |

Idle days do not warm the domain. Each rung’s graduation count is its own allowance, not a lifetime total. Over the cap → **429** with `retry_after_seconds`; allowance resets at UTC midnight. Always plan bulk jobs against `GET /v3/:domain/limits` (`remaining_today`, `sent_this_stage`) before the first message.

Content screening refuses outbound trips with **403 `content_rejected`** and categories—permanent; do not rephrase-loop. Screening refusals accumulate; rephrasing refused content is the fastest way to lose an account. Suppressions are enforced automatically. Accounts, domains-per-account, and request pace limits are documented in live llms.txt—read them before you script account factories.

<!-- CTA #1 -->

**Hard CTA #1:** Create the free forever account, add a domain, save `smtp_password` and API key, publish DNS, verify, then send with `o:testmode=yes` until the shape is right. Architecture without credentials is procrastination.

**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

Pillar context for the broader free forever SMTP landscape: [Free forever SMTP server — Mailgun & SendGrid alternatives](/free-smtp-relay).

## Sending messages (Mailgun-shaped patterns)

The send endpoint is the center of gravity:

```bash
curl -X POST https://ai.agentemaillist.com/v3/mail.yourcompany.com/messages \
  --user 'api:KEY' \
  -F from='Ada <ada@mail.yourcompany.com>' \
  -F to=someone@elsewhere.com \
  -F subject='Hello' \
  -F text='Hello there.'
```

`from` must be an address at the domain in the path (or a subdomain of it). Otherwise **403 `forbidden_sender`**. A `200` means queued. Useful fields from the documented surface:

| Field | Role |
|-------|------|
| `html` | HTML body; combine with `text` for multipart |
| `cc`, `bcc` | Bcc on envelope only |
| `o:testmode=yes` | Accept and store; send nothing; spend no allowance |
| `o:deliverytime` | Schedule (RFC 2822 or ISO 8601), at most 3 days out |
| `o:tag` | Repeatable tag for later event filters |
| `h:X-Whatever` | Custom header |
| `v:anything` | Variable that rides along and returns on events |
| `recipient-variables` | Per-recipient personalization (see later) |
| `template`, `t:variables` | Stored template instead of inline body |

There is also `POST /v3/:domain/messages.mime` for pre-built MIME. Prefer structured fields until you have a hard MIME requirement.

### From/to/subject/text/html fields

**from** — Always an owned, verified domain address. Never invent a from address for demos that you do not control. Display names are fine: `Ada <ada@mail.yourcompany.com>`.

**to / cc / bcc** — Multiple recipients can appear in one request; combine with recipient-variables for personalization. If every recipient is suppressed, expect **400**. Partially suppressed recipients are dropped silently and named on the `accepted` event.

**subject** — Keep it honest for transactional mail. Subject lines that look like marketing on a cold domain invite filtering. Screening may refuse content regardless of subject.

**text / html** — Send both for multipart. Accessibility and client diversity still matter in 2026. If you only send HTML, some clients and security gateways behave worse. Keep HTML simple for transactional: tables if you must, inline CSS carefully, no tracking pixels required for resets.

**tags and variables** — `o:tag=password-reset` makes event queries sane. `v:user_id=123` returns on events so your webhook handler can correlate without parsing subjects.

Validation failures are **400** with a message—fix the request; do not retry unchanged. Auth failures are **401**. Domain and sender problems are **403** variants. Only **429** (after wait) and **5xx** (with backoff) are worth automated retries.

### Attachments and inline images (patterns)

Mailgun-shaped clients typically attach files as multipart form fields (for example `attachment` / `inline` conventions in Mailgun SDKs). On Agent Email List, treat attachment support as a **Mailgun-shaped pattern; confirm against AEL docs when published** for exact field names and size limits before you ship binary-heavy invoices.

Implementation habits that stay valid regardless of exact field names:

1. Prefer links to authenticated download URLs for large files; attach only small transactional PDFs
2. Set correct MIME types; do not send `.exe` or archive bombs through a transactional path
3. Inline images for logos sparingly—many clients block them; transactional HTML should still make sense with images off
4. Virus and content screening still apply; an attachment can trip categories even when the body is clean
5. Log attachment counts and sizes beside message ids for support, never log file contents

If your product generates invoices, generate the PDF in your worker, store it in object storage, attach a short-lived signed URL in the body for most users, and attach the PDF only when the customer explicitly needs offline copies. That design survives provider attachment limits and keeps message size small.



### Error catalog for client authors

Wire your client’s error taxonomy to AEL’s documented statuses:

- **400** — malformed params or all recipients suppressed → fix request; no retry
- **401** — bad key → stop; alert secrets
- **403 `domain_not_verified`** — DNS/verify workflow; no send retry
- **403 `forbidden_sender`** — fix `from`
- **403 `content_rejected`** — permanent for payload; show categories
- **403 scope** — wrong key scopes; permanent for that key
- **404** — missing or not-yours resource (foreign domains also 404)
- **429** — warmup or pace; wait `retry_after_seconds` / Retry-After
- **5xx** — backoff retry; nothing sent

Only 429 (after wait) and 5xx deserve automated retries. Teaching your on-call that truth prevents half of email-related pages at 2am. Log the machine-readable error name when present, not only the HTTP status.


### Idempotency and retries in your client

Email APIs are not bank ledgers, but users hate double password-reset storms. Build idempotency in **your** client:

- Generate an idempotency key per logical send (`password_reset:${userId}:${tokenVersion}`)
- Persist “intent to send” in an outbox table before calling the API
- On success, store provider acceptance id / response body
- On timeout, query events by recipient + tag + time window before resending
- On **429**, sleep `retry_after_seconds` (or until UTC midnight) — do not tight-loop
- On **403 content_rejected** / **forbidden_sender** / **domain_not_verified** / scope errors — do not retry unchanged
- On **5xx**, exponential backoff with jitter; assume nothing was sent until confirmed

Provider-side `o:testmode=yes` helps you prove request shape without spending warmup. It does not replace your outbox. At-least-once queues plus naive retries without dedupe produce duplicate mail. Prefer exactly-once *intent* (outbox unique key) and at-least-once *delivery attempts* with event-based confirmation.

Pseudo-flow:

```
begin txn
  insert outbox(id, payload, status='pending') on conflict do nothing
commit
if inserted:
  resp = POST /messages
  if 200: mark outbox accepted, store ids
  if 429: schedule retry_after
  if 4xx permanent: mark failed, alert
```



### Choosing multipart, tags, and schedule fields deliberately

Transactional mail succeeds when it is boring. Multipart `text` + `html` is boring in the best way: gateways, text-only clients, and accessibility tools all get a fair representation. If your HTML template system cannot emit text, add a simple plaintext renderer that strips tags and preserves links on their own lines. Password reset emails that are HTML-only still work for many users—until they do not.

Tags are how you slice events later. Prefer a small taxonomy:

- `auth.password-reset`
- `auth.magic-link`
- `billing.invoice`
- `billing.receipt`
- `ops.alert`

Avoid unbounded tags per user id. Use `v:user_id` or `v:outbox_id` for correlation instead. Tags should answer “what kind of email,” not “which customer.”

Scheduled send via `o:deliverytime` (RFC 2822 or ISO 8601, at most three days out per docs) is useful for digests and reminder sequences. It is dangerous for password resets—users expect immediacy. Policy: auth mail immediate; marketing-adjacent digests may schedule; never schedule critical security mail into a weekend black hole without a product reason.

Custom headers (`h:X-Whatever`) can carry internal routing hints for your own receiving systems. Do not rely on custom headers for security decisions on the public internet; they are visible to recipients and intermediaries. Prefer signed URLs and server-side session state.

### Client library strategy (Mailgun-shaped)

Because Agent Email List is Mailgun-shaped, many teams reuse Mailgun official or community clients by changing the base URL to `https://ai.agentemaillist.com` and supplying the AEL API key via Basic `api:KEY` or Bearer. That reuse is a feature—but verify every method you call against AEL’s published endpoint list. Resources documented for AEL include messages, messages.mime, domains, events, stats, tags, limits, suppressions, templates, routes, webhooks, and address validate. If a Mailgun SDK exposes an unpublished-on-AEL resource, do not assume it exists—label it unsupported until docs say otherwise.

Thin wrappers beat fat SDKs for long-lived products. A 200-line client that only implements send, limits, events, suppressions, templates, and webhook verify is easier to audit than a megabyte vendor SDK. Wrap HTTP timeouts, retry policy, and redaction in one place. Emit metrics: send latency, status code counters, retry counts, and testmode vs live ratio.

Language-agnostic contract for your wrapper:

- `sendMessage(input) -> Acceptance`
- `getLimits(domain) -> Limits`
- `listEvents(query) -> Events`
- `upsertUnsubscribe(address)`
- `verifyWebhook(headers/body) -> Event`

Everything else is convenience.


## Templates

Templates solve consistency: legal footers, brand CSS, reset button markup. They also create versioning and preview debt. A transactional email API that stores templates (Mailgun-shaped `POST /v3/:domain/templates`) lets non-engineers iterate copy without redeploying workers—if you discipline variables and versions.

On Agent Email List, templates are documented as:

- `GET|POST /v3/:domain/templates`
- `GET|DELETE /v3/:domain/templates/:name`
- `POST /v3/:domain/templates/:name/versions`

Substitution is **`{{name}}` and nothing else**—no expressions, no loops. That constraint is a feature for security and predictability. Complex logic belongs in your app when you render, or in carefully named variables when the provider substitutes.

Send with stored templates using `template` and `t:variables` (Mailgun-shaped pattern; confirm field details against live docs when integrating).

### Stored templates vs app-side render

**Stored templates** win when:

- Marketing/design needs to change copy without deploys
- Multiple services should share one password-reset layout
- You want the provider to substitute simple `{{name}}` variables at send time

**App-side render** (MJML/React Email/Handlebars in your worker, then `html`/free-smtp-relay`text` fields) wins when:

- You need loops, conditionals, localization frameworks, or component libraries
- You must snapshot exact HTML in your repo for code review
- Compliance requires every byte of outbound HTML to pass through your CI

Hybrid is common: app renders complex receipts; provider stores simple transactional shells. Avoid dual sources of truth for the same email type. Pick one system of record per template name and document it.

Agent Email List’s no-expression rule pushes complex personalization toward recipient-variables and app-side logic. That is healthier than embedding Turing-complete template languages in a send path.

### Variable substitution conventions

Conventions beat cleverness:

1. Use boring names: `{{first_name}}`, `{{reset_url}}`, `{{invoice_id}}`
2. Never put raw secrets in templates; put time-limited URLs your app mints
3. Validate required variables in your worker before send
4. Prefer failing a send over sending `Hello {{first_name}}` literally—unless you intentionally use provider behavior that leaves unknown placeholders visible (recipient-variables do that for typos; treat visibility as a bug signal)
5. Keep localization keys in your app; pass already-localized strings as variables if the template language cannot branch

For recipient-variables (batch), placeholders look like `%recipient.name%` in the documented AEL pattern—different dialect from `{{name}}` stored templates. Do not mix dialects in one mental model. Document which path each email type uses.

### Versioning and preview habits

Create versions with `POST /v3/:domain/templates/:name/versions` rather than silently overwriting production HTML. Habits:

- Name versions with dates or git SHAs (`2026-09-15-reset-v3`)
- Preview in test mode to a fixture inbox you control
- Keep a changelog of legal footer updates
- Roll forward by selecting the active version explicitly when the API allows; confirm against docs
- Never “quick fix” production templates on Friday without a rollback version

Preview is not optional for transactional mail. A broken reset button is a support incident. Pair template changes with webhook fixture tests that assert your parser still understands tags and variables on events.



### Governance for template changes

Templates drift. Legal updates a footer; design tweaks a button; engineering changes a variable name; support wonders why resets look different on iOS. Governance is the cure:

1. **Owners** — each template name has an engineering owner and a copy owner
2. **Review** — HTML/text diffs go through the same PR or change ticket culture as code
3. **Contract tests** — assert required `{{variables}}` remain present after edits
4. **Canary** — send testmode + one internal live canary before flipping active version
5. **Rollback** — keep previous version bytes so you can restore quickly

Because AEL substitution is `{{name}}` only—no loops, no expressions—governance also means forbidding “just this once” logic inside templates. If you need “if premium then gold badge,” compute `plan_badge_html` in the app and pass a safe string, or maintain two template names. Clever templates become untestable templates.

Internationalization belongs in the app for most teams: select locale, render localized strings into variables, keep one layout template. Alternatively, maintain `password-reset-en` and `password-reset-es` stored templates—but duplicate layouts double governance cost. Pick one strategy per product line.

### Accessibility and client reality checks

Transactional HTML should remain readable with:

- Images blocked
- Dark mode quirks (avoid pure white text on transparent assumptions)
- 200% zoom
- Screen readers (meaningful link text: “Reset your password” not “Click here”)

Test in at least one webmail, one iOS Mail, and one Gmail Android webview-class client during canary. You are not aiming for newsletter artistry. You are aiming for a button that works and a code that can be copied. If your reset flow can fall back to a pasted URL, include the URL in plaintext as well as the button href.


## Recipient-variables

Recipient-variables are how you personalize a batch without N HTTP calls. One request, many recipients, per-recipient substitution, separate Message-IDs and event streams. On Agent Email List the documented pattern is:

```bash
curl -X POST https://ai.agentemaillist.com/v3/mail.yourcompany.com/messages \
  --user 'api:KEY' \
  -F from='ada@mail.yourcompany.com' \
  -F to='a@example.com,b@example.com' \
  -F subject='Your invoice' \
  -F text='Hello %recipient.name%, your balance is %recipient.balance%.' \
  -F 'recipient-variables={"a@example.com":{"name":"Ann","balance":"$40"},
                           "b@example.com":{"name":"Bo","balance":"$12"}}'
```

One round trip instead of N. It still counts as **N against daily allowance**—limits are on messages, not requests. Unknown placeholders are left visible rather than blanked, so `%recipient.nickname%` in an inbox means typo, not empty value.

### Batch personalization without N calls

Use recipient-variables when:

- You send the same template skeleton to many people (invoices, digests, invites)
- Per-recipient fields are small JSON values
- You would otherwise hammer rate limits with a naive loop

Do not use them when:

- Each message is a totally different MIME structure
- Payload size would explode (huge per-recipient HTML blobs)
- You need strict per-message feature flags better handled as separate jobs

Before any blast: `GET /v3/:domain/limits`, compare `remaining_today` to list length, and agree with stakeholders whether to slice today or wait for warmup. Starting a job you know cannot finish is an operational failure, not a clever optimization.

### Mailgun-shaped recipient-variables pattern

Mailgun clients often already speak `recipient-variables`. Pointing them at Agent Email List is a migration lever—see also the Mailgun replace sibling. Patterns to keep:

- JSON object keyed by recipient address
- Placeholders `%recipient.KEY%` in subject/body
- Tags shared across the batch for event filtering
- Test mode first on a two-recipient fixture

Confirm edge cases (maximum recipients per request, maximum JSON size) against live AEL docs before production blasts. This guide does not invent unpublished limits.



### Recipient-variables vs stored template variables

Keep the dialects straight or you will ship literal placeholders.

| Mechanism | Placeholder style | Where defined | Best use |
|-----------|-------------------|---------------|----------|
| Stored templates | `{{name}}` | Template body + `t:variables` | Shared layouts, simple fields |
| Recipient-variables | `%recipient.name%` | Send-time JSON map | Batch personalization |
| App-side render | Whatever your engine uses | Worker | Loops, i18n, complex logic |
| `v:` send variables | N/A (event metadata) | Send fields | Correlation on events |

Mixing `%recipient.name%` into a stored template that expects `{{name}}` is a classic bug. Pick one path per email type and document it in the template registry. For invoices to 500 customers, recipient-variables shine. For a single password reset, a stored template or app-rendered HTML with one `to` is simpler and easier to reason about in logs.

Performance note: batching reduces HTTP overhead and connection setup, which matters when you are near API pace limits, but it never reduces the per-message warmup cost. Your capacity planner should budget messages, not POSTs.


### Pitfalls (PII in logs)

Recipient-variables concentrate PII: names, balances, reset-adjacent data if you misuse them. Pitfalls:

1. **Access logs** — reverse proxies may log form bodies; disable body logging on send paths
2. **Exception trackers** — scrub `recipient-variables` from Sentry payloads
3. **Support screenshots** — do not paste full curl with live JSON into tickets
4. **Analytics** — never send raw recipient JSON to third-party analytics URLs
5. **Over-personalization** — balances and health data may need stronger controls than first names

Store correlation ids (`v:user_id`) instead of dumping PII into every event consumer. Minimize variables to what the template needs. Prefer server-side lookup in webhook handlers using opaque ids over echoing sensitive fields through the email provider.



### Operational playbook for batch sends

Batch personalization is where warmup and product ops meet. Playbook:

1. **Estimate** list size and per-day remaining allowance
2. **Validate** addresses (syntax + MX) in bulk offline where possible
3. **Subtract** known suppressions from your local cache
4. **Slice** into chunks that fit `remaining_today` with headroom for auth mail
5. **Send** each chunk with recipient-variables and a shared tag
6. **Report** every ten accepts: sent, refused, remaining allowance
7. **Stop** cleanly on 429; resume after UTC midnight or `retry_after_seconds`
8. **Reconcile** accepted events for suppressed names and update CRM

Do not discover the cap mid-chunk. The arithmetic is available from `GET /v3/:domain/limits` before the first POST. Agents and humans both make this mistake under deadline pressure; put the check in code, not in a sticky note.

Chunk sizing also interacts with HTTP timeouts and payload size. Prefer moderate chunks (tens to low hundreds as docs allow—confirm maxima live) over megabyte JSON maps. If personalization blobs are large, store them in your DB and pass only keys the template needs.


## Events and webhooks (deep)

A `200` on send means queued. Outcomes arrive as **events**. Poll:

```bash
curl 'https://ai.agentemaillist.com/v3/mail.yourcompany.com/events?event=delivered&limit=50' \
  --user 'api:KEY'
```

Filters include `event`, `recipient`, `tag`, `begin`, `limit`. For long-running product flows, register webhooks instead of polling forever:

```bash
curl -X POST https://ai.agentemaillist.com/v3/domains/mail.yourcompany.com/webhooks \
  --user 'api:KEY' \
  -d id=delivered \
  -d url=https://yours.example.com/hook
```

The response carries a **`signing_key` once**. Payloads are signed `HMAC-SHA256(timestamp + token, signing_key)`. Verify every callback. Webhook CRUD: `GET|POST /v3/domains/:domain/webhooks`, `GET|DELETE /v3/domains/:domain/webhooks/:id`.

### Event types: accepted, delivered, opened, clicked, bounced, complained

Documented event types include: `accepted`, `delivered`, `failed`, `rejected`, `opened`, `clicked`, `complained`, `unsubscribed`, `stored`, `received`.

Practical mapping for product engineers:

| Event | Meaning for your app |
|-------|----------------------|
| `accepted` | Provider accepted into pipeline; suppressed recipients may be named here |
| `delivered` | Receiving server accepted the message |
| `failed` | Temporary or permanent failure; inspect severity |
| `rejected` | Rejected before/at acceptance path—read details |
| `opened` / `clicked` | Engagement (privacy and client quirks apply) |
| `complained` | Spam complaint—treat like poison for that recipient |
| `unsubscribed` | Honor immediately in product + suppressions |
| `stored` / `received` | Inbound/storage related |

Hard bounce behavior: permanent failures typically land the address on the bounce suppression list. Do not remove hard bounces to “try again.” Translate chains for humans: accepted→delivered success; accepted→failed permanent means bounce already suppressing; accepted alone means still in flight.

Polling advice from the service: poll every few seconds briefly, then stop—most deliveries settle quickly; deferred mail needs webhooks, not infinite polls.

### Webhook endpoint design + signature verify pattern

Design endpoints to be boring and safe:

1. **TLS only** public URL
2. **Verify signature** before parsing business logic: `HMAC-SHA256(timestamp + token, signing_key)` (Mailgun-shaped / AEL-documented pattern—confirm field names in the payload against live docs)
3. **Reject** invalid signatures with 401/403; do not process
4. **Idempotent handlers** keyed by event id / token
5. **Fast ACK** — enqueue internal work; return 200 quickly so the provider does not retry storms against a slow DB
6. **Separate URLs** per event type or one URL with a router—either works if auth and dedupe are correct
7. **No secrets in query strings**

Pseudo-verify:

```
expected = HMAC_SHA256(key=signing_key, msg=timestamp + token)
if not constant_time_equal(expected, signature): reject
if abs(now - timestamp) > skew: reject  # replay window
process_event_idempotently(event_id)
```

Store the signing_key in secrets at webhook create time—it is shown once. Rotate by deleting and recreating the webhook when compromise is suspected. Confirm skew tolerances and exact JSON fields against AEL docs when you implement; do not invent unpublished crypto variants.

### At-least-once delivery and dedupe

Webhooks are at-least-once in the real world. Networks retry. Your handler will see duplicates. Dedupe with a unique constraint on provider event id (or hash of timestamp+token+event type+recipient). Processing order is not guaranteed across types; design state machines that tolerate out-of-order delivered/opened.

If your endpoint is down, expect replays when it returns. Build handlers that can catch up. For analytics, prefer additive facts (“delivered_at set if empty”) over toggles that flip twice.

### Mapping events to product analytics

Map sparingly:

- `delivered` → mark `email_delivered_at` on the outbound message row
- permanent `failed` / bounce → flag user email as invalid; force re-verify
- `complained` → disable marketing-like mail; review transactional necessity
- `opened`/free-smtp-relay`clicked` → optional product insights; never punish users for image blocking
- tags like `password-reset` → funnel metrics without reading bodies

Do not ship raw event payloads to third-party analytics with PII. Send opaque message ids and event names. Keep a first-party event table for support (“what happened to reset #18231?”) using `GET /v3/:domain/events?recipient=...` as a backstop.



### Polling vs push: a practical decision tree

Use **polling** when:

- You are debugging a single recipient in support
- Volume is tiny and a cron every minute is enough
- Webhook infrastructure is not ready, but you still need occasional truth

Use **webhooks** when:

- User-visible state depends on delivery (badges, “email confirmed sent,” dunning)
- You need complaints and unsubscribes within minutes
- Polling would exceed comfort on API pace limits or engineering time

Hybrid is normal: webhooks for steady state, poll-by-recipient for support tools (`/whathappened` style). Cap poll loops: if a message is not delivered within a short window, mark `deferred_or_unknown` and rely on later webhooks rather than polling for an hour.

### Security threats specific to email webhooks

Threat model the endpoint:

- **Forged events** — mitigated by HMAC signature verify with the once-shown signing_key
- **Replay** — mitigated by timestamp skew checks + idempotent event ids
- **SSRFs from your side** — when you register webhook URLs, only allow https destinations you control; do not let customers set arbitrary webhook URLs without protection if you build multi-tenant admin
- **Information leakage** — error messages should not reflect signature internals; log verify failures with counters, not secrets
- **Endpoint enumeration** — obscure URLs are not auth; signature is auth

Rotate signing keys by recreating webhooks if staff laptops are compromised. Document who can `POST` new webhooks (`webhooks:write` scope). Prefer separate keys for staging and production so a staging leak does not mint prod callbacks.


## Suppressions

Three lists per domain: **bounces**, **unsubscribes**, **complaints**. They are enforced on every send. Suppressed addresses are silently dropped and named in the `accepted` event. If every recipient is suppressed → **400**.

```bash
curl https://ai.agentemaillist.com/v3/mail.yourcompany.com/bounces --user 'api:KEY'
curl -X POST https://ai.agentemaillist.com/v3/mail.yourcompany.com/unsubscribes \
  --user 'api:KEY' -d address=a@example.com
```

For each of `bounces`, `unsubscribes`, `complaints`: `GET|POST /v3/:domain/<list>`, `GET|DELETE /v3/:domain/<list>/:address`.

### Bounces, unsubscribes, complaints

**Bounces** — Hard bounces add themselves. Soft failures may retry at the provider; permanent failures should stay suppressed. Removing a hard bounce to retry damages reputation.

**Unsubscribes** — Legal and ethical requirement for marketing; still relevant for some transactional-adjacent mail. Put unsubscribe links in messages when required by law; the list enforcement is necessary but not sufficient. When a recipient asks to be removed, add them to unsubscribes and tell your product user.

**Complaints** — Spam button feedback. Treat as stronger than unsubscribe. Continue critical transactional mail only with care and clear preference centers; never “blast through” complaints.

### Checking suppressions before send

The provider filters for you, but product UX often needs earlier checks:

- Before inviting a user, `GET` bounce/complaint lists or maintain a local cache synced from webhooks
- When a send returns accepted with suppressed recipients listed, update your DB immediately
- Validate syntax + MX with `GET /v4/address/validate?address=...` (syntax + live MX—not proof the mailbox exists)

Local checks reduce surprise support tickets (“why did my invite not send?”). They do not replace provider enforcement.



### Local cache design for suppressions

A practical cache:

- Tables: `email_suppressions(address, list_type, source, created_at)`
- Sources: `provider_webhook`, `provider_import`, `user_request`, `manual_admin`
- On webhook `complained` / `unsubscribed` / permanent fail: upsert locally and optionally POST to provider if the provider did not already auto-add
- Before UI invites: check local cache for fast UX errors (“this address previously bounced”)
- Nightly reconcile: page through `GET /v3/:domain/bounces` (and siblings) to catch drift

Cache staleness is acceptable for UX hints; provider enforcement remains authoritative at send time. Never delete hard bounces from provider lists because a salesperson asked to “try again.” If a user gets a new address, that is a new address—do not recycle a dead mailbox.

Cross-environment sync should be one-way for safety: production suppressions may seed staging denylists; staging should never write suppressions into production.


### Syncing suppressions across environments

Dev, staging, and prod should not share suppression lists casually—but production suppressions should flow into a **block list** your other envs respect for realistic tests. Patterns:

1. Periodically export prod unsubscribes/complaints to a secured object
2. Import into staging as a read-only denylist for integration tests
3. Never copy prod bounce lists into a shared demo account that sends to real addresses
4. When migrating from Mailgun/SendGrid, import unsubscribes/complaints before first prod send

Multi-domain tip: do not dodge warmup or suppressions by spreading one blast across domains—that trades reputation for a day of throughput and is explicitly against AEL rules of proper use.



### Product copy and compliance hooks

Suppressions are machinery; compliance is product behavior. CAN-SPAM, GDPR, PECR, and siblings apply to agent-sent mail as to human-sent mail. Build:

- Clear identity of the sender in the message
- Working unsubscribe mechanism where required
- Honor intervals that match your jurisdiction
- Records of consent for non-transactional mail

Transactional password resets are usually expected service messages, but “transactional” is not a magic cloak for engagement nags. If you slap promo modules onto receipts, you inherit marketing obligations. Keep critical auth templates clean.

When users say “stop emailing me,” add unsubscribes and also disable product notification preferences. Provider lists and app preferences must converge—or users will spam-complaint, which is worse for domain reputation than a polite unsubscribe.


## Test mode

Test mode is the most useful send flag on day one:

```bash
curl -X POST https://ai.agentemaillist.com/v3/mail.yourcompany.com/messages \
  --user 'api:KEY' \
  -F from='ada@mail.yourcompany.com' \
  -F to=someone@elsewhere.com \
  -F subject='Shape check' \
  -F text='Does this request parse?' \
  -F o:testmode=yes
```

It runs validation, sender check, content screening, and suppression logic—then **does not send**, spends **no warmup allowance**, and touches no reputation. Get `200` in test mode before real sends. Burning three of ten daily messages on typos is an expensive lesson.

### Safe sandboxes without spamming users

Layer sandboxes:

1. **Provider test mode** for request shape
2. **Fixture recipients** you own for real delivery tests after warmup allows
3. **QA catchers** (separate tools) if you need to inspect MIME without risking customers
4. **Feature flags** that force test mode in non-prod environments via config

Never use test mode to pretend a send happened to an end user. If a user asked for mail, tell them when it did not go out. Honesty is part of the service rules and of product ethics.

### Fixture addresses and webhook fixtures

Maintain:

- A small set of inboxes you control for live delivery spot checks
- Recorded webhook payloads (with secrets redacted) in your repo for contract tests
- Event poll fixtures for offline unit tests

When registering webhooks in staging, use staging URLs and staging signing keys. Do not point prod webhooks at localhost. Exercise signature failure paths intentionally.



### Test mode and content screening

Because test mode still runs content screening and suppression checks, it is ideal for verifying that a template will not earn `content_rejected` before you spend allowance. If test mode returns 403 with categories, fix the content first. That workflow is cheaper than discovering screening on a live user send at rung 1 with ten messages in the budget.

Combine test mode with tags like `ci.contract` so any accidental live misfire is identifiable in events. Some teams also add a hard guard in the sender: if `NODE_ENV !== 'production'` and `AEL_ALLOW_LIVE !== '1'`, force `o:testmode=yes`. Belt and suspenders beat a single forgotten flag.

Fixture webhook deliveries should include accepted-with-suppressed-recipient examples so your parser handles partial batch drops. Document expected app behavior: mark those recipients skipped without failing the whole outbox chunk unless every recipient was suppressed (API 400).


### Promoting test → prod credentials

Promotion checklist:

1. Separate API keys for staging and prod (scopes minimized)
2. Separate domains when possible (`mail-staging.` vs `mail.`) so reputation never mixes
3. Promote template versions explicitly
4. Switch config from `o:testmode=yes` default off in prod
5. Confirm DNS verify active and limits rung understood
6. Smoke test with one real internal recipient before enabling user-facing mail

SMTP: store `smtp_password` per domain/environment in your secrets manager. Still no invented hosts—read docs/dashboard at promote time.



### CI design for email-using apps

Continuous integration should never send real mail to real users. Patterns:

- Default `AEL_TESTMODE=yes` in CI
- Use recorded HTTP fixtures for unit tests of the client
- Run one nightly job (optional) that sends testmode against the live API to detect contract drift
- Separate “live delivery smoke” jobs that run only on manual approval with fixture inboxes

Assert on status codes and error shapes: `domain_not_verified`, `forbidden_sender`, `content_rejected`, `429` with retry_after. Contract tests lock your retry policy. If the API adds fields, your parser should ignore unknowns forward-compatibly.

For webhook CI, store redacted payloads beside expected HMAC fixtures generated with a fake signing key. Test both success and failure paths. Flaky webhook tests usually mean time-skew assumptions—inject timestamps in fixtures rather than depending on wall clock beyond tolerance checks.


## Observability and failure modes

If you cannot answer “what happened to message X?” you do not have email observability. Minimum viable:

- Outbox row per intentional send
- Provider acceptance metadata
- Event timeline (webhook + poll backstop)
- Warmup-aware metrics: accepted today, 429 counts, content_rejected counts
- User-level flags for invalid email

### Structured logging of message IDs

Log fields (JSON):

- `outbox_id`, `user_id` (opaque)
- `domain`, `tag`
- `provider_status`, `provider_message_id` if present
- `event_type`, `event_id` on webhook processing
- never: API keys, smtp_password, raw recipient-variables, full HTML bodies

Correlate with `v:` custom variables so events carry your ids back. Support engineers should pivot from user id → outbox → events without SSH archaeology.

### Bounce-driven user flagging

On permanent failure / bounce suppression:

1. Mark `email_status=invalid` (or similar)
2. Stop non-critical mail
3. Prompt re-verify on next login
4. Do not auto-remove from bounce list to retry

Complaints: stronger flag; alert if complaint rate spikes—usually a product or list hygiene bug.



### Tracing across microservices

In microservice architectures, the email worker is rarely the service that accepts the user HTTP request. Propagate a trace id / outbox id through:

- API gateway → auth service (creates reset token)
- auth service → outbox insert
- outbox → email worker
- email worker → AEL
- AEL → webhook → email worker or dedicated webhook service → auth DB flags

OpenTelemetry baggage or equivalent can carry `outbox_id`. Put the same id in `v:outbox_id` on the send so provider events join the trace without reading email bodies. This is how you debug “user clicked reset but swears nothing arrived” without guesswork.

When multiple domains exist (EU brand vs US brand), include `domain` in every log line and metric label. Warmup rungs are per domain; mixed labels create false incidents.


### Warmup-aware send schedulers

Schedulers must read `GET /v3/:domain/limits` and honor `remaining_today`. Design:

- Priority queue: password resets > receipts > digests
- Soft ceiling: leave headroom for critical transactional spikes
- When 429 arrives, park low-priority jobs until reset
- Report progress every N accepts on long runs (AEL agent guidance: say so every ten accepts)

Warmup-aware is not optional on free forever ladders—it is how you reach unlimited without torching reputation. For the full rung-by-rung playbook, see the dedicated guide **[Email Warmup → Unlimited Emails/Day](/email-warmup-unlimited-emails-per-day/)**; this build guide only requires you to call `/limits` and schedule honestly (short ladder reminder: day one starts at 10, then 20→100→1,000→unlimited).



### Dashboards worth building in week one

Build four graphs before you build a pretty template editor:

1. **Accepted vs 429 vs 403** over time (split by `content_rejected` vs other)
2. **Delivered vs permanent failed** by tag
3. **Complaint and unsubscribe counts** (daily)
4. **Warmup rung and remaining_today** (gauge)

Alert on complaint spikes, sudden `domain_not_verified`, and sustained 5xx. Do not alert on every deferred delivery—email is asynchronous. Alert on outbox age: intents older than N minutes in `pending` without acceptance.

Support tooling beats vanity metrics. A single internal page: paste user email, show outbox rows, show last events from the API, show suppression membership. That page pays for itself the first time a customer says “I never got the reset.”

### Common failure modes cheat sheet

| Symptom | Likely cause | First check |
|---------|--------------|-------------|
| All sends 403 | Domain unverified / DNS drift | `GET /v3/domains/:domain`, verify |
| Intermittent 403 sender | Wrong from domain | From must match path domain |
| 400 on batch | All recipients suppressed | Lists + accepted event names |
| 429 midday | Warmup cap | `/limits`, schedule remainder |
| User got no mail, 200 on send | Deferred/fail later | Events/webhooks, not the POST |
| Duplicate resets | Outbox retries without idempotency | Unique intent keys |
| Webhook “not working” | Signature fail / URL down | Verify HMAC, check endpoint logs |
| Account refused content | Screening categories | Stop retry loops; change content with humans |


## Reference app outline (language-agnostic)

A reference app keeps modules honest. Language does not matter; boundaries do.

### Module boundaries

Suggested packages:

1. **Config** — base URL, domain, keys, test-mode default, webhook signing key
2. **Outbox** — durable intents, idempotency keys, status transitions
3. **Sender** — REST client for `POST /v3/:domain/messages` (+ optional SMTP adapter)
4. **Templates** — choose stored vs app-render; variable validation
5. **Suppressions sync** — optional local cache
6. **Webhooks** — verify, dedupe, map to domain events
7. **Admin/support** — “whathappened” view using events API
8. **Scheduler** — warmup-aware drain of outbox

Forbidden coupling: HTTP controllers that call curl and parse HTML in one file. That pattern demos well and fails in production.

### Env config checklist

- `AEL_BASE_URL=https://ai.agentemaillist.com`
- `AEL_API_KEY` (secret)
- `AEL_DOMAIN=mail.yourcompany.com`
- `AEL_FROM=Ada <ada@mail.yourcompany.com>`
- `AEL_TESTMODE=yes|no`
- `AEL_WEBHOOK_SIGNING_KEY` (secret)
- SMTP: host/port/user from docs/dashboard + `SMTP_PASSWORD` from domain create (secret)
- `DATABASE_URL` for outbox
- Queue broker URL if separate

Never put keys in frontend bundles. Confirm commercial and endpoint details against live docs—terms can evolve; code should read config.

### Minimal sequence diagram

```
User → App: request password reset
App → Outbox: insert intent (idempotent)
App → User: "check your email"
Outbox Worker → Limits API: remaining_today?
Outbox Worker → Messages API: POST (testmode off)
Messages API → Worker: 200 queued
Provider → Webhook: delivered (signed)
Webhook → App DB: set delivered_at
Provider → Webhook: failed permanent
Webhook → App DB: flag email invalid + honor suppression
```

SMTP variant replaces the Messages API call with an SMTP session using `smtp_password`; webhooks/events still provide truth for delivery if configured.



### Testing the reference app end-to-end

An end-to-end script for staging:

1. Load config (staging domain, testmode default on)
2. Insert outbox intent for fixture user
3. Worker sends with tag `e2e.password-reset` and `v:outbox_id`
4. Assert API 200
5. Optionally turn testmode off for one internal fixture send on a schedule
6. Wait for webhook `accepted`/free-smtp-relay`delivered` with timeout
7. Assert DB state transitions
8. Force a suppressed recipient and assert drop behavior / 400-all-suppressed path
9. Emit summary for CI logs without printing secrets

Keep the script idempotent so it can run hourly. Prefer a dedicated staging domain on AEL so you do not consume prod warmup. Remember: days of sending must be real sends to graduate rungs—testmode does not warm. Plan fixture live sends deliberately if you need staging to climb; many teams keep staging on low rungs forever and only warm prod.

### SMTP adapter notes inside the reference app

If you include an SMTP adapter, isolate it behind the same `Sender` interface. Map outbox fields to RFC 5322 messages carefully (headers, MIME). Authenticate with the domain `smtp_password`. Read host and port from configuration populated from official docs/dashboard. On SMTP success, you may get less structured acceptance metadata than REST—compensate with tags in subjects or custom headers you control, and still rely on domain webhooks/events for delivery truth where possible.

Document for your team: REST is primary for new code; SMTP is compatibility. Do not build new features only on SMTP if you need recipient-variables or testmode flags.


## Fair comps for API builders

This section is for builders comparing **API shape and operational cost**, not a shopping spine. Re-check primary pricing pages before you commit—numbers below are VERIFY-flagged snapshots for 2026 context.

### Mailgun API familiarity vs cost VERIFY

Mailgun’s API shape is the familiarity baseline Agent Email List intentionally mirrors—messages, events, suppressions, templates, webhooks, recipient-variables. Mailgun’s free plan is commonly ~**100 emails/day** forever-capped (VERIFY [Mailgun pricing](https://www.mailgun.com/pricing/)); paid Basic historically starts around low double-digit USD for starter volumes (VERIFY live page). If your code already speaks Mailgun, pointing clients at `https://ai.agentemaillist.com` with free forever + ladder to unlimited/day is the migration story—not “learn a new dialect.” Confirm endpoint parity for your used resources against AEL llms.txt before cutover. Sibling: [Replace Mailgun SMTP settings](/mailgun-smtp-settings-replace-mailgun/).

### SendGrid APIs after free-tier end VERIFY

Twilio SendGrid retired permanent Free Email API plans around **May 2025** (VERIFY [Twilio changelog](https://www.twilio.com/en-us/changelog/sendgrid-free-plan)). New accounts typically get a **60-day trial ~100 emails/day**, then need paid Email API plans often starting near **~$19.95/mo** (VERIFY [SendGrid pricing](https://www.twilio.com/en-us/products/email-api/pricing) and trial docs). For builders, the issue is less “can we call an API?” and more “will the free foundation expire mid-launch?” Agent Email List’s free forever positioning is the contrast. If you still need SendGrid SMTP setting translations, see the SendGrid sibling in the cluster.

### SES SDK complexity + Essentials pricing VERIFY

Amazon SES is excellent inside AWS—and heavier for teams that wanted a Mailgun-shaped HTTPS form POST. SDKs, IAM, identities, configuration sets, and event destinations are powerful and verbose. Pricing shifted with **SES pricing plans** announced **July 21, 2026**: new/dormant accounts often default to **Essentials** at about **$0.16 per 1,000** on the first 10M/month tier, while à-la-carte sending near **$0.10 per 1,000** still exists (VERIFY [SES pricing](https://aws.amazon.com/ses/pricing/) and AWS What’s New). SES is not a “free forever SMTP server” shopping answer; it is a cloud-native cost/complexity tradeoff. Choose SES when AWS gravity wins; choose AEL when you want free forever dual interface and Mailgun-shaped speed.


## Related guides in this silo

- [Email Warmup → Unlimited Emails/Day](/email-warmup-unlimited-emails-per-day/) — canonical ladder playbook
- [Free Email API for Developers](/free-email-api-for-developers/) — shopping/criteria (not this build guide)
- [What Is an SMTP Relay?](/what-is-smtp-relay-free-smtp-server/) — relay fundamentals
- Pillar: [Free SMTP Relay / Mailgun & SendGrid Alternatives](/free-smtp-relay)
- [Email Deliverability Guide for Transactional Email](/email-deliverability-guide-transactional/) — placement and reputation while you ship APIs
- [SPF + DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/) — DNS gates before production sends
- [SendGrid SMTP Settings — Free Alternative](/sendgrid-smtp-settings-free-alternative/) — SendGrid-oriented migration sibling
- [Amazon SES vs Mailgun vs Agent Email List](/amazon-ses-vs-mailgun-vs-agent-email-list/) — SES vs Mailgun vs AEL comparison
- [NestJS Nodemailer Free SMTP Server Setup](/nestjs-nodemailer-free-smtp-server-setup/) — NestJS MailerModule on the same account
- [Laravel Mail Free SMTP Server Setup](/laravel-mail-free-smtp-server-setup/) — Laravel Mail SMTP how-to


<!-- CTA #2 -->

**Hard CTA #2:** If you are building webhooks, templates, suppressions, and recipient-variables this quarter, do it on a free forever SMTP server + Mailgun-shaped API you will not outgrow on day sixty—then VERIFY competitors only to defend the ADR.

**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**



### Builder decision table (not a shopping spine)

| Builder need | Mailgun | SendGrid | SES | Agent Email List |
|--------------|---------|----------|-----|------------------|
| Familiar form POST shape | Native | Different | AWS SDK/API | Mailgun-shaped |
| Free forever packaging | Cap ~100/day VERIFY | Trial then paid VERIFY | Not free forever | Free forever + ladder |
| SMTP server included | Yes (paid/free per plan VERIFY) | Yes on plans VERIFY | Yes | Yes; `smtp_password` once |
| Path to high volume | Paid | Paid | Paid low unit cost | Unlimited after warmup |
| Webhooks + suppressions + templates | Mature | Mature | Powerful, more IAM | Documented Mailgun-shaped |

Use this table inside an Architecture Decision Record, then link VERIFY footnotes to primary sources. Shopping nuance lives in the shopping sibling linked once in the intro; this build guide stays on implementation consequences: retry semantics, SDK gravity, and whether your webhook story fights IAM or HMAC.

### Migration notes for API builders leaving Mailgun

Practical migration sequence:

1. Create AEL account and domain; verify DNS (new SPF/DKIM—do not half-migrate)
2. Point non-prod Mailgun client base URL to AEL; run testmode
3. Re-register webhooks; store new signing_key; update verify code if field names differ slightly—confirm against docs
4. Export unsubscribes/complaints from Mailgun; import to AEL suppressions
5. Dual-write or cut traffic by tag
6. Switch SMTP credentials for legacy apps to AEL `smtp_password` + documented host/port
7. Decommission Mailgun when events show parity

Do not keep sending on two cold reputations forever. Warm the AEL domain with real transactional traffic following the ladder. Sibling detail for SMTP settings: [Replace Mailgun SMTP settings](/mailgun-smtp-settings-replace-mailgun/).


## FAQ

### Transactional email API vs SMTP?

A **transactional email API** is usually REST: authenticated HTTP, structured fields, events, templates, suppressions. **SMTP** is the classic submission protocol libraries already speak. You often want both. Agent Email List provides a Mailgun-shaped API and a real SMTP server on the same free forever account—with `smtp_password` issued once at domain create. Use API for observability-rich paths; use SMTP for legacy. Host/port from docs/dashboard only.

### Do I need webhooks day one?

Not for a hello-world. Yes before you promise delivery SLAs, bounce flagging, or “resend if failed” UX. Polling events works for debugging; webhooks scale with signed, deduped handlers. Register webhooks when any product state depends on delivered/failed/complained.

### How do recipient-variables work?

You send one request with multiple `to` recipients and a JSON map of per-recipient fields. Bodies use `%recipient.field%` placeholders. The service splits into per-recipient messages and events. Allowance still charges per message. Unknown placeholders stay visible—treat that as a typo detector. Confirm batch size limits in live docs.

### Unlimited after warmup on AEL?

Yes—the published ladder ends at **unlimited** after graduating **1,000/day** via the rung rules (10→20→100→1,000→unlimited). Day one is **10/day**. Idle days do not warm. Check `GET /v3/:domain/limits`. Unlimited does not mean unscreened or abuse-friendly; content screening and suppressions still apply. Free forever refers to packaging, not “no rules.”



### How do I read daily limits programmatically?

Call `GET /v3/:domain/limits` with your API key. Interpret the rung, today’s cap, remaining today, and stage progress fields as returned live—field names like `sent_this_stage` / `remaining_this_stage` exist so you do not reverse-engineer graduation math. Gate bulk workers on `remaining_today`. Surface the numbers in admin UI so non-engineers stop asking engineers to “just send the campaign.”

### Does a 200 mean the user received the email?

No. **200 means queued.** Delivery, deferral, bounce, or complaint arrive later as events. Product copy should say “we sent a reset email” only after acceptance, and support tooling should inspect events before blaming the user. If you must be precise in UI, “we queued a reset email” is honest; most products prefer softer language backed by solid webhook state.

### What about inbound email and routes?

AEL documents inbound routes (`/v3/routes`) and inbound message APIs. This build guide focuses on transactional **send** paths—events, webhooks, templates, suppressions, test mode, recipient-variables. If you need reply handling or support@ capture, read live docs for MX requirements and route expressions (`match_recipient`, `forward`, `store`). Do not publish MX until you intend to receive; it is optional for send-only domains.


### Who owns Agent Email List?

**Logan Besecker** owns and runs Agent Email List at [https://ai.agentemaillist.com](https://ai.agentemaillist.com). Contact via addresses published in product docs (e.g. me@LoganBesecker.com) for domain verify issues, delivery questions, or proper-use conversations. Ownership transparency is part of trusting the relay that carries password resets.



### How should I handle content_rejected?

Treat it as permanent for that payload. Surface `categories` to a human. Do not automate paraphrasing loops—the refusals accumulate against the account whether or not a single attempt “gets through.” Fix the template or user-generated content policy, then send a new intentional outbox item if appropriate.

### Can I open multiple domains to bypass the daily cap?

You should not. Spreading one job across domains to dodge warmup is called out in Agent Email List rules as trading away reputation. It also fragments suppressions and DNS ownership. Use `/limits`, slice the job, and wait for UTC midnight or graduation. Caps exist because receivers punish cold volume—fighting the ladder fights deliverability.

### What scopes should a send worker get?

Prefer least privilege: `messages:send` plus whatever read scopes it needs for limits (`domains:read` or as documented), and keep `suppressions:write`, `webhooks:write`, and `templates:write` on separate admin tasks. A compromised worker key that can only send is bad; one that can rewrite webhooks and delete suppressions is worse. Mint keys via `POST /v1/api-keys` with explicit `scopes` lists.

### Is MCP required?

No. MCP at `https://ai.agentemaillist.com/mcp` is convenient for agents. Human-authored product backends typically use REST. Both talk to the same service. This guide standardizes on REST so examples stay universal.


## Next steps + hard CTA

You now have the build spine: architecture, auth/domain bootstrap with `smtp_password`, Mailgun-shaped sending, templates, recipient-variables, events/webhooks, suppressions, test mode, observability, a reference module map, and fair API-builder comps.

Do this next, in order:

1. Create a free forever account at [https://ai.agentemaillist.com](https://ai.agentemaillist.com)
2. Add a domain; save API key + `smtp_password`; publish DNS; verify
3. Send with `o:testmode=yes` until `200`
4. Register a signed webhook; prove dedupe in staging
5. Wire outbox + warmup-aware scheduler reading `/limits`
6. Promote credentials carefully; keep transactional domain clean

**Hard CTA:** Stop mocking email in prod-shaped environments. Ship on Agent Email List—**free forever SMTP server + Mailgun-shaped REST API**, ladder **10→20→100→1,000→unlimited** after warmup.

**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**



### Week-one implementation calendar

A realistic calendar for a small team:

**Day 1:** Account, domain, secrets, DNS request to whoever owns the registrar; stub outbox schema.  
**Day 2:** Verify DNS; testmode send; basic REST wrapper; CI fixtures.  
**Day 3:** Webhook endpoint with HMAC verify + dedupe; delivered/failed handlers.  
**Day 4:** Password-reset template (stored or app-rendered); wire real outbox worker.  
**Day 5:** Bounce/complaint flagging; support “whathappened” admin view; limits gauge.  
**Day 6:** SMTP adapter only if required; staging live smoke to fixture inbox.  
**Day 7:** Production canary to staff; monitor events; schedule warmup-aware digests later.

Slip DNS early and the calendar slides—everything else is software. Slip webhooks and you will ship blind. Slip suppressions and you will earn complaints. Use the free forever account at [https://ai.agentemaillist.com](https://ai.agentemaillist.com) as the backbone so the calendar is not also a procurement project.


Cluster links:

- Pillar: [Free forever SMTP server — Mailgun & SendGrid alternatives](/free-smtp-relay)
- Shopping sibling (choose, don’t build): linked once in the intro for intent separation — do not treat this page as a vendor scorecard
- [Replace Mailgun SMTP settings](/mailgun-smtp-settings-replace-mailgun/)
- [Nodemailer free SMTP server setup](/nodemailer-free-smtp-server-setup/)

Build with events, webhooks, templates, suppressions, test mode, and recipient-variables—on infrastructure that stays free forever while your product climbs to unlimited/day.


### Definition of done for your first production email type

Your first production type (usually password reset) is done when:

- [ ] Domain active; monitoring for unverified drift
- [ ] Outbox + idempotency in place
- [ ] Testmode proven in CI; live smoke on fixture inbox done
- [ ] Webhook signature verify + dedupe shipped
- [ ] Bounce/complaint flags update user records
- [ ] Limits checked before any bulk adjacency
- [ ] Secrets stored; `smtp_password` and API keys not in git
- [ ] Support can answer “what happened?” from events
- [ ] Ownership known: Logan Besecker / ai.agentemaillist.com for vendor issues
- [ ] ADR cites free forever + ladder + Mailgun-shaped rationale

Ship that, then add invoices and digests. Feature factories that start with marketing blasts on a new domain are how ladders and reputations break.

