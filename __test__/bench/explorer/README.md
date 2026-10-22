# Explorer benchmark and acceptance

Node entry points and shared input provenance live in `script/benchmark/`.
Lua probes, support and fixtures live under `__test__/`.

The unified runner covers browsing, real configuration startup, Git, copy throughput,
idle/activity CPU, and lifecycle/UI/LSP acceptance. It uses installed Neovim, Node,
Rust tooling and plugins; it does not install packages or change either checkout's
Git state. Git writes are confined to newly created disposable Git fixtures.

This guide keeps each scenario's method and its latest accepted baseline. Dated
acceptance logs, superseded measurements and their local evidence paths remain in
this file's Git history (`git log -p -- __test__/bench/explorer/README.md`).
The native snapshot that opens [Latest baselines](#latest-baselines) uses the unified result format.
The older tables after it predate the unified naming: their `samples` are independent processes,
`repeats` are iterations within a process, and the standalone Lua probes reported a lower-middle p50.
They also ran on another host against the pre-native baseline, so they are not directly comparable
with the snapshot and are replaced as each A/B scenario is measured again.

## Unified runner

```sh
# Comprehensive matrix: alternating baseline/native Tree, native List, and acceptance.
# Build both release libraries from their sources without deploying to either checkout.
node script/benchmark/explorer.mjs --baseline ~/.config/nvim --build --processes 3

# Native only, using the installed library.
node script/benchmark/explorer.mjs --processes 3

# Fast harness smoke. Repeat --case to select any subset.
node script/benchmark/explorer.mjs --baseline ~/.config/nvim \
  --processes 1 --iterations 1 --mode both --case mixed_200 --case git_1000

# Rebuild the report from an existing result directory.
node script/benchmark/explorer-report.mjs /absolute/result/directory
```

Run `--help` for all options. Defaults are three independent processes,
three interaction iterations within a process, both widget modes, 200 soak cycles,
and a ten-minute deadline per driver process. `--processes` and `--iterations`
accept 1–100; `--cycles` accepts multiples of 20 through 10,000. Large process
counts may require a longer `--timeout-ms` because several acceptance drivers start
all their processes within one invocation. Copy/startup run once per process; unchanged
refresh repeats at most three times. Soak runs the requested cycles in each process.

`--current` selects another native checkout and `--baseline` a baseline checkout.
The harness stays in this checkout. `--output` must name a new directory outside
the measured and harness checkouts; by default it is created in the system temp
directory. Result directories are never reused. Fixtures are removed on success,
failure and handled interruption. A failed case retains diagnostics and lets the
remaining cases run; interruption or input drift stops the matrix.
`--native` and `--baseline-native` select preserved modules, including outputs from
an earlier isolated build. Their receipts are verified against the selected sources;
these flags cannot be combined with `--build`.

The default 25 cases are:

| Cases                                                                 | Coverage                                                                                                                                 |
| --------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `mixed_200`, `flat_1000`, `flat_10000`, `flat_50000`                  | Widget open, cursor, scrolling, single/Visual selection, refresh, empty Git notification, hide/reopen                                    |
| `branch_1000_plus_9000`                                               | The same operations, plus cold/warm expansion and collapse in Tree                                                                       |
| `startup_200`                                                         | Actual init.lua, installed plugins and first default Explorer                                                                            |
| `git_1000`                                                            | Real status/ignore queries, staged/untracked/ignored entries, changed Git annotations                                                    |
| `copy_64mib`, `copy_100_files`, `copy_1000_files`, `copy_10000_files` | Dense large-file copy and four-byte-file count scaling; actual actions and verified contents                                             |
| `copy_1000_4kib`, `copy_1000_64kib`                                   | File-size scaling with the same 1,000-file count                                                                                         |
| `copy_1000_expanded`, `copy_1000_outside`                             | Expanded source versus a destination outside the display root                                                                            |
| `navigation`                                                          | Native typed selection, nested reveal, removed-root recovery and view release across fresh processes                                     |
| `active_loading`                                                      | Native Tree/List typed cursor and cancellation during cold expansion and warm refresh of a 50k directory, followed by complete reopening |
| `idle`                                                                | Baseline/native visible, hidden and disposed idle phases                                                                                 |
| `watch`, `jobs_activity`                                              | Native burst/continuous watch activity and a 256 MiB sparse-file Job                                                                     |
| `root_watch`                                                          | Native macOS recursive subscription and external-symlink acceptance                                                                      |
| `soak`                                                                | Native repeated browsing, multi-tab, release and memory checks                                                                           |
| `full_config`, `jobs_ui`, `lsp`                                       | Native real prompts/Jobs/exit, unsaved buffers and installed-server rename                                                               |

The recorded baseline checkout (`00ccccfd3`, the pre-native Explorer) does not
recursively project directories. Tree is the common widget comparison; List is
native-only. Other native-only cases are labeled acceptance, not baseline/native wins. Missing installed vtsls marks LSP `blocked`; a non-macOS host
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
- `visible_ms` ends when the parent observes the requested content/cursor/selection in a UI
  flush; terminal/GPU rendering is excluded. `ready_ms` waits for expected rows and
  renderer completion, including the baseline's offscreen icons and native viewport decoration.
  First screen, operation completion and all-row readiness are distinct boundaries.
  Native ready also requires the current buffer tick, frame and decoration versions
  to have reached Neovim's redraw-end callback, including the final viewport's work
  even when `on_frame` runs before its redraw. The ready timestamp remains child-side;
  parent-observed flush timing stays separate.
- Native open/reopen/refresh additionally record `accepted_ms` when the child
  observes the explicit refresh request's Future, and `scan_ms` when the accepted
  browse/refresh work is observed settled. `ready_ms` also waits for an applicable
  frame, completed viewport preparation and a matching redraw. Source errors on
  the fixture root or exercised branch reject the sample. These are observation
  times, not per-syscall traces; they must not be added together. Watch events not
  yet delivered after coalescing and independent file Jobs are outside the scan
  condition. Untimed selection reset and
  copy/idle/activity setup wait in the parent so the child's RPC can return before
  its required redraw. Cancelled queued/running workers remain pending until
  retirement; replacement scans wait for the old slot's cached Scan to be reclaimed.
- Cursor uses typed j/k; scrolling uses typed Ngg across the viewport. Tab toggles a
  single entry; Visual selection spans 100 file rows. A child operation-start notification
  arms first-flush observation before input is processed. Selection `visible_ms` requires
  the target filename row and its actual selected/unselected glyph state inside the
  Explorer window; Visual selection observes its final file row. `ready_ms` separately
  requires the published count/revision and decoration completion. Baseline ready includes
  all-row precise icons; native ready includes viewport preparation. These ready boundaries
  do not describe equivalent first feedback or continuous main-thread blocking.
  Older records without selection `visible_ms` keep that metric unavailable; the report
  never substitutes their ready values. Start/finish notifications add no parent readiness
  RPCs during measurement, and the existing tick-gap/CPU measurements remain separate.
- `active_loading` uses a fresh native process per trial and mode. It injects typed `j`
  only while the branch reports Loading and the visible frame is applicable, and requires
  the cursor publication to complete during Loading. The parent separately observes the
  matching cursor in a UI flush. Typed `h` (Tree) or `t2` (List to Tree) must collapse the
  view and retire accepted scan work; reopening must load all children. Cold expansion
  and warm refresh remain separate. A two-ms child observer sends notifications, with
  zero parent readiness RPCs in the measured windows. This is native acceptance, with
  no baseline comparison or p95 claim; one fixture is reused across fresh processes.
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
  UI-flush claim, because the output is initially offscreen or outside the displayed tree.
  `job_ms` ends at native terminal
  notification or the baseline copy return; throughput divides verified bytes/files by
  this interval. `ready_ms` includes publication and native result draining/unlock,
  plus the native completion cursor on the target. An outside native copy follows the
  destination parent; baseline copy keeps its initial root. Their ready endpoints therefore
  include different navigation work; compare `job_ms` for IO throughput.
  Native copies also report `selection_unlocked_ms`, `session_idle_ms` and
  `frame_ready_ms`: the first checks after terminal delivery that observe an unlocked
  selection, an idle Session, and the expected rows with current data/selection revisions.
  These checkpoints use the existing 2 ms timer; they are observation times, not exact
  Rust transition timestamps or UI-flush times. `ready_ms` keeps its original stricter
  requirement that native work, view updates and subscriptions have settled. Its tail
  must not be interpreted as the entire interval during which input is unavailable.
  `visible_ms` is destination-name appearance: with per-item publication a directory
  may appear before its contents finish copying; directory staging makes it appear
  only after the root rename. This measures publication policy, not input latency or
  progress responsiveness; use Job timing, tick gaps and the Job UI probes separately.
  The runner hashes every source/destination file after
  timing. The matrix uses 100/1,000/10,000 four-byte files, 1,000 files of 4 KiB/64 KiB,
  and a dense 64 MiB file. These warm-cache workloads do not establish sustained
  throughput on a slow device; the sparse Job activity probe is separate.
- Passing `{"destination_browse":"tree"}` or `{"destination_browse":"list"}`
  in the copy probe's final options adds a native-only phase after a collapsed
  directory copy. It requires one source entry and a destination inside the display
  root. Cursor placement settles before timing. The Tree phase reports
  `first_children_ms` for any copied child in a UI flush and `first_item_ms` for
  `file-00000.lua`; filesystem enumeration order can make the latter much later.
  `destination_browse.ready_ms` waits for all expected rows and renderer completion.
  List reports completion without a destination first-screen claim. The separate
  `browsed_memory` snapshot includes target descendants loaded by this phase.
- Passing `{"memory_stages":true}` in the copy probe's final options argument enables
  a separate native directory-copy diagnostic. It fully expands and collapses the
  source before timing, checks that its children are loaded, and samples memory after
  source loading, terminal delivery with the Job held, ready with the Job held, Job
  release, hide and disposal. Terminal sampling forces GC before UI result draining;
  these diagnostic runs must not be pooled with throughput samples. Hide must release
  watches and queued work. Disposal first keeps one explicit native owner and reports
  weak references before/after JIT trace collection, then releases that owner. This
  separates Source/index ownership from view lifetime and allocator footprint; process
  memory remaining after release alone does not establish a leak.
- Comparable Widget, copy, Git and startup phases deliver completion notifications;
  `observer_rpcs` must be zero during each timed operation. Widget readiness is checked
  on frame/cursor events and a 2 ms timer. Copy/Git only begin readiness checks after
  the real terminal/query notification. `readiness_checks` records those checks.
  This avoids a `vim.wait` predicate issuing many RPCs while an asynchronous Job runs:
  the predicate interval is not a request rate limit when events keep arriving.
- `cpu_ms` and `main_cpu_ms` cover the operation through ready; `job_cpu_ms` and
  `job_main_cpu_ms` stop at native terminal notification or the baseline copy return.
  Process CPU includes native threads; main-thread CPU is collected on macOS.
  Timers and necessary observation work remain included, so these are not pure IO
  algorithm timings.
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
node script/benchmark/explorer.mjs --case navigation --processes 20 --native /absolute/yoz.so
```

Each fresh process performs ten cycles. Real j/mx input selects a file for cut,
nested reveal preserves its selection, and external removal of the display root is
followed by refresh and reveal of an existing external file. Assertions check the
native cursor and the displayed target through UI flushes. Every cycle hides and
disposes the view after watches and queued work reach zero. This is native-only
acceptance; it makes no baseline/native latency claim.

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
nvim -l __test__/run.lua era/m/explorer/
```

The Git cases create a disposable repository and change only its index and files.
They use actual status/ignore jobs, external writes and rename, native Explorer IO,
ignore invalidation on focus, and watch/buffer release on hide. Ordinary specs load
the installed native module described in the main test guide.

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

## Idle CPU

```sh
# Native only, three fresh processes.
nvim -l __test__/bench/explorer/idle.lua > /tmp/explorer-idle.json

# Alternating baseline/native, three fresh processes each.
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

## Bulk Move editor preparation

```sh
nvim -l __test__/bench/explorer/move.lua 200 200 none
nvim -l __test__/bench/explorer/move.lua 200 200 notify
nvim -l __test__/bench/explorer/move.lua 200 200 async
nvim -l __test__/bench/explorer/move.lua 200 200 none profile
```

The driver exercises real per-item Filetree Move, editor preparation and result
delivery with the release library. It creates only owned temporary files, opens the
requested number of modified buffers (half moving, half unrelated, up to the number
of moved files), and checks every file's contents and every buffer's final name,
modified flag and unsaved text. It detaches the view and waits for watch teardown
before timing; Git collection, rendering and startup are excluded.

Arguments are file count, buffer count, LSP adapter mode and optional detailed
profiling. `none` has no clients; `notify` accepts only `didRenameFiles`; `async`
adds an asynchronous `willRenameFiles` reply with no workspace edit. These adapters
measure protocol integration overhead, not an installed server's response latency.
`NVIM_EXPLORER_BENCH_CHECKOUT` selects the Lua source checkout and
`NVIM_EXPLORER_BENCH_NATIVE` selects the release artifact, allowing the same driver
and native library to run against an archived Lua baseline.

`wall_ms` runs from the operation request through session unlock and native idle;
`terminal_ms` ends on the native terminal notification observed by Lua.
`delivery_tail_ms` is only the remaining tail, not the cost of all result handling.
`prepare_ms` sums preparation lifetimes, including asynchronous waits; `sync_ms`
sums buffer synchronization time; `callbacks_ms` sums Job update callbacks and
therefore overlaps other phases. Do not add these fields. Detailed `profile` runs
wrap `entry_path`, `path_suffix` and `nvim_list_bufs`; their overhead is kept separate
from ordinary timing samples. Natural GC remains enabled after a pre-run collection.

## Filetree native probes

```sh
# 50k files, attached 80×48 UI; mode tree or list, optional annotations phase.
nvim -l __test__/bench/filetree.lua 20 tree annotations

# Real single-file rename through UI flush, attached 80×24 UI.
nvim -l __test__/bench/filetree_watch.lua 20
```

Both use the installed release module (`lua/yoz.so`) and natural GC during samples.
`filetree.lua` reports publication/flush latency and separate memory metrics; the
`annotations` phase also measures a 48-row viewport, worst-case 50k-row diagnostic
navigation, and diagnostic updates through UI flush. `filetree_watch.lua` reports
mutation-to-flush latency including the fixed 150 ms coalescing window, the Lua
observation-to-flush tail, and checks zero watches and queue depth after detach.

Opt-in Rust probes run in release mode, one at a time and without concurrent tests
or builds:

```sh
cargo test --manifest-path rust/Cargo.toml -p yoz --release --lib \
  ux::filetree::reader::tests::t_scan_stages -- --exact --ignored --nocapture
cargo test --manifest-path rust/Cargo.toml -p yoz --release --lib \
  t_annotations_wide_directory_with_loaded_aliases -- --ignored --nocapture
cargo test --manifest-path rust/Cargo.toml -p yoz --release --lib \
  t_native_watch_notification_latency -- --ignored --nocapture
cargo test --manifest-path rust/Cargo.toml -p yoz --release --lib \
  t_native_link_watch_budget_stress -- --ignored --nocapture
cargo test --manifest-path rust/Cargo.toml --offline -p yoz --release --lib \
  ux::filetree::jobs::staged::tests:: -- --ignored --nocapture --test-threads=1
```

- `t_scan_stages` scans 1k, 10k and 100k real direct files, cold and fully loaded
  warm, through a fresh Source with an attached state. Each line reports
  `scan_stage count=… loaded=… initialize_ms io_ms apply_ms project_ms retire_ms
  pages staging_peak`; fixture construction and terminal assertions are excluded.
  Staging values are page-boundary observations, not exact transient peaks or RSS.
- The staged copy cases use a real Treeview selection task and check disk contents,
  source preservation, paged results, selection cleanup, task unlock, staging removal
  and result reclamation. They have no UI and sample retained memory every 5 ms; they
  establish capacity and integrity, not throughput or p95 latency.
- The watch-budget stress needs a file descriptor limit of at least 4096. It covers
  55 external symlink targets: macOS caps actual recursive roots at 50, while Linux
  retains the 50-directory cap.

Cross-filesystem Job cases need a disposable second filesystem:
`FILETREE_TEST_VOLUME=/absolute/mount cargo test --manifest-path rust/Cargo.toml -p yoz --lib cross_filesystem -- --ignored --test-threads=1`.

## Platform evidence

The tools select the native module for macOS/Linux/Windows and avoid host-specific
memory commands and record the libuv reading's definition. This is portability support, not evidence that another platform passed.
Linux, Windows and WSL still require execution on their actual runtime, including OS
watch and trash behavior. Cross-compilation and Windows path simulation do not replace
those checks. Trash tests use a disposable tool fixture, not the user's recycle bin.

## Latest baselines

Unless noted, measurements use Apple M1 Pro / 32 GiB, Darwin 27.0.0, Neovim 0.12.5
Release, libuv 1.53.0 and Rust 1.99.0, with source-bound release receipts, warm
filesystem/plugin caches, a 110×40 attached UI, natural GC, alternating fresh
processes and no concurrent builds or tests. System background load was uncontrolled.
Values are independent-process medians in milliseconds; fewer than 20 processes
support no p95 claim. The baseline checkout is `00ccccfd3`, the pre-native Explorer.
Each entry names its date and the change it accepted; rerun the unified runner before
comparing against a different build.

### Native snapshot, unified format (2026-10-21)

`node script/benchmark/explorer.mjs --processes 3`, native only: Apple M5 Pro (6P + 12E) on AC power,
Darwin 27.0.0, Neovim 0.12.6, libuv 1.53.0, Rust 1.99.0, a verified source-bound release receipt and
macOS physical footprint. Values are medians of three independent processes after each process's median;
three processes support no p95 claim. Every case in the matrix passed, including all acceptance drivers.

Widget cases (ms; first flush is 10.6–12.7 ms throughout):

| Case       | Mode |   Ready | Cursor | Scroll | Selection | Visual selection | Refresh ready | Reopen | Open MiB |
| ---------- | ---- | ------: | -----: | -----: | --------: | ---------------: | ------------: | -----: | -------: |
| mixed 200  | Tree |  11.844 |  0.261 |  0.684 |     0.409 |            4.988 |         9.510 |  4.699 |     10.5 |
| mixed 200  | List |  11.111 |  0.248 |  0.758 |     0.407 |            4.835 |        10.166 |  4.261 |     11.0 |
| flat 1k    | Tree |  32.074 |  0.233 |  0.709 |     0.510 |            4.002 |         9.683 |  4.341 |     14.7 |
| flat 1k    | List |  31.770 |  0.213 |  0.661 |     0.522 |            3.627 |         9.585 |  5.640 |     14.8 |
| flat 10k   | Tree | 115.208 |  0.264 |  0.653 |     0.782 |            5.544 |        28.581 |  8.335 |     44.2 |
| flat 10k   | List | 114.881 |  0.239 |  0.799 |     0.922 |            4.256 |        29.179 |  7.789 |     44.4 |
| branch 10k | Tree | 118.031 |  0.243 |  0.676 |     0.749 |            5.566 |        36.698 |  8.714 |     40.3 |
| branch 10k | List | 126.626 |  0.245 |  0.605 |     0.800 |            5.115 |        36.587 |  8.434 |     42.1 |
| flat 50k   | Tree | 857.852 |  0.221 |  0.680 |     3.499 |            7.434 |       157.175 | 21.302 |    151.5 |
| flat 50k   | List | 861.067 |  0.211 |  0.627 |     3.329 |            7.416 |       160.041 | 22.349 |    151.6 |

Startup and Git: real-configuration startup is ready at 75.303 ms and visible at 100.408 ms; the first
default Explorer is ready at 26.290 ms. `git_1000` refresh is ready at 87.050 ms, of which the status
query takes 82.771 ms, with 2.350 ms main-thread CPU and a 2.449 ms maximum tick gap (2026-10-22). Each
refresh now first outlasts the previous refresh's throttle window; the earlier 796.519 ms timed that window.

| Copy case           |   Job ms |   CPU ms | Ready ms |
| ------------------- | -------: | -------: | -------: |
| One dense 64 MiB    |   20.468 |   12.910 |   26.883 |
| 100 × 4 B           |   22.479 |   19.249 |   26.276 |
| 1k × 4 B            |  173.652 |  140.479 |  177.976 |
| 10k × 4 B           | 1520.837 | 1313.794 | 1524.246 |
| 1k × 4 KiB          |  163.910 |  141.032 |  168.003 |
| 1k × 64 KiB         |  195.860 |  164.251 |  198.761 |
| 1k, source expanded |  159.448 |  146.679 |  173.581 |
| 1k, target outside  |  164.202 |  141.622 |  168.653 |

Active loading (50k directory):

| Mode | Phase | Input visible ms | Cancel visible ms | Resume ms | Max tick gap ms |
| ---- | ----- | ---------------: | ----------------: | --------: | --------------: |
| Tree | Cold  |            0.267 |             1.498 |   888.439 |           4.391 |
| Tree | Warm  |            0.287 |            10.406 |   224.955 |           3.187 |
| List | Cold  |            0.226 |            18.277 |   881.004 |           3.826 |
| List | Warm  |            0.244 |             5.289 |   236.731 |           2.971 |

- Idle visible, hidden and disposed phases each use 0.155–0.254 ms CPU per three seconds with no redraw
  notifications at 11.5 MiB; the macOS recursive root watch over 97 idle directories uses 0.226 ms.
- Watch activity: an isolated change is visible after 186 ms at 7.3% main-thread CPU, a continuous stream
  after 29 ms at 9.0%, and a burst after 124 ms. The 256 MiB sparse-file Job takes 68.9 ms wall time,
  3.8 ms main-thread CPU and a 6.4 ms maximum tick gap.
- Soak (200 cycles): the cycle watch median is 186 ms; hidden-view footprint grows from 16.7 to 20.1 MiB
  and settles at 19.8 MiB after the trace flush.
- Full configuration: create, rename and delete are confirmed after 28.6, 9.9 and 10.5 ms; the worst cursor
  during a refresh is 17.1 ms. The vtsls rename edits arrive after 71.6 ms with 6.8 ms of rename I/O.
- Navigation acceptance: three processes of ten cycles each complete typed selection, nested reveal,
  removed-root recovery and view release.

### Browsing (Tree, 2026-10-07 compact browse scan)

Three processes per side and case; ready and refresh are complete boundaries.

| Tree case  | Baseline ready | Native ready | Baseline refresh | Native refresh |
| :--------- | -------------: | -----------: | ---------------: | -------------: |
| mixed 200  |         30.328 |       14.845 |           20.053 |          9.982 |
| flat 1k    |         94.915 |       29.330 |          105.094 |         10.198 |
| flat 10k   |        875.174 |      259.038 |         1453.124 |         62.033 |
| branch 10k |        784.903 |      238.735 |         1503.043 |         60.018 |
| flat 50k   |       4393.667 |     2066.040 |        15035.019 |        324.016 |

- 50k Tree first flush is 4394.114 → 17.727 ms and final physical footprint
  639.861 → 172.360 MiB. Native is not better on every axis: at mixed 200, cursor
  flush is 0.214 → 0.337 ms, scroll flush 0.630 → 1.472 ms and open footprint
  8.985 → 10.454 MiB; 1k open footprint is 13.626 → 14.501 MiB.
- Final native acceptance (native input `63bf34ab…`, three processes per mode):
  50k Tree/List ready 1923.098/2022.978 ms, refresh 290.393/315.097 ms, first flush
  17.552/17.541 ms.
- Published 50k selection (2026-10-07 settled-scan matrix, native `23e7a7bfd`, five
  processes): single/100-row Visual 5.79/13.02 native versus 13,882.13/13,861.14
  baseline. Selection ready is not a UI-flush metric. Cached 50k reopen in the same
  matrix was 14,006.36 baseline versus 387.06 native Tree and 383.21 native List.
- After browsing and GC, 50k native retained accounting is about 90.06 MiB at
  50,011 nodes (2026-10-06 viewport icon preparation).

### Startup and idle (2026-10-07 settled-scan matrix)

Five fresh processes per side, native `23e7a7bfd`.

- Full-configuration startup to first Explorer UI flush: 319.04 baseline versus
  319.22 native; configuration ready 251.99/215.85; first Explorer visible interval
  67.02/103.33 and ready interval 95.61/103.53. Startup uses each checkout's own
  configuration/plugins and does not isolate Explorer cost.
- Idle visible/hidden/disposed CPU: 0.0120%/0.0107%/0.0149% of one core baseline and
  0.0095%/0.0115%/0.0184% native, with zero redraw notifications. The 200-file
  visible idle footprint is 9.02 versus 11.09 MiB.

### Copy throughput

Baseline/native, five processes per side. Job time ends at native terminal
notification or the baseline copy return.

| Copy fixture | Source                                    | Baseline Job | Native Job | Baseline ready | Native ready |
| :----------- | :---------------------------------------- | -----------: | ---------: | -------------: | -----------: |
| 1k × 4 B     | 2026-10-07 private traversal, `a7d94c57c` |      3260.04 |    3681.62 |        3269.51 |      3687.37 |
| 10k × 4 B    | 2026-10-07 private traversal, `a7d94c57c` |      9313.74 |    3312.89 |        9379.45 |      3315.16 |
| 64 MiB file  | 2026-10-07 source prefetch, `67c6a9b46`   |       101.71 |      54.45 |         104.57 |        63.03 |

- The 1k comparison is highly variable (baseline/native ranges 766.05–4,511.66 /
  373.08–4,982.62 ms; native faster in 2/5 pairs). A native-only before/after
  measurement of the same change, taken with the since-removed copy-stage probe,
  isolates it better: 1k median of process medians 327.46 → 298.19 ms, with Source
  nodes retained per Job 1,010 → 10.
- Job CPU (baseline/native): 366.13/664.90 ms at 1k and 2,594.11/3,300.71 ms at 10k;
  main-thread Job CPU 363.33/109.00 and 2,573.73/88.58 ms. Final post-GC footprint
  11.61/10.56 MiB at 1k and 32.67/12.66 MiB at 10k. Median maximum timer gap
  3,267.74/7.51 ms at 1k and 9,377.50/6.99 ms at 10k.

Native-only copy variants (2026-10-06 directory staging, five processes, Job/CPU ms).
The 1k and 10k four-byte cases improved further with source prefetch and private
traversal; the variants were later checked for correctness only.

| Copy case           |  Job ms |  CPU ms |
| :------------------ | ------: | ------: |
| 100 × 4 B           |  106.07 |   36.04 |
| 1k × 4 B            |  979.81 |  355.40 |
| 10k × 4 B           | 9063.76 | 3794.87 |
| 1k × 4 KiB          |  926.04 |  351.50 |
| 1k × 64 KiB         | 1199.09 |  418.01 |
| 1k, source expanded |  701.38 |  329.36 |
| 1k, target outside  | 1011.90 |  322.27 |
| One dense 64 MiB    |   21.50 |   19.02 |

First browse of copied output (2026-10-06 viewport icon preparation, three processes;
the phase starts after copy):

| Destination browse | Ready ms | Main CPU ms |
| :----------------- | -------: | ----------: |
| 1k Tree            |    22.96 |       15.67 |
| 10k Tree           |   318.46 |      130.09 |
| 1k List            |    24.71 |       13.90 |
| 10k List           |   333.67 |      145.03 |

Tree first children appear at 22.91/21.27 ms (1k/10k). After full 10k destination
browsing, native retained accounting is 33.36 MiB in Tree and 35.79 MiB in List;
an unbrowsed copied directory stays lazy.

### Copy capacity (2026-10-07 private Job traversal)

Opt-in staged copy cases, one execution each, 32 MiB task limit throughout. Job time
includes selection cleanup and excludes fixture construction and content verification.

| Scenario               | Source files | Copied | Job seconds | Sampled task peak MiB | Final Source nodes |
| :--------------------- | -----------: | -----: | ----------: | --------------------: | -----------------: |
| Unloaded source        |       100000 | 100000 |       47.49 |                 25.28 |                 10 |
| Already loaded source  |       100000 | 100000 |       59.51 |                 25.29 |             100010 |
| Decline last conflict  |       100000 |  99999 |      261.38 |                 19.04 |             100009 |
| Merge directory        |        10000 |  10000 |       15.64 |                  1.88 |                 10 |
| Cancel after 40k bytes |        50000 |  10006 |        9.71 |                  2.68 |              10016 |
| Nested long paths      |        10000 |  10000 |       10.31 |                  1.23 |                 34 |

The loaded-100k row is the final `traversal-v5` recheck; the others use
`traversal-v4`. Loaded cases construct Source entries from real metadata without
browse Scan, so they validate loaded Job inputs, not 100k browse capacity. The shared
data ledger, which includes task charges, samples 210.84 MiB in the 100k partial case;
task accounting is not process memory.

### Active loading (50k directory)

| Mode | Phase | Cursor flush ms | Cancel visible ms | Scan retirement ms | Source                         |
| :--- | :---- | --------------: | ----------------: | -----------------: | :----------------------------- |
| Tree | Cold  |           0.393 |                 — |              5.154 | 2026-10-07 private traversal   |
| List | Cold  |           0.365 |                 — |              4.588 | 2026-10-07 private traversal   |
| Tree | Warm  |           0.369 |            29.718 |            290.107 | 2026-10-07 compact browse scan |
| List | Warm  |           0.295 |             8.040 |            276.884 | 2026-10-07 compact browse scan |

Three processes per mode; warm retirement maxima are 297.439/284.609 ms. Background
retirement and visible collapse are different boundaries; this does not claim
immediate cancellation of blocking syscalls.

### Browse scan stages (2026-10-07 compact browse scan)

Release Rust scan probes against baseline `3a9f88688`, three alternating process pairs
for 1k/10k (medians of initialization + scan/IO + owner application + destruction):

| Direct files | Phase | Scan ms | Staging MiB |
| -----------: | :---- | ------: | ----------: |
|         1000 | Cold  |    7.96 |       0.893 |
|         1000 | Warm  |    4.75 |       0.698 |
|        10000 | Cold  |  100.65 |       3.378 |
|        10000 | Warm  |   59.35 |       1.197 |

A single 100k pair completes both cold and fully loaded warm scans in 196 pages,
2558.31/907.79 ms with 28.815/6.186 MiB boundary-observed staging. These figures
predate merging the per-size probes into `t_scan_stages` and its `project_ms` column;
`t_scan_stages` now runs all three sizes in one process.

### Watch and Job activity (2026-09-27)

The 150 ms watch coalescing window is retained. Three alternating processes showed
that 50 ms would reduce isolated rename-to-UI median from 202.08 to 88.41 ms but raise
continuous-generation process CPU from 440.59 to 716.89 ms and main-thread CPU from
338.35 to 567.72 ms. Notification-driven Job activity showed broadly similar
end-to-end CPU and duration to the former poller for cached 256 MiB and 1,000-file
copies; it does not establish savings while IO is blocked on a slow device.

### Long session (2026-09-24)

Apple M2 Max / 32 GiB, Neovim 0.12.5, 200 cycles / 1k files. The process-memory
reading over the last 50 cycles ranged from 34.64 to 34.84 MiB; Lua heap ranged from
2.26 to 2.53 MiB. Disposed session/data/view weak references were zero **before** the
final JIT trace flush. Watch rename-to-UI-flush latency was median 190.61 ms / p95
199.76 ms, including the 150 ms window. This record predates schema 2: its
process-memory value is the then-recorded libuv reading, not `ps` RSS. Later
acceptance runs (3 × 40 cycles on macOS, five 100-cycle soaks on Linux) passed all
release checks without new memory figures.

### Bulk Move preparation (2026-10-07)

Baseline `bc85767d1`, the same preserved release library on both sides, three
fresh-process pairs per case, 200 four-byte files:

| Buffers | LSP adapter | Total ms | Prepare ms |
| ------: | :---------- | -------: | ---------: |
|       0 | none        |   592.21 |      12.83 |
|      40 | none        |  1497.70 |     524.17 |
|     200 | none        |  4993.93 |    2212.13 |
|     200 | notify      |  4977.34 |    2202.25 |
|     200 | async       |  6961.04 |    4199.55 |

The buffer-heavy cases improved by about 30% over the baseline; asynchronous
willRename retains both required checks and is not materially faster. The no-buffer
case is slower: a ten-pair recheck gives 312.26 → 360.49 ms total. The 200-buffer
no-client runs retain about 2.2 s of per-item buffer synchronization.

### Filetree probes (2026-09-22)

Apple M2 Max / 32 GiB, Neovim 0.12.5, 80×48 attached UI, 50k files, 20 samples per
mode. Values are p95 milliseconds:

| Measurement                                   |     Tree |     List |
| :-------------------------------------------- | -------: | -------: |
| First 512 rows through UI flush               |   17.590 |   20.747 |
| Complete initial load through UI flush        | 1986.568 | 1969.299 |
| 48-row annotation query                       |    1.930 |    1.660 |
| Diagnostic navigation across 50k visible rows |   14.196 |   14.066 |
| Diagnostic update through UI flush            |    2.888 |    2.506 |

Rust retained memory after collection was about 109.2 MiB per final tree; final Lua
heaps were 1055.8/1021.0 KiB. These metrics describe different owners and must not
be added. With 128 real loaded aliases, `t_annotations_wide_directory_with_loaded_aliases`
measured annotation aggregate p95 10.086 ms and sparse Git navigation p95 6.054 ms.
A real single-file rename measured p95 185.722 ms from mutation to UI flush, including
the 150 ms window; Lua's first observation to flush measured p95 0.325 ms, and the
native OS notification probe p95 14.424 ms with 1 ms polling. These are separate
observations, not an additive per-event trace. On macOS, 471 nested directories reach
a 1022-byte absolute path; native open, lookup and details succeed at that depth.

### Linux (2026-10-08)

WSL2 on warm local ext4, native baseline `13e2442bb`, five fresh processes per
case/mode and three repeats, run as sequential before/after matrices (not alternating
pairs). Final native input `53bd3f19…`:

| Tree metric, ms               |   Before |    Final |
| :---------------------------- | -------: | -------: |
| 10k complete open             |  206.761 |  141.397 |
| 50k first content flush       |   12.218 |   12.909 |
| 50k complete open             | 3430.214 | 1581.009 |
| 50k refresh                   |  388.777 |  283.966 |
| 64 MiB copy Job               |   16.917 |   14.459 |
| 10k four-byte files, copy Job |  336.425 |  335.973 |

The final eleven-case matrix passes Tree/List browsing, loading input/cancellation,
idle, watch churn, five 100-cycle soaks, full-config operations, and Job/exit UI.
Linux parent entry watches share the 50-root budget and ignore unrelated siblings.
Native Windows runtime acceptance has not been run.

## Known limits

- Native small-file copy CPU remains higher than the baseline, and copy throughput
  varies widely across processes; responsiveness and throughput need separate
  conclusions.
- A fixed 32 MiB task budget and the shared scan staging cap bound copy and browse
  capacity; large change sets and long names still share those caps.
- Expanded-source copy preparation can still reject with `selection revision changed`
  while acquiring the selection lock; reruns pass, so the race is unresolved rather
  than absent.
- Cross-volume IO, the Git-writing Explorer suites and `git_1000` were outside the
  recorded acceptance runs.
