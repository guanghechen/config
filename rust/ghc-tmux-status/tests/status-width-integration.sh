#!/usr/bin/env bash
set -euo pipefail

crate_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
repo_dir=$(cd "$crate_dir/../.." && pwd)
if [ "$#" -eq 0 ]; then
  cargo build --quiet --offline --locked --manifest-path "$crate_dir/Cargo.toml"
  binary="$crate_dir/target/debug/ghc-tmux-status"
elif [ "$#" -eq 1 ]; then
  binary=$1
else
  printf 'usage: %s [renderer-binary]\n' "$0" >&2
  exit 1
fi

python3 - "$repo_dir" "$binary" <<'PY'
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

repo = Path(sys.argv[1])
binary = str(Path(sys.argv[2]).resolve())
cache_options = [
    "@GHC_SL_STATUS02_LEFT", "@GHC_SL_STATUS02_RIGHT",
    "@GHC_SL_STATUS02_SESSION_FORMAT", "@GHC_SL_STATUS02_CURRENT_FORMAT",
    "@GHC_SL_RENDER_KEY",
]


def normalized(value):
    return re.sub(r"\d{2}:\d{2}:\d{2}", "<clock>", value)


def verify(names):
    with tempfile.TemporaryDirectory(prefix="ghc-tmux-status-width-", dir="/tmp") as scratch:
        env = dict(os.environ, HOME=scratch)
        env.pop("TMUX", None)
        env.pop("TMUX_PANE", None)
        base = ["tmux", "-S", str(Path(scratch) / "tmux.sock"), "-f", "/dev/null"]
        driver = Path(scratch) / ".config/tmux/script/status-scheduler.sh"
        driver.parent.mkdir(parents=True)
        driver.write_text("#!/bin/sh\nexit 0\n")
        driver.chmod(0o755)
        clients = []

        def tmux(*args):
            result = subprocess.run(base + list(args), env=env, capture_output=True, text=True, timeout=10)
            if result.returncode:
                raise AssertionError(f"tmux {args[:3]!r}: {result.stderr}")
            return result.stdout.rstrip("\n")

        def apply():
            result = subprocess.run(
                [binary, "apply", "manual-apply"], env=renderer_env,
                capture_output=True, text=True, timeout=35,
            )
            assert result.returncode == 0, result.stderr

        def resize(width):
            tmux("refresh-client", "-t", client_names[0], "-C", f"{width},40")

        def expand(value, client_index=0):
            return tmux("display-message", "-p", "-c", client_names[client_index], "-t", owner, value)

        def right():
            return normalized(expand("#{E:@GHC_SL_STATUS02_SESSION_FORMAT}"))

        def cached():
            return [tmux("show-options", "-qv", "-t", owner, option) for option in cache_options]

        def sample(running, bell):
            value = "sample:" + "".join(f"|R{item}|" for item in running)
            value += "".join(f"|B{item}|" for item in bell)
            tmux("set-option", "-s", "@GHC_SL_SESSION_STATES", value)

        try:
            ids = [
                tmux("new-session", "-d", "-s", name, "-x", "800", "-y", "40",
                     "-P", "-F", "#{session_id}", "/bin/sleep", "420")
                for name in names
            ]
            owner = ids[0]
            for path in ["conf/variable.tmux.conf", "theme/vsc-dark-modern.tmux.conf", "conf/theme.tmux.conf"]:
                tmux("source-file", str(repo / path))
            for option, value in [
                ("@GHC_SL_MODE", "02"), ("@GHC_CPU_NOW", "100"),
                ("@GHC_MEM_NOW", "100"), ("@GHC_NET_NOW", "↓99.9G ↑99.9G"),
            ]:
                tmux("set-option", "-g", option, value)
            tmux("set-option", "-s", "@GHC_SL_SCHED_ACTIVE", "1")
            tmux("set-option", "-s", "@GHC_SL_SCHED_GEN", "1")
            for _ in range(2):
                clients.append(subprocess.Popen(
                    base + ["-C", "attach-session", "-t", owner], env=env,
                    stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                ))
            deadline = time.monotonic() + 5
            while True:
                attached = dict(line.split("\t") for line in tmux(
                    "list-clients", "-F", "#{client_pid}\t#{client_name}"
                ).splitlines())
                if all(str(client.pid) in attached for client in clients):
                    break
                assert time.monotonic() < deadline, "control clients did not attach"
                time.sleep(0.02)
            client_names = [attached[str(client.pid)] for client in clients]
            for name in client_names:
                tmux("refresh-client", "-t", name, "-C", "800,40")
            renderer_env = dict(env, TMUX=tmux("display-message", "-p", "#{socket_path},#{pid},0"))

            for rows in ["2", "1"]:
                tmux("set-option", "-g", "@GHC_SL_ROWS", rows)
                sample([], [])
                apply()
                snapshot = cached()
                assert all(snapshot), "guarded apply did not publish every cache"
                apply()
                assert cached() == snapshot, "settled apply changed the rendered cache"
                visible = re.findall(r"(?<!#)#\[range=session\|(\$\d+)\]", snapshot[0])
                assert visible and owner in visible
                hidden = sorted(set(ids) - set(visible))
                if len(ids) == 40:
                    assert hidden, "large fixture must exercise the bounded session list"
                thresholds = set(map(int, re.findall(r"#\{e\|>=:#\{client_width\},(\d+)\}", snapshot[2])))
                assert thresholds
                scenarios = [
                    ("running", visible, [], True),
                    ("bell", [], visible, True),
                    ("both", visible, visible, True),
                    ("mixed", visible[::2], visible[::3], True),
                    ("hidden", hidden, hidden, True),
                    ("inactive", visible, visible, False),
                ]
                widths = {1, 800}
                for _, running, bell, active in scenarios:
                    extra = 2 * len(set(visible) & set(running) & set(bell)) if active else 0
                    for threshold in thresholds:
                        widths.update(max(1, threshold + offset + delta)
                                      for offset in [0, extra] for delta in [-1, 0, 1])
                lookup_widths = set(widths)
                for _, running, bell, active in scenarios:
                    extra = 2 * len(set(visible) & set(running) & set(bell)) if active else 0
                    lookup_widths.update(max(1, width - extra) for width in widths)
                baseline = {}
                for width in sorted(lookup_widths):
                    resize(width)
                    baseline[width] = right()
                resize(1)
                minimum_right = int(expand("#{w:#{E:@GHC_SL_STATUS02_SESSION_FORMAT}}"))
                wide_baseline = normalized(expand("#{E:@GHC_SL_STATUS02_SESSION_FORMAT}", 1))
                if "@GHC_SYM_CPU" in snapshot[2]:
                    assert "100%" in wide_baseline, "metric percent escaping changed"
                revision = tmux("show-options", "-sqv", "@GHC_SL_RENDER_REV")
                assert revision, "guarded apply did not publish a server render revision"

                for label, running, bell, active in scenarios:
                    sample(running, bell)
                    tmux("set-option", "-s", "@GHC_SL_SCHED_ACTIVE", "1" if active else "0")
                    extra = 2 * len(set(visible) & set(running) & set(bell)) if active else 0
                    for width in sorted(widths):
                        resize(width)
                        observed = right()
                        expected = baseline[max(1, width - extra)]
                        assert observed == expected, (
                            f"rows={rows} state={label} width={width} extra={extra}: "
                            "metrics did not follow the visible second-prefix budget"
                        )
                        if rows == "2":
                            left_width = int(expand("#{w:#{E:@GHC_SL_STATUS02_LEFT}}"))
                            right_width = int(expand("#{w:#{E:@GHC_SL_STATUS02_SESSION_FORMAT}}"))
                            if width >= left_width + minimum_right:
                                assert left_width + right_width <= width, (
                                    f"state={label}: row needs {left_width + right_width} columns, has {width}"
                                )
                        assert normalized(expand("#{E:@GHC_SL_STATUS02_SESSION_FORMAT}", 1)) == wide_baseline
                    assert cached() == snapshot, "state transition rewrote a rendered cache"
                    assert tmux("show-options", "-sqv", "@GHC_SL_RENDER_REV") == revision
                tmux("set-option", "-s", "@GHC_SL_SCHED_ACTIVE", "1")
                sample([], [])
                resize(800)
                print(f"status width fixture: sessions={len(ids)}, visible={len(visible)}, rows={rows}: ok", flush=True)
        finally:
            subprocess.run(base + ["kill-server"], env=env, capture_output=True, timeout=10)
            for client in clients:
                if client.stdin:
                    client.stdin.close()
                try:
                    client.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    client.terminate()
                    client.wait(timeout=3)


verify(["alpha", "beta", "gamma", "delta"])
verify([f"s{index:02}" for index in range(40)])
print("status width integration: ok")
PY
