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
