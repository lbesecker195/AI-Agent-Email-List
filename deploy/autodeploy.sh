#!/usr/bin/env bash
#
# Pull main, build it, and restart the service — but only when there is
# something new and only when it compiles.
#
# Run it by hand any time:
#
#     sudo bash /var/www/HoneyTrap/AI-Agent-Email-List/deploy/autodeploy.sh
#
# or leave the timer to call it every ten minutes. Both paths run this same
# script, so "deploy now" and "deploy on the timer" cannot drift apart.
#
# Three things it refuses to do, each of which has cost somebody an afternoon
# on this box's sibling deployment (CSuiteFinder) already:
#
#   * Rebuild when nothing has changed. A release build here takes minutes and
#     restarts the service. Ten-minute rebuilds of an unchanged tree would mean
#     the site restarts 144 times a day for no reason.
#   * Deploy a tree that does not compile. Warnings are errors here, which is
#     the gate that catches a mistake pushed green locally because a warning
#     scrolled past, before it ever reaches the running release.
#   * Run twice at once. A build started while another is half-written
#     produces a release nobody can reason about.
#
# What it does NOT do is run the test suite. That belongs before the push —
# `mix test` — not on a box that would need its own throwaway database to run
# one here as well. Set AUTODEPLOY_TEST=1 if you want it here too.

set -euo pipefail

APP_NAME="${APP_NAME:-email_provider}"
APP_DIR="${APP_DIR:-/var/www/HoneyTrap/AI-Agent-Email-List}"
ENV_FILE="${ENV_FILE:-/etc/email-provider.env}"
SERVICE="${SERVICE:-email-provider}"
APP_USER="${APP_USER:-mailer}"
BRANCH="${BRANCH:-main}"
HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:4005/health}"
LOCK="${LOCK:-/var/lock/email-provider-autodeploy.lock}"

# `date -Is` is GNU-only, and this script is worth being able to run on a Mac
# to check it does the right thing before it runs anywhere that matters.
log() { printf '%s  %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"; }
die() { log "FAILED: $*"; exit 1; }

# One at a time. Without this the timer can start a build on top of a build.
#
# The missing-flock case is checked separately and loudly. `! flock -n 9` is
# also true when there is no flock at all, so without this the script would
# announce that another deploy is running, exit 0, and go on never deploying
# anything — a silent permanent no-op, which is the worst thing this could do.
command -v flock >/dev/null || die "flock is not installed (apt install util-linux)"

exec 9>"$LOCK"
if ! flock -n 9; then
  log "another deploy is running; leaving it alone"
  exit 0
fi

cd "$APP_DIR" || die "no such directory: $APP_DIR"

git fetch --quiet origin "$BRANCH" || die "could not reach the remote"

local_sha="$(git rev-parse HEAD)"
remote_sha="$(git rev-parse "origin/$BRANCH")"

if [ "$local_sha" = "$remote_sha" ]; then
  log "already at ${local_sha:0:8}; nothing to do"
  exit 0
fi

log "deploying ${local_sha:0:8} -> ${remote_sha:0:8}"
git log --oneline "$local_sha..$remote_sha" | sed 's/^/    /'

# Anything uncommitted here is a hand-edit on the server. Refuse rather than
# silently throw it away: someone put it there for a reason and a pull that
# discards it is the kind of thing nobody finds out about until much later.
if ! git diff --quiet || ! git diff --cached --quiet; then
  die "working tree is dirty — commit, stash or discard it, then run again"
fi

git merge --ff-only "origin/$BRANCH" || die "cannot fast-forward; the server has diverged"

[[ -r "$ENV_FILE" ]] || die "$ENV_FILE not found or unreadable"

# The build and the migration run as $APP_USER, same split of duties as
# deploy.sh: the app's own files stay owned by the app, not by root, and
# root's job here is only to source the env file, drop privileges for the
# heavy lifting, and restart the service once it is done.
chown -R "$APP_USER:$APP_USER" "$APP_DIR"

sudo -u "$APP_USER" env HOME="$APP_DIR" bash -lc 'command -v mix' >/dev/null 2>&1 ||
  die "$APP_USER cannot run mix. Elixir is probably installed under /root, or via
  a version manager that this user cannot see."

# Same memory-based choice deploy.sh makes: parallel compilation is free on a
# box with room, and the thing that OOM-kills a small box during a build.
mem_mb=$(free -m | awk '/^Mem:/{print $2}')
if [[ $mem_mb -ge 3500 ]]; then
  build_schedulers=""
  build_make="-j$(nproc)"
else
  build_schedulers="+S 1:1"
  build_make="-j1"
fi

log "compiling (warnings as errors)"
sudo -u "$APP_USER" env HOME="$APP_DIR" MIX_ENV=prod \
  ELIXIR_ERL_OPTIONS="$build_schedulers" MAKEFLAGS="$build_make" bash -lc "
  set -e
  cd '$APP_DIR'
  mix local.hex --force --if-missing >/dev/null 2>&1 || mix local.hex --force >/dev/null
  mix local.rebar --force >/dev/null
  mix deps.get --only prod >/dev/null
  mix compile --warnings-as-errors
" || die "it does not compile; the running site is untouched"

if [ "${AUTODEPLOY_TEST:-0}" = "1" ]; then
  log "running the test suite"
  sudo -u "$APP_USER" env HOME="$APP_DIR" MIX_ENV=test bash -lc "
    cd '$APP_DIR' && mix test
  " || die "tests failed; the running site is untouched"
fi

log "building the release"
sudo -u "$APP_USER" env HOME="$APP_DIR" MIX_ENV=prod bash -lc "
  cd '$APP_DIR' && mix release --overwrite >/dev/null
" || die "release build"

log "migrating"
sudo -u "$APP_USER" env HOME="$APP_DIR" bash -c '
  set -e
  set -a; . "$1"; set +a
  exec "$2"
' _ "$ENV_FILE" "$APP_DIR/_build/prod/rel/$APP_NAME/bin/migrate" || die "migration"

# A failed boot leaves one of these behind, and it is confusing to find later.
rm -f "$APP_DIR/erl_crash.dump"

log "restarting $SERVICE"
systemctl restart "$SERVICE"

# Give it a moment, then check it actually came up. A deploy that leaves the
# site down and says nothing is worse than one that never ran.
for attempt in 1 2 3 4 5 6 7 8 9 10; do
  sleep 2
  if curl -fsS --max-time 5 "$HEALTH_URL" >/dev/null 2>&1; then
    log "healthy at ${remote_sha:0:8}"
    exit 0
  fi
  log "  health check $attempt/10 not yet"
done

die "deployed ${remote_sha:0:8} but the health check never passed — check: journalctl -u $SERVICE -n 50"
