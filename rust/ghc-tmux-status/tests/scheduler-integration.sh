#!/usr/bin/env bash
set -euo pipefail

crate_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
binary="$crate_dir/target/debug/ghc-tmux-status"
tmp=$(mktemp -d /tmp/ghc-tmux-scheduler-test.XXXXXX)
socket="ghc-tmux-scheduler-test-$$"

cleanup() {
  tmux -L "$socket" kill-server 2>/dev/null || true
  rm -rf "$tmp"
}
trap cleanup EXIT

cargo build --quiet --manifest-path "$crate_dir/Cargo.toml"
env -u TMUX tmux -L "$socket" -f /dev/null new-session -d -s scheduler -x 120 -y 30
server_env=$(tmux -L "$socket" display-message -p '#{socket_path},#{pid},0')

# Retired recursive commands must fail before touching tmux. The proxy records
# every adapter invocation, including any attempt to enqueue a successor job.
real_tmux=$(command -v tmux)
mkdir -p "$tmp/bin"
cat >"$tmp/bin/tmux" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$GHC_TMUX_TMUX_CALL_LOG"
case "$*" in *"${GHC_TMUX_FAIL_MATCH:-__never__}"*) exit 1 ;; esac
exec "$GHC_TMUX_REAL_TMUX" "$@"
EOF
chmod +x "$tmp/bin/tmux"
tmux_call_log="$tmp/legacy-tmux-calls"
: >"$tmux_call_log"

tmux -L "$socket" set -s @GHC_SL_SCHED_ACTIVE 1 ';' \
  set -s @GHC_SL_SCHED_GEN 777 ';' \
  set -s @GHC_SL_METRIC_SCHED '777:9:9999999999:0' ';' \
  set -s @GHC_SL_HEARTBEAT_SCHED '777:11:9999999999:0' ';' \
  set -s @GHC_SL_METRIC_GEN 7 ';' \
  set -s @GHC_SL_HEARTBEAT_GEN 7 ';' \
  set -g @GHC_SL_CPU_GEN 7

legacy_state() {
  printf '%s\n' \
    "$(tmux -L "$socket" show -sqv @GHC_SL_SCHED_ACTIVE)" \
    "$(tmux -L "$socket" show -sqv @GHC_SL_SCHED_GEN)" \
    "$(tmux -L "$socket" show -sqv @GHC_SL_METRIC_SCHED)" \
    "$(tmux -L "$socket" show -sqv @GHC_SL_HEARTBEAT_SCHED)" \
    "$(tmux -L "$socket" show -sqv @GHC_SL_METRIC_GEN)" \
    "$(tmux -L "$socket" show -sqv @GHC_SL_HEARTBEAT_GEN)" \
    "$(tmux -L "$socket" show -gqv @GHC_SL_CPU_GEN)"
}

legacy_state_before=$(legacy_state)
while read -r command generation; do
  stdout="$tmp/$command.stdout"
  stderr="$tmp/$command.stderr"
  if env \
    TMUX="$server_env" \
    PATH="$tmp/bin:$PATH" \
    GHC_TMUX_REAL_TMUX="$real_tmux" \
    GHC_TMUX_TMUX_CALL_LOG="$tmux_call_log" \
    "$binary" "$command" "$generation" >"$stdout" 2>"$stderr"; then
    echo "retired command unexpectedly succeeded: $command" >&2
    exit 1
  fi
  error=$(cat "$stderr")
  if [ -s "$stdout" ] || [ "$error" != "ghc-tmux-status: unknown command: $command" ]; then
    echo "retired command did not return its usage error: $command" >&2
    cat "$stdout" "$stderr" >&2
    exit 1
  fi
done <<'EOF'
heartbeat 7
metrics-sample 7
cpu-sample 7
EOF

if [ -s "$tmux_call_log" ]; then
  echo "retired command reached tmux or enqueued a successor" >&2
  cat "$tmux_call_log" >&2
  exit 1
fi
if [ "$(legacy_state)" != "$legacy_state_before" ]; then
  echo "retired command mutated scheduler or generation state" >&2
  exit 1
fi

# The production driver already owns one atomic scheduler snapshot. Reusing a
# valid, not-due snapshot must not issue a second tmux query from Rust.
snapshot_now=$(date +%s)
metric_not_due="777:9:$((snapshot_now + 30)):0"
heartbeat_not_due="777:11:$((snapshot_now + 60)):0"
tmux -L "$socket" set -s @GHC_SL_METRIC_SCHED "$metric_not_due" ';' \
  set -s @GHC_SL_HEARTBEAT_SCHED "$heartbeat_not_due"
: >"$tmux_call_log"
env \
  TMUX="$server_env" \
  PATH="$tmp/bin:$PATH" \
  GHC_TMUX_REAL_TMUX="$real_tmux" \
  GHC_TMUX_TMUX_CALL_LOG="$tmux_call_log" \
  GHC_TMUX_STATUS_SCHEDULER_SNAPSHOT=$'1\t'"777"$'\t'"$metric_not_due"$'\t'"$heartbeat_not_due" \
  "$binary" scheduler-tick
if [ -s "$tmux_call_log" ]; then
  echo "preloaded not-due scheduler snapshot queried tmux" >&2
  cat "$tmux_call_log" >&2
  exit 1
fi

# A preloaded due witness may race another scheduler. The exact state guard
# must skip rather than overwrite the newer authoritative value.
snapshot_state_before=$(legacy_state)
env \
  TMUX="$server_env" \
  GHC_TMUX_STATUS_SCHEDULER_SNAPSHOT=$'1\t'"777"$'\t'"$metric_not_due"$'\t777:10:0:0' \
  "$binary" scheduler-tick
if [ "$(legacy_state)" != "$snapshot_state_before" ]; then
  echo "stale preloaded scheduler snapshot overwrote authoritative state" >&2
  exit 1
fi

# Invalid transported state falls back to the live-read form. This keeps new
# binaries compatible with old drivers and preserves exact repair semantics.
: >"$tmux_call_log"
env \
  TMUX="$server_env" \
  PATH="$tmp/bin:$PATH" \
  GHC_TMUX_REAL_TMUX="$real_tmux" \
  GHC_TMUX_TMUX_CALL_LOG="$tmux_call_log" \
  GHC_TMUX_STATUS_SCHEDULER_SNAPSHOT=invalid \
  "$binary" scheduler-tick
if [ ! -s "$tmux_call_log" ]; then
  echo "invalid transported scheduler snapshot did not fall back to tmux" >&2
  exit 1
fi

# An owned tick attempts its session-state publication exactly once: inside the
# first mutation queue it executes, or on its own when no queue carried it.
publish_prefix="314:5120:$snapshot_now:"
tmux -L "$socket" set -g @GHC_SL_MODE 02
owned_stdout="$tmp/owned.stdout"
session_states_ack='__GHC_SESSION_STATES_V2_TAKEN__'
run_owned_tick() {
  local snapshot=$1
  shift
  : >"$tmux_call_log"
  env \
    TMUX="$server_env" \
    PATH="$tmp/bin:$PATH" \
    GHC_TMUX_REAL_TMUX="$real_tmux" \
    GHC_TMUX_TMUX_CALL_LOG="$tmux_call_log" \
    GHC_TMUX_STATUS_SCHEDULER_SNAPSHOT="$snapshot" \
    GHC_TMUX_STATUS_SESSION_STATES_PREFIX_V2="$publish_prefix" \
    GHC_TMUX_STATUS_SESSION_STATE_TTL_SECONDS=12 \
    "$@" "$binary" scheduler-tick >"$owned_stdout"
}
# A publication always leads its tmux invocation with the delayed expiry; failure
# outcomes may quote it, but never at the start of a call.
publish_calls() {
  rg -c '^run-shell -bC -d 12 ' "$tmux_call_log" || echo 0
}
session_states() {
  tmux -L "$socket" show -sqv @GHC_SL_SESSION_STATES
}
expect_publication() {
  local expected_value=$1
  local context=$2
  if [ "$(publish_calls)" != "1" ] || [ "$(session_states)" != "$expected_value" ]; then
    echo "$context: expected one publication of '$expected_value'" >&2
    cat "$tmux_call_log" >&2
    exit 1
  fi
}

# Nothing due: the only tmux call is the standalone publication.
tmux -L "$socket" set -s @GHC_SL_SESSION_STATES stale
run_owned_tick $'1\t777\t'"$metric_not_due"$'\t'"$heartbeat_not_due"
expect_publication "$publish_prefix" "not-due owned tick"
if [ "$(cat "$owned_stdout")" != "$session_states_ack" ]; then
  echo "owned tick did not acknowledge its publication: $(cat "$owned_stdout")" >&2
  exit 1
fi
if [ "$(wc -l <"$tmux_call_log" | tr -d ' ')" != "1" ]; then
  echo "not-due owned tick issued more than its publication" >&2
  cat "$tmux_call_log" >&2
  exit 1
fi

# Malformed or unversioned publication requests are not owned work: no
# acknowledgement, no publication, and the tick still succeeds.
expect_unowned_request() {
  if [ -s "$tmux_call_log" ] || [ -s "$owned_stdout" ]; then
    echo "unowned publication request was acknowledged or published: $1" >&2
    cat "$tmux_call_log" "$owned_stdout" >&2
    exit 1
  fi
}
run_owned_tick $'1\t777\t'"$metric_not_due"$'\t'"$heartbeat_not_due" \
  GHC_TMUX_STATUS_SESSION_STATES_PREFIX_V2=bad
expect_unowned_request "malformed request"
run_owned_tick $'1\t777\t'"$metric_not_due"$'\t'"$heartbeat_not_due" \
  GHC_TMUX_STATUS_SESSION_STATES_PREFIX_V2= \
  "GHC_TMUX_STATUS_SESSION_STATES_PREFIX=$publish_prefix"
expect_unowned_request "unversioned request"

# An acknowledgement that cannot be written forfeits the tick before any work. A
# pipe whose reader is already closed makes the write fail with EPIPE.
if env \
  TMUX="$server_env" \
  PATH="$tmp/bin:$PATH" \
  GHC_TMUX_REAL_TMUX="$real_tmux" \
  GHC_TMUX_TMUX_CALL_LOG="$tmux_call_log" \
  GHC_TMUX_STATUS_SESSION_STATES_PREFIX_V2="$publish_prefix" \
  GHC_TMUX_STATUS_SESSION_STATE_TTL_SECONDS=12 \
  python3 -c '
import os, subprocess, sys
read_end, write_end = os.pipe()
os.close(read_end)
sys.exit(subprocess.run(sys.argv[1:], stdout=write_end, stderr=subprocess.DEVNULL).returncode)
' "$binary" scheduler-tick; then
  echo "unwritable acknowledgement reported success" >&2
  exit 1
fi
if [ -s "$tmux_call_log" ]; then
  echo "unwritable acknowledgement still reached tmux" >&2
  cat "$tmux_call_log" >&2
  exit 1
fi

# A due claim carries the publication ahead of its guard, in the same queue.
heartbeat_due="777:11:0:0"
tmux -L "$socket" set -s @GHC_SL_HEARTBEAT_SCHED "$heartbeat_due" ';' \
  set -s @GHC_SL_SESSION_STATES stale
run_owned_tick $'1\t777\t'"$metric_not_due"$'\t'"$heartbeat_due"
expect_publication "$publish_prefix" "due heartbeat tick"
if ! rg '^run-shell -bC -d 12 ' "$tmux_call_log" | rg -Fq '@GHC_SL_HEARTBEAT_LAST_ATTEMPT'; then
  echo "publication did not share the heartbeat claim queue" >&2
  cat "$tmux_call_log" >&2
  exit 1
fi
heartbeat_after_publish=$(tmux -L "$socket" show -sqv @GHC_SL_HEARTBEAT_SCHED)
case "$heartbeat_after_publish" in
  777:12:*:0) ;;
  *) echo "due heartbeat did not complete after publishing: $heartbeat_after_publish" >&2; exit 1 ;;
esac

# A stale witness skips the claim, but the publication outside its guard ran.
tmux -L "$socket" set -s @GHC_SL_SESSION_STATES stale
run_owned_tick $'1\t777\t'"$metric_not_due"$'\t'"$heartbeat_due"
expect_publication "$publish_prefix" "skipped heartbeat claim"
if [ "$(tmux -L "$socket" show -sqv @GHC_SL_HEARTBEAT_SCHED)" != "$heartbeat_after_publish" ]; then
  echo "stale witness overwrote heartbeat state" >&2
  exit 1
fi

# A failed live read still attempts the publication and keeps its error.
tmux -L "$socket" set -s @GHC_SL_SESSION_STATES stale
if run_owned_tick invalid GHC_TMUX_FAIL_MATCH=@GHC_SL_SCHED_GEN 2>/dev/null; then
  echo "failed scheduler snapshot read reported success" >&2
  exit 1
fi
expect_publication "$publish_prefix" "failed snapshot read"

# An inactive lifecycle exits before any task yet still publishes, clearing samples.
tmux -L "$socket" set -s @GHC_SL_SCHED_ACTIVE 0 ';' \
  set -s @GHC_SL_SESSION_STATES stale
run_owned_tick ''
expect_publication "" "inactive owned tick"
tmux -L "$socket" set -s @GHC_SL_SCHED_ACTIVE 1

# A claim queue that fails before reaching tmux consumed the attempt: it is not
# repeated even though nothing was committed.
tmux -L "$socket" set -s @GHC_SL_HEARTBEAT_SCHED "$heartbeat_due" ';' \
  set -s @GHC_SL_SESSION_STATES stale
if run_owned_tick $'1\t777\t'"$metric_not_due"$'\t'"$heartbeat_due" \
  GHC_TMUX_FAIL_MATCH=@GHC_SL_HEARTBEAT_LAST_ATTEMPT 2>/dev/null; then
  echo "failed heartbeat claim reported success" >&2
  exit 1
fi
expect_publication stale "failed claim queue"

tmux -L "$socket" set -s @GHC_SL_SCHED_ACTIVE 1
tmux -L "$socket" set -s @GHC_SL_SCHED_GEN 42
tmux -L "$socket" set -g @GHC_SL_MODE 01

: > "$tmp/stdout"
: > "$tmp/stderr"
for _ in $(seq 1 20); do
  env TMUX="$server_env" "$binary" scheduler-tick >>"$tmp/stdout" 2>>"$tmp/stderr" &
done
wait

if [ -s "$tmp/stdout" ] || [ -s "$tmp/stderr" ]; then
  echo "concurrent scheduler tick emitted output" >&2
  cat "$tmp/stdout" "$tmp/stderr" >&2
  exit 1
fi

heartbeat_state=$(tmux -L "$socket" show -sqv @GHC_SL_HEARTBEAT_SCHED)
case "$heartbeat_state" in
  42:1:*:0) ;;
  *) echo "expected one heartbeat claim, got: $heartbeat_state" >&2; exit 1 ;;
esac
heartbeat_outcome=$(tmux -L "$socket" show -gqv @GHC_SL_HEARTBEAT_LAST_EXEC_OUTCOME)
case "$heartbeat_outcome" in
  *$'\t42\t1\tcomplete\tknown\tok') ;;
  *) echo "missing heartbeat completion outcome: $heartbeat_outcome" >&2; exit 1 ;;
esac

env TMUX="$server_env" "$binary" scheduler-tick
if [ "$(tmux -L "$socket" show -sqv @GHC_SL_HEARTBEAT_SCHED)" != "$heartbeat_state" ]; then
  echo "not-due tick advanced heartbeat state" >&2
  exit 1
fi

now=$(date +%s)
lease_state="42:7:0:$((now + 5))"
tmux -L "$socket" set -s @GHC_SL_HEARTBEAT_SCHED "$lease_state"
env TMUX="$server_env" "$binary" scheduler-tick
if [ "$(tmux -L "$socket" show -sqv @GHC_SL_HEARTBEAT_SCHED)" != "$lease_state" ]; then
  echo "active lease did not block a claim" >&2
  exit 1
fi

# Model a renderer crash after claim: the lease remains non-zero until it
# expires, then the next independent status tick advances the sequence once.
expired_lease_state="42:7:0:$((now - 1))"
tmux -L "$socket" set -s @GHC_SL_HEARTBEAT_SCHED "$expired_lease_state"
env TMUX="$server_env" "$binary" scheduler-tick
case "$(tmux -L "$socket" show -sqv @GHC_SL_HEARTBEAT_SCHED)" in
  42:8:*:0) ;;
  *) echo "expired crash lease did not recover exactly once" >&2; exit 1 ;;
esac

tmux -L "$socket" set -s @GHC_SL_HEARTBEAT_SCHED 'bad#,}'
env TMUX="$server_env" "$binary" scheduler-tick
case "$(tmux -L "$socket" show -sqv @GHC_SL_HEARTBEAT_SCHED)" in
  42:1:*:0) ;;
  *) echo "malformed state was not repaired safely" >&2; exit 1 ;;
esac

tmux -L "$socket" set -s @GHC_SL_SCHED_GEN 43
env TMUX="$server_env" "$binary" scheduler-tick
case "$(tmux -L "$socket" show -sqv @GHC_SL_HEARTBEAT_SCHED)" in
  43:1:*:0) ;;
  *) echo "generation change did not restart sequence" >&2; exit 1 ;;
esac

tmux -L "$socket" set -s @GHC_SL_SCHED_ACTIVE 0
before=$(tmux -L "$socket" show -sqv @GHC_SL_HEARTBEAT_SCHED)
env TMUX="$server_env" "$binary" scheduler-tick
after=$(tmux -L "$socket" show -sqv @GHC_SL_HEARTBEAT_SCHED)
if [ "$before" != "$after" ]; then
  echo "inactive fence allowed a scheduler mutation" >&2
  exit 1
fi

# Model the adapter timeout boundary: the server commits the witness, then the
# client times out while a blocking command keeps its queue open. A retry with
# the old witness must skip rather than duplicate the mutation.
tmux -L "$socket" set -s @GHC_TEST_CAS old
python3 - "$socket" <<'PY'
import subprocess
import sys

socket = sys.argv[1]
command = [
    "tmux", "-L", socket,
    "if-shell", "-F", "#{==:#{@GHC_TEST_CAS},old}",
    "set -s @GHC_TEST_CAS claimed ; run-shell 'sleep 1' ; display-message -p CLAIMED",
    "display-message -p SKIPPED",
]
try:
    subprocess.run(command, check=False, capture_output=True, timeout=0.2)
except subprocess.TimeoutExpired:
    pass
else:
    raise SystemExit("expected client timeout after server commit")
PY
if [ "$(tmux -L "$socket" show -sqv @GHC_TEST_CAS)" != "claimed" ]; then
  echo "server did not retain the ambiguous committed mutation" >&2
  exit 1
fi
retry=$(tmux -L "$socket" if-shell -F '#{==:#{@GHC_TEST_CAS},old}' \
  'set -s @GHC_TEST_CAS duplicate ; display-message -p CLAIMED' \
  'display-message -p SKIPPED')
if [ "$retry" != "SKIPPED" ]; then
  echo "ambiguous mutation retry was not deduplicated: $retry" >&2
  exit 1
fi

# A committing heartbeat must not refresh clients: its `set` commands already
# redraw them, while refresh-client restarts #() jobs and SIGTERMs the driver
# that owns this tick.
tmux -L "$socket" set -s @GHC_SL_SCHED_ACTIVE 1 ';' \
  set -s @GHC_SL_HEARTBEAT_SCHED '43:20:0:0' ';' \
  set -g @GHC_SL_MODE 02 ';' \
  set -g status-interval 20
: >"$tmux_call_log"
env \
  TMUX="$server_env" \
  PATH="$tmp/bin:$PATH" \
  GHC_TMUX_REAL_TMUX="$real_tmux" \
  GHC_TMUX_TMUX_CALL_LOG="$tmux_call_log" \
  "$binary" scheduler-tick
case "$(tmux -L "$socket" show -sqv @GHC_SL_HEARTBEAT_SCHED)" in
  43:21:*:0) ;;
  *) echo "committing heartbeat did not complete" >&2; exit 1 ;;
esac
if [ "$(tmux -L "$socket" show -gqv status-interval)" != "1" ]; then
  echo "committing heartbeat did not publish its render" >&2
  exit 1
fi
if rg -Fq 'refresh-client' "$tmux_call_log"; then
  echo "scheduler commit refreshed clients" >&2
  exit 1
fi

printf '%s\n' "scheduler integration: ok"
