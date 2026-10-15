#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
tmp=$(mktemp -d /tmp/ghc-tmux-hook-gates-test.XXXXXX)
socket="ghc-tmux-hook-gates-test-$$"

cleanup() {
  env -u TMUX tmux -L "$socket" kill-server 2>/dev/null || true
  rm -rf "$tmp"
}
trap cleanup EXIT

# Renderer hooks are gated in-server: events that cannot change renderer-owned
# state must not start a renderer process. A counting shim stands in for the
# renderer so each scenario observes exactly which applies were launched.
python3 - "$repo_dir" "$tmp" "$socket" <<'PY'
import fcntl
import os
import pty
import select
import shutil
import signal
import struct
import subprocess
import sys
import termios
import time
from pathlib import Path

repo, tmp, socket = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
home = tmp / "home"
root = home / ".config/tmux"
calls = tmp / "renderer-calls"
renderer = root / "rust/ghc-tmux-status/target/release/ghc-tmux-status"
for directory in [root / "script", root / "conf/theme", renderer.parent]:
    directory.mkdir(parents=True)
shutil.copy(repo / "script/load-theme.sh", root / "script/load-theme.sh")
shutil.copy(repo / "conf/theme.tmux.conf", root / "conf/theme.tmux.conf")
for name in ["status01", "status02", "panestatus01", "panestatus02"]:
    shutil.copy(repo / f"conf/theme/{name}.tmux.conf", root / f"conf/theme/{name}.tmux.conf")
driver = root / "script/status-scheduler.sh"
driver.write_text("#!/bin/sh\nexit 0\n")
renderer.write_text(
    "#!/bin/sh\n"
    f'if [ "$1" = apply ] && [ "$2" != theme-loaded ]; then echo "$2" >>"{calls}"; fi\n'
    "exit 0\n"
)
for executable in [driver, renderer]:
    executable.chmod(0o755)

env = dict(os.environ, HOME=str(home), TERM="xterm-256color")
env.pop("TMUX", None)
env.pop("TMUX_PANE", None)


def tmux(*args):
    result = subprocess.run(["tmux", "-L", socket, *args], env=env, capture_output=True, text=True, timeout=10)
    if result.returncode:
        raise AssertionError(f"tmux {args!r}: {result.stderr}")
    return result.stdout.strip()


tmux("-f", "/dev/null", "new-session", "-d", "-s", "main", "-x", "200", "-y", "40", "sleep 120")
tmux("new-session", "-d", "-s", "work", "sleep 120")
tmux("set-environment", "-g", "HOME", str(home))
tmux("set", "-g", "@GHC_SL_MODE", "02")
server_env = tmux("display-message", "-p", "#{socket_path},#{pid},0")
subprocess.run(["bash", str(root / "script/load-theme.sh")], env=dict(env, TMUX=server_env), check=True, timeout=30)
assert tmux("show", "-sqv", "@GHC_SL_SCHED_ACTIVE") == "1", "loader did not activate status02"

master, slave = pty.openpty()
fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 200, 0, 0))
client = subprocess.Popen(["tmux", "-L", socket, "attach", "-t", "main"], stdin=slave, stdout=slave,
                          stderr=slave, env=env, start_new_session=True)
os.close(slave)


def pump(seconds):
    deadline = time.time() + seconds
    while time.time() < deadline:
        if select.select([master], [], [], 0.05)[0]:
            try:
                os.read(master, 65536)
            except OSError:
                return


def resize(*widths):
    for width in widths:
        fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", 40, width, 0, 0))
        os.kill(client.pid, signal.SIGWINCH)
        pump(0.05)


def launched(label, action, expected):
    calls.write_text("")
    action()
    # Background applies land asynchronously: wait for the expected set, then
    # keep observing so a late or extra launch cannot leak into the next case.
    deadline = time.time() + 3
    while sorted(set(calls.read_text().split())) != expected or time.time() < deadline - 2.2:
        if time.time() > deadline:
            break
        pump(0.1)
    pump(0.5)
    observed = sorted(set(calls.read_text().split()))
    if observed != expected:
        raise AssertionError(f"{label}: launched {observed or 'nothing'}, expected {expected or 'nothing'}")


pump(0.8)
client_name = tmux("list-clients", "-F", "#{client_name}").splitlines()[0]

# Fixed two-row layout (rows unset): width changes cannot change renderer state.
launched("two-row resize", lambda: resize(190, 180, 170), [])
# Popup and agent sessions are status-off groups that never appear in a list.
launched("popup created", lambda: tmux("new-session", "-d", "-s", "_popup@main"), [])
launched("agent created", lambda: tmux("new-session", "-d", "-s", "claude-0a1b"), [])
tmux("set", "-t", "=_popup@main:", "status", "off")
launched("switch to status-off session",
         lambda: tmux("switch-client", "-c", client_name, "-t", "=_popup@main:"), [])
launched("switch to listed session",
         lambda: tmux("switch-client", "-c", client_name, "-t", "=main:"), ["session-changed"])
launched("agent closed", lambda: tmux("kill-session", "-t", "=claude-0a1b:"), [])
launched("listed created", lambda: tmux("new-session", "-d", "-s", "listed"), ["session-created"])
launched("listed closed", lambda: tmux("kill-session", "-t", "=listed:"), ["session-closed"])
launched("listed renamed", lambda: tmux("rename-session", "-t", "=work:", "work2"), ["session-renamed"])

# Auto rows resolve layout from attached widths, so resizes reconcile again.
tmux("set", "-g", "@GHC_SL_ROWS", "auto")
launched("auto resize", lambda: resize(160, 150), ["client-resized"])
tmux("set", "-g", "@GHC_SL_ROWS", "2")
launched("explicit two-row resize", lambda: resize(140), [])

client.terminate()
client.wait(timeout=5)
PY

printf '%s\n' "hook gates integration: ok"
