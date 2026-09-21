#!/usr/bin/env bash
set -euo pipefail

crate_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
repo_dir=$(cd "$crate_dir/../.." && pwd)
binary="$crate_dir/target/debug/ghc-tmux-status"

cargo build --quiet --offline --locked --manifest-path "$crate_dir/Cargo.toml"

python3 - "$repo_dir" "$binary" <<'PY'
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

repo = Path(sys.argv[1])
binary = sys.argv[2]
names = ["literal-%H", "year-%Y", "rate-100%", "repeat-%%H", "line-%n%t", "mix-%H#[],}中"]

with tempfile.TemporaryDirectory(prefix="ghc-tmux-session-names-", dir="/tmp") as scratch:
    env = dict(os.environ, HOME=scratch)
    env.pop("TMUX", None)
    env.pop("TMUX_PANE", None)
    socket = str(Path(scratch) / "tmux.sock")
    tmux_command = ["tmux", "-S", socket, "-f", "/dev/null"]
    driver = Path(scratch) / ".config/tmux/script/status-scheduler.sh"
    driver.parent.mkdir(parents=True)
    driver.write_text("#!/bin/sh\nexit 0\n")
    driver.chmod(0o755)
    client = None

    def tmux(*args):
        result = subprocess.run(
            tmux_command + list(args), env=env, capture_output=True, text=True, timeout=10
        )
        if result.returncode:
            raise AssertionError(f"tmux {args!r}: {result.stderr}")
        return result.stdout.rstrip("\n")

    def apply():
        subprocess.run(
            [binary, "apply", "manual-apply"], env=renderer_env, check=True,
            capture_output=True, text=True, timeout=35
        )

    def session_item(owner, target, name):
        row = tmux("display-message", "-p", "-c", client_name, "-t", owner,
                   "#{T:status-format[0]}")
        marker = f"#[range=session|{target}]"
        assert marker in row, (name, row)
        item = row.split(marker, 1)[1].split("#[norange]", 1)[0]
        # format_draw folds escaped hashes once more after this expansion.
        assert name.replace("#", "##") in item, (name, item)
        return item

    try:
        main = tmux("new-session", "-d", "-s", "main", "-x", "400", "-y", "40",
                    "-P", "-F", "#{session_id}", "/bin/sleep", "120")
        other = tmux("new-session", "-d", "-s", "other", "-P", "-F", "#{session_id}",
                     "/bin/sleep", "120")
        tmux("source-file", str(repo / "conf/variable.tmux.conf"))
        tmux("source-file", str(repo / "theme/vsc-dark-modern.tmux.conf"))
        tmux("source-file", str(repo / "conf/theme.tmux.conf"))
        for option, value in [
            ("@GHC_SL_MODE", "02"),
            ("@GHC_SL_FG_SESSION_ITEM_LAST", "red"),
            ("@GHC_SL_FG_SESSION_ITEM_NAME", "blue"),
            ("@GHC_SL_FG_SESSION_ITEM_NUM", "blue"),
            ("@GHC_SL_BG_SESSION_ITEM_NAME", "black"),
            ("@GHC_SL_BG_SESSION_ITEM_NUM", "black"),
        ]:
            tmux("set-option", "-g", option, value)
        tmux("set-option", "-s", "@GHC_SL_SCHED_ACTIVE", "1")
        tmux("set-option", "-s", "@GHC_SL_SCHED_GEN", "1")
        renderer_env = dict(env, TMUX=tmux("display-message", "-p", "#{socket_path},#{pid},0"))
        client = subprocess.Popen(
            tmux_command + ["-C", "attach-session", "-t", main], env=env,
            stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
        deadline = time.monotonic() + 5
        while True:
            client_name = tmux("list-clients", "-F", "#{client_name}")
            if client_name:
                break
            assert time.monotonic() < deadline, "control client did not attach"
            time.sleep(0.02)
        tmux("refresh-client", "-t", client_name, "-C", "400,40")

        for name in names:
            target = tmux("new-session", "-d", "-s", name, "-P", "-F", "#{session_id}",
                          "/bin/sleep", "120")
            for rows in ["1", "2"]:
                tmux("set-option", "-g", "@GHC_SL_ROWS", rows)
                tmux("switch-client", "-c", client_name, "-t", target)
                apply()
                assert tmux("show-options", "-v", "-t", target, "status") == (
                    "on" if rows == "1" else "2"
                )
                session_item(target, target, name)

                tmux("switch-client", "-c", client_name, "-t", main)
                apply()
                for state in ["", f"sample|R{target}||B{target}|"]:
                    tmux("set-option", "-s", "@GHC_SL_SESSION_STATES", state)
                    item = session_item(main, target, name)
                    assert "#[fg=black,bg=red,reverse]" in item, (name, item)
                    if state:
                        assert "#[fg=black,bg=red,nobold]" in item, (name, item)
                        assert "⠋" in item or "⠴" in item, (name, item)
                right = tmux("display-message", "-p", "-c", client_name, "-t", main,
                             "#{T:status-right}")
                assert re.search(r"\b\d{2}:\d{2}:\d{2}\b", right), right

                tmux("switch-client", "-c", client_name, "-t", other)
                tmux("switch-client", "-c", client_name, "-t", main)
                apply()
                item = session_item(main, target, name)
                assert "#[fg=black,bg=blue,reverse]" in item, (name, item)
                assert "#[fg=black,bg=blue,nobold]" in item, (name, item)
                tmux("set-option", "-s", "@GHC_SL_SESSION_STATES", "")
            tmux("kill-session", "-t", target)
    finally:
        subprocess.run(tmux_command + ["kill-server"], env=env, capture_output=True, timeout=10)
        if client is not None:
            if client.stdin is not None:
                client.stdin.close()
            try:
                client.wait(timeout=3)
            except subprocess.TimeoutExpired:
                client.terminate()
                client.wait(timeout=3)

print("session names integration: ok")
PY
