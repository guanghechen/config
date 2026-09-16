#!/usr/bin/env bash
set -euo pipefail

crate_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
repo_dir=$(cd "$crate_dir/../.." && pwd)
tmp=$(mktemp -d /tmp/ghc-tmux-focus-session-test.XXXXXX)
socket="$tmp/tmux.sock"
real_tmux=$(command -v tmux)
client_pid=

cleanup() {
  [ -z "$client_pid" ] || kill "$client_pid" 2>/dev/null || true
  [ -z "$client_pid" ] || wait "$client_pid" 2>/dev/null || true
  exec 9>&- 2>/dev/null || true
  env -u TMUX "$real_tmux" -S "$socket" kill-server 2>/dev/null || true
  rm -rf "$tmp"
}
trap cleanup EXIT

fail() {
  echo "$*" >&2
  exit 1
}

test_home="$tmp/home"
renderer="$test_home/.config/tmux/rust/ghc-tmux-status/target/release/ghc-tmux-status"
mkdir -p "$(dirname "$renderer")" "$tmp/bin"

cat >"$renderer" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$GHC_FOCUS_RENDERER_CALLS"
if [ "${1-}" = "help" ]; then
  printf '%s\n' 'session focus <prev|next|index>'
  exit 0
fi
printf '%s\n' 'renderer stdout must not reach run-shell'
printf '%s\n' 'renderer stderr must not reach run-shell' >&2
exit "${GHC_FAKE_RENDERER_EXIT:-1}"
EOF
chmod +x "$renderer"

cat >"$tmp/bin/tmux" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$GHC_FOCUS_TMUX_CALLS"
EOF
chmod +x "$tmp/bin/tmux"

renderer_calls="$tmp/renderer-calls"
tmux_calls="$tmp/tmux-calls"

set +e
output=$(env \
  HOME="$test_home" \
  PATH="$tmp/bin:$PATH" \
  GHC_FOCUS_RENDERER_CALLS="$renderer_calls" \
  GHC_FOCUS_TMUX_CALLS="$tmux_calls" \
  bash "$repo_dir/script/focus-session.sh" prev 2>&1)
status=$?
set -e

[ "$status" = "0" ] || fail "focus helper propagated renderer exit $status"
[ -z "$output" ] || fail "focus helper leaked renderer output: $output"
[ "$(cat "$tmux_calls")" = "display-message Session focus failed" ] \
  || fail "focus helper did not degrade to the expected status message"
[ "$(tail -1 "$renderer_calls")" = "session focus prev" ] \
  || fail "focus helper did not call the renderer with the requested target"

: >"$renderer_calls"
: >"$tmux_calls"
output=$(env \
  HOME="$test_home" \
  PATH="$tmp/bin:$PATH" \
  GHC_FAKE_RENDERER_EXIT=0 \
  GHC_FOCUS_RENDERER_CALLS="$renderer_calls" \
  GHC_FOCUS_TMUX_CALLS="$tmux_calls" \
  bash "$repo_dir/script/focus-session.sh" next 2>&1)

[ -z "$output" ] || fail "successful focus leaked renderer output: $output"
[ ! -s "$tmux_calls" ] || fail "successful focus emitted a failure message"
[ "$(tail -1 "$renderer_calls")" = "session focus next" ] \
  || fail "successful focus did not preserve the requested target"

# The last navigation record can end in a valid session-name space. The runtime
# must preserve it so prev/next can locate the current session before switching.
cargo build --quiet --locked --offline --manifest-path "$crate_dir/Cargo.toml"
binary="$crate_dir/target/debug/ghc-tmux-status"
env -u TMUX "$real_tmux" -S "$socket" -f /dev/null \
  new-session -d -s alpha '/bin/sleep 60'
spaced_pane=$(env -u TMUX "$real_tmux" -S "$socket" \
  new-session -dP -F '#{pane_id}' -s 'zeta  ' '/bin/sleep 60')
server_env=$(env -u TMUX "$real_tmux" -S "$socket" \
  display-message -p -t "$spaced_pane" '#{socket_path},#{pid},0')
mkfifo "$tmp/client.in"
exec 9<>"$tmp/client.in"
env -u TMUX "$real_tmux" -S "$socket" -C attach-session -t "$spaced_pane" \
  <&9 >"$tmp/client.log" 2>&1 &
client_pid=$!
client_ready=0
for _ in $(seq 1 100); do
  if [ "$(env -u TMUX "$real_tmux" -S "$socket" list-clients -F '#{session_name}')" = 'zeta  ' ]; then
    client_ready=1
    break
  fi
  sleep 0.02
done
[ "$client_ready" = "1" ] || fail "control client did not attach to the spaced session"

output=$(env TMUX="$server_env" TMUX_PANE="$spaced_pane" \
  "$binary" session focus prev 2>&1)
[ -z "$output" ] || fail "focus from a spaced session leaked output: $output"
[ "$(env -u TMUX "$real_tmux" -S "$socket" list-clients -F '#{session_name}')" = alpha ] \
  || fail "trailing session-name spaces prevented previous-session focus"

printf '%s\n' "focus session integration: ok"
