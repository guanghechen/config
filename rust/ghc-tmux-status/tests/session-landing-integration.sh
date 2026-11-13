#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
tmp=$(mktemp -d /tmp/ghc-tmux-session-landing-test.XXXXXX)
socket="$tmp/tmux.sock"

cleanup() {
  env -u TMUX tmux -S "$socket" kill-server 2>/dev/null || true
  rm -rf "$tmp"
}
trap cleanup EXIT

# A destroyed session hands its clients to the most recently active session. The
# session policy from tmux.conf must move a displaced client off status-off agent
# and popup sessions, while explicit attaches and switches into them stay put.
python3 - "$repo_dir" "$tmp" "$socket" <<'PY'
import fcntl
import os
import pty
import select
import shutil
import struct
import subprocess
import sys
import termios
import threading
import time
from pathlib import Path

repo, tmp, socket = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
home = tmp / "home"
(home / ".config/tmux/script").mkdir(parents=True)
shutil.copy(repo / "script/leave-hidden-session.sh", home / ".config/tmux/script/leave-hidden-session.sh")
config = (repo / "tmux.conf").read_text()
(tmp / "hooks.conf").write_text(config[config.index("## Hooks"):config.index("## Plugins")])

env = {key: value for key, value in os.environ.items() if key not in ("TMUX", "TMUX_PANE")}
env.update(HOME=str(home), TERM="xterm-256color")


def tmux(*args):
    result = subprocess.run(["tmux", "-S", socket, *args], env=env, capture_output=True, text=True, timeout=10)
    if result.returncode:
        raise AssertionError(f"tmux {args!r}: {result.stderr}")
    return result.stdout.strip()


masters = []
stop = threading.Event()


def drain():
    while not stop.is_set():
        if not masters:
            time.sleep(0.05)
            continue
        ready, _, _ = select.select(masters, [], [], 0.05)
        for fd in ready:
            try:
                os.read(fd, 65536)
            except OSError:
                masters.remove(fd)


def attach(session):
    known = set(tmux("list-clients", "-F", "#{client_name}").split())
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
    subprocess.Popen(["tmux", "-S", socket, "attach", "-t", session], stdin=slave, stdout=slave,
                     stderr=slave, env=env, start_new_session=True)
    os.close(slave)
    masters.append(master)
    for _ in range(100):
        added = set(tmux("list-clients", "-F", "#{client_name}").split()) - known
        if added:
            return added.pop()
        time.sleep(0.05)
    raise AssertionError(f"client did not attach to {session}")


def session_of(client):
    return tmux("display-message", "-t", client, "-p", "#{session_name}")


def settle(client, expected, description):
    # The check runs as a background job after the hook fires.
    for _ in range(40):
        if session_of(client) == expected:
            break
        time.sleep(0.05)
    time.sleep(0.5)
    actual = session_of(client)
    if actual != expected:
        raise AssertionError(f"{description}: client is on {actual}, expected {expected}")


threading.Thread(target=drain, daemon=True).start()
tmux("-f", "/dev/null", "new-session", "-d", "-s", "main", "-x", "120", "-y", "40", "sleep 600")
tmux("set-environment", "-g", "HOME", str(home))
tmux("set", "-g", "detach-on-destroy", "off")
tmux("source-file", str(tmp / "hooks.conf"))
for name in ["other", "claude-abc"]:
    tmux("new-session", "-d", "-s", name, "sleep 600")
main_client = attach("main")
# Only clients older than the attach window count as displaced.
time.sleep(2.2)

agent_client = attach("claude-abc")
settle(agent_client, "claude-abc", "an explicit attach to an agent session")
tmux("switch-client", "-c", main_client, "-t", "claude-abc")
settle(main_client, "claude-abc", "an explicit switch into an agent session")
tmux("switch-client", "-c", main_client, "-t", "main")
settle(main_client, "main", "a switch back to main")

# The agent session is now more recently active than `other`, so tmux moves the
# main client there when main closes; the policy moves it on to `other`.
tmux("kill-session", "-t", "main")
settle(main_client, "other", "a client displaced onto an agent session")
settle(agent_client, "claude-abc", "an agent client unrelated to the destroyed session")

# With no visible session left, the displaced client stays where tmux put it.
tmux("kill-session", "-t", "other")
settle(main_client, "claude-abc", "a displaced client without a visible session")
stop.set()
PY
echo "session landing integration: ok"
