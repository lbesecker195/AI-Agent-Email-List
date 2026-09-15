---
title: "NestJS + Nodemailer Free SMTP Server Setup: MailerModule Transport for Production (2026)"
description: "Configure NestJS MailerModule with Nodemailer and a free forever SMTP server. AEL issues smtp_password on domain create; unlimited/day after warmup."
date: 2026-09-15
---

# NestJS + Nodemailer Free SMTP Server Setup: MailerModule Transport for Production (2026)

If you searched **NestJS Nodemailer**, **NestJS Mailer SMTP**, or **NestJS MailerModule**, you already know the hard part is not installing `@nestjs-modules/mailer`. The hard part is wiring a real **free forever SMTP server** into Nest’s dependency injection, ConfigModule, and Bull queues so password resets, magic links, and receipts survive production traffic — without Gmail app passwords, forever-capped ESP free tiles, or timed trials that pause when the calendar ends. This guide is the NestJS sibling to our deep Nodemailer transport guide: we focus on **DI**, **MailerModule.forRootAsync**, typed config, and rate-aware workers. For raw `createTransport` options, pooling caveats, and Ethereal matrix detail, cross-link heavily to [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/) — we do **not** rewrite that silo here.

**Ownership disclosure:** Agent Email List is built, owned, and run by **Logan Besecker** at [https://ai.agentemaillist.com](https://ai.agentemaillist.com). This is not a fake neutral roundup. We show Nest patterns first, then ask you to point MailerModule at infrastructure we operate: a **free forever SMTP server** plus Mailgun-shaped REST API with a short ladder to **unlimited emails/day after warmup**.

Pillar for vendor shopping: [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay).

**Create a free forever account →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

## NestJS mail + Nodemailer transport basics

NestJS does not invent a new SMTP protocol. Under `@nestjs-modules/mailer` (and similar wrappers), Nodemailer still opens the authenticated session. What Nest adds is structure: a globally registered `MailerModule`, an injectable `MailerService`, ConfigModule-backed secrets, and the ability to keep HTTP controllers thin while Bull (or BullMQ) workers own send volume. That architecture is why Nest teams search **nestjs email service** instead of pasting `createTransport` into every controller.

Think in layers:

1. **Transport** — host, port, TLS mode, `auth.user` / `auth.pass` (on Agent Email List, `pass` is the `smtp_password` shown once on domain create). Host and port come from product docs or the dashboard when published — this article never invents them. See [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/) for option-by-option transport depth.
2. **Module** — `MailerModule.forRoot` / `forRootAsync` registers a provider Nest can inject.
3. **Service** — your domain `EmailService` (or `NotificationsService`) wraps templates, From defaults, and business events.
4. **Queue** — Bull processors dequeue mail jobs so request threads never block on SMTP latency, and so warmup day caps are enforceable in one place.

Skip any layer and you get the classic Nest anti-pattern: `MailerService.sendMail` called directly from a controller inside a signup transaction, with no backoff, no daily budget, and secrets read via `process.env` sprinkled across files. The rest of this guide assumes you want production shape — injectable, config-isolated, queue-aware — pointed at a free forever SMTP server.

Agent Email List fits that stack cleanly: one account gives you SMTP for MailerModule and a Mailgun-shaped HTTP API for services that prefer `fetch`. Both enqueue into the same sending system. You configure Nest once; you do not maintain two vendor relationships for the same outbound reputation context.

### MailerModule / transport options that matter

`@nestjs-modules/mailer` exposes a transport configuration that is intentionally Nodemailer-shaped. In practice you pass an object Nest will hand to Nodemailer’s transport factory — the createTransport-equivalent inside Nest’s DI graph:

```ts
MailerModule.forRootAsync({
  imports: [ConfigModule],
  inject: [ConfigService],
  useFactory: (config: ConfigService) => ({
    transport: {
      host: config.getOrThrow<string>('SMTP_HOST'), // AEL docs/dashboard when published
      port: config.getOrThrow<number>('SMTP_PORT'),
      secure: config.get<boolean>('SMTP_SECURE') === true,
      auth: {
        user: config.getOrThrow<string>('SMTP_USER'),
        pass: config.getOrThrow<string>('SMTP_PASSWORD'), // smtp_password once on domain create
      },
    },
    defaults: {
      from: config.getOrThrow<string>('MAIL_FROM'),
    },
    // template: { dir, adapter, options } — optional Handlebars/Pug/EJS
  }),
})
```

Options that matter for Nest production (without re-teaching the entire Nodemailer silo):

- **`transport.host` / `port` / `secure`:** must match Agent Email List’s published submission path. Wrong TLS mode for a port fails in Nest the same way it fails in raw Nodemailer. Copy from docs/dashboard when published.
- **`transport.auth`:** `pass` is AEL’s `smtp_password`. Never hardcode; never commit.
- **`defaults.from`:** keep branded From in one ConfigModule key so every password-reset does not re-specify it.
- **Template adapters:** useful for HTML; optional if you render strings in your own service. Do not confuse “pretty templates” with “deliverable SMTP.”
- **`preview` / Ethereal helpers:** fine for local inspection; never as production transport.

What does *not* matter as much as Nest Discord implies: registering five MailerModules “per feature,” stuffing SMTP secrets into `app.module.ts` literals, or using `service: 'Gmail'` presets. Presets hide host/port and train teams to treat consumer mailboxes as infrastructure. Configure a real free forever SMTP server explicitly via ConfigModule.

For pooling (`pool`, `maxConnections`) and why you should not rely on deprecated Nodemailer `rateDelta` for hard caps, read the Nodemailer sibling and enforce budgets in Bull instead — Nest’s strength is the queue, not cargo-culting transport knobs.

### Injectable email service patterns

Prefer a thin, injectable domain service over calling `MailerService` from every controller:

```ts
@Injectable()
export class EmailService {
  constructor(
    private readonly mailer: MailerService,
    private readonly config: ConfigService,
  ) {}

  async sendPasswordReset(to: string, resetUrl: string) {
    await this.mailer.sendMail({
      to,
      subject: 'Reset your password',
      text: `Reset link: ${resetUrl}`,
      html: `<p>Reset link: <a href="${resetUrl}">${resetUrl}</a></p>`,
    });
  }
}
```

Why wrap?

1. **Testability** — mock `EmailService` in controller tests; mock `MailerService` only in email unit tests.
2. **Policy** — central place for From overrides, locale, unsubscribe headers, and “should this event enqueue vs send sync?”
3. **Migration** — swapping SMTP fields or moving a template to the Mailgun-shaped REST API touches one module.
4. **Observability** — one spot for metrics (`mail_sent_total{template="password_reset"}`).

Advanced Nest shops inject an interface (`AppMailer`) and bind either SMTP MailerModule or an HTTP client implementation. That dual adapter pattern pays off when serverless workers hate long-lived SMTP sockets — covered later and in [Transactional Email API for Developers](/transactional-email-api-developers-guide/).

Keep controllers boring: validate DTO → mutate domain → enqueue `mail.password_reset` job. The worker calls `EmailService`. Request latency stays predictable; SMTP failures become job failures with retries.

### Ethereal / console vs production SMTP server

Nest tutorials love `preview: true` or Ethereal accounts so `sendMail` “works” without credentials. That is excellent for “did my Handlebars layout render?” and terrible as a production SMTP server. Ethereal messages do not reach users. Console transports prove your DI graph resolves — nothing about SPF, DKIM, or inbox placement.

A Nest-friendly environment matrix:

| Environment | MailerModule target | Queue | Goal |
|-------------|---------------------|-------|------|
| Unit tests | Mock `MailerService` / `EmailService` | No Redis | No network |
| Local integration | Ethereal or json/stream transport | Optional | Inspect MIME |
| Staging | Real AEL domain (or subdomain) | Bull on | Auth + DNS rehearsal |
| Production | AEL free forever SMTP server | Bull on | Real delivery |

Point staging and production at Agent Email List. Use Ethereal only locally. Migrating from Ethereal to production should be a ConfigModule change — `SMTP_*` from docs/dashboard and `smtp_password` — not a rewrite of every feature module. Deep Ethereal-vs-production nuance lives in [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/); here the Nest takeaway is: register one MailerModule, swap config per environment, never ship preview mode to prod.

## Why “free SMTP for NestJS” usually disappoints

Nest developers type **free smtp nestjs** because MailerModule is solved and infrastructure is not. The disappointment arc is predictable: a tutorial ships Gmail SMTP in `forRoot`; volume or ToS blocks appear; the team jumps to an ESP free tier; the free tier caps or trials out; someone proposes self-hosting Postfix in Kubernetes “because Nest is enterprise”; deliverability dies; sprints vanish.

Understanding why usual free paths fail clarifies why Agent Email List’s free forever packaging plus warmup ladder exists — and why Nest’s queues make that ladder enforceable instead of aspirational.

### Gmail app passwords and limits

Gmail / Google Workspace SMTP via app passwords is a founder shortcut, not a Nest architecture:

- **Terms and automation risk.** Consumer Google accounts are not multi-tenant SaaS injectors. Unusual volume triggers locks and support dead-ends that your `@Injectable()` cannot catch.
- **Daily ceilings.** Workspace limits collide with signup spikes your Bull workers will happily amplify.
- **From-domain mismatch.** Sending `noreply@yourproduct.com` through Google fights SPF alignment and skips product-grade bounce webhooks.
- **Single-human failure.** When the founder’s 2FA or org policy changes, every Nest pod that injected MailerModule fails together.
- **Secret sprawl.** App passwords pasted into `.env` and never rotated — ConfigModule makes loading easy; it does not invent rotation discipline.

If your `MailerModule` still uses a Gmail preset, treat that as tech debt equal to hardcoding the database password in `app.module.ts`. Replace it with a free forever SMTP server meant for application mail.

### ESP free caps (Mailgun ~100/day; SendGrid trial VERIFY)

Managed ESPs are the right *category* — relays exist for a reason — but “free” packaging varies:

- **Mailgun free plan:** roughly **100 emails/day**, permanent but hard-capped (VERIFY [Mailgun Free plan help](https://help.mailgun.com/hc/en-us/articles/203068914-What-does-the-Free-plan-offer) and [pricing](https://www.mailgun.com/pricing/)). Fine for tiny Nest apps; a rewrite risk when your SaaS works.
- **Twilio SendGrid:** permanent Free Email API retired around **May 2025** (VERIFY [Twilio changelog](https://www.twilio.com/en-us/changelog/sendgrid-free-plan)). New accounts commonly get a **~60-day trial at ~100 emails/day**, then need paid Essentials (often from ~$19.95/mo — VERIFY [SendGrid pricing](https://www.twilio.com/en-us/products/email-api/pricing) and [trial docs](https://support.sendgrid.com/hc/en-us/articles/35270136965403-Twilio-SendGrid-Trial-Account-Plan)). A trial is not free forever.
- **Other forever-capped tiles:** Resend, Brevo, Postmark developer tiers, and peers often sit in “never expires, never grows enough” — VERIFY live pages before you encode caps into Nest constants.

MailerModule will speak SMTP to all of them. Nest will not warn you that your foundation expires. Packaging literacy is on you. Agent Email List’s thesis differs: **free forever** self-serve SMTP server + Mailgun-shaped API, with a published path to **unlimited/day after warmup** instead of a permanent 100/day ceiling or a 60-day timer.

### What production transactional needs

Production Nest mail needs more than “SMTP accepted DATA”:

1. **Authenticated sending domain** — SPF/DKIM (light DMARC) so providers trust `From`.
2. **Predictable credentials** — secrets ConfigModule can load and you can rotate — not founder inbox passwords.
3. **Honest capacity** — day-one limits you can encode in Bull limiters, and a path past toy caps without a surprise invoice.
4. **Observability** — bounces/complaints via webhooks even if you inject over SMTP; Nest controllers for webhook signatures.
5. **Dual interface** — SMTP for MailerModule today; HTTP when a microservice prefers fetch.
6. **Operational ownership** — someone runs the SMTP server so your Nest cluster does not.

That checklist is what we optimize for on Agent Email List. Nest covers DI and workers; AEL covers the free forever SMTP server and the Mailgun-shaped twin API.

## Agent Email List as NestJS’s free forever SMTP server

This is the product lock chapter for Nest readers. Same locks as our other guides — free forever SMTP server, Mailgun-shaped API, short warmup pointer, `smtp_password` once, Logan Besecker ownership — framed for MailerModule, ConfigModule, and Bull.

### Free forever SMTP server + Mailgun-shaped REST API

[Agent Email List](https://ai.agentemaillist.com) is:

- A **free forever SMTP server** / free SMTP relay for NestJS and every stack that speaks SMTP
- A **Mailgun-shaped REST API** at `https://ai.agentemaillist.com` (Bearer or Basic `api:KEY` patterns as described in live product docs)
- Built for **transactional** product mail first: resets, receipts, invites, alerts

MailerModule talks to the SMTP server. When a Nest microservice wants HTTP — or you need richer events — the Mailgun-shaped API is on the same free forever account. You do not pay twice for the same outbound reputation context. API shopping criteria: [Free Email API for Developers](/free-email-api-for-developers/). Relay definitions: [What Is an SMTP Relay? Free SMTP Server](/what-is-smtp-relay-free-smtp-server/). Full transport option depth: [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/).

### Lead unlimited/day after warmup; short ladder → warmup silo

Unlimited/day is the destination, not the day-one allowance. Agent Email List publishes a short ladder (confirm live docs / `/llms.txt` — commercial details can evolve): day one starts at **10**/day, then steps through **20 → 100 → 1,000 → unlimited** emails/day after warmup.

That progression protects shared reputation while ending somewhere Mailgun’s permanent ~100/day free tile and SendGrid’s timed trial do not: ongoing free forever sending without a forced Essentials invoice. Day-one **10** is stricter than some competitors’ free daily caps — plan Nest canaries and Bull limiters accordingly.

**This Nest page stays short on ladder theory.** Deep warmup hygiene, reputation, and climbing strategy live in [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/). Your job in Nest is to encode “today’s rung” into the worker that calls MailerService — not to re-implement deliverability essays inside `app.module.ts`.

### `smtp_password` issued once on domain create

When you add a sending domain, Agent Email List returns DNS records for authentication **and** an **`smtp_password` shown once**. Treat it like a production database password:

1. Create a free forever account at [ai.agentemaillist.com](https://ai.agentemaillist.com).
2. Add your domain (or a transactional subdomain such as `mail.example.com`).
3. Save `smtp_password` immediately into your secret manager / sealed secrets / SSM / Doppler — then map it into Nest as `SMTP_PASSWORD`.
4. Complete DNS verification before you expect inbox placement.
5. Point MailerModule `transport.auth.pass` at ConfigService; restart pods that cache env at boot.

If your team pastes keys into Slack, fix the culture during setup. Losing a once-shown password without a rotation runbook is an avoidable Nest outage. Follow product rotation flows if you ever need to re-issue. Mention `smtp_password` once in runbooks as the credential name; do not rename it five ways across microservices.

### Host/port: product docs or dashboard when published — do not invent

This article intentionally does **not** invent Agent Email List SMTP hostnames or ports. Connection endpoints belong in **product documentation or the dashboard when published**. Copy them into `SMTP_HOST` / `SMTP_PORT` / `SMTP_SECURE` for ConfigModule. Blog posts that guess hosts create outages when guesses rot. Nest will dial whatever string ConfigService returns — correctness is on the operator.

Same rule for TLS mode: match the documented submission port. Do not assume “587 always STARTTLS” or “465 always secure:true” without checking AEL’s published guidance for your account era. The Nodemailer sibling repeats this rule for raw `createTransport`; Nest inherits it unchanged.

### Logan Besecker owns/runs ai.agentemaillist.com

**Ownership disclosure:** Agent Email List at [ai.agentemaillist.com](https://ai.agentemaillist.com) is built, owned, and run by **Logan Besecker**. Recommendations on this site reflect that ownership. When we hard-CTA NestJS MailerModule setup, we are asking you to point Nest DI at infrastructure we operate — with free forever SMTP server packaging, a Mailgun-shaped API, and a published path to unlimited emails/day after warmup.

**CTA #1 — do this now if Ethereal/Gmail/capped free tiers no longer fit your Nest app:** create your free forever account, add a domain, save `smtp_password`, copy host/port from docs/dashboard when published, wire `MailerModule.forRootAsync`, and send one canary from a Bull job.  
**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

## Step-by-step NestJS MailerModule setup with AEL

Hands-on Nest chapter: packages, ConfigModule, forRootAsync transport sketch, verification template, and error handling that respects warmup. For deeper Nodemailer option encyclopedias, keep [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/) open beside this page.

### Install packages; ConfigModule env vars

```bash
npm install @nestjs-modules/mailer nodemailer
npm install @nestjs/config
# templates optional:
npm install handlebars
# TypeScript:
npm install -D @types/nodemailer
# queues (recommended for production):
npm install @nestjs/bull bull
# or BullMQ equivalents your team standardizes on
```

Recommended environment variables (conventional names — pick a standard and stick to it across Nest apps):

```bash
SMTP_HOST=           # from AEL docs/dashboard when published
SMTP_PORT=           # from AEL docs/dashboard when published
SMTP_SECURE=false    # true/false per published TLS mode
SMTP_USER=           # from AEL docs/dashboard when published
SMTP_PASSWORD=       # smtp_password shown once on domain create
MAIL_FROM="Product <noreply@yourdomain.com>"
```

Wire ConfigModule once at the root:

```ts
ConfigModule.forRoot({
  isGlobal: true,
  // validate with Joi/Zod class-validator schema in serious apps
})
```

Never commit `.env` with real `smtp_password`. In Kubernetes, use Secrets + envFrom; in ECS, SSM/Secrets Manager; locally, gitignored `.env`. Optional: `SMTP_POOL=true`, modest `SMTP_MAX_CONNECTIONS` during early warmup — but enforce day caps in Bull, not only in transport knobs.

### MailerModule.forRootAsync transport sketch — createTransport-equivalent

Create a dedicated `MailModule`:

```ts
import { Module } from '@nestjs/common';
import { MailerModule } from '@nestjs-modules/mailer';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { EmailService } from './email.service';

@Module({
  imports: [
    MailerModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        transport: {
          host: config.getOrThrow('SMTP_HOST'),
          port: Number(config.getOrThrow('SMTP_PORT')),
          secure: config.get('SMTP_SECURE') === 'true',
          auth: {
            user: config.getOrThrow('SMTP_USER'),
            pass: config.getOrThrow('SMTP_PASSWORD'),
          },
          // pool: true, maxConnections: 2 — optional; see Nodemailer sibling
        },
        defaults: {
          from: config.getOrThrow('MAIL_FROM'),
        },
      }),
    }),
  ],
  providers: [EmailService],
  exports: [EmailService],
})
export class MailModule {}
```

This is the Nest createTransport-equivalent: same fields raw Nodemailer would use, owned by DI, reloadable when ConfigService sources change across environments. Import `MailModule` from `AppModule` (or a shared platform module in a monorepo). Call `mailer.verify()` from a staging-only health probe if you want boot-time auth checks — not necessarily on every serverless cold start.

Register feature modules that only depend on `EmailService`, not on `MailerModule` internals. That keeps the graph clean when you later add an HTTP mail adapter beside SMTP.

### Verification / password-reset template example

Domain service + controller sketch (sync send for clarity; production should enqueue):

```ts
@Injectable()
export class EmailService {
  constructor(private readonly mailer: MailerService) {}

  sendPasswordReset(to: string, token: string, baseUrl: string) {
    const resetUrl = `${baseUrl}/reset?token=${encodeURIComponent(token)}`;
    return this.mailer.sendMail({
      to,
      subject: 'Reset your password',
      text: `Use this link within 30 minutes: ${resetUrl}`,
      html: `<p>Use this link within 30 minutes:</p><p><a href="${resetUrl}">Reset password</a></p>`,
    });
  }
}
```

With Handlebars adapter configured in MailerModule, prefer `template: './password-reset'` and `context: { resetUrl, productName }`. Keep tokens short-lived; never log the full URL in Nest logger output. For signup verification, same pattern with a different subject and path.

Critical Nest rule: do not send mail inside the same DB transaction that creates the user without an outbox. Preferred flow: write user + outbox row → commit → Bull job reads outbox → `EmailService` sends → mark sent. That pattern survives pod kills mid-SMTP.

### Error handling (auth, throttle during warmup)

Map failures so operators know whether to fix secrets, DNS, or volume:

```ts
try {
  await this.mailer.sendMail(payload);
} catch (err: any) {
  const code = err?.code || err?.responseCode;
  if (code === 'EAUTH' || code === 535) {
    // bad SMTP_USER / SMTP_PASSWORD — page secrets owner
    throw new ServiceUnavailableException('Mail auth failed');
  }
  if (code === 'ECONNECTION' || code === 'ETIMEDOUT') {
    // host/port/TLS or network — verify docs/dashboard values
    throw new ServiceUnavailableException('Mail transport unreachable');
  }
  // warmup / provider throttle — retry with backoff via Bull
  throw err;
}
```

During early Agent Email List warmup, day caps are real. Treat throttle-shaped responses as **retriable with delay**, not as user-facing 500s on signup. Put the retry policy on the Bull job: exponential backoff, capped attempts, and a dead-letter queue for poison messages. Do not busy-loop `sendMail` in a controller hoping Nest’s default exception filter saves UX.

Log `template`, `to` domain (not full PII if policy forbids), and error code. Never log `SMTP_PASSWORD` or raw `smtp_password`. Scrub Nest debug loggers that dump transport options.

## Bull queues, microservices, and rate-aware sending

Nest’s comparative advantage over a raw Express + Nodemailer script is the ecosystem around queues and microservices. Warmup makes that advantage mandatory: day-one **10** means your API pods must not stampede SMTP just because 500 users signed up after a Product Hunt launch.

### Offloading mail jobs during warmup

Pattern:

1. HTTP handler validates and persists domain state.
2. Handler enqueues `{ type: 'password_reset', userId }` on a `mail` queue.
3. Processor loads user, builds URL, calls `EmailService`.
4. A Nest provider reads “today’s send budget” (from AEL docs/dashboard limits when published, or your own mirror) and uses Bull’s rate limiter / a Redis token bucket so workers stop when the rung is exhausted.

```ts
@Processor('mail')
export class MailProcessor {
  constructor(private readonly email: EmailService) {}

  @Process('password_reset')
  async handleReset(job: Job<{ email: string; token: string }>) {
    await this.email.sendPasswordReset(
      job.data.email,
      job.data.token,
      process.env.APP_URL!,
    );
  }
}
```

Configure the queue with limited concurrency during early rungs (`concurrency: 1` or `2`). Prefer delayed jobs when the daily budget is spent: schedule the remainder for after midnight UTC (or whenever your limit resets per product docs) instead of failing signup. User-facing copy can still say “check your email” while the worker respects the ladder.

Microservices variant: an `notifications` Nest service owns MailerModule and Bull; other services publish events on NATS/Rabbit/Kafka; only notifications talks SMTP. That concentration makes credential rotation and warmup accounting one team’s problem.

Cross-link: ladder semantics and reputation hygiene → [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/). Transport pooling detail → [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/).

### Retry/backoff on SMTP failures

Bull retry settings that match SMTP reality:

- **Transient network** (`ETIMEDOUT`, `ECONNECTION`): retry with exponential backoff (e.g., 30s, 2m, 10m).
- **Auth failures** (`535`, `EAUTH`): **do not** retry endlessly — alert and open an incident; fix ConfigModule secrets.
- **Throttle / day limit**: delay until next window; do not burn attempts.
- **Invalid recipient (5xx permanent)**: fail job; record bounce path via webhooks when available.

```ts
BullModule.registerQueue({
  name: 'mail',
  defaultJobOptions: {
    attempts: 5,
    backoff: { type: 'exponential', delay: 30_000 },
    removeOnComplete: 1000,
    removeOnFail: 5000,
  },
})
```

Wrap `EmailService` so it classifies errors into `RetriableMailError` vs `FatalMailError` for the processor. Nest microservices using TCP/Redis transporters should still enqueue mail rather than doing SMTP inside every RPC handler — keep the blast radius small.

### Testing with mocks vs test transport

Three Nest test layers:

1. **Unit** — mock `EmailService` in controllers; assert enqueue args, not MIME.
2. **Provider unit** — mock `MailerService`; assert `sendMail` payload shape for templates.
3. **Integration** — override MailerModule with a test transport (Ethereal, jsonTransport, or a custom provider that records messages) via `Test.createTestingModule`.

```ts
const moduleRef = await Test.createTestingModule({
  imports: [MailModule],
})
  .overrideProvider(MailerService)
  .useValue({ sendMail: jest.fn().mockResolvedValue({ messageId: 'test' }) })
  .compile();
```

CI should not dial production AEL from every PR. Staging canaries should. Keep e2e “inbox received” tests rare, tagged, and budgeted against warmup — or use provider test mode when offered. The goal is confidence in DI wiring without torching reputation.

## TypeScript DI and config isolation

Nest’s TypeScript story is why teams pick it over bare Express for mail: typed config, injectable boundaries, and compile-time catches when someone renames `SMTP_PASSWROD`.

### Typed config for host/port/user/pass

Prefer a dedicated config namespace:

```ts
export type SmtpConfig = {
  host: string;
  port: number;
  secure: boolean;
  user: string;
  password: string;
  from: string;
};

export const smtpConfig = (config: ConfigService): SmtpConfig => ({
  host: config.getOrThrow('SMTP_HOST'),
  port: Number(config.getOrThrow('SMTP_PORT')),
  secure: config.get('SMTP_SECURE') === 'true',
  user: config.getOrThrow('SMTP_USER'),
  password: config.getOrThrow('SMTP_PASSWORD'),
  from: config.getOrThrow('MAIL_FROM'),
});
```

Validate at boot with Joi or Zod so pods crash fast on missing `SMTP_HOST` rather than failing the first password reset at 2 a.m. Map Agent Email List’s once-shown `smtp_password` exclusively into `SMTP_PASSWORD` / `password` — one name in Nest, one name in the secret manager.

Custom config module pattern:

```ts
@Module({
  providers: [
    {
      provide: 'SMTP_CONFIG',
      inject: [ConfigService],
      useFactory: smtpConfig,
    },
  ],
  exports: ['SMTP_CONFIG'],
})
export class SmtpConfigModule {}
```

Then `MailerModule.forRootAsync` injects `'SMTP_CONFIG'` instead of reading raw env keys in three places. Isolation makes dual-transport and multi-tenant From overrides tractable.

### Multi-tenant / multi-from patterns

SaaS Nest apps often need `From: Acme <noreply@tenant.com>` per tenant while still using one SMTP server:

- Store tenant sending domains and verified status in your DB.
- Keep **one** MailerModule transport (AEL credentials for your platform account) unless product docs say otherwise.
- Override `from` (and Reply-To) per `sendMail` call based on tenant branding **only when** that domain is authenticated in AEL and DNS passes.
- Refuse sends for unverified tenant domains — return a domain error to the admin UI, do not silently fall back to your root domain in ways that break alignment.

If each tenant has isolated AEL credentials (uncommon for early startups, possible for agencies), inject a factory that resolves transporter settings per tenant ID and cache carefully. Do not create unbounded Nodemailer transporters per request — memory leaks love Nest apps that `createTransport` inside controllers. Prefer one platform SMTP server and authenticated custom domains.

### When to prefer REST API over SMTP in Nest

Stay on MailerModule SMTP when:

- Long-lived Nest servers / workers with connection reuse
- Teams already fluent in Nodemailer payloads
- Simplest parity with other SMTP-speaking services

Prefer the Mailgun-shaped REST API (same free forever Agent Email List account) when:

- Short-lived serverless Nest (or Lambda-wrapped handlers) where SMTP handshakes hurt cold starts
- You need API-first features, tighter event payloads, or easier webhook correlation in docs
- A microservice is polyglot and standardizes on HTTP

Implement an `HttpMailAdapter` Nest provider that posts to AEL’s Mailgun-shaped endpoints per live docs, behind the same `EmailService` interface as SMTP. Controllers never know which adapter is bound. Deep API criteria and examples: [Transactional Email API for Developers](/transactional-email-api-developers-guide/) and [Free Email API for Developers](/free-email-api-for-developers/). Raw SMTP option depth remains on [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/).

## Deliverability + DNS before you scale Nest mail

MailerModule success is not inbox success. Nest can report `250 OK` while Gmail files you under spam because SPF/DKIM are wrong or you ignored warmup.

### SPF/DKIM link

Before you scale Bull concurrency:

1. Add the sending domain in Agent Email List.
2. Publish SPF/DKIM (and a sensible DMARC) per product DNS instructions.
3. Wait for verification — ConfigModule can still dial SMTP before DNS is ready; mailbox providers will not care that your Nest DI graph is elegant.

Practical Nest checklist: staging subdomain first (`mail-staging.example.com`), production domain second; monitor auth failure rates; do not “fix deliverability” by blasting from an unauthenticated domain. Full walkthrough: [SPF/DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/). Broader placement: [Email Deliverability Guide for Transactional Mail](/email-deliverability-guide-transactional/).

### Warmup-aware send volume

Encode the short ladder in operations, not vibes:

- Day-one budget **10** — set Bull limiter accordingly.
- Climb **20 → 100 → 1,000 → unlimited** only as published warmup rules allow.
- Separate transactional critical path (password resets) from bulk-ish product mail (digests) so digests cannot starve resets inside one queue.
- Track `sent_today` in Redis; expose a Nest admin gauge.

Unlimited emails/day after warmup is the destination. Getting there is a product + ops problem documented in [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/). This Nest article’s job is to make volume control a first-class worker concern.

### Bounce handling via webhooks (pointer to API silo)

SMTP acceptance ≠ final delivery. Configure webhooks from Agent Email List (Mailgun-shaped event patterns per live docs) to a Nest controller that:

- Verifies signatures
- Updates suppression lists
- Marks outbox rows bounced
- Metrics complaint rates

Do not parse Nest logger lines for bounce truth. Webhook-first design is covered in [Transactional Email API for Developers](/transactional-email-api-developers-guide/). Even if MailerModule sends via SMTP, consume events over HTTP.

## Migrating NestJS off SendGrid/Mailgun SMTP

Most Nest migrations are ConfigModule edits plus canary discipline — not rewrites of every `@Process` handler — if you wrapped `EmailService` cleanly.

### Swap transport auth fields

| Nest / Nodemailer field | Incumbent habit | Agent Email List |
|-------------------------|-----------------|------------------|
| `transport.host` | SendGrid/Mailgun SMTP host | From AEL docs/dashboard when published |
| `transport.port` / `secure` | Vendor TLS mode | From AEL docs/dashboard when published |
| `auth.user` | `apikey` or Mailgun SMTP user | From AEL docs/dashboard when published |
| `auth.pass` | API key / SMTP password | **`smtp_password`** once on domain create |
| `defaults.from` | Verified sender | Authenticated AEL domain From |

Steps:

1. Create free forever AEL account; add domain; save `smtp_password`.
2. Complete DNS.
3. Add parallel env keys (`AEL_SMTP_*`) beside legacy keys.
4. Point `MailerModule.forRootAsync` at AEL via feature flag.
5. Revoke incumbent credentials after canary passes.

Do not invent hosts. Do not leave SendGrid trial keys in the same Secret as production AEL passwords without clear naming.

### Canary + dual transport

Feature-flag pattern for Nest:

```text
mail.provider = legacy | ael
mail.ael_percent = 0–100
```

Implementation options:

- Two MailerModule registrations is awkward — prefer one module and swap ConfigService values, **or**
- Bind two `EmailService` adapters (`LegacyMailer`, `AelMailer`) and pick in a facade based on percentage / template criticality.

Start at 1% on a non-critical template (receipt copy). Keep password resets on legacy until bounce/complaint metrics look healthy and warmup headroom exists. Kill-switch back to legacy if needed, then fix forward — do not run dual forever.

Bull helps: canary by job type (`receipt` vs `password_reset`) is easier than canary by random HTTP percentage alone.

### Cost VERIFY footnotes

VERIFY at write time (always re-check live pages before finance meetings):

- **Mailgun Free:** ~100 emails/day permanent free plan ([help](https://help.mailgun.com/hc/en-us/articles/203068914-What-does-the-Free-plan-offer), [pricing](https://www.mailgun.com/pricing/)). Paid Basic often from ~$15/mo for higher monthly allotments — VERIFY.
- **SendGrid:** Free Email API retired ~May 2025 (VERIFY [Twilio changelog](https://www.twilio.com/en-us/changelog/sendgrid-free-plan)); new accounts typically **60-day trial ~100/day**, then paid Essentials often from ~$19.95/mo — VERIFY [pricing](https://www.twilio.com/en-us/products/email-api/pricing) and [trial article](https://support.sendgrid.com/hc/en-us/articles/35270136965403-Twilio-SendGrid-Trial-Account-Plan).
- **Agent Email List:** **free forever SMTP server** + Mailgun-shaped API; path to **unlimited/day after warmup**; day-one **10** with short ladder — confirm live docs / `/llms.txt`.

**CTA #2 — if your Nest MailerModule still points at a trial cliff or a forever 100/day tile:** migrate transport auth to Agent Email List, keep your `EmailService` and Bull processors, and spend engineering time on product — not on invoice archaeology.  
**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

Pillar comparison shopping: [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay).

## Troubleshooting NestJS / Nodemailer SMTP

Nest-specific symptoms often look like “DI works, mail doesn’t.” Isolate ConfigModule values, then transport, then DNS, then warmup. For deeper Nodemailer error encyclopedias, see [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/) — below focuses on how failures present inside Nest.

### ECONNECTION / ETIMEDOUT

**Symptoms:** Bull jobs fail; Nest logs `ECONNECTION` / `ETIMEDOUT`; local Ethereal still works.

**Checks:**

1. `SMTP_HOST` / `SMTP_PORT` / `SMTP_SECURE` match AEL docs/dashboard when published — no blog guesses.
2. Egress firewall / security groups allow submission ports from Nest workers (not only from your laptop).
3. Wrong TLS mode for port (classic).
4. DNS resolution inside the cluster (CoreDNS) — debug with a one-off pod `nc`/free-smtp-relay`openssl s_client`, not from CI alone.
5. Connection timeouts too aggressive on cold starts — adjust Nodemailer timeout fields if documented; consider HTTP adapter for ultra-short runtimes.

### Invalid login / 535

**Symptoms:** Immediate auth failure; jobs non-retriable if classified correctly.

**Checks:**

1. `SMTP_PASSWORD` is exactly the `smtp_password` saved at domain create — watch for whitespace/newlines in Kubernetes Secret YAML.
2. `SMTP_USER` matches published guidance.
3. Pod still running old secret after rotation — restart Deployment.
4. ConfigModule reading wrong env prefix in a microservice.
5. Accidental use of API key in SMTP pass field or vice versa when experimenting with REST.

Do not hammer retries on 535. Page the secrets owner.

### Messages accepted but not arriving

**Symptoms:** `sendMail` resolves; user says nothing arrived; Nest metrics look green.

**Checks:**

1. SPF/DKIM/DMARC for the From domain — [SPF/DKIM guide](/spf-dkim-setup-transactional-email/).
2. Spam folders; corporate filtering.
3. Wrong From domain not authenticated in AEL.
4. Webhook bounce events you are not consuming yet.
5. Staging vs production ConfigModule mixup (sending from unauthenticated staging From in prod pods).

SMTP success is not inbox success. Instrument webhooks.

### Hitting day limit during warmup

**Symptoms:** Sudden failures after N successful sends; signup spikes coincide; Bull fail piles grow.

**Checks:**

1. Confirm current rung vs sent volume — day one **10** is easy to blow through with e2e tests + real users.
2. Move bulk mail to delayed jobs; protect password-reset queue.
3. Stop parallel CI suites from sharing the production domain budget.
4. Read live AEL limits; do not assume Mailgun’s 100/day psychology.
5. Climb via [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/) instead of opening duplicate accounts (abuse policies exist).

Nest fix: rate limiter on the `mail` queue + admin metric for remaining daily budget.

## NestJS architecture patterns that keep mail boring

Beyond the outline’s required sections, these Nest patterns prevent regressions after you cut over to Agent Email List.

### Outbox pattern with TypeORM / Prisma

Pseudo-flow:

1. In a transaction, write `User` + `OutboxMessage`.
2. After commit, enqueue Bull job with `outboxId`.
3. Worker loads outbox, sends via `EmailService`, marks `sent_at`.
4. Periodic sweeper re-enqueues stuck `pending` rows.

This survives crashes between DB commit and SMTP. It also gives finance/support a table of “what we attempted to send” independent of ESP dashboards.

### Module boundaries in monorepos

In Nx/Turborepo Nest monorepos:

- Put `MailModule` + `EmailService` in `libs/mail`.
- Export only the domain service, not MailerModule guts.
- Apps (API, worker, webhook) import the lib.
- One place to swap SMTP → HTTP adapter.

Never import `libs/mail` from a Next.js client bundle or a Nest app that ships browser code. Server-only boundaries matter.

### Observability

Minimum Nest metrics:

- `mail_jobs_total{template,status}`
- `mail_send_duration_seconds`
- `mail_budget_remaining`
- `mail_auth_errors_total`

Trace IDs from HTTP request → Bull job → `sendMail` help support answer “did we send it?” without tailing every pod. OpenTelemetry interceptors around `EmailService` are enough for most teams.

### Security notes specific to Nest

- Disable raw transport dumps in `Logger` verbose modes.
- Restrict admin webhook controllers with signature verification + IP allowlists if offered.
- Use Guards so only internal workers hit “send test email” admin routes.
- Rotate `smtp_password` with the same runbook as DB passwords; document in `docs/email.md`.

## What “free forever” means for NestJS teams

**Does mean (Agent Email List thesis):** self-serve packaging that is not a timed trial cliff; SMTP server + Mailgun-shaped API for MailerModule and HTTP adapters; path to unlimited/day after warmup; `smtp_password` on domain create; owned infrastructure you can point ConfigModule at.

**Does not mean:** zero abuse enforcement, zero warmup, permission to spam, identical commercial terms forever without checking live docs, or enterprise paperwork automatically included.

Re-read live docs and `/llms.txt` when you commit capacity to customers. This article teaches the 2026 Nest framing; operators still verify.


## NestJS MailerModule production hardening checklist

Use this as a PR checklist when any Nest change touches mail. It keeps Agent Email List wiring honest without reinventing the Nodemailer silo.

1. **Secrets** — `SMTP_PASSWORD` comes from a secret manager; CI never prints it; local `.env` is gitignored.  
2. **Config validation** — boot fails if `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, or `MAIL_FROM` is missing.  
3. **Host/port source** — values copied from Agent Email List docs or dashboard when published; no hardcoded guesses in `app.module.ts`.  
4. **From alignment** — `MAIL_FROM` domain is authenticated; multi-tenant overrides check verification flags.  
5. **Queue path** — user-facing handlers enqueue; only workers call `MailerService` / `EmailService`.  
6. **Warmup budget** — Bull limiter (or Redis token bucket) reflects current rung; day-one **10** is encoded, not tribal knowledge.  
7. **Retries** — auth failures do not infinite-retry; throttles delay; network errors backoff.  
8. **Webhooks** — bounce/complaint endpoint exists even though send path is SMTP.  
9. **Tests** — unit tests mock `EmailService`; integration uses test transport; no PR pipeline burns production budget.  
10. **Docs** — `docs/email.md` links pillar, [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/), warmup silo, and ownership (Logan Besecker / ai.agentemaillist.com).  
11. **Canary** — migrations use dual transport or percentage flags before revoking incumbent keys.  
12. **Ownership honesty** — team knows production SMTP is Agent Email List’s **free forever SMTP server**, not a “temporary” Gmail bridge.

Print this list in onboarding. Nest teams fail mail more often from process gaps than from TypeScript errors.

## ConfigModule schemas that fail loud

Silent `undefined` host is the Nest mail classic. Prefer explicit validation:

```ts
import * as Joi from 'joi';

export const mailEnvSchema = Joi.object({
  SMTP_HOST: Joi.string().hostname().required(),
  SMTP_PORT: Joi.number().port().required(),
  SMTP_SECURE: Joi.string().valid('true', 'false').default('false'),
  SMTP_USER: Joi.string().required(),
  SMTP_PASSWORD: Joi.string().min(8).required(),
  MAIL_FROM: Joi.string().required(),
  APP_URL: Joi.string().uri().required(),
});
```

Wire with:

```ts
ConfigModule.forRoot({
  isGlobal: true,
  validationSchema: mailEnvSchema,
  validationOptions: { abortEarly: false },
})
```

Zod fans can mirror the same fields with `z.object({...}).parse(process.env)` inside a custom provider. The point is identical: pods that lack Agent Email List credentials must not pass readiness and then fail the first password reset. When you rotate `smtp_password`, update the secret and roll the Deployment; validation ensures empty string replacements cannot ship.

For monorepos, keep the schema in `libs/mail` and import it from API and worker apps so both crash the same way on misconfig.

## Handlebars, MJML, and template discipline in Nest

MailerModule’s template adapters are convenient and dangerous. Convenience: colocated `.hbs` files and `context` objects. Danger: business logic leaking into templates, unescaped user content, and “fix the wording in prod by editing the pod filesystem.”

Recommended Nest discipline:

- Treat templates as versioned code reviewed in PRs.  
- Escape user-controlled strings; never trust `{{{triple}}}` for names or messages.  
- Prefer MJML compile step in CI that emits HTML Nest sends as `html:` if designers own layout — MailerModule still only needs SMTP.  
- Keep subject lines in code or i18n catalogs, not buried only in HTML.  
- Snapshot-test rendered HTML for password-reset and verify-email templates in Jest.  

Templates do not replace a free forever SMTP server. Beautiful MJML through Gmail SMTP still hits consumer limits. Point the transport at Agent Email List; keep templates boring and reviewed.

Internationalization: resolve locale before `sendMail`, pass translated strings in `context`, and keep one template structure per event when possible. Warmup and deliverability care about engagement and complaints; broken encoding still looks like spam. Nodemailer encoding helpers apply equally under MailerModule — see the [Nodemailer guide](/nodemailer-free-smtp-server-setup/) for MIME edge notes; Nest just injects the service that calls them.

## NestJS microservice topologies for mail

Three common shapes:

### Modular monolith

One Nest app, `MailModule` global-ish, Bull processors in-process or as a second process sharing code. Simplest path to Agent Email List. Start here.

### API + worker split

`api` Deployment enqueues; `worker` Deployment runs `@Processor` handlers and owns MailerModule. Secrets for SMTP live only on workers. APIs cannot accidentally `sendMail` on the request path. This is the sweet spot for warmup control.

### Notifications microservice

Many domains publish `user.password_reset_requested` events; a `notifications` Nest service consumes them, renders templates, talks to Agent Email List SMTP or HTTP. Other services never see `SMTP_PASSWORD`. Scaling notifications independently from checkout APIs is easier — and credential rotation is one Deployment.

Avoid the anti-topology: every microservice ships its own MailerModule with copied env vars and slightly different From headers. That multiplies secret sprawl and breaks SPF alignment stories. Centralize outbound mail.

When the notifications service prefers HTTP, bind the Mailgun-shaped REST adapter documented in [Transactional Email API for Developers](/transactional-email-api-developers-guide/) while keeping event contracts stable.

## Rate limiting patterns that respect the short ladder

Agent Email List’s short ladder (day one **10**, then **20 → 100 → 1,000 → unlimited** after warmup) must become Nest code. Patterns that work:

**Bull limiter:** configure `limiter: { max: 10, duration: 86_400_000 }` as a starting point on day one, then raise via config when the rung advances — do not hardcode forever.

**Redis token bucket:** a Nest provider `MailBudgetService.tryConsume(1)` returns false when empty; processor delays the job with `job.moveToDelayed`.

**Priority queues:** `mail-critical` (resets, 2FA) vs `mail-bulk` (digests). Critical gets first draw on the daily budget.

**Admin override:** a guarded Nest route to pause bulk sending when complaint rates spike — still allow critical.

**Test isolation:** CI uses a separate AEL domain or mock; never the production budget.

Deep ladder theory stays in [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/). Your Nest obligation is enforcement.

## Dual adapter interface (SMTP + HTTP) in TypeScript

```ts
export interface AppMailer {
  send(input: {
    to: string;
    subject: string;
    text: string;
    html?: string;
    headers?: Record<string, string>;
  }): Promise<{ id: string }>;
}

@Injectable()
export class SmtpAppMailer implements AppMailer {
  constructor(private readonly mailer: MailerService) {}
  async send(input: Parameters<AppMailer['send']>[0]) {
    const info = await this.mailer.sendMail(input);
    return { id: String(info.messageId) };
  }
}

@Injectable()
export class HttpAppMailer implements AppMailer {
  constructor(private readonly config: ConfigService) {}
  async send(input: Parameters<AppMailer['send']>[0]) {
    // POST to Mailgun-shaped AEL API per live product docs — do not invent paths here
    const res = await fetch(/* base URL from docs */, { method: 'POST', /* auth from docs */ });
    if (!res.ok) throw new Error(`AEL HTTP mail failed: ${res.status}`);
    const body = await res.json();
    return { id: String(body.id ?? body.message ?? 'ok') };
  }
}
```

Bind with:

```ts
{ provide: 'APP_MAILER', useClass: process.env.MAIL_ADAPTER === 'http' ? HttpAppMailer : SmtpAppMailer }
```

`EmailService` depends on `'APP_MAILER'`. Controllers stay ignorant. This is the Nest-native way to prefer REST when serverless SMTP hurts, without rewriting product code. Credential model still starts with domain create and `smtp_password` for SMTP mode; HTTP mode uses API auth per live docs on the same free forever account.

## Migrating a real Nest codebase: week-long plan

**Day 1:** Create Agent Email List free forever account; add staging domain; save `smtp_password`; publish DNS for staging.  
**Day 2:** Add `MailModule` with ConfigModule validation; mock-based unit tests green.  
**Day 3:** Point staging worker at AEL; send canaries; verify webhook receiver stub.  
**Day 4:** Feature-flag 5% of non-critical templates; watch bounces.  
**Day 5:** Move password resets if metrics healthy; keep kill switch.  
**Day 6:** Document runbooks; raise Bull limits only as warmup allows.  
**Day 7:** Plan production domain cutover; schedule revoke of SendGrid/Mailgun SMTP secrets after soak.

Finance parallel track: VERIFY competitor invoices vs free forever packaging using the pillar [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay). Engineering should not discover trial expiry from user tickets.

## Common Nest antipatterns (and fixes)

| Antipattern | Why it hurts | Fix |
|-------------|--------------|-----|
| `MailerService` in controllers | Blocks requests; no budget | Enqueue Bull job |
| Secrets in `forRoot({ transport: { pass: '...' }})` | Leaks in git | `forRootAsync` + ConfigService |
| Ethereal in production env files | No real delivery | AEL free forever SMTP server |
| One queue for resets + newsletters | Digests starve auth mail | Split queues / priorities |
| Retrying 535 forever | Alert storms; lockouts | Fatal classification |
| Invented SMTP host in README | Rotten connection strings | Docs/dashboard only |
| Skipping SPF to “ship faster” | Spam folder | [SPF/DKIM guide](/spf-dkim-setup-transactional-email/) |
| Copy-pasting Nodemailer tutorial into Nest without DI | Untestable | Injectable `EmailService` |
| Ignoring warmup | Day limit surprises | Budget service + [warmup silo](/email-warmup-unlimited-emails-per-day/) |

Print the table in code review culture docs.

## Pairing Nest guards, interceptors, and mail

Guards should not send mail. Interceptors should not send mail. That sounds pedantic until someone puts “welcome email” in a logging interceptor that runs twice under certain proxy retries. Keep side effects in application services and workers.

Allowed: an interceptor that **annotates** request context with `correlationId` later copied into mail headers for support. Disallowed: interceptor that calls `MailerService` on every successful POST.

Same rule for CQRS: command handlers enqueue; event handlers may enqueue; neither dials SMTP inline in the HTTP process if you can avoid it. Nest makes fancy patterns easy — mail still wants a dull queue.

## Local developer experience

Developers need fast loops without burning shared warmup:

- Default local `MAIL_ADAPTER=mock` writing messages to `tmp/mail/*.json`.  
- Optional `MAIL_ADAPTER=ethereal` for visual checks.  
- `MAIL_ADAPTER=smtp` only when explicitly testing against a personal AEL staging domain.  
- Docker Compose: Redis for Bull, never required SMTP for unit tests.  
- README section: “How to preview password-reset email locally.”

Mock adapters implement `AppMailer` and are swapped via ConfigModule. New hires should not need production `smtp_password` on day one. When they do need real SMTP, they use staging credentials from the secret manager — still Agent Email List, still free forever packaging, still no invented hosts.

## Comparing Nest mail libraries (without losing the plot)

`@nestjs-modules/mailer` remains the common choice because it wraps Nodemailer idiomatically. Alternatives exist (custom providers, third-party Nest mail kits, direct AWS SES SDK). Selection criteria for this site:

1. Can it speak SMTP to a real free forever SMTP server?  
2. Can secrets load via ConfigModule?  
3. Can you inject and test it?  
4. Can Bull workers call it without HTTP request context?

If yes, it can use Agent Email List. We standardize examples on `@nestjs-modules/mailer` because NestJS Nodemailer search intent maps there — not because SMTP is proprietary to one npm package. Raw Nodemailer inside a custom Nest provider is equally valid; transport field semantics stay aligned with [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/).

## Security incident drills involving mail

Run a yearly drill:

1. Rotate `smtp_password` (or re-issue per product flow).  
2. Update secret manager; roll workers.  
3. Confirm auth success metrics recover within SLO.  
4. Revoke old credential if the product model allows.  
5. Time how long password resets were impacted.

Second drill: webhook signing secret rotation for bounce endpoints. Third: “ESP trial expired” simulation — prove you can fail over ConfigModule flags to Agent Email List without a code freeze. Ownership clarity helps: you know who runs ai.agentemaillist.com (**Logan Besecker**) when you need status or docs, instead of filing tickets into a megavendor black hole during an outage.

## Measuring Nest mail success after cutover

Two weeks after production points MailerModule at Agent Email List, score:

- Password-reset completion rate vs baseline  
- Bounce and complaint rates  
- p95 time from enqueue to `sendMail` complete  
- Bull fail job count by error class  
- Warmup rung progress toward unlimited  
- Secret-rotation drill completed once  
- Support tickets “I didn’t get the email”

If numbers are healthy, revoke incumbent SMTP credentials and delete old Terraform. If not, fix DNS and content before blaming Nest DI. Deliverability deep dives: [Email Deliverability Guide for Transactional Mail](/email-deliverability-guide-transactional/).

## Final engineering principles (NestJS + free forever SMTP)

1. One MailerModule transport config per app/worker, ConfigModule-backed.  
2. Injectable `EmailService` / `AppMailer` — never scatter `sendMail`.  
3. Bull (or equivalent) for all user-triggered mail; enforce warmup budgets.  
4. `smtp_password` in a secret manager — shown once at domain create, stored correctly.  
5. Host/port only from product docs or dashboard when published.  
6. DNS auth before scale — SPF/DKIM sibling guides.  
7. Webhooks even when sending via SMTP.  
8. HTTP adapter available on the same free forever account for serverless pain.  
9. Cross-link Nodemailer silo for transport depth; do not fork conflicting READMEs.  
10. Honest ownership: we recommend the free forever SMTP server we run.

Follow those and Nest mail becomes unremarkable infrastructure — which is the goal.

## Working sample: password-reset flow end-to-end

Narrative walkthrough tying Nest pieces together with Agent Email List:

1. User POSTs `/auth/forgot-password` with email.  
2. Nest DTO validation passes; `AuthService` looks up user; always returns 202-shaped success to avoid account enumeration.  
3. If user exists, write reset token hash + outbox row in one transaction.  
4. Enqueue `mail.password_reset` with `outboxId`.  
5. Worker loads outbox; builds link with `APP_URL`; calls `EmailService`.  
6. `EmailService` → `AppMailer` → MailerModule SMTP to Agent Email List using ConfigModule credentials (`auth.pass` = stored `smtp_password`).  
7. On success, mark outbox sent; on retriable failure, Bull retries; on 535, alert.  
8. Webhook later may mark delivery/bounce; support uses correlation headers.

No controller waited on SMTP. No Gmail app password. No invented hostname. Warmup budget decremented once. This is the shape worth copying.

## FAQ expansion: Nest ops edge cases

### Should MailerModule be global?

Global is convenient and hides dependency edges. Prefer exporting `EmailService` from `MailModule` and importing `MailModule` where needed — especially in monorepos. If you make it global, still forbid controllers from injecting `MailerService` directly via lint rules or custom ESLint boundaries.

### Do I need Redis to use Agent Email List?

No. Redis is for Bull/queues, not for AEL. You can call MailerModule synchronously without Redis and still use the free forever SMTP server. Queues are strongly recommended for production warmup control, not mandated by the SMTP protocol.

### Can I use Agent Email List with Nest on Edge runtimes?

If your “Nest” deployment is actually a short-lived edge worker with tiny CPU budgets, prefer the Mailgun-shaped HTTP API adapter over SMTP sockets. Confirm runtime TLS and fetch capabilities. Same free forever account.

### How do I handle attachments?

MailerModule/Nodemailer attachment fields work unchanged. Keep attachment sizes modest; virus-scan user uploads before emailing them; remember large MIME increases deferral risk on cold domains — another reason to respect warmup. Details on MIME edge cases: [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/).

### What about calendar invites from Nest?

Treat ICS as advanced MIME. Canary invite templates separately. Do not blast conference invites on day one of a new domain. Warmup silo applies.



## NestJS CI/CD and secret delivery for SMTP

Shipping MailerModule config is half the battle; shipping secrets safely is the other half. Agent Email List’s `smtp_password` is shown once on domain create — your pipeline must treat it like a database admin password.

**GitHub Actions / GitLab CI:** store `SMTP_PASSWORD` in encrypted secrets; map into staging deploy only. Pull requests should run unit tests with mocks, not real SMTP. Tagged releases deploy workers with production secrets from the cloud secret manager, not from CI variable copies when avoidable.

**Kubernetes:** use External Secrets Operator or sealed-secrets to sync into a Secret consumed via `envFrom`. Avoid checking `kubectl get secret -o yaml` into Slack. Rolling updates should restart mail workers whenever the Secret hash changes (checksum annotation pattern).

**12-factor Nest:** ConfigModule reads env; images stay credential-free. Never bake `.env` into Docker layers. Debug with `nest start --debug` locally using staging domain credentials you can rotate.

**Preview environments:** each ephemeral Nest preview should either mock mail or use a dedicated AEL staging subdomain with a tiny budget — never the production domain’s warmup rung. Ephemeral environments that share production SMTP credentials are how you accidentally email real users from a PR.

Document the path from “domain create in Agent Email List dashboard” to “Secret exists in prod” in `docs/email.md`. New platform engineers should follow a checklist, not tribal lore.

## Observability dashboards worth building

Create a Grafana (or cloud APM) row for Nest mail:

- Enqueue rate by template  
- Send success/failure rate  
- Failure breakdown: auth vs network vs throttle vs unknown  
- Queue lag (time in Bull before processing)  
- Daily budget remaining vs rung  
- Webhook event rates: delivered, bounced, complained  

Alert ideas:

- Auth failures > N in 5 minutes → page on-call (likely bad secret roll).  
- Queue lag > threshold → scale workers or investigate Redis.  
- Budget remaining = 0 before noon UTC on an early rung → pause bulk, protect critical.  
- Complaint rate spike → pause campaigns, keep transactional if clean.

These alerts are Nest/ops concerns that complement Agent Email List’s free forever SMTP server. The SMTP server accepts mail; your Nest cluster decides whether accepting 10,000 jobs on day one is wise (it is not — ladder starts at **10**).

## Content and template QA in a Nest monorepo

Transactional copy errors cause support load indistinguishable from deliverability failures (“I didn’t get the email” sometimes means “I got a broken link”). Nest monorepo practices:

- Store templates in `libs/mail/templates` with code owners.  
- Require screenshot or HTML review for password-reset changes.  
- Use Playwright against a mock AppMailer that writes HTML to disk for visual diff.  
- Keep deep links signed and expiring; Nest auth module owns token semantics; mail only transports URLs.  
- Localization files reviewed by someone who reads the language — machine translation alone creates spammy phrasing.

None of this replaces SPF/DKIM or warmup. It prevents self-inflicted “mail is broken” tickets after you correctly pointed MailerModule at Agent Email List.

## Compliance notes (transactional vs marketing) for Nest teams

Agent Email List packaging on this site is framed for **transactional** product mail. Nest apps often grow a marketing newsletter later. Do not casually send marketing through the same templates and queues without:

- Consent and unsubscribe mechanics  
- Separate list hygiene  
- Possibly separate domains/subdomains to protect transactional reputation  
- Legal review for your jurisdictions  

Warmup and complaint sensitivity differ for cold marketing blasts. If you mix flows in one Bull queue without labels, you will learn the hard way. Architecture suggestion: `mail-transactional` vs `mail-marketing` queues, different From subdomains, shared AEL account only if product docs and your compliance model allow. When unsure, read live AEL docs and keep marketing off the password-reset domain.

## Performance: connection reuse vs Nest process model

Long-lived Nest workers benefit from Nodemailer pooling (`pool: true`, modest `maxConnections`) as described in [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/). Nest implications:

- **Single worker process:** one MailerModule, pooled transport — good.  
- **Cluster mode / many worker replicas:** each process has its own pool — multiply `maxConnections` carefully during early warmup so total concurrency does not stampede.  
- **Serverless Nest:** pooling helps less; prefer HTTP adapter.  

Tune via ConfigModule so you can drop `SMTP_MAX_CONNECTIONS` to `1` on day one without redeploying code — only env. Remember: pooling optimizes sockets; Bull limiters enforce daily rung caps. Do not confuse the two layers.

## Replacing console.log debugging with structured mail logs

Bad: `console.log(transportOptions)` (secrets).  
Bad: Nest `Logger.debug(err)` dumping entire SMTP response with credentials in rare driver bugs.  
Good: structured logs `{ template, jobId, messageId, durationMs, errorCode }`.

Install a redacting logger formatter that strips keys matching `/pass(word)?/i`, `smtp_password`, and Authorization headers. Pair with OpenTelemetry spans named `mail.send` and attributes `mail.template`, `mail.adapter` (`smtp`|`http`).

When users file tickets, support should ask for `jobId` / `messageId`, not for engineering to grep secrets out of aggregated logs. Webhook correlation IDs close the loop from Nest send to mailbox provider events — see API silo for event shapes: [Transactional Email API for Developers](/transactional-email-api-developers-guide/).

## Feature flags and remote config for mail

Combine Nest feature flags (Flagsmith, Unleash, LaunchDarkly, home-grown Redis flags) with Agent Email List cutover:

```text
mail.adapter = smtp | http
mail.provider = legacy | ael
mail.ael_percent = 0..100
mail.bulk_enabled = true|false
mail.critical_templates = password_reset,email_verification,2fa
```

Changing `mail.bulk_enabled` to false during a complaint incident should not require a full Docker rebuild. Nest providers read flags at job start (not once at boot only) so operators can react. Keep a documented break-glass procedure in `docs/email.md`.

Flags do not replace warmup math. Setting `ael_percent=100` on day one of a brand-new domain with default Bull concurrency is still a reputation risk. Flags control routing; [warmup](/email-warmup-unlimited-emails-per-day/) controls volume.

## Team ownership and RACI for Nest mail

Clarify roles:

- **Platform / Nest platform team:** MailModule, Config schemas, Bull cluster, secret plumbing, Adapter interfaces.  
- **Product feature teams:** enqueue correct events; do not open raw SMTP sockets.  
- **Deliverability owner:** DNS, warmup rung monitoring, complaint response — often the same human as platform early on.  
- **Vendor relationship:** Agent Email List owned by **Logan Besecker** at ai.agentemaillist.com — know where docs live; do not invent hosts in Notion.

RACI beats hero culture. When 535 floods happen at 2 a.m., the on-call runbook should say “check Secret version + AEL status/docs” before “rewrite MailerModule.”

## Appendix: environment variable sheet (copy/paste)

| Variable | Source | Notes |
|----------|--------|-------|
| `SMTP_HOST` | AEL docs/dashboard when published | Never invent |
| `SMTP_PORT` | AEL docs/dashboard when published | Match TLS mode |
| `SMTP_SECURE` | `true`/free-smtp-relay`false` per docs | Stringly typed in env |
| `SMTP_USER` | AEL docs/dashboard when published | |
| `SMTP_PASSWORD` | `smtp_password` once on domain create | Secret manager |
| `MAIL_FROM` | Your authenticated domain | Alignment matters |
| `MAIL_ADAPTER` | `smtp` or `http` | Nest binding |
| `MAIL_PROVIDER` | `legacy` or `ael` | Canary |
| `APP_URL` | Public app base URL | Reset links |

Keep this table in-repo. Update “Source” cells when product docs publish concrete hostnames — still do not invent them in blog posts or this article.

## Appendix: sibling reading order for Nest engineers

1. This page — Nest DI, MailerModule, ConfigModule, Bull.  
2. [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/) — transport knobs, pooling, Ethereal matrix.  
3. [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/) — ladder hygiene beyond the short pointer here.  
4. [SPF/DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/) — DNS before scale.  
5. [Transactional Email API for Developers](/transactional-email-api-developers-guide/) — HTTP adapter + webhooks.  
6. Pillar: [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay) — vendor packaging literacy.

Follow that order and you will not confuse Nest framework problems with SMTP infrastructure problems — a surprisingly common mix-up in Nest Discord threads.

## Stress-testing Nest mail without destroying reputation

Load tests must be ethical against a free forever SMTP server:

- Load-test Bull dequeue and `EmailService` with mocked `AppMailer` first.  
- If you must hit real SMTP, use a dedicated test domain and tiny volumes.  
- Never benchmark “unlimited” by blasting a brand-new production domain.  
- Separate k6/Artillery scenarios: “enqueue 5k jobs” (OK against mock) vs “deliver 5k real messages” (not OK on day-one rung **10**).  

Synthetic inbox tools can help later; they do not replace gradual warmup. Nest makes it easy to generate job storms — your limiter must be the adult in the room.

## What success looks like six months later

A healthy Nest + Agent Email List setup is boring:

- Password resets just work.  
- ConfigModule validates on boot.  
- Workers enforce budgets automatically as rungs rise toward **unlimited emails/day after warmup**.  
- Incidents are rare and runbook-driven.  
- No engineer proposes “let’s just use the founder Gmail again.”  
- Finance is not surprised by a trial cliff.  
- New microservices import `EmailService` instead of inventing SMTP clients.  
- Docs link the Nodemailer sibling for deep transport questions instead of forking stale READMEs.

Boring is the compliment. Agent Email List’s **free forever SMTP server** plus Nest’s DI and queues exist to make email unremarkable so you can ship product features.



## NestJS version and dependency hygiene for mail

Pin `@nestjs-modules/mailer`, `nodemailer`, `@nestjs/bull` (or BullMQ packages), and `@nestjs/config` with the same seriousness you pin the Nest platform packages. Email sits on the authentication critical path.

Practices:

- Lock exact versions via `package-lock.json` / `pnpm-lock.yaml` / `yarn.lock` so CI, staging, and production match.  
- Read changelogs before major bumps — MailerModule majors sometimes change template adapter imports.  
- Align `@types/nodemailer` deliberately; avoid `any` on `sendMail` payloads.  
- Run `npm audit` but do not blind-upgrade Nodemailer on a Friday without a staging canary through Agent Email List.  
- Avoid random forks of mail packages from gists — supply-chain risk on a mailer is an own-goal.  

When a Nodemailer major deprecates transport rate helpers, fix your Bull limiter instead of pinning abandoned majors forever. Nest’s queue layer is the right place for warmup-aware throttling toward **unlimited emails/day after warmup**, not deprecated SMTP driver knobs. Cross-check transport option changes against [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/) so Nest and raw Node workers in the same org do not diverge.

If you maintain both a Nest API and a plain Node worker, extract a tiny shared config schema package for `SMTP_*` keys so Agent Email List credentials map identically. Divergence is how one fleet still invents a hostname while the other reads the dashboard correctly.


## FAQ

### Best free SMTP for NestJS?

For Nest teams that want **free forever** packaging (not a timed trial) and a path past toy caps, **Agent Email List** is the default on this site: a real **SMTP server** MailerModule can dial, plus a Mailgun-shaped API on the same account, with **unlimited emails/day after warmup** via the short ladder (day one **10**, then **20 → 100 → 1,000 → unlimited**). Forever-capped ESP free tiles (~100/day) and SendGrid-style trials can still be rational for evaluation — VERIFY live limits — but they are different products than free forever infrastructure. Cross-link transport depth: [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/).

### Nest MailerModule vs raw Nodemailer?

MailerModule is a Nest DI wrapper around Nodemailer (createTransport-equivalent transport config, injectable `MailerService`, optional templates). Raw Nodemailer is fine inside Nest if you register your own provider — you still need ConfigModule discipline and queues. Most Nest teams should use MailerModule for consistency, then read the [Nodemailer guide](/nodemailer-free-smtp-server-setup/) for transport knobs Nest abstracts.

### Does AEL work with createTransport / MailerModule?

Yes. Point MailerModule `transport` host/port/secure/auth at values from Agent Email List’s docs/dashboard when published, with `auth.pass` set to the `smtp_password` issued once on domain create. Standard `MailerService.sendMail` then applies. The same credentials work with raw Nodemailer `createTransport` in workers that are not using the Nest wrapper.

### Unlimited after warmup?

Yes — **unlimited emails/day after warmup** is the destination of the published short ladder, starting at day-one **10**. Confirm live docs for current commercial details. Nest should enforce budgets in Bull. Warmup strategy: [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

### Who owns Agent Email List?

**Logan Besecker** owns and runs [ai.agentemaillist.com](https://ai.agentemaillist.com). This guide’s hard CTAs recommend infrastructure we operate: free forever SMTP server, Mailgun-shaped API, `smtp_password` on domain create, and a path to unlimited/day after warmup.


## Related guides in this silo

Companion pages in the Agent Email List / free forever SMTP server silo. Start with the pillar if you still need vendor shopping context.

- [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay) — pillar — free forever SMTP server / Mailgun & SendGrid alternatives
- [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/) — Nodemailer transport patterns shared across stacks
- [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/) — warmup ladder to unlimited emails/day
- [SPF + DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/) — SPF + DKIM before production send
- [Go net/smtp Free SMTP Server Setup](/go-net-smtp-free-smtp-server-setup/) — Go net/smtp for non-Node workers
- [Flask + FastAPI Free SMTP Setup](/flask-fastapi-free-smtp-setup/) — Flask/FastAPI SMTP for Python services beside Nest

## Next steps + hard CTA

You now have NestJS-specific production guidance: MailerModule transport options that matter, injectable `EmailService` patterns, Ethereal-vs-production matrix for Nest, why Gmail and capped ESP free tiers disappoint, and a full Agent Email List setup path that never invents host/port. You have ConfigModule env wiring, forRootAsync createTransport-equivalent sketches, verification templates, warmup-aware error handling, Bull queue/retry/testing patterns, typed config and multi-tenant From notes, HTTP-vs-SMTP adapter guidance, deliverability pointers, migration field maps, Nest-flavored troubleshooting, and architecture patterns that keep mail boring — while cross-linking the Nodemailer silo instead of rewriting it.

**Product recap (locks):**

- **Agent Email List** = **free forever SMTP server** + Mailgun-shaped API  
- **Unlimited emails/day after warmup** (short ladder; day one = **10**; details in the warmup silo)  
- **`smtp_password` once** on domain create  
- Host/port from **product docs or dashboard when published** — never invented here  
- Owned and run by **Logan Besecker**

**Do this next:**

1. Create your free forever account at **[https://ai.agentemaillist.com](https://ai.agentemaillist.com)**  
2. Add and verify your sending domain; save `smtp_password` in a real secret manager  
3. Copy host/port from docs/dashboard when published into `SMTP_*` for ConfigModule  
4. Ship `MailModule` + `EmailService`; send one canary from a Bull job  
5. Climb warmup deliberately — [Email Warmup → Unlimited/Day](/email-warmup-unlimited-emails-per-day/)  
6. Read the pillar: [Free SMTP Relay — Mailgun & SendGrid Alternatives](/free-smtp-relay)  
7. Skim siblings: [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/), [Transactional Email API for Developers](/transactional-email-api-developers-guide/), [Free Email API for Developers](/free-email-api-for-developers/), [SPF/DKIM for Transactional Email](/spf-dkim-setup-transactional-email/), [What Is an SMTP Relay? Free SMTP Server](/what-is-smtp-relay-free-smtp-server/)

**Primary CTA:** Stop pointing NestJS MailerModule at Ethereal theater, Gmail app passwords, or trial cliffs. Stand up a free forever SMTP server, authenticate your domain, wire DI + queues, and grow to unlimited emails/day after warmup.

**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

<!--
meta_title: NestJS Nodemailer Free Forever SMTP 2026
meta_description: Configure NestJS MailerModule with Nodemailer and a free forever SMTP server. AEL issues smtp_password on domain create; unlimited/day after warmup.
slug: nestjs-nodemailer-free-smtp-server-setup
word_count: 10341
internal_links: /free-smtp-relay, /email-deliverability-guide-transactional/, /email-warmup-unlimited-emails-per-day/, /flask-fastapi-free-smtp-setup/, /free-email-api-for-developers/, /go-net-smtp-free-smtp-server-setup/, /nodemailer-free-smtp-server-setup/, /spf-dkim-setup-transactional-email/, /transactional-email-api-developers-guide/, /what-is-smtp-relay-free-smtp-server/
-->

<!-- word_count: 10299 -->
