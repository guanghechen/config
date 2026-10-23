#!/usr/bin/env bash
set -euo pipefail

crate_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
repo_dir=$(cd "$crate_dir/../.." && pwd)

python3 - "$repo_dir" <<'PY'
import os
from pathlib import Path
import pty
import select
import subprocess
import sys
import tempfile
import time

repo = Path(sys.argv[1])
# command-prompt substitutes only the first `%%`, so typed input must reach every
# command through the binding itself; drive the real keys through a pty client.
keymaps = [
    ("conf/keymap.tmux.conf", b"\x01N", b"\x01?"),
    ("conf/keymap.nix.tmux.conf", b"\x1bN", b"\x1b?"),
]
created_names = ["plain", "a}b,c", 'q"x$HOME;~']
rejected_inputs = ["", "#{GHC_UNSET_FORMAT}"]

with tempfile.TemporaryDirectory(prefix="ghc-tmux-session-prompt-", dir="/tmp") as scratch:
    env = dict(os.environ, HOME=scratch, TERM="xterm-256color")
    env.pop("TMUX", None)
    env.pop("TMUX_PANE", None)
    socket = str(Path(scratch) / "tmux.sock")

    def tmux(*args):
        result = subprocess.run(
            ["tmux", "-S", socket, *args], env=env, capture_output=True, text=True, timeout=10
        )
        if result.returncode:
            raise AssertionError(f"tmux {args!r}: {result.stderr}")
        return result.stdout.rstrip("\n")

    def drain(fd, seconds):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            ready, _, _ = select.select([fd], [], [], 0.02)
            if ready:
                os.read(fd, 65536)

    def session_names():
        return set(tmux("list-sessions", "-F", "#{session_name}").splitlines())

    def wait_for(predicate, label):
        deadline = time.monotonic() + 5
        while not predicate():
            assert time.monotonic() < deadline, label
            time.sleep(0.02)

    for keymap, new_key, rename_key in keymaps:
        tmux("-f", "/dev/null", "new-session", "-d", "-s", "main", "-x", "120", "-y", "30")
        tmux("set-option", "-g", "status-keys", "emacs")
        tmux("set-option", "-g", "detach-on-destroy", "off")
        tmux("source-file", str(repo / keymap))
        pid, fd = pty.fork()
        if pid == 0:
            os.execvpe("tmux", ["tmux", "-S", socket, "attach-session", "-t", "main"], env)
        try:
            drain(fd, 0.5)
            wait_for(lambda: tmux("list-clients", "-F", "#{client_name}"), "client did not attach")
            client = tmux("list-clients", "-F", "#{client_name}")

            def submit(key, text):
                tmux("switch-client", "-c", client, "-t", "main")
                os.write(fd, key)
                # No format exposes an open prompt; give the binding time to open it.
                drain(fd, 0.3)
                os.write(fd, b"\x15" + text.encode() + b"\r")
                drain(fd, 0.1)

            for name in created_names:
                submit(new_key, name)
                wait_for(lambda: name in session_names(), (keymap, name, session_names()))
                tmux("switch-client", "-c", client, "-t", "main")
                tmux("kill-session", "-t", "=" + name)

            for index, text in enumerate(rejected_inputs):
                before = session_names()
                submit(new_key, text)
                # A later submission through the same client proves the rejected one ran.
                sentinel = f"sentinel-{index}"
                submit(new_key, sentinel)
                wait_for(lambda: sentinel in session_names(), (keymap, text, session_names()))
                assert session_names() == before | {sentinel}, (keymap, text, session_names())
                tmux("switch-client", "-c", client, "-t", "main")
                tmux("kill-session", "-t", "=" + sentinel)

            submit(rename_key, "")
            submit(rename_key, "renamed")
            wait_for(lambda: "renamed" in session_names(), (keymap, session_names()))
            assert session_names() == {"renamed"}, (keymap, session_names())
            assert tmux("show-options", "-sqv", "@GHC_SESSION_NAME_INPUT") == "", keymap
        finally:
            subprocess.run(["tmux", "-S", socket, "kill-server"], env=env,
                           capture_output=True, timeout=10)
            os.close(fd)
            os.waitpid(pid, 0)

print("session prompt integration: ok")
PY
