# Explorer benchmark and acceptance

Node entry points and shared input provenance live in `script/benchmark/`.
Lua probes, support and fixtures live under `__test__/`.

The unified runner covers browsing, real configuration startup, Git, copy throughput,
idle/activity CPU, and lifecycle/UI/LSP acceptance. It uses installed Neovim, Node,
Rust tooling and plugins; it does not install packages or change either checkout's
Git state. Git writes are confined to newly created disposable Git fixtures.

## Unified runner

```sh
# Comprehensive matrix: alternating legacy/native Tree, native List, and acceptance.
# Build both release libraries from their sources without deploying to either checkout.
node script/benchmark/explorer.mjs --baseline ~/.config/nvim --build --samples 3

# Native only, using the installed library.
node script/benchmark/explorer.mjs --samples 3

# Fast harness smoke. Repeat --case to select any subset.
node script/benchmark/explorer.mjs --baseline ~/.config/nvim \
  --samples 1 --repeats 1 --mode both --case mixed_200 --case git_1000

# Rebuild the report from an existing result directory.
node script/benchmark/explorer-report.mjs /absolute/result/directory
```

Run `--help` for all options. Defaults are three independent processes,
three interaction repeats, both widget modes, 200 soak cycles, and a ten-minute
deadline per driver process. `--samples` and `--repeats` accept 1–100;
`--cycles` accepts multiples of 20 through 10,000. Large sample counts may
require a longer `--timeout-ms` because several acceptance drivers manage all
their samples within one invocation. Copy/startup run once per process; unchanged
refresh repeats at most three times. Soak runs the requested cycles in each sample.

`--current` selects another native checkout and `--baseline` a legacy checkout.
The harness stays in this checkout. `--output` must name a new directory outside
the measured and harness checkouts; by default it is created in the system temp
directory. Result directories are never reused. Fixtures are removed on success,
failure and handled interruption. A failed case retains diagnostics and lets the
remaining cases run; interruption or input drift stops the matrix.
`--native` and `--baseline-native` select preserved modules, including outputs from
an earlier isolated build. Their receipts are verified against the selected sources;
these flags cannot be combined with `--build`.

The default 24 cases are:

| Cases | Coverage |
| --- | --- |
| `mixed_200`, `flat_1000`, `flat_10000`, `flat_50000` | Widget open, cursor, scrolling, single/Visual selection, refresh, empty Git notification, hide/reopen |
| `branch_1000_plus_9000` | The same operations, plus cold/warm expansion and collapse in Tree |
| `startup_200` | Actual init.lua, installed plugins and first default Explorer |
| `git_1000` | Real status/ignore queries, staged/untracked/ignored entries, changed Git annotations |
| `copy_64mib`, `copy_100_files`, `copy_1000_files`, `copy_10000_files` | Dense large-file copy and four-byte-file count scaling; actual actions and verified contents |
| `copy_1000_4kib`, `copy_1000_64kib` | File-size scaling with the same 1,000-file count |
| `copy_1000_expanded`, `copy_1000_outside` | Expanded source versus a destination outside the display root |
| `navigation` | Native typed selection, nested reveal, removed-root recovery and view release across fresh processes |
| `idle` | Legacy/native visible, hidden and disposed idle phases |
| `watch`, `jobs_activity` | Native burst/continuous watch activity and a 256 MiB sparse-file Job |
| `root_watch` | Native macOS recursive subscription and external-symlink acceptance |
| `soak` | Native repeated browsing, multi-tab, release and memory checks |
| `full_config`, `jobs_ui`, `lsp` | Native real prompts/Jobs/exit, unsaved buffers and installed-server rename |

The legacy viewtype flag does not recursively project directories. Tree is the common
widget comparison; List is native-only. Other native-only cases are labeled acceptance,
not legacy/native wins. Missing installed vtsls marks LSP `blocked`; a non-macOS host
marks recursive root-watch `not_applicable`. No selected case disappears silently:
coverage includes passed, failed, blocked, not_applicable and not_run. Failed or blocked
runs return a nonzero exit status.

## Inputs and build receipts

`--build` uses `script/build.mjs --root … --output … --offline` with
`cargo build --release --locked`. Dependencies must already be cached. The libraries
and their `.build.json` sidecars remain under the result directory; temporary Cargo
targets are removed after a successful build. The measured checkout is not deployed to.

A receipt binds the loaded artifact's SHA-256 to the native source content, build
command and toolchain. Native inputs include `rust/` and `.cargo/`, excluding
`rust/target/`; Lua/init/lockfile contents have a separate runtime fingerprint.
Builds reject source changes during compilation. Measurement rejects source, artifact,
harness or plugin runtime-content drift. Checkout Git metadata changes are recorded
in `repository_metadata_changes`; staging unchanged contents does not invalidate a
measurement. The analyzer also rejects duplicate trials and
mixed input fingerprints within a comparison group.

Without `--build`, a matching receipt is `verified`; a missing or unreadable
receipt is explicitly `unverified`. A source/artifact mismatch is rejected.
A hash of an installed binary alone does not prove that it was built from the current
source. Full-config cases first run an unmeasured startup to discover configured
plugins, then fingerprint their Lua/Vim/JS, query/snippet/JSON, Wasm and native-library
files, including Git-ignored dylib/so/dll files. Snapshots are checked before and after
cases and comparable processes; unverifiable inputs stop the run. CI configuration,
Rust/compiler intermediates and arbitrary external programs are outside this runtime snapshot.
These are local source-bound builds, not hermetic compiler/environment builds.

Outputs:

- `metadata.json`: host, Neovim, commits/trees, NUL-safe worktree metadata, source
  and harness fingerprints, build receipts, commands, conditions and complete coverage.
- `results.jsonl`: one record per comparable fresh process, repeated operations and
  memory snapshots. Startup also records plugin paths, loaded state, lock commits and
  installed Git commits/worktree state and content fingerprints. Installed plugin caches are retained.
- `probes/*.json`: acceptance results, including event/cycle samples, assertions,
  runtime ownership, server details and the probe's own measurement boundaries.
- `logs/`: driver stdout/stderr, build logs and failure diagnostics.
- `summary.json` and `report.md`: process-level statistics and coverage.

## Measurement boundaries

- Widget: actual Widget, 110×40 attached UI, 44-column pane, Rosé Pine main, hidden
  entries shown and compression disabled. Modules/theme load before timing; Git/LSP
  collection and plugin startup are excluded. Source hashing and fixture creation warm
  filesystem/page caches. A/B and B/A alternate, without concurrent measurements.
- `visible_ms` ends when the parent observes the requested content/cursor in a UI
  flush; terminal/GPU rendering is excluded. `ready_ms` waits for expected rows and
  renderer completion, including legacy offscreen icons and native viewport decoration.
  First screen, operation completion and all-row readiness are distinct boundaries.
- Cursor uses typed j/k; scrolling uses typed Ngg across the viewport. Tab toggles a
  single entry; Visual selection spans 100 file rows. Selection timing requires the
  published count and revision to change, and makes no UI-flush claim.
- Startup includes process creation, the UI handshake, actual configuration readiness
  and the first default Explorer. Workspace/context state is isolated in a temporary
  directory, automatic input-method changes are disabled, and each checkout uses its
  own plugin lockfile. An unmeasured provenance startup and input hashing warm plugin
  caches before sampling; this measures fresh processes, not empty plugin caches.
  The child observes configuration readiness every 5 ms and the first Explorer every
  2 ms, and sends completion notifications. First-Explorer readiness also requires its
  first UI flush. The parent does not issue readiness RPCs while timing.
- Git uses a new repository with staged files but no commit. Each repeat modifies and
  restores a tracked file. `query_ms` waits for the real refresh; `ready_ms`
  additionally checks the changed annotation in the Explorer model. This is not Git
  UI-flush timing. `empty_git_notification` separately measures unchanged empty
  notification handling with collection disabled.
- Copy invokes the actual c action and automatically accepts the path prompt. Source
  and destination normally share the displayed directory; the destination sorts after
  the source. The expanded-source case loads its children before timing; the outside
  case copies into a sibling of the display root. These two cases make no destination
  UI-flush claim, because the output is offscreen or outside the displayed tree.
  `job_ms` ends at native terminal
  notification or the legacy copy return; throughput divides verified bytes/files by
  this interval. `ready_ms` includes publication and native result draining/unlock.
  `visible_ms` is destination-name appearance: a directory may appear before its
  contents finish copying. The runner hashes every source/destination file after
  timing. The matrix uses 100/1,000/10,000 four-byte files, 1,000 files of 4 KiB/64 KiB,
  and a dense 64 MiB file. These warm-cache workloads do not establish sustained
  throughput on a slow device; the sparse Job activity probe is separate.
- Comparable Widget, copy, Git and startup phases deliver completion notifications;
  `observer_rpcs` must be zero during each timed operation. Widget readiness is checked
  on frame/cursor events and a 2 ms timer. Copy/Git only begin readiness checks after
  the real terminal/query notification. `readiness_checks` records those checks.
  This avoids a `vim.wait` predicate issuing many RPCs while an asynchronous Job runs:
  the predicate interval is not a request rate limit when events keep arriving.
- `cpu_ms` and `main_cpu_ms` cover the operation through ready; `job_cpu_ms` and
  `job_main_cpu_ms` stop at native terminal notification or the legacy copy return.
  Process CPU includes native threads; main-thread CPU is collected on macOS.
  Timers and necessary observation work remain included, so these are not pure IO
  algorithm timings. Historical results using readiness RPC polling remain separate.
- A nominal 2 ms scheduled timer records the largest tick gap, including its final
  interval through completion. Natural GC remains enabled during timing; full GC
  precedes memory snapshots. Process CPU includes native threads and observation cost.
- Schema 2 calls the libuv memory reading `process_memory_bytes` and records its kind.
  On macOS/libuv 1.53+ it is `physical_footprint`, following
  [libuv's Darwin implementation](https://github.com/libuv/libuv/blob/v1.53.0/src/unix/darwin.c).
  Other platforms report RSS; older Darwin versions retain an unresolved libuv label.
  This is not interchangeable with `ps` RSS. Process memory, Lua heap and native
  retained accounting overlap; do not add them or infer a leak from growth alone.
- Repeated operations first become one median per process, then independent-process
  median/min/max. Descriptive p95 is a percentile of those process medians and requires
  at least 20 independent processes. `maximum_observation` separately preserves the
  slowest individual operation; it is not a percentile. Watch
  events and soak cycles remain observations within their process, not independent
  trials. One-process smoke validates wiring only. Schema 1 results require a rerun;
  historical RSS labels are not silently reinterpreted.

Run performance samples sequentially without concurrent tests/builds. The direct
drivers below remain useful for focused diagnostics; use the unified runner when
source/build provenance, coverage and a reproducible report are required.

## Navigation acceptance

```sh
node script/benchmark/explorer.mjs --case navigation --samples 20 --native /absolute/yoz.so
```

Each fresh process performs ten cycles. Real j/mx input selects a file for cut,
nested reveal preserves its selection, and external removal of the display root is
followed by refresh and reveal of an existing external file. Assertions check the
native cursor and the displayed target through UI flushes. Every cycle hides and
disposes the view after watches and queued work reach zero. This is native-only
acceptance; it makes no legacy/native latency claim.

The first workspace is also the child process's cwd. On filesystems that allow its
external removal, later rendering must use absolute resource paths without depending
on `uv.cwd()`. The macOS acceptance exercises this condition without dismissing error
prompts. Fileicon specs separately cover unavailable cwd and case-sensitive filetype
matching, including the unknown-extension fallback.

The ordinary navigation/recovery specs separately control stale observation,
superseded navigation, delayed cursor events, unavailable frame preparation, stale
recovery plans and projection errors. Native tests coalesce loading/selection updates
with reveal before projection to validate expansion invalidation deterministically.

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

This probe starts the supplied, already installed `vtsls` over stdio in a
temporary TypeScript project. It renames through the actual Explorer action and
checks server-driven import edits, modified buffer preservation and client reattachment.
It observes requests/notifications without replacing the server's answers. No buffer
is saved. The output records which rename capabilities the server supports; vtsls
0.3.0 uses `didRenameFiles` followed by `workspace/applyEdit`, not `willRenameFiles`.
The latter's preparation, cancellation and error paths have separate Explorer specs.

## Full configuration

```sh
nvim -l __test__/bench/explorer/full_config.lua 5 200 > /tmp/explorer-full-config.json
```

Arguments are fresh processes and cursor moves per process. This loads the actual
`init.lua`, installed plugins, UI dressing and runtime services. It creates 200 text
files under an owned temporary directory and isolates context persistence;
automatic input-method changes are disabled. It uses the real create/rename/delete
prompts, verifies that rename and delete preserve an unsaved buffer, then types
cursor movement while refreshing every 40 ms. It also checks errors after disposal.
The fixture is removed on success or failure; only its own files are permanently deleted.

`prompt_ms` ends when the parent observes the prompt text in the attached UI.
`confirmed_ms` waits for filesystem/buffer effects and published Explorer content;
it does not measure a UI flush. Cursor timing waits for the window and native frame
to agree on the requested row. All timings include parent RPC observation and exclude
configuration startup and GPU rendering. Each operation waits for its intended cursor
target before accepting the next key, so prompt readiness is distinct from mutation
completion. These checks do not replace the separate Git and installed-LSP probes.

Job notification E2E uses the same full configuration and real input/select UI:

```sh
nvim -l __test__/bench/explorer/jobs_ui.lua 3 > /tmp/explorer-jobs-ui.json
```

Each fresh process accepts and declines overwrite prompts, copies and moves through
missing parent directories, cancels preparation, pastes 260 selected files while hidden,
cancels a running 10,000-file copy through the Space menu, and starts another operation.
It then exits during another native copy; samples alternate typed quit confirmation
and a direct quit command. A `VimLeavePre` marker must show acknowledged cancellation
and an empty Job registry before the process exits.
The probe checks exact file contents, terminal state, selection release, result delivery,
reopened UI content, and zero pending work/watches after disposal. RPC positions the
cursor and fills actual path prompts; action keys, confirmations and menu choices use
Neovim input. A bounded synchronous Lua pause lets native IO finish while hidden so
more than 128 results await delivery. Cancellation may leave a partial destination.
Only owned fixtures are changed and removed; native Jobs and prompt callbacks are not
mocked. The existing cancellation warning is recorded separately only when its Job is
cancelled; other warning/error reports fail the probe. JSON includes the observed UI
text, scenario results and any failure diagnostic.

2026-09-27 validation: all nine scenarios passed in four fresh processes (36 cases),
including two typed quits and two scripted quits during real native copies. Exit markers
confirmed cancellation, an empty Job registry and revoked view publication, with no
unexpected reports. The regression originally reproduced `Neovim is exiting` and
`Treeview buffer changed while preparing a frame` on both the current and pre-notification
Lua/native snapshots. Revoking the view synchronously on buffer unload prevents pending
annotation/frame completion from publishing during teardown; window cleanup stays deferred.

## Idle CPU

```sh
# Native only, three fresh processes.
nvim -l __test__/bench/explorer/idle.lua > /tmp/explorer-idle.json

# Alternating legacy/native, three fresh processes each.
nvim -l __test__/bench/explorer/idle.lua ~/.config/nvim 3 > /tmp/explorer-idle-comparison.json
```

Each process opens the actual Widget with 200 empty Lua files and a 110×40 attached
UI, then measures visible, hidden and disposed phases. Each phase settles for 500 ms
after GC, followed by 3 s without parent polling. The benchmark timer is stopped;
Git collection and LSP are disabled. CPU comes from process-wide libuv `getrusage`,
  including native worker threads, and is expressed as a percentage of one CPU core.
Raw samples include wall time, CPU time, process memory and redraw-notification counts. Run this
sequentially with the other performance tools; record the checkout and native build
alongside the output. The short quiet window is an idle measurement, not an energy
or full-configuration CPU benchmark.

## Recursive root-watch acceptance (macOS)

```sh
nvim -l __test__/bench/explorer/root_watch.lua 3
# Use a preserved release native module before installing it.
nvim -l __test__/bench/explorer/root_watch.lua 3 /absolute/yoz.so
```

The actual Widget opens 96 expanded directories with an attached 110×40 UI.
It requires `roots=1`, `directories=97`, and `limited=false`, then checks external
create/rename/delete beyond the old 50-directory cap through grid flushes. It also
covers renamed directories, rereading collapsed caches, a separate external symlink
root and target recovery, narrowing the view, releasing all subscriptions on hide,
and clean disposal/exit. The JSON includes coverage and screen rows.

Each fresh process also records a 3 s idle window after 500 ms settling with the
fixture timer stopped and no parent polling; Git collection and LSP are disabled.
Run sequentially with other tests/builds when using its CPU/process-memory samples. The 50-root
budget still applies to independent OS roots; ordinary expanded subdirectories do
not consume additional roots on macOS. Linux/Windows retain their nonrecursive
directory budget and are outside this probe's runtime coverage.

## Job and filesystem activity

```sh
# Three fresh processes; copy a 256 MiB sparse source through the actual Explorer Job.
nvim -l __test__/bench/explorer/activity.lua jobs 3

# A longer Job with 1,000 four-byte files, covering multiple progress intervals.
nvim -l __test__/bench/explorer/activity.lua jobs-many 3

# Isolated renames, continuous file generation, and a burst of 500 new files.
nvim -l __test__/bench/explorer/activity.lua watch 3

# Select a preserved native module and, optionally, a matching Lua source overlay.
nvim -l __test__/bench/explorer/activity.lua jobs 1 /absolute/yoz.so /absolute/snapshot/lua
```

The optional overlay precedes both runtimepath and package.path. The probe verifies
the loaded Job, Filetree data and Filetree observer source paths; a native-only comparison can omit the overlay.
Save source and native hashes alongside each output, alternate variants in separate
fresh processes, and run without concurrent builds or tests.

The watch fixture starts with 1,000 files, a stable cursor anchor and a visible rename
marker. Keeping the cursor on the anchor prevents viewport preservation from scrolling
the marker out of sight. Continuous generation
creates 80 files and renames a visible marker every 20 ms; the burst creates 500 files
before its final marker change. Every phase verifies that all expected rows publish.
Only displayed marker versions contribute to `visible_ms`; intermediate versions
may be coalesced. `final_change_ms` measures final catch-up, and `wall_ms` includes the
whole phase. The maximum tick gap includes the final tick-to-completion interval.
CPU includes a 5 ms latency timer and parent RPC observation; Git/LSP
collection is disabled. Main-thread CPU uses Mach thread information on macOS and is
omitted elsewhere. Copy verifies the completed byte count and destination size.

2026-09-27 macOS comparison: five fresh processes per Job implementation, alternating
the pre-change Lua/native snapshot and the notification implementation. The separate
Explorer Job poller was eliminated; cached 256 MiB copies and 1,000-file directory
copies showed broadly similar end-to-end CPU and duration. These workloads do not
establish sustained savings while IO is blocked on a slow device.

Three alternating fresh processes per watch window retained the 150 ms default.
Changing to 50 ms reduced isolated rename-to-UI median from 202.08 to 88.41 ms, but
continuous generation increased total process CPU time from 440.59 to 716.89 ms and
main-thread CPU time from 338.35 to 567.72 ms. Each figure is the median of the three
process-level measurements; isolated latency first takes each process's median.
Continuous generation displayed more intermediate versions (median 7 to 20 of 80),
while final catch-up medians were similar. The smaller window is not adopted.

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
memory commands and record the libuv reading's definition. This is portability support, not evidence that another platform passed.
Linux, Windows and WSL still require execution on their actual runtime, including OS
watch and trash behavior. Cross-compilation and Windows path simulation do not replace
those checks. Trash tests use a disposable tool fixture, not the user's recycle bin.

The following historical results predate schema 2. Their old `RSS` label denotes the
then-recorded libuv process-memory reading; it is not evidence of `ps` RSS or a reason
to relabel historical values without the original libuv version.

2026-09-24 local acceptance: Apple M2 Max / 32 GiB, Neovim 0.12.5 Release,
installed release native module. All five benchmark cases completed (legacy Tree,
native Tree and native List: 15 fresh-process smoke runs, one sample each).
These smoke samples validate every case and output path; the earlier five-process
performance comparison remains a separate dataset.

The 200-cycle / 1k-file session run passed all watch, queue and buffer checks,
including 20 second-tab openings and 10 full session disposals. The process-memory reading over the last
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
