# Explorer acceptance and measurements

These tools exercise `era.m.explorer.Widget` with the checkout's installed release
`lua/yoz.so` (`yoz.dll` on Windows). They use existing Neovim, Node and native builds;
they do not install packages or change either checkout's Git state.

## Widget benchmark

```sh
# Current native Explorer; prints a fresh result directory under the system temp directory.
node __test__/bench/explorer/run.mjs --samples 5

# Alternating legacy/native Tree comparison, plus native List measurements.
node __test__/bench/explorer/run.mjs --baseline ~/.config/nvim --samples 5 --mode both

# Fast harness smoke; select multiple cases by repeating --case.
node __test__/bench/explorer/run.mjs --baseline ~/.config/nvim \
  --samples 1 --repeats 1 --case mixed_200 --mode both

# Rebuild summaries from one result directory.
node __test__/bench/explorer/analyze.mjs /absolute/result/directory
```

`--current` selects another native checkout; `--baseline` selects the legacy
Explorer implementation. `--nvim`, `--output` and `--timeout-ms` select the executable,
new output directory and whole-process deadline. Run `--help` for the full CLI.
An existing output directory is rejected, so smoke, calibration and formal samples
cannot silently accumulate in one file. On failure, metadata marks the run failed
and completed raw samples remain available. Temporary filesystem fixtures are removed
on success, failure and handled interruption.

The five cases are 200 mixed entries, flat 1k/10k/50k files, and a 1k-file branch
beside 9k files. Each process measures open, cursor movement, unchanged refresh and
unchanged empty Git notifications; Tree's branch case also measures cold expansion,
warm expansion and collapse. The legacy viewtype flag does not recursively project
List directories, so List is measured only for the native implementation.

Outputs:

- `metadata.json`: host, Neovim version, commits, dirty worktrees, native module and
  harness hashes, parameters and measurement conditions.
- `results.jsonl`: one record per fresh process, including all repeated operations
  and memory snapshots. No samples are appended from a previous invocation.
- `summary.json`: counts, median, min/max and, for at least 20 independent processes,
  descriptive p95. Repeats inside a process do not become independent samples:
  aggregation first takes each process's median, then compares those medians.
- `report.md`: compact tables generated from the same raw records.

Measurement boundaries:

- Actual Widget, 110×40 attached UI, 44-column Explorer, Rosé Pine main, hidden items
  shown, compression disabled. Modules/theme load before the timer; plugin startup
  is excluded. Disk/page caches are warm from fixture creation; A/B order alternates.
- `visible_ms` ends when the parent observes the requested content/cursor in a UI
  flush. Terminal font/GPU rendering is excluded. `ready_ms` waits for all expected
  rows and an idle renderer, including legacy offscreen icons and native viewport
  decorations. A fast first screen does not imply all rows have loaded.
- `empty_git_notification` deliberately disables Git collection and publishes
  unchanged empty status. It measures notification handling and redraw, **not** a Git
  process, changed statuses, ignore queries or LSP. The integration checks below cover
  those behaviors separately.
- A nominal 2 ms scheduled timer records the largest observed gap per operation.
  Natural GC remains enabled during timing; full GC precedes memory snapshots.
  RSS uses libuv's resident-set measurement. RSS, Lua heap and Rust retained accounting
  overlap and must not be added together. RSS growth alone does not establish a leak.
- One-process smoke runs validate the harness; they are not performance acceptance.
  Run formal samples sequentially without concurrent builds or tests. Do not combine
  results from different commits, native modules, platforms or measurement modes.

## Git, filesystem and selection integration

```sh
nvim -l __test__/run.lua era/m/explorer/runtime_spec.lua
nvim -l __test__/run.lua era/m/explorer/selection_spec.lua
```

The Git case creates a disposable repository and changes only its index and files.
It uses actual status/ignore jobs, external writes and rename, native Explorer IO,
ignore invalidation on focus, and watch/buffer release on hide. Ordinary specs use
the existing debug native build, as described in the main test guide.

Pending selection checks cover complete-directory shortcuts, automatic source
loading, cancellation, failure/retry, revision conflicts and closing the originating
pane. They assert that no partially loaded collection reaches the requested action.

## Installed LSP server

```sh
nvim -l __test__/bench/explorer/lsp.lua ~/.local/share/nvim/mason/bin/vtsls
```

This opt-in probe starts the supplied, already installed `vtsls` over stdio in a
temporary TypeScript project. It renames through the actual Explorer action and
checks server-driven import edits, modified buffer preservation and client reattachment.
It observes requests/notifications without replacing the server's answers. No buffer
is saved. The output records which rename capabilities the server supports; vtsls
0.3.0 uses `didRenameFiles` followed by `workspace/applyEdit`, not `willRenameFiles`.
The latter's preparation, cancellation and error paths have separate Explorer specs.

## Long session

```sh
nvim -l __test__/bench/explorer/soak.lua 200 1000 > /tmp/explorer-soak.json
```

Arguments are cycles (a multiple of 20) and fixture file count, plus one watched
sentinel file. Every cycle performs
fold/expand, Tree/List transitions, refresh, an external rename through UI flush,
hide and reopen. A second tab is exercised every 10 cycles; the entire Widget/session
is disposed and recreated every 20 cycles. Git collection is disabled here to isolate
the browsing lifecycle; the separate Git integration test uses real collection.

The JSON retains every memory sample and the watch latency distribution. Hidden panes
must have zero watches and queued work, and no orphan Explorer buffers. The release
checks distinguish retained navigation-history entries from live session/data/view
ownership. Compare memory across equivalent lifecycle points, after warm-up.
All cycle samples retain normal LuaJIT behavior. The final ownership assertion flushes
compiled traces (which can retain closure constants), then checks that disposed
session/data/view objects are collectible. The output also retains the memory and
weak-reference counts **before** that trace flush; this boundary must not be omitted
when interpreting the result. Disposed Widget shells retained by navigation history
are excluded from the session release assertion.

## Platform evidence

The tools select the native module for macOS/Linux/Windows and avoid host-specific
RSS commands. This is portability support, not evidence that another platform passed.
Linux, Windows and WSL still require execution on their actual runtime, including OS
watch and trash behavior. Cross-compilation and Windows path simulation do not replace
those checks. Trash tests use a disposable tool fixture, not the user's recycle bin.

2026-09-24 local acceptance: Apple M2 Max / 32 GiB, Neovim 0.12.5 Release,
installed release native module. All five benchmark cases completed (legacy Tree,
native Tree and native List: 15 fresh-process smoke runs, one sample each).
These smoke samples validate every case and output path; the earlier five-process
performance comparison remains a separate dataset.

The 200-cycle / 1k-file session run passed all watch, queue and buffer checks,
including 20 second-tab openings and 10 full session disposals. RSS over the last
50 cycles ranged from 34.64 to 34.84 MiB; Lua heap ranged from 2.26 to 2.53 MiB.
Final weak-reference counts for disposed sessions, data and views were already zero
**before** the final JIT trace flush. Watch rename-to-UI-flush latency was median
190.61 ms / p95 199.76 ms, including the backend's 150 ms coalescing window.
This is a finite stability run, not proof against every possible leak.

The real Git/watch integration and vtsls 0.3.0 rename probe passed. A read-only run
against the configuration repository also passed modified-file Git decoration,
reveal, shared state in two tabs and List hide/reopen, ending with zero watches and
queued work. The session work uncovered and fixed immediate callback retention on
unsubscribe; its weak-reference and reentrant-delivery regression cases are in
`../../specs/stl/c/subscribers_spec.lua`.

Final regression after the native source-retry fix: `nvim -l __test__/run.lua --timeout 60000`
passed all 227 suites / 1,708 cases; the earlier Node run passed all 9 tests. Changed Lua files passed StyLua and annotation
alignment checks. The Visual directory-range case now waits for the revealed child
and cursor to be published before typing its range; 20 isolated repetitions passed
before the successful full regression run.

R1 retry verification uses real directory permission failures on non-root POSIX hosts:
repeated attempts while unreadable fail without partial output, restoring permissions
lets the next action export the complete selection without a separate refresh, and a
fully selected directory still exports its path without reading its failed children.
Native tests also cover required/unrelated error slots, stale tokens, cancellation,
repeated read failure and the retained Ready snapshot. The rebuilt release module
passed all 7 selection cases. Rust `yoz` passed 456 tests with 15 opt-in cases ignored;
`yoz-im` passed all 26 when rerun separately after two helper timeouts. A root-watch
timeout in the first Explorer run passed on the subsequent serial run and full Lua run.
