#!/usr/bin/env bash
set -euo pipefail

crate_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
repo_dir=$(cd "$crate_dir/../.." && pwd)
binary="$crate_dir/target/debug/ghc-tmux-status"
tmp=$(mktemp -d /tmp/ghc-tmux-render-lifecycle-test.XXXXXX)
socket="ghc-tmux-render-lifecycle-test-$$"
real_tmux=$(command -v tmux)
refresh_client_a_pid=
refresh_client_b_pid=

cleanup() {
  [ -z "$refresh_client_a_pid" ] || kill "$refresh_client_a_pid" 2>/dev/null || true
  [ -z "$refresh_client_b_pid" ] || kill "$refresh_client_b_pid" 2>/dev/null || true
  exec 9>&- 2>/dev/null || true
  exec 8>&- 2>/dev/null || true
  env -u TMUX tmux -L "$socket" kill-server 2>/dev/null || true
  rm -rf "$tmp"
}
trap cleanup EXIT

wait_for_file() {
  local path=$1
  for _ in $(seq 1 100); do
    if [ -e "$path" ]; then
      return 0
    fi
    sleep 0.02
  done
  echo "timed out waiting for $path" >&2
  return 1
}

wait_for_client_count() {
  local expected=$1
  local count=0
  for _ in $(seq 1 100); do
    count=$(env -u TMUX tmux -L "$socket" list-clients | wc -l | tr -d ' ')
    if [ "$count" -eq "$expected" ]; then
      return 0
    fi
    sleep 0.02
  done
  echo "timed out waiting for $expected clients; observed $count" >&2
  return 1
}

assert_refresh_context_guard() {
  local expected=$1
  local context=$2
  local actual
  env TMUX="$server_env" TMUX_PANE="$refresh_pane" "$real_tmux" \
    if-shell -F '#{!=:#{client_name},}' \
    'set -g @GHC_TEST_REFRESH_CONTEXT true' \
    'set -g @GHC_TEST_REFRESH_CONTEXT false'
  actual=$(env -u TMUX tmux -L "$socket" show -gqv @GHC_TEST_REFRESH_CONTEXT)
  if [ "$actual" != "$expected" ]; then
    echo "$context refresh context guard was $actual, expected $expected" >&2
    exit 1
  fi
}

fence_to_status01() {
  local generation=$1
  tmux -L "$socket" set -g @GHC_SL_MODE 01 ';' \
    set -s @GHC_SL_SCHED_ACTIVE 0 ';' \
    set -s @GHC_SL_SCHED_GEN "$generation" ';' \
    set -s @GHC_SL_RENDER_REV "fenced:$generation" ';' \
    set -g status-left STATUS01-LEFT ';' \
    set -g status-right STATUS01-RIGHT ';' \
    set -g status-interval 20
}

assert_status01_unchanged() {
  local state
  state=$(tmux -L "$socket" display-message -p \
    '#{@GHC_SL_MODE}	#{status-left}	#{status-right}	#{status-interval}')
  if [ "$state" != $'01\tSTATUS01-LEFT\tSTATUS01-RIGHT\t20' ]; then
    echo "stale renderer escaped lifecycle fence: $state" >&2
    exit 1
  fi
}

assert_fallback_status_unchanged() {
  local expected_generation=$1
  local state
  state=$(tmux -L "$socket" display-message -p \
    '#{@GHC_SL_MODE}	#{@GHC_SL_SCHED_ACTIVE}	#{@GHC_SL_SCHED_GEN}	#{status-left}	#{status-right}	#{status-interval}')
  if [ "$state" != "02"$'\t'"0"$'\t'"$expected_generation"$'\t'"STATUS01-LEFT"$'\t'"STATUS01-RIGHT"$'\t'"20" ]; then
    echo "stale bootstrap escaped lifecycle generation: $state" >&2
    exit 1
  fi
}

cargo build --quiet --manifest-path "$crate_dir/Cargo.toml"
env -u TMUX tmux -L "$socket" -f /dev/null new-session -d -s lifecycle -x 120 -y 30
server_env=$(tmux -L "$socket" display-message -p '#{socket_path},#{pid},0')
refresh_pane=$(tmux -L "$socket" display-message -p -t lifecycle:0.0 '#{pane_id}')

# A standard apply that already captured status02 must not commit after the loader
# fences lifecycle and installs status01.
mkdir -p "$tmp/after/bin"
cat >"$tmp/after/bin/tmux" <<'EOF'
#!/bin/sh
if (set -C; : >"$GHC_TMUX_FIRST_CALL") 2>/dev/null; then
  "$GHC_TMUX_REAL_TMUX" "$@" >"$GHC_TMUX_FIRST_STDOUT" 2>"$GHC_TMUX_FIRST_STDERR"
  status=$?
  : >"$GHC_TMUX_FIRST_READY"
  sleep 0.5
  cat "$GHC_TMUX_FIRST_STDOUT"
  cat "$GHC_TMUX_FIRST_STDERR" >&2
  exit "$status"
fi
exec "$GHC_TMUX_REAL_TMUX" "$@"
EOF
chmod +x "$tmp/after/bin/tmux"

tmux -L "$socket" set -g @GHC_SL_MODE 02 ';' \
  set -s @GHC_SL_SCHED_ACTIVE 1 ';' \
  set -s @GHC_SL_SCHED_GEN 41 ';' \
  set -g status on
env \
  TMUX="$server_env" \
  PATH="$tmp/after/bin:$PATH" \
  GHC_TMUX_REAL_TMUX="$real_tmux" \
  GHC_TMUX_FIRST_CALL="$tmp/after/first-call" \
  GHC_TMUX_FIRST_READY="$tmp/after/first-ready" \
  GHC_TMUX_FIRST_STDOUT="$tmp/after/first-stdout" \
  GHC_TMUX_FIRST_STDERR="$tmp/after/first-stderr" \
  "$binary" apply client-resized >"$tmp/after/apply-stdout" 2>"$tmp/after/apply-stderr" &
apply_pid=$!
wait_for_file "$tmp/after/first-ready"
fence_to_status01 42
wait "$apply_pid"
assert_status01_unchanged

# A hook process that was spawned earlier but reaches tmux only after the fence
# must be rejected before it can replace @GHC_SL_RENDER_REV.
mkdir -p "$tmp/before/bin"
cat >"$tmp/before/bin/tmux" <<'EOF'
#!/bin/sh
if (set -C; : >"$GHC_TMUX_FIRST_CALL") 2>/dev/null; then
  : >"$GHC_TMUX_FIRST_READY"
  sleep 0.5
fi
exec "$GHC_TMUX_REAL_TMUX" "$@"
EOF
chmod +x "$tmp/before/bin/tmux"

tmux -L "$socket" set -g @GHC_SL_MODE 02 ';' \
  set -s @GHC_SL_SCHED_ACTIVE 1 ';' \
  set -s @GHC_SL_SCHED_GEN 43 ';' \
  set -g status on
env \
  TMUX="$server_env" \
  PATH="$tmp/before/bin:$PATH" \
  GHC_TMUX_REAL_TMUX="$real_tmux" \
  GHC_TMUX_FIRST_CALL="$tmp/before/first-call" \
  GHC_TMUX_FIRST_READY="$tmp/before/first-ready" \
  "$binary" apply client-resized >"$tmp/before/apply-stdout" 2>"$tmp/before/apply-stderr" &
apply_pid=$!
wait_for_file "$tmp/before/first-ready"
fence_to_status01 44
wait "$apply_pid"
assert_status01_unchanged

# A stale theme bootstrap must retain the generation passed by its loader. It
# may not adopt a newer fallback generation merely because lifecycle is inactive.
tmux -L "$socket" set -g @GHC_SL_MODE 02 ';' \
  set -s @GHC_SL_SCHED_ACTIVE 0 ';' \
  set -s @GHC_SL_SCHED_GEN 45 ';' \
  set -s @GHC_SL_RENDER_REV fenced:45 ';' \
  set -g status on
env \
  TMUX="$server_env" \
  PATH="$tmp/before/bin:$PATH" \
  GHC_TMUX_REAL_TMUX="$real_tmux" \
  GHC_TMUX_FIRST_CALL="$tmp/before/bootstrap-first-call" \
  GHC_TMUX_FIRST_READY="$tmp/before/bootstrap-first-ready" \
  "$binary" apply theme-loaded 45 \
  >"$tmp/before/bootstrap-stdout" 2>"$tmp/before/bootstrap-stderr" &
bootstrap_pid=$!
wait_for_file "$tmp/before/bootstrap-first-ready"
tmux -L "$socket" set -s @GHC_SL_SCHED_ACTIVE 0 ';' \
  set -s @GHC_SL_SCHED_GEN 46 ';' \
  set -s @GHC_SL_RENDER_REV fenced:46 ';' \
  set -g status-left STATUS01-LEFT ';' \
  set -g status-right STATUS01-RIGHT ';' \
  set -g status-interval 20
if wait "$bootstrap_pid"; then
  echo "stale theme bootstrap unexpectedly succeeded" >&2
  exit 1
fi
assert_fallback_status_unchanged 46

# A current-generation bootstrap whose render revision loses after snapshot must
# observe Skipped, retry from a fresh snapshot, and converge before activation.
tmux -L "$socket" set -g @GHC_SL_MODE 02 ';' \
  set -s @GHC_SL_SCHED_ACTIVE 0 ';' \
  set -s @GHC_SL_SCHED_GEN 47 ';' \
  set -s @GHC_SL_RENDER_REV fenced:47 ';' \
  set -g status on ';' \
  set -g status-left '#{E:@GHC_SL_STATUS02_LEFT}' ';' \
  set -g status-right '#{E:@GHC_SL_STATUS02_RIGHT}' ';' \
  set -g status-interval 20
env \
  TMUX="$server_env" \
  PATH="$tmp/after/bin:$PATH" \
  GHC_TMUX_REAL_TMUX="$real_tmux" \
  GHC_TMUX_FIRST_CALL="$tmp/after/bootstrap-first-call" \
  GHC_TMUX_FIRST_READY="$tmp/after/bootstrap-first-ready" \
  GHC_TMUX_FIRST_STDOUT="$tmp/after/bootstrap-first-stdout" \
  GHC_TMUX_FIRST_STDERR="$tmp/after/bootstrap-first-stderr" \
  "$binary" apply theme-loaded 47 \
  >"$tmp/after/bootstrap-stdout" 2>"$tmp/after/bootstrap-stderr" &
bootstrap_pid=$!
wait_for_file "$tmp/after/bootstrap-first-ready"
tmux -L "$socket" set -s @GHC_SL_RENDER_REV competing-bootstrap
wait "$bootstrap_pid"
status_left=$(tmux -L "$socket" show -gqv status-left)
case "$status_left" in
  '#($HOME/.config/tmux/script/status-scheduler.sh)'*) ;;
  *) echo "bootstrap did not recover a skipped commit: $status_left" >&2; exit 1 ;;
esac
if [ "$(tmux -L "$socket" show -gqv status-interval)" != "1" ]; then
  echo "bootstrap retry did not converge status interval" >&2
  exit 1
fi

# theme-loaded is the sole bootstrap writer while lifecycle is inactive.
tmux -L "$socket" set -g @GHC_SL_MODE 02 ';' \
  set -s @GHC_SL_SCHED_ACTIVE 0 ';' \
  set -s @GHC_SL_SCHED_GEN 48 ';' \
  set -s @GHC_SL_RENDER_REV fenced:48 ';' \
  set -g status on
env TMUX="$server_env" "$binary" apply theme-loaded 48
status_left=$(tmux -L "$socket" show -gqv status-left)
case "$status_left" in
  '#($HOME/.config/tmux/script/status-scheduler.sh)'*) ;;
  *) echo "bootstrap render did not install the scheduler driver: $status_left" >&2; exit 1 ;;
esac

# Exercise the actual loader boundary, including fenced render revision and
# generation-CAS scheduler activation, in an isolated HOME.
loader_home="$tmp/loader-home"
loader_root="$loader_home/.config/tmux"
mkdir -p \
  "$loader_root/script" \
  "$loader_root/conf/theme" \
  "$loader_root/rust/ghc-tmux-status/target/release"
cp "$repo_dir/script/load-theme.sh" "$loader_root/script/load-theme.sh"
cp "$repo_dir/script/status-scheduler.sh" "$loader_root/script/status-scheduler.sh"
cp "$repo_dir/conf/theme.tmux.conf" "$loader_root/conf/theme.tmux.conf"
cp "$repo_dir/conf/theme/"{status01,status02,panestatus01,panestatus02}.tmux.conf \
  "$loader_root/conf/theme/"
cp "$binary" "$loader_root/rust/ghc-tmux-status/target/release/ghc-tmux-status"
tmux -L "$socket" set-environment -g HOME "$loader_home"
env HOME="$loader_home" TMUX="$server_env" bash "$loader_root/script/load-theme.sh"
loader_state=$(tmux -L "$socket" display-message -p \
  '#{@GHC_SL_MODE}	#{@GHC_SL_SCHED_ACTIVE}	#{status-left}	#{status-interval}')
case "$loader_state" in
  $'02\t1\t#($HOME/.config/tmux/script/status-scheduler.sh)'*$'\t1') ;;
  *) echo "loader did not converge and activate status02: $loader_state" >&2; exit 1 ;;
esac

# A non-empty standard render folds its guarded status refresh into the final
# commit queue, avoiding a third tmux process.
mkdir -p "$tmp/folded-refresh/bin"
cat >"$tmp/folded-refresh/bin/tmux" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$GHC_TMUX_CALL_LOG"
if [ -n "${GHC_TMUX_FAIL_FOLDED_ONCE:-}" ] && \
  [ ! -e "$GHC_TMUX_FAIL_FOLDED_ONCE" ]; then
  case "$*" in
    *client_name*refresh-client*)
      : >"$GHC_TMUX_FAIL_FOLDED_ONCE"
      exit 1
      ;;
  esac
fi
exec "$GHC_TMUX_REAL_TMUX" "$@"
EOF
chmod +x "$tmp/folded-refresh/bin/tmux"

assert_folded_call_log() {
  local context=$1
  local call_count
  call_count=$(wc -l <"$tmp/folded-refresh/calls" | tr -d ' ')
  if [ "$call_count" -ne 2 ]; then
    echo "$context standard render used $call_count tmux calls instead of 2" >&2
    exit 1
  fi
  if ! awk '/client_name/ && /refresh-client/ { found = 1 } END { exit !found }' \
    "$tmp/folded-refresh/calls"; then
    echo "$context standard render did not fold the guarded refresh" >&2
    exit 1
  fi
}

# Without an attached client, the context guard must skip refresh while the
# mutation and applied marker still complete in the folded queue.
assert_refresh_context_guard false detached
tmux -L "$socket" set -g @GHC_SL_MODE 02 ';' \
  set -s @GHC_SL_SCHED_ACTIVE 1 ';' \
  set -s @GHC_SL_SCHED_GEN 49 ';' \
  set -g status on ';' \
  set -g status-left STALE-LEFT
env \
  HOME="$loader_home" \
  TMUX="$server_env" \
  PATH="$tmp/folded-refresh/bin:$PATH" \
  GHC_TMUX_CALL_LOG="$tmp/folded-refresh/calls" \
  GHC_TMUX_REAL_TMUX="$real_tmux" \
  "$binary" apply client-resized
assert_folded_call_log detached
if [ "$(tmux -L "$socket" show -gqv status-left)" = "STALE-LEFT" ]; then
  echo "detached standard render did not commit" >&2
  exit 1
fi

# Hold real control-mode clients open so the same predicate is evaluated by
# tmux with one and then two attached client contexts.
mkfifo \
  "$tmp/folded-refresh/client-a.in" \
  "$tmp/folded-refresh/client-b.in"
exec 9<>"$tmp/folded-refresh/client-a.in"
exec 8<>"$tmp/folded-refresh/client-b.in"
env -u TMUX "$real_tmux" -L "$socket" -C attach-session -t lifecycle \
  <&9 >"$tmp/folded-refresh/client-a.out" 2>&1 &
refresh_client_a_pid=$!
wait_for_client_count 1
assert_refresh_context_guard true one-client

: >"$tmp/folded-refresh/calls"
tmux -L "$socket" set -g status-left STALE-ATTACHED-LEFT
env \
  HOME="$loader_home" \
  TMUX="$server_env" \
  TMUX_PANE="$refresh_pane" \
  PATH="$tmp/folded-refresh/bin:$PATH" \
  GHC_TMUX_CALL_LOG="$tmp/folded-refresh/calls" \
  GHC_TMUX_REAL_TMUX="$real_tmux" \
  "$binary" apply client-resized
assert_folded_call_log attached
if [ "$(tmux -L "$socket" show -gqv status-left)" = "STALE-ATTACHED-LEFT" ]; then
  echo "attached standard render did not commit" >&2
  exit 1
fi

env -u TMUX "$real_tmux" -L "$socket" -C attach-session -t lifecycle \
  <&8 >"$tmp/folded-refresh/client-b.out" 2>&1 &
refresh_client_b_pid=$!
wait_for_client_count 2
assert_refresh_context_guard true two-client

# If the final folded queue fails, the standard path retains its existing
# per-command retry and follows it with the original best-effort refresh.
: >"$tmp/folded-refresh/calls"
tmux -L "$socket" set -g status-left STALE-LEFT-AGAIN
env \
  HOME="$loader_home" \
  TMUX="$server_env" \
  PATH="$tmp/folded-refresh/bin:$PATH" \
  GHC_TMUX_CALL_LOG="$tmp/folded-refresh/calls" \
  GHC_TMUX_FAIL_FOLDED_ONCE="$tmp/folded-refresh/failed-once" \
  GHC_TMUX_REAL_TMUX="$real_tmux" \
  "$binary" apply client-resized
if [ "$(tmux -L "$socket" show -gqv status-left)" = "STALE-LEFT-AGAIN" ]; then
  echo "standard render did not recover from a folded commit failure" >&2
  exit 1
fi
if ! awk '
  /refresh-client/ && !/client_name/ { found = 1 }
  END { exit !found }
' "$tmp/folded-refresh/calls"; then
  echo "folded commit fallback omitted the separate refresh" >&2
  exit 1
fi

printf '%s\n' "renderer lifecycle integration: ok"
