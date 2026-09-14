# email_provider

An email sending and receiving service in Elixir/Phoenix: accounts, customer
domains with their own DKIM keys, a Mailgun-shaped REST API, automatic sending
warmup, and content screening on both directions of mail.

API only — no HTML, no assets.

Maintained by Logan Besecker. Questions, bug reports and cold outreach all
welcome at <me@LoganBesecker.com> or <lbesecker195@gmail.com>.

## Running it

```bash
mix setup            # deps, database, migrations
mix phx.server       # http://localhost:4005
mix test
```

It listens on **4005** by default, because 4000 through 4003 are taken on the
machines this runs alongside. `PORT` overrides it.

### Database

Set credentials once, in `.env` at the project root:

```bash
cp .env.example .env
```

Every mix command reads it, so nothing has to be retyped per command, and a
real environment variable still overrides it: `DATABASE_URL=... mix test` does
what it looks like. `.env` is gitignored; `.env.example` lists everything that
can go in it.

Without that file, `DATABASE_URL` wins if it is set, which is the form that
works everywhere:

```bash
DATABASE_URL=ecto://user:pass@localhost/email_provider_dev mix setup
```

Otherwise the standard `PGUSER`, `PGPASSWORD`, `PGHOST`, `PGPORT` and
`PGDATABASE` variables, and only then a guess at a role named after the OS
user, which is what a stock Homebrew Postgres gives you.

The guess skips the OS user when that user is `root`. On a server you are often
root, there is rarely a Postgres role called root, and the error you get back —
`password authentication failed for user "root"` — reads like a credentials
problem when really nobody has said which credentials to use. If you hit that
on a fresh box, either set `DATABASE_URL` or create the role:

```bash
sudo -u postgres psql -c "CREATE ROLE youruser LOGIN PASSWORD 'apassword' CREATEDB;"
```

On a real deployment, run the release with `MIX_ENV=prod` and `DATABASE_URL`
rather than `mix setup`, which is a development task. One command does the whole
thing, and [DEPLOY.md](DEPLOY.md) explains every step it takes:

```bash
sudo bash deploy/deploy.sh --domain ai.agentemaillist.com --email you@example.com
```

### On a machine that is running other things

`mix setup` is a developer command and it is not a good neighbour. Use this
instead:

```bash
DATABASE_URL=ecto://user:pass@localhost/email_provider_dev bin/setup-server
```

Three differences, each of which is a way `mix setup` can disturb something
else on the box.

**It caps the build.** Compiling 35 dependencies and two C NIFs fans the Elixir
compiler out to one process per scheduler and `make` to one job per core, which
on a small VPS makes the build the largest memory consumer on the machine. When
memory runs out the kernel does not kill the build; the OOM killer picks the
biggest process, which is usually a running application. The script serialises
compilation and, under systemd as root, runs it inside a scope with a hard
`MemoryMax`, so anything killed for memory is the build itself. Override with
`MEMORY_MAX=1G`.

**It opens two connections, not ten.** Postgres has a fixed `max_connections`,
and one that runs out answers *every* client with "sorry, too many clients
already", including services that were already connected. The dev pool now
defaults to 5 and reads `POOL_SIZE`; the script sets it to 2.

**It never starts the application.** `mix setup` boots the whole supervision
tree to run `priv/repo/seeds.exs`, which opens a pool and starts the delivery
queue. `mix setup.server` creates and migrates without booting anything.

If something already went offline during a `mix setup`, these say which of the
two it was:

```bash
sudo dmesg -T | grep -i -A2 'killed process'
```

```bash
sudo grep -i "too many clients" /var/log/postgresql/*.log | tail
```

### A note on PGDATABASE

Host, user and password are read from the environment. The database name is
not. It is not a credential, it is which application's data this is, and
`PGDATABASE` is a standard libpq variable that may already be exported on a
shared box for some other service. Honouring it would point `mix ecto.migrate`
at that service's database and create this application's tables inside it. To
use a different database, name it in `DATABASE_URL`.

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
curl -s localhost:4005/v1/accounts \
  -d email=you@example.com -d password='a sufficiently long password'
```

The response carries an API key. It is shown once — only a SHA-256 hash is
stored, so a lost key is rotated rather than looked up. Authenticate either way:

```bash
curl -s --user 'api:ep_live_...' localhost:4005/v3/domains     # Mailgun style
curl -s -H 'Authorization: Bearer ep_live_...' localhost:4005/v3/domains
```

Keys carry scopes (`messages:send`, `events:read`, `domains:write`, …). Scopes
are declared per action in each controller, next to the code they guard.

## Custom domains

Adding a domain generates an RSA-2048 DKIM keypair. The private half stays in
the database; the public half is what the customer publishes.

```bash
curl -s --user 'api:KEY' localhost:4005/v3/domains -d name=mail.yourcompany.com
```

The response lists the records to publish, then:

```bash
curl -s -X PUT --user 'api:KEY' localhost:4005/v3/domains/mail.yourcompany.com/verify
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
curl -s --user 'api:KEY' localhost:4005/v3/mail.yourcompany.com/messages \
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

### Operator dashboard
`GET /admin` — service-wide figures: accounts, domains, messages in and out,
hard bounces, unsubscribes, complaints, screening outcomes, and how verified
domains are spread across the warmup ladder.

Guarded by `ADMIN_TOKEN`, not by an API key, because these figures span every
account and no customer credential should open them. With no token set the
dashboard refuses to open at all, which is the right failure mode for a missing
environment variable. The page itself is served without a token and carries no
figures; it fetches `GET /admin/stats` with one, so landing on the URL uninvited
shows a prompt rather than a count of anything.

One number it does not have: outbound messages refused by content screening.
They are rejected before anything is stored, so they leave no row and no event.
The dashboard says so rather than omitting it silently.

### For people
`/signup`, `/login`, then `/domains`, `/send`, `/messages`, `/account`. Ordinary
server-rendered pages, one URL each, so they can be linked and bookmarked.

They are a client of the same contexts the JSON API uses, not a second
implementation: adding a domain from the form and from `POST /v3/domains` run
the same code. The session holds a user id and nothing else, looked up per
request, so suspending an account takes effect immediately rather than when its
session expires.

HEEx rather than the string templates the landing page uses, because these
render addresses, domain names and subject lines. All of that is customer input
and `~H` escapes it on the way out.

### For agents
`GET /llms.txt` — an agent-facing description of this API, needing no key. It
is rendered from the running service, so the sending ladder in it is the ladder
actually enforced rather than a number written down once and left to drift. A
test asserts both that the published rungs match `EmailProvider.Warmup.stages/0`
and that every endpoint the file advertises is really routed.

`/robots.txt` points at it.

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

## SMTP

The service speaks SMTP in both directions. Neither listener is on by default:
receiving needs port 25, and sending directly needs outbound port 25, and both
are decisions rather than defaults.

### Sending

Three ways out, in order of precedence.

| Setting | Route |
| --- | --- |
| `SMTP_RELAY` | Through a smarthost you chose. Demands STARTTLS and verifies the certificate. |
| `DIRECT_DELIVERY=true` | Straight to each recipient's MX, no smarthost. |
| neither | Written to `priv/local_mail`. Nothing leaves the machine. |

Direct delivery groups recipients by domain, looks up each domain's MX records,
and tries them in preference order, falling back to the domain's own A record
when it publishes no MX as RFC 5321 requires. A 5xx from a destination ends the
attempt; anything else moves to the next host, because it usually means that
host is unreachable rather than the mail being unwanted.

TLS is deliberately weaker here than to a smarthost: opportunistic and
unverified. A smarthost is one server you chose and can hold to a standard. The
open internet is full of receiving servers with self-signed or mismatched
certificates and no prior agreement to check them against, so demanding
verification would not make delivery safer, it would stop it working. This is
what every other MTA does and what RFC 7435 calls opportunistic security.

**Most hosts block outbound port 25, Vultr included.** Until that is lifted for
the machine, every direct delivery times out. Ask support to unblock it, or use
a smarthost.

### Receiving

`SMTP_RECEIVE_ENABLED=true` opens port 25 and accepts mail for hosted domains.
`SMTP_SUBMISSION_ENABLED=true` opens 587, where a customer's own software
authenticates with the credentials issued when their domain was added and then
sends through us. Submission runs the same pipeline as the REST API, so
screening, the suppression list and the warmup ladder all still apply.

The property that matters is not being an open relay, and it lives in one
function, `handle_RCPT/2`. On port 25 a recipient is accepted only if its domain
is one we host and is active; everything else gets `550 5.7.1`. A hosted domain
that is not verified yet gets `450` instead, so a legitimate sender retries once
the customer finishes their DNS rather than being told permanently to go away.
Relaying becomes permitted only once a session has authenticated, which is the
entire purpose of the submission port and the reason it must never be port 25.
`AUTH` is advertised only on the submission port, because offering it on 25
turns every customer's SMTP password into something guessable from anywhere.

Port 25 needs root or `CAP_NET_BIND_SERVICE`. A listener that cannot bind is
logged and skipped rather than taken as a reason for the application not to
start: a provider that cannot receive today should still serve its API and keep
sending.

### DNS this deployment needs

`ai.agentemaillist.com` already resolves to the box. These do not exist yet and
are what make domain verification and delivery work:

| Type | Name | Value | For |
| --- | --- | --- | --- |
| TXT | `ai.agentemaillist.com` | `v=spf1 ip4:155.138.220.76 ~all` | so `include:ai.agentemaillist.com` in a customer's SPF authorises this machine |
| PTR | `155.138.220.76` | `ai.agentemaillist.com` | set in the Vultr panel, not in DNS; receiving servers compare it against HELO |

The root domain's existing MX points at Namecheap forwarding for ordinary mail
to `@agentemaillist.com`. Everything here lives under `ai.` so that is left
alone.

## How delivery works

Delivery runs concurrently, bounded by `DELIVERY_CONCURRENCY`. It is almost
entirely waiting on DNS, a TCP connect and a conversation with a server on the
other side of the internet, so done one at a time the queue moves at the speed
of its slowest recipient and one server taking thirty seconds stalls everything
behind it. The ceiling stays under `POOL_SIZE` because each in-flight delivery
holds a database connection.

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
curl -s --user 'api:KEY' localhost:4005/v1/profile
curl -s --user 'api:KEY' -X POST localhost:4005/v1/profile/refresh
curl -s --user 'api:KEY' localhost:4005/v1/profile/signals
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
