#!/usr/bin/env bash
set -euo pipefail

crate_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
repo_dir=$(cd "$crate_dir/../.." && pwd)
tmp=$(mktemp -d /tmp/ghc-tmux-focus-session-test.XXXXXX)

cleanup() {
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

printf '%s\n' "focus session integration: ok"
