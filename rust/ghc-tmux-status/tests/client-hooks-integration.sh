#!/usr/bin/env bash
set -euo pipefail

crate_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
repo_dir=$(cd "$crate_dir/../.." && pwd)
binary="$crate_dir/target/debug/ghc-tmux-status"
tmp=$(mktemp -d /tmp/ghc-tmux-client-hooks-test.XXXXXX)
socket="ghc-tmux-client-hooks-test-$$"
client_pids=()
started_client_pid=""

cleanup() {
  env -u TMUX tmux -L "$socket" kill-server 2>/dev/null || true
  for client_pid in "${client_pids[@]}"; do
    kill "$client_pid" 2>/dev/null || true
    wait "$client_pid" 2>/dev/null || true
  done
  rm -rf "$tmp"
}
trap cleanup EXIT

fail() {
  echo "$*" >&2
  exit 1
}

wait_for_file() {
  local path=$1
  for _ in $(seq 1 250); do
    if [ -e "$path" ]; then
      return 0
    fi
    sleep 0.02
  done
  fail "timed out waiting for $path"
}

wait_for_process_exit() {
  local pid=$1
  if ! [[ "$pid" =~ ^[0-9]+$ ]]; then
    fail "invalid process id: $pid"
  fi
  for _ in $(seq 1 250); do
    if ! kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
    sleep 0.02
  done
  fail "timed out waiting for process $pid to exit"
}

tmux_server() {
  env -u TMUX tmux -L "$socket" "$@"
}

if ! command -v script >/dev/null 2>&1; then
  fail "client hooks integration requires a PTY launcher: script not found"
fi

case $(uname -s) in
  Darwin | Linux) ;;
  *) fail "client hooks integration has no script(1) driver for $(uname -s)" ;;
esac

start_client() {
  local label=$1
  local columns=$2
  local session=$3
  local command="stty cols $columns rows 40; exec env -u TMUX TERM=xterm-256color tmux -L '$socket' attach-session -t '$session'"
  local log="$tmp/client-$label.log"

  case $(uname -s) in
    Darwin)
      script -q /dev/null sh -c "$command" </dev/null >"$log" 2>&1 &
      ;;
    Linux)
      script -q -c "$command" /dev/null </dev/null >"$log" 2>&1 &
      ;;
  esac
  started_client_pid=$!
  client_pids+=("$started_client_pid")
}

wait_for_client_count() {
  local expected=$1
  local count=""
  for _ in $(seq 1 150); do
    count=$(tmux_server list-clients 2>/dev/null | wc -l | tr -d ' ')
    if [ "$count" = "$expected" ]; then
      return 0
    fi
    sleep 0.02
  done
  for log in "$tmp"/client-*.log; do
    if [ -f "$log" ]; then
      printf '%s\n' "PTY client log ($log):" >&2
      tail -20 "$log" >&2
    fi
  done
  fail "timed out waiting for $expected clients; observed $count"
}

client_tty_for_session() {
  local session=$1
  tmux_server list-clients -F '#{client_tty}|#{session_name}' \
    | awk -F '|' -v session="$session" '$2 == session { print $1; exit }'
}

session_state() {
  local session=$1
  tmux_server list-sessions \
    -F '#{session_name}|#{status}|#{@GHC_SL_LAYOUT}|#{@GHC_SL_RENDER_KEY}' \
    | awk -F '|' -v session="$session" \
      '$1 == session { print $2 "|" $3 "|" $4; exit }'
}

wait_for_session_state() {
  local session=$1
  local expected_status=$2
  local expected_layout=$3
  local state=""
  for _ in $(seq 1 250); do
    state=$(session_state "$session")
    case "$state" in
      "$expected_status|$expected_layout|"?*) return 0 ;;
    esac
    sleep 0.02
  done
  fail "session $session did not converge to $expected_status|$expected_layout|<render-key>; observed $state"
}

wait_for_global_option() {
  local option=$1
  local expected=$2
  local attempts=$3
  local value=""
  for _ in $(seq 1 "$attempts"); do
    value=$(tmux_server show -gqv "$option")
    if [ "$value" = "$expected" ]; then
      return 0
    fi
    sleep 0.02
  done
  fail "timed out waiting for $option=$expected; observed $value"
}

wait_for_render_key_change() {
  local session=$1
  local previous=$2
  local state=""
  local key=""
  for _ in $(seq 1 250); do
    state=$(session_state "$session")
    key=${state##*|}
    if [ -n "$key" ] && [ "$key" != "$previous" ]; then
      return 0
    fi
    sleep 0.02
  done
  fail "session $session render key did not change after session close; observed $state"
}

assert_background_hook() {
  local hook=$1
  local event=$2
  local renderer=$3
  local actual
  actual=$(tmux_server show-hooks -g "$hook")
  if [[ "$actual" != *"run-shell -b"* \
    || "$actual" != *"$renderer apply $event"* \
    || "$actual" != *">/dev/null 2>&1 || true"* ]]; then
    fail "hook $hook is not the expected failure-isolated background renderer: $actual"
  fi
}

cargo build --quiet --manifest-path "$crate_dir/Cargo.toml"
tmux_server -f /dev/null new-session -d -s vscode -x 220 -y 40 'sleep 60'
tmux_server new-session -d -s other -x 100 -y 30 'sleep 60'
server_env=$(tmux_server display-message -p '#{socket_path},#{pid},0')

loader_home="$tmp/loader-home"
loader_root="$loader_home/.config/tmux"
renderer="$loader_root/rust/ghc-tmux-status/target/release/ghc-tmux-status"
mkdir -p \
  "$loader_root/script" \
  "$loader_root/conf/theme" \
  "$(dirname "$renderer")"
cp "$repo_dir/script/load-theme.sh" "$loader_root/script/load-theme.sh"
cp "$repo_dir/conf/theme.tmux.conf" "$loader_root/conf/theme.tmux.conf"
cp "$repo_dir/conf/theme/"{status01,status02,panestatus01,panestatus02}.tmux.conf \
  "$loader_root/conf/theme/"
cp "$binary" "$renderer"

# The status #() command is irrelevant to hook reconciliation. Keep it inert so
# no scheduler event can hide a failed single-event convergence assertion.
cat >"$loader_root/script/status-scheduler.sh" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$loader_root/script/status-scheduler.sh"

tmux_server set-environment -g HOME "$loader_home"
tmux_server set -g @GHC_SL_MODE 02
env HOME="$loader_home" TMUX="$server_env" bash "$loader_root/script/load-theme.sh"

assert_background_hook 'client-attached[40]' client-resized "$renderer"
assert_background_hook 'client-detached[40]' client-resized "$renderer"
assert_background_hook 'client-resized[40]' client-resized "$renderer"
assert_background_hook 'client-session-changed[40]' session-changed "$renderer"
assert_background_hook 'session-created[40]' session-created "$renderer"
assert_background_hook 'session-closed[40]' session-closed "$renderer"
assert_background_hook 'session-renamed[40]' session-renamed "$renderer"
assert_background_hook 'session-window-changed[40]' window-changed "$renderer"
if [[ $(tmux_server show-hooks -g) == *"theme-loaded"* ]]; then
  fail "theme-loaded bootstrap must remain outside the asynchronous hook set"
fi

start_client a 220 vscode
start_client b 80 other
wait_for_client_count 2
wait_for_session_state vscode on 02:wide
wait_for_session_state other 2 02:narrow
client_b_tty=$(client_tty_for_session other)
[ -n "$client_b_tty" ] || fail "could not resolve client B"

# The delayed shim covers queue ordering while the real renderer beneath it
# covers re-entrant tmux calls and convergence. Its final output and exit 23
# exercise the background job failure boundary.
mv "$renderer" "$renderer.real"
cat >"$renderer" <<'EOF'
#!/bin/sh
printf '%s\n' "$$" >"$0.pid"
: >"$0.started"
sleep 2
: >"$0.before-real"
"$0.real" "$@"
printf '%s\n' 'renderer stdout must not reach tmux'
printf '%s\n' 'renderer stderr must not reach tmux' >&2
printf '%s\n' 23 >"$0.exit"
exit 23
EOF
chmod +x "$renderer"
tmux_server set-hook -g 'client-session-changed[50]' \
  'set -g @GHC_CLIENT_HOOK_AFTER background-reached'
tmux_server set -gu @GHC_CLIENT_HOOK_AFTER 2>/dev/null || true
tmux_server switch-client -c "$client_b_tty" -t vscode
wait_for_global_option @GHC_CLIENT_HOOK_AFTER background-reached 25
wait_for_file "$renderer.started"
if [ -e "$renderer.before-real" ]; then
  fail "background renderer completed its two-second delay before the following hook ran"
fi

# Restore the real path atomically for later events. Replacing the directory
# entry keeps the running shell on the shim inode; truncating it in place could
# make that shell lose the remaining exec line after its sleep.
cp "$renderer.real" "$renderer.restored"
mv "$renderer.restored" "$renderer"
tmux_server set-hook -gu 'client-session-changed[50]'
wait_for_file "$renderer.exit"
if [ "$(cat "$renderer.exit")" != "23" ]; then
  fail "fault renderer did not exercise the expected exit 23"
fi
wait_for_process_exit "$(cat "$renderer.pid")"
wait_for_session_state vscode 2 02:narrow
# The renderer exits just before its outer `sh -c` wrapper. Keep observing long
# enough for a delayed job-completion callback to expose any view-mode failure.
for _ in $(seq 1 50); do
  while IFS='|' read -r pane_id pane_in_mode pane_mode; do
    if [ "$pane_in_mode" != "0" ]; then
      fail "background renderer failure put $pane_id into ${pane_mode:-an unknown mode}"
    fi
  done < <(tmux_server list-panes -a -F '#{pane_id}|#{pane_in_mode}|#{pane_mode}')
  sleep 0.02
done

# client-detached must survive destruction of its triggering client and widen
# the remaining session from the authoritative attached-width set. Remove the
# resize/session-change fallbacks so only the dedicated detach hook can do it.
tmux_server set-hook -gu 'client-resized[40]'
tmux_server set-hook -gu 'client-session-changed[40]'
tmux_server detach-client -t "$client_b_tty"
wait_for_client_count 1
wait_for_session_state vscode on 02:wide

# A direct attach is not guaranteed to emit client-session-changed. The
# dedicated client-attached hook must narrow the target without another event.
start_client c 80 vscode
wait_for_client_count 2
wait_for_session_state vscode 2 02:narrow
client_c_tty=$(tmux_server list-clients -F '#{client_tty}|#{client_width}' \
  | awk -F '|' '$2 == 80 { print $1; exit }')
[ -n "$client_c_tty" ] || fail "could not resolve client C"
tmux_server detach-client -t "$client_c_tty"
wait_for_client_count 1
wait_for_session_state vscode on 02:wide

# Isolate session-closed as the only remaining renderer notification, then
# prove its server-wide background job survives destruction of its source.
for hook in \
  'client-attached[40]' \
  'client-detached[40]' \
  'client-resized[40]' \
  'client-session-changed[40]' \
  'session-created[40]' \
  'session-renamed[40]' \
  'session-window-changed[40]'; do
  tmux_server set-hook -gu "$hook" 2>/dev/null || true
done
state_before_close=$(session_state vscode)
render_key_before_close=${state_before_close##*|}
tmux_server kill-session -t other
wait_for_render_key_change vscode "$render_key_before_close"
wait_for_session_state vscode on 02:wide

printf '%s\n' "client hooks integration: ok"
