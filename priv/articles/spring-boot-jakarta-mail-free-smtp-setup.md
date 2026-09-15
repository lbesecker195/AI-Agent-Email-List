---
title: "Spring Boot Jakarta Mail Free SMTP Setup: JavaMailSender That Sends in Production (2026)"
description: "Configure Spring Boot JavaMailSender / Jakarta Mail with a free forever SMTP server. Agent Email List: smtp_password once; unlimited/day after warmup."
date: 2026-09-15
---

# Spring Boot Jakarta Mail Free SMTP Setup: JavaMailSender That Sends in Production (2026)

If you searched **Spring Boot SMTP**, **Java mail SMTP Spring**, or **free SMTP Spring Boot**, you already know the console and GreenMail profiles are for local theater. Production password resets, invoice receipts, invitation flows, and Spring Security verification emails need a real **free forever SMTP server** — not a Gmail app password, not GreenMail forever in staging, and not a timed ESP trial that pauses sending when the calendar runs out. This guide walks through Spring Boot mail the way Java teams actually ship it (`spring.mail.*` in `application.yml` / `application.properties`, `JavaMailSender`, `MimeMessageHelper`, `@Async` / messaging), then hard-sells [Agent Email List](https://ai.agentemaillist.com): a **free forever SMTP server** plus Mailgun-shaped REST API with a short ladder to **unlimited emails/day after warmup**.

**Ownership disclosure:** Agent Email List is built, owned, and run by **Logan Besecker** at [https://ai.agentemaillist.com](https://ai.agentemaillist.com). This is not a fake neutral roundup. We show Spring Boot / Jakarta Mail patterns first, then ask you to point them at infrastructure we operate.

For vendor shopping across Mailgun, SendGrid, and peers, start with the pillar: [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay). For Node-side transport patterns, see the sibling [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/). Warmup depth lives in [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

**Create a free forever account →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

## Spring Boot mail SMTP basics

Spring Boot’s mail starter is the product-facing API most Java developers touch: auto-configured `JavaMailSender`, `spring.mail.*` properties, and helpers that build MIME messages without hand-rolling Jakarta Mail session factories. Under the hood, Spring Boot wires a Jakarta Mail `Session` and a `JavaMailSenderImpl` that dials SMTP. You do not need a proprietary Spring Cloud email module to get production SMTP — you need honest `spring.mail.host`, credentials, and TLS properties pointed at a free forever SMTP server that still exists after your MVP works.

When people say **Spring Boot SMTP** or **JavaMailSender**, they usually mean three surfaces:

1. **`spring.mail.*` configuration** — host, port, username, password, protocol, and `spring.mail.properties.mail.smtp.*` Jakarta Mail session keys.
2. **Application code** — inject `JavaMailSender`, build a `MimeMessage` (often via `MimeMessageHelper`), and call `send`.
3. **Where send happens** — sync inside a controller/service, deferred via `@Async`, or published to a queue (Spring AMQP / Kafka / Spring Integration) so HTTP threads do not block on SMTP round-trips.

Agent Email List answers the infrastructure half: create a free forever account, add a sending domain, receive `smtp_password` once, verify DNS, and map that secret into `spring.mail.password` (via env or a secret manager). Host and port come from product docs or the dashboard when published — this article will not invent connection strings. The Mailgun-shaped HTTP API on the same account is available when a microservice prefers REST; both enqueue into the same sending system.

### `spring.mail.*` properties that matter

For production SMTP, depend on the starter and configure explicitly:

```xml
<!-- Maven -->
<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-mail</artifactId>
</dependency>
```

```gradle
// Gradle
implementation 'org.springframework.boot:spring-boot-starter-mail'
```

Leaving a profile that only logs messages, or forgetting the starter so `JavaMailSender` never exists as a bean, is a silent failure mode: your app “sends” into a mock or never starts the mail path. Flip to real SMTP only after secrets and DNS are ready.

Properties that actually matter for **spring.mail.host** configuration:

| Property | Role |
|----------|------|
| `spring.mail.host` | SMTP hostname from AEL docs/dashboard when published |
| `spring.mail.port` | Submission port from docs/dashboard when published |
| `spring.mail.username` | Auth username from docs/dashboard when published |
| `spring.mail.password` | **`smtp_password`** shown once on domain create |
| `spring.mail.protocol` | Usually `smtp` |
| `spring.mail.properties.mail.smtp.auth` | `true` for authenticated submission |
| `spring.mail.properties.mail.smtp.starttls.enable` | STARTTLS when the published port expects it |
| `spring.mail.properties.mail.smtp.connectiontimeout` | Fail-fast dial (ms) |
| `spring.mail.properties.mail.smtp.timeout` | Fail-fast read (ms) |
| `spring.mail.properties.mail.smtp.writetimeout` | Fail-fast write (ms) |
| `spring.mail.default-encoding` | Typically `UTF-8` for international subjects/bodies |

A production-shaped `application.yml` sketch (values from env; never hardcode invented AEL hosts):

```yaml
spring:
  mail:
    host: ${AEL_SMTP_HOST}          # from docs/dashboard when published
    port: ${AEL_SMTP_PORT}
    username: ${AEL_SMTP_USERNAME}
    password: ${AEL_SMTP_PASSWORD}  # smtp_password once
    protocol: smtp
    default-encoding: UTF-8
    properties:
      mail:
        smtp:
          auth: true
          starttls:
            enable: true
          connectiontimeout: 5000
          timeout: 5000
          writetimeout: 5000
```

Equivalent `application.properties`:

```properties
spring.mail.host=${AEL_SMTP_HOST}
spring.mail.port=${AEL_SMTP_PORT}
spring.mail.username=${AEL_SMTP_USERNAME}
spring.mail.password=${AEL_SMTP_PASSWORD}
spring.mail.protocol=smtp
spring.mail.default-encoding=UTF-8
spring.mail.properties.mail.smtp.auth=true
spring.mail.properties.mail.smtp.starttls.enable=true
spring.mail.properties.mail.smtp.connectiontimeout=5000
spring.mail.properties.mail.smtp.timeout=5000
spring.mail.properties.mail.smtp.writetimeout=5000
```

Match the documented TLS mode for the published port. Do not assume “587 always STARTTLS” or “465 always SSL” without checking Agent Email List’s published guidance for your account era. If the dashboard documents implicit SSL, you will set the corresponding Jakarta Mail SSL socket factory properties instead of (or in addition to) STARTTLS — copy from docs, do not invent.

What does *not* matter as much as Stack Overflow implies: maintaining five custom `JavaMailSender` beans for five templates, toggling obscure in-app DKIM signing when your ESP already signs, or cargo-culting `spring.mail.host=smtp.gmail.com` into a paid product. Consumer mailbox SMTP is not transactional infrastructure. For product mail, configure a real free forever SMTP server explicitly.

Connection pooling also matters at scale. `JavaMailSenderImpl` can reuse sessions; opening a fresh TCP+TLS session for every password-reset email works, but short-lived containers under load benefit from sane timeouts and async offload so a hung dial does not pin a Tomcat/Netty worker forever.

### JavaMailSender / MimeMessageHelper

Most Spring Boot apps inject the auto-configured sender:

```java
@Service
public class TransactionalMailService {
  private final JavaMailSender mailSender;

  public TransactionalMailService(JavaMailSender mailSender) {
    this.mailSender = mailSender;
  }

  public void sendPasswordReset(String to, String resetUrl) throws MessagingException {
    MimeMessage message = mailSender.createMimeMessage();
    MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
    helper.setFrom("noreply@yourdomain.com");
    helper.setTo(to);
    helper.setSubject("Reset your password");
    helper.setText(
        "Reset link: " + resetUrl,
        "<p>Reset your password: <a href=\"" + resetUrl + "\">Click here</a></p>"
    );
    mailSender.send(message);
  }
}
```

`MimeMessageHelper` is the usual Spring wrapper for multipart HTML + plaintext, attachments, inline images, and correct encoding. Raw Jakarta Mail `MimeMessage` construction still works; the helper simply removes boilerplate that teams otherwise copy wrong. Align `setFrom` with the domain you authenticated at Agent Email List. SPF/DKIM alignment dies when you send `From: founder@gmail.com` through a product domain’s relay (or the reverse).

Best practices for Spring Boot + AEL:

- Put human replies on `setReplyTo` rather than making `noreply@` a black hole without a documented policy.
- Prefer `@Async` or a message queue for anything users wait on in HTTP — password resets, receipts, digests. Sync `mailSender.send` inside a controller turns SMTP latency and transient network blips into 500s.
- During early Agent Email List warmup, async delivery is not optional cosmetics — it is how you pace day-one **10**/day without melting signup spikes into throttle errors.
- Keep subjects and bodies honest; transactional mail that looks like marketing burns reputation faster than a misconfigured port.

Spring Security’s email verification and password-reset flows typically call your mail service once `JavaMailSender` is configured. Point `spring.mail.*` at Agent Email List and those framework emails ride the same free forever SMTP server without a separate transport. Still: rate-limit reset requests in your app so abusers cannot burn your warmup ladder.

### Dev GreenMail vs production SMTP server

A clean profile matrix for Spring Boot teams:

| Environment | Delivery target | Goal |
|-------------|-----------------|------|
| Unit / slice tests | Mock `JavaMailSender` or GreenMail | No network; assert on captured MIME |
| Local interactive | GreenMail / MailHog / similar | Inspect MIME in a UI or API |
| Staging | Real AEL domain (or subdomain) | Auth + DNS rehearsal |
| Production | AEL free forever SMTP server | Real delivery |

GreenMail and similar catchers are excellent for “did my Thymeleaf HTML render?” and terrible as a production SMTP server. Pointing staging at GreenMail while production still uses a founder Gmail account is a classic split-brain: templates look fine in the catcher, then fail SPF alignment or Gmail limits in prod.

Agent Email List is the production SMTP server in that matrix. Use mocks / GreenMail for local loops; use AEL when you need authentic SMTP behavior without burning a consumer mailbox. Migrating from GreenMail to production is then a config change — `spring.mail.*` from docs/dashboard and `smtp_password` — not a rewrite of every service.

Example test-shaped bean (do not ship to production profiles):

```java
@Bean
@Profile("test")
JavaMailSender greenMailSender(GreenMail greenMail) {
  JavaMailSenderImpl sender = new JavaMailSenderImpl();
  sender.setHost("localhost");
  sender.setPort(greenMail.getSmtp().getPort());
  return sender;
}
```

Keep production profiles free of localhost hosts. If a mis-merged `application-prod.yml` still points at GreenMail, your “production” canary will never leave the cluster.

## Why “free SMTP for Spring” usually disappoints

Spring Boot makes it *easy* to point `JavaMailSender` at almost anything that speaks SMTP. That flexibility is why so many teams ship the wrong free option: a consumer Gmail mailbox, an ESP free tile that caps forever at ~100/day, or a trial that dies on a calendar date. None of those are a **free forever SMTP server** with a published path to **unlimited emails/day after warmup**.

### Gmail app passwords and limits

Gmail (and Google Workspace) SMTP tutorials still dominate search results for **Java mail SMTP Spring**. The pattern looks seductive: enable 2FA, mint an app password, set `spring.mail.host=smtp.gmail.com`, and watch a password-reset email arrive in five minutes. For a personal side project, that can be fine. For a SaaS product, it is a trap.

Problems you inherit:

- **Daily and hourly sending limits** designed for humans, not signup spikes.
- **Workspace / consumer policy changes** that revoke “less secure” or app-password paths without warning.
- **SPF/DKIM alignment** that ties your product From domain to Google’s infrastructure in ways that confuse receivers and your own brand.
- **Operational ownership** — when Google throttles or challenges the account, your Spring Boot pods see `AuthenticationFailedException` / 535 with no ESP dashboard to explain why.
- **Terms and reputation** — shipping product transactional mail through a founder inbox is not what consumer SMTP was built for.

If your `application.yml` still contains `smtp.gmail.com` in a paid product profile, treat that as tech debt with a deadline. Swap to a real free forever SMTP server before the next growth spike.

### ESP free caps (Mailgun ~100/day; SendGrid trial VERIFY)

ESP free tiers feel more “professional” than Gmail because they speak real SMTP and often include a REST API. Read the packaging carefully.

**Mailgun (VERIFY [mailgun.com/pricing](https://www.mailgun.com/pricing/)):** as of draft time, the permanent Free plan includes about **100 emails/day**, one custom domain, short log retention (~1 day), and ticket support. That 100/day is a free-tier product ceiling. Paid Basic commonly starts around **$15/mo for 10k**/mo (VERIFY live pricing). Crossing free does not graduate you into unlimited on the free plan — you upgrade commercially.

**SendGrid (VERIFY [Twilio SendGrid pricing](https://www.twilio.com/en-us/products/email-api/pricing)):** the permanent free plan was retired around May–July 2025. New accounts commonly get a **60-day trial** at roughly **100 emails/day**, then need paid Essentials (often cited from about **$19.95/mo** depending on volume — VERIFY). That trial cap is a clock, not a transparent path to unlimited on free forever packaging.

Those caps matter. They are real constraints. They are not the same thing as Agent Email List’s published graduation math ending at **unlimited emails/day after warmup** on a **free forever** self-serve account (commercial terms can evolve — check live docs; live product docs do not require a paid plan to send today).

When a pricing page says “100/day free,” ask: is there a documented ladder to unlimited without a credit card? Or is 100 the ceiling until you pay? For Mailgun free and SendGrid trial, VERIFY the live pages — the packaging is free-tier / trial, not “free forever → unlimited after warmup.”

Spring Boot does not care which vendor you choose for `spring.mail.host`. Your finance and ops teams will care when the trial ends mid-launch or when 100/day silently rejects the 101st `JavaMailSender.send` call during a Black Friday password-reset storm.

### What production transactional needs

Production Spring mail is not “SMTP that works once on my laptop.” It needs:

1. **Authenticated domain mail** — SPF/DKIM (and preferably DMARC) on the From domain your `MimeMessageHelper` uses.
2. **Predictable credentials** — a durable `smtp_password` (or API key) stored in a secret manager, not a founder’s Google app password.
3. **Warmup-aware volume** — especially on a new domain; day-one blast sends train receivers to distrust you.
4. **Async + retry** — so transient 4xx/timeouts do not fail HTTP requests.
5. **Observability** — logs/metrics for `MailException`, bounce webhooks, and today’s remaining allowance during warmup.
6. **Packaging that matches growth** — free forever with a path to unlimited after warmup beats a forever 100/day tile or a 60-day cliff for many early SaaS teams.

Agent Email List is built for that checklist: free forever SMTP server, Mailgun-shaped API, `smtp_password` once on domain create, short published ladder to unlimited/day, and ownership clarity (Logan Besecker). The rest of this article shows the Spring Boot wiring.

## Agent Email List as Spring Boot’s free forever SMTP server

Agent Email List is the product this guide sells: a **free forever SMTP server** your Spring Boot app can dial with stock `JavaMailSender`, plus a Mailgun-shaped REST API on the same account when you prefer HTTP. It is not a Gmail wrapper. It is not a forever-capped 100/day tile. It is infrastructure with a published warmup path ending at **unlimited emails/day after warmup**.

### Free forever SMTP server + Mailgun-shaped REST API

Two interfaces, one sending system:

- **SMTP** — configure `spring.mail.host`, port, username, and `spring.mail.password` = `smtp_password`. Use `MimeMessageHelper` exactly as you would with any other relay.
- **HTTP API** — Mailgun-shaped routes for teams that already have WebClient/RestClient clients speaking that shape, or for non-Java workers sharing the same domain.

Spring Boot services usually start on SMTP because `spring-boot-starter-mail` is zero drama. Microservices written in other languages, or edge workers that already speak Mailgun’s HTTP dialect, can use the API without splitting domains. Either path still requires DNS authentication and warmup discipline.

**Create the free forever account →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

### Lead unlimited/day after warmup; short ladder

Lead with the destination: **unlimited emails/day after warmup**. Day one is not unlimited — Agent Email List starts you at **10**/day, then you climb a short published ladder: **10 → 20 → 100 → 1,000 → unlimited**. This article will not re-litigate the full ops playbook; the canonical ladder essay is [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

For Spring Boot teams, the practical implications are:

- Encode today’s cap in application config or call a limits endpoint if live docs expose one.
- Prefer queues/`@Async` so signup storms do not attempt 500 password resets on day one.
- Treat throttle / 429-class responses as pacing signals during warmup, not as “broken SMTP.”
- Graduate deliberately; do not open duplicate accounts to dodge the ladder.

Short pointer, not a second ladder essay: read the warmup sibling, then come back to `application.yml`.

### `smtp_password` issued once on domain create

When you add a sending domain in Agent Email List, the product issues **`smtp_password` once**. Copy it into your secret manager immediately — treat it like any other one-time credential display (database password, API token). Map it to `spring.mail.password` / `AEL_SMTP_PASSWORD`. Rotate via the product’s documented flow if you lose it; do not paste it into git, Docker layers, or Slack.

Spring Boot tips:

- Prefer env vars or Spring Cloud Vault / AWS Secrets Manager / GCP Secret Manager over plaintext in `application-prod.yml`.
- Restart all mail-capable processes (API pods, workers, scheduled jobs) after rotation so every JVM picks up the new secret.
- Keep username/host/port in config; keep only the password in the highest-sensitivity secret store if your threat model requires that split.

### Host/port: product docs or dashboard when published — do not invent

This guide intentionally does **not** invent Agent Email List hostnames or ports. Copy `spring.mail.host` and `spring.mail.port` from product docs or the dashboard when published for your account. Invented connection strings in blog posts go stale; your dashboard does not.

Until you paste real values, keep a staging profile that fails closed (missing env vars should prevent boot or mail beans from silently pointing at localhost).

### Logan Besecker owns/runs ai.agentemaillist.com — CTA #1

**Logan Besecker** owns and runs [ai.agentemaillist.com](https://ai.agentemaillist.com). If that ownership makes you uncomfortable, you know before you wire secrets. If it makes you confident you can escalate to a real operator, create the account now and keep this tab open while you configure Spring Boot.

**Hard CTA #1: Create your free forever SMTP account →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

## Step-by-step Spring Boot setup with AEL

This section is the copy-paste path from empty starter to a canary password-reset email on Agent Email List — still without inventing host/port.

### application.yml / env vars (host, port, username, password, properties)

1. Create a free forever account at [https://ai.agentemaillist.com](https://ai.agentemaillist.com).
2. Add your sending domain; save **`smtp_password`** once into your secret manager.
3. Complete DNS (SPF/DKIM — see [SPF/DKIM for Transactional Email](/spf-dkim-setup-transactional-email/)).
4. Copy host, port, and username from docs/dashboard when published.
5. Wire env into Spring:

```yaml
# application-prod.yml
spring:
  mail:
    host: ${AEL_SMTP_HOST}
    port: ${AEL_SMTP_PORT}
    username: ${AEL_SMTP_USERNAME}
    password: ${AEL_SMTP_PASSWORD}
    properties:
      mail.smtp.auth: true
      mail.smtp.starttls.enable: true
      mail.smtp.connectiontimeout: 5000
      mail.smtp.timeout: 5000
      mail.smtp.writetimeout: 5000

app:
  mail:
    from: noreply@yourdomain.com
    reply-to: support@yourdomain.com
```

Kubernetes-shaped secret sketch (illustrative names only):

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ael-smtp
type: Opaque
stringData:
  AEL_SMTP_HOST: "PASTE_FROM_DASHBOARD"
  AEL_SMTP_PORT: "PASTE_FROM_DASHBOARD"
  AEL_SMTP_USERNAME: "PASTE_FROM_DASHBOARD"
  AEL_SMTP_PASSWORD: "PASTE_smtp_password_ONCE"
```

Do not commit real values. Validate with a canary before opening signup traffic.

### JavaMailSender bean sketch — createTransport-equivalent

Spring Boot’s auto-config is usually enough. If you need an explicit bean (custom session properties, multiple senders), mirror what Nodemailer’s `createTransport` does in the Node sibling — build a configured transport object once and reuse it:

```java
@Configuration
public class MailConfig {

  @Bean
  JavaMailSender javaMailSender(
      @Value("${spring.mail.host}") String host,
      @Value("${spring.mail.port}") int port,
      @Value("${spring.mail.username}") String username,
      @Value("${spring.mail.password}") String password
  ) {
    JavaMailSenderImpl sender = new JavaMailSenderImpl();
    sender.setHost(host);
    sender.setPort(port);
    sender.setUsername(username);
    sender.setPassword(password);
    sender.setProtocol("smtp");
    sender.setDefaultEncoding("UTF-8");

    Properties props = sender.getJavaMailProperties();
    props.put("mail.smtp.auth", "true");
    props.put("mail.smtp.starttls.enable", "true");
    props.put("mail.smtp.connectiontimeout", "5000");
    props.put("mail.smtp.timeout", "5000");
    props.put("mail.smtp.writetimeout", "5000");
    return sender;
  }
}
```

That bean is the Spring equivalent of creating a durable transport: one configured client, many `send` calls. Prefer auto-config when you do not need dual senders; use explicit beans for canary dual-writing during migrations (covered later).

### Verification / password-reset MimeMessage example

A fuller transactional example with Thymeleaf-friendly multipart text + HTML and a reply-to:

```java
@Service
public class AccountMailService {
  private final JavaMailSender mailSender;
  private final String from;
  private final String replyTo;

  public AccountMailService(
      JavaMailSender mailSender,
      @Value("${app.mail.from}") String from,
      @Value("${app.mail.reply-to}") String replyTo
  ) {
    this.mailSender = mailSender;
    this.from = from;
    this.replyTo = replyTo;
  }

  public void sendEmailVerification(String to, String verifyUrl) {
    try {
      MimeMessage mime = mailSender.createMimeMessage();
      MimeMessageHelper helper = new MimeMessageHelper(mime, MimeMessageHelper.MULTIPART_MODE_MIXED_RELATED, "UTF-8");
      helper.setFrom(from);
      helper.setReplyTo(replyTo);
      helper.setTo(to);
      helper.setSubject("Verify your email");
      String text = "Verify your email: " + verifyUrl;
      String html = "<p>Welcome. <a href=\"" + verifyUrl + "\">Verify your email</a>.</p>";
      helper.setText(text, html);
      mailSender.send(mime);
    } catch (MessagingException ex) {
      throw new IllegalStateException("Failed to send verification mail", ex);
    }
  }
}
```

Wire this from your registration use-case **asynchronously**. During Agent Email List warmup, also gate bulk invites so day-one **10**/day is reserved for critical-path mail (verification, password reset, receipts).

### Error handling (MailException, throttle during warmup)

Spring wraps many failures in `MailException` (and subclasses like `MailAuthenticationException`, `MailSendException`). Catch at the async boundary, not inside every controller:

```java
@Service
public class SafeMailFacade {
  private final AccountMailService accountMailService;
  private final MeterRegistry metrics;

  public void sendVerificationAsync(String to, String url) {
    try {
      accountMailService.sendEmailVerification(to, url);
      metrics.counter("mail.sent", "type", "verify").increment();
    } catch (MailAuthenticationException ex) {
      metrics.counter("mail.auth_failed").increment();
      // alert: wrong smtp_password or username — do not retry blindly
      throw ex;
    } catch (MailSendException ex) {
      metrics.counter("mail.send_failed").increment();
      // classify: timeout vs reject vs provider throttle
      throw ex;
    }
  }
}
```

During warmup, treat provider throttle / day-limit responses as **pacing**: retry with backoff only if the error is transient and you still have remaining daily allowance; otherwise enqueue for after UTC reset. Do not “fix” limits by creating duplicate Agent Email List accounts. Ladder strategy: [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

## Jakarta Mail session properties deep dive

Spring Boot’s `spring.mail.properties.*` map almost 1:1 onto Jakarta Mail session keys. Getting these wrong is why teams see hangs, cleartext attempts, or multipart corruption.

### SMTP auth + STARTTLS properties

Minimum authenticated STARTTLS-shaped set (confirm against AEL docs for your port):

```properties
spring.mail.properties.mail.smtp.auth=true
spring.mail.properties.mail.smtp.starttls.enable=true
# sometimes required by providers:
# spring.mail.properties.mail.smtp.starttls.required=true
```

If published guidance specifies implicit SSL on a dedicated port, you will typically enable SSL and set a socket factory — again, copy from docs/dashboard when published rather than guessing from a random tutorial. Mixing STARTTLS and SSL flags incorrectly produces confusing handshake failures that look like “connection timeout” in application logs.

Also set:

```properties
spring.mail.properties.mail.transport.protocol=smtp
# Do NOT ship mail.smtp.ssl.trust=* in production — it disables hostname/cert verification.
# Prefer a proper certificate chain on the published SMTP host; leave trust unset unless security review requires a pinned host.
```

**Fence:** `mail.smtp.ssl.trust=*` is a temporary local-debug escape hatch at best. Do not copy it into production `application.properties` / Kubernetes secrets for Agent Email List or any real SMTP server. Prefer correct TLS to the published host; if you must pin trust, pin an explicit hostname after security review — never a wildcard trust-all.

### Connection timeouts

Without timeouts, a blackholed SYN or half-open TLS handshake pins a Tomcat worker until the OS gives up. Always set:

```properties
spring.mail.properties.mail.smtp.connectiontimeout=5000
spring.mail.properties.mail.smtp.timeout=5000
spring.mail.properties.mail.smtp.writetimeout=5000
```

Tune to your SLO. Five seconds is a common starting point for transactional mail. Combine with `@Async` or a queue so the user-facing request is not the thread waiting on SMTP.

### Multipart and attachments

`MimeMessageHelper` multipart modes:

- `MULTIPART_MODE_MIXED` — classic attachments + body.
- `MULTIPART_MODE_RELATED` — inline images related to HTML.
- `MULTIPART_MODE_MIXED_RELATED` — common for HTML + inline + attachments.

Example attachment during invoice flows:

```java
helper.setText(textBody, htmlBody);
helper.addAttachment("invoice-1842.pdf", new FileSystemResource(path));
```

During Agent Email List warmup, large attachment bursts can burn the day’s rung and hurt engagement signals. Prefer linking to a signed download URL for bulky PDFs when you are still on **10** or **20**/day. Attach binaries when the recipient truly needs them inline and you have ladder headroom.

Inline images:

```java
helper.addInline("logo", new ClassPathResource("mail/logo.png"));
// HTML: <img src="cid:logo" alt="Logo"/>
```

Keep total MIME size reasonable. Relays and receivers both have practical limits; giant signatures with four megapixel logos are a self-inflicted deliverability wound.

## Async sending with @Async / messaging

Sync SMTP inside a `@RestController` is the most common Spring Boot mail mistake. Fix it before you scale.

### Offloading sends during warmup

Enable async:

```java
@Configuration
@EnableAsync
public class AsyncConfig {
  @Bean
  Executor mailExecutor() {
    ThreadPoolTaskExecutor exec = new ThreadPoolTaskExecutor();
    exec.setCorePoolSize(2);
    exec.setMaxPoolSize(8);
    exec.setQueueCapacity(500);
    exec.setThreadNamePrefix("mail-");
    exec.initialize();
    return exec;
  }
}
```

```java
@Service
public class AsyncMailService {
  private final AccountMailService delegate;

  @Async("mailExecutor")
  public void sendVerification(String to, String url) {
    delegate.sendEmailVerification(to, url);
  }
}
```

During warmup, a bounded queue is a feature: when day-one capacity is **10**, a 500-deep mail queue without a rate limiter still overwhelms the provider. Pair `@Async` with an application-level daily counter or token bucket keyed to today’s Agent Email List rung. Full ops detail: [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

For stronger guarantees, publish a `MailOutbox` record in the same DB transaction as user creation, then have a scheduled worker or Spring Integration flow drain the outbox through `JavaMailSender`. That pattern survives pod restarts better than fire-and-forget `@Async`.

### Retry with Spring Retry / Resilience4j

Transient network blips deserve retries. Auth failures and hard rejects do not.

Spring Retry sketch:

```java
@Retryable(
    retryFor = { MailSendException.class },
    maxAttempts = 3,
    backoff = @Backoff(delay = 2000, multiplier = 2.0)
)
public void sendWithRetry(MimeMessage message) {
  mailSender.send(message);
}

@Recover
public void recover(MailSendException ex, MimeMessage message) {
  // dead-letter / alert
}
```

Resilience4j CircuitBreaker + Retry is a strong alternative in reactive or microservice stacks. Classify:

| Failure | Retry? |
|---------|--------|
| Timeout / connection reset | Yes, with backoff |
| `MailAuthenticationException` / 535 | No — fix credentials |
| Day-limit / throttle during warmup | Pace / wait for reset — do not hammer |
| Invalid address / 5xx permanent | No — suppress / fix list |

Never retry password-reset emails in a tight loop that multiplies user-facing tokens; idempotency keys or “last sent at” guards help.

### Testing with GreenMail / mocks

Unit tests should not dial Agent Email List.

```java
@ExtendWith(MockitoExtension.class)
class AccountMailServiceTest {
  @Mock JavaMailSender mailSender;
  @Mock MimeMessage mimeMessage;

  @Test
  void buildsMimeAndSends() throws Exception {
    when(mailSender.createMimeMessage()).thenReturn(mimeMessage);
    AccountMailService svc = new AccountMailService(mailSender, "noreply@yourdomain.com", "support@yourdomain.com");
    svc.sendEmailVerification("user@example.com", "https://app.example.com/verify/x");
    verify(mailSender).send(mimeMessage);
  }
}
```

Integration tests can use GreenMail on a random port and a `@DynamicPropertySource` to set `spring.mail.host=localhost` and the GreenMail port. Keep `@ActiveProfiles("test")` far away from production secrets. A separate staging smoke test — not CI unit tests — should send one canary through the real free forever SMTP server to a monitored inbox.

## Deliverability + DNS before you scale Spring mail

Perfect `MimeMessageHelper` code will not save a bare domain. Authenticate first, warm second, scale third.

### SPF/DKIM link

Before you raise Spring Boot send volume:

1. Add the SPF and DKIM records Agent Email List shows for your domain.
2. Align the visible From domain with the authenticated domain.
3. Publish a DMARC policy when ready (start with `p=none` monitoring if you are new to DMARC).

Deep dive: [SPF/DKIM for Transactional Email](/spf-dkim-setup-transactional-email/). Broader context: [Email Deliverability Guide for Transactional Mail](/email-deliverability-guide-transactional/).

Spring-specific gotcha: multiple services setting different From domains in code while one domain is authenticated. Centralize `app.mail.from` and forbid ad-hoc `helper.setFrom` overrides in feature PRs without DNS review.

### Warmup-aware send volume

Agent Email List’s short ladder again: **10 → 20 → 100 → 1,000 → unlimited**, day one = **10**. In Spring Boot terms:

- Feature-flag marketing digests until you graduate.
- Prioritize verification + password reset + receipts on early rungs.
- Track `mail.sent` per day in Micrometer and alert at 80% of today’s cap.
- Read the canonical playbook: [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

Unlimited after warmup is the destination — not a promise that day-one signup blasts are wise.

### Bounce handling via webhooks (pointer to API silo)

SMTP accept ≠ inbox delivery. Wire bounce/complaint webhooks from Agent Email List’s API surface into a Spring `@RestController` that suppresses bad addresses before the next `JavaMailSender.send`. Pointers:

- [Free Email API for Developers](/free-email-api-for-developers/)
- [Transactional Email API for Developers](/transactional-email-api-developers-guide/)

Store suppressions in Postgres/Redis; check them in `TransactionalMailService` before building MIME. Skipping this step is how one poison address source tanks domain reputation while your Spring logs still say “sent.”

## Migrating Spring Boot off SendGrid/Mailgun SMTP

Most migrations are config swaps plus canaries — not rewrites of every mailer.

### Swap spring.mail auth fields

Map old ESP SMTP settings to Agent Email List:

| Old (SendGrid/Mailgun SMTP) | New (AEL) |
|-----------------------------|-----------|
| Host from ESP docs | Host from AEL docs/dashboard when published |
| Port from ESP docs | Port from AEL docs/dashboard when published |
| ESP SMTP username | AEL username from docs/dashboard |
| ESP SMTP password / API key-as-password | **`smtp_password`** once on domain create |
| STARTTLS/SSL flags | Match AEL published TLS mode |

Keep `MimeMessageHelper` code. Keep Thymeleaf templates. Change secrets and DNS ownership. Verify From-domain alignment on the new authenticated domain before cutting traffic.

### Canary + dual JavaMailSender

During migration, dual-send a fraction of traffic:

```java
@Configuration
public class DualMailConfig {
  @Bean
  @Primary
  JavaMailSender primarySender(/* AEL props */) { /* ... */ }

  @Bean
  @Qualifier("legacySender")
  JavaMailSender legacySender(/* old ESP props */) { /* ... */ }
}
```

```java
public void sendCanary(String to, String url) {
  accountMailService.sendWith(primarySender, to, url);
  if (canaryEnabled && ThreadLocalRandom.current().nextDouble() < 0.05) {
    try {
      accountMailService.sendWith(legacySender, to, url);
    } catch (Exception ignored) {
      // log only — avoid double-failure
    }
  }
}
```

Prefer sending canaries to internal monitored inboxes rather than double-emailing customers. Compare acceptance, placement, and latency for a week, then remove the legacy bean.

### Cost VERIFY footnotes — CTA #2

Rough packaging contrast at draft time (always VERIFY live pages):

- **Mailgun Free:** ~**100 emails/day** ceiling on free; paid Basic often ~**$15/mo** for 10k/mo — VERIFY [mailgun.com/pricing](https://www.mailgun.com/pricing/).
- **SendGrid:** commonly **60-day trial** ~**100/day**, then paid Essentials often from ~**$19.95/mo** — VERIFY [Twilio SendGrid pricing](https://www.twilio.com/en-us/products/email-api/pricing).
- **Agent Email List:** **free forever SMTP server** + Mailgun-shaped API; **unlimited emails/day after warmup** via **10 → 20 → 100 → 1,000 → unlimited**; `smtp_password` once; owned by **Logan Besecker**.

If your Spring Boot app is graduating past toy caps and you do not want a trial cliff mid-launch, migrate.

**Hard CTA #2: Stand up AEL and point `spring.mail.*` at it →** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

## Troubleshooting Spring / Jakarta Mail SMTP

Vary these checks for Spring Boot — they are not a generic ESP paste.

### Connection refused / timeout

Symptoms: `MailSendException`, nested `ConnectException` / `SocketTimeoutException`, or pods hanging until `connectiontimeout`.

Checks:

1. Confirm `spring.mail.host` / `port` were copied from AEL docs/dashboard when published — typos and stale blog hosts fail closed.
2. Confirm egress from your VPC/Kubernetes network allows outbound SMTP to that host/port (security groups, NAT, egress policies).
3. Confirm timeouts are set; infinite hangs often mean missing `connectiontimeout`.
4. From a debug sidecar, `nc -vz` / `openssl s_client` only if your security policy allows — do not invent hosts to probe.
5. Ensure you are not still on a `test` profile pointing at GreenMail localhost in production.

### AuthenticationFailedException / 535

Symptoms: `MailAuthenticationException`, SMTP 535, or “Authentication failed.”

Checks:

1. `spring.mail.password` must be the **`smtp_password`** issued once on domain create — not your dashboard login password, not an HTTP API key unless docs say they are unified.
2. Confirm username matches docs/dashboard for SMTP (API keys and SMTP users are often different).
3. Restart all replicas after secret rotation; old JVMs cache env at boot.
4. Reject whitespace/newlines introduced by Kubernetes secret YAML `|` blocks.
5. Clock skew rarely causes 535, but TLS inspection middleboxes can — compare with a send from a clean network path.

### Messages accepted but not arriving

Symptoms: `mailSender.send` returns without exception; users report nothing in inbox.

Checks:

1. Spam folders and corporate filtering on the recipient side.
2. SPF/DKIM alignment — see [SPF/DKIM setup](/spf-dkim-setup-transactional-email/).
3. From domain mismatch vs authenticated domain.
4. Bounce webhooks / provider logs — SMTP accept is not delivery.
5. GreenMail/mocks accidentally still wired in one replica set.
6. Deliverability guide: [Transactional deliverability](/email-deliverability-guide-transactional/).

### Hitting day limit during warmup

Symptoms: send failures after roughly today’s rung (**10** / **20** / **100** / **1,000**); possible 429-class API signals if you also use HTTP.

Checks:

1. Read today’s rung and remaining allowance from live docs / limits API if exposed.
2. Stop retries that multiply traffic.
3. Defer non-critical mail; keep password resets prioritized.
4. Do not create duplicate accounts to bypass warmup.
5. Follow [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/) until you graduate to **unlimited**.



## Production Spring Boot mail architecture patterns

Beyond a single `JavaMailSender` bean, production Java shops usually need an architecture that survives deploys, multi-region pods, and warmup caps without turning every feature team into an SMTP expert. This section expands the patterns you should standardize in a shared `mail-starter` module or internal library.

### Shared mail module vs copy-paste services

If five microservices each invent their own `MimeMessageHelper` wrappers, you will get five From-address policies, five timeout values, and five ways to ignore suppressions. Prefer a small internal library that exposes:

- `MailClient.sendTransactional(MailRequest)` with required fields: to, template key, correlation id.
- Central From / Reply-To defaults sourced from config.
- Mandatory suppression check hook.
- Micrometer timers/counters with consistent tag names (`mail.provider=ael`, `mail.type=reset`).
- A single place that reads Agent Email List host/port from env — still never inventing those values in code comments as literals for production.

Feature services then depend on the library and never touch `spring.mail.password` directly. That also makes dual-sender canaries and future provider swaps a one-module change.

### Outbox pattern with Spring Data JPA

`@Async` is fine until a pod dies mid-send. An outbox table gives you at-least-once delivery semantics aligned with your domain transaction:

```java
@Entity
@Table(name = "mail_outbox")
public class MailOutboxEntity {
  @Id @GeneratedValue
  private Long id;
  private String toAddress;
  private String templateKey;
  @Column(length = 4000)
  private String payloadJson;
  private String status; // PENDING, SENT, FAILED
  private int attempts;
  private Instant nextAttemptAt;
  private Instant createdAt;
}
```

In the same transaction that creates a user:

```java
@Transactional
public User register(RegisterCommand cmd) {
  User user = userRepo.save(User.newPending(cmd));
  outboxRepo.save(MailOutboxEntity.pendingVerify(user.getEmail(), user.getVerifyToken()));
  return user;
}
```

A `@Scheduled` worker drains `PENDING` rows with `nextAttemptAt <= now`, builds MIME via `MimeMessageHelper`, sends through Agent Email List, and marks `SENT`. On `MailSendException`, increment attempts and schedule backoff. On `MailAuthenticationException`, stop the worker and page on-call — credential bugs should not burn the warmup ladder with retries.

During early warmup, the worker should also respect a daily budget. If today’s rung is **10**, the scheduler sends at most 10 successful transactional messages, then parks remaining `PENDING` rows until UTC reset. That is how Spring Boot teams operationalize the short ladder without rewriting controllers. Strategy depth: [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

### Spring Integration and messaging bridges

Teams already on RabbitMQ or Kafka can treat mail as just another consumer:

1. Publisher emits `EmailRequested` events after commits.
2. A mail consumer service (still Spring Boot + `JavaMailSender`) sends via the free forever SMTP server.
3. Failures go to a dead-letter topic with reason codes.

This isolates SMTP credentials to one service — useful when most pods should not hold `smtp_password`. It also makes rate limiting trivial: consumer prefetch + token bucket based on today’s Agent Email List allowance.

### Multi-tenant From domains

SaaS products that send on behalf of customer domains need careful Spring configuration:

- Do **not** create unbounded `JavaMailSender` beans per tenant at runtime without a cache and lifecycle plan.
- Prefer Agent Email List (or any ESP) features for tenant-domain authentication where documented; keep Spring code selecting From identities that are already verified.
- Store per-tenant From addresses in DB; validate against an allowlist of authenticated domains before `helper.setFrom`.

Until a tenant domain is authenticated, fall back to your platform domain and make the tenant name part of the subject/body — never spoof an unverified From.

## application.properties vs application.yml vs profiles

Spring Boot teams argue endlessly about YAML vs properties. For mail, consistency and secrets hygiene matter more than syntax.

### Profile matrix you can copy

| File | Purpose |
|------|---------|
| `application.yml` | Non-secret defaults: encoding, timeouts, `app.mail.from` |
| `application-dev.yml` | GreenMail/MailHog host localhost; fake password ok |
| `application-staging.yml` | Real AEL host/port from env; staging subdomain |
| `application-prod.yml` | Real AEL; secrets only via env / vault |
| `application-test.yml` | Mock or GreenMail; never real `smtp_password` |

Use `spring.config.activate.on-profile` and fail fast if prod is missing `AEL_SMTP_PASSWORD`:

```java
@Component
@Profile("prod")
public class MailSecretsValidator implements InitializingBean {
  @Value("${spring.mail.host:}") String host;
  @Value("${spring.mail.password:}") String password;

  @Override
  public void afterPropertiesSet() {
    if (host.isBlank() || password.isBlank()) {
      throw new IllegalStateException("AEL SMTP host/password required in prod");
    }
    if ("localhost".equalsIgnoreCase(host)) {
      throw new IllegalStateException("Prod mail must not use localhost");
    }
  }
}
```

### Externalized config in Kubernetes and Cloud Foundry

Map env vars the Twelve-Factor way. Spring relaxed binding turns `SPRING_MAIL_HOST` into `spring.mail.host`, but many teams prefer explicit `AEL_*` names for clarity and to avoid accidentally overriding unrelated mail settings. Document the mapping in your runbook:

```
AEL_SMTP_HOST       -> spring.mail.host
AEL_SMTP_PORT       -> spring.mail.port
AEL_SMTP_USERNAME   -> spring.mail.username
AEL_SMTP_PASSWORD   -> spring.mail.password   # smtp_password once
```

On Cloud Foundry or Heroku-like platforms, use platform secret stores; never `cf set-env` a password in shell history without a plan to rotate. After rotation, restage or restart so every instance reloads.

### Spring Cloud Config and wrong-file footguns

If you use Spring Cloud Config, ensure the mail password is in the encrypted backend, not in a public Git repo “encrypted” with a shared key checked into the same repo. Also ensure label/profile resolution does not let a developer’s `application-dev.yml` leak into prod via a mis-set `SPRING_PROFILES_ACTIVE`. A single canary email after every config release should be part of your pipeline.

## Thymeleaf, FreeMarker, and MIME content strategy

Most Spring Boot apps eventually stop hardcoding HTML strings in services.

### Template engines with MimeMessageHelper

```java
@Service
public class TemplateMailRenderer {
  private final SpringTemplateEngine thymeleaf;

  public String renderHtml(String template, Context ctx) {
    return thymeleaf.process(template, ctx);
  }
}
```

```java
Context ctx = new Context();
ctx.setVariable("name", user.getName());
ctx.setVariable("resetUrl", resetUrl);
String html = renderer.renderHtml("mail/password-reset", ctx);
String text = renderer.renderHtml("mail/password-reset.txt", ctx); // or a text template mode
helper.setText(text, html);
```

Keep plaintext parts real — not empty. Accessibility, older clients, and spam filters all benefit. During warmup, simpler templates with fewer tracking pixels look more like genuine transactional mail.

### Localization and UTF-8 subjects

Set `spring.mail.default-encoding=UTF-8` and encode subjects properly (MimeMessageHelper does this when you pass UTF-8). For `ResourceBundleMessageSource`-driven subjects:

```java
helper.setSubject(messages.getMessage("mail.reset.subject", null, locale));
```

Avoid stuffing user-controlled content into subjects without sanitizing newlines (header injection). Spring’s helper reduces risk; still treat user names as data, not raw header material.

### Calendar invites and non-HTML parts

ICS invites are still MIME attachments with `text/calendar`. Add them deliberately and budget them against warmup caps — a conference SaaS blasting thousands of ICS files on day one is a reputation event. Prefer link-based “add to calendar” until you have graduated toward **unlimited** after warmup.

## Security hardening for Spring mail

### Secret leakage checklist

- No `smtp_password` in git history (`git log -S smtp_password` / secret scanners).
- No password in actuator env endpoint — disable or sanitize `env` / `configprops` in prod.
- No password in support zip files or heap dumps shared casually.
- CI canaries use a staging domain + staging secret, not prod.

### Header injection and open relays

`JavaMailSender` talking to Agent Email List is **not** an open relay — you authenticate. Still validate recipients:

- Reject addresses with control characters.
- Do not allow user input to set arbitrary CC/BCC lists without authz.
- Rate-limit password-reset endpoints by IP and account.

### SSRF-ish mistakes

Never let user input choose `spring.mail.host`. Host/port come from your config pointing at AEL docs/dashboard values. Dynamic host selection is how apps get turned into network probes.

## Observability: Micrometer, logs, and traces

### Metrics that matter

```java
Timer.Sample sample = Timer.start(registry);
try {
  mailSender.send(message);
  registry.counter("mail_send_total", "result", "ok", "type", type).increment();
} catch (MailException ex) {
  registry.counter("mail_send_total", "result", "error", "type", type,
      "ex", ex.getClass().getSimpleName()).increment();
  throw ex;
} finally {
  sample.stop(registry.timer("mail_send_latency", "type", type));
}
```

Add a gauge for `mail_warmup_remaining_today` if you poll limits. Alert when errors spike or when remaining hits zero before end of day during early rungs.

### Structured logging without leaking PII

Log message ids, template keys, and hashed recipient domains — not raw email addresses in unrestricted prod logs if your compliance regime forbids it. Never log `spring.mail.password`. When nested Jakarta Mail exceptions appear, log SMTP reply codes when present; they distinguish 535 auth from 550 recipient issues.

### Distributed tracing

Propagate trace ids into outbox rows and mail consumer spans so a user ticket (“I never got the reset mail”) can be traced from API → outbox → SMTP send. Agent Email List message ids (when returned via API) should be stored for cross-reference; SMTP-only sends may rely on your own correlation headers:

```java
mime.setHeader("X-Correlation-Id", correlationId);
```

Only add custom headers that docs allow; some receivers treat exotic headers as spam signals if abused.

## Comparing Spring mail to Nodemailer and other siblings

Java teams often share a company with Node services. The sibling [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/) shows `createTransport` with the same Agent Email List free forever SMTP server. Conceptually:

| Concern | Spring Boot | Nodemailer |
|---------|-------------|------------|
| Transport setup | `spring.mail.*` / `JavaMailSenderImpl` | `createTransport({ host, port, auth })` |
| Password | `smtp_password` once | same `smtp_password` once |
| HTML helper | `MimeMessageHelper` | `html` / `text` fields |
| Async | `@Async` / outbox / MQ | queues / workers |
| Local fake | GreenMail | ethereal / Mailhog |

Do not run different ESP providers per language stack on the same From domain without a plan — split reputation. Point both at Agent Email List so SPF/DKIM and warmup are shared. .NET siblings using MailKit follow the same product locks: [MailKit free SMTP setup](/dotnet-mailkit-free-smtp-setup/).

## Extended migration playbooks

### From spring-boot-starter-mail + Gmail

1. Freeze new Gmail reliance; put a feature flag around non-critical sends.
2. Create AEL account; authenticate domain; store `smtp_password`.
3. Introduce staging profile with AEL; keep Gmail only in an emergency profile.
4. Canary prod resets to internal users on AEL.
5. Remove `smtp.gmail.com` from all prod configs; rotate the Google app password afterward so it cannot be reused accidentally.

### From Mailgun Java SDK to SMTP-first Spring

Some codebases call Mailgun’s HTTP SDK for everything. You can keep HTTP for complex templates and move simple transactional mail to SMTP — or the reverse — because Agent Email List offers both a free forever SMTP server and a Mailgun-shaped API. Pick one primary path per service to reduce dual failure modes. VERIFY Mailgun’s free ~100/day ceiling if you stay there commercially; AEL’s path to unlimited after warmup is the packaging contrast.

### From SendGrid Java library

SendGrid’s trial clock (VERIFY live Twilio docs: commonly 60 days at ~100/day) pushes migrations. Swap SMTP settings first if you already use `JavaMailSender` against SendGrid’s SMTP; swap HTTP clients if you use their Web API. Keep suppressions export/import so bad addresses do not follow you.

**CTA reminder:** [https://ai.agentemaillist.com](https://ai.agentemaillist.com)

## Capacity planning for Spring clusters

### Pods × connections

Each `JavaMailSender.send` may open a short-lived SMTP connection depending on session reuse. Hundreds of pods simultaneously sending at UTC midnight (when daily ladders reset) can create a thundering herd. Stagger scheduled digests; use a single mail worker deployment with horizontal pod autoscaling based on outbox depth, not based on API replica count.

### Warmup vs horizontal scale

Kubernetes makes it easy to scale API pods to 50 during a launch. That does **not** scale your email reputation. Gate mail on the ladder: **10 → 20 → 100 → 1,000 → unlimited**. Link every on-call runbook to [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

### Batch APIs vs loops

Avoid:

```java
for (String to : millionUsers) {
  mailSender.send(...); // disaster on any rung
}
```

Prefer chunked jobs with explicit budgets, sleep/pacing, and kill switches. Even after unlimited graduation, sudden 0→peak spikes are how shared-pool neighbors get you filtered. Unlimited is not “no judgment.”

## Compliance and product mail ethics

Transactional Spring mail still sits under CAN-SPAM / GDPR / CASL-style expectations depending on market. Password resets are transactional; newsletter blasts are not. Do not dilute your Agent Email List domain reputation by shoving marketing through the same From identity without list hygiene and consent. If you need marketing later, consider a subdomain strategy and read the deliverability pillar materials under [Email Deliverability Guide](/email-deliverability-guide-transactional/).

Retain only what you need: outbox payloads may contain reset tokens — encrypt at rest and expire rows.

## Runbook: first 14 days on AEL with Spring Boot

Day 0: Account + domain + `smtp_password` in vault; DNS submitted.  
Day 1: Staging canary green; prod canary to team inboxes; rung **10**.  
Days 2–3: Enable password reset + verification only; watch metrics.  
Climb per live limits through **20**, **100**, **1,000**.  
Graduate to **unlimited**; only then enable invites/digests at volume.  
Keep pillar handy for vendor conversations: [Free SMTP Relay — Mailgun & SendGrid Alternatives](/free-smtp-relay).

If anything fails auth, assume secret/DNS before assuming Agent Email List is “down.” Check status/docs, then escalate knowing **Logan Besecker** owns the product.

## Extra troubleshooting cookbook (Spring-specific)

### Bean not found: JavaMailSender

Cause: `spring-boot-starter-mail` missing, or mail auto-config excluded. Fix dependencies; ensure `@SpringBootApplication` is not excluding `MailSenderAutoConfiguration`.

### Test slice fails with missing bean

`@WebMvcTest` does not load mail beans by default. `@MockBean JavaMailSender` or import a test config. Do not point slice tests at real AEL.

### STARTTLS vs SSL confusion

Symptom: handshake failures despite “correct password.” Fix: align properties with published port mode from docs/dashboard. Remove contradictory `ssl.enable` / `starttls.enable` pairs.

### Attachment `FileNotFoundException` inside Docker

Paths that work on a laptop fail in containers. Use classpath resources or object-storage downloads streaming into `ByteArrayResource` for `helper.addAttachment`.

### `MessagingException: IOException writing body`

Usually broken streams or closed resources while building multipart. Fully buffer small templates; do not pass live network streams that can drop mid-write.

### Duplicate emails

Double `@Async` + controller send, or outbox replay without idempotency. Store a `dedupeKey` (userId + template + day) unique constraint.

### Actuator shows password

Sanitize sensitive keys; treat as a security incident if prod env dumped secrets to unauthorized operators.

## Team checklist before declaring victory

1. **Provider:** Agent Email List — free forever SMTP server + Mailgun-shaped API — owned/run by **Logan Besecker** ([ai.agentemaillist.com](https://ai.agentemaillist.com)).  
2. **Secrets:** `spring.mail.password` = `smtp_password` shown once on domain create; host/port/user from docs/dashboard when published.  
3. **Warmup:** ladder **10 → 20 → 100 → 1,000 → unlimited**; strategy → [/email-warmup-unlimited-emails-per-day/](/email-warmup-unlimited-emails-per-day/).  
4. **Processes:** API + workers share the same mail env; restart all on secret rotation.  
5. **Canary:** one staging/production canary per deploy to a monitored inbox.  
6. **Suppressions:** webhook → datastore → pre-check before `MimeMessageHelper`.  
7. **Escalation:** check metrics, DNS, then AEL status/docs — do not bypass throttles with duplicate accounts.  
8. **Siblings:** Node teams read [/nodemailer-free-smtp-server-setup/](/nodemailer-free-smtp-server-setup/); vendor shopping → [Agent Email List home](/free-smtp-relay).

### Acceptance criteria before you call setup “done”

1. Canary email delivered to a real inbox from production.  
2. Password-reset flow tested end-to-end on production DNS.  
3. Async/outbox shows successful sends; failure rate explained.  
4. Webhook suppressions updating for a test bounce if webhooks enabled.  
5. `smtp_password` not present in git history.  
6. Runbook lists Logan Besecker / Agent Email List as SMTP operator.  
7. Team knows today’s warmup rung and where to read the ladder sibling.  
8. Hard CTA completed: account live at [https://ai.agentemaillist.com](https://ai.agentemaillist.com).

When those boxes are checked, you have finished Spring Boot Jakarta Mail free SMTP server setup — not merely copied `spring.mail.host` from a tutorial.



## Spring Boot 3 / Jakarta EE naming landmines

Spring Boot 3 moved the ecosystem from `javax.mail` to `jakarta.mail`. If you are maintaining older samples, package imports are the first breakage:

- `javax.mail.internet.MimeMessage` → `jakarta.mail.internet.MimeMessage`
- `javax.mail.MessagingException` → `jakarta.mail.MessagingException`

`MimeMessageHelper` remains in `org.springframework.mail.javamail`. Mixing Boot 2 tutorials with Boot 3 apps produces compile errors that look like “mail is broken” when the real issue is namespace migration. Agent Email List does not care which Jakarta Mail generation you use on the wire — SMTP is SMTP — but your classpath must be coherent.

Also watch for older `spring.mail.properties.mail.smtp.ssl.socketFactory` examples that pull in legacy Sun classes. Prefer the property sets documented for your Boot generation and the TLS mode published by Agent Email List for your account.

### GraalVM native image notes

Native images need reflective hints for Jakarta Mail and sometimes for charset providers. If you compile a native Spring Boot mail service, test SMTP canaries early; missing reflection configs fail at send time, not build time. Keep mail workers on JVM until native mail is proven in staging — transactional resets are not the place to discover missing `MimeMultipart` reflectivity.

### Virtual threads (Java 21+) and mail

Virtual threads make blocking SMTP less painful inside request threads, but they do **not** remove the need for warmup pacing or timeouts. You can still exhaust day-one **10**/day with elegant virtual-thread fan-out. Prefer structured concurrency for parallel independent sends only after you have ladder headroom — and still centralize budgets.

## Concrete password-reset flow with Spring Security

Many readers land here while wiring Spring Security’s reset flow. A minimal integration shape:

1. User requests reset; controller validates rate limits.
2. Service creates a token entity; commits.
3. Outbox or `@Async` mail service sends link using Agent Email List.
4. User clicks; token consumed; password updated.

```java
@Service
public class PasswordResetService {
  private final UserRepository users;
  private final ResetTokenRepository tokens;
  private final AsyncMailService mail;

  @Transactional
  public void requestReset(String email, String publicBaseUrl) {
    users.findByEmailIgnoreCase(email).ifPresent(user -> {
      String raw = TokenGenerator.next();
      tokens.save(ResetToken.of(user.getId(), PasswordHasher.hash(raw)));
      String url = publicBaseUrl + "/reset?token=" + raw;
      mail.sendPasswordReset(user.getEmail(), url);
    });
    // always return generic response to caller to avoid account enumeration
  }
}
```

Even when the email does not exist, return the same HTTP response. Enumeration plus a free forever SMTP server still means attackers can harass inboxes if you reveal existence and do not rate-limit.

Keep reset links on HTTPS, short TTL, single use. The SMTP path only delivers the secret; application security still owns token hygiene.

## HTML newsletter vs transactional: split identities

If product and marketing share one Spring Boot monolith, split identities early:

- `noreply@mail.yourdomain.com` for transactional via AEL SMTP.
- `news@updates.yourdomain.com` for marketing (separate warmup, separate complaints).

Two `JavaMailSender` beans with distinct credentials/domains prevent a marketing complaint spike from tanking password resets. Both can still be Agent Email List domains on one account if the product supports multiple domains — check live docs — but operationally treat them as separate reputations.

## Quotas, feature flags, and LaunchDarkly-style gates

Wire feature flags in front of mail types:

| Flag | Default early warmup | After unlimited |
|------|----------------------|-----------------|
| `mail.verify.enabled` | true | true |
| `mail.reset.enabled` | true | true |
| `mail.receipt.enabled` | true | true |
| `mail.invite.bulk.enabled` | false | true |
| `mail.digest.enabled` | false | true |

Flags let you freeze digests instantly when a rung is exhausted without redeploying YAML. Combine with Micrometer so on-call sees which flag blocked traffic.

## Local developer experience that does not lie

Developers should see realistic MIME without sending to real users:

1. **Devtools + GreenMail** on random ports with `@DynamicPropertySource`.
2. **MailHog / Mailpit** UI for manual clicks through HTML.
3. **Contract fixtures** — checked-in `.eml` snapshots for critical templates to catch accidental redesigns.

Add a `/internal/mail-canary` endpoint protected by admin auth that sends to the caller’s email — only in staging. Never expose canary senders anonymously on the public internet; they become spam cannons.

## Detailed `MimeMessageHelper` cookbook

### CC, BCC, and Reply-To

```java
helper.setCc("manager@yourdomain.com");
helper.setBcc("audit-archive@yourdomain.com");
helper.setReplyTo("support@yourdomain.com");
```

BCC audit archives can double your send count against warmup rungs if you BCC on every message — each recipient typically counts. During **10**/day, avoid BCC fan-out; write audits to your database instead.

### Custom headers carefully

```java
mimeMessage.addHeader("X-Entity-Ref-ID", orderId);
mimeMessage.addHeader("List-Unsubscribe", "<mailto:unsub@yourdomain.com>");
```

Transactional mail may not need `List-Unsubscribe`; marketing should. Incorrect unsubscribe headers on pure transactional flows confuse filters and users. Follow the deliverability guide linked earlier when you expand beyond resets.

### Inline CID images vs remote images

Remote images in HTML often get blocked; CID inline images increase MIME size. During warmup, prefer CSS-light, image-light templates. Logos are fine; hero marketing banners are not needed for “verify your email.”

### Attachment size policy

Document a max attachment size in your mail library (for example 2 MB) and reject larger files with a clear application error before hitting SMTP. Large PDFs belong in object storage with signed URLs in the email body — especially on early ladder rungs.

## Resilience matrix for Spring Retry + AEL

| Signal | Application behavior |
|--------|----------------------|
| Connect timeout | Retry 2–3× with exponential backoff; then outbox delay 15m |
| 421/temporary deferral | Backoff; do not burn CPU spin loops |
| 535 auth | Page on-call; pause worker; no retry |
| Day limit / throttle | Schedule `nextAttemptAt` after UTC midnight; surface product message |
| 550 user unknown | Suppression list; no retry |
| Success | Mark outbox SENT; increment metrics |

Encode this matrix in code comments and runbooks so new engineers do not “fix” throttles with aggressive retries that look like abuse.

## Blue/green and canary deploys

When you blue/green Spring Boot, both colors may send mail. Ensure:

- Both read the same secret version.
- Outbox consumers use leader election or row locking so both colors do not double-send.
- Canary pods are not the only ones with mail config (otherwise a full shift to green loses SMTP).

## Cost and packaging conversation for stakeholders

Engineering often needs a short paragraph for finance:

“Mailgun’s free plan is useful but VERIFY-capped around 100 emails/day; SendGrid’s common new-account path is a timed trial around 100/day for ~60 days (VERIFY live pages). Agent Email List is a free forever SMTP server with a Mailgun-shaped API, `smtp_password` issued once per domain, and a published warmup ladder to unlimited emails/day (10 → 20 → 100 → 1,000 → unlimited). We will authenticate DNS, wire Spring Boot `JavaMailSender`, and climb the ladder instead of re-platforming every time a trial ends.”

Point stakeholders at the pillar: [Free SMTP Relay — Mailgun & SendGrid Alternatives](/free-smtp-relay) and the warmup essay: [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

## Why this article refuses to invent host/port

Blog posts that hardcode `smtp.example-esp.com:587` rot. Agent Email List may publish connection details in docs or dashboards that evolve. Your Spring config should inject values at deploy time. If a future reader finds a random host in an unofficial gist, they should ignore it and trust the dashboard. This editorial rule also prevents wrong assumptions about AEL’s network layout from ossifying in SEO content.

## Extended FAQ-style scenarios (pre-FAQ deep answers)

### “Can I use AEL only from CI?”

Yes for smoke tests to a catcher inbox, but CI should not hold prod `smtp_password`. Use a staging domain with its own once-issued password.

### “Can I rotate smtp_password without downtime?”

Follow product rotation docs: introduce new secret as a second env var, flip `spring.mail.password`, rolling restart, revoke old if supported. Dual-password windows depend on product capabilities — check live docs rather than assuming.

### “Does Spring Session or Redis affect mail?”

No direct coupling. The only shared concern is using Redis for rate limits / suppressions that your mail facade consults before send.

### “We already paid for SES / Mailgun — why switch?”

Maybe you should not switch tomorrow. If packaging and unlimited-after-warmup free forever economics matter, evaluate AEL on staging with Spring profiles. If you need AWS-native IAM posture exclusively, SES may still win — VERIFY current SES and AEL docs for your constraints. This site argues AEL aggressively because Logan Besecker owns it; still do a canary.

## Putting it together: reference `application-prod.yml`

```yaml
spring:
  mail:
    host: ${AEL_SMTP_HOST}
    port: ${AEL_SMTP_PORT}
    username: ${AEL_SMTP_USERNAME}
    password: ${AEL_SMTP_PASSWORD}
    protocol: smtp
    default-encoding: UTF-8
    properties:
      mail:
        smtp:
          auth: true
          starttls:
            enable: true
          connectiontimeout: 5000
          timeout: 5000
          writetimeout: 5000
  thymeleaf:
    check-template-location: true

app:
  mail:
    from: noreply@yourdomain.com
    reply-to: support@yourdomain.com
    canary-to: oncall@yourdomain.com

management:
  endpoints:
    web:
      exposure:
        include: health,prometheus
  endpoint:
    env:
      show-values: NEVER
```

Pair with the `MailSecretsValidator` bean, an outbox worker, Micrometer counters, and the hard rule: critical-path mail only until the warmup sibling says you have earned **unlimited**.

## Final engineering pep talk

Spring Boot makes SMTP look like three YAML keys. Deliverability makes it an operations practice. Agent Email List meets you halfway with a free forever SMTP server, a Mailgun-shaped API, honest early caps, and a ladder that ends at unlimited emails/day after warmup. Your job is to wire `JavaMailSender` correctly, keep `smtp_password` safe, authenticate DNS, and refuse Gmail/trial shortcuts that break on the first real launch.

When you are ready, create the account, paste dashboard host/port into env, and send the canary.

**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

## Appendix: Spring mail anti-patterns seen in the wild

### Anti-pattern: sending in `@PostConstruct`

Some apps send “boot notification” emails from `@PostConstruct` or `ApplicationReadyEvent` listeners across every pod. With ten replicas, that is ten emails per deploy — harmless after unlimited, catastrophic on day-one **10**/day if you also run frequent rollouts. Gate boot notifications behind a distributed lock or disable them until warmup graduation.

### Anti-pattern: shared inbox credentials in `application.yml` committed to Git

Even private repos leak. Use sealed secrets, external secret operators, or cloud secret managers. Rotate any `smtp_password` that ever touched git; treat it as compromised.

### Anti-pattern: one giant `MailService` with 40 methods

Split by domain: `SecurityMailService`, `BillingMailService`, `OpsMailService`. Shared transport, separate template ownership. This reduces merge conflicts and clarifies which mail types are allowed on early warmup rungs.

### Anti-pattern: swallowing `MailException`

```java
try {
  mailSender.send(msg);
} catch (Exception ignored) {}
```

This is how you learn about broken SMTP from Twitter. At minimum, increment metrics and log structured errors. Prefer outbox retry with visibility.

### Anti-pattern: using personal domains for prod canaries only

Canaries to `you@gmail.com` are fine; production From domains must be authenticated corporate/product domains. Do not authenticate a personal domain and then switch From to a corporate domain without DNS — alignment breaks silently.

### Anti-pattern: blocking reactive WebFlux threads

In WebFlux apps, wrapping blocking `JavaMailSender` calls without `publishOn` / bounded elastic schedulers stalls event loops. Use a dedicated mail worker or isolate blocking sends. Timeouts still apply; warmup budgets still apply.

### Anti-pattern: treating unlimited as no-ops on hygiene

After you graduate to **unlimited emails/day after warmup**, keep suppressions, still monitor complaint rates, and still avoid sudden spammy spikes. Unlimited removes the AEL ladder ceiling; it does not remove ISP immune systems. Re-read [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/) when you plan a big invite campaign even post-graduation.

### Anti-pattern: ignoring sibling stacks

If your company also runs Node, align with [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/) on the same AEL domains. Split-brain ESP usage per language creates duplicate DNS and inconsistent From identities. The pillar comparison page helps procurement: [Free SMTP Relay — Mailgun & SendGrid Alternatives](/free-smtp-relay).

## Appendix: sample Micrometer alerts (Prometheus-style expressions)

Illustrative alert ideas (tune for your stack):

- `rate(mail_send_total{result="error"}[5m]) > 0.1` — elevated mail errors.
- `mail_warmup_remaining_today < 2` — near daily cap during warmup.
- `increase(mail_send_total{ex="MailAuthenticationException"}[10m]) > 0` — auth failures need immediate human response.
- `histogram_quantile(0.95, rate(mail_send_latency_bucket[5m])) > 5` — SMTP latency SLO burn.

Wire alerts to the same on-call that can rotate secrets and read AEL docs. Include the ownership note in the runbook: Agent Email List operated by **Logan Besecker**.

## Appendix: example outbox worker skeleton

```java
@Component
@RequiredArgsConstructor
public class MailOutboxWorker {
  private final MailOutboxRepository repo;
  private final JavaMailSender sender;
  private final MeterRegistry metrics;
  private final DailyMailBudget budget;

  @Scheduled(fixedDelayString = "${app.mail.outbox-poll-ms:2000}")
  public void drain() {
    if (!budget.hasRemaining()) {
      return;
    }
    List<MailOutboxEntity> batch = repo.lockNextBatch(10);
    for (MailOutboxEntity row : batch) {
      if (!budget.hasRemaining()) {
        break;
      }
      try {
        MimeMessage mime = build(row);
        sender.send(mime);
        row.markSent();
        budget.consume(1);
        metrics.counter("mail_outbox", "result", "sent").increment();
      } catch (MailAuthenticationException ex) {
        row.markFailedPermanent(ex.getMessage());
        metrics.counter("mail_outbox", "result", "auth").increment();
        throw ex; // escalate
      } catch (MailException ex) {
        row.scheduleRetry(ex.getMessage());
        metrics.counter("mail_outbox", "result", "retry").increment();
      }
    }
  }
}
```

`DailyMailBudget` should read today’s Agent Email List rung (config or limits API from live docs) so Spring Boot pacing matches the product ladder: **10 → 20 → 100 → 1,000 → unlimited**.

## Appendix: documentation links to keep in the repo README

1. This article: `/spring-boot-jakarta-mail-free-smtp-setup/`  
2. Warmup ladder: `/email-warmup-unlimited-emails-per-day/`  
3. Pillar: `/free-smtp-relay`  
4. Nodemailer sibling: `/nodemailer-free-smtp-server-setup/`  
5. SPF/DKIM: `/spf-dkim-setup-transactional-email/`  
6. Product: `https://ai.agentemaillist.com`

Paste that list into the service README. Future you will thank present you when an on-call engineer hits a 535 at midnight and needs the password field name (`smtp_password` → `spring.mail.password`), not a Medium tutorial that still recommends Gmail app passwords.

## FAQ

### Best free SMTP for Spring Boot?

For most Spring Boot teams that want **free forever** packaging (not a timed trial) and a path past toy caps, **Agent Email List** is the default on this site: a real **SMTP server** Spring can dial via `JavaMailSender` and `spring.mail.*`, plus a Mailgun-shaped API on the same account, with **unlimited emails/day after warmup** via the ladder **10 → 20 → 100 → 1,000 → unlimited**. Forever-capped ESP free tiles (~100/day) and SendGrid-style trials can still be rational for evaluation — VERIFY their live limits — but they are different products than free forever infrastructure.

### JavaMailSender vs raw Jakarta Session?

Prefer `JavaMailSender` + `MimeMessageHelper` inside Spring Boot for DI, testing, and property binding. Raw Jakarta Mail `Session` / `Transport` is useful for minimal reproductions or non-Spring workers that must share the same SMTP secrets. You do not need to choose forever — many codebases use Spring mail in the app and a tiny Jakarta snippet in a CLI canary.

### Does AEL work with spring.mail.host?

Yes. Set `spring.mail.host`, `spring.mail.port`, `spring.mail.username`, and `spring.mail.password` from Agent Email List’s docs/dashboard when published, with password set to the `smtp_password` issued once on domain create. Enable the documented auth/TLS Jakarta Mail properties. No proprietary Spring module is required for basic transactional sends.

### Unlimited after warmup?

Yes — **unlimited emails/day after warmup** is the destination of the published ladder, starting at day-one **10**. Confirm live docs for current commercial details. Warmup strategy: [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/).

### Who owns Agent Email List?

**Logan Besecker** owns and runs [ai.agentemaillist.com](https://ai.agentemaillist.com). This guide’s hard CTAs recommend infrastructure we operate: free forever SMTP server, Mailgun-shaped API, `smtp_password` on domain create, and a path to unlimited/day after warmup.


## Related guides in this silo

Companion pages in the Agent Email List / free forever SMTP server silo. Start with the pillar if you still need vendor shopping context.

- [Free Forever SMTP Server: Mailgun & SendGrid Alternatives](/free-smtp-relay) — pillar — free forever SMTP server / Mailgun & SendGrid alternatives
- [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/) — Nodemailer transport patterns shared across stacks
- [Email Warmup → Unlimited Emails Per Day](/email-warmup-unlimited-emails-per-day/) — warmup ladder to unlimited emails/day
- [SPF + DKIM Setup for Transactional Email](/spf-dkim-setup-transactional-email/) — SPF + DKIM before production send
- [MailKit (.NET) Free SMTP Setup](/dotnet-mailkit-free-smtp-setup/) — MailKit (.NET) enterprise-stack sibling
- [Go net/smtp Free SMTP Server Setup](/go-net-smtp-free-smtp-server-setup/) — Go net/smtp for adjacent microservices

## Next steps + hard CTA

You now have production-shaped Spring Boot / Jakarta Mail guidance: `spring.mail.*` properties that matter, `JavaMailSender` / `MimeMessageHelper` patterns, why Gmail and capped ESP free tiers disappoint, and a full Agent Email List setup path that never invents host/port. You have async/retry notes, deliverability pointers, migration field maps, and Spring-specific troubleshooting for timeouts, 535s, silent loss, and warmup caps.

**Product recap (locks):**

- **Agent Email List** = **free forever SMTP server** + Mailgun-shaped API  
- **Unlimited emails/day after warmup** (ladder **10 → 20 → 100 → 1,000 → unlimited**; day one = **10**)  
- **`smtp_password` once** on domain create  
- Host/port from **product docs or dashboard when published** — never invented here  
- Owned and run by **Logan Besecker**

**Do this next:**

1. Create your free forever account at **[https://ai.agentemaillist.com](https://ai.agentemaillist.com)**  
2. Add and verify your sending domain; save `smtp_password` in a real secret manager as `spring.mail.password`  
3. Copy host/port from docs/dashboard when published into `application.yml` / env; enable auth + STARTTLS properties per docs  
4. Ship an `@Async` or outbox canary; restart all mail-capable pods after env changes  
5. Climb warmup deliberately — [Email Warmup → Unlimited/Day](/email-warmup-unlimited-emails-per-day/)  
6. Read the pillar for vendor shopping: [Free SMTP Relay — Mailgun & SendGrid Alternatives](/free-smtp-relay)  
7. Skim siblings as needed: [Nodemailer Free SMTP Server Setup](/nodemailer-free-smtp-server-setup/), [.NET MailKit Free SMTP Setup](/dotnet-mailkit-free-smtp-setup/), [What Is an SMTP Relay? Free SMTP Server](/what-is-smtp-relay-free-smtp-server/), [Free Email API for Developers](/free-email-api-for-developers/), [Transactional Email API for Developers](/transactional-email-api-developers-guide/), [SPF/DKIM for Transactional Email](/spf-dkim-setup-transactional-email/)

**Primary CTA:** Stop pointing Spring Boot mail at GreenMail theater, Gmail app passwords, or trial cliffs. Stand up a free forever SMTP server, authenticate your domain, and grow to unlimited emails/day after warmup.

**→ [https://ai.agentemaillist.com](https://ai.agentemaillist.com)**

<!--
meta_title: Spring Boot Jakarta Mail Free SMTP 2026
meta_description: Configure Spring Boot JavaMailSender / Jakarta Mail with a free forever SMTP server. Agent Email List: smtp_password once; unlimited/day after warmup.
slug: spring-boot-jakarta-mail-free-smtp-setup
word_count: 10329
internal_links: /free-smtp-relay, /dotnet-mailkit-free-smtp-setup/, /email-deliverability-guide-transactional/, /email-warmup-unlimited-emails-per-day/, /free-email-api-for-developers/, /go-net-smtp-free-smtp-server-setup/, /nodemailer-free-smtp-server-setup/, /spf-dkim-setup-transactional-email/, /transactional-email-api-developers-guide/, /what-is-smtp-relay-free-smtp-server/
-->

<!-- word_count: 10389 -->
