#!/usr/bin/env bash
set -u

# The status format is the only caller. Hooks invoke the renderer directly and
# rely on its process watchdog, preserving their existing ordering semantics.
if [ "$#" != "0" ]; then
  exit 1
fi

readonly active_option='@GHC_SL_SCHED_ACTIVE'
readonly generation_option='@GHC_SL_SCHED_GEN'
readonly renderer="$HOME/.config/tmux/rust/ghc-tmux-status/target/release/ghc-tmux-status"

printf '\n'

# `refresh-client -S` may invalidate tmux's #() job cache while an old job is
# alive. The lock bounds this self-triggering path to one renderer. Exactly one
# recovery owner may inspect/remove a stale lock, avoiding TOCTOU deletion races.
tmux_fields=${TMUX#*,}
server_pid=${tmux_fields%%,*}
if ! [[ "$server_pid" =~ ^[0-9]+$ ]]; then
  exit 0
fi
lock_dir="${TMPDIR:-/tmp}/ghc-tmux-status-scheduler-${UID}-${server_pid}.lock"
owner_file="$lock_dir/owner"
recovery_dir="${lock_dir}.recovery"
owns_lock=0
owns_recovery=0
renderer_pid=""

lock_owner_is_alive() {
  local owner owner_driver owner_renderer owner_pid
  owner=$(cat "$owner_file" 2>/dev/null || true)
  # A process preempted between mkdir and owner write is conservatively live.
  if [ -z "$owner" ]; then
    return 0
  fi
  IFS=: read -r owner_driver owner_renderer <<<"$owner"
  for owner_pid in "$owner_driver" "$owner_renderer"; do
    if [[ "$owner_pid" =~ ^[0-9]+$ ]] && kill -0 "$owner_pid" 2>/dev/null; then
      return 0
    fi
  done
  return 1
}

acquire_fresh_lock() {
  if ! mkdir "$lock_dir" 2>/dev/null; then
    return 1
  fi
  owns_lock=1
  if ! printf '%s\n' "$$" >"$owner_file"; then
    unlink "$owner_file" 2>/dev/null || true
    rmdir "$lock_dir" 2>/dev/null || true
    owns_lock=0
    return 1
  fi
}

recover_stale_lock() {
  local owner
  owner=$(cat "$owner_file" 2>/dev/null || true)
  if [ -z "$owner" ] || lock_owner_is_alive; then
    return 1
  fi
  unlink "$owner_file" 2>/dev/null || return 1
  rmdir "$lock_dir" 2>/dev/null || return 1
}

release_lock() {
  local owner
  if [ "$owns_lock" = "1" ]; then
    owner=$(cat "$owner_file" 2>/dev/null || true)
  else
    owner=""
  fi
  if [ "${owner%%:*}" = "$$" ]; then
    unlink "$owner_file" 2>/dev/null || true
    rmdir "$lock_dir" 2>/dev/null || true
  fi
  owns_lock=0
}

release_recovery() {
  if [ "$owns_recovery" = "1" ]; then
    rmdir "$recovery_dir" 2>/dev/null || true
    owns_recovery=0
  fi
}

cleanup_driver() {
  release_lock
  release_recovery
}

stop_driver() {
  local exit_code=$1
  if [[ "$renderer_pid" =~ ^[0-9]+$ ]]; then
    kill "$renderer_pid" 2>/dev/null || true
    wait "$renderer_pid" 2>/dev/null || true
  fi
  exit "$exit_code"
}

trap cleanup_driver EXIT
trap 'stop_driver 129' HUP
trap 'stop_driver 130' INT
trap 'stop_driver 143' TERM

acquire_driver_lock() {
  if acquire_fresh_lock; then
    return 0
  fi
  if ! mkdir "$recovery_dir" 2>/dev/null; then
    return 1
  fi
  owns_recovery=1
  recover_stale_lock || true
  if acquire_fresh_lock; then
    release_recovery
    return 0
  fi
  return 1
}

acquire_driver_lock || exit 0

delay_seconds=${GHC_TMUX_STATUS_DRIVER_DELAY_SECONDS:-4}
if ! [[ "$delay_seconds" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  delay_seconds=4
fi
sleep "$delay_seconds"

lifecycle=$(tmux display-message -p $'#{@GHC_SL_SCHED_ACTIVE}\t#{@GHC_SL_SCHED_GEN}' 2>/dev/null) || exit 0
IFS=$'\t' read -r active generation <<<"$lifecycle"
if [ "$active" != "1" ] || ! [[ "$generation" =~ ^[0-9]+$ ]]; then
  exit 0
fi

renderer_status=0
"$renderer" scheduler-tick >/dev/null 2>&1 &
renderer_pid=$!
printf '%s:%s\n' "$$" "$renderer_pid" >"$owner_file"
wait "$renderer_pid" || renderer_status=$?
renderer_pid=""
if [ "$renderer_status" = "0" ]; then
  exit 0
fi

# Exit 1 is the normal application-error boundary (for example a transient tmux
# timeout). Keep the scheduler active so its task lease can recover on a later tick.
if [ "$renderer_status" = "1" ]; then
  exit 0
fi

# Panic (101), watchdog (124), missing binary (127), and signal exits (>128) are
# abnormal process failures. Fence only the generation observed before launch.
tmux if-shell -F \
  "#{&&:#{==:#{${active_option}},1},#{==:#{${generation_option}},${generation}}}" \
  "set -s ${active_option} 0" \
  >/dev/null 2>&1 || true

exit 0
