#!/usr/bin/env bash
set -euo pipefail

crate_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
repo_dir=$(cd "$crate_dir/../.." && pwd)
tmp=$(mktemp -d /tmp/ghc-tmux-swap-session-test.XXXXXX)
socket="ghc-tmux-swap-session-test-$$"
real_tmux=$(command -v tmux)

cleanup() {
  env -u TMUX "$real_tmux" -L "$socket" kill-server 2>/dev/null || true
  rm -rf "$tmp"
}
trap cleanup EXIT

fail() {
  printf '%s\n' "$*" >&2
  exit 1
}

wrapper_home="$tmp/wrapper-home"
wrapper_renderer="$wrapper_home/.config/tmux/rust/ghc-tmux-status/target/release/ghc-tmux-status"
wrapper_bin="$tmp/wrapper-bin"
wrapper_renderer_calls="$tmp/wrapper-renderer-calls"
wrapper_tmux_calls="$tmp/wrapper-tmux-calls"
mkdir -p "$(dirname "$wrapper_renderer")" "$wrapper_bin"

cat >"$wrapper_renderer" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$GHC_SWAP_RENDERER_CALLS"
printf '%s\n' 'renderer stdout must not reach run-shell'
printf '%s\n' 'renderer stderr must not reach run-shell' >&2
exit "${GHC_FAKE_SWAP_EXIT:-1}"
EOF
chmod +x "$wrapper_renderer"

cat >"$wrapper_bin/tmux" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$GHC_SWAP_TMUX_CALLS"
EOF
chmod +x "$wrapper_bin/tmux"

set +e
output=$(env \
  HOME="$wrapper_home" \
  PATH="$wrapper_bin:$PATH" \
  GHC_SWAP_RENDERER_CALLS="$wrapper_renderer_calls" \
  GHC_SWAP_TMUX_CALLS="$wrapper_tmux_calls" \
  bash "$repo_dir/script/swap-session.sh" prev 2>&1)
status=$?
set -e

[ "$status" = "0" ] || fail "swap wrapper propagated renderer exit $status"
[ -z "$output" ] || fail "swap wrapper leaked renderer output: $output"
[ "$(cat "$wrapper_tmux_calls")" = "display-message Session swap failed" ] \
  || fail "swap wrapper did not isolate renderer failure"
[ "$(cat "$wrapper_renderer_calls")" = "session swap prev" ] \
  || fail "swap wrapper did not preserve the requested direction"

: >"$wrapper_renderer_calls"
: >"$wrapper_tmux_calls"
output=$(env \
  HOME="$wrapper_home" \
  PATH="$wrapper_bin:$PATH" \
  GHC_FAKE_SWAP_EXIT=0 \
  GHC_SWAP_RENDERER_CALLS="$wrapper_renderer_calls" \
  GHC_SWAP_TMUX_CALLS="$wrapper_tmux_calls" \
  bash "$repo_dir/script/swap-session.sh" next 2>&1)

[ -z "$output" ] || fail "successful swap leaked renderer output: $output"
[ ! -s "$wrapper_tmux_calls" ] || fail "successful swap emitted a failure message"
[ "$(cat "$wrapper_renderer_calls")" = "session swap next" ] \
  || fail "successful swap did not preserve the requested direction"

chmod -x "$wrapper_renderer"
: >"$wrapper_tmux_calls"
output=$(env \
  HOME="$wrapper_home" \
  PATH="$wrapper_bin:$PATH" \
  GHC_SWAP_RENDERER_CALLS="$wrapper_renderer_calls" \
  GHC_SWAP_TMUX_CALLS="$wrapper_tmux_calls" \
  bash "$repo_dir/script/swap-session.sh" prev 2>&1)

[ -z "$output" ] || fail "unavailable swap leaked output: $output"
[ "$(cat "$wrapper_tmux_calls")" = "display-message Session swap unavailable" ] \
  || fail "missing renderer did not report unavailable swap"

cargo build --quiet --manifest-path "$crate_dir/Cargo.toml"
binary="$crate_dir/target/debug/ghc-tmux-status"
runtime_bin="$tmp/runtime-bin"
runtime_tmux_calls="$tmp/runtime-tmux-calls"
mkdir -p "$runtime_bin"

cat >"$runtime_bin/tmux" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$GHC_SWAP_TMUX_CALLS"

if [ "${GHC_SWAP_FORCE_CONFLICT:-0}" = "1" ] \
  && [ "${1-}" = "if-shell" ] \
  && [ -n "${GHC_SWAP_REVISION_OPTION:-}" ]; then
  case "$*" in
    *"$GHC_SWAP_REVISION_OPTION"*)
      "$GHC_SWAP_REAL_TMUX" set -s "$GHC_SWAP_REVISION_OPTION" "forced-$$" || exit
      ;;
  esac
fi

if [ "${GHC_SWAP_DELAY_AFTER_CAS:-0}" = "1" ] \
  && [ "${1-}" = "if-shell" ] \
  && [ -n "${GHC_SWAP_REVISION_OPTION:-}" ] \
  && [ -n "${GHC_SWAP_DELAY_MARKER:-}" ] \
  && [ ! -e "$GHC_SWAP_DELAY_MARKER" ]; then
  case "$*" in
    *"$GHC_SWAP_REVISION_OPTION"*)
      output=$("$GHC_SWAP_REAL_TMUX" "$@")
      status=$?
      : >"$GHC_SWAP_DELAY_MARKER"
      if [ "${GHC_SWAP_REPLACE_AFTER_CAS:-0}" = "1" ]; then
        "$GHC_SWAP_REAL_TMUX" set -g '@GHC_SL_SESSION_ORDER' "$GHC_SWAP_REPLACEMENT_ORDER" ';' \
          set -s "$GHC_SWAP_REVISION_OPTION" replacement ';' \
          set -s "$GHC_SWAP_OPERATION_OPTION" replacement || exit
      fi
      sleep 3
      printf '%s\n' "$output"
      exit "$status"
      ;;
  esac
fi

if [ -n "${GHC_SWAP_BARRIER_DIR:-}" ] \
  && [ -n "${GHC_SWAP_WORKER_ID:-}" ]; then
  case "$*" in
    *__GHC_STATUS_NAVIGATION__*)
      seen="$GHC_SWAP_BARRIER_DIR/seen.$GHC_SWAP_WORKER_ID"
      if [ ! -e "$seen" ]; then
        output=$("$GHC_SWAP_REAL_TMUX" "$@")
        status=$?
        : >"$seen"
        : >"$GHC_SWAP_BARRIER_DIR/ready.$GHC_SWAP_WORKER_ID"
        attempts=0
        while [ ! -e "$GHC_SWAP_BARRIER_DIR/ready.one" ] \
          || [ ! -e "$GHC_SWAP_BARRIER_DIR/ready.two" ]; do
          attempts=$((attempts + 1))
          [ "$attempts" -le 200 ] || exit 124
          sleep 0.01
        done
        printf '%s\n' "$output"
        exit "$status"
      fi
      ;;
  esac
fi

exec "$GHC_SWAP_REAL_TMUX" "$@"
EOF
chmod +x "$runtime_bin/tmux"

pane_id=$(env -u TMUX "$real_tmux" -L "$socket" -f /dev/null \
  new-session -dP -F '#{pane_id}' -s alpha)
env -u TMUX "$real_tmux" -L "$socket" new-session -d -s beta
env -u TMUX "$real_tmux" -L "$socket" new-session -d -s gamma

alpha_id=$(env -u TMUX "$real_tmux" -L "$socket" display-message -p -t alpha:0.0 '#{session_id}')
beta_id=$(env -u TMUX "$real_tmux" -L "$socket" display-message -p -t beta:0.0 '#{session_id}')
gamma_id=$(env -u TMUX "$real_tmux" -L "$socket" display-message -p -t gamma:0.0 '#{session_id}')
initial_order="$alpha_id"$'\t'"$beta_id"$'\t'"$gamma_id"
one_gamma_move="$gamma_id"$'\t'"$beta_id"$'\t'"$alpha_id"
two_gamma_moves="$beta_id"$'\t'"$gamma_id"$'\t'"$alpha_id"
revision_option='@GHC_SL_SESSION_ORDER_REV'
operation_option='@GHC_SL_SESSION_ORDER_OP'

env -u TMUX "$real_tmux" -L "$socket" set -g '@GHC_SL_MODE' 02 ';' \
  set -s '@GHC_SL_SCHED_ACTIVE' 0 ';' \
  set -s '@GHC_SL_SCHED_GEN' 1
server_env=$(env -u TMUX "$real_tmux" -L "$socket" display-message -p -t "$pane_id" \
  '#{socket_path},#{pid},0')
current_session=$(env TMUX="$server_env" "$real_tmux" display-message -p '#{session_name}')
[ "$current_session" = "gamma" ] \
  || fail "isolated swap context drifted: expected gamma, got $current_session"

env -u TMUX "$real_tmux" -L "$socket" set -gu '@GHC_SL_SESSION_ORDER' 2>/dev/null || true
env -u TMUX "$real_tmux" -L "$socket" set -su "$revision_option" 2>/dev/null || true
env \
  TMUX="$server_env" \
  PATH="$runtime_bin:$PATH" \
  GHC_SWAP_REAL_TMUX="$real_tmux" \
  GHC_SWAP_TMUX_CALLS="$runtime_tmux_calls" \
  "$binary" session swap next >/dev/null 2>&1 \
  || fail "swap from an unset order failed"
actual_order=$(env -u TMUX "$real_tmux" -L "$socket" show -gqv '@GHC_SL_SESSION_ORDER')
[ "$actual_order" = "$one_gamma_move" ] \
  || fail "swap from an unset order produced $actual_order"

env -u TMUX "$real_tmux" -L "$socket" set -g '@GHC_SL_SESSION_ORDER' "$initial_order" ';' \
  set -s "$revision_option" 10 ';' \
  set -t gamma '@GHC_SL_SESSION_ORDER' "$initial_order" ';' \
  set -t gamma "$revision_option" shadow
: >"$runtime_tmux_calls"
output=$(env \
  TMUX="$server_env" \
  PATH="$runtime_bin:$PATH" \
  GHC_SWAP_REAL_TMUX="$real_tmux" \
  GHC_SWAP_TMUX_CALLS="$runtime_tmux_calls" \
  "$binary" session swap next 2>&1)
actual_order=$(env -u TMUX "$real_tmux" -L "$socket" show -gqv '@GHC_SL_SESSION_ORDER')
[ -z "$output" ] || fail "local order override leaked output: $output"
[ "$actual_order" = "$one_gamma_move" ] \
  || fail "local order override shadowed the server revision CAS: $actual_order"
env -u TMUX "$real_tmux" -L "$socket" set -u -t gamma '@GHC_SL_SESSION_ORDER'
env -u TMUX "$real_tmux" -L "$socket" set -u -t gamma "$revision_option"

env -u TMUX "$real_tmux" -L "$socket" set -g '@GHC_SL_SESSION_ORDER' "$initial_order" ';' \
  set -s "$revision_option" 15 ';' \
  set -su "$operation_option" ';' \
  set -s '@GHC_SL_SCHED_ACTIVE' 0
delay_marker="$tmp/cas-delay-applied"
: >"$runtime_tmux_calls"
set +e
output=$(env \
  TMUX="$server_env" \
  PATH="$runtime_bin:$PATH" \
  GHC_SWAP_REAL_TMUX="$real_tmux" \
  GHC_SWAP_TMUX_CALLS="$runtime_tmux_calls" \
  GHC_SWAP_REVISION_OPTION="$revision_option" \
  GHC_SWAP_OPERATION_OPTION="$operation_option" \
  GHC_SWAP_DELAY_AFTER_CAS=1 \
  GHC_SWAP_DELAY_MARKER="$delay_marker" \
  "$binary" session swap next 2>&1)
status=$?
set -e
actual_order=$(env -u TMUX "$real_tmux" -L "$socket" show -gqv '@GHC_SL_SESSION_ORDER')
actual_revision=$(env -u TMUX "$real_tmux" -L "$socket" show -sqv "$revision_option")
actual_operation=$(env -u TMUX "$real_tmux" -L "$socket" show -sqv "$operation_option")
[ "$status" = "0" ] || fail "applied CAS timeout reported failure: $output"
[ -z "$output" ] || fail "applied CAS timeout leaked output: $output"
[ "$actual_order" = "$one_gamma_move" ] \
  || fail "applied CAS timeout lost committed order: $actual_order"
[ "$actual_revision" = "16" ] || fail "applied CAS timeout lost revision: $actual_revision"
[ -n "$actual_operation" ] || fail "applied CAS timeout lost operation token"

env -u TMUX "$real_tmux" -L "$socket" set -g '@GHC_SL_SESSION_ORDER' "$initial_order" ';' \
  set -s "$revision_option" 17 ';' \
  set -s "$operation_option" previous ';' \
  set -s '@GHC_SL_SCHED_ACTIVE' 0
delay_marker="$tmp/cas-delay-unknown"
: >"$runtime_tmux_calls"
set +e
output=$(env \
  TMUX="$server_env" \
  PATH="$runtime_bin:$PATH" \
  GHC_SWAP_REAL_TMUX="$real_tmux" \
  GHC_SWAP_TMUX_CALLS="$runtime_tmux_calls" \
  GHC_SWAP_REVISION_OPTION="$revision_option" \
  GHC_SWAP_OPERATION_OPTION="$operation_option" \
  GHC_SWAP_DELAY_AFTER_CAS=1 \
  GHC_SWAP_DELAY_MARKER="$delay_marker" \
  GHC_SWAP_REPLACE_AFTER_CAS=1 \
  GHC_SWAP_REPLACEMENT_ORDER="$initial_order" \
  "$binary" session swap next 2>&1)
status=$?
set -e
actual_order=$(env -u TMUX "$real_tmux" -L "$socket" show -gqv '@GHC_SL_SESSION_ORDER')
[ "$status" = "0" ] || fail "unknown CAS outcome reported failure: $output"
[ -z "$output" ] || fail "unknown CAS outcome leaked output: $output"
[ "$actual_order" = "$initial_order" ] \
  || fail "unknown CAS outcome overwrote the replacement order: $actual_order"
rg -Fq 'display-message Session swap outcome unknown; inspect session order' "$runtime_tmux_calls" \
  || fail "unknown CAS outcome did not report inspect-order message"

env -u TMUX "$real_tmux" -L "$socket" set -g '@GHC_SL_SESSION_ORDER' "$initial_order" ';' \
  set -s "$revision_option" 20 ';' \
  set -s '@GHC_SL_SCHED_ACTIVE' 1 ';' \
  set -s '@GHC_SL_SCHED_GEN' invalid
: >"$runtime_tmux_calls"
set +e
output=$(env \
  TMUX="$server_env" \
  PATH="$runtime_bin:$PATH" \
  GHC_SWAP_REAL_TMUX="$real_tmux" \
  GHC_SWAP_TMUX_CALLS="$runtime_tmux_calls" \
  "$binary" session swap next 2>&1)
status=$?
set -e
actual_order=$(env -u TMUX "$real_tmux" -L "$socket" show -gqv '@GHC_SL_SESSION_ORDER')

[ "$status" = "0" ] || fail "committed swap reported failure: $output"
[ -z "$output" ] || fail "committed swap leaked render failure: $output"
[ "$actual_order" = "$one_gamma_move" ] \
  || fail "render failure lost committed order: $actual_order"
rg -Fq 'display-message Session order updated; status refresh pending' "$runtime_tmux_calls" \
  || fail "render failure did not report pending refresh"

env -u TMUX "$real_tmux" -L "$socket" set -s '@GHC_SL_SCHED_ACTIVE' 0 ';' \
  set -s '@GHC_SL_SCHED_GEN' 1 ';' \
  set -s "$revision_option" 30 ';' \
  set -g '@GHC_SL_SESSION_ORDER' "$initial_order"
barrier_dir="$tmp/concurrent-barrier"
mkdir -p "$barrier_dir"
: >"$runtime_tmux_calls"
env \
  TMUX="$server_env" \
  PATH="$runtime_bin:$PATH" \
  GHC_SWAP_REAL_TMUX="$real_tmux" \
  GHC_SWAP_TMUX_CALLS="$runtime_tmux_calls" \
  GHC_SWAP_REVISION_OPTION="$revision_option" \
  GHC_SWAP_BARRIER_DIR="$barrier_dir" \
  GHC_SWAP_WORKER_ID=one \
  "$binary" session swap next >/dev/null 2>&1 &
first_pid=$!
env \
  TMUX="$server_env" \
  PATH="$runtime_bin:$PATH" \
  GHC_SWAP_REAL_TMUX="$real_tmux" \
  GHC_SWAP_TMUX_CALLS="$runtime_tmux_calls" \
  GHC_SWAP_REVISION_OPTION="$revision_option" \
  GHC_SWAP_BARRIER_DIR="$barrier_dir" \
  GHC_SWAP_WORKER_ID=two \
  "$binary" session swap next >/dev/null 2>&1 &
second_pid=$!
wait "$first_pid" || fail "first barrier-controlled concurrent swap failed"
wait "$second_pid" || fail "second barrier-controlled concurrent swap failed"
actual_order=$(env -u TMUX "$real_tmux" -L "$socket" show -gqv '@GHC_SL_SESSION_ORDER')
[ "$actual_order" = "$two_gamma_moves" ] \
  || fail "barrier-controlled concurrent swap lost an update: $actual_order"
navigation_reads=$(rg -c '__GHC_STATUS_NAVIGATION__' "$runtime_tmux_calls")
[ "$navigation_reads" -ge 3 ] \
  || fail "concurrent CAS did not force a retry: reads=$navigation_reads"

env -u TMUX "$real_tmux" -L "$socket" set -g '@GHC_SL_SESSION_ORDER' "$initial_order" ';' \
  set -s "$revision_option" 40
: >"$runtime_tmux_calls"
output=$(env \
  TMUX="$server_env" \
  PATH="$runtime_bin:$PATH" \
  GHC_SWAP_REAL_TMUX="$real_tmux" \
  GHC_SWAP_TMUX_CALLS="$runtime_tmux_calls" \
  GHC_SWAP_REVISION_OPTION="$revision_option" \
  GHC_SWAP_FORCE_CONFLICT=1 \
  "$binary" session swap next 2>&1)
actual_order=$(env -u TMUX "$real_tmux" -L "$socket" show -gqv '@GHC_SL_SESSION_ORDER')
[ -z "$output" ] || fail "retry exhaustion leaked output: $output"
[ "$actual_order" = "$initial_order" ] \
  || fail "retry exhaustion mutated session order: $actual_order"
navigation_reads=$(rg -c '__GHC_STATUS_NAVIGATION__' "$runtime_tmux_calls")
[ "$navigation_reads" = "3" ] \
  || fail "retry exhaustion used $navigation_reads reads instead of 3"
rg -Fq 'display-message Session order changed concurrently; retry' "$runtime_tmux_calls" \
  || fail "retry exhaustion did not report the retry message"

printf '%s\n' "swap session integration: ok"
