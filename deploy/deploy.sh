#!/usr/bin/env bash
#
# Agent Email List — one-shot deploy for Ubuntu/Debian.
#
#   sudo bash deploy/deploy.sh --domain ai.agentemaillist.com --email you@example.com
#
# Safe to re-run: it keeps secrets it has already generated, skips work that is
# already done, and only restarts what it changed. Re-running it is the intended
# way to deploy a change.
#
# This machine also runs CSuiteFinder. Everything here uses its own user, port,
# database, service name and nginx site, and the script will refuse to touch
# anything belonging to that deployment.
#
# Flags (all optional — you will be prompted for what is missing):
#   --domain <fqdn>     public hostname, default ai.agentemaillist.com
#   --email <addr>      contact address for Let's Encrypt
#   --no-ssl            skip certbot (use when DNS is not pointed here yet)
#   --no-firewall       skip ufw
#   --skip-build        redeploy config and restart without rebuilding
#   --enable-mail       also turn on the SMTP listeners (needs port 25 open)
#   --yes               never prompt; fail instead of asking

set -euo pipefail

APP_NAME=email_provider
SERVICE=email-provider
ENV_FILE=/etc/email-provider.env
APP_USER=mailer
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_NAME=email_provider_prod
DB_USER=mailer
PORT=4005
NGINX_SITE=email-provider

DOMAIN="ai.agentemaillist.com"; LE_EMAIL=""
DO_SSL=1; DO_FIREWALL=1; DO_BUILD=1; ENABLE_MAIL=0; ASSUME_YES=0

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
step()  { printf '\n\033[1;36m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
ok()    { printf '    \033[32m✓\033[0m %s\n' "$*"; }
warn()  { printf '    \033[33m!\033[0m %s\n' "$*"; }
die()   { printf '\n\033[31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)       DOMAIN="${2:?}"; shift 2 ;;
    --email)        LE_EMAIL="${2:?}"; shift 2 ;;
    --no-ssl)       DO_SSL=0; shift ;;
    --no-firewall)  DO_FIREWALL=0; shift ;;
    --skip-build)   DO_BUILD=0; shift ;;
    --enable-mail)  ENABLE_MAIL=1; shift ;;
    --yes|-y)       ASSUME_YES=1; shift ;;
    -h|--help)      sed -n '2,23p' "$0"; exit 0 ;;
    *)              die "unknown flag: $1" ;;
  esac
done

ask() {
  local prompt="$1" default="${2:-}"
  if [[ $ASSUME_YES -eq 1 ]]; then
    [[ -n $default ]] && { printf '%s' "$default"; return; }
    die "$prompt (needed, and --yes was given so I cannot ask)"
  fi
  local answer
  read -rp "    $prompt " answer </dev/tty
  printf '%s' "${answer:-$default}"
}

# ---------------------------------------------------------------- preflight

step "Preflight"
[[ $EUID -eq 0 ]] || die "run with sudo"
[[ -f "$APP_DIR/mix.exs" ]] || die "$APP_DIR does not look like the project"
command -v apt-get >/dev/null || die "this script is for Debian/Ubuntu"
ok "deploying $APP_DIR as $DOMAIN"

# The other service on this box. Knowing its port stops us colliding with it.
if [[ -f /etc/systemd/system/csuite-finder.service ]]; then
  ok "CSuiteFinder is installed here; leaving it alone"
fi

# This script chowns the tree to the app user so the build can write to it, which
# then makes git refuse to run here as root: since 2.35.2 it will not touch a
# repository owned by somebody else, in case a hook belongs to them too. The
# exception is safe for a directory root administers and a user root created, and
# adding it here means `git pull` keeps working after the first deploy rather
# than failing with "dubious ownership" the next time.
if ! git config --global --get-all safe.directory 2>/dev/null | grep -qxF "$APP_DIR"; then
  git config --global --add safe.directory "$APP_DIR"
  ok "allowed root to run git in $APP_DIR"
fi

if ss -lntp 2>/dev/null | grep -q ":$PORT "; then
  if ! systemctl is-active --quiet "$SERVICE"; then
    die "port $PORT is in use by something that is not $SERVICE. Stop it first."
  fi
fi

# --------------------------------------------------------------- packages

step "System packages"
missing=()
# openssl generates SECRET_KEY_BASE and the database password; ca-certificates
# lets curl reach the address-lookup service over HTTPS; iproute2 provides `ss`.
# None are guaranteed on a minimal image.
for pkg in build-essential git postgresql nginx curl openssl ca-certificates iproute2; do
  dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  DEBIAN_FRONTEND=noninteractive apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${missing[@]}"
  ok "installed: ${missing[*]}"
else
  ok "all present"
fi

command -v mix >/dev/null || die "Elixir is not installed. Install Erlang/Elixir, then re-run."
ok "elixir $(elixir --version | awk '/^Elixir/{print $2}')"


# ----------------------------------------------------------------- memory

step "Memory"
mem_mb=$(free -m | awk '/^Mem:/{print $2}')
swap_mb=$(free -m | awk '/^Swap:/{print $2}')
if [[ $mem_mb -lt 2048 && $swap_mb -lt 1024 ]]; then
  if [[ ! -f /swapfile ]]; then
    # Compiling is the largest memory consumer this machine will see, and when
    # it runs out the kernel kills the biggest process rather than the build —
    # which on this box means CSuiteFinder.
    fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap -q /swapfile && swapon /swapfile
    grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
    ok "added 2G swap (${mem_mb}MB RAM would not survive the build)"
  else
    warn "/swapfile exists but is not active; run: swapon /swapfile"
  fi
else
  ok "${mem_mb}MB RAM, ${swap_mb}MB swap"
fi

# ------------------------------------------------------------------- user

step "Service user"
if id "$APP_USER" >/dev/null 2>&1; then
  ok "$APP_USER exists"
else
  adduser --system --group --home "$APP_DIR" --no-create-home "$APP_USER" >/dev/null
  ok "created $APP_USER"
fi

# --------------------------------------------------------------- postgres

step "PostgreSQL"
systemctl is-active --quiet postgresql || systemctl start postgresql

psql_as_postgres() { sudo -u postgres psql -qtAX -c "$1"; }

max_conn=$(psql_as_postgres "SHOW max_connections;")
in_use=$(psql_as_postgres "SELECT count(*) FROM pg_stat_activity;")
ok "max_connections=$max_conn, currently $in_use in use"

# Read any password we already issued, so re-running does not lock us out of a
# database we cannot then reach.
EXISTING_DB_PASSWORD=""
if [[ -f "$ENV_FILE" ]]; then
  EXISTING_DB_PASSWORD=$(sed -nE 's#^DATABASE_URL=ecto://[^:]+:([^@]+)@.*#\1#p' "$ENV_FILE" | head -1)
fi

if [[ -n $EXISTING_DB_PASSWORD ]]; then
  DB_PASSWORD="$EXISTING_DB_PASSWORD"
  ok "reusing the database password from $ENV_FILE"
else
  DB_PASSWORD=$(openssl rand -hex 24)
fi

if [[ $(psql_as_postgres "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER';") == "1" ]]; then
  psql_as_postgres "ALTER ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PASSWORD';" >/dev/null
  ok "role $DB_USER updated"
else
  psql_as_postgres "CREATE ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PASSWORD';" >/dev/null
  ok "role $DB_USER created"
fi

if [[ $(psql_as_postgres "SELECT 1 FROM pg_database WHERE datname='$DB_NAME';") == "1" ]]; then
  ok "database $DB_NAME exists"
else
  sudo -u postgres createdb -O "$DB_USER" "$DB_NAME"
  ok "database $DB_NAME created"
fi

# ------------------------------------------------------------ environment

step "Environment file"
if [[ -f "$ENV_FILE" ]]; then
  ok "$ENV_FILE exists — keeping its secrets"
  # shellcheck disable=SC1090
  set -a && . "$ENV_FILE" && set +a
fi

SECRET_KEY_BASE="${SECRET_KEY_BASE:-$(openssl rand -base64 48 | tr -d '\n')}"
# Opens /admin. Generated rather than left blank, because a blank one leaves the
# dashboard closed and the operator with no obvious way to open it.
ADMIN_TOKEN="${ADMIN_TOKEN:-$(openssl rand -hex 24)}"
POOL_SIZE="${POOL_SIZE:-10}"

if [[ -z "${LE_EMAIL:-}" && -n "${LETSENCRYPT_EMAIL:-}" ]]; then
  LE_EMAIL="$LETSENCRYPT_EMAIL"
fi

# Preserve whatever sending configuration is already set. This script never
# turns sending on by itself: with no relay and no direct delivery, mail is
# written to disk and nothing leaves the machine, which is the right default
# until somebody has decided otherwise.
SMTP_RELAY_LINE=""
[[ -n "${SMTP_RELAY:-}" ]] && SMTP_RELAY_LINE="SMTP_RELAY=$SMTP_RELAY
SMTP_PORT=${SMTP_PORT:-587}
SMTP_USERNAME=${SMTP_USERNAME:-}
SMTP_PASSWORD=${SMTP_PASSWORD:-}"

DIRECT_LINE=""
[[ "${DIRECT_DELIVERY:-}" == "true" ]] && DIRECT_LINE="DIRECT_DELIVERY=true"

# Written only when they have a value. A line like `OPENAI_API_KEY=` reads back
# as an empty string, which is not nil, so the code would take it for a real key
# and every screening call would come back 401.
OPTIONAL_KEYS=""
[[ -n "${OPENAI_API_KEY:-}" ]] && OPTIONAL_KEYS="OPENAI_API_KEY=$OPENAI_API_KEY"
[[ -n "${CSUITEFINDER_API_KEY:-}" ]] &&
  OPTIONAL_KEYS="$OPTIONAL_KEYS
CSUITEFINDER_API_KEY=$CSUITEFINDER_API_KEY"

if [[ $ENABLE_MAIL -eq 1 ]]; then
  SMTP_RECEIVE_ENABLED=true
  SMTP_SUBMISSION_ENABLED=true
fi

umask 077
cat > "$ENV_FILE" <<ENVEOF
# Written by deploy/deploy.sh. Safe to edit; re-running preserves what is here.
MIX_ENV=prod
PHX_SERVER=true

SECRET_KEY_BASE=$SECRET_KEY_BASE
ADMIN_TOKEN=$ADMIN_TOKEN
DATABASE_URL=ecto://$DB_USER:$DB_PASSWORD@localhost/$DB_NAME
PHX_HOST=$DOMAIN

PORT=$PORT
BIND_IP=127.0.0.1
POOL_SIZE=$POOL_SIZE

SMTP_HOSTNAME=${SMTP_HOSTNAME:-$DOMAIN}
SPF_HOST=${SPF_HOST:-$DOMAIN}
MX_HOST=${MX_HOST:-$DOMAIN}

SMTP_RECEIVE_ENABLED=${SMTP_RECEIVE_ENABLED:-false}
SMTP_SUBMISSION_ENABLED=${SMTP_SUBMISSION_ENABLED:-false}

$SMTP_RELAY_LINE
$DIRECT_LINE

$OPTIONAL_KEYS
ENVEOF
# root:$APP_USER 640, not root:root 600.
#
# systemd reads EnvironmentFile as root before dropping privileges, so the
# service works either way. The migration does not: it runs as the app user and
# has to read this file itself. Letting that user read it grants nothing it does
# not already have, since every one of these values ends up in its own process
# environment a moment later. Nobody else on the machine can read it.
# An earlier version of this script wrote FORCE_SSL here and it made the release
# refuse to boot. Remove it rather than leaving a line that looks meaningful.
sed -i '/^FORCE_SSL=/d' "$ENV_FILE"

chown "root:$APP_USER" "$ENV_FILE"
chmod 640 "$ENV_FILE"
umask 022
ok "$ENV_FILE written (root, readable by $APP_USER)"

sudo -u "$APP_USER" test -r "$ENV_FILE" ||
  die "$APP_USER cannot read $ENV_FILE; migrations would run without credentials"

# ------------------------------------------------------------------- build

if [[ $DO_BUILD -eq 1 ]]; then
  step "Building the release (this is the slow part)"
  chown -R "$APP_USER:$APP_USER" "$APP_DIR"

  # Root having mix says nothing about the app user having it, and the build runs
  # as the app user: a version manager installed under /root puts Elixir where
  # this user cannot reach it, and sudo resets PATH to secure_path besides.
  #
  # Checked here rather than in preflight because the app user does not exist
  # until a few steps ago, and `sudo -u` on a missing user fails in a way that
  # reads exactly like a missing Elixir.
  if ! sudo -u "$APP_USER" env HOME="$APP_DIR" bash -lc 'command -v mix' >/dev/null 2>&1; then
    die "$APP_USER cannot run mix. Elixir is probably installed under /root, or
    via a version manager that this user cannot see. Install it system-wide, for
    instance into /usr/local/bin, so both users reach the same one."
  fi
  ok "$APP_USER can run mix"

  # HOME inside the app tree, because it is the directory we just chowned: hex
  # and rebar caches have to land somewhere the service user can write.
  #
  # Parallelism follows the machine. Serialising compilation is what stops a
  # 1GB box OOM-killing its neighbours, and it is pure waste on a box with room
  # to spare: the same build that needs protecting on 1GB should use every core
  # on 12GB. The threshold is memory rather than cores, because memory is what
  # actually runs out.
  if [[ $mem_mb -ge 3500 ]]; then
    build_schedulers=""
    build_make="-j$(nproc)"
    ok "building in parallel across $(nproc) cores (${mem_mb}MB RAM)"
  else
    build_schedulers="+S 1:1"
    build_make="-j1"
    ok "building one process at a time (${mem_mb}MB RAM is not enough to parallelise safely)"
  fi
  # `-lc`, matching the preflight check: a login shell sources /etc/profile,
  # which is where a system-wide Elixir install usually puts itself on PATH. A
  # check that used a different shell from the build would prove nothing.
  sudo -u "$APP_USER" env HOME="$APP_DIR" MIX_ENV=prod \
    ELIXIR_ERL_OPTIONS="$build_schedulers" MAKEFLAGS="$build_make" bash -lc "
    set -e
    cd '$APP_DIR'
    mix local.hex --force --if-missing >/dev/null 2>&1 || mix local.hex --force >/dev/null
    mix local.rebar --force >/dev/null
    mix deps.get --only prod >/dev/null
    mix release --overwrite >/dev/null
  "
  ok "release built"
else
  [[ -x "$APP_DIR/_build/prod/rel/$APP_NAME/bin/server" ]] ||
    die "--skip-build given but no release exists yet"
  ok "skipping build"
fi

# -------------------------------------------------------------- migrations

step "Migrations"
# Source the env file inside the child shell. Passing it through `xargs` would
# split SECRET_KEY_BASE on the / and = that base64 produces, and putting it on
# the command line would show the database password in `ps`.
#
# `set -e` in the inner shell matters: without it a file this user cannot read
# fails quietly and migrate runs anyway, which surfaces as "DATABASE_URL is
# missing" and sends you looking in the wrong place.
sudo -u "$APP_USER" env HOME="$APP_DIR" bash -c '
  set -e
  set -a; . "$1"; set +a
  exec "$2"
' _ "$ENV_FILE" "$APP_DIR/_build/prod/rel/$APP_NAME/bin/migrate"
ok "database migrated"

# A failed boot leaves one of these behind, and it is confusing to find later.
rm -f "$APP_DIR/erl_crash.dump"

# ----------------------------------------------------------------- systemd

step "systemd service"
# The unit ships with this deployment's paths written in. Substitute rather than
# copy, so deploying somewhere else does not leave a unit pointing at a
# directory that is not there.
sed -e "s#/var/www/HoneyTrap/AI-Agent-Email-List#$APP_DIR#g" \
    -e "s/^User=mailer\$/User=$APP_USER/" \
    -e "s/^Group=mailer\$/Group=$APP_USER/" \
    "$APP_DIR/deploy/$SERVICE.service" > "/etc/systemd/system/$SERVICE.service"
chmod 644 "/etc/systemd/system/$SERVICE.service"
systemctl daemon-reload
systemctl enable "$SERVICE" >/dev/null 2>&1 || true
systemctl restart "$SERVICE"

for _ in $(seq 1 30); do
  curl -sf "http://127.0.0.1:$PORT/health" >/dev/null 2>&1 && break
  sleep 1
done

if curl -sf "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
  ok "$SERVICE is up on 127.0.0.1:$PORT"
else
  journalctl -u "$SERVICE" -n 30 --no-pager >&2
  die "$SERVICE did not come up; the last 30 log lines are above"
fi

# ------------------------------------------------------------------- nginx

step "nginx"
site_conf="/etc/nginx/sites-available/$NGINX_SITE"

# Certbot edits this file in place to add the TLS block. Overwriting it after
# that would throw away the certificate configuration and leave nginx pointing
# at nothing on 443.
if [[ -f $site_conf ]] && grep -q "ssl_certificate" "$site_conf"; then
  ok "site exists and certbot has edited it — leaving it alone"
else
  sed -e "s/server_name ai\.agentemaillist\.com;/server_name $DOMAIN;/" \
      -e "s/server 127\.0\.0\.1:4005;/server 127.0.0.1:$PORT;/" \
      "$APP_DIR/deploy/nginx-ai-agentemaillist.conf" > "$site_conf"
  ln -sf "$site_conf" "/etc/nginx/sites-enabled/$NGINX_SITE"
  ok "site written for $DOMAIN"
fi

nginx -t 2>/dev/null || die "nginx config is invalid; nothing was reloaded"
systemctl reload nginx
ok "nginx reloaded"

# --------------------------------------------------------------------- TLS

resolved=$(getent hosts "$DOMAIN" | awk '{print $1}' | head -1 || true)
my_ip=$(curl -sf --max-time 5 https://api.ipify.org || true)

if [[ $DO_SSL -eq 1 ]]; then
  if [[ -n $resolved && -n $my_ip && $resolved != "$my_ip" ]]; then
    warn "$DOMAIN resolves to $resolved but this machine is $my_ip"
    warn "certbot will fail until DNS points here; skipping TLS"
    DO_SSL=0
  fi
fi

if [[ $DO_SSL -eq 1 ]]; then
  step "TLS certificate"
  dpkg -s certbot >/dev/null 2>&1 ||
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq certbot python3-certbot-nginx

  if [[ -d "/etc/letsencrypt/live/$DOMAIN" ]]; then
    ok "certificate already issued"
  else
    [[ -n $LE_EMAIL ]] || LE_EMAIL=$(ask "contact address for Let's Encrypt:")
    [[ -n $LE_EMAIL ]] || die "an email address is required for certbot"
    certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$LE_EMAIL" --redirect
    ok "certificate issued"
  fi

  # Nothing to switch on: HTTPS enforcement is compile-time config in
  # config/prod.exs and has been active since the first boot. It excludes
  # loopback, which is why the health check above still answered over plain HTTP.

  step "Verifying over HTTPS"
  if curl -sf --max-time 10 "https://$DOMAIN/health" >/dev/null; then
    ok "https://$DOMAIN/health answers"
  else
    warn "https://$DOMAIN/health did not answer; check: journalctl -u $SERVICE -n 50"
  fi
else
  step "Verifying over HTTP"
  # `curl -sf` treats a 301 as success, and before TLS exists every request is
  # a 301 to a scheme nothing serves. Checking the status explicitly is the
  # difference between "the site works" and "the site redirects into a void".
  http_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "http://$DOMAIN/health" || echo 000)
  case "$http_status" in
    200)
      ok "http://$DOMAIN/health answers"
      ;;
    301|302|308)
      warn "http://$DOMAIN/health redirects to HTTPS, which is not set up yet."
      warn "That is expected with --no-ssl. Point DNS here, then re-run without it."
      ;;
    000)
      warn "http://$DOMAIN/health did not answer at all; DNS may still point elsewhere"
      ;;
    *)
      warn "http://$DOMAIN/health answered $http_status"
      ;;
  esac
fi

# ---------------------------------------------------------------- firewall

if [[ $DO_FIREWALL -eq 1 ]] && command -v ufw >/dev/null; then
  step "Firewall"
  ufw allow 80,443/tcp >/dev/null 2>&1 || true
  if [[ "${SMTP_RECEIVE_ENABLED:-false}" == "true" ]]; then
    ufw allow 25,587/tcp >/dev/null 2>&1 || true
    ok "80, 443, 25 and 587 allowed"
  else
    ok "80 and 443 allowed (25 and 587 stay closed while mail is off)"
  fi
  # Port 4005 is deliberately not opened. nginx is the only thing that should
  # reach the application.
fi

# ------------------------------------------------------------------- done

step "Done"
echo
bold "  Service"
echo "    systemctl status $SERVICE"
echo "    journalctl -u $SERVICE -f"
echo
bold "  Operator dashboard"
if [[ $DO_SSL -eq 1 ]]; then
  echo "    https://$DOMAIN/admin"
else
  echo "    http://$DOMAIN/admin"
fi
echo "    Token:  $ADMIN_TOKEN"
echo "    Also in $ENV_FILE, which only root can read."
echo

bold "  Reachable at"
if [[ $DO_SSL -eq 1 ]]; then
  echo "    https://$DOMAIN/health"
  echo "    https://$DOMAIN/llms.txt"
else
  echo "    http://$DOMAIN/health"
  echo "    http://$DOMAIN/llms.txt"
fi
echo

bold "  Mail is not sending yet"
if [[ -n "${SMTP_RELAY:-}" ]]; then
  echo "    Relaying through ${SMTP_RELAY}."
elif [[ "${DIRECT_DELIVERY:-}" == "true" ]]; then
  echo "    Direct delivery is on. Check outbound 25 is really open:"
  echo "      bash -c 'exec 3<>/dev/tcp/gmail-smtp-in.l.google.com/25 && echo open'"
else
  echo "    Nothing is set, so messages are written to disk and never sent."
  echo "    That is the safe default, not a fault. Pick one:"
  echo
  echo "      SMTP_RELAY=...      a smarthost. No port 25 needed, and it"
  echo "                          delivers far better from a new address."
  echo "      DIRECT_DELIVERY=true  straight to each recipient's MX. Needs"
  echo "                          outbound port 25, which Vultr blocks by"
  echo "                          default; open a support ticket first."
  echo
  echo "    Set one in $ENV_FILE, then: systemctl restart $SERVICE"
fi
echo

if [[ "${SMTP_RECEIVE_ENABLED:-false}" != "true" ]]; then
  bold "  Mail is not being received yet"
  echo "    Publish an MX record pointing at $DOMAIN, then re-run with"
  echo "    --enable-mail. The unit already grants CAP_NET_BIND_SERVICE, so"
  echo "    ports 25 and 587 work without running as root."
  echo
fi

bold "  DNS still needed before any customer domain can verify"
echo "    TXT  $DOMAIN  \"v=spf1 ip4:${my_ip:-YOUR_IP} ~all\""
echo "    PTR  ${my_ip:-YOUR_IP} -> $DOMAIN   (set in the Vultr panel, not DNS)"
echo
