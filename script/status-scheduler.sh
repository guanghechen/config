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
readonly session_states_option='@GHC_SL_SESSION_STATES'
readonly recovery_owner_option='@GHC_SL_LOCK_RECOVERY_OWNER'
readonly renderer="$HOME/.config/tmux/rust/ghc-tmux-status/target/release/ghc-tmux-status"
# A renderer prints this line, and nothing else, once it owns the tick's session-state
# publication; it must match the renderer's SESSION_STATES_ACK.
readonly session_states_ack='__GHC_SESSION_STATES_V2_TAKEN__'
# Only the versioned request below hands publication over. Renderers that predate
# it ignore that request, so an inherited unversioned request must not reach them.
unset GHC_TMUX_STATUS_SESSION_STATES_PREFIX

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
lock_ack="${lock_path}.ack.$$"
legacy_owner_file="$lock_path/owner"
owns_lock=0
owns_recovery_lease=0
renderer_pid=""
lock_owner_value=""

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
  lock_owner_value=""
  if [ -d "$lock_path" ]; then
    if [ -r "$legacy_owner_file" ]; then
      IFS= read -r lock_owner_value <"$legacy_owner_file" || true
    fi
    return
  fi
  if [ -f "$lock_path" ] && [ -r "$lock_path" ]; then
    IFS= read -r lock_owner_value <"$lock_path" || true
  fi
}

lock_has_live_owner() {
  lock_exists || return 1
  read_lock_owner
  owner_value_is_alive "$lock_owner_value"
}

cleanup_candidate_files() {
  if [ -e "$lock_candidate" ] || [ -L "$lock_candidate" ]; then
    unlink "$lock_candidate" 2>/dev/null || true
  fi
  if [ -e "$lock_update" ] || [ -L "$lock_update" ]; then
    unlink "$lock_update" 2>/dev/null || true
  fi
  if [ -e "$lock_ack" ] || [ -L "$lock_ack" ]; then
    unlink "$lock_ack" 2>/dev/null || true
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
  # Retain the source link so normal release can remove all owned artifacts in
  # one process; only the fixed lock path is read as scheduler ownership.
}

publish_renderer_owner() {
  local owner
  if ! printf '%s:%s\n' "$$" "$renderer_pid" >"$lock_update"; then
    return 1
  fi
  read_lock_owner
  owner=$lock_owner_value
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
  read_lock_owner
  owner=$lock_owner_value
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
    unlink "${lock_path}.ack.${owner_driver}" 2>/dev/null || true
  fi
}

release_lock() {
  local owner
  if [ "$owns_lock" = "1" ]; then
    read_lock_owner
    owner=$lock_owner_value
  else
    owner=""
  fi
  if [ "${owner%%:*}" = "$$" ]; then
    rm -f -- "$lock_path" "$lock_candidate" "$lock_update" "$lock_ack" 2>/dev/null || true
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
# Any refresh-client makes tmux SIGTERM this running #() job and start a
# replacement that loses the lock. TERM is therefore a restart notice, not a
# stop request: finish this cycle so a claimed task completes instead of
# waiting out its lease. A handler, unlike an ignored disposition, is not
# inherited by the renderer.
term_received=0
trap 'term_received=1' TERM

recover_lock_with_lease() {
  acquire_recovery_lease || return 1
  recover_stale_lock || true
}

if [ "$recover_only" = "1" ]; then
  recover_lock_with_lease || exit 0
  exit 0
fi

acquire_driver_lock() {
  lock_has_live_owner && return 1
  if acquire_fresh_lock; then
    return 0
  fi
  lock_has_live_owner && return 1
  recover_lock_with_lease || return 1
  if acquire_fresh_lock; then
    release_recovery_lease
    return 0
  fi
  return 1
}

acquire_driver_lock || exit 0

# Each owned tick publishes session states once. A renderer that acknowledges the
# versioned request carries the publication in its first mutation queue, saving a
# full client redraw. The driver publishes itself on exits that never start the
# renderer, and after a normal renderer exit that never acknowledged the request.
nonce=${EPOCHREALTIME:-${RANDOM}${RANDOM}}
sample_prefix="${server_pid}:$$:${nonce/./}:"
ttl_seconds=${GHC_TMUX_STATUS_SESSION_STATE_TTL_SECONDS:-12}
if ! [[ "$ttl_seconds" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  ttl_seconds=12
fi

publish_session_states() {
  local enabled_format stale_clear_command
  enabled_format='#{&&:#{==:#{@GHC_SL_SCHED_ACTIVE},1},#{||:#{==:#{@GHC_SL_MODE},02},#{==:#{@GHC_SL_MODE},12}}}'

  # run-shell expands once when it is scheduled. Double hashes preserve the
  # sample comparison for if-shell to expand when the delayed command executes.
  stale_clear_command="if-shell -F '##{m:${sample_prefix}*,##{${session_states_option}}}' 'set-option -s ${session_states_option} \"\"'"

  # Only the scheduler lock owner samples. Clearing before format expansion makes
  # a malformed sample degrade to no marker without blocking scheduler work.
  tmux run-shell -bC -d "$ttl_seconds" "$stale_clear_command" ';' \
    set-option -s "$session_states_option" "" ';' \
    set-option -sF "$session_states_option" \
    "#{?${enabled_format},${sample_prefix}#{E:@GHC_SESSION_STATES_FMT},}" \
    >/dev/null 2>&1 || true
}

delay_seconds=${GHC_TMUX_STATUS_DRIVER_DELAY_SECONDS:-4}
if ! [[ "$delay_seconds" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  delay_seconds=4
fi
sleep "$delay_seconds"

if ! scheduler_snapshot=$(tmux display-message -p \
  $'#{@GHC_SL_SCHED_ACTIVE}\t#{@GHC_SL_SCHED_GEN}\t#{@GHC_SL_METRIC_SCHED}\t#{@GHC_SL_HEARTBEAT_SCHED}' \
  2>/dev/null); then
  publish_session_states
  exit 0
fi
IFS=$'\t' read -r active generation _ <<<"$scheduler_snapshot"
if [ "$active" != "1" ] || ! [[ "$generation" =~ ^[0-9]+$ ]]; then
  publish_session_states
  exit 0
fi

# tmux remains authoritative. A fully framed snapshot saves the renderer's
# duplicate read; malformed state falls back so Rust can observe and repair the
# exact value. Every due mutation still compares these raw strings through CAS.
scheduler_snapshot_pattern=$'^1\t([0-9]+)\t([0-9]+:[0-9]+:[0-9]+:[0-9]+)\t([0-9]+:[0-9]+:[0-9]+:[0-9]+)$'
if [[ "$scheduler_snapshot" =~ $scheduler_snapshot_pattern ]]; then
  generation=${BASH_REMATCH[1]}
  export GHC_TMUX_STATUS_SCHEDULER_SNAPSHOT="1"$'\t'"$generation"$'\t'"${BASH_REMATCH[2]}"$'\t'"${BASH_REMATCH[3]}"
else
  unset GHC_TMUX_STATUS_SCHEDULER_SNAPSHOT
fi

# The ack file belongs to this invocation. Acquisition already unlinked any stale
# path, and an exclusive create gives the renderer a fresh file that an orphan's
# old descriptor cannot write into. Without one, the driver keeps publication.
ack_ready=0
set -C
if : >"$lock_ack" 2>/dev/null; then
  ack_ready=1
fi
set +C

renderer_status=0
term_received=0
if [ "$ack_ready" = "1" ]; then
  GHC_TMUX_STATUS_SESSION_STATES_PREFIX_V2="$sample_prefix" \
    GHC_TMUX_STATUS_SESSION_STATE_TTL_SECONDS="$ttl_seconds" \
    "$renderer" scheduler-tick >"$lock_ack" 2>/dev/null &
else
  publish_session_states
  "$renderer" scheduler-tick >/dev/null 2>&1 &
fi
renderer_pid=$!
if ! publish_renderer_owner; then
  kill "$renderer_pid" 2>/dev/null || true
  wait "$renderer_pid" 2>/dev/null || true
  renderer_pid=""
  exit 1
fi
wait "$renderer_pid" || renderer_status=$?
# A trapped TERM interrupts wait with a status above 128 while the renderer may
# still run. Wait again for the renderer's own status; 127 means the previous
# wait already reaped it, so its status stands.
while [ "$term_received" = "1" ] && [ "$renderer_status" -gt 128 ]; do
  term_received=0
  waited_status=0
  wait "$renderer_pid" 2>/dev/null || waited_status=$?
  if [ "$waited_status" = "127" ]; then
    break
  fi
  renderer_status=$waited_status
done
renderer_pid=""

# Classifies this invocation's ack. `taken`: a complete ack line, so the renderer owned
# the publication whatever happened afterwards. `declined`: an empty file or another
# complete line, so the renderer predates the handoff or failed before taking it and
# never published. `unknown`: the ack could not be opened or fully read; that proves
# neither, so the tick is left to the TTL rather than risk a second publication.
classify_renderer_publication() {
  local ack_line="" opened=0 read_status=0
  publication_state=unknown
  if ! [ -f "$lock_ack" ]; then
    return
  fi
  {
    opened=1
    IFS= read -r ack_line || read_status=$?
  } 2>/dev/null <"$lock_ack"
  if [ "$opened" != "1" ]; then
    return
  fi
  if [ "$read_status" = "0" ]; then
    if [ "$ack_line" = "$session_states_ack" ]; then
      publication_state=taken
    else
      publication_state=declined
    fi
  elif [ -z "$ack_line" ] && ! [ -s "$lock_ack" ]; then
    publication_state=declined
  fi
}

# Only normal exits fall back; abnormal exits keep the generation fence below.
if [ "$ack_ready" = "1" ] && { [ "$renderer_status" = "0" ] || [ "$renderer_status" = "1" ]; }; then
  classify_renderer_publication
  if [ "$publication_state" = "declined" ]; then
    publish_session_states
  fi
fi

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
