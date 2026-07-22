#!/usr/bin/env bash
set -u

# The status format is the normal caller. `--recover` is loader-only and runs
# after the loader fences the scheduler generation.
recover_only=0
if [ "$#" = "1" ] && [ "$1" = "--recover" ]; then
  recover_only=1
elif [ "$#" != "0" ]; then
  exit 1
fi

readonly active_option='@GHC_SL_SCHED_ACTIVE'
readonly generation_option='@GHC_SL_SCHED_GEN'
readonly recovery_owner_option='@GHC_SL_LOCK_RECOVERY_OWNER'
readonly renderer="$HOME/.config/tmux/rust/ghc-tmux-status/target/release/ghc-tmux-status"

if [ "$recover_only" = "0" ]; then
  printf '\n'
fi

tmux_fields=${TMUX#*,}
server_pid=${tmux_fields%%,*}
if ! [[ "$server_pid" =~ ^[0-9]+$ ]]; then
  exit 0
fi

# Candidate content is written before the atomic hard-link acquisition, so the
# published lock never has an empty owner window. A legacy directory lock from
# the previous implementation remains readable/recoverable during upgrade.
lock_path="${TMPDIR:-/tmp}/ghc-tmux-status-scheduler-${UID}-${server_pid}.lock"
lock_candidate="${lock_path}.candidate.$$"
lock_update="${lock_path}.update.$$"
legacy_owner_file="$lock_path/owner"
owns_lock=0
owns_recovery_lease=0
renderer_pid=""

owner_value_is_alive() {
  local owner_value=$1
  local owner_driver owner_renderer owner_pid
  IFS=: read -r owner_driver owner_renderer <<<"$owner_value"
  for owner_pid in "$owner_driver" "$owner_renderer"; do
    if [[ "$owner_pid" =~ ^[0-9]+$ ]] && kill -0 "$owner_pid" 2>/dev/null; then
      return 0
    fi
  done
  return 1
}

lock_exists() {
  [ -e "$lock_path" ] || [ -L "$lock_path" ]
}

read_lock_owner() {
  if [ -d "$lock_path" ]; then
    cat "$legacy_owner_file" 2>/dev/null || true
    return
  fi
  if [ -f "$lock_path" ]; then
    cat "$lock_path" 2>/dev/null || true
  fi
}

cleanup_candidate_files() {
  if [ -e "$lock_candidate" ] || [ -L "$lock_candidate" ]; then
    unlink "$lock_candidate" 2>/dev/null || true
  fi
  if [ -e "$lock_update" ] || [ -L "$lock_update" ]; then
    unlink "$lock_update" 2>/dev/null || true
  fi
}

acquire_fresh_lock() {
  cleanup_candidate_files
  if ! printf '%s\n' "$$" >"$lock_candidate"; then
    cleanup_candidate_files
    return 1
  fi
  # `link` maps directly to link(2) and never treats a legacy directory target
  # as a destination directory (unlike `ln source existing-directory`).
  if ! link "$lock_candidate" "$lock_path" 2>/dev/null; then
    cleanup_candidate_files
    return 1
  fi
  owns_lock=1
  # The fixed hard link now owns the inode; the source name is no longer needed.
  unlink "$lock_candidate" 2>/dev/null || true
}

publish_renderer_owner() {
  local owner
  if ! printf '%s:%s\n' "$$" "$renderer_pid" >"$lock_update"; then
    return 1
  fi
  owner=$(read_lock_owner)
  if [ "${owner%%:*}" != "$$" ]; then
    unlink "$lock_update" 2>/dev/null || true
    return 1
  fi
  mv -f "$lock_update" "$lock_path" 2>/dev/null
}

recover_stale_lock() {
  local owner owner_driver
  if ! lock_exists; then
    return 0
  fi
  owner=$(read_lock_owner)
  # Empty or unsupported lock state is retained rather than guessed stale.
  if [ -z "$owner" ] || owner_value_is_alive "$owner"; then
    return 1
  fi
  owner_driver=${owner%%:*}
  if [ -d "$lock_path" ]; then
    unlink "$legacy_owner_file" 2>/dev/null || return 1
    rmdir "$lock_path" 2>/dev/null || return 1
  elif [ -f "$lock_path" ]; then
    unlink "$lock_path" 2>/dev/null || return 1
  else
    return 1
  fi
  if [[ "$owner_driver" =~ ^[0-9]+$ ]]; then
    unlink "${lock_path}.candidate.${owner_driver}" 2>/dev/null || true
    unlink "${lock_path}.update.${owner_driver}" 2>/dev/null || true
  fi
}

release_lock() {
  local owner
  if [ "$owns_lock" = "1" ]; then
    owner=$(read_lock_owner)
  else
    owner=""
  fi
  if [ "${owner%%:*}" = "$$" ]; then
    unlink "$lock_path" 2>/dev/null || true
  fi
  cleanup_candidate_files
  owns_lock=0
}

acquire_recovery_lease() {
  local observed outcome
  if ! observed=$(tmux show -sqv "$recovery_owner_option" 2>/dev/null); then
    return 1
  fi
  if [ -n "$observed" ]; then
    if ! [[ "$observed" =~ ^[0-9]+$ ]] || kill -0 "$observed" 2>/dev/null; then
      return 1
    fi
  fi
  outcome=$(tmux if-shell -F \
    "#{==:#{${recovery_owner_option}},#{l:${observed}}}" \
    "set -s ${recovery_owner_option} $$ ; display-message -p __GHC_LOCK_RECOVERY_APPLIED__" \
    "display-message -p __GHC_LOCK_RECOVERY_SKIPPED__" \
    2>/dev/null || true)
  if [ "$outcome" != "__GHC_LOCK_RECOVERY_APPLIED__" ]; then
    return 1
  fi
  owns_recovery_lease=1
}

release_recovery_lease() {
  if [ "$owns_recovery_lease" = "1" ]; then
    tmux if-shell -F \
      "#{==:#{${recovery_owner_option}},#{l:$$}}" \
      "set -su ${recovery_owner_option}" \
      >/dev/null 2>&1 || true
    owns_recovery_lease=0
  fi
}

cleanup_driver() {
  release_lock
  release_recovery_lease
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

recover_lock_with_lease() {
  acquire_recovery_lease || return 1
  recover_stale_lock || true
}

if [ "$recover_only" = "1" ]; then
  recover_lock_with_lease || exit 0
  exit 0
fi

acquire_driver_lock() {
  if acquire_fresh_lock; then
    return 0
  fi
  recover_lock_with_lease || return 1
  if acquire_fresh_lock; then
    release_recovery_lease
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
if ! publish_renderer_owner; then
  kill "$renderer_pid" 2>/dev/null || true
  wait "$renderer_pid" 2>/dev/null || true
  renderer_pid=""
  exit 1
fi
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
