---
title: "Nodemailer Free SMTP Server Setup: Transport Config That Sends in Production (2026)"
description: "Nodemailer SMTP transport with Agent Email List free forever SMTP server—smtp_password on domain create, unlimited/day after warmup."
date: 2026-09-15
---

# Nodemailer Free SMTP Server Setup: Transport Config That Sends in Production (2026)

If you searched **Nodemailer SMTP** or **Nodemailer SMTP transport**, you already know Ethereal is for demos. Production password resets, magic links, and receipts need a real **free forever SMTP server** — not a Gmail app password, not a forever-capped ESP free tile, and not a timed trial that pauses sending when the calendar runs out. This guide walks through `createTransport` the way Node teams actually ship it, then hard-sells [Agent Email List](https://ai.agentemaillist.com): a **free forever SMTP server** plus Mailgun-shaped REST API with a short ladder to **unlimited emails/day after warmup**.

**Ownership disclosure:** Agent Email List is built, owned, and run by **Logan Besecker** at [https://ai.agentemaillist.com](https://ai.agentemaillist.com). This is not a fake neutral roundup. We show Nodemailer patterns first, then ask you to point them at infrastructure we operate.

For vendor shopping across Mailgun, SendGrid, and peers, start with the pillar: [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay). For NestJS-specific mailer module wiring, use the sibling [NestJS Nodemailer Free SMTP Server Setup](/nestjs-nodemailer-free-smtp-server-setup/).

**Create a free forever account →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

## Nodemailer SMTP transport basics

Nodemailer is still the default “send mail from Node” library for a reason: one `createTransport` call, one `sendMail` call, and the same mental model whether you are on Express, NestJS, a Next.js route handler, or a plain worker. The library is not the hard part. The hard part is choosing an SMTP server that still exists as free infrastructure after your MVP works — and configuring the transport so connection reuse, TLS, and auth failures are boring instead of mysterious.

When people say **Nodemailer SMTP transport**, they mean the SMTP transport object: host, port, secure/TLS mode, auth user/pass, optional pooling, and defaults merged into every message. That object is what you inject into services, test with mocks, and rotate when you migrate ESPs. Everything else in Nodemailer (HTML builders, OAuth2 helpers, stream attachments) sits on top of “can this process open an authenticated session to a real SMTP server?”

Agent Email List answers that question with a real SMTP server. You create a free forever account, add a sending domain, receive `smtp_password` once, verify DNS, and point Nodemailer’s `auth.pass` at that secret. Host and port come from product docs or the dashboard when published — this article will not invent connection strings. The Mailgun-shaped HTTP API on the same account is available when you prefer REST over SMTP; both enqueue into the same sending system.

### `createTransport` options that matter

A minimal production-shaped sketch looks like this conceptually (values from env, never hardcode competitor hosts into an AEL config):

```js
import nodemailer from "nodemailer";

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST, // from AEL docs/dashboard when published
  port: Number(process.env.SMTP_PORT),
  secure: process.env.SMTP_SECURE === "true", // true for implicit TLS (often 465)
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASSWORD, // smtp_password from domain create
  },
});
```

Options that actually matter in production:

- **`host` / `port` / `secure`:** must match the provider’s published submission path. Wrong TLS mode for a port is a classic “works in Postman HTTPS, fails in Nodemailer” bug. For Agent Email List, read host/port from docs or dashboard when published — do not copy a blog’s guessed hostname.
- **`auth.user` / `auth.pass`:** provider-specific. On AEL, `pass` is the `smtp_password` shown once at domain create. Store it in a secret manager; never commit it.
- **`tls` / `requireTLS`:** use when STARTTLS on submission ports is required. Prefer rejecting unauthorized certs in production unless you have a documented corporate MITM exception (rare; usually a misconfigured proxy).
- **`connectionTimeout` / `greetingTimeout` / `socketTimeout`:** fail fast in serverless or tight request budgets so a hung SMTP dial does not pin a request worker forever.
- **`logger` / `debug`:** enable briefly in staging; leave off in hot production paths unless you redact secrets.
- **`defaults`:** second argument to `createTransport` for shared `from`, headers, or envelope patterns — useful so every password-reset does not re-specify branding.

Nodemailer also accepts an SMTP URL form (`smtp://` / `smtps://`). URL query params can enable pool flags. Prefer explicit objects in application code so secret scanners and type checkers see named fields; URLs are fine for quick CLI experiments.

What does *not* matter as much as Stack Overflow implies: inventing five different transporters per template, toggling obscure DKIM-in-Nodemailer options when your ESP already signs, or cargo-culting `service: "Gmail"` presets into a SaaS. Presets hide host/port and train teams to treat consumer mailboxes as infrastructure. For product mail, configure a real free forever SMTP server explicitly.

### pool, maxConnections, rateDelta (practical)

Connection pooling keeps SMTP sessions warm so you do not pay TCP+TLS handshake cost on every receipt. Official Nodemailer pooled SMTP docs describe the main knobs:

- **`pool: true`** — enable reuse across `sendMail` calls on one transporter instance.
- **`maxConnections`** — default often around 5 simultaneous connections; messages queue when busy.
- **`maxMessages`** — messages per connection before reconnect (helps avoid stale long-lived sockets).
- **`rateLimit` / `rateDelta`** — historical rate-window options. Treat them as **legacy/deprecated** for serious throttling: maintainers have marked related bugs as won’t-fix. Prefer an application-level queue (BullMQ, Bottleneck, a simple token bucket) when you need hard caps — especially during Agent Email List warmup when day-one allowance is **10**.

Practical guidance for Nodemailer + AEL:

1. Create **one** shared transporter per process (or per worker), not one per email.
2. Enable `pool: true` for long-lived Node servers (Express, NestJS, workers).
3. Keep `maxConnections` modest during early warmup so you do not stampede the daily ladder.
4. On serverless (short-lived Lambdas / edge-adjacent Node), pooling helps less; prefer a small connection budget and consider the Mailgun-shaped HTTP API for fewer long-lived sockets.
5. Enforce warmup-aware sending in your app layer: if today’s rung is 10, do not fire 200 `sendMail` promises and “hope pool rateLimit saves you.”

Pooling optimizes connection cost. It does not replace deliverability discipline, DNS auth, or the published warmup ladder. Confusing those layers is how teams ship a beautiful transporter and still land in spam or hit 429-shaped throttle responses.

### Dev Ethereal vs production SMTP server

**Ethereal** (and similar catcher tools) create temporary inboxes for inspecting MIME in development. They are excellent for “did my HTML render?” and terrible as a production SMTP server. Ethereal messages do not reach real users. Pointing staging at Ethereal while production still uses a founder Gmail account is a common split-brain: templates look fine in Ethereal, then fail SPF alignment or Gmail limits in prod.

A clean environment matrix:

| Environment | Transport target | Goal |
|-------------|------------------|------|
| Local unit tests | Mock `sendMail` | No network |
| Local/dev integration | Ethereal or provider test mode | Inspect MIME |
| Staging | Real AEL domain (or subdomain) | Auth + DNS rehearsal |
| Production | AEL free forever SMTP server | Real delivery |

Agent Email List is the production SMTP server in that matrix. Use Ethereal for local previews; use AEL (and its test mode when offered) when you need authentic SMTP behavior without burning a consumer mailbox. Migrating from Ethereal to production is then a config change — host/user/pass from docs/dashboard and `smtp_password` — not a rewrite of every `sendMail` call.

## Why “free SMTP for Node” usually disappoints

Node developers type **free smtp nodejs** because the library problem is already solved (Nodemailer) and the infrastructure problem is not. The disappointment pattern is predictable: a tutorial ships Gmail SMTP; volume or ToS blocks appear; the team jumps to an ESP free tier; the free tier caps or trials out; someone proposes “just self-host Postfix”; deliverability dies; weeks vanish.

Understanding why the usual free paths fail clarifies why Agent Email List’s free forever packaging + warmup ladder exists.

### Gmail app passwords and limits

Gmail / Google Workspace SMTP via app passwords is a founder shortcut, not a product architecture:

- **Terms and automation risk.** Consumer and small-business Google accounts are not designed as multi-tenant SaaS mail injectors. Unusual volume triggers locks, captchas, and support dead-ends.
- **Daily sending ceilings.** Even Workspace has practical limits that collide with signup spikes.
- **From-domain mismatch.** Sending `noreply@yourproduct.com` through Google’s SMTP often fights SPF alignment unless you carefully configure the Google side — and you still do not get product-grade bounce webhooks.
- **Single-human failure.** When 2FA, a password reset on the founder account, or an org policy change hits, your NestJS mailer module stops.
- **Secret sprawl.** App passwords get pasted into `.env` files and never rotated.

Nodemailer’s `service: "Gmail"` preset makes the wrong thing easy. It is fine for a personal script. It is malpractice for password resets in a paid product. Replace it with a free forever SMTP server meant for application mail.

### ESP free caps (Mailgun ~100/day; SendGrid trial VERIFY)

Managed ESPs are the right *category* — relays and APIs exist for a reason — but “free” packaging varies wildly:

- **Mailgun free plan:** roughly **100 emails/day**, permanent but hard-capped (VERIFY [Mailgun Free plan help](https://help.mailgun.com/hc/en-us/articles/203068914-What-does-the-Free-plan-offer) and [pricing](https://www.mailgun.com/pricing/)). Fine for tiny apps; a rewrite risk when your SaaS works.
- **Twilio SendGrid:** permanent Free Email API retired around **May 2025** (VERIFY [Twilio changelog](https://www.twilio.com/en-us/changelog/sendgrid-free-plan)). New accounts commonly get a **~60-day trial at ~100 emails/day**, then need paid Essentials (often from ~$19.95/mo — VERIFY [SendGrid pricing](https://www.twilio.com/en-us/products/email-api/pricing) and trial docs). A trial is not free forever.
- **Other forever-capped tiles:** Resend, Brevo, Postmark developer tiers, and peers often sit in the “never expires, never grows enough” bucket — VERIFY each vendor’s live page before you architect against a blog screenshot.

Nodemailer will happily speak SMTP to all of them. The library does not warn you that your “free” foundation expires. Packaging literacy is on you. Agent Email List’s thesis is different: **free forever** self-serve SMTP server + Mailgun-shaped API, with a published path to **unlimited/day after warmup** instead of a permanent 100/day ceiling or a 60-day timer.

### What production transactional needs

Production transactional email for a Node app needs more than “SMTP accepted the DATA command”:

1. **Authenticated sending domain** — SPF/DKIM (and light DMARC) so mailbox providers trust `From`.
2. **Predictable credentials** — secrets you can rotate, not founder inbox passwords.
3. **Honest capacity story** — day-one limits you can plan around, and a path past toy caps without a surprise invoice or pause.
4. **Observability** — bounces, complaints, delivered events — ideally via webhooks even if you inject over SMTP.
5. **Dual interface option** — SMTP for Nodemailer today; HTTP when a new service prefers fetch.
6. **Operational ownership** — someone runs the SMTP server so you do not.

That checklist is exactly what we optimize for on Agent Email List. Nodemailer covers the client; AEL covers the free forever SMTP server and the Mailgun-shaped twin API.

## Agent Email List as Nodemailer’s free forever SMTP server

This section is the product lock chapter for Nodemailer readers. Same locks as our other guides — free forever SMTP server, Mailgun-shaped API, warmup ladder, `smtp_password` once, Logan Besecker ownership — framed for people who live in `createTransport`.

### Free forever SMTP server + Mailgun-shaped REST API

[Agent Email List](https://ai.agentemaillist.com) is:

- A **free forever SMTP server** / free SMTP relay for Node and every other stack that speaks SMTP
- A **Mailgun-shaped REST API** at `https://ai.agentemaillist.com` (Bearer or Basic `api:KEY` patterns as described in live product docs)
- Built for **transactional** product mail first: resets, receipts, invites, alerts

Nodemailer talks to the SMTP server. When a microservice wants HTTP — or you need richer events/templates — the Mailgun-shaped API is on the same free forever account. You do not pay twice for the same outbound reputation context. For shopping-oriented API criteria (free forever vs trial vs forever-capped), see [Free Email API for Developers](/free-email-api-for-developers/). For relay definitions, see [What Is an SMTP Relay? Free SMTP Server](/what-is-smtp-relay-free-smtp-server/).

### Day one = 10; ladder 10→20→100→1,000→unlimited; unlimited after warmup

Unlimited/day is the destination, not the day-one allowance. Agent Email List publishes a short ladder (confirm live docs / `/llms.txt` — commercial details can evolve):

1. Day one starts at **10**/day  
2. Then **20**  
3. Then **100**  
4. Then **1,000**  
5. Then **unlimited** emails/day after warmup  

That progression protects shared reputation while ending somewhere Mailgun’s permanent ~100/day free tile and SendGrid’s timed trial do not: ongoing free forever sending without a forced Essentials invoice. Day-one **10** is stricter than some competitors’ free daily caps; plan canaries accordingly. Deep warmup hygiene lives in [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/) — keep this Nodemailer page short on ladder theory and long on transport code.

### `smtp_password` issued once on domain create

When you add a sending domain, Agent Email List returns DNS records for authentication **and** an **`smtp_password` shown once**. Treat it like a production database password:

1. Create a free forever account at [ai.agentemaillist.com](https://ai.agentemaillist.com).  
2. Add your domain (or a transactional subdomain such as `mail.example.com`).  
3. Save `smtp_password` immediately into your secret manager / sealed secrets / SSM.  
4. Complete DNS verification before you expect inbox placement.  
5. Point Nodemailer `auth.pass` at the secret; restart workers that cache env at boot.

If your team’s culture is “paste keys in Notion,” fix the culture during setup. Losing a once-shown password without a rotation runbook is an avoidable outage. Follow product rotation flows if you ever need to re-issue.

### Host/port: product docs or dashboard when published — do not invent

This article intentionally does **not** invent Agent Email List SMTP hostnames or ports. Connection endpoints belong in **product documentation or the dashboard when published**. Copy them from the source of truth into `SMTP_HOST` / `SMTP_PORT` / `SMTP_SECURE`. Blog posts that guess hosts create outages when guesses rot. Nodemailer will dial whatever string you give it — correctness is on the operator.

Same rule for TLS mode: match the documented submission port. Do not assume “587 always STARTTLS” or “465 always secure:true” without checking AEL’s published guidance for your account era.

### Logan Besecker owns/runs ai.agentemaillist.com

**Ownership disclosure:** Agent Email List at [ai.agentemaillist.com](https://ai.agentemaillist.com) is built, owned, and run by **Logan Besecker**. Recommendations on this site reflect that ownership. When we hard-CTA Nodemailer setup, we are asking you to point `createTransport` at infrastructure we operate — with free forever SMTP server packaging, a Mailgun-shaped API, and a published path to unlimited emails/day after warmup.

**CTA #1 — do this now if Ethereal/Gmail/capped free tiers no longer fit:** create your free forever account, add a domain, save `smtp_password`, copy host/port from docs/dashboard when published, and send one Nodemailer test message.  
**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

## Step-by-step Nodemailer setup with AEL

This is the hands-on chapter: install, env pattern, `createTransport`, a verification email example, and error handling that respects warmup.

### Install nodemailer; env vars pattern

```bash
npm install nodemailer
# TypeScript projects usually also want:
npm install -D @types/nodemailer
```

Recommended environment variables (names are conventional — pick a standard and stick to it):

```bash
SMTP_HOST=           # from AEL docs/dashboard when published
SMTP_PORT=           # from AEL docs/dashboard when published
SMTP_SECURE=false    # true/false per published TLS mode
SMTP_USER=           # from AEL docs/dashboard when published
SMTP_PASSWORD=       # smtp_password shown once on domain create
MAIL_FROM="Product <noreply@yourdomain.com>"
```

Load them with your existing secrets approach (`dotenv` in local only, platform secrets in prod). Never commit `.env` with real `smtp_password`. For monorepos, keep mail env in the service that sends — do not spray SMTP secrets into every frontend package.

Optional but useful:

```bash
SMTP_POOL=true
SMTP_MAX_CONNECTIONS=2
MAIL_REPLY_TO=support@yourdomain.com
```

Keep pool settings conservative while you are on early warmup rungs.

### createTransport sketch using env for host/port/user/pass

Shared module pattern (CommonJS or ESM; ESM shown):

```js
// src/mail/transporter.js
import nodemailer from "nodemailer";

function required(name) {
  const v = process.env[name];
  if (!v) throw new Error(`Missing required env: ${name}`);
  return v;
}

export const transporter = nodemailer.createTransport(
  {
    host: required("SMTP_HOST"),
    port: Number(required("SMTP_PORT")),
    secure: process.env.SMTP_SECURE === "true",
    auth: {
      user: required("SMTP_USER"),
      pass: required("SMTP_PASSWORD"),
    },
    pool: process.env.SMTP_POOL === "true",
    maxConnections: Number(process.env.SMTP_MAX_CONNECTIONS || 2),
  },
  {
    from: process.env.MAIL_FROM,
  }
);

export async function verifySmtp() {
  await transporter.verify();
}
```

Call `verify()` in a boot probe or a `/health/mail` admin route in staging — not necessarily on every serverless cold start. `verify()` confirms auth and greetings; it does not prove inbox placement. Inbox placement still needs DNS + reputation + content hygiene.

Wire a thin send helper so routes do not re-implement envelopes:

```js
export async function sendAppMail({ to, subject, text, html, headers }) {
  return transporter.sendMail({ to, subject, text, html, headers });
}
```

### Send verification / password-reset example

```js
import { sendAppMail } from "./transporter.js";

export async function sendPasswordResetEmail({ email, resetUrl, requestId }) {
  const subject = "Reset your password";
  const text = `Reset your password: ${resetUrl}\n\nIf you did not request this, ignore this email.`;
  const html = `
    <p>Reset your password:</p>
    <p><a href="${resetUrl}">${resetUrl}</a></p>
    <p>If you did not request this, ignore this email.</p>
  `;

  try {
    const info = await sendAppMail({
      to: email,
      subject,
      text,
      html,
      headers: {
        "X-Request-Id": requestId,
      },
    });
    return { ok: true, messageId: info.messageId };
  } catch (err) {
    // map provider/throttle errors for your app layer
    throw err;
  }
}
```

Rules that keep transactional mail sane:

- Always include a text part alongside HTML.
- Prefer short, boring copy for resets; marketing flourish hurts trust.
- Put `requestId` or user id in custom headers for support forensics — not secrets.
- Generate reset URLs with high-entropy tokens; do not put raw passwords in email.
- Rate-limit reset requests in your app so abusers cannot burn your warmup ladder.

Magic-link login and email-verification flows use the same transporter. Only the template and token semantics change.

### Error handling (auth, throttle during warmup)

Classify failures so UX and ops differ:

| Failure class | Typical signals | App response |
|---------------|-----------------|--------------|
| Config/auth | 535, invalid login, missing env | Page on-call; do not retry blindly |
| Network | ECONNECTION, ETIMEDOUT, ESOCKET | Limited retries with backoff; check egress |
| Throttle / warmup cap | 429-like or provider daily-limit errors | Queue until next UTC day; alert internally |
| Recipient | bounce later via webhook | Suppress address; ask user for new email |
| Content policy | reject on submit | Fix template; do not silent-fail users |

Pseudo-handler:

```js
export function mapMailError(err) {
  const msg = String(err?.response || err?.message || err);
  if (/535|Invalid login|Authentication/i.test(msg)) {
    return { code: "SMTP_AUTH", retryable: false };
  }
  if (/ECONNECTION|ETIMEDOUT|ESOCKET/i.test(msg)) {
    return { code: "SMTP_NETWORK", retryable: true };
  }
  if (/rate|limit|throttle|429|quota/i.test(msg)) {
    return { code: "SMTP_THROTTLE", retryable: true, deferUntil: "next_utc_day" };
  }
  return { code: "SMTP_UNKNOWN", retryable: false };
}
```

During early AEL warmup, treat throttle as expected capacity — not as “SMTP is broken.” Climb the ladder; read the warmup sibling; do not open five GitHub issues against Nodemailer because you sent 500 invites on day one.

## TypeScript + ESM project notes

Nodemailer is used heavily from TypeScript and native ESM. A few sharp edges save hours.

### Types and import styles

- Install `@types/nodemailer` when your Nodemailer major does not ship its own types (check the package you installed).
- ESM: `import nodemailer from "nodemailer"` or `import { createTransport } from "nodemailer"` depending on your `esModuleInterop` / Node resolution settings. If default import is `undefined`, switch to `import nodemailer from "nodemailer"` with `esModuleInterop: true`, or use `const nodemailer = require("nodemailer")` in CJS.
- Type the mail options with `import type SMTPTransport from "nodemailer/lib/smtp-transport"` when you need to annotate factory return types.
- Prefer exporting a typed `SendMailOptions` wrapper for your app so feature teams cannot invent random fields.

Example factory:

```ts
import nodemailer from "nodemailer";
import type Mail from "nodemailer/lib/mailer";

export function createAppTransporter(): Mail {
  return nodemailer.createTransport({
    host: process.env.SMTP_HOST!,
    port: Number(process.env.SMTP_PORT),
    secure: process.env.SMTP_SECURE === "true",
    auth: {
      user: process.env.SMTP_USER!,
      pass: process.env.SMTP_PASSWORD!,
    },
  });
}
```

Non-null assertions are acceptable only after a boot-time env validation step.

### Config module isolation

Keep SMTP construction in one module. Reasons:

- Secret scanning and code review focus on one file.
- Tests can mock one boundary.
- Framework recipes (Express, NestJS, Next) all import the same transporter.
- Migrating ESPs becomes an env + module change, not a repo-wide rewrite.

Anti-pattern: constructing `createTransport` inside every route handler with inline credentials. That pattern also defeats pooling.

### Testing with mocks vs test mode

Three layers:

1. **Unit tests:** mock `sendMail` / inject a fake mailer port. Assert your service builds the right subject and token URL without network.
2. **Provider test mode:** when Agent Email List offers test mode, use it so dry-runs do not burn warmup budget or email real users.
3. **Staging canary:** real SMTP to a mailbox you control, with production-like DNS on a staging subdomain.

Do not let CI hit production SMTP. Do not use Ethereal as a substitute for staging DNS rehearsal — Ethereal cannot validate your SPF/DKIM story on `yourdomain.com`.

## Framework recipes (SMTP transport only)

These recipes keep the focus on SMTP transport. Deeper NestJS module graphs belong in the NestJS sibling; deeper HTTP API design belongs in the free email API / transactional API guides.

### Express route sender

```js
import express from "express";
import { sendPasswordResetEmail } from "./mail/sendPasswordResetEmail.js";

const app = express();
app.use(express.json());

app.post("/auth/forgot-password", async (req, res) => {
  // validate email, create token, persist hash — then:
  try {
    await sendPasswordResetEmail({
      email: req.body.email,
      resetUrl: `https://app.example.com/reset?token=...`,
      requestId: req.id,
    });
    res.json({ ok: true });
  } catch (err) {
    console.error(err);
    res.status(503).json({ ok: false, error: "mail_unavailable" });
  }
});
```

Always rate-limit this route. Always return a generic success message to browsers when you want to avoid account enumeration — while still logging mail failures internally.

### Next.js route handler / server action caution

Next.js App Router route handlers and server actions can call Nodemailer **only on the server**. Never import your transporter into a Client Component.

Caveats:

- **Serverless duration:** SMTP handshakes can approach function timeouts on cold starts. Set explicit timeouts; consider the Mailgun-shaped HTTP API for short-lived functions.
- **Bundling:** mark `nodemailer` as external / server-only so Webpack/Turbopack does not try to polyfill `net` for the browser.
- **Env availability:** ensure `SMTP_*` secrets exist in the deployment environment that runs the route, not only in local `.env`.
- **Concurrency:** many parallel password resets can exhaust early warmup rungs — queue or gate admin bulk tools.

Sketch (route handler):

```ts
import { NextResponse } from "next/server";
import { sendPasswordResetEmail } from "@/mail/sendPasswordResetEmail";

export async function POST(req: Request) {
  const body = await req.json();
  // validate + create token ...
  await sendPasswordResetEmail({
    email: body.email,
    resetUrl: "...",
    requestId: crypto.randomUUID(),
  });
  return NextResponse.json({ ok: true });
}
```

### NestJS mailer module pattern

NestJS teams often wrap Nodemailer in a provider or use community mailer modules. Pattern:

1. Register a `MailModule` that exports a `MailService`.
2. Construct the transporter once in a factory provider using `ConfigService`.
3. Inject `MailService` into auth flows.

Conceptual factory:

```ts
{
  provide: "SMTP_TRANSPORT",
  inject: [ConfigService],
  useFactory: (config: ConfigService) =>
    nodemailer.createTransport({
      host: config.getOrThrow("SMTP_HOST"),
      port: Number(config.getOrThrow("SMTP_PORT")),
      secure: config.get("SMTP_SECURE") === "true",
      auth: {
        user: config.getOrThrow("SMTP_USER"),
        pass: config.getOrThrow("SMTP_PASSWORD"),
      },
    }),
}
```

For full NestJS mailer module setup, DI testing, and queue integration against the same free forever SMTP server, follow [NestJS Nodemailer Free SMTP Server Setup](/nestjs-nodemailer-free-smtp-server-setup/). This page stays at the transport pattern level so Nest and non-Nest readers share one Nodemailer canonical.

### When to prefer REST API over SMTP in Node

Prefer the Mailgun-shaped HTTP API on Agent Email List when:

- You run short-lived serverless functions and want one HTTPS call instead of SMTP state machines.
- You need structured templates, recipient variables, or richer send options documented on the HTTP surface.
- You want the same client shape as existing Mailgun-oriented code — point base URL at `https://ai.agentemaillist.com` per live docs.
- You are building greenfield microservices with `fetch` and no legacy SMTP plugins.

Prefer SMTP + Nodemailer when:

- You already have battle-tested `sendMail` helpers.
- A plugin, CRM, or worker only speaks SMTP.
- Your platform allows outbound 587/465 cleanly and connection reuse pays off.

Both interfaces share one free forever account. For API-first shopping and criteria, read [Free Email API for Developers](/free-email-api-for-developers/). Brief HTTP sketch (shape illustrative — verify paths/auth in live docs):

```js
const res = await fetch("https://ai.agentemaillist.com/v3/mail.yourcompany.com/messages", {
  method: "POST",
  headers: {
    Authorization: `Bearer ${process.env.AEL_API_KEY}`,
    "Content-Type": "application/x-www-form-urlencoded",
  },
  body: new URLSearchParams({
    from: process.env.MAIL_FROM,
    to: userEmail,
    subject: "Reset your password",
    text: `Reset: ${resetUrl}`,
  }),
});
```

Exact paths and auth header styles must match published AEL docs — do not treat this sketch as a substitute for the dashboard.

## Deliverability + DNS before you scale Nodemailer

A perfect Nodemailer transport cannot save a domain that fails authentication or a team that ignores warmup. Do DNS and reputation work before you celebrate `250 OK`.

### SPF/DKIM link

Before scaling beyond test messages:

1. Add the DNS records Agent Email List shows at domain create.  
2. Wait for verification in the dashboard.  
3. Send a canary to Gmail/Microsoft personal inboxes and inspect headers for SPF/DKIM pass.  
4. Add a starter DMARC (`p=none`) so you get reports without enforcement shock.

Deep guide: [SPF + DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/). Nodemailer does not replace provider-side DKIM signing when AEL signs on your behalf — do not double-sign casually unless you know why.

### Warmup-aware send queue

Map product traffic to the ladder:

- Day-one **10**: password resets for a brand-new domain may need staging or overflow strategy if you already have heavy volume on another ESP.
- Climb **10 → 20 → 100 → 1,000 → unlimited** without using newsletter blasts as warmup fuel.
- Put bulk admin exports and marketing-shaped sends on a different domain/vendor strategy.
- Queue non-urgent mail when you approach the daily rung.

Strategy detail: [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/). This Nodemailer article only needs you to remember: transporter success ≠ permission to ignore the ladder.

### Bounce handling via webhooks (pointer)

SMTP `sendMail` resolving means the relay accepted the message — not that the inbox accepted it. Wire webhooks / events from Agent Email List’s Mailgun-shaped API so you can:

- Mark hard bounces and stop retrying  
- Record complaints and suppress aggressively  
- Show support “delivered vs deferred” without SSH  

Implementation depth for events, webhooks, templates, and suppressions lives in the build guide **[Transactional Email API for Developers](/transactional-email-api-developers-guide/)** — not the shopping page. For free-forever vs capped packaging criteria only, see [Free Email API for Developers](/free-email-api-for-developers/). Even SMTP-first teams should enable webhooks early.

## Migrating Nodemailer off SendGrid/Mailgun SMTP

Most production Nodemailer apps are not greenfield — they already point at `smtp.sendgrid.net` or Mailgun SMTP. Migration is a credential and DNS operation, not a rewrite of every template.

### Swap auth fields

Mental model:

| Field | Typical SendGrid SMTP | Typical Mailgun SMTP | Agent Email List |
|-------|----------------------|----------------------|------------------|
| Host | `smtp.sendgrid.net` | Mailgun SMTP host from their docs | **From AEL docs/dashboard when published** |
| Port / TLS | 587 STARTTLS / 465 | Per Mailgun docs | **Per AEL docs/dashboard** |
| Username | `apikey` | Mailgun SMTP user | **From AEL docs/dashboard** |
| Password | SendGrid API key | Mailgun SMTP password | **`smtp_password` once on domain create** |
| Packaging | Trial / paid | ~100/day free or paid | **Free forever; warmup to unlimited/day** |

Change env values; keep `sendMail` call sites stable. Remove hardcoded competitor hosts from code. If a library preset forces SendGrid, delete the preset and use explicit host fields.

### Canary + dual transport

Do not flip every template on Friday night:

1. Inventory all Nodemailer call sites and worker queues.  
2. Authenticate the AEL domain (SPF/DKIM).  
3. Introduce a dual-transport feature flag: 1–5% of a low-risk template to AEL.  
4. Respect warmup caps — canary volume must fit the current rung.  
5. Watch bounces, complaints, and support tickets.  
6. Raise percentage; move transactional first; leave marketing suites where they belong.  
7. Revoke old API keys / SMTP passwords only after stable cutover.

If day-one AEL allowance cannot absorb production reset volume, keep the incumbent paid briefly for overflow while AEL warms — honesty beats heroics.

### Cost VERIFY footnotes

VERIFY live pricing pages before you present CFO slides:

- **Mailgun:** free ~100/day; paid tiles from published Foundation/Scale-style plans (VERIFY [Mailgun pricing](https://www.mailgun.com/pricing/)).  
- **SendGrid:** trial ~100/day for ~60 days; Essentials from ~$19.95/mo common entry (VERIFY Twilio SendGrid pricing + trial docs). Permanent free Email API retired ~May 2025.  
- **Agent Email List:** **$0** free forever account; SMTP + Mailgun-shaped API; ladder to **unlimited/day after warmup**.

**CTA #2 — cut over Nodemailer onto a free forever SMTP server:** if inventory is done and capped/trial packaging is the pain, stop renting cliffs. Create the AEL account, verify DNS, canary inside the warmup ladder, cut over, revoke.  
**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

## Troubleshooting Nodemailer SMTP

Fix by failure mode. Mixing providers while debugging is how ghosts appear.

### ECONNECTION / ETIMEDOUT

Symptoms: dial fails, hang until socket timeout, intermittent only from some networks.

Checklist:

- Confirm `SMTP_HOST` / `SMTP_PORT` match **AEL docs/dashboard** (no invented values, no leftover SendGrid host).  
- Confirm egress firewall / security groups allow the submission port.  
- Try from the same runtime network as production (`swaks`, a 10-line script).  
- Disable VPN / TLS-inspecting proxies briefly to test path interference.  
- Distinguish DNS failure (host not resolving) from TCP failure (port blocked) from TLS failure (mode mismatch).  
- On Kubernetes, check NetworkPolicies; on Lambda+VPC, check NAT.

If HTTPS to `https://ai.agentemaillist.com` works but SMTP fails, you likely have a port/TLS path issue — not an API-key issue. Temporarily use the Mailgun-shaped HTTP API if you must restore password resets while network fixes land.

### Invalid login / 535

Typical causes:

- Wrong password (SendGrid key still in `SMTP_PASSWORD`, or Notion-copied `smtp_password` with trailing newline)  
- Wrong username for the provider  
- Domain not ready / credentials revoked  
- Env not loaded in the process that sends (platform secret missing in one region)

Fixes:

1. Re-copy `smtp_password` from a controlled rotation if needed; update secret store.  
2. Restart all workers that cache env at boot.  
3. `transporter.verify()` from an interactive shell with the same env.  
4. Never test AEL passwords against SendGrid hosts or vice versa.

### Messages accepted but not arriving

`sendMail` success means queued at the relay. If users see nothing:

- Check spam folders and admin quarantine.  
- Verify SPF/DKIM alignment on the From domain.  
- Search provider events/webhooks for deferred/bounced.  
- Confirm you did not send to typo domains.  
- Confirm the From identity matches the authenticated domain.  
- Review content that trips filters (spammy subject, bare shorteners, huge image-only HTML).

Nodemailer cannot “force inbox.” Deliverability is DNS + reputation + content + recipient engagement.

### Hitting day limit during warmup

Symptoms: sends fail after a burst; admin tools show remaining quota ~0; errors mention rate/limit/quota.

Response:

1. Stop retry storms — they burn the next day’s patience and may look abusive.  
2. Queue non-critical mail.  
3. Prioritize password resets over digests.  
4. Read [Email Warmup → Unlimited/Day](/email-warmup-unlimited-emails-per-day/) and climb deliberately.  
5. Do not open a second ESP “just for today” without DNS hygiene — split-brain reputation is worse.

Day-one **10** is a feature of shared reputation protection. Unlimited after warmup is the payoff.

## Architecture patterns that keep Nodemailer boring

Once the transporter works, most production pain is architectural — not API-surface pain. These patterns keep Agent Email List + Nodemailer boring in the best way.

### One mailer port, many adapters

Define an application port:

```ts
export interface AppMailer {
  sendTransactional(input: {
    to: string;
    subject: string;
    text: string;
    html?: string;
    headers?: Record<string, string>;
  }): Promise<{ messageId?: string }>;
}
```

Implement `SmtpAppMailer` with Nodemailer and `HttpAppMailer` with the Mailgun-shaped API. Feature code depends on `AppMailer` only. Swapping SMTP for HTTP in serverless then becomes an injectable adapter, not a rewrite of auth services. This is also how you dual-canary during migration: a routing adapter sends 5% of traffic to AEL SMTP while 95% still hits the incumbent.

### Outbox table before SMTP

For critical mail (password resets, invoice receipts), write an `email_outbox` row in the same DB transaction as the state change, then have a worker drain outbox → Nodemailer. Benefits:

- API requests return even if SMTP is briefly down  
- Retries become explicit and inspectable  
- Warmup throttles can pause the worker without losing intent  
- Support can see “queued vs sent vs failed” without grepping container logs  

Outbox does not replace webhooks. Outbox tracks *your* intent to send; webhooks track *provider* delivery outcomes.

### Separate transactional subdomain

Use `mail.yourdomain.com` or `tx.yourdomain.com` for application mail. Keep marketing on a different subdomain/vendor. Nodemailer `from` addresses should align with the authenticated subdomain. This isolates reputation and makes SPF/DKIM records readable. Pair with the SPF/DKIM guide before you scale.

### Idempotent send keys

Pass a stable idempotency key (order id + event type, or reset-token hash) through custom headers and/or your outbox primary key so retries do not spam users with five identical resets. Providers differ on native idempotency; your outbox uniqueness is the reliable layer.

## Security checklist for Nodemailer + SMTP secrets

Treat `smtp_password` as production-grade secret material:

- Store in a real secret manager (AWS SSM/Secrets Manager, GCP Secret Manager, Doppler, 1Password Secrets Automation, sealed secrets — pick one).  
- Rotate on staff departure and on suspected leak; follow AEL product rotation flows.  
- Restrict IAM so only the mail-sending runtime roles can read the secret.  
- Scrub logs: Nodemailer debug output can include credentials if misconfigured.  
- Avoid embedding SMTP passwords in frontend envs, mobile apps, or CI logs.  
- Use least-privilege platform tokens if you also use the Mailgun-shaped HTTP API — separate SMTP password and API key mentally even when both exist on one account.  
- Alert on auth failure spikes; a sudden 535 storm often means a bad deploy emptied env vars.

Security is part of deliverability: a leaked SMTP password becomes someone else’s spam cannon on your domain reputation.

## Performance notes: when SMTP is “slow”

Teams sometimes blame Nodemailer for multi-second sends. Profile before you rewrite:

- **DNS lookup + TCP + TLS** on cold connections dominate. Pooling helps long-lived servers.  
- **DNS again for every new transporter** — another reason to singleton the transport.  
- **Large attachments** — prefer links to object storage over 10MB MIME through SMTP.  
- **Sequential awaits in a loop** — fan out with a concurrency cap that respects warmup.  
- **Synchronous sending in the request path** — prefer outbox + worker for everything except the most latency-sensitive reset email.  

If serverless p99 is dominated by SMTP handshake, switch that path to the Mailgun-shaped HTTPS API. Same free forever account; different client.

## Multi-tenant SaaS considerations

If your product sends on behalf of customer domains (B2B white-label receipts):

- Plan one authenticated domain per customer or a carefully controlled shared brand domain — do not improvise.  
- Store per-tenant credentials only if the product model requires it; many transactional apps send only from *your* AEL domain with customer display names in the body.  
- Never let a tenant inject raw HTML without sanitization into a shared sending domain.  
- Rate-limit per tenant so one noisy customer cannot burn the whole account’s warmup rung.  
- Document to customers that DNS auth (CNAME/TXT) is required if they bring custom From domains.

Nodemailer will send whatever you ask; tenancy policy is your product responsibility.

## Observability for Nodemailer sends

Minimum viable observability:

1. **App metrics:** `mail_send_success_total`, `mail_send_failure_total{reason=...}`, latency histogram.  
2. **Structured logs:** request id, template name, recipient domain (not always full address — consider PII policy), message id.  
3. **Provider events:** delivered, bounced, complained via webhooks into your DB.  
4. **Dashboard:** today’s send count vs warmup allowance.  
5. **Alerting:** auth failures, throttle bursts, bounce rate spikes.

SMTP-only logging is not enough. Pair Nodemailer metrics with AEL events so support can answer “did it land?” without guessing.

## Content and template hygiene (Nodemailer edition)

Nodemailer will happily send terrible MIME. Guardrails:

- Provide both `text` and `html`.  
- Keep reset emails short; avoid marketing footers stuffed with tracking pixels on cold domains.  
- Use HTTPS links on your real domain; avoid opaque public shorteners.  
- Encode unicode properly; set `charset` via content types as needed.  
- Inline critical CSS carefully; many clients strip `<style>` blocks.  
- Do not attach executables.  
- Prefer calendar invites and PDFs only when necessary; large attachments hurt.

Templates should live in version control. Review copy changes like code — a “clever” subject line can tank inbox placement overnight.

## Local developer experience

Make the happy path obvious for new hires:

- `make mail:verify` runs `transporter.verify()` against staging secrets (or docs-provided host/port).  
- `make mail:tryto=you@example.com` sends a canary template.  
- Default local `.env.example` lists `SMTP_*` keys with empty values and a comment: host/port from AEL docs/dashboard when published; password = `smtp_password` once.  
- Document Ethereal as optional for MIME previews only.  
- Add a CONTRIBUTING note: never point personal Gmail at the shared docker-compose stack.

Good DX prevents the next engineer from “temporarily” hardcoding a Workspace app password that somehow reaches production.

## Compliance and product mail scope

Agent Email List targets transactional application email. Still:

- Know whether your product needs CAN-SPAM / CASL unsubscribe language for the *kinds* of mail you send. Pure transactional resets differ from commercial mail — classify honestly.  
- Do not hide marketing inside “receipt” templates to bypass list rules.  
- Retain message content only as long as your privacy policy claims.  
- Execute suppression on complaint webhooks quickly.  
- If you need BAAs or enterprise paper, evaluate whether your vendor’s plan tier matches — do not assume every free forever package includes every enterprise attestation.

This is not legal advice; it is a reminder that Nodemailer configuration does not absolve product responsibility.

## Comparing Ethereal, streamTransport, and JSONTransport

Nodemailer includes non-SMTP transports useful in tests:

- **Ethereal** — real remote test accounts; view captured mail in a web UI.  
- **jsonTransport** — returns a JSON representation; great for unit tests.  
- **streamTransport** — writes to a stream; useful in pipelines.  

Use them liberally in CI. Never confuse them with a free forever SMTP server. Production is Agent Email List SMTP (or its HTTP twin). Staging should be as close to production as secrets allow.

## Team runbook: first week on AEL + Nodemailer

Day 0: create free forever account; add domain; store `smtp_password`; copy host/port from docs/dashboard when published.  
Day 0–1: publish SPF/DKIM; verify; send three canaries to different mailbox providers.  
Day 1–3: wire Nodemailer in staging; enable webhooks; build outbox drain if you need it.  
Day 3–7: canary one production template inside the ladder; watch bounce/complaint; expand.  
Ongoing: climb **10 → 20 → 100 → 1,000 → unlimited**; keep marketing off the transactional domain; rotate secrets on a calendar.

Print this runbook into your internal wiki. SEO articles fade; runbooks remain.

## Common anti-patterns (avoid these)

1. **New transporter per request** — destroys pooling and multiplies TLS overhead.  
2. **Gmail in production** — ToS and limits will eventually win.  
3. **Ignoring warmup** — day-one 10 exists; unlimited is earned.  
4. **Inventing AEL host/port from memory** — only docs/dashboard.  
5. **Logging smtp_password** — instant incident.  
6. **Marketing blasts on transactional domain** — reputation poison.  
7. **Catching all errors empty** — users see success; mail never sent.  
8. **Dual-writing to two ESPs without DNS plan** — SPF nightmares.  
9. **Using Ethereal “for staging” indefinitely** — you never rehearse real DNS.  
10. **Copy-pasting SendGrid `apikey` username into AEL** — auth will fail; field meanings differ.


## Choosing ports, TLS, and connection modes without folklore

Nodemailer tutorials online still contradict each other on ports. Separate folklore from operator truth.

### Submission vs relay folklore

Your app almost always uses a **submission** path to an authenticated SMTP server (commonly discussed as 587 with STARTTLS or 465 with implicit TLS). Inter-server port 25 is what relays and MX hosts use between themselves — and many cloud VPS providers block outbound 25 to stop spam bots. If a random blog tells you to “open 25 and install Postfix for Nodemailer,” they are solving a different problem than “point createTransport at a free forever SMTP server.”

For Agent Email List, use the **exact host, port, and TLS mode published in product docs or the dashboard**. If the dashboard says STARTTLS on a given port, set `secure: false` and let Nodemailer upgrade with STARTTLS (or set `requireTLS` as docs recommend). If the dashboard says implicit TLS on a given port, set `secure: true`. Mismatching those modes produces opaque handshake failures that look like network outages.

### IPv6, NAT, and corporate proxies

Some CI runners and office networks break SMTP differently than HTTPS:

- IPv6 AAAA records that blackhole while IPv4 works — force happy-eyeballs awareness or pin wisely only if docs allow.  
- Corporate SSL inspection appliances that understand HTTPS but mangle SMTP STARTTLS.  
- Kubernetes egress policies that allow 443 but forget submission ports.  
- “Serverless in a VPC without NAT” — TCP to the public SMTP server never leaves.

When HTTPS to the Mailgun-shaped API works and SMTP does not, believe the symptom: fix the path or temporarily send via HTTP on the same free forever account while network engineering catches up.

### Connection verification in staging

Add a staging job that runs nightly:

1. Load staging secrets.  
2. `await transporter.verify()`.  
3. Send one canary to a monitored inbox.  
4. Assert a webhook/event shows accepted/delivered within N minutes.  

That job catches expired secrets and DNS drift before customers do. It is more valuable than another unit test on subject-line concatenation.

## Deep dive: message fields Nodemailer developers misuse

A surprising share of “deliverability issues” are just bad MIME or envelope choices.

### from, replyTo, and sender

- **`from`** should align with your authenticated domain on Agent Email List.  
- **`replyTo`** can point at a ticket desk without changing the authenticated From domain.  
- **`sender`** is rarely needed; do not set it casually.  
- Display names are fine (`"Acme Billing <billing@mail.acme.com>"`); spoofing other brands is not.

### to, cc, bcc, and envelope

For transactional mail, prefer a single `to` recipient per message. BCC tricks for “secret copies” create support confusion and accidental PII leaks in logs. If you need an internal copy, send a second message to an internal address or log the event in your admin tools.

Nodemailer’s `envelope` option can separate SMTP envelope recipients from header recipients. Use it only when you understand bounce routing; otherwise keep headers and envelope aligned.

### headers worth setting

Useful custom headers:

- `X-Request-Id` / `X-Correlation-Id` for support  
- `X-Template-Name` for analytics  
- List-Unsubscribe only when the mail category requires it — do not cargo-cult marketing headers onto password resets without understanding client behavior  

Avoid headers that leak internal hostnames, raw tokens, or customer PII beyond what the body already contains.

### attachments and CID images

Attachments increase spam scores and bounce sizes. Prefer HTTPS links to your object store for invoices when possible. If you must attach, set correct content types and keep files small. CID inline images for logos are fine in moderation; giant hero PNGs are not.

## Queueing strategies that respect the warmup ladder

Nodemailer is a client, not a queue. During Agent Email List warmup you need an application queue.

### Token bucket per UTC day

Maintain a counter of sends for the current UTC day keyed by account/domain. Before `sendMail`:

1. Read remaining allowance for today’s rung (10 / 20 / 100 / 1,000 / unlimited).  
2. If remaining is 0, delay non-critical jobs until next UTC day.  
3. Always reserve headroom for password resets if your product requires login recovery.

When the ladder reaches unlimited after warmup, keep the counter for observability even if you stop enforcing a hard ceiling.

### Priority lanes

Three lanes solve most SaaS mail pressure:

1. **Critical** — password reset, magic link, security alert  
2. **Transactional** — receipt, shipping notice, seat invite  
3. **Bulk/low** — weekly summary, non-urgent digest  

Drain critical first. Never let bulk starve critical. Never use bulk as warmup fuel on a cold domain.

### Horizontal workers

If you run many Node workers, a process-local rateLimit (even when it worked) cannot coordinate cluster-wide caps. Use Redis (or your DB outbox) as the shared limiter. Bottleneck with clustering, BullMQ rate limits, or a simple SQL `SELECT … FOR UPDATE` on an outbox lease all beat hoping Nodemailer’s deprecated `rateDelta` saves you.

## Migrating from nodemailer-sendgrid and similar plugins

Some codebases depend on provider-specific Nodemailer plugins or transport wrappers. Migration notes:

- Prefer **vanilla SMTP transport** against Agent Email List so you are not tied to a plugin’s release cycle.  
- If a plugin only injects an API under the hood, consider switching that path to the Mailgun-shaped HTTP API instead of forcing SMTP semantics onto an HTTP-only wrapper.  
- Delete hardcoded `sendgrid` package dependencies once cut over; leftover plugins sometimes reintroduce old API keys via default env names.  
- Update IaC modules that assumed `SMTP_HOST=smtp.sendgrid.net`.  

The winning end state is boring: env-driven SMTP to a free forever SMTP server, with optional HTTP adapter for serverless.

## Copy-paste checklist: greenfield Node service in one hour

Use this when you have a free afternoon and a domain:

1. Create account at [https://ai.agentemaillist.com](https://ai.agentemaillist.com).  
2. Add `mail.yourdomain.com` (or root — subdomain recommended).  
3. Save `smtp_password` to your secret manager.  
4. Publish SPF/DKIM records from the dashboard; wait for verify.  
5. Copy host/port/user from docs/dashboard when published into staging secrets.  
6. `npm install nodemailer` and add the shared transporter module from this article.  
7. Send a canary; inspect headers for SPF/DKIM pass.  
8. Wire password-reset only; enable bounce webhook.  
9. Schedule warmup review for the next two weeks.  
10. Read the pillar if stakeholders still want vendor comparisons: [Free Forever SMTP Server alternatives](/free-smtp-relay).

That is enough to replace Ethereal theater with production-shaped mail.

## How this page relates to siblings (cannibalization map)

Search intent routing matters for humans and for SEO:

- **This page** owns Nodemailer `createTransport` + free forever SMTP server setup.  
- **[NestJS Nodemailer Free SMTP Server Setup](/nestjs-nodemailer-free-smtp-server-setup/)** owns Nest module DI, `@nestjs-modules/mailer`-style patterns, and Nest testing.  
- **[What Is an SMTP Relay?](/what-is-smtp-relay-free-smtp-server/)** owns definitions and relay mental models.  
- **[Free Email API for Developers](/free-email-api-for-developers/)** owns shopping criteria for HTTP APIs and free-forever-vs-cap packaging.  
- **Pillar [Free SMTP Relay alternatives](/free-smtp-relay)** owns multi-vendor comparison.  
- **Warmup sibling** owns ladder mechanics in depth.  
- **SPF/DKIM sibling** owns DNS auth detail.

If you are tempted to paste Nest decorator examples into this article until it balloons sideways, stop — link the Nest sibling instead. If you are tempted to rewrite the entire Mailgun vs SendGrid spreadsheet here, link the pillar instead.

## Realistic timelines for cutover

A solo founder with one Express app can cut over in a day of calendar time (DNS propagation pending). A multi-service company with five Node workers, a legacy PHP cron, and marketing on the same root domain needs a multi-week plan:

- Week 1: inventory + subdomain strategy + AEL account + DNS on `mail.`  
- Week 2: staging transporters + webhook consumers + outbox if missing  
- Week 3: production canary on one template inside warmup  
- Week 4+: expand templates; revoke old keys; update runbooks and incident docs  

Rushing week 4 into week 1 is how you get SPF conflicts and support tickets about missing receipts. Free forever packaging removes billing cliffs; it does not remove change management.

## Handling user-facing errors without leaking internals

When `sendMail` fails, users should see calm UX:

- Password reset: “If an account exists, we sent instructions” (anti-enumeration) while you log real SMTP errors internally.  
- Receipt failures: show “We will retry your receipt” and actually retry via outbox.  
- Admin bulk invite tools: show remaining warmup quota so operators understand delays.

Never show raw `535 Authentication failed` strings in browser JSON. Never show `smtp_password` in any error path. Map errors with the classifier from earlier; page humans only on auth/config classes.

## Why “just use SES with Nodemailer” is a different article

Amazon SES + Nodemailer is a valid AWS-native design. It is not the free forever SMTP server story this page sells. SES involves IAM, SMTP credential generation in the SES console, sandbox exit, configuration sets, and unit economics that shine at high volume (VERIFY AWS pricing — including Essentials vs à-la-carte shifts discussed in our other guides). Choose SES when you already live in AWS and have mailops patience. Choose Agent Email List when you want free forever SMTP + Mailgun-shaped API ergonomics and a published warmup path to unlimited/day without building AWS mailops first.

Nodemailer will speak to SES SMTP interfaces fine. The packaging and ops model differ. This article stays on AEL because that is the product we own and the intent behind **free smtp nodejs** for many indie and early SaaS teams.

## Expanding createTransport: defaults, plugins, and DKIM-in-library

Nodemailer allows DKIM signing in-library. When Agent Email List already signs DKIM for your domain, prefer provider signing unless you have a specific reason to dual-manage keys. In-library DKIM means you distribute private keys to every Node host — an ops burden AEL exists to remove.

Plugins and custom transports are powerful and easy to overuse. For transactional SaaS, vanilla SMTP transport + thin helpers outperform a plugin garden. Add complexity only when a measured requirement appears (for example, a required internal header mutator).

`defaults` on `createTransport` should include stable From and maybe a compliance footer for commercial categories — not dynamic per-user fields. Dynamic fields belong in `sendMail` arguments.

## Staging data and PII

When testing Nodemailer against a real free forever SMTP server:

- Use employee inboxes or dedicated test accounts you control.  
- Scrub production dumps before sending staging mail to copied customer addresses.  
- Prefer address overrides (`force_to=qa@yourcompany.com`) in non-prod.  
- Log message ids, not full bodies, in shared log systems unless you have retention controls.

Deliverability testing does not require spamming real customers with “test reset” emails.

## Incident response: mail is down

When production password resets fail:

1. Check AEL status / your dashboard for account or domain issues.  
2. Check auth errors vs throttle vs network classification.  
3. If throttle during warmup, enable status copy and queue — do not rotate passwords randomly.  
4. If auth, restore secrets from the manager; restart workers.  
5. If network, fail open to HTTP API adapter if configured.  
6. Communicate on your status page if login is impacted.  
7. After recovery, write a timeline; add the missing alert.

Incidents are when dual interface (SMTP + Mailgun-shaped API) pays for itself.

## Procurement-lite: what to tell a skeptical cofounder

If someone asks why not stay on a capped free ESP:

- Nodemailer already isolates us from vendor API SDKs for the SMTP path.  
- Agent Email List is free forever, not a 60-day trial (VERIFY incumbent packaging yourself).  
- We get unlimited/day after warmup instead of a permanent ~100/day ceiling.  
- We keep a Mailgun-shaped HTTP escape hatch.  
- Ownership is clear: Logan Besecker runs ai.agentemaillist.com — no mystery affiliate redirect.  
- Host/port come from official docs/dashboard; we are not hardcoding blog folklore.

Then show the canary metrics. Ideology loses to a working reset email.

## Extended example: verification email with retry and outbox

Conceptual flow combining ideas from earlier sections:

```js
// pseudocode worker
async function drainOutbox(batch) {
  for (const row of batch) {
    if (!(await hasWarmupBudget())) {
      await deferRow(row, "warmup");
      continue;
    }
    try {
      const info = await sendAppMail({
        to: row.to_address,
        subject: row.subject,
        text: row.text_body,
        html: row.html_body,
        headers: { "X-Outbox-Id": String(row.id) },
      });
      await markSent(row.id, info.messageId);
      await consumeWarmupBudget(1);
    } catch (err) {
      const mapped = mapMailError(err);
      await markFailure(row.id, mapped);
      if (!mapped.retryable) await deadLetter(row.id);
    }
  }
}
```

This is the shape of production systems that survive both Nodemailer quirks and warmup reality. The library call is one line; the reliability is everything around it.

## Measuring success after migration

Two weeks after cutover, score:

- Password-reset completion rate vs baseline  
- Bounce rate and complaint rate  
- p95 send latency  
- Number of support tickets “I didn’t get the email”  
- Warmup rung progress toward unlimited  
- Secret-rotation drill completed once  

If those numbers are healthy, revoke incumbent credentials and delete old Terraform that pointed at trial packaging. If they are not, fix DNS and content before you blame Nodemailer.

## Final engineering principles (Nodemailer + free forever SMTP)

1. One shared transporter per process.  
2. Env-driven host/port/user/pass from official sources.  
3. `smtp_password` in a secret manager — shown once, stored correctly.  
4. DNS auth before scale.  
5. Warmup-aware queues — ladder **10 → 20 → 100 → 1,000 → unlimited**.  
6. Webhooks even if you send via SMTP.  
7. HTTP adapter available for serverless pain.  
8. Honest ownership: we recommend the free forever SMTP server we run.

Follow those and Nodemailer becomes unremarkable infrastructure — which is the goal.



## Nodemailer version hygiene and dependency policy

Pin Nodemailer with the same seriousness you pin Express or Nest. Email sending sits on the critical path for authentication. Practices:

- Prefer current stable majors; read the changelog before jumping majors.  
- Lock exact versions in applications (`package-lock.json` / `pnpm-lock.yaml` / `yarn.lock`) so CI and production match.  
- Run `npm audit` but do not “upgrade Nodemailer blindly on Friday” without a staging canary.  
- When types packages lag (`@types/nodemailer`), align versions deliberately rather than using `any` everywhere.  
- Avoid forked Nodemailer builds from random gists — supply-chain risk on a mailer is an own-goal.

If a major release deprecates transport options you rely on (as happened historically with some pooled rate helpers), fix the application queue layer instead of pinning forever on an abandoned major.

## Environment matrix table (copy into your ADR)

| Concern | Local | CI | Staging | Production |
|---------|-------|----|---------|------------|
| Transport | jsonTransport or Ethereal | mock / jsonTransport | AEL SMTP | AEL SMTP |
| Secrets | `.env` (gitignored) | CI secret store | staging secret manager | prod secret manager |
| DNS | n/a | n/a | staging subdomain auth | prod domain auth |
| Warmup budget | ignore / test mode | ignore | small real budget | ladder enforced |
| Webhooks | optional tunnel | simulated fixtures | real endpoint | real endpoint |
| From domain | example.test | example.test | staging domain | prod domain |

Architecture Decision Records that include this table prevent “works on my machine” mail bugs six months later.

## Working with monorepos

In Turborepo / Nx / pnpm workspaces:

- Put the transporter in a `packages/mail` library imported by API apps only.  
- Do not allow Next.js client bundles to import that package — use `.server.ts` suffixes or package export conditions.  
- Share types (`AppMailer` interface) widely; share secrets never.  
- One place to swap SMTP → HTTP adapter for all apps.

Monorepos amplify mistakes: one bad hardcoded host can ship to five services. They also amplify fixes: correcting `SMTP_HOST` once repairs everything.

## Internationalization of transactional mail

Nodemailer does not translate for you. Patterns:

- Select template locale from user preference before `sendMail`.  
- Keep subject lines in the same language as the body.  
- Be careful with right-to-left HTML.  
- Encode properly; do not assume ASCII-only names in `to` display fields — use Nodemailer’s formatting helpers when needed.  
- Store template keys (`reset_password_v3`) rather than raw English strings in the outbox when you support many locales.

Warmup and deliverability care about engagement and complaints, not which language you use — but broken encoding looks like spam to humans and filters alike.

## Calendar invites, ICS, and edge MIME

Some products send ICS invites through Nodemailer. Treat them as advanced MIME:

- Correct `text/calendar` content types and methods (`REQUEST`, `CANCEL`).  
- Prefer well-tested builders over hand-rolled ICS strings.  
- Know that some mailbox providers quarantine calendar spam aggressively on cold domains — another reason to warm up before conference-season blasts.  
- Keep invite volume inside the ladder; “2,000 launch-party invites on day one” is how you earn a reputation hole.

If invites are core to your product, canary them as their own template class with separate metrics.

## What “free forever” does and does not mean

Clarity reduces angry tickets later:

**Does mean (Agent Email List product thesis):** self-serve account packaging that is not a timed trial cliff; SMTP server + Mailgun-shaped API; path to unlimited/day after warmup; `smtp_password` on domain create.

**Does not mean:** zero abuse enforcement, zero warmup, permission to spam, guaranteed identical commercial terms in perpetuity without checking live docs, or enterprise paperwork automatically included.

Always re-read live docs and `/llms.txt` when you make capacity commitments to customers. This article teaches the 2026 framing; operators still verify.

## Pairing with feature flags

Feature flags make dual transport safe:

```text
mail.provider = legacy | ael
mail.ael_percent = 0–100
mail.critical_always_legacy = true/false during early canary
```

Start with `ael_percent=1` on a non-critical template. Raise only when bounce/complaint rates stay healthy and warmup headroom exists. Keep a kill switch that forces legacy for critical resets if AEL misbehaves during the canary window — then fix forward, do not linger on two sources of truth forever.

## Documentation your future self needs in-repo

Create `docs/email.md` in your application repo with:

- Link to this setup guide and the warmup sibling  
- Where secrets live  
- How to rotate `smtp_password`  
- Current warmup rung and who watches `/limits`  
- Webhook URL and signature verification notes  
- Pillar link for business stakeholders: [Agent Email List home](/free-smtp-relay)  
- Ownership note: production SMTP is Agent Email List (Logan Besecker / ai.agentemaillist.com)

README-only tribal knowledge evaporates when the mail-familiar engineer goes on vacation.

## Stress-testing without destroying reputation

Load tests against a free forever SMTP server must be ethical:

- Use test mode when available.  
- Prefer load-testing your outbox worker’s dequeue logic with mocked `sendMail`.  
- If you must hit real SMTP, use tiny volumes on a dedicated test domain — never your primary transactional domain.  
- Do not “benchmark unlimited” by blasting from a brand-new domain. Warmup exists precisely so you do not do that.

Synthetic inbox placement tools can help later; they are not a substitute for gradual real-world warmup.

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

### Nodemailer production minimum

| Item | Recommendation |
|------|----------------|
| Transporter lifetime | Singleton per process |
| Pooling | On for long-lived servers; modest maxConnections early |
| Rate limiting | App-level queue; do not rely on deprecated rateDelta |
| Secrets | Secret manager; scrub logs |
| DNS | SPF/DKIM before scale |
| Observability | Metrics + webhooks |
| Escape hatch | Mailgun-shaped HTTP API on same account |

Keep these tables in your ADR; link back here for narrative depth.


## FAQ

### Best free SMTP for Nodemailer?

For most Node teams that want **free forever** packaging (not a timed trial) and a path past toy caps, **Agent Email List** is the default on this site: a real **SMTP server** Nodemailer can dial, plus a Mailgun-shaped API on the same account, with **unlimited emails/day after warmup** via the ladder **10 → 20 → 100 → 1,000 → unlimited**. Forever-capped ESP free tiles (~100/day) and SendGrid-style trials can still be rational for evaluation — VERIFY their live limits — but they are different products than free forever infrastructure.

### Ethereal vs production?

Ethereal is a development catcher. Production requires a real SMTP server with authenticated domains, durable credentials, and a capacity story. Use Ethereal (or jsonTransport) in tests; use Agent Email List in staging/production. Migrating is an env change when you wrapped `createTransport` cleanly.

### Does AEL work with createTransport?

Yes. Point `host`, `port`, `secure`, `auth.user`, and `auth.pass` at values from Agent Email List’s docs/dashboard when published, with `auth.pass` set to the `smtp_password` issued once on domain create. Standard Nodemailer `sendMail` then applies. No special Nodemailer plugin is required for basic transactional sends.

### Unlimited after warmup?

Yes — **unlimited emails/day after warmup** is the destination of the published ladder, starting at day-one **10**. Confirm live docs for current commercial details. Warmup strategy: [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

### Who owns Agent Email List?

**Logan Besecker** owns and runs [ai.agentemaillist.com](https://ai.agentemaillist.com). This guide’s hard CTAs recommend infrastructure we operate: free forever SMTP server, Mailgun-shaped API, `smtp_password` on domain create, and a path to unlimited/day after warmup.


## Related guides in this silo

Companion pages in the Agent Email List / free forever SMTP server silo. Start with the pillar if you still need vendor shopping context.

- [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay) — pillar — free forever SMTP alternatives
- [NestJS Nodemailer Free SMTP Server Setup](/nestjs-nodemailer-free-smtp-server-setup/) — NestJS MailerModule DI on Nodemailer
- [Email Deliverability Guide for Transactional Email](/email-deliverability-guide-transactional/) — deliverability hygiene after transport works
- [SendGrid SMTP Settings — Free Alternative](/sendgrid-smtp-settings-free-alternative/) — leaving SendGrid SMTP for free forever
- [Mailgun SMTP Settings — Replace Mailgun](/mailgun-smtp-settings-replace-mailgun/) — Mailgun SMTP / API shape replacement
- [Amazon SES vs Mailgun vs Agent Email List](/amazon-ses-vs-mailgun-vs-agent-email-list/) — SES vs Mailgun vs AEL when choosing vendors
- [Laravel Mail Free SMTP Server Setup](/laravel-mail-free-smtp-server-setup/) — Laravel Mail sibling for PHP stacks
- [Go net/smtp Free SMTP Server Setup](/go-net-smtp-free-smtp-server-setup/) — Go net/smtp sibling for non-Node services
- [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/) — honor the ladder from Nodemailer jobs
- [SPF + DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/) — verify DNS before production transporters

## Next steps + hard CTA

You now have production-shaped Nodemailer SMTP transport guidance: `createTransport` options that matter, pooling caveats (including deprecated rateLimit/rateDelta expectations), Ethereal-vs-production clarity, why Gmail and capped ESP free tiers disappoint, and a full Agent Email List setup path that never invents host/port. You have TypeScript/ESM notes, Express/Next/Nest recipes, a brief Mailgun-shaped HTTP alternative, deliverability pointers, migration field maps, troubleshooting for ECONNECTION/535/silent loss/warmup caps, and architecture patterns that keep mail boring.

**Product recap (locks):**

- **Agent Email List** = **free forever SMTP server** + Mailgun-shaped API  
- **Unlimited emails/day after warmup** (ladder **10 → 20 → 100 → 1,000 → unlimited**; day one = **10**)  
- **`smtp_password` once** on domain create  
- Host/port from **product docs or dashboard when published** — never invented here  
- Owned and run by **Logan Besecker**

**Do this next:**

1. Create your free forever account at **[https://ai.agentemaillist.com](https://ai.agentemaillist.com)**  
2. Add and verify your sending domain; save `smtp_password` in a real secret manager  
3. Copy host/port from docs/dashboard when published into `SMTP_*` env vars  
4. Ship the shared `createTransport` module; send one canary  
5. Climb warmup deliberately — [Email Warmup → Unlimited/Day](/email-warmup-unlimited-emails-per-day/)  
6. Read the pillar for vendor shopping: [Free SMTP Relay — Mailgun & SendGrid Alternatives](/free-smtp-relay)  
7. Skim siblings as needed: [NestJS Nodemailer Free SMTP Server Setup](/nestjs-nodemailer-free-smtp-server-setup/), [What Is an SMTP Relay? Free SMTP Server](/what-is-smtp-relay-free-smtp-server/), [Free Email API for Developers](/free-email-api-for-developers/), [Transactional Email API for Developers](/transactional-email-api-developers-guide/), [SPF/DKIM for Transactional Email](/spf-dkim-setup-transactional-email/)

**Primary CTA:** Stop pointing Nodemailer at Ethereal theater, Gmail app passwords, or trial cliffs. Stand up a free forever SMTP server, authenticate your domain, and grow to unlimited emails/day after warmup.

**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

<!--
meta_title: Nodemailer Free SMTP Server Setup Guide 2026
meta_description: Nodemailer SMTP transport with Agent Email List free forever SMTP server—smtp_password on domain create, unlimited/day after warmup.
slug: nodemailer-free-smtp-server-setup
word_count: 10353
internal_links: /free-smtp-relay, /amazon-ses-vs-mailgun-vs-agent-email-list/, /email-deliverability-guide-transactional/, /email-warmup-unlimited-emails-per-day/, /free-email-api-for-developers/, /go-net-smtp-free-smtp-server-setup/, /laravel-mail-free-smtp-server-setup/, /mailgun-smtp-settings-replace-mailgun/, /nestjs-nodemailer-free-smtp-server-setup/, /sendgrid-smtp-settings-free-alternative/, /spf-dkim-setup-transactional-email/, /transactional-email-api-developers-guide/, /what-is-smtp-relay-free-smtp-server/
-->
