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

printf '%s\n' "scheduler integration: ok"
