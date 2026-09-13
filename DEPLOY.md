# Deploying to ai.agentemaillist.com

Ubuntu VPS, nginx in front, Let's Encrypt for TLS, systemd to keep it running.
The same shape as the CSuiteFinder deployment already on this machine.

Two things are deliberately **not** part of getting the web service up, because
each depends on something outside this repo:

- **Sending** needs either a smarthost or outbound port 25, which Vultr blocks
  on new accounts. Until one of those exists, mail is written to disk and
  nothing is sent. Nothing else breaks.
- **Receiving** needs an MX record and a PTR. Off until you add them.

So the order below gets the API and `/llms.txt` publicly reachable over HTTPS
first, which is what someone reviewing the service needs to see.

Assumes the repo is at `/var/www/HoneyTrap/AI-Agent-Email-List`.

## The short way

```bash
sudo bash deploy/deploy.sh --domain ai.agentemaillist.com --email you@example.com
```

That does everything below. It is safe to re-run and is the intended way to
deploy a change: it keeps secrets it has already generated, skips work already
done, and restarts only what it changed.

Useful flags:

| Flag | Does |
| --- | --- |
| `--no-ssl` | Skip certbot. Use when DNS is not pointed here yet. |
| `--skip-build` | Re-apply config and restart without rebuilding. |
| `--enable-mail` | Also turn on the SMTP listeners. Needs port 25 open. |
| `--yes` | Never prompt. Fails instead of asking. |

It will not turn sending on by itself, and it will not touch the CSuiteFinder
deployment on the same machine. It adds swap if the box has too little memory to
survive a build, because otherwise the kernel resolves that by killing the
largest process, which here means CSuiteFinder.

The rest of this file is the same work done by hand, which is what to read when
a step fails or you want to know why it is there.

## 1. A user and a database

The service does not run as root. CSuiteFinder runs as `csuite`; this one runs
as `mailer`.

```bash
sudo adduser --system --group --home /var/www/HoneyTrap/AI-Agent-Email-List --no-create-home mailer
sudo chown -R mailer:mailer /var/www/HoneyTrap/AI-Agent-Email-List
```

```bash
sudo -u postgres psql -c "CREATE ROLE mailer LOGIN PASSWORD 'pick-a-password';"
sudo -u postgres psql -c "CREATE DATABASE email_provider_prod OWNER mailer;"
```

Postgres on this box is shared with CSuiteFinder. Check what headroom is left
before setting `POOL_SIZE`:

```bash
sudo -u postgres psql -c "SHOW max_connections;" -c "SELECT count(*) FROM pg_stat_activity;"
```

## 2. The environment file

Production secrets live in one root-owned file, never in the systemd unit, which
is world-readable.

```bash
sudo cp deploy/email-provider.env.example /etc/email-provider.env
sudo chown root:mailer /etc/email-provider.env
sudo chmod 640 /etc/email-provider.env
sudo nano /etc/email-provider.env
```

`root:mailer` and `640`, not `root:root` and `600`. systemd reads
`EnvironmentFile` as root before dropping privileges so the service works either
way, but the migration below runs as `mailer` and has to read the file itself.
Letting that user read it grants nothing it does not already have, because every
value in it ends up in its own process environment a moment later. Nothing else
on the machine can read it.

Three values have to be set or the release refuses to boot:

```bash
mix phx.gen.secret        # paste into SECRET_KEY_BASE
```

`DATABASE_URL` with the password from step 1, and `PHX_HOST=ai.agentemaillist.com`.

Leave `FORCE_SSL` commented out for now. Turning it on before certbot has issued
means every request redirects to a scheme nothing is listening on, which looks
exactly like a broken application.

## 3. Build the release

Do **not** use `mix setup` here. It is a development command and on a shared box
it can take the neighbours down: compiling fans out to one process per core,
making the build the largest memory consumer on the machine, and when memory
runs out the kernel kills the biggest process rather than the build.

```bash
cd /var/www/HoneyTrap/AI-Agent-Email-List
sudo git pull
sudo -u mailer bin/setup-server --release
```

Pull as root, not as `mailer`. Root holds the SSH key the clone was made with;
`mailer` is a system user with no key and no shell. The tree is owned by `mailer`
so the build can write to it, which makes git refuse to run here as root until
the directory is marked safe:

```bash
sudo git config --global --add safe.directory /var/www/HoneyTrap/AI-Agent-Email-List
```

`deploy.sh` adds that itself, so this is only needed if you pull before running
it the first time.

`--release` serialises compilation, caps its memory under systemd, and touches
no database, so it does not matter that migrations have not run yet.

## 4. Migrate

```bash
sudo -u mailer env HOME=/var/www/HoneyTrap/AI-Agent-Email-List bash -c '
  set -e
  set -a; . /etc/email-provider.env; set +a
  exec _build/prod/rel/email_provider/bin/migrate
'
```

The file is sourced inside the shell rather than expanded onto the command line,
which would put `SECRET_KEY_BASE` and the database password into `ps` and your
shell history, and would split that secret on the `/` and `=` that base64
produces.

`set -e` matters. Without it, a file this user cannot read fails quietly and
`migrate` runs anyway, which surfaces as `environment variable DATABASE_URL is
missing` and sends you looking at the wrong file.

## 5. systemd

```bash
sudo cp deploy/email-provider.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now email-provider
sudo systemctl status email-provider
```

It listens on `127.0.0.1:4005` only. That is deliberate: nginx is the only thing
that should reach it. Confirm before moving on:

```bash
curl -s localhost:4005/health
```

## 6. nginx

CSuiteFinder already has a site here. This adds a second server block matched by
`server_name`, so do not remove the existing one.

```bash
sudo cp deploy/nginx-ai-agentemaillist.conf /etc/nginx/sites-available/email-provider
sudo ln -s /etc/nginx/sites-available/email-provider /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

`ai.agentemaillist.com` already resolves to this machine, so this should now
answer from anywhere:

```bash
curl -s http://ai.agentemaillist.com/health
```

## 7. TLS

```bash
sudo certbot --nginx -d ai.agentemaillist.com
```

Certbot rewrites the site file in place, adding the TLS block and a redirect
from port 80. Once it has issued, turn on the app's own enforcement:

```bash
sudo sed -i 's/^# FORCE_SSL=true/FORCE_SSL=true/' /etc/email-provider.env
sudo systemctl restart email-provider
```

Then check the whole path:

```bash
curl -s https://ai.agentemaillist.com/health
curl -s https://ai.agentemaillist.com/llms.txt | head -20
```

`llms.txt` should now report `Base URL: https://ai.agentemaillist.com`. It reads
the host from the request, so if it says anything else the proxy headers are
wrong rather than the app.

## 8. Firewall

```bash
sudo ufw allow 80,443/tcp
sudo ufw status
```

Do not open 4005. Nothing outside the machine should reach the application port.

## Turning on mail, later

### Sending

Nothing sends until one of these is set in `/etc/email-provider.env`.

A smarthost needs no port 25 and delivers far better from an address with no
sending history, which is what this one is:

```bash
SMTP_RELAY=smtp.provider.example
SMTP_USERNAME=...
SMTP_PASSWORD=...
```

Direct delivery needs outbound port 25, which Vultr blocks on new accounts:

```bash
DIRECT_DELIVERY=true
```

Before that is worth enabling, check the block is actually lifted:

```bash
nc -zv -w 5 gmail-smtp-in.l.google.com 25
```

A timeout means it is still blocked and every delivery will time out too.

### DNS that sending needs

Without this record no customer domain can ever verify, because verification
looks for an SPF include naming this host:

| Type | Name | Value |
| --- | --- | --- |
| TXT | `ai.agentemaillist.com` | `v=spf1 ip4:155.138.220.76 ~all` |

And set the reverse DNS for `155.138.220.76` to `ai.agentemaillist.com` in the
Vultr control panel, not in DNS. Receiving servers compare it against the name
given in HELO, and a mismatch is one of the most common reasons new mail is
rejected outright.

### Receiving

Once an MX record points here:

```bash
SMTP_RECEIVE_ENABLED=true
SMTP_SUBMISSION_ENABLED=true
```

The systemd unit grants `CAP_NET_BIND_SERVICE`, so ports 25 and 587 work
without running as root. Open them:

```bash
sudo ufw allow 25,587/tcp
```

A listener that cannot bind is logged and skipped rather than stopping the
service, so if the API stays up but no mail arrives, check the journal first.

## Operating it

```bash
sudo systemctl status email-provider
sudo journalctl -u email-provider -f
sudo journalctl -u email-provider -p err --since "1 hour ago"
```

A remote console into the running system, which is a real shell on production:

```bash
sudo -u mailer _build/prod/rel/email_provider/bin/email_provider remote
```

Deploying a change:

```bash
sudo bash deploy/deploy.sh --domain ai.agentemaillist.com
```

## If it will not start

**`DATABASE_URL is missing`, usually just after `Permission denied` on the env
file.** The release refuses to boot without it by design, but the real cause is
one line above: whoever is running the command cannot read
`/etc/email-provider.env`. It has to be `root:mailer` and `640`, not
`root:root` and `600`.

```bash
sudo chown root:mailer /etc/email-provider.env && sudo chmod 640 /etc/email-provider.env
```

**Redirect loop, or every request 301s.** `FORCE_SSL=true` with no TLS yet, or
nginx not sending `X-Forwarded-Proto`. Both look identical from a browser.

**`password authentication failed`.** The role in `DATABASE_URL` does not exist
or its password is wrong. Note that `PGDATABASE` is deliberately ignored, so the
database has to be named in the URL.

**Port 4005 already in use.** Another copy is running, probably a `mix
phx.server` left over from testing.

**`fatal: detected dubious ownership in repository`.** The tree belongs to
`mailer` and you are running git as root. Mark it safe once:

```bash
sudo git config --global --add safe.directory /var/www/HoneyTrap/AI-Agent-Email-List
```

Do not chown the tree back to root to work around this. The build writes to
`_build`, `deps` and its hex cache, and needs to own them.
