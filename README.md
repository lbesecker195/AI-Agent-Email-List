# email_provider

An email sending and receiving service in Elixir/Phoenix: accounts, customer
domains with their own DKIM keys, a Mailgun-shaped REST API, automatic sending
warmup, and content screening on both directions of mail.

API only — no HTML, no assets.

## Running it

```bash
mix setup            # deps, database, migrations
mix phx.server       # http://localhost:4000
mix test
```

The database configuration reads the standard `PGUSER` / `PGPASSWORD` /
`PGHOST` variables and falls back to a role named after the OS user, which is
what a stock Homebrew Postgres gives you.

### Environment

| Variable | Meaning | Default |
| --- | --- | --- |
| `OPENAI_API_KEY` | Key for the moderation endpoint | none — screening is skipped |
| `MODERATION_ENABLED` | Turn screening off entirely | `true` |
| `MODERATION_ON_ERROR` | `block` to fail closed when screening is unreachable | `allow` |
| `SMTP_RELAY` | Smarthost for outbound mail | unset — mail is written to `priv/local_mail` |
| `SMTP_PORT` / `SMTP_USERNAME` / `SMTP_PASSWORD` | Smarthost credentials | `587`, none |
| `SPF_HOST` | What customers put in their SPF include | `mail.example.com` |
| `MX_HOST` | What customers point their MX at | `mx.example.com` |

Without `SMTP_RELAY` nothing reaches the internet: the local sender writes each
message to disk and logs it. That is the default on purpose.

## Accounts and keys

```bash
curl -s localhost:4000/v1/accounts \
  -d email=you@example.com -d password='a sufficiently long password'
```

The response carries an API key. It is shown once — only a SHA-256 hash is
stored, so a lost key is rotated rather than looked up. Authenticate either way:

```bash
curl -s --user 'api:ep_live_...' localhost:4000/v3/domains     # Mailgun style
curl -s -H 'Authorization: Bearer ep_live_...' localhost:4000/v3/domains
```

Keys carry scopes (`messages:send`, `events:read`, `domains:write`, …). Scopes
are declared per action in each controller, next to the code they guard.

## Custom domains

Adding a domain generates an RSA-2048 DKIM keypair. The private half stays in
the database; the public half is what the customer publishes.

```bash
curl -s --user 'api:KEY' localhost:4000/v3/domains -d name=mail.yourcompany.com
```

The response lists the records to publish, then:

```bash
curl -s -X PUT --user 'api:KEY' localhost:4000/v3/domains/mail.yourcompany.com/verify
```

A domain is `unverified` until SPF and DKIM are both observed in DNS, and it
cannot send until it is `active`. If the records later disappear it drops back
to `unverified` and stops sending. MX is reported but not required — it is only
needed to receive.

Outbound mail is signed RSA-SHA256 with relaxed/relaxed canonicalization, so a
relay that re-folds a header or trims trailing whitespace does not break the
signature.

## Sending

```bash
curl -s --user 'api:KEY' localhost:4000/v3/mail.yourcompany.com/messages \
  -F from='Ada <ada@mail.yourcompany.com>' \
  -F to=someone@elsewhere.com \
  -F subject='Hello' \
  -F text='Hello there.' \
  -F o:tag=welcome \
  -F h:X-Campaign=spring \
  -F v:customer_id=42
```

The `from` address must belong to the domain the key is sending for.

## Endpoints

### Messages
| | |
| --- | --- |
| `POST /v3/:domain/messages` | Send. Fields below. |
| `POST /v3/:domain/messages.mime` | Send a pre-built MIME document. Still screened, still counted. |
| `GET /v3/:domain/messages` | List, filterable by `folder` and `direction`. |
| `GET /v3/domains/:domain/messages/:key` | Retrieve one stored message. |

Send fields: `from`, `to`, `cc`, `bcc`, `subject`, `text`, `html`,
`o:tag`, `o:deliverytime`, `o:testmode`, `o:tracking-opens`,
`o:tracking-clicks`, `h:*` (headers to emit), `v:*` (variables that ride along
and come back on events), `recipient-variables`, `template`, `t:version`,
`t:variables`.

`o:deliverytime` takes RFC 2822 or ISO 8601 and is capped at three days out.
`o:testmode` accepts and stores a message without sending it, and without
spending warmup allowance. `recipient-variables` turns one request into one
message per recipient, each with its own body and Message-ID, substituting
`%recipient.name%`.

### Domains
`GET|POST /v3/domains` · `GET|PUT|DELETE /v3/domains/:domain` ·
`PUT /v3/domains/:domain/verify`

### Reporting
`GET /v3/:domain/events` (filter by `event`, `recipient`, `tag`, `begin`,
`limit`) · `GET /v3/:domain/stats/total` · `GET /v3/:domain/tags` ·
`GET /v3/:domain/limits` (warmup position)

### Suppressions
`GET|POST /v3/:domain/bounces` · `GET|DELETE /v3/:domain/bounces/:address`,
and the same shape for `unsubscribes` and `complaints`. Enforced on every
send; a hard bounce adds itself.

### Templates
`GET|POST /v3/:domain/templates` · `GET|DELETE /v3/:domain/templates/:name` ·
`POST /v3/:domain/templates/:name/versions`

Substitution is `{{name}}` and nothing else — no expressions, no includes, no
loops. Stored templates are attacker-controlled input in a multi-tenant
service, and the smallest engine has the smallest blast radius. An unknown
placeholder is left visible rather than blanked, so a typo shows up as
`{{frist_name}}` instead of silently vanishing.

### Routes (inbound)
`GET|POST /v3/routes` · `GET|PUT|DELETE /v3/routes/:id`

Expressions: `match_recipient("regex")`, `match_header("name", "regex")`,
`catch_all()`. Actions: `forward("https://…")`, `store()`, `stop()`. Highest
priority first, stopping at `stop()`.

### Webhooks
`GET|POST /v3/domains/:domain/webhooks` · `GET|DELETE /v3/domains/:domain/webhooks/:id`

Payloads are signed `HMAC-SHA256(timestamp <> token, signing_key)` with a
per-domain secret, so one leaked secret cannot forge another customer's
callbacks. The key is returned once, at creation.

### Address validation
`GET /v4/address/validate?address=…` — syntax plus a live MX lookup. It does
not probe the recipient's server with a partial SMTP conversation: that is what
makes validation accurate, and it is also indistinguishable from the
reconnaissance step of a directory harvest.

### Inbound
`POST /v1/inbound/:domain` — where the MTA hands us received mail, as raw
`message` or as parsed fields. `GET /v1/inbound/:domain/spam` lists what
screening filed away.

## Automatic warmup

A new domain that opens at full volume gets filtered, so every domain climbs a
ladder. Stages are configured in `config/config.exs`, not hard-coded:

| Stage | Daily cap | Graduates when |
| --- | --- | --- |
| 1 | 10 | it has sent on 5 separate days |
| 2 | 20 | 1,000 messages sent on this rung |
| 3 | 100 | a further 1,000 on this rung |
| 4 | 1,000 | a further 10,000 on this rung |
| 5 | unlimited | — |

Two things worth knowing:

**"Days of sending" means days it actually sent on**, not days since the domain
was created. A domain idle for a week has not warmed up for a week.

**Each rung's number is its own allowance, not a lifetime total.** A domain
leaves the 20/day rung after 1,000 messages at 20/day, then leaves the 100/day
rung after a *further* 1,000. Where that lands in absolute terms depends on how
hard the domain sent during its first five days: one that maxed out rung 1 has
50 messages behind it, so its rungs run 50 to 1,050 to 2,050 to 12,050, while
one that trickled reaches each rung a little sooner. `GET /v3/:domain/limits`
reports progress through the current rung, which is the number that answers
"how much longer at this cap?", alongside the absolute total it graduates at.

Use `{:lifetime_sent, n}` instead of `{:stage_volume, n}` in
`config/config.exs` for a rung that should graduate at an absolute total.

Capacity is reserved before dispatch and released if the send never happens, so
a crash between the two costs a few sends rather than letting a domain overrun.
Reservation is a single atomic upsert: two requests arriving together cannot
both read "9 sent today" and both be allowed. `GET /v3/:domain/limits` reports
the current rung, today's headroom and what graduates it; a refused send comes
back 429 with the same detail and a `retry_after_seconds`.

Warmup can be disabled per domain with `warmup_enabled`.

## Content screening

Every message is screened through OpenAI's moderation endpoint, which is free
to call. The consequence differs by direction:

- **Outbound** — flagged content is refused with a 403 before it reaches the
  wire, and before it spends any warmup allowance. The verdict is stored on the
  message so a refusal can be explained afterwards rather than being a 403 in a
  log.
- **Inbound** — flagged content is delivered but filed in `spam` rather than
  `inbox`. Dropping incoming mail outright loses real messages to false
  positives; filing it does not.

If the moderation service is unreachable the default is to allow and record the
message as unscreened, so a third-party outage does not take the service down
with it. `MODERATION_ON_ERROR=block` fails closed instead. "Unscreened" is a
distinct state from "screened and clean" — it carries no check timestamp, so
nothing downstream can mistake one for the other.

## How delivery works

The queue is the messages table rather than a separate broker. That costs a
poll every few seconds and buys one-owner semantics: a claim is an `UPDATE`
guarded by the current status, so two nodes racing for the same message cannot
both win, and a node that dies mid-send leaves a row the stale-claim sweep
returns to the queue. A 5xx fails the message permanently, suppresses the
address and refunds its warmup allowance; a 4xx is retried up to five times.

`Bcc` is put on the envelope but never written into the headers, so blind
recipients stay blind.

## Layout

```
lib/email_provider/
  accounts.ex          users, API keys, scopes
  domains.ex           registration, DKIM keys, DNS records, verification
  mail.ex              the send and receive pipeline
  warmup.ex            the ladder and its counters
  moderation.ex        OpenAI screening client
  suppressions.ex      bounces, unsubscribes, complaints
  templates.ex         stored bodies and substitution
  routes.ex            inbound matching and actions
  webhooks.ex          signed callbacks
  delivery/
    mime.ex            render RFC 5322
    dkim.ex            relaxed/relaxed RSA-SHA256 signing
    inbound.ex         parse MIME, decode RFC 2047 headers
    sender.ex          SMTP and local adapters
    queue.ex           claim and dispatch
```

## Tests

```bash
mix test
```

Nothing in the suite can reach the network: screening is off, the dispatch loop
is not running, and the sender writes to a temp directory. `config/runtime.exs`
skips its environment-driven configuration under test so a stray variable on a
developer's machine cannot point the suite at a live relay or a paid API.

## Account profiles

Every account holder gets a rolling description of about 200 words, rewritten
each time a message moves in either direction. Two inputs feed it:

- **A CSuiteFinder enrichment lookup** on the account's own address, via
  `/csuitefinder/email/enrich`. The response is cached on the profile row for
  30 days, because the provider bills per result and a job title does not
  change between two emails.
- **A digest of mail activity**: volume and direction, first and last activity,
  cadence per active day, top correspondents, recent subject lines, sending
  domains, tags, and a hard-capped excerpt of recent bodies.

```bash
curl -s --user 'api:KEY' localhost:4000/v1/profile
curl -s --user 'api:KEY' -X POST localhost:4000/v1/profile/refresh
curl -s --user 'api:KEY' localhost:4000/v1/profile/signals
```

The stored row keeps the description *and* the enrichment record and activity
digest it was written from, and the API returns all three. A description nobody
can account for is not one you can act on, correct, or defend.

### Two generators

`EmailProvider.Profiles.Generator` picks by config. With an OpenAI key it uses
a chat model, prompted to stay on the evidence: no invented employers or
titles, uncertain material attributed, and no inference about protected
characteristics. Without a key it falls back to a deterministic builder that
composes the paragraph from the facts directly, no model and no network. That
is what the test suite runs, so the tests exercise the real path rather than a
mock, and the feature works out of the box.

The deterministic generator says what the data supports and stops, so a thin
record produces a short description rather than a padded one. Only the model
adapter targets the full 200 words. Both are trimmed to 200, at a sentence
boundary where there is one.

### Cost

`min_interval_seconds` defaults to `0`, which is one rewrite per message and,
with the model adapter, one model call per message. That is what was asked for
and it is the expensive setting. Raise it in `config/config.exs` to coalesce
refreshes on busy accounts; every message is still counted, so the next rewrite
knows how much it missed.

The work runs in a task off the send path, so neither the enrichment call nor
the model can add latency to an API request or hold up a delivery. Failures are
recorded on the row and never propagated: a profile that could not be rewritten
keeps the description it had.

### Scope

`GET /v1/profile` returns the calling account's own description and nothing
else. There is no endpoint that returns somebody else's, and the enrichment
lookup is on the account holder's own address, not on the people they
correspond with.

The earlier note here said I had not built this. You confirmed you wanted it,
so it is built as specified. Two things are worth deciding deliberately rather
than by default, because they are policy rather than code: whether your terms
tell account holders that this exists, and whether they can read or switch off
what is held about them. `EmailProvider.Profiles.enabled?/0` and the
`/v1/profile` endpoint are the hooks for the second if you want it.
