#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
driver_source="$repo_dir/script/status-scheduler.sh"
tmp=$(mktemp -d /tmp/ghc-tmux-driver-test.XXXXXX)
socket="ghc-tmux-driver-test-$$"
home="$tmp/home"
lock_tmp="$tmp/locks"
renderer="$home/.config/tmux/rust/ghc-tmux-status/target/release/ghc-tmux-status"
driver="$home/.config/tmux/script/status-scheduler.sh"
client_holder=""

cleanup() {
  if [ -n "$client_holder" ]; then
    kill "$client_holder" 2>/dev/null || true
    wait "$client_holder" 2>/dev/null || true
  fi
  env -u TMUX tmux -L "$socket" kill-server 2>/dev/null || true
  rm -rf "$tmp"
}
trap cleanup EXIT

wait_for() {
  local description=$1
  shift
  for _ in $(seq 1 100); do
    if "$@"; then
      return 0
    fi
    sleep 0.05
  done
  echo "timed out waiting for $description" >&2
  return 1
}

option_is_inactive() {
  [ "$(env -u TMUX tmux -L "$socket" show -sqv @GHC_SL_SCHED_ACTIVE 2>/dev/null)" = "0" ]
}

option_is_active() {
  [ "$(env -u TMUX tmux -L "$socket" show -sqv @GHC_SL_SCHED_ACTIVE 2>/dev/null)" = "1" ]
}

client_is_attached() {
  [ -n "$(env -u TMUX tmux -L "$socket" list-clients 2>/dev/null)" ]
}

file_exists() {
  [ -f "$1" ]
}

file_is_nonempty() {
  [ -s "$1" ]
}

mkdir -p "$(dirname "$renderer")" "$(dirname "$driver")" "$lock_tmp"
cp "$driver_source" "$driver"
chmod +x "$driver"

cat >"$renderer" <<EOF
#!/bin/sh
printf '%s\n' "\$\$" >>'$tmp/crashes'
kill -KILL "\$\$"
EOF
chmod +x "$renderer"

env -u TMUX tmux -L "$socket" -f /dev/null new-session -d -s driver -x 80 -y 24
env -u TMUX tmux -L "$socket" set-environment -g HOME "$home"
env -u TMUX tmux -L "$socket" set-environment -g TMPDIR "$lock_tmp"
env -u TMUX tmux -L "$socket" set-environment -g GHC_TMUX_STATUS_DRIVER_DELAY_SECONDS 0.05
env -u TMUX tmux -L "$socket" set -g status on ';' set -g status-interval 1

# Hold one real attached client so tmux evaluates status #() jobs.
python3 - "$socket" >"$tmp/client.log" 2>&1 <<'PY' &
import os
import pty
import select
import sys

socket = sys.argv[1]
pid, fd = pty.fork()
if pid == 0:
    environment = os.environ.copy()
    environment.pop("TMUX", None)
    environment["TERM"] = "xterm-256color"
    os.execvpe(
        "tmux",
        ["tmux", "-L", socket, "attach-session", "-t", "driver"],
        environment,
    )

while True:
    readable, _, _ = select.select([fd], [], [], 1)
    if not readable:
        continue
    try:
        os.read(fd, 65536)
    except OSError:
        break
PY
client_holder=$!
wait_for "attached test client" client_is_attached
server_env=$(env -u TMUX tmux -L "$socket" display-message -p '#{socket_path},#{pid},0')
server_pid=$(env -u TMUX tmux -L "$socket" display-message -p '#{pid}')
scheduler_lock="$lock_tmp/ghc-tmux-status-scheduler-${UID}-${server_pid}.lock"

driver_format='#($HOME/.config/tmux/script/status-scheduler.sh)ALIVE'
env -u TMUX tmux -L "$socket" set -s @GHC_SL_SCHED_GEN 42 ';' \
  set -s @GHC_SL_SCHED_ACTIVE 1 ';' set -g status-left "$driver_format"
wait_for "crash fence" option_is_inactive
sleep 1.2

if [ "$(wc -l <"$tmp/crashes" | tr -d ' ')" != "1" ]; then
  echo "renderer crash loop was not stopped" >&2
  exit 1
fi
env -u TMUX tmux -L "$socket" display-message -p '#{pid}:alive' >/dev/null

# A normal application error must preserve lease-based scheduler recovery.
env -u TMUX tmux -L "$socket" set -g status-left ALIVE
cat >"$renderer" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "$renderer"
env -u TMUX tmux -L "$socket" set -s @GHC_SL_SCHED_GEN 43 ';' \
  set -s @GHC_SL_SCHED_ACTIVE 1
env HOME="$home" TMPDIR="$lock_tmp" TMUX="$server_env" \
  GHC_TMUX_STATUS_DRIVER_DELAY_SECONDS=0 "$driver" >/dev/null
if ! option_is_active; then
  echo "ordinary renderer error permanently fenced scheduler" >&2
  exit 1
fi

# An abnormally terminated old worker must not fence a generation activated by
# a concurrent reload.
cat >"$renderer" <<EOF
#!/bin/sh
: >'$tmp/stale-started'
sleep 0.3
kill -KILL "\$\$"
EOF
chmod +x "$renderer"
env -u TMUX tmux -L "$socket" set -s @GHC_SL_SCHED_GEN 44 ';' \
  set -s @GHC_SL_SCHED_ACTIVE 1 ';' set -g status-left "$driver_format"
wait_for "stale worker start" file_exists "$tmp/stale-started"
env -u TMUX tmux -L "$socket" set -s @GHC_SL_SCHED_GEN 45 ';' \
  set -s @GHC_SL_SCHED_ACTIVE 1 ';' set -g status-left ALIVE
sleep 0.5
if [ "$(env -u TMUX tmux -L "$socket" show -sqv @GHC_SL_SCHED_ACTIVE)" != "1" ]; then
  echo "old driver failure fenced a newer generation" >&2
  exit 1
fi

# A hung renderer remains an isolated child. tmux remains responsive, and the
# server-scoped lock rejects concurrent driver attempts.
cat >"$renderer" <<EOF
#!/bin/sh
exec python3 -c 'import os, time; f = open("$tmp/hangs", "a"); f.write(f"{os.getpid()}\\n"); f.flush(); time.sleep(30)'
EOF
chmod +x "$renderer"
env -u TMUX tmux -L "$socket" set -s @GHC_SL_SCHED_GEN 46 ';' \
  set -s @GHC_SL_SCHED_ACTIVE 1 ';' set -g status-left "$driver_format"
wait_for "hung renderer start" file_is_nonempty "$tmp/hangs"
driver_pids=()
for _ in $(seq 1 20); do
  env \
    HOME="$home" \
    TMPDIR="$lock_tmp" \
    TMUX="$server_env" \
    GHC_TMUX_STATUS_DRIVER_DELAY_SECONDS=0 \
    "$driver" >/dev/null 2>&1 &
  driver_pids+=("$!")
done
for driver_pid in "${driver_pids[@]}"; do
  wait "$driver_pid"
done
hang_count=$(wc -l <"$tmp/hangs" | tr -d ' ')
if [ "$hang_count" != "1" ]; then
  echo "hung renderer spawned duplicate format jobs: $hang_count" >&2
  exit 1
fi
env -u TMUX tmux -L "$socket" display-message -p '#{pid}:alive' >/dev/null

hang_pid=$(tail -n 1 "$tmp/hangs")
if ! kill -0 "$hang_pid" 2>/dev/null; then
  echo "recorded hung renderer pid is not alive: $hang_pid" >&2
  exit 1
fi
lock_owner=$(cat "$scheduler_lock" 2>/dev/null || true)
if [ "${lock_owner#*:}" != "$hang_pid" ] || [ ! -f "$scheduler_lock" ]; then
  echo "atomic scheduler lock did not publish driver and renderer ownership" >&2
  exit 1
fi
env -u TMUX tmux -L "$socket" set -s @GHC_SL_SCHED_ACTIVE 0 ';' set -g status-left ALIVE
kill "$hang_pid" 2>/dev/null || true

# If the driver itself is SIGKILLed after publishing renderer ownership, loader
# cleanup must preserve the lock until that orphaned renderer exits.
for _ in $(seq 1 100); do
  [ ! -e "$scheduler_lock" ] && break
  sleep 0.05
done
cat >"$renderer" <<EOF
#!/bin/sh
exec python3 -c 'import os, time; f = open("$tmp/orphan-renderers", "a"); f.write(f"{os.getpid()}\\n"); f.flush(); time.sleep(30)'
EOF
chmod +x "$renderer"
env -u TMUX tmux -L "$socket" set -s @GHC_SL_SCHED_GEN 47 ';' \
  set -s @GHC_SL_SCHED_ACTIVE 1
env HOME="$home" TMPDIR="$lock_tmp" TMUX="$server_env" \
  GHC_TMUX_STATUS_DRIVER_DELAY_SECONDS=0 "$driver" >/dev/null 2>&1 &
orphan_driver_pid=$!
wait_for "orphan renderer ownership publication" file_is_nonempty "$tmp/orphan-renderers"
orphan_renderer_pid=$(tail -n 1 "$tmp/orphan-renderers")
orphan_lock_owner=$(cat "$scheduler_lock" 2>/dev/null || true)
if [ "$orphan_lock_owner" != "$orphan_driver_pid:$orphan_renderer_pid" ]; then
  echo "driver did not publish orphan renderer ownership" >&2
  exit 1
fi
kill -KILL "$orphan_driver_pid" 2>/dev/null || true
wait "$orphan_driver_pid" 2>/dev/null || true
driver_pids=()
for _ in $(seq 1 20); do
  env HOME="$home" TMPDIR="$lock_tmp" TMUX="$server_env" \
    "$driver" --recover >/dev/null 2>&1 &
  driver_pids+=("$!")
done
for driver_pid in "${driver_pids[@]}"; do
  wait "$driver_pid"
done
if [ ! -f "$scheduler_lock" ] || [ "$(wc -l <"$tmp/orphan-renderers" | tr -d ' ')" != "1" ]; then
  echo "cleanup removed a lock still owned by an orphan renderer" >&2
  exit 1
fi
kill "$orphan_renderer_pid" 2>/dev/null || true
env HOME="$home" TMPDIR="$lock_tmp" TMUX="$server_env" \
  "$driver" --recover >/dev/null 2>&1
if [ -e "$scheduler_lock" ]; then
  echo "cleanup did not reclaim orphaned renderer lock artifacts" >&2
  exit 1
fi
env -u TMUX tmux -L "$socket" set -s @GHC_SL_SCHED_ACTIVE 0

# Stale scheduler recovery has one elected reclaimer; concurrent status jobs
# must never overlap renderer executions.
cat >"$renderer" <<EOF
#!/bin/sh
if ! mkdir '$tmp/stale-render-active' 2>/dev/null; then
  : >'$tmp/stale-render-overlap'
fi
printf '%s\n' "\$\$" >>'$tmp/stale-render-invocations'
sleep 0.3
rmdir '$tmp/stale-render-active' 2>/dev/null || true
EOF
chmod +x "$renderer"
stale_lock="$scheduler_lock"
for _ in $(seq 1 100); do
  [ ! -e "$stale_lock" ] && break
  sleep 0.05
done
if [ -e "$stale_lock" ]; then
  echo "scheduler lock was not released after hung renderer termination" >&2
  exit 1
fi
mkdir "$stale_lock"
printf '%s\n' 999999 >"$stale_lock/owner"
env -u TMUX tmux -L "$socket" set -s @GHC_SL_SCHED_GEN 48 ';' \
  set -s @GHC_SL_SCHED_ACTIVE 1
driver_pids=()
for _ in $(seq 1 20); do
  env HOME="$home" TMPDIR="$lock_tmp" TMUX="$server_env" \
    GHC_TMUX_STATUS_DRIVER_DELAY_SECONDS=0 "$driver" >/dev/null 2>&1 &
  driver_pids+=("$!")
done
for driver_pid in "${driver_pids[@]}"; do
  wait "$driver_pid"
done
if [ -f "$tmp/stale-render-overlap" ]; then
  echo "stale lock recovery allowed overlapping renderers" >&2
  exit 1
fi
if [ ! -s "$tmp/stale-render-invocations" ]; then
  echo "stale scheduler lock was not recovered" >&2
  exit 1
fi
env -u TMUX tmux -L "$socket" set -s @GHC_SL_SCHED_ACTIVE 0

# Loader recovery and normal recovery share one server CAS lease. Concurrent
# cleanup reclaims a dead lease and removes only a lock with dead owners.
printf '%s\n' 999999 >"$stale_lock"
env -u TMUX tmux -L "$socket" set -s @GHC_SL_LOCK_RECOVERY_OWNER 999999
driver_pids=()
for _ in $(seq 1 20); do
  env HOME="$home" TMPDIR="$lock_tmp" TMUX="$server_env" \
    "$driver" --recover >/dev/null 2>&1 &
  driver_pids+=("$!")
done
for driver_pid in "${driver_pids[@]}"; do
  wait "$driver_pid"
done
if [ -e "$stale_lock" ]; then
  echo "loader recovery did not remove dead scheduler lock state" >&2
  exit 1
fi
if [ -n "$(env -u TMUX tmux -L "$socket" show -sqv @GHC_SL_LOCK_RECOVERY_OWNER)" ]; then
  echo "loader recovery lease was not released" >&2
  exit 1
fi

# A live driver or renderer owner blocks cleanup even if its peer PID is dead.
printf '%s:%s\n' 999999 "$$" >"$stale_lock"
env HOME="$home" TMPDIR="$lock_tmp" TMUX="$server_env" \
  "$driver" --recover >/dev/null 2>&1
if [ ! -f "$stale_lock" ]; then
  echo "loader recovery removed state owned by a live renderer" >&2
  exit 1
fi
unlink "$stale_lock"

# Empty/corrupt legacy state is conservatively retained. New lock acquisition
# cannot publish an empty owner because candidate content is written before link(2).
: >"$stale_lock"
env HOME="$home" TMPDIR="$lock_tmp" TMUX="$server_env" \
  "$driver" --recover >/dev/null 2>&1
if [ ! -f "$stale_lock" ]; then
  echo "loader recovery removed an unknown lock owner" >&2
  exit 1
fi
unlink "$stale_lock"

# A cleanup-lease read failure must fail closed. Even with a dead main-lock
# owner, normal recovery may not delete the lock or start the renderer.
mkdir -p "$tmp/fail-bin"
real_tmux=$(command -v tmux)
cat >"$tmp/fail-bin/tmux" <<EOF
#!/bin/sh
if [ "\${1:-}" = show ] && [ "\${2:-}" = -sqv ] \
  && [ "\${3:-}" = @GHC_SL_LOCK_RECOVERY_OWNER ]; then
  exit 1
fi
exec '$real_tmux' "\$@"
EOF
chmod +x "$tmp/fail-bin/tmux"
cat >"$renderer" <<EOF
#!/bin/sh
: >'$tmp/ipc-failure-renderer-ran'
exit 0
EOF
chmod +x "$renderer"
printf '%s\n' 999999 >"$stale_lock"
env -u TMUX tmux -L "$socket" set -s @GHC_SL_LOCK_RECOVERY_OWNER "$$" ';' \
  set -s @GHC_SL_SCHED_GEN 49 ';' set -s @GHC_SL_SCHED_ACTIVE 1
env PATH="$tmp/fail-bin:/usr/bin:/bin" HOME="$home" TMPDIR="$lock_tmp" \
  TMUX="$server_env" GHC_TMUX_STATUS_DRIVER_DELAY_SECONDS=0 \
  "$driver" >/dev/null 2>&1
if [ -f "$tmp/ipc-failure-renderer-ran" ] || [ ! -f "$stale_lock" ]; then
  echo "tmux cleanup-lease read failure did not fail closed" >&2
  exit 1
fi
env -u TMUX tmux -L "$socket" set -su @GHC_SL_LOCK_RECOVERY_OWNER
unlink "$stale_lock"

env -u TMUX tmux -L "$socket" display-message -p '#{pid}:alive' >/dev/null

printf '%s\n' "driver fault integration: ok"
