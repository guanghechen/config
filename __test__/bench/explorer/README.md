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

The default 25 cases are:

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
| `active_loading` | Native Tree/List typed cursor and cancellation during cold expansion and warm refresh of a 50k directory, followed by complete reopening |
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

## Small-file copy stage measurements

The opt-in Rust probes exercise a real selection task and verify every copied file:

```sh
cargo test --offline --manifest-path rust/Cargo.toml -p yoz --release --lib \
  t_profile_copy_ -- --ignored --nocapture --test-threads=1
```

Each size (1k and 10k four-byte files) runs six fresh Jobs in one process, alternating
three instrumented and three uninstrumented runs. Fixtures and file verification are
outside the reported Job elapsed time. These are diagnostic repetitions, not six
independent processes or a p95 estimate. Run them without other tests, builds or probes.

`copy_stage` reports calls and inclusive/exclusive wall time. The stack subtracts nested
spans once within each thread. Source-read time follows the Job's traversal boundary;
older versions waited for the browse Source, while private traversal measures its own
bounded observations. It is not the scan worker's CPU time. Read-ahead `source_worker` spans run concurrently:
their accumulated time overlaps the Job, so do not add it to Job elapsed time. `source_wait`
measures the serial writer's wait for those descriptors. Native retained accounting and
Source node counts are separate from process RSS/physical footprint. Timings are compiled
only into Rust tests; production libraries contain no profiler or timing switch.

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
  renderer completion, including legacy offscreen icons and native viewport decoration.
  First screen, operation completion and all-row readiness are distinct boundaries.
  The viewport-icon acceptance below additionally requires the current buffer tick,
  frame and decoration versions to have reached Neovim's redraw-end callback. This
  includes the final viewport's work even when `on_frame` runs before its redraw.
  The ready timestamp remains child-side; parent-observed flush timing stays separate.
  Earlier native ready/CPU measurements could stop before the final Explorer icon
  callback. Those historical datasets and the initial icon pilots are not pooled
  with the comparisons using this corrected boundary.
- Native open/reopen/refresh additionally record `accepted_ms` when the child
  observes the explicit refresh request's Future, and `scan_ms` when the accepted
  browse/refresh work is observed settled. `ready_ms` also waits for an applicable
  frame, completed viewport preparation and a matching redraw. Source errors on
  the fixture root or exercised branch reject the sample. These are observation
  times, not per-syscall traces; they must not be added together. Watch events not
  yet delivered after coalescing and independent file Jobs are outside the scan
  condition. Earlier ready datasets using only active read slots have a different
  boundary and are not pooled with these runs. Untimed selection reset and
  copy/idle/activity setup wait in the parent so the child's RPC can return before
  its required redraw. Cancelled queued/running workers remain pending until
  retirement; replacement scans wait for the old slot's cached Scan to be reclaimed.
- Cursor uses typed j/k; scrolling uses typed Ngg across the viewport. Tab toggles a
  single entry; Visual selection spans 100 file rows. A child operation-start notification
  arms first-flush observation before input is processed. Selection `visible_ms` requires
  the target filename row and its actual selected/unselected glyph state inside the
  Explorer window; Visual selection observes its final file row. `ready_ms` separately
  requires the published count/revision and decoration completion. Legacy ready includes
  all-row precise icons; native ready includes viewport preparation. These ready boundaries
  do not describe equivalent first feedback or continuous main-thread blocking.
  Older records without selection `visible_ms` keep that metric unavailable; the report
  never substitutes their ready values. Start/finish notifications add no parent readiness
  RPCs during measurement, and the existing tick-gap/CPU measurements remain separate.
- `active_loading` uses a fresh native process per sample and mode. It injects typed `j`
  only while the branch reports Loading and the visible frame is applicable, and requires
  the cursor publication to complete during Loading. The parent separately observes the
  matching cursor in a UI flush. Typed `h` (Tree) or `t2` (List to Tree) must collapse the
  view and retire accepted scan work; reopening must load all children. Cold expansion
  and warm refresh remain separate. A two-ms child observer sends notifications, with
  zero parent readiness RPCs in the measured windows. This is native acceptance, with
  no legacy comparison or p95 claim; one fixture is reused across fresh processes.
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
  notification or the legacy copy return; throughput divides verified bytes/files by
  this interval. `ready_ms` includes publication and native result draining/unlock,
  plus the native completion cursor on the target. An outside native copy follows the
  destination parent; legacy copy keeps its initial root. Their ready endpoints therefore
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

## 2026-09-30 optimization acceptance

Apple M1 Pro / 32 GiB, Darwin 27.0.0, Neovim 0.12.5 Release and libuv 1.53.0.
The changes retain failed/skipped/synchronization results independently of the recent
success tail, reuse a Job's copy buffer and destination descriptors, coalesce source
frames over 8 ms, and transfer the opening scratch buffer to the native view.
The confirmed contracts remain in [Explorer](../../../spec/design/feat/explorer.md),
[Filetree](../../../spec/design/filetree.md) and [Treeview](../../../doc/spec/treeview/performance.md).

The following **native before/after** comparison uses preserved source snapshots,
verified release receipts, identical fixtures and alternating fresh processes.
All 70 runs passed; source/artifact hashes were checked before and after each case,
every copied file was verified, and timed observer RPC counts were zero. Installed
plugin caches were warm. Values are independent-process medians, not p95. Each side
has the indicated process count; copy time ends at Job terminal notification.

| Measurement | Processes | Before ms | After ms |
| --- | ---: | ---: | ---: |
| First Explorer UI flush after full-config readiness | 5 | 112.84 | 84.81 |
| Copy 100 × 4 B | 5 | 189.73 | 114.29 |
| Copy 1,000 × 4 B | 5 | 2161.61 | 1254.85 |
| Copy 10,000 × 4 B | 3 | 29354.27 | 14858.76 |
| Copy 1,000 × 4 KiB | 3 | 4562.06 | 1415.48 |
| Copy 1,000 × 64 KiB | 3 | 6797.81 | 1598.65 |
| Copy 1,000 × 4 B, source expanded | 5 | 2812.07 | 1437.69 |
| Copy 1,000 × 4 B, destination outside the tree | 3 | 3445.03 | 1278.58 |
| Copy one 64 MiB file | 3 | 46.64 | 45.44 |

For 1,000 small files, Job CPU fell from 1512.71 to 747.45 ms and main-thread CPU
from 744.38 to 217.50 ms. For 10,000 files they fell from 16976.61 to 8426.99 ms
and from 8496.14 to 2513.13 ms. Copy allocation churn decreased, but final process
memory did **not** improve uniformly: after full GC, the 1,000-file footprint was
18.75 → 19.09 MiB and the 10,000-file footprint was 85.86 → 87.25 MiB.
First-Explorer footprint fell from 26.64 to 23.67 MiB. These are physical footprints,
not peak memory or sums of Lua/native accounting. First-Explorer improvement does
not establish a faster overall configuration startup.

A separate final **legacy/native** comparison used three alternating processes per
side, with both native receipts and full-config plugin inputs verified. It used
legacy `00ccccfd3` and the changed native checkout based on `81c0b78be`:

| Measurement | Legacy ms | Final native ms |
| --- | ---: | ---: |
| First Explorer UI flush after full-config readiness | 46.26 | 84.48 |
| Copy 1,000 × 4 B, Job terminal | 470.98 | 1112.26 |
| Copy 10,000 × 4 B, Job terminal | 4738.10 | 12076.46 |
| Copy 1,000 × 4 B, maximum tick gap per process | 475.40 | 3.57 |
| Copy 10,000 × 4 B, maximum tick gap per process | 4805.89 | 17.94 |

Native retains much better interaction during copy, but still loses small-file
throughput, first-open latency and copy footprint to legacy. The largest individual
native tick gap in this final comparison was 65.31 ms; there is no universal 16 ms
latency claim. These samples are separate from the native before/after dataset.

Final verification:

- Rust UX: 237 passed, 15 opt-in tests ignored. The five new IO regressions cover
  working-set reuse, a growing source, replaced cached parents, capacity failure
  before private output creation, and output-name replacement after copying.
- Lua: 34 suites / 259 cases passed, including 32 Explorer/Treeview/Filetree suites
  and the adjacent nvimbar Explorer and source-window opening suites. Three suites
  that create Git fixtures, and `git_1000`, were excluded under this task's Git-write
  restriction. Native Git annotation tests use synthetic snapshots and were run.
- Benchmark harness: 11 Node tests passed. StyLua, all 408 field/parameter annotation
  alignments in changed Lua files, `cargo fmt` and `git diff HEAD --check` passed.
- Three-process acceptance passed navigation/root recovery, idle, recursive root
  watch, full-config create/rename/delete and dirty-buffer preservation, and all
  nine Job UI scenarios per process, including typed/scripted exit during copy.
  Three vtsls 0.3.0 rename runs preserved unsaved buffers and applied import edits;
  this server supports `didRenameFiles`, while `willRenameFiles` remains unit coverage.
- Final 50k Tree/List acceptance passed: first UI flush 19.02/19.22 ms, full ready
  2258.82/2289.06 ms, 100-row Visual selection 13.80/14.23 ms, full refresh
  1028.96/1031.02 ms. These are three-process native measurements, not a new
  before/after browsing comparison or evidence of improvement in every metric.
- A 20-cycle / 1k-file lifecycle smoke passed Tree/List transitions, watch rename,
  hide/reopen, two second-tab openings and one full disposal. Hidden watches were
  zero; disposed session/data/view weak references were already zero before JIT
  trace flushing. This is finite lifecycle coverage, not a long-session leak proof.
  Cross-volume and Linux/Windows/WSL runtime behavior were not revalidated here.

Evidence is retained under
`/var/folders/46/g_pc2kcd0png2zh_xr46wwp00000gp/T/explorer-opt-sjiqiwyl/`:
`final-report.md`, `final-paired-inputs.json`, `final-paired-results.jsonl`,
`final-paired-summary.json`, `final-regression-l3hlqrxh/`, `final-acceptance/`,
`final-legacy-comparison/` and `final-soak/`. The three unified-runner directories
are complete and retain metadata, raw records, receipts and reports. Release
artifacts were rebuilt in the checkout; restart an existing Neovim process to load them.

## 2026-10-01 pagination acceptance

The change based on `a167896b9` keeps the 8 ms source-publication window and lets
directory pages advance while only that display deadline is pending. Active frame
preparation and pending input still apply backpressure; the latest target remains
bounded to one per view. The confirmed boundaries are in
[Treeview](../../../doc/spec/treeview/performance.md) and
[Filetree](../../../spec/design/filetree.md). No native code or artifact changed.

The final native before/after comparison uses the same Apple M1 Pro / 32 GiB host,
Darwin 27.0.0, Neovim 0.12.5 Release and libuv 1.53.0. Each side has three alternating
fresh processes per case, using frozen sources and a matching verified release
receipt. Tree uses the attached 110×40 UI with preloaded modules and Git/LSP disabled;
filesystem caches are warm, with no concurrent tests or builds. All 30 runs passed,
every copied file was verified, and timed observer RPC counts were zero. These are
independent-process medians in milliseconds, not p95 or a new legacy comparison.

| Measurement                                  | Before ms | After ms |
| -------------------------------------------- | --------: | -------: |
| 1,000 files, all rows ready                   |     33.47 |    33.60 |
| 50,000 files, all rows ready                  |   2613.77 |  2561.73 |
| 1,000 files, unchanged refresh                |     17.54 |     7.75 |
| 50,000 files, unchanged refresh               |   1044.00 |   447.01 |
| 50,000 files, refresh process CPU             |    660.34 |   510.71 |
| 50,000 files, refresh main-thread CPU         |    263.08 |   116.59 |
| Copy 1,000 × 4 B, Job terminal                |   1305.93 |  1186.79 |
| Copy 1,000 × 4 B, source expanded             |   1390.81 |  1270.76 |
| Copy 10,000 × 4 B, Job terminal               |  12995.17 | 12396.82 |

Refresh time fell by about 56–57%. The 50k before/after ranges were
1042.82–1048.21 / 440.05–447.05 ms. Copy-duration ranges overlap, and CPU and memory
did not improve uniformly. Collapsed 1k copy process CPU was 894.23 → 930.94 ms,
with main-thread CPU 235.85 → 263.82 ms; 10k values were 9401.63 → 9547.99 ms and
2534.40 → 2661.36 ms. Expanded 1k main-thread CPU fell from 1093.61 to 990.91 ms.
The 10k final physical footprint rose from 87.30 to 89.20 MiB, while native retained
accounting stayed about 38.38 MiB. These are post-GC snapshots, not peak memory.
This change establishes a refresh improvement, without establishing uniform copy
CPU/memory savings or overall superiority to legacy.

A separate exploratory 16 ms variant was discarded: its 1k all-row readiness
median rose from 37.95 to 54.12 ms, and 10k copy Job time did not improve. Those
samples remain separate from the final comparison; production retains 8 ms.

Final verification:

- Lua: 34 suites / 262 cases passed. Three new regressions cover pagination during
  a held display deadline, first nonempty publication, and active-preparation
  backpressure. Explorer fixture initialization/idle now waits for publication;
  cursor navigation still works against the displayed frame during confirmation
  or deliberately paused publication. Existing safety assertions are unchanged.
- Three-process acceptance passed navigation/root recovery, idle, 97-directory
  recursive root watch, full-config create/rename/delete and dirty-buffer
  preservation, and all nine Job UI scenarios per process, including typed/scripted
  exit during copy. Idle phases had zero redraw notifications. Three vtsls 0.3.0
  rename runs passed with unsaved buffers and import edits; `willRenameFiles`
  remains unit coverage because this server supports only `didRenameFiles`.
- A 20-cycle / 1k-file lifecycle smoke passed Tree/List transitions, watch rename,
  hide/reopen, two second-tab openings and one full disposal. Hidden watches and
  queued work were zero. Before the final JIT trace flush, weak references retained
  zero sessions/views and one data object; after flushing traces, the ownership
  assertion confirmed that all disposed session/data/view objects were collectible.
  This boundary does not establish leak-free operation over an unbounded session.
- StyLua, all 246 field/parameter annotation alignments in changed Lua files, and
  `git diff HEAD --check` passed. Native code and Node harness are unchanged; their
  previous 237 Rust UX / 11 Node test results are reused, not newly executed here.
  The same three Git-writing Lua suites and `git_1000` remain excluded. Cross-volume
  and Linux/Windows/WSL runtime behavior were not revalidated.

Evidence is retained under
`/var/folders/46/g_pc2kcd0png2zh_xr46wwp00000gp/T/explorer-pacing-Y51Bwe/`:
`before-inputs.json`, `final-inputs.json`, `paired-final/`, `final-regression-v3/`,
`final-checks.json`, `final-acceptance/` and `final-soak/`. The exploratory
`paired-stage-a/` and `paired-stage-b/` datasets and the original failed regression
outputs are retained separately. All final input/artifact checks passed.

## 2026-10-04 small-file copy acceptance

The change based on `931239462` reduces the cost of inserting copied entries into
the native source. A child that sorts after the last sibling takes the append
path; other positions retain binary search. Comparisons borrow native filename
bytes instead of allocating lowercase/raw sort-key vectors. Directory precedence,
ASCII case folding, raw-byte tie breaking and exclusion of the moving entry keep
their existing semantics. File IO, identity checks, cancellation, publication
ownership and the 8 ms display window are unchanged.

Apple M1 Pro / 32 GiB, Darwin 27.0.0, Neovim 0.12.5 Release, libuv 1.53.0. Both
before/after libraries were built offline with Rust 1.99.0 and verified receipts;
frozen Lua/native sources and the comparative drivers were checked during each
matrix. Fresh processes alternate A/B and B/A with identical fixtures, the 110×40
Tree UI, warm filesystem caches and no concurrent agent tests/builds. Background
system activity remains uncontrolled. Every copied file was verified, and timed
observer RPC counts were zero.

The initial five-case matrix passed all 30 runs, three processes per side. Because
10k timing ranges overlapped substantially, a separate five-process-per-side
10k matrix was run. These are its independent-process medians, not p95:

| 10,000 × 4 B copy         | Before ms | After ms |
| ------------------------ | --------: | -------: |
| Job terminal             |  10396.62 | 10031.03 |
| Job process CPU          |   7899.00 |  7268.22 |
| Job main-thread CPU      |   2126.43 |  1957.82 |

The medians indicate about 3.5% less elapsed time and 8% less process CPU. Computing
each paired process ratio first gives median improvements of 3.6% elapsed / 5.9%
CPU; individual pairs do not all improve. Elapsed ranges were 9.38–19.70 s before
and 9.26–15.04 s after. The per-process maximum tick-gap median was 4.27 → 5.21 ms,
with an after maximum of 7.71 ms; these samples establish no universal latency bound.

The initial matrix showed only small 1k CPU changes: 843.60 → 828.86 ms collapsed
and 1431.13 → 1414.20 ms expanded. The 1k × 64 KiB case was 1046.35 → 1004.36 ms;
a single 64 MiB file remained about 46 ms through Job terminal. Those three-process
measurements are separate from the five-process confirmation. This reduces one
source of per-item work and does not establish parity with legacy small-file copy.

Final 10k physical footprint was 89.05 → 88.92 MiB, with native retained accounting
about 38.38 MiB on both sides. The initial three-process footprint had instead
risen from 87.99 to 89.58 MiB. These post-GC snapshots do not establish a retained
memory improvement; the change introduces no new cache or retained source handles.

Validation:

- Rust UX: 239 passed, 15 opt-in cases ignored. Two new regressions compare the
  borrowed ordering with owned keys, including native byte names and directory
  links, and compare insertion positions with a linear oracle across empty/single/
  populated parents, ties, boundaries and exclusion of the moving entry.
- Lua: 34 suites / 262 cases passed, reusing unchanged successful suite results
  and rerunning the corrected annotations suite through the normal runner.
  Its original failure was also reproduced with the pre-change release library:
  an initial watch reread advanced only the source/load revision after the 150 ms
  coalescing window. The fixture's quiet window is now 250 ms instead of 50 ms;
  frame identity, buffer text and changedtick assertions remain intact. Nine
  before/after/debug focused runs also passed.
- Three-process release acceptance passed 50k Tree/List, navigation/root recovery,
  idle, recursive root watch, full-config file operations and dirty buffers, and
  three vtsls 0.3.0 renames. Job UI passed all nine scenarios in each of three
  fresh processes, including hidden backlog, cancellation and typed/scripted exit.
  Its cursor gate now waits for an applicable published frame after a completed
  Job. A held-deadline probe reproduced the old gate accepting a stale selection
  revision on both native versions; production Stale protection is unchanged.
- `cargo fmt`, changed Lua StyLua checks and diff checks passed. Node harness
  implementation is unchanged; the prior 11 Node tests remain applicable. The
  same three Git-writing Lua suites and `git_1000` were excluded. Cross-volume
  and Linux/Windows/WSL runtime behavior were not revalidated.

Evidence is retained under
`/var/folders/46/g_pc2kcd0png2zh_xr46wwp00000gp/T/explorer-smallfiles-620nuroj/`:
`before-inputs.json`, `sort-inputs.json`, `paired-sort/`, `paired-verify/`,
`native-ux-tests.log`, `final-regression.json`, `annotation-trace/`,
`annotation-fixed/`, `job-readiness/`, `acceptance/` and `jobs-ui-fixed/`.
The initial failed regression/acceptance outputs are retained; the focused runs
cover their fixture corrections. Only the Job UI driver changed after the timed
copy matrices; it is outside those comparative copy paths. Installed modules and
receipts match the verified release artifacts, with old copies under
`installed-before/` and replacement hashes in `deployment.json`. Restart an
existing Neovim process to use the rebuilt module.

## 2026-10-05 bounded copy publication acceptance

Unix regular-file copying now reuses the opened descriptor's metadata for its
identity check. Recursive copies group completed ordinary files up to 64 KiB in
one owner action, capped at 16 items and 64 KiB of pending reservations/staging.
Each item retains the existing publication validation and atomicity. Confirmation,
directory/parent transitions, top-level results and terminal cleanup flush completed
siblings; cancellation preserves their IO results and selection cleanup. Job/data
budgets are unchanged. The confirmed contract is in `spec/design/filetree.md`.

A separate diagnostic source sampled one in 64 calls, calibrated empty spans and
recorded thread CPU as well as wall time. The 10k case made 10,001 owner publications;
output creation/publication and source opening dominated sampled worker CPU. Owner
publication itself was not the largest cost, so batching was accepted only after
uninstrumented measurements. Nested profile spans are not additive, and directory
sampling biases prevent treating the diagnostic totals as release acceptance.

The final matrix compares frozen native `94d408fb1` inputs with this implementation:
six cases, five alternating fresh processes per side, 110×40 UI, shared padded-name
fixtures, warm caches, natural GC during timing and no concurrent tests/builds.
All 60 processes passed, with zero timed observer RPCs and every source/destination
file verified. Values below are medians in milliseconds, not p95 estimates.

| Case                 | Job before | Job after | CPU before | CPU after | Main before | Main after |
| -------------------- | ---------: | --------: | ---------: | --------: | ----------: | ---------: |
| 1,000 × 4 B          |     842.43 |    891.72 |     700.54 |    564.09 |      180.81 |      90.72 |
| 10,000 × 4 B         |   12127.21 |   8952.21 |    8357.56 |   5476.22 |     2294.61 |     839.66 |
| 1,000 × 4 B expanded |    1531.78 |   1379.67 |    1714.56 |   1099.30 |     1082.72 |     573.72 |
| 1,000 × 64 KiB       |    1691.03 |   1192.42 |     973.05 |    668.86 |      317.11 |     112.01 |
| One 64 MiB file      |      42.17 |     18.07 |      18.76 |     19.00 |        3.00 |       3.24 |
| 1,000 × 4 B outside  |    1128.73 |   1083.89 |     774.39 |    595.46 |      226.49 |     102.89 |

The 10k case reduced median Job wall time by 26.2%, CPU by 34.5% and main-thread
CPU by 63.4%. Its wall ranges still overlap: 9.29–15.66 s before and 8.66–12.53 s
after. The collapsed 1k median wall time increased 5.9% despite lower CPU; this is
not a uniform throughput win. The 64 MiB file is outside batching, its wall ranges
overlap substantially and CPU is essentially unchanged, so its wall median does
not establish a batching benefit. The largest tick gap across all samples was
10.54 ms; 10k median maximum gaps were 4.53 → 4.30 ms. This is a native before/after
comparison and does not establish parity with the legacy Explorer.

A separate 12-process metadata-only versus batch comparison isolated publication
grouping: 10k median Job/CPU/main CPU changed from 14.33/8.79/2.57 s to
8.59/6.15/0.97 s. An earlier attempt reused a relocated Cargo cache's batch binary
for the metadata arm; matching artifact hashes exposed this and those measurements
were discarded. The accepted metadata build followed `cargo clean -p yoz --release`.

Readiness checkpoints keep the original `ready_ms` condition. For the final 10k
case, median Job terminal, observed Session idle, matching frame and full ready were
8952.21, 8953.79, 8960.25 and 8960.25 ms. For 64 MiB they were 18.07, 18.31, 21.02
and 21.02 ms. The earlier ~168 ms short-copy ready tail was not reproduced here;
it is not a fixed interaction delay. These are first observations after terminal
delivery and do not date the exact Rust unlock or exclude later watch events.

Memory was measured separately in three fresh processes each at 1k and 10k files,
with the source fully expanded then collapsed before copying. For 10k, median Rust
retained bytes were 19.47 MiB at 10,011 loaded nodes, 38.49 MiB at Job terminal,
38.47 MiB at ready with the Job held and 38.38 MiB after Job release. Hide released
all watches and queued work while retaining about 38.37 MiB. Disposed Lua owners
remained reachable through diagnostic JIT traces; after recording that boundary
and flushing traces, only the deliberately held native owner remained, still with
38.37 MiB at 20,012 nodes. Releasing it cleared all tracked weak references. Physical
footprint stayed around 98 MiB, so footprint alone cannot identify live retention.
The ordinary collapsed 10k matrix ended at 88.58 → 88.22 MiB physical footprint
and about 38.38 MiB native retained on both sides. This change does not reduce the
per-node Source/index storage cost or establish a memory improvement.

Validation passed 241 Rust UX tests (15 existing opt-in tests ignored), 34 Lua
suites / 358 cases, and three processes with nine real Job UI scenarios each.
The new regression cases cover publication before overwrite confirmation,
successful siblings around a stale batch item and cancellation during a source
file that grew after admission. Full configuration create/rename/delete, unsaved
buffer preservation and cursor/refresh behavior passed; a separate fresh process
rechecked the installed artifact after deployment completed. The same three
Git-writing Lua suites were excluded, and cross-volume/platform runtime checks
were not repeated. Formatting, Lua annotation alignment and diff whitespace checks
passed. No profiling hooks or extra dependencies were added to production.

Evidence is retained under
`/var/folders/46/g_pc2kcd0png2zh_xr46wwp00000gp/T/explorer-copy-pipeline-cqhwpppp/`:
`profile-runs/`, `paired-batch-pilot/`, `paired-metadata-batch-clean/`, `paired-final/`,
`memory-stages-loaded/`, `memory-summary.json`, `final-rust-ux.log`, `lua-regressions/`,
`final-jobs-ui.json`, `post-install-full-config.json` and their input/build records.
The first memory probe only resolved one path; its correction record excludes that
checkpoint from the loaded-source comparison. The final native input hash is
`245762ef131d19270f1e6262179ebf0854d1efcce7f8b8340e875534634949b0`.
Installed libraries and receipts match the measured batch artifacts; old copies
are under `installed-before/` and replacements are recorded in `installed.json`.

## 2026-10-05 copy follow-up experiments

Two further experiments were evaluated against the preceding bounded-publication
implementation, in independent source-bound release builds. Each matrix ran three
alternating fresh processes per side for 1k and 10k four-byte files: 24 processes
total, all content checks passed and timed observer RPC counts were zero. No builds
or tests ran alongside the measurements. System background load was uncontrolled;
these are medians, not confidence bounds, and the two matrices must not be pooled.

| Experiment / files | Job before ms | Job after ms | CPU before ms | CPU after ms |
| ------------------ | ------------: | -----------: | ------------: | -----------: |
| Fewer checks / 1k  |       1368.89 |      1051.91 |        744.18 |       685.12 |
| Fewer checks / 10k |      14646.47 |     14834.76 |       7396.95 |      7477.89 |
| Append batch / 1k  |       1149.72 |      1132.53 |        681.25 |       673.22 |
| Append batch / 10k |      12631.39 |     12436.44 |       6815.97 |      6770.11 |

The first experiment removed five repeated pathname metadata queries per ordinary
file, keeping the Copier's checks around IO and the Temporary's final destination
check. Its 1k result improved, but the 10k CPU and wall medians rose about 1%, so it
did not establish a benefit across scales. The second combined sorted new siblings
into one model transaction, falling back to individual publication for stale items,
existing entries, other ordering and aggregate capacity failures. Its 10k CPU median
fell only 0.7%, while main-thread CPU rose from 1037.54 to 1133.97 ms; wall ranges
overlapped. Neither experiment was retained. The remaining dominant costs in the
existing profile are source opening, private-output creation and filesystem publish;
these results do not justify more owner-side specialization on their own.

Four behavioral regressions were retained against the unchanged production code:

- Replacing the source during streaming preserves the replacement and original
  destination, rejects publication and removes the private output.
- Creating or replacing a destination during streaming preserves that external
  occurrence, including after overwrite confirmation.
- Exhausting the data budget after bytes are copied makes whole-action rejection
  report IO Success with a ResourceLimit `sync_error`, without deleting the output.
- When the model can admit only one more node, a three-item publication preserves
  the successful prefix and reports per-item capacity errors for the remaining two.

The final Rust UX run passed 245 tests with 15 existing opt-in tests ignored. Source
comparison confirmed that only test files and the `#[cfg(test)]` tail of `jobs.rs`
changed in this follow-up. The preceding Lua/UI acceptance therefore still covers
the production implementation. Release artifacts were rebuilt because native input
fingerprints include Rust tests; both installed modules passed load/receipt verification.
Formatting and whitespace validation passed.

Evidence is retained under
`/var/folders/46/g_pc2kcd0png2zh_xr46wwp00000gp/T/explorer-copy-boundaries-67_bekzx/`:
`checks/`, `append/`, their build/input records, `paired-checks-pilot/`,
`paired-append-pilot/`, `experiment-summary.json`, `final-rust-ux.log`,
`final-source.json`, `final-release-build.log`, `installed.json` and `installed-before/`.
The final native input hash is
`dd4516492aff48cd2d1dd9523c0fe7e32cc0e118f76198663ce0b83367aba7b4`.

## 2026-10-05 payload memory acceptance

The baseline is commit `4eaf8b440`. A separate diagnostic build grouped live charges
by payload kind and persistent-container type. Its `Charge` remained 16 bytes, and
each snapshot asserted that category totals equalled the existing retained-byte
counter. Two diagnostic processes covered 1k and 10k source files, fully loaded
before copying. These are ledger estimates, including bookkeeping, not exact heap
allocation sizes; diagnostic timings and footprint are excluded from acceptance.

After the 10k copy, with disposed Lua owners collected and the native data owner
held, 20,012 nodes retained 38.37 MiB:

| Owner category                         | Retained MiB |
| -------------------------------------- | -----------: |
| Payload allocations and bookkeeping    |        22.05 |
| Source node map                        |         5.19 |
| Source key map                         |         2.14 |
| Filetree name/reverse indexes          |         5.92 |
| Order-location indexes                |         2.14 |
| Other structures and watch reservation |         0.94 |

The payload category contained 100,060 accounting objects: five per node for its
key, label, NodeData, fields and encoded Entry. Their fixed record/ledger charges
alone accounted for 14.51 MiB. Releasing the remaining UI/old-version references
reduced total retained bytes by about 0.10 MiB, so old snapshots were not the main
steady-state cost in this case.

The accepted change derives a payload's registry key from its retained owner and
stores immutable child references in an exactly sized boxed slice. Common captures
reserve the required child count before construction. The accounting record shrank
from 88 to 64 bytes on this host, while owners still keep allocations alive until
registry removal. Shared-allocation accounting, snapshot validity and budget limits
are unchanged. Production contains no diagnostic fields or profiling hooks.

Uninstrumented source-bound release comparisons used shared warm-cache fixtures,
alternating fresh processes, natural GC during timings and no concurrent builds or
tests. Copy used five processes per side per case; browsing used three processes
per side per case and summarized repeats within each process first. All 50 processes
and 992 timed operations passed with zero observer RPCs. Every copied file was
verified. Medians below are post-operation, post-GC snapshots in MiB:

| Case                  | Retained before | Retained after | Footprint before | Footprint after |
| --------------------- | --------------: | -------------: | ---------------: | --------------: |
| Copy 1k × 4 B         |            4.32 |           4.01 |            18.63 |           18.30 |
| Copy 10k × 4 B        |           38.38 |          35.33 |            86.61 |           81.59 |
| Browse 1k Tree        |            2.70 |           2.54 |            18.73 |           18.33 |
| Browse 1k List        |            2.70 |           2.54 |            18.47 |           18.22 |
| Browse 10k Tree       |           22.02 |          20.49 |            72.48 |           69.88 |
| Browse 10k List       |           22.02 |          20.49 |            71.38 |           70.22 |
| Browse 9k + 1k branch |           21.99 |          20.47 |            69.97 |           66.25 |

The 10k copy reduced retained bytes by 8.0% and physical footprint by 5.8%. Its
footprint ranges were 86.11–90.16 MiB before and 80.45–85.84 MiB after. The 1k
footprint ranges overlap. These final snapshots do not imply lower memory at every
transient boundary: the 1k List immediate-open retained median was 2.66 → 3.08 MiB,
while its final snapshot consistently settled lower.

This is a memory improvement, without a uniform latency or CPU improvement. Copy
10k median Job time was 12.64 → 12.28 s and Job CPU was 6.80 → 6.98 s; both ranges
overlap. Copy 1k Job CPU was essentially unchanged. First-screen browsing remained
about 25–26 ms. Full-ready medians were 362.89 → 373.83 ms for 10k Tree and
404.89 → 370.08 ms for 10k List; 1k Tree changed from 48.58 to 53.57 ms. Expanded
branch readiness was 22.61 → 20.83 ms. Cursor, scroll, selection, refresh, collapse
and reopen are recorded separately in the raw matrix; no p95 claim is made from
three-process groups. System background load was uncontrolled.

Six additional lifecycle processes verified 1k/10k copies with diagnostic GC at
terminal delivery. At 10k, source-loaded retained bytes were 17.94 MiB; after copy,
Job release and disposal they remained about 35.4 MiB while owners were still held.
After recording natural JIT retention and flushing traces, only the explicit native
owner remained, at 35.32 MiB. Releasing it cleared every tracked weak reference;
hidden watches and queued work were zero. Physical footprint still stayed around
94 MiB after release, so it must not be interpreted as live allocation or a leak.

Validation passed 247 Rust UX tests (15 existing opt-in cases ignored), 34 Lua
suites / 358 cases, and three processes with nine real Job UI scenarios each.
New regressions cover shared nested payloads being charged once and remaining
charged until their last capture drops, plus external allocations staying alive
until ledger release. Existing retained-frame capacity/recovery tests also passed.
The installed release passed full-configuration create/rename/delete, unsaved-buffer
preservation, 100 cursor moves and repeated refresh, with no reported messages.
The same three Git-writing Lua suites remain excluded; other-platform and
cross-volume runtime cases were not repeated. Formatting and whitespace checks
passed, and both installed libraries and receipts match the tested source.

Evidence is retained under
`/var/folders/46/g_pc2kcd0png2zh_xr46wwp00000gp/T/explorer-memory-faNZxg/`:
`before-inputs.json`, `profile-inputs.json`, `compact-inputs.json`, `memory-profile/`,
`attribution-summary.json`, `attribution-groups.json`, `paired-compact-copy/`,
`browse-compact/`, `memory-compact/`, `compact-memory-summary.json`,
`compact-rust-ux.log`, `lua-regressions/`, `final-jobs-ui.json`,
`final-full-config.json`, `installed.json` and `installed-before/`.
The final native input hash is
`0d359e10d7ce87b62f8a6b6859809526fa87e5fbea5abbb57625dade0601d652`.

## 2026-10-06 native provider payload acceptance

The baseline is `27b890d26`. Filetree now keeps its immutable resource bytes in
Treeview's native `NodeData.payload` slot. Structured `fields` remain available for
queries and Lua-facing data; Filetree no longer allocates a one-entry field map
for every resource. All resource readers, metadata updates, link annotations and
move validation use the native slot. The resource codec and filesystem IO are
unchanged. The contract is recorded in `doc/spec/treeview/data.md` and
`spec/design/filetree.md`; there is no adapter for the former private field.

The native slot participates in full imports, partial updates, content comparison,
scope validation, staging/source byte limits and shared retained accounting. Its
allocation shares the existing ledger with `Value::Bytes`, including when both
refer to the same buffer. Old sources retain their immutable version. Empty
structured fields use the existing shared empty map.

Source-bound release comparisons used Apple M1 Pro / 32 GiB, Neovim 0.12.5,
Rust 1.99.0, identical warm-cache fixtures and 110×40 UI. Fresh processes alternated
A/B and B/A without concurrent builds or tests. Eight copy cases ran five processes
per side, and seven Tree/List/branch cases ran three per side: 122 processes, all
passed, with zero timed observer RPCs and every copied file verified. Values below
are independent-process medians after full GC; physical footprint and Rust retained
accounting overlap and are not peak memory or additive metrics.

| Case                  | Retained before MiB | Retained after MiB | Footprint before MiB | Footprint after MiB |
| --------------------- | ------------------: | -----------------: | -------------------: | ------------------: |
| Copy 1k × 4 B         |                4.00 |               3.56 |                18.23 |               16.69 |
| Copy 10k × 4 B        |               35.33 |              30.90 |                84.39 |               69.55 |
| Browse 10k Tree       |               20.49 |              18.28 |                70.56 |               64.02 |
| Browse 10k List       |               20.49 |              18.28 |                70.73 |               63.95 |
| Browse 50k Tree       |              101.13 |              90.06 |               231.14 |              189.19 |
| Browse 50k List       |              101.13 |              90.06 |               232.49 |              185.94 |
| Browse 9k + 1k branch |               20.47 |              18.25 |                67.05 |               61.84 |

Copy 10k retained bytes fell 12.5% and footprint fell 17.6%. Both variants retained
20,013 nodes. Its footprint ranges were 83.88–85.59 MiB before and 68.25–70.81 MiB
after. The 50k Tree/List footprint reductions were 18.2%/20.0%, with 50,011 nodes
on both sides. These gains do not come from dropping resources or loosening budgets.
The 100-file footprint remained effectively unchanged.

This is a storage improvement, without a uniform throughput improvement. Copy 10k
Job wall/CPU/main CPU medians were 12.615/6.218/1.024 → 12.671/6.141/0.945 s.
Job wall ranges were 12.45–20.41 s before and 12.12–13.19 s after. The 100-file
and 1k Job wall medians rose from 104.22 → 132.66 ms and 1098.39 → 1169.98 ms,
with overlapping ranges; other size/expanded/outside cases are retained separately.
The maximum copy tick gap across all samples was 10.50 ms. Diagnostic worker-stack
sampling still concentrated on source open, private-output creation and rename;
those samples include blocked time and are not process-CPU proportions or release
acceptance timings.

50k Tree complete readiness was 2362.09 → 2315.95 ms; its first screen was
21.47 → 20.54 ms. The initial three-process 1k Tree ready median increased from
27.68 → 41.44 ms, prompting a separate 20-process-per-side confirmation. In that
independent dataset, ready median/p95 were 29.75/49.30 → 28.57/40.95 ms, first-screen
medians were 20.66 → 19.72 ms, and main CPU medians were 19.42 → 18.19 ms.
The three-process increase was not reproduced as a stable regression. These 40
additional processes remain separate from the original browsing matrix; no p95
is claimed for its three-process groups. Background system load was uncontrolled.

Validation passed 252 Rust UX tests (15 existing opt-in cases ignored), 34 Lua
suites / 358 cases and all nine native acceptance groups. New regressions cover
native-only budget charging, shared native/field ownership, immutable old versions,
payload clearing, batch/source limits and provider-scope isolation. Real Job UI
passed 3 × 9 scenarios; soak passed 3 × 40 cycles; recursive watch covered 97
directories with one root. Full configuration file operations and unsaved buffers,
navigation, idle, watch activity and three installed-vtsls renames passed. Vtsls
0.3.0 exercised didRename/import edits and reattachment, not unsupported willRename.
The same three Git-writing Lua suites, actual Git A/B, cross-volume and other-platform
runtime were excluded. Formatting and whitespace checks passed.

One final native-only accounting regression was added after copy measurement.
Rebuilding changed only the test-source fingerprint: the measured and final Lua
libraries have the identical SHA-256
`bbc2241d94b9c4ecae8f19576baa52bb9a11c3240990c777ebcca6c198ca4190`.
The measured source snapshot is preserved separately. Both installed libraries and
receipts match the final source; a fresh process using the installed default module
passed create/rename/delete, dirty-buffer preservation, 120 cursor moves and repeated
refresh with no reported messages. Restart an existing Neovim process to use it.

Evidence is under
`/var/folders/46/g_pc2kcd0png2zh_xr46wwp00000gp/T/explorer-refactor-hjZ6fa/`:
`baseline.json`, `before/`, `payload-source/`, `measured-payload-inputs.json`,
`paired-payload/`, `browse-final/`, `browse-focused-final/`, `focused-statistics.json`,
`final-build-equivalence.json`, `rust-ux-final.log`, `lua-regressions/`, `acceptance/`,
`deployment.json` and `installed-full-config.json`. The final native source hash is
`bf560de9754e4910f8bb9c9676f3ab43411d876c7c04fd9a4bf4c7d150ca8844`.

## 2026-10-06 directory staging acceptance

The baseline is the verified provider-payload build above, still based on
`27b890d26`. On macOS/Linux, copying an ordinary directory to an absent destination
now fills a private directory and publishes it with one no-replace root rename.
An identity journal owns temporary output independently of browse nodes. Source
discovery retains the existing task leases and NodeIds; target descendants load
when browsing needs them. Existing-directory merges and other operations retain
their per-item path. The publication, cancellation, cleanup and capacity contract
is in [Filetree](../../../spec/design/filetree.md#执行器).

Release comparisons used Apple M1 Pro / 32 GiB, macOS, Neovim 0.12.5 and Rust 1.99.0.
Fresh native processes alternated A/B and B/A against shared warm-cache fixtures,
with 110×40 UI and natural GC during timing. No agent builds, tests or other
benchmarks ran concurrently. System background load was uncontrolled and was high
during part of this run; wall-time ranges are retained separately from CPU costs.
All measured native/runtime inputs and libraries were fingerprinted and checked.

The accepted copy dataset contains five processes per side for eight cases: 80
successful processes, zero timed observer RPCs, with every source/destination file
verified after timing. Values are independent-process medians.

| Copy case             | Job before ms | Job after ms | CPU before ms | CPU after ms |
| --------------------- | ------------: | -----------: | ------------: | -----------: |
| 100 × 4 B             |        183.11 |       106.07 |         69.14 |        36.04 |
| 1k × 4 B              |       1978.72 |       979.81 |        717.57 |       355.40 |
| 10k × 4 B             |      17286.72 |      9063.76 |       8051.01 |      3794.87 |
| 1k × 4 KiB            |       1773.04 |       926.04 |        746.70 |       351.50 |
| 1k × 64 KiB           |       2080.32 |      1199.09 |        825.44 |       418.01 |
| 1k, source expanded   |       1471.69 |       701.38 |       1117.14 |       329.36 |
| 1k, target outside    |       1888.80 |      1011.90 |        633.39 |       322.27 |
| One dense 64 MiB file |         31.99 |        21.50 |         18.71 |        19.02 |

Copy 10k reduced Job wall time by 47.6%, process CPU by 52.9% and main-thread CPU
by 83.6% (1200.76 → 196.40 ms). Wall ranges were 15.99–32.55 s before and
7.93–12.08 s after; CPU ranges were 7.09–9.31 s and 3.34–3.95 s. Its maximum tick
gap across five samples was 14.20 → 13.39 ms. The dense single-file path does not
use directory staging; its CPU was effectively unchanged, and its wall-time
difference is not evidence of a staging benefit.

After copy, full GC and Job release, the collapsed 1k case retained 3.56 → 2.05 MiB
and 2013 → 1013 nodes; footprint was 17.11 → 13.92 MiB. Copy 10k retained
30.90 → 15.73 MiB and 20,013 → 10,013 nodes, with footprint 68.69 → 55.06 MiB.
These reductions depend on the destination remaining unbrowsed. Native retained
accounting overlaps process footprint; neither value is peak memory, and they
must not be added together.

A separate 24-process comparison explicitly expanded the copied destination or
switched to List after copy: three processes per side, mode and size, all passed
with content checks and zero timed observer RPCs. It measures the deferred cost:

| First browse of copied output | Ready before ms | Ready after ms | Named item before ms | Named item after ms |
| ----------------------------- | --------------: | -------------: | -------------------: | ------------------: |
| 1k Tree expansion             |           15.91 |          24.56 |                16.16 |               16.76 |
| 10k Tree expansion            |          105.04 |         510.45 |                31.57 |              131.25 |
| 1k List switch                |           22.52 |          24.21 |                    — |                   — |
| 10k List switch               |          135.25 |         551.77 |                    — |                   — |

The last two columns were initially mislabeled as first-screen latency. That probe
waited for the specific name `file-00000.lua`, not the first copied child. On APFS,
directory pages need not encounter that name first. Follow-up runs of this same
release observed the first children at 18.07/24.39 ms, the named file at
134.53/153.86 ms, and full readiness at 506.35/520.77 ms. The ready measurements
remain valid; the named-file timing must not be interpreted as a blank-screen wait.

List makes no destination first-screen claim because those rows are offscreen.
Both variants then retain the same 2013/20,013 nodes. For 10k, Tree retained
33.33/33.36 MiB and List 35.75/35.79 MiB: loading the target pays the usual browse
cost. Within this separate dataset, copy plus first Tree expansion was
13.99 → 7.48 s, and copy plus List switch 17.79 → 9.65 s. The optimization moves
target enumeration to demand; it does not make the first expansion free.

Seven ordinary Tree/List/branch cases passed 42 processes. The 50k Tree/List ready
medians were 2369.92/2416.23 → 2388.02/2385.82 ms, with unchanged 90.06 MiB retained
and 50,011 nodes. Initial three-process 1k Tree and branch-open medians increased,
so both cases received a separate 20-process-per-side confirmation (80 processes).
1k Tree ready median/p95 were 28.39/43.83 → 27.78/30.89 ms; branch initial ready
was 272.28/289.53 → 266.74/294.19 ms. First screens stayed around 21–22 ms, and the
initial regressions were not reproduced as stable costs. These datasets remain
separate; p95 is reported only for the twenty-process groups.

One initial expanded-source baseline process rejected copy preparation with
`Stale: selection revision changed`. Expected rows alone did not establish a
current selection frame after loading children. The expanded-source setup now
waits for the frame selection stamp to match native state before timing. Its five
accepted A/B pairs passed separately; the preceding four complete copy cases do
not execute that setup branch. The original failure and harness version are kept.

Validation passed 262 Rust UX tests (15 existing opt-in cases ignored), 34 Lua
suites / 358 cases and all nine native acceptance groups. Regressions cover private
visibility through refresh/watch/aliases, cancelled and partial copies, ownership
conflicts, capacity before IO, source replacement, committed IO with model failure,
permission handling and delayed target loading. Unix source open and macOS name
observation use nonblocking descriptors so a FIFO cannot stall a worker. Real
Job/exit UI, 3 × 40 soak cycles, recursive watch, full-config file/buffer actions
and three installed-vtsls renames passed. This is macOS runtime acceptance;
Linux execution, cross-volume IO and the three Git-writing Lua suites remain
outside this run. No dependencies were added.

Evidence is under
`/var/folders/46/g_pc2kcd0png2zh_xr46wwp00000gp/T/explorer-staging-rOSUBg/`:
`before/`, `accepted-source/`, their input records, `copy-summary.json`,
`paired-final/`, `paired-expanded-readiness/`, `paired-remainder/`,
`browse-candidate/`, `browse-focused-candidate/`, `focused-statistics.json`,
`paired-destination-tree/`, `paired-destination-list/`, `destination-summary.json`,
`rust-ux-3.log`, `lua-regressions/`, `acceptance/`, `deployment.json`,
`installed-full-config.json` and `final-verification.json`.
Pilot and failed exploratory probes are retained separately from accepted samples.
The native source hash is
`04e705f91cff98d6038707e3963ea6730404322a4229e8b3a360ecb4ee9b688c`;
the tested and installed Lua library SHA-256 is
`25f3d217c854ba47eb4da000946bf0b18c49ca8f76ac0375271ac0845810cddd`.
Both libraries and receipts match this source. A fresh process using the installed
default module passed create/rename/delete, unsaved-buffer preservation, 120 cursor
moves and repeated refresh without reported messages. Existing Neovim processes
need a restart to load the updated native module.

## 2026-10-06 nested page projection acceptance

Baseline `e9a2b32` contains the separately committed Treeview payload, Filetree
directory staging and documentation changes. Its verified native source is
`04e705f91cff98d6038707e3963ea6730404322a4229e8b3a360ecb4ee9b688c`.

An isolated diagnostic build timed a 10k copied-directory expansion: scanning
took about 57 ms, page commits 56 ms and native projection 202 ms. The existing
fixed-gap insertion path applied only to display roots. Nested pages still
reindexed rows and repaired ancestor boundaries for each arriving subtree.
Projection now batches normalized independent subtrees at every visible depth,
then repairs boundaries once. Globally sorted List and node-only List updates
retain their required sequential ordering. The contract is in
[Treeview rendering](../../../doc/spec/treeview/render.md).

The diagnostic also established that the former 131 ms "first screen" metric
actually waited for one specific filename. The preceding acceptance record now
labels that metric correctly. The repository's copy probe supports a separate
destination-browse phase and records both the first children and the named first
item, using the shared phase timer and renderer readiness checks.

Uninstrumented release comparisons used the same M1 Pro / 32 GiB environment,
110×40 UI, warm caches, natural GC during timing and alternating fresh processes.
All tests, builds and measurements ran serially. Background load remained
uncontrolled. The four destination-browse cases ran five processes per side:
40 processes, all passed with zero timed observer RPCs and copied-file content
verification. Independent-process medians follow; five samples do not establish p95.

| Destination browse | Ready before ms | Ready after ms | CPU before ms | CPU after ms |
| ------------------ | --------------: | -------------: | ------------: | -----------: |
| 1k Tree            |           19.43 |          11.65 |         21.75 |        12.67 |
| 10k Tree           |          499.10 |         339.41 |        534.07 |       371.35 |
| 1k List            |           21.92 |          15.01 |         25.59 |        24.54 |
| 10k List           |          544.74 |         360.20 |        662.38 |       518.15 |

10k complete readiness fell 32.0% in Tree and 33.9% in List; CPU fell 30.5% and
21.8%. Main-thread CPU was 174.62 → 158.31 ms and 203.97 → 184.54 ms. Tree first
children remained 16.74 → 16.66 ms; the named `file-00000.lua` appeared at
140.51 → 95.23 ms. Ready and UI flush remain separate events, so ready may precede
first visible text in small cases. Both sides retained 20,013 nodes after demand
loaded the target, with 33.36 MiB in Tree and 35.79 MiB in List.

Seven ordinary browsing cases passed 42 processes. The 50k Tree/List ready
medians were 2375.56/2361.31 → 2352.28/2344.78 ms. Eight copy regression cases
passed another 48 processes, including expanded source, outside target, 4 KiB,
64 KiB and dense 64 MiB files; every file was checked. The unbrowsed 10k copy
still retained 15.73 MiB on both sides. These regressions preserve the directory
staging gain; their wall-time variation is not attributed to this projection change.

Validation passed 263 Rust UX tests (15 existing opt-in cases ignored), 34 Lua
suites / 358 cases, all nine native acceptance groups and 130 formal comparison
processes. The new regression covers interleaved inserts below multiple parents
at different depths, compressed Tree, List ancestry, globally sorted List, parent
renames, fixed old frames and equivalence to complete projection. The test helper
compares ancestry text semantically because independent builders need not share
prefix allocations; it still checks label allocation ownership and complete row
layout. Native acceptance includes real Job/exit UI, 3 × 40 soak cycles, recursive
watch, full configuration and three installed-vtsls renames. Cross-platform,
cross-volume and the three Git-writing Lua suites remain outside this run.

Evidence is under
`/var/folders/46/g_pc2kcd0png2zh_xr46wwp00000gp/T/explorer-first-expand-24xcmo2v/`:
`commit-targets.json`, the three commit receipts, `before-inputs.json`,
`initial-diagnostic/`, `profile-source/`, `phase-profile/`, `paired-tree-pilot/`,
`paired-tree-final/`, `paired-list-final/`, `destination-summary.json`,
`browse-candidate/`, `paired-copy-regression/`, `rust-ux-1.log`, `lua-regressions/`,
`acceptance/`, `accepted-source/`, `deployment.json`, `installed-full-config.json`
and `final-verification.json`.
Diagnostic and pilot timings are separate from the formal uninstrumented results.
The accepted native source hash is
`eec9c7d2b3176e0ca5f028ec6145f76b4f4d7cb2180304bad93145dc22cd413e`;
the tested and installed Lua library SHA-256 is
`c15309ffa639be70fb0f836ea3fbc066efa0811b0973e4affbd094c77bf48fe9`.
Both installed libraries and receipts match the accepted source. A fresh process
using the default installed module passed create/rename/delete, dirty-buffer
preservation, 120 cursor moves and repeated refresh without reported messages.

## 2026-10-06 viewport icon preparation acceptance

The baseline includes the preceding nested-page projection change. Both sides use
the same source-bound Rust release, with native input SHA-256
`eec9c7d2b3176e0ca5f028ec6145f76b4f4d7cb2180304bad93145dc22cd413e`
and Lua-library SHA-256
`c15309ffa639be70fb0f836ea3fbc066efa0811b0973e4affbd094c77bf48fe9`.
No native code or library changed in this acceptance.

Two diagnostic 10k expansions previously made 722/760 file-icon queries for only
105/123 distinct paths. These queries took about 68/70 ms; all buffer writes took
about 7 ms in separate diagnostic samples. Source-wide cache invalidation caused
offscreen directory pages to repeat visible filetype detection. Diagnostics are
instrumented attribution, not release throughput measurements.

Explorer now prepares its icons in bounded Lua slices before frame publication,
reuses Treeview's exported viewport rows and retains only the latest prepared
viewport's validated resource values. Paths, kinds and directory completeness are
checked after source changes; cursor-only frames reuse their verified values.
Completed pure icon values survive a superseded plan, while displayed rows and
glyphs still change together at publication. Redraw no longer performs Resource
inspection, path construction or filetype detection. The contracts are in
[Explorer](../../../spec/design/feat/explorer.md) and
[Treeview rendering](../../../doc/spec/treeview/render.md).

Treeview installs consumer callbacks before its first frame request. Cold scrolling
and theme invalidation reuse its preparation pipeline, including a same-frame Swap
when text is unchanged. Prepared feature rows remain bound to the exact frame:
matching data/layout alone cannot preserve selection/expansion columns across a
retarget. Tests also cover redraw of an old empty frame during new icon preparation.

All final comparisons ran serially on Apple M1 Pro / 32 GiB, macOS, Neovim 0.12.5,
110×40 attached UI, warm filesystem/module inputs and natural GC. Git/LSP collection
is disabled in the comparable browse/copy fixtures. Fresh processes alternate A/B
and B/A; system background load is uncontrolled. Input/library fingerprints remained
unchanged and timed observer RPC counts were zero. The final harness waits for the
matching Neovim redraw before ready/CPU completion; earlier pilots used a different
boundary and remain separate.

Seven browse cases ran five processes per side: 70 successful processes. Values are
independent-process medians in milliseconds, not p95.

| Browse case | Ready before | Ready after | Main CPU before | Main CPU after |
| ----------- | -----------: | ----------: | --------------: | -------------: |
| 1k Tree     |        51.57 |       45.59 |           31.96 |          23.58 |
| 1k List     |        42.07 |       43.85 |           28.63 |          27.00 |
| 10k Tree    |       316.27 |      239.29 |          180.54 |         113.50 |
| 10k List    |       302.57 |      241.01 |          168.14 |         112.32 |
| 9k + 1k branch |    282.66 |      206.87 |          164.92 |          99.97 |
| 50k Tree    |      2349.60 |     1986.96 |         1130.65 |         795.50 |
| 50k List    |      2399.79 |     2000.80 |         1135.04 |         796.08 |

10k Tree/List main-thread CPU fell 37.1%/33.2%; 50k fell about 29.6%/29.9%.
Ordinary first screens stayed around 20–22 ms. The 1k List ready median increased
1.78 ms, so this is not a uniform latency win. A 50k median near two seconds does
not establish the design's p95 target. Cumulative CPU does not represent one
uninterrupted main-thread stall.

After the browse workloads and GC, 50k native retained accounting remained about
90.06 MiB with 50,011 nodes. Final Lua heaps were about 2.54–2.58 MiB. Process
physical footprint varied in both directions: Tree 185.97 → 188.25 MiB and List
192.38 → 189.24 MiB. These measurements do not establish lower process memory.

Four copy-then-browse cases ran three processes per side: 24 successful processes,
with every copied file's contents verified. The following phase starts after copy:

| Destination browse | Ready before | Ready after | Main CPU before | Main CPU after |
| ------------------ | -----------: | ----------: | --------------: | -------------: |
| 1k Tree            |        25.13 |       22.96 |           18.68 |          15.67 |
| 10k Tree           |       371.31 |      318.46 |          185.01 |         130.09 |
| 1k List            |        29.12 |       24.71 |           20.89 |          13.90 |
| 10k List           |       378.12 |      333.67 |          197.61 |         145.03 |

Preparing icons before publication has a first-content tradeoff: copied Tree first
children were 15.98 → 22.91 ms at 1k and 17.68 → 21.27 ms at 10k. After full 10k
destination browsing, native retained accounting stayed 33.36 MiB in Tree and
35.79 MiB in List. Copy IO and source discovery are unchanged; copy-duration
variation in these runs is not attributed to an IO optimization.

Validation passed 35 Lua suites / 367 cases, 11 Node harness tests and all nine
native acceptance groups. Coverage includes offscreen insertions, metadata-only
refresh, ancestor rename with retained NodeId, symlink target changes, bounded
scroll caches, theme invalidation, superseded preparation, attachment failure and
row-dependent features across selection retargets. Actual UI checks assert no icon
resolution during redraw and no text rewrites for scrolling/theme refresh.
Acceptance includes 3 × 40 lifecycle cycles, multi-tab, watch, Job/exit UI, full
configuration create/rename/delete with unsaved buffers, and three installed-vtsls
renames. The unchanged native implementation retains its preceding 263 Rust UX
test result; Rust tests were not rerun for this Lua-only change. Three Git-writing
Lua suites and cross-platform/cross-volume runtime remain outside this run.

Evidence is under
`/var/folders/46/g_pc2kcd0png2zh_xr46wwp00000gp/T/explorer-viewport-Z8A0Tl/`:
`before/`, `before-inputs.json`, `candidate-inputs.json`, `browse-candidate/`,
`paired-tree-final/`, `paired-list-final/`, `destination-summary.json`, `lua-final/`,
`node-final.stdout`, `acceptance/` and `validation.json`. Diagnostic and pilot
directories remain separate. The accepted Lua runtime fingerprint is
`2d00d0e764c2bb9ef45bd9696c2a65b4542a742c4ba1aa0a7a40b38966dcb7a2`.

## 2026-10-06 file-job result capacity acceptance

Baseline `8e3a149ce` includes viewport preparation and its failure recovery. The
earlier release audit copied only 25,634 of 50,000 four-byte files before reporting
`ResourceLimit: copy staging and results exceed task capacity`. The published
prefix was valid, but complete per-file paths and result objects exhausted the
32 MiB task budget before the directory could be compacted. That count depends on
path lengths and directory shape; it is not a public item limit.

Successful results now retain NodeId, basename and shared execution-time parent
paths. The immutable compact records are reference-counted; querying a page shares
them, and the Lua binding constructs one item's output paths at a time. Errors,
skips, synchronization errors and physical paths retain their required details.
Ownership-based reservations release shared paths only after their final result
reference, including caller-held pages. The task budget remains 32 MiB; no new
native retained-budget reservation or expanded result record is required to read
a valid result page under memory pressure. See the [Filetree contract](../../../spec/design/filetree.md).

Five opt-in release tests ran serially on the existing macOS host. Each used a real
Treeview selection task and checked disk contents, source preservation, paged
results, selection cleanup, task unlock, staging removal and result reclamation.
The matrix has one diagnostic execution per case, no attached UI and 5 ms memory
observation. It establishes capacity and integrity, not throughput or p95 latency.

| Case | Source files | Copied files | Terminal result |
| ---- | -----------: | -----------: | --------------- |
| Flat directory | 50,000 | 50,000 | Complete; one successful directory result |
| Existing-directory merge | 10,000 | 10,000 | Complete |
| Nested directories with long ancestors | 10,000 | 10,000 | Complete |
| Cancel after at least 10k files | 50,000 | 10,000 | Cancelled; committed files remain queryable and are unselected |
| Flat-directory pressure | 100,000 | 0 | ResourceLimit before copy IO; source and selection preserved |

The 100k case is **not** a successful copy: the existing, separate scan budget
reports `Filetree scan staging capacity exceeded` while loading the source into
the browse model. No output is published. This remains a reason to evaluate
decoupling task traversal from browse Source; result compaction does not remove
that limit. The successful 50k case sampled about 108 MiB of data-wide native
retained memory at its peak. This includes Source and in-flight work; it is not
the 32 MiB task ledger or process RSS, and sampling can miss shorter peaks.

Validation passed 269 ordinary Rust UX tests, the five opt-in capacity cases and
35 Lua suites / 373 cases. Unit coverage includes 100k compact results with long
shared prefixes, caller-held result lifetimes, raw byte names, complete issue
details, fixed historical paths after both parents move, and terminal first/middle/
final pages while the data budget is exhausted. Release acceptance also passed one
Job UI run (nine scenarios), one full-config run with 120 cursor moves, and one
installed-vtsls rename. Formatting and diff checks passed. Cross-volume and other
platform runtime, the three Git-writing Lua suites and a new throughput comparison
are outside this acceptance.

Reproduce the opt-in matrix without concurrent build/test load:

```sh
cargo test --manifest-path rust/Cargo.toml --offline -p yoz --release --lib \
  ux::filetree::jobs::staged::tests:: -- --ignored --nocapture --test-threads=1
```

Evidence is under `/tmp/explorer-goal-jPLeqT/`: `phase2-capacity-v2.log`,
`phase2-rust-ux-v2.log`, `phase2-jobs-v2.log`, `phase2-lua/`,
`phase2-acceptance/` and `phase2-native-inputs.json`. That acceptance used
native source SHA-256
`d44391a284f889e289e11b2d2835d7ab8fded44db590d3373ac9fda330b01686`
and library SHA-256
`fde64334254231f696e2b748bee42857f3d576cd1f031c2d2a210894fe22b43a`.
The receipt verified that source and artifact before measurement.

## 2026-10-07 settled-scan and worker-retirement acceptance

The final comparison used Apple M1 Pro / 32 GiB, Darwin 27.0.0, Neovim 0.12.5
Release and LuaJIT 2.1.1788856981. Legacy is checkout `00ccccfd396d9249176d456afbbb5ababa360dd3`
under `~/.config/nvim`, with a separate offline build verified against its sources.
Native is the frozen `phase3-v4-inputs.json` snapshot above `23e7a7bfd`.
Five fresh processes per case/implementation/mode ran serially in alternating
A/B order, with one complete operation sequence per process (`--repeats 1`).
All 115 comparable process records and the separate five-process-per-side idle
probe passed. Filesystem and plugin caches were warm. Tree is the common comparison;
List is native-only. Values below are process medians in milliseconds unless noted.
Five processes do not establish p95 or a worst-case latency bound; raw ranges and
the slowest individual observations remain in the report.

Completion now distinguishes the refresh Future's acceptance, settled native
browse work, applicable frame/preparation and matching redraw. Settled includes
the owner's complete execution cycle, dirty demand and queued/running page work,
including cancelled work awaiting retirement. IO errors still require checking.
A real permission-failure injection retained the same six List rows and an
applicable frame; the benchmark rejected the failed branch scan instead of
recording success. All timed comparable operations issued zero readiness RPCs;
all 150 native open/refresh/reopen observations satisfied accepted <= scan <= ready.

This boundary also exposed a real 50k reopen failure: a cancelled worker could
retain its Scan while a replacement started against the same 32 MiB staging
budget. Reader now retains that slot through worker exit and reclaims its cached
Scan before admitting a different work ID for the same node. Same-work pages
also wait for the previous closure to finish. An unexecuted, rejected closure
resets its running state without waking the owner, preserving the existing retry
backoff; executed work wakes the owner on exit. No Lua polling loop was added.
The old release failed the focused reopen probe on cycle 2. The final release
passed all 30 cycles, and then all five 50k Tree and five List comparison processes.

| Common Tree fixture | Open legacy | Open native | Refresh legacy | Refresh native | Reopen legacy | Reopen native |
| ------------------- | ----------: | ----------: | -------------: | -------------: | ------------: | ------------: |
| Mixed 200           |       27.63 |       14.33 |          19.09 |           9.80 |         16.71 |          7.33 |
| Flat 1,000          |       88.98 |       29.95 |          99.22 |           9.53 |         84.10 |         18.46 |
| Flat 10,000         |      824.21 |      193.33 |       1,383.32 |          59.97 |      1,209.37 |        103.34 |
| 9k + 1k branch      |      757.23 |      173.19 |       1,429.31 |          68.26 |      1,255.88 |        114.14 |
| Flat 50,000         |    4,335.85 |    1,728.70 |      14,902.29 |         339.35 |     14,006.36 |        387.06 |

These are complete ready boundaries. The branch fixture opens with 9,001 rows and
is expanded to 10,001 for later operations. Cold/warm expansion and collapse were
1,125.99/1,138.35/1,139.81 legacy versus 14.50/17.19/6.37 native. At 50k,
native refresh acceptance/scan/ready were 4.63/338.75/339.35. First open UI flush
was 4,336.27 legacy versus 18.21 native. Cached reopen UI flush was 14,006.80
versus 35.51; it does not mean the native refresh finished in 35.51 ms.
Native List's 50k complete open/refresh/reopen were 1,699.41/335.04/383.21.

Interaction and memory retain meaningful tradeoffs. At 1k, native cursor/scroll
visible medians were 0.33/1.07 versus legacy 0.24/0.56. At 50k they were
0.32/1.13 versus 2.24/2.46. Published single/100-row Visual selection at 50k
was 5.79/13.02 native versus 13,882.13/13,861.14 legacy; selection ready is not
a UI-flush metric. Final 50k Tree process footprint after full GC was 177.17 MiB
native versus 645.72 MiB legacy; native List was 177.11 MiB. These are libuv
physical-footprint measurements, not retained-budget totals or RSS.

| Copy fixture | Job legacy | Job native | Ready legacy | Ready native | Max tick gap legacy | Max tick gap native |
| ------------ | ---------: | ---------: | -----------: | -----------: | ------------------: | ------------------: |
| 64 MiB file  |      98.98 |      54.66 |       100.42 |        59.92 |               99.55 |                3.06 |
| 1k x 4 bytes |     496.84 |     601.60 |       502.98 |       603.93 |              501.47 |                4.00 |
| 10k x 4 bytes |   4,723.64 |   6,251.83 |     4,784.25 |     6,253.99 |            4,782.58 |                4.42 |

The last two columns are medians of each process's maximum scheduled-timer gap.
All file names and contents were verified after timing. Native small-file Job
time was about 21%/32% higher at 1k/10k, despite much lower main-thread occupancy:
18.07/127.44 ms versus legacy 213.64/2,295.16 ms through ready. Total process CPU
was also higher for those copies, 292.79/3,179.76 versus 215.28/2,312.61 ms.
Responsiveness and throughput therefore need separate conclusions. Individual
samples varied: 10k Job time ranged from 4,590.07 to 13,780.51 legacy and
6,159.85 to 8,447.74 native. The native 64 MiB ready maximum was 175.55 ms
despite its lower median, so this dataset does not establish a universal tail win.

Full-configuration startup to first Explorer UI flush was effectively equal:
319.04 legacy versus 319.22 native. Configuration-ready medians were
251.99/215.85; the first Explorer's own visible interval was 67.02/103.33 and
its ready interval 95.61/103.53. Startup varied widely across processes and uses
each checkout's own configuration/plugins; it does not isolate Explorer cost.
Idle visible/hidden/disposed CPU medians were 0.0120%/0.0107%/0.0149% of one core
legacy and 0.0095%/0.0115%/0.0184% native, with zero redraw notifications in every
sample. The 200-file visible idle footprint was 9.02 versus 11.09 MiB, so native
also retains a small fixed memory cost despite its lower large-directory footprint.

The result supports substantial gains in large-directory browsing, selection,
memory and responsiveness, but not superiority on every axis. The preceding
100k copy capacity failure remained at this checkpoint: task traversal still needed
the browse Source scan, whose separate 32 MiB staging limit could fail before copy IO.
The follow-up contract is now documented in
[Filetree private traversal](../../../spec/design/filetree.md#job-私有遍历); the historical
measurements in this section predate that implementation. Traversal, IO validation
and publication costs still need separate profiling before assigning the entire
small-file throughput difference to Source coupling.

Final verification passed 274 ordinary Rust UX tests (20 opt-in cases ignored),
35 Lua suites / 373 cases, the 16 unchanged Node report/provenance tests, and the
30-cycle reopen probe. Deterministic regressions cover owner publication after an
accepted layout action, move-blocked refresh, failed/unavailable roots, retained
cancelled workers, the retention/admission handoff and rejected-work backoff.
The current release also passed one expanded-copy A/B run and one process each
for navigation, watch, Job activity, recursive root watch, 40-cycle soak,
full-config actions, Job/exit UI and installed-vtsls rename. The three Git-writing
Lua suites, `git_1000`, cross-volume and other-platform runtime were not run.

Evidence is under `/tmp/explorer-goal-jPLeqT/`: `phase3-comparison-v3/` contains the
accepted raw records, metadata, summary and report; `phase3-v4-acceptance/`,
`phase3-v4-lua/`, `phase3-rust-ux-v4.log`, `phase3-v4-reopen.json`,
`phase3-branch-error.lua`/`.json`, `phase3-retirement-before.log`,
`phase3-retirement-races-before.log` and `phase3-v4-native-inputs.json` retain the
validation and failure evidence. Earlier pilots, the interrupted comparison and
the failed `phase3-comparison-v2/` are not pooled with the final dataset.
The accepted native source SHA-256 is
`3dbf41e9f8448532b945a6ef3431fbe26dcc88b2b2e8edb848aa6f6b2ce08122`,
and the installed release library SHA-256 is
`e44e30283c6a92df89b075c4e712c11f374996a14cec261ee492413ff0849c1d`.
Both checkouts' measured native artifacts and runtime contents are fingerprinted
in the comparison metadata. Existing Neovim processes need a restart to load the
native retirement fix.

## 2026-10-07 small-file source prefetch acceptance

The opt-in stage probes identified source opening and target creation as the main
serial costs. Across five independent before processes, the 1k instrumented runs
had median source-read/open-call/create-call times of 11.38/345.78/199.07 ms;
transfer exclusive time was 25.95 ms. Each process contributes the median of its
three instrumented Jobs. Browse Source loading therefore does not explain most
of this small-file throughput gap, although it still limits large-copy capacity.

On macOS/Linux, directory staging now prefetches at most four consecutive regular
source files up to 64 KiB through the existing IO workers. Destination writes keep
the serial process-wide executor. Open descriptors carry the captured identity;
consumption revalidates the pathname, and parent/publication checks remain intact.
Reservations follow descriptor ownership and count against the unchanged task and
data budgets. Required-allocation pressure retires that Job's prefetch before a
synchronous retry. fd pressure disables process-wide prefetch, retires unconsumed
descriptors across Jobs and retries only the failed fd allocation once. A writer's
taken descriptor stays owned by that writer. Queued callbacks retain only Weak
pointers and can be cancelled without waiting for an available IO worker; retirement
waits only for running raw opens. Directory boundaries, early returns and Job
completion retire prefetch. fd-pressure fallback lasts until process restart.

The native Rust before/after comparison ran five alternating process pairs, six
Jobs per process, with complete content and selection-cleanup assertions. Taking
each process's three uninstrumented Job medians, then the cross-process median,
1k elapsed time fell from 691.03 to 332.49 ms (51.9%); all five pairs improved.
After prefetch, median serial source wait was 33.45 ms. Accumulated parallel
open-call time was 560.53 ms and overlaps Job wall time; it is not an additive cost.
The final 10k diagnostic also passed all six Jobs, retaining 10,010 Source nodes.
Its three uninstrumented Jobs had a 3,834.45 ms median within one process; this
diagnostic is separate from the independent-process Explorer measurements below.

The real Explorer comparison used legacy `00ccccfd3` and native inputs based on
`67c6a9b46`, Apple M1 Pro / 32 GiB, Darwin 27.0.0 and Neovim 0.12.5 Release.
Each case has five fresh processes per side in alternating order, warm filesystem
caches and no concurrent tests/builds. Both native receipts were verified, runtime
inputs stayed unchanged, every copied file was verified, and all timed observer
RPC counts were zero. These are independent-process medians, not p95:

| Copy fixture  | Job legacy ms | Job native ms | Ready legacy ms | Ready native ms |
| ------------- | ------------: | ------------: | --------------: | --------------: |
| 1k x 4 bytes  |       1023.47 |        567.22 |         1039.70 |          568.43 |
| 10k x 4 bytes |      12641.62 |       5120.93 |        12716.48 |         5123.06 |
| 64 MiB file   |        101.71 |         54.45 |          104.57 |           63.03 |

Native Job time improved in all five pairs for each case.
Legacy 10k Job time ranged from 6,478.00 to 20,400.22 ms; native ranged from
3,981.49 to 8,117.52 ms. The large legacy variation and five-process count limit
tail claims. The 64 MiB file does not use this prefetch path; its comparison is
not evidence of a prefetch gain. Its native ready maximum was 169.41 ms, and
ready improved in only 4/5 pairs despite faster Job completion in all five.

Total CPU remains a mixed result, and final copy footprint still favors legacy.
The 1k/10k Job CPU medians were 278.11/4,223.13 ms legacy versus 388.76/3,710.21 ms
native; main-thread CPU was 276.27/4,190.34 versus 24.09/163.41 ms. Native 1k CPU
was higher in 4/5 pairs. The 10k CPU median was lower in this matrix, but legacy
ranged from 2,898.92 to 4,989.46 ms and one pair favored legacy. Final post-GC
footprint was 11.66/32.66 MiB legacy versus 13.63/47.64 MiB native. These are
whole-process snapshots, not peak memory or sums of retained counters. Throughput
and main-thread occupancy have improved; uniform CPU/memory superiority is not
established. Job traversal still populates the browse Source; the prior 100k scan
capacity failure is unresolved by this change.

Validation passed 289 Rust UX tests (22 opt-in cases ignored), including identity,
cancellation, tight task/data budgets and queue-admission regressions. fd-pressure
cases run in isolated processes under a reduced soft limit: a single staged copy
has only three slots left, and a second real Job has no free slots until it reclaims
the first Job's prefetched descriptors. Concurrent regressions cover four occupied
IO workers reclaiming queued reads, take/reclaim ownership and registration racing
with process disable. A subsequent lifecycle regression reproduced 1,550 bytes
still charged after cancellation while a coordination reference survived. Queued
payloads now belong to the cancellable state slot; the final version passed all
172 Filetree tests (15 opt-in cases ignored), including immediate mandatory-memory
admission while worker/coordinator handles remain alive. Earlier unchanged Treeview
coverage remains applicable. Lua passed 37 suites / 390 cases; the final release
passed six Filetree Job cases, three progress cases and all nine real Job UI scenarios.

The 4 KiB, 64 KiB and outside-tree variants each passed one legacy/native pair.
The first expanded-source native attempt was rejected with `selection revision
changed` while acquiring the selection lock, before a native Job or prefetch ran.
That failed attempt remains in the evidence; three subsequent expanded-source pairs
passed full content verification without code changes or relaxing the version check.
Variant checks establish exercised correctness, not stable performance. Formatting
and diff checks passed. Git-writing suites, `git_1000`, cross-volume and other-platform
runtime were not run; Linux prefetch has not been runtime-tested.

Evidence is under `/tmp/explorer-next-7w7udg0c/`: `copy-paired-c4-1000/`,
`prefetch-c4-comparison/`, `prefetch-c4-variants/`, `prefetch-c4-expanded-recheck/`,
`prefetch-c4-profile-10000.log`, `prefetch-c3-ux.log`, `prefetch-c4-red.log`,
`prefetch-c4-green.log`, `prefetch-c4-filetree-tests.log`, `prefetch-c3-lua/`,
`prefetch-c4-jobs-ui.stdout`, `prefetch-c4-filetree-lua.stdout`,
`prefetch-c4-progress-lua.stdout` and `prefetch-c4-native-inputs.json`. Earlier
prefetch matrices, exploratory clone/openat variants and interrupted profiling
pilots are separate and are not pooled with these results. The accepted native
source SHA-256 is
`65896e9be56fb40fde22f5d617f157d3174f47c5b55bf4455d5728a515950212`,
and the installed release library SHA-256 is
`574549b66dc300f2775d1db97a8339835a21245dcca106332f3f0e11a1949d10`.

## 2026-10-07 private Job traversal measurements

Jobs now enumerate their own bounded filesystem cursors. Copy descendants can retain
Job item IDs and execution paths without browse NodeIds; a partial successful frontier
is admitted only when selection cleanup needs it. Target descendants stay lazy unless
already known or needed by browsing. Source identity, read-scope restrictions and
selection cleanup remain separate checks. The task limit is still 32 MiB, shared by
results, captured identities, cursors, journal, prefetch and admission scratch.

The measurements below use the `traversal-v4` build. The final `traversal-v5` build
also corrects cursor lookup after concurrent browsing; its validation follows this
matrix. Results from the two builds remain separate.

The native-only Rust comparison uses the accepted source-prefetch version as its
before binary and the private-traversal version as after. Five alternating process
pairs each run six verified Jobs; only each process's three uninstrumented Jobs enter
the elapsed comparison. The 1k median of process medians is **327.46 → 298.19 ms**
(8.9% lower), with 4/5 pairs improving. Process medians range from 312.66–407.35 ms
before and 273.05–401.80 ms after. Every before Job retains 1,010 Source nodes; every
after Job retains 10. This does not imply that traversal accounted for most copy time,
or that every individual run improves. Instrumented spans remain diagnostic.

The real Explorer comparison uses legacy `00ccccfd3` and native inputs based on
`a7d94c57c`, Apple M1 Pro / 32 GiB, Darwin 27.0.0 and Neovim 0.12.5 Release.
Both libraries have verified source receipts. Each size has five fresh processes per
side in alternating order, warm filesystem caches, no concurrent tests/builds, complete
source/target content verification and zero timed readiness RPCs. These are process
medians, not p95:

| Copy fixture  | Job legacy ms | Job native ms | Ready legacy ms | Ready native ms |
| ------------- | ------------: | ------------: | --------------: | --------------: |
| 1k x 4 bytes  |       3260.04 |       3681.62 |         3269.51 |         3687.37 |
| 10k x 4 bytes |       9313.74 |       3312.89 |         9379.45 |         3315.16 |

The 10k Job is faster in all five pairs. The 1k Job improves in only 2/5 pairs and its
median is higher in this run. Variation is substantial: 1k legacy/native ranges are
766.05–4,511.66 / 373.08–4,982.62 ms; 10k ranges are
4,022.01–17,109.25 / 3,112.31–6,448.07 ms. The native-only comparison above isolates
the implementation change better, but neither dataset establishes universal throughput
or tail superiority. These observations are retained without pooling earlier matrices.

Job CPU remains higher for native: 366.13/664.90 ms at 1k and 2,594.11/3,300.71 ms at
10k, legacy/native respectively. Main-thread Job CPU is 363.33/109.00 and
2,573.73/88.58 ms. Final post-GC physical footprint is **11.61/10.56 MiB** at 1k and
**32.67/12.66 MiB** at 10k. These are final whole-process snapshots, not peak memory or
sums of retained counters. The median maximum scheduled-timer gap is
3,267.74/7.51 ms at 1k and 9,377.50/6.99 ms at 10k; timer gaps are distinct from actual
input-to-flush measurements.

The new active-loading acceptance uses a 50k directory, three fresh native processes
for each widget mode, and separate cold expansion/warm refresh phases. Every cursor
publication occurs while the directory still reports Loading; typed Tree collapse or
List-to-Tree switching retires accepted scan work, and reopening loads all 50k entries.
All 12 phase records pass, with zero timed readiness RPCs:

| Mode | Phase | Cursor flush median ms | Cursor flush max ms | Scan retirement median ms |
| ---- | ----- | ---------------------: | ------------------: | ------------------------: |
| Tree | Cold  |                  0.393 |               0.448 |                     5.154 |
| Tree | Warm  |                  0.329 |               0.454 |                   354.307 |
| List | Cold  |                  0.365 |               0.454 |                     4.588 |
| List | Warm  |                  0.323 |               0.528 |                   360.666 |

The warm retirement maximum is 397.84 ms. Background scan retirement and visible
collapse are different boundaries; this result does not claim immediate cancellation
of blocking syscalls or zero retirement cost. Three samples do not establish p95 or
compare against legacy. A separate 10k smoke run preceded this matrix and is not pooled.

The v4 release test binary passes seven opt-in capacity cases, once each, without
concurrent tests, builds or measurements. Job time includes selection cleanup but
excludes fixture construction and terminal content verification. These native-only
cases have no UI and sample retained memory every 5 ms; they are capacity checks,
not independent-process throughput distributions or exact peak-memory measurements:

| Scenario              | Source files | Copied | Job seconds | Sampled task peak MiB | Final Source nodes |
| --------------------- | -----------: | -----: | ----------: | --------------------: | -----------------: |
| Unloaded source       |       100000 | 100000 |       47.49 |                 25.28 |                 10 |
| Already loaded source |        50000 |  50000 |       22.20 |                 12.73 |              50010 |
| Already loaded source |       100000 | 100000 |       51.12 |                 25.29 |             100010 |
| Decline last conflict |       100000 |  99999 |      261.38 |                 19.04 |             100009 |
| Merge directory       |        10000 |  10000 |       15.64 |                  1.88 |                 10 |
| Cancel after 40k bytes |        50000 |  10006 |        9.71 |                  2.68 |              10016 |
| Nested long paths     |        10000 |  10000 |       10.31 |                  1.23 |                 34 |

Every case keeps the 32 MiB task limit and passes complete source/target content,
selection cleanup, unlock, result synchronization and held-page lifetime checks.
After the Job is dropped, a retained result page remains readable and charged;
dropping the last page brings that task ledger to zero. Declining the final conflict
preserves the existing target and clears the successful frontier while retaining
the skipped source and ancestor self-selection, with 100,001 result records.
Cancellation is an expected terminal failure and retains
the successful frontier. Partial cleanup can materialize that frontier, as the
Source counts show; complete copies do not need to materialize their descendants.
Task accounting is not process memory: the shared data ledger, which includes task
charges, samples 210.84 MiB in the 100k partial case.

The loaded cases construct Source entries from real filesystem metadata, without
going through browse Scan. They validate already-loaded Job inputs, not 100k browse
Scan capacity. The earlier v2 partial100k attempt was cancelled by its 300-second
test watchdog after copying 91,500 items; it did not hit the memory limit. That
failure remains separate. Only this 100k partial test's watchdog is now 900 seconds;
the final run finishes in 261.38 seconds. Extending a test deadline is not a
throughput improvement, and no production memory budget was raised.

The v4 dedicated Rust runs pass 113 Treeview tests (7 opt-in ignored) and
183 Filetree tests (18 opt-in ignored), including the identity, admission budget,
read-scope and partial-cleanup regressions. Lua passes 35 suites / 276 cases,
including stable Job item IDs, optional NodeIds and historical result behavior;
the Node benchmark/report tests pass all 12 cases. Rust/Lua formatting, annotation
alignment and diff checks pass. That release also passes all nine real
Job UI scenarios in two fresh processes, including typed and scripted exits during
copy, acknowledged cancellation and an empty Job registry.

The outside-target variant passes one legacy/native pair. The first expanded-source
native attempt is rejected with `selection revision changed` while acquiring the
selection lock, before Task creation or native Job execution. The same stack and
harness occurred in the accepted source-prefetch stage. Three fixed alternating
expanded-source pairs then pass full content verification without code changes or
relaxing the version check. The initial failure remains recorded; these rechecks
do not prove that this existing preparation race is absent or its frequency unchanged.
Variant checks are separate from the formal timing matrix above.

An earlier v2 release UX run also retains a watch-timing failure at the existing
`elapsed >= 130 ms` assertion (299 passed / 1 failed). Four alternating baseline/v2
pairs each produce three passes and one failure; the latest dedicated debug modules
pass. This is not reported as a complete final release UX pass, and the watch
implementation was not changed. Cross-volume, Linux/Windows runtime, `git_1000`
and the three Git-writing Lua suites remain untested here. All reported runtime
validation is on aarch64-apple-darwin.

Evidence is under `/tmp/explorer-next-7w7udg0c/`: `traversal-paired-v4-1000/`,
`traversal-v4-comparison/`, `traversal-v4-active-loading/` and
`traversal-v4-native-inputs.json`; capacity results are in
`traversal-v4-capacity-summary.json` and its seven named logs. Validation and failure
records are in `traversal-c5-treeview.log`, `traversal-c5-filetree.log`,
`traversal-v4-lua/`, `traversal-bench-node.log`, `traversal-v4-variants/`,
`traversal-v4-expanded-recheck/`, `traversal-v4-jobs-ui/`,
`traversal-v2-partial_100k.log`, `traversal-v2-ux_regression.log` and
`traversal-watch-paired.json`. The source SHA-256 is
`840836a0b1a014805423b95a506c5e8a28f96541206f2428863269ea5ada39c9`, the release test
binary SHA-256 is `4a405a76749f07f1f88410fcaf4bc5ed8b0defbb2a26c6ad8718c8dfe0d5db69`,
and the v4 release library SHA-256 is
`05387bcb0b5a6a7c5655659bd102f8806d0526952385e81b3f2b094504e74271`.
The exact v4 native sources and release/debug libraries are preserved under
`traversal-v4-preserved/`; all 218 source hashes and both library hashes match their
original records.

The final v5 build resolves a Source-version mismatch in the traversal shared by
recursive Delete and EXDEV directory Move. A directory bound after browse pages
arrive can have a newer Source than the Job's initial snapshot. Cursor name lookup,
known-member counts, completeness and seen positions now use that captured Source;
the separate Job-start Index snapshot is removed. Discovery eligibility, filesystem
identity checks and memory limits remain unchanged.

Two deterministic real-Delete regressions hold execution until the Job is claimed,
then publish legitimate browse pages for a previously unloaded subtree. Complete
and Partial pages respectively reproduced false `gained a member` and `members
disappeared` errors. Both now pass in debug and release, including deletion, selection
cleanup and unlock. The final Filetree module run passes **185 tests / 18 opt-in
ignored**; the rebuilt libraries also pass all seven Lua Filetree Job cases, two
expanded-source legacy/native pairs with complete content verification, and all
18 real Job UI scenarios in two fresh processes. The earlier preparation race
remains recorded despite these successful checks. Unchanged Treeview, Lua consumer
and benchmark code retain the applicable v4 coverage above.

The final release repeats the loaded-100k capacity case through every assertion and
fixture cleanup: **100,000 copied, 59.508 seconds Job time, 26,519,284 bytes sampled
task peak (25.29 MiB), 100,010 Source nodes**, with the same 33,554,432-byte task cap.
Held pages remain valid after Job release and the final task charge drops to zero.
This is one capacity recheck, separate from the v4 timing matrix; its 442.78-second
whole-process duration also includes fixture creation, content checks and cleanup.

Final correction evidence is in `traversal-c6-red.log`, `traversal-c6-green-v2.log`,
`traversal-c6-filetree.log`, `traversal-v5-validation-summary.json`,
`traversal-v5-loaded_100k.log`, `traversal-v5-release_c6.log`,
`traversal-v5-lua_jobs.log`, `traversal-v5-ui/` and `traversal-v5-native-inputs.json`.
The final source SHA-256 is
`969523ff2e234c5e7c3af11862c2585bf7bb2ee246e5ecd04eb7538d377f95bd`, and the installed
release library SHA-256 is
`15126ff23626af1b3b60745eeb28bb3c0eb67f620c9fc14d90b917fcb48d6fd9`.


## 2026-10-07 compact browse scan acceptance

The browse scanner now pins one alignment Source and retains compact NodeId and
identity ordinals, observed/consumed flags and an ordered set of active bitmap
words. Unchanged members keep their Source names, payloads and sibling ordering;
only newly inserted or reordered entries enter the sparse ordering delta.
Identity grouping and complete observation still decide ambiguous hardlinks and
renames. Deferred/carry observations retain their own reservation and acquire
page-output space when consumed. The deferred queue admits capacity growth before
allocation and retains its backing-storage charge until Scan drops, even after
pages consume every entry. Scan reservations use one scalar ledger instead
of allocating a Charge object for each accounting addition. The shared scan
staging cap remains 32 MiB, with 512-item / 1-MiB pages and the same data limits.

The release probes are opt-in and use real filesystem entries. Each process
constructs a fresh Source for a cold scan and a fully loaded warm scan. The same
probe was compiled against baseline `3a9f88688` and the new implementation; the
baseline production source archive and both executables are retained. Run without
other tests or builds:

```sh
cargo test --offline --release --manifest-path rust/Cargo.toml -p yoz --lib \
  t_scan_stages_ -- --ignored --nocapture --test-threads=1
```

Apple M1 Pro / 32 GiB, Neovim 0.12.5 Release, Rust 1.99.0. There are three fresh
process pairs for 1k and 10k, alternating A/B then B/A. Times below are medians of
each process's initialization + scan/IO + owner application + scan destruction;
fixture construction and terminal assertions are excluded. Staging values are
maximum observations at page boundaries, not an exact transient peak or RSS.
These probes have no UI, projection or p95 claim.

| Direct files | Phase | Before ms | After ms | Before staging MiB | After staging MiB |
| -----------: | :---- | --------: | -------: | -----------------: | ----------------: |
|         1000 | Cold  |      8.57 |     7.96 |              0.953 |             0.893 |
|         1000 | Warm  |      6.13 |     4.75 |              1.173 |             0.698 |
|        10000 | Cold  |    105.40 |   100.65 |              3.971 |             3.378 |
|        10000 | Warm  |     76.91 |    59.35 |              6.223 |             1.197 |

The 10k warm initialization median is 5.844 → 1.079 ms. Its final scan-container
release is 0.943 → 0.033 ms; this is not the full background cancellation/retirement
boundary measured by the active-loading driver.

A separate single 100k capacity pair passes both cold and fully loaded warm scans
after the change, including complete membership, ordering and warm NodeId equality.
Before: cold scanning returns ResourceLimit after 178 committed pages; warm scanning
returns ResourceLimit during initialization before its first page. After: both
complete in 196 pages, taking 2558.31 / 907.79 ms with boundary-observed staging
28.815 / 6.186 MiB (cold / warm). A held final page keeps its reservation, and the
last scan/page release returns the staging ledger to zero. This establishes the
short-name fixture's scan capacity, not an unlimited directory size or a 100k UI
latency distribution. Large change sets and long names still share the fixed cap.

The deterministic tests include the original 100k-cache ResourceLimit regression,
initialization cancellation, deferred backing-storage ownership during and after
page consumption, and cross-page renames mixed with recreated old names,
new directories and ambiguous hardlinks. Every committed page retains Filetree
ordering and successful unique renames retain their original NodeIds.

The legacy UI comparison uses checkout `00ccccfd396d9249176d456afbbb5ababa360dd3`
and a verified release build receipt on both sides. Five cases × three processes
cover legacy/native Tree and native List (45 records). These v2 measurements
precede the final deferred-capacity accounting correction; none of these unchanged
fixtures takes that deferred path. Final-source acceptance is recorded separately
below, without pooling samples across native fingerprints.

| Tree case | Legacy ready ms | Native ready ms | Legacy refresh ms | Native refresh ms |
| :-------- | --------------: | --------------: | ----------------: | ----------------: |
| mixed 200 |          30.328 |          14.845 |            20.053 |             9.982 |
| flat 1k   |          94.915 |          29.330 |           105.094 |            10.198 |
| flat 10k  |         875.174 |         259.038 |          1453.124 |            62.033 |
| branch 10k |        784.903 |         238.735 |          1503.043 |            60.018 |
| flat 50k  |        4393.667 |        2066.040 |         15035.019 |           324.016 |

At 50k, Tree's first flush is 4394.114 → 17.727 ms and final physical footprint is
639.861 → 172.360 MiB. This does not establish universal superiority: at mixed 200,
cursor flush is 0.214 → 0.337 ms, scroll flush 0.630 → 1.472 ms and open footprint
8.985 → 10.454 MiB. At 1k, open footprint is 13.626 → 14.501 MiB. These are three-
process medians, with modules preloaded and Git/LSP collection disabled, not p95 or
full-configuration latency claims.

Lua validation exposed a separate pre-existing conservative Task guard: while 520
selected leaves are being prepared, their parent's warm refresh can publish
Complete → Partial and invalidate the task before IO. A captured source trace
shows Ready followed by this transition and a zero-result Stale. A forced refresh
after Ready reproduces the same rejection with both baseline and v2 release
libraries, retaining all source files and creating no targets. The ordinary and editor issue-history
limit specs now detach their views and wait for watch teardown/native idle before
the operation, then reopen the views for the results menu. Task guards and IO retry
semantics are unchanged; arbitrary concurrent refresh is not claimed to always
permit an operation to proceed.

Final v3 release acceptance uses a verified receipt for native input
`63bf34ab50d35c758560e69f0662eefa67aabf7bce1fe0b1fd5dac61b56c228a`.
Three fresh processes per mode pass mixed 200 and flat 50k. The 50k Tree/List
ready medians are 1923.098 / 2022.978 ms, refresh 290.393 / 315.097 ms and first
flush 17.552 / 17.541 ms. Three-process navigation/root recovery and full-config
Jobs/exit acceptance also pass.

The final active-loading cases pass typed input, cancellation and complete reopening
in all three processes per scenario. Warm Tree/List input-visible medians are
0.369 / 0.295 ms and cancel-visible 29.718 / 8.040 ms. Full background retirement
still takes 290.107 / 276.884 ms (observed maxima 297.439 / 284.609 ms). The compact
Scan's destruction time does not eliminate this broader owner/Source cleanup cost.

Final validation: Filetree 189 passed / 21 ignored, Explorer native 16 passed,
and 36 safe Lua suites / 277 cases passed. Both history-limit suites also pass
five additional fresh-process runs each. The Git-writing Explorer runtime/view
and Filetree Git suites, and the `git_1000` benchmark, remain excluded. These
results cover macOS and the declared fixtures; there is no new all-platform or
universal feature/performance parity claim.

Evidence: `/tmp/explorer-scan-move-RxhVxP/`, including `baseline-inputs.json`,
`before-tests`, `after-tests-v3`, `scan-comparison-v3.json`, `scan-summary-v3.json`,
`scan-wide-red.log`, `deferred-capacity-red.log`, `filetree-v3.log`,
`editor-trace-v2-3.log`, `editor-refresh-guard-before.log`,
`editor-refresh-guard-after.log`, `lua-v3-summary.json`,
`ui-comparison-verified-v2/` and `ui-acceptance-v3/`. The earlier
`ui-comparison-v2/` pilot used an as-installed legacy library without a verified
receipt and is excluded from the comparison above.

## 2026-10-07 bulk Move editor preparation

Move preparation now keeps buffer validation read-only. It validates before the
first `workspace/willRenameFiles` request, when a client supports that request,
and always validates again immediately before admitting IO. With no such client,
there is only the final pass. Empty, unloaded, unlisted, unmodified placeholders
are disposed only when needed during successful post-IO synchronization, so the preparation pass
cannot trigger buffer-deletion callbacks and invalidate its own name snapshot.
Disposable names do not constrain IO: an unreadable empty `B/child` placeholder
after a file Move to `B` cannot block source-buffer synchronization or a later Move.
Resolvable source placeholders still follow their source, and exact target-name
placeholders are discarded only when needed. Loaded, listed or modified buffers
retain full protection. Ownership is queried only for conflicting or unreadable
names, avoiding an extra buffer-state pass on the ordinary path.
Physical path matching remains scoped to each synchronous pass; no resolution is
cached across an LSP reply, filesystem IO or another item. Native identity checks,
confirmation, cancellation, unsaved-buffer protection and editor outcomes remain
unchanged.

The standalone driver exercises real per-item Filetree Move, preparation and
result delivery with the release library. It creates only owned temporary files,
opens the requested number of modified buffers (half moving, half unrelated, up
to the number of moved files), and checks every file's contents and every buffer's
final name, modified flag and unsaved text. It detaches the view and waits for
watch teardown before timing; Git collection, rendering and startup are excluded.

```sh
nvim -l __test__/bench/explorer/move.lua 200 200 none
nvim -l __test__/bench/explorer/move.lua 200 200 notify
nvim -l __test__/bench/explorer/move.lua 200 200 async
nvim -l __test__/bench/explorer/move.lua 200 200 none profile
```

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

The A/B baseline is `bc85767d149169c86bb44e635c921eb610d2772a`. Both sides use
the same preserved v3 release library; the baseline Lua/support files are archived
from that commit. Driver, runtime files and artifact hashes are checked before
and after each process. On Apple M1 Pro / 32 GiB and Neovim 0.12.5, each case has
three fresh-process pairs in alternating A/B, B/A, A/B order (30 runs total).
All cases move 200 four-byte files. Values are process medians in milliseconds,
without detailed profiling; three samples do not support p95 claims.

| Buffers | LSP adapter | Before total | After total | Before prepare | After prepare |
| ------: | :---------- | -----------: | ----------: | -------------: | ------------: |
|       0 | none        |       394.04 |      592.21 |          15.18 |         12.83 |
|      40 | none        |      2161.17 |     1497.70 |        1033.49 |        524.17 |
|     200 | none        |      7116.45 |     4993.93 |        4425.31 |       2212.13 |
|     200 | notify      |      7239.33 |     4977.34 |        4402.34 |       2202.25 |
|     200 | async       |      7099.08 |     6961.04 |        4229.29 |       4199.55 |

The 40-buffer/no-client case improves by 30.7%; 200 buffers improve by 29.8%
without clients and 31.2% with the notification-only adapter. The asynchronous
willRename path retains both required checks: total 7099.08 → 6961.04 ms and
preparation 4229.29 → 4199.55 ms are close; no material speedup is claimed there.

The no-buffer case is explicitly not a win: its primary three-process total is
394.04 → 592.21 ms. A separate ten alternating-pair recheck yields 312.26 →
360.49 ms, with before/after ranges 273.18–341.69 / 296.42–428.15 ms. Preparation
medians in that recheck are only 14.69 → 14.13 ms and main CPU 57.58 → 63.40 ms.
These observations retain the slower total rather than asserting a universal
improvement; the buffer-heavy matching benefit does not establish no-buffer
throughput superiority. The recheck is separate from the table above.

A separate instrumented pair with 200 buffers and no client observes 700 → 500
`nvim_list_bufs` calls (including 100 source-buffer renames), 170348 → 112799
`entry_path` calls and 224598 → 167249 `path_suffix` calls. Every item still receives
preparation and synchronization. The ordinary 200-buffer/no-client runs retain
2216.47 → 2207.23 ms of synchronization cost; this change does not remove the
remaining per-item buffer matching cost. Terminal-to-idle medians remain below
0.1 ms, with individual observations up to 11.83 ms. This small tail does not
justify restructuring result delivery in this phase.

Two new placeholder regressions fail before the change and pass afterward. They
assert that preparation leaves a disposable buffer alive without emitting
BufWipeout, both with and without an asynchronous willRename reply. A further
regression reproduces the review-discovered file-over-missing-parent case before
its fix and validates the complete Move, unsaved source buffer, zero editor
issues and a subsequent unrelated Move afterward. Existing round-trip rename,
target collision, LSP-introduced target, alias/Unicode matching, cancellation
and post-IO recovery assertions remain in place. The 26 safe Explorer Lua suites
pass all 196 cases; Git-writing runtime/view suites remain excluded.

Three-process full-configuration Jobs/exit acceptance and three installed-vtsls
renames pass against the final Lua source with the verified native receipt.
Vtsls 0.3.0 supports didRename but not willRename: every run receives one rename
notification and one workspace-edit response, reattaches the source buffer and
preserves unsaved source/dependent buffers. Asynchronous willRename preparation
remains covered by the controlled adapter and Lua regression cases, not by this
server. This phase neither rebuilds nor changes the native module.

Final evidence: `/tmp/explorer-scan-move-RxhVxP/move/v3/`, including
`baseline-inputs.json`, `comparison-inputs.json`, `comparison.json`, `summary.json`,
separate `before-profile.log` / `after-profile.log`, `zero-recheck.json`,
`lua-summary.json` and `integration/`. Its parent directory retains
`prepare-readonly-red.log`, `prepare-readonly-green.log`,
`descendant-placeholder-red.log` and `descendant-placeholder-final.log`.
Early draft-driver and intermediate-source samples are not pooled with these
final-source results.


**Linux optimization validation, 2026-10-08**

The follow-up comparison uses native baseline `13e2442bb`, five fresh processes per
case/mode, three repeats, warm local ext4 on WSL2, and source-bound release modules.
The before and after matrices ran sequentially, not as alternating paired samples.
The final native input is `53bd3f1930d20aa229c53e58c03129f070e68cbd3b0932b61ec510375a8dfbbc`.

| Tree metric, ms | Before | Final |
| --- | ---: | ---: |
| 10k complete open | 206.761 | 141.397 |
| 50k first content flush | 12.218 | 12.909 |
| 50k complete open | 3430.214 | 1581.009 |
| 50k refresh | 388.777 | 283.966 |
| 64 MiB copy Job | 16.917 | 14.459 |
| 10k four-byte files, copy Job | 336.425 | 335.973 |

Bounded larger follow-up scan pages reduce repeated insertion/index work while
the first page stays small. Linux copy uses cancellable sendfile chunks with
offset-preserving buffered fallback. Small-file copy throughput remains similar;
the measurements do not establish universal startup, idle or platform superiority.

The final eleven-case matrix passes Tree/List browsing, loading input/cancellation,
idle, watch churn, five 100-cycle soaks, full-config operations, and Job/exit UI.
Earlier expanded coverage also passes real vtsls integration. Dedicated probes
verify repeated annotation/parent input, 520 prepared leaf copies across an unchanged
refresh, and automatic empty-root removal with cwd pinned to the removed directory.
Linux parent entry watches share the 50-root budget and ignore unrelated siblings.
The formerly conservative ancestor-only completeness invalidation described above
is now narrowed; selected-subtree and ancestor topology guards remain enforced.

Validation: 583 Rust tests passed with 28 explicit ignores,
286 Lua cases across 39 Explorer/UX suites passed, and three cross-volume
Rust cases passed. The symlink capture test forces a full redraw after attaching
its recorder; an ordinary redraw can omit unchanged rows already painted before
recording. Git setup explicitly exposes its ignored fixture, and Job cancellation
uses a 50k-file fixture with a pre-cancel liveness assertion. Windows GNU checking
passes with existing platform unused/dead-code warnings; native Windows/macOS
runtime acceptance was not run here.

Detailed raw results and reproduction commands are preserved locally in
`/tmp/explorer-optimization-20261008/before-matrix/` and
`/tmp/explorer-optimization-20261008/final-matrix/`.
