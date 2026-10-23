# Explorer benchmarks

Benchmarks and acceptance probes for the Explorer and Filetree. The unified runner and its provenance live in
`script/benchmark/`; Lua probes, support and fixtures live under `__test__/`. This file keeps each scenario's method
and latest baseline; earlier measurements remain in its Git history
(`git log -p -- __test__/bench/explorer/README.md`).

## Unified runner

```sh
# Native only, with the installed library.
node script/benchmark/explorer.mjs --processes 3

# A/B against another checkout: build both release libraries, alternate baseline and native processes.
node script/benchmark/explorer.mjs --baseline /path/to/baseline --build --processes 3

# Smoke; repeat --case to select cases.
node script/benchmark/explorer.mjs --processes 1 --iterations 1 --case mixed_200 --case git_1000

# Rebuild the report from a result directory.
node script/benchmark/explorer-report.mjs /absolute/result/directory
```

`--help` lists every option. Defaults are three processes, three iterations within each process, both widget modes,
200 soak cycles and a ten-minute deadline per driver process; large process counts may need a longer `--timeout-ms`.
Copy and startup run once per process. `--native` and `--baseline-native` select preserved libraries, checked
against the sources through their receipts; they exclude `--build`. `--output` must be a new directory outside the checkouts (default: the
system temp directory). A failed case keeps its diagnostics while the remaining cases run; interruption or input
drift stops the matrix. The runner installs nothing and changes neither checkout's Git state: Git writes stay in
disposable fixtures. Run nothing else concurrently.

| Cases                                                                 | Coverage                                                                                       |
| --------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `mixed_200`, `flat_1000`, `flat_10000`, `flat_50000`                  | Open, cursor, scrolling, single/Visual selection, refresh, empty Git notification, hide/reopen |
| `branch_1000_plus_9000`                                               | The same, plus cold/warm expansion and collapse in Tree                                        |
| `startup_200`                                                         | Actual `init.lua`, installed plugins and the first default Explorer                            |
| `git_1000`                                                            | Real status/ignore queries; staged, untracked and ignored entries; changed annotations         |
| `copy_64mib`, `copy_100_files`, `copy_1000_files`, `copy_10000_files` | One dense file, then four-byte files by count, through the actual action                       |
| `copy_1000_4kib`, `copy_1000_64kib`                                   | File size at 1,000 files                                                                       |
| `copy_1000_expanded`, `copy_1000_outside`                             | An expanded source; a destination outside the display root                                     |
| `navigation`                                                          | Typed selection, nested reveal, removed-root recovery and view release                         |
| `active_loading`                                                      | Typed cursor and cancellation while a 50k directory loads cold or refreshes warm               |
| `idle`                                                                | Visible, hidden and disposed idle phases                                                       |
| `watch`, `jobs_activity`                                              | Isolated, continuous and burst watch activity; a 256 MiB sparse-file Job                       |
| `root_watch`                                                          | macOS recursive subscription and an external symlink root                                      |
| `soak`                                                                | Repeated browsing, multi-tab, release and memory                                               |
| `full_config`, `jobs_ui`, `lsp`                                       | Real prompts, Jobs and exit, unsaved buffers, installed-server rename                          |

A/B compares the common Tree cases: the recorded pre-native baseline (`00ccccfd3`) has neither List nor recursive
projection. The remaining cases are native acceptance. The report lists every selected case as passed, failed,
blocked (for example, no installed vtsls), not_applicable (root watch off macOS) or not_run; failed or blocked runs
exit nonzero.

## Provenance and outputs

A build receipt binds the loaded library's SHA-256 to the native sources (`rust/` and `.cargo/`, without
`rust/target/`), the build command and the toolchain; Lua, `init.lua` and lockfile contents form a separate runtime
fingerprint. `--build` compiles each checkout offline (`cargo build --release --locked`, dependencies already cached)
into the result directory and deploys nothing. Without it, a matching receipt is `verified`, a missing one
`unverified`, and a mismatch is rejected. Full-configuration cases also fingerprint the configured plugins' runtime
files. Source, artifact, harness or plugin drift during a run rejects the measurement. These are source-bound local
builds, not hermetic ones.

- `metadata.json`: host, Neovim, commits, fingerprints, receipts, commands, conditions and coverage.
- `results.jsonl`: one record per fresh process, with its repeated operations and memory snapshots.
- `probes/*.json`: acceptance results with their samples, assertions and boundaries.
- `logs/`: driver output, build logs and failure diagnostics.
- `summary.json`, `report.md`: per-process statistics and coverage.

## Measurement boundaries

- **Widget.** The actual Widget in a 110×40 attached UI: a 44-column pane, Rosé Pine main, hidden entries shown,
  compression off. Modules and theme load before timing; Git/LSP collection and plugin startup are excluded. Fixture
  creation and source hashing warm the filesystem caches; A/B and B/A alternate.
- **Endpoints.** `visible_ms` ends when the parent observes the requested content, cursor or selection in a UI flush;
  terminal and GPU presentation are excluded. `ready_ms` also waits for every expected row and renderer completion:
  native ready needs an applicable frame, prepared viewport decorations and a matching redraw end; baseline ready
  includes all-row icons. Native open, reopen and refresh also record `accepted_ms` (the refresh request observed) and
  `scan_ms` (the accepted scan settled). These are observation times, not traces; never add them.
- **Operations.** Cursor uses typed j/k, scrolling typed Ngg across the viewport, selection Tab on one entry and Visual
  selection 100 file rows. Selection `visible_ms` needs the target row's actual mark; `ready_ms` needs the published
  count and revision.
- **Active loading.** A fresh process per trial and mode. Typed `j` while the branch reports Loading must publish
  during Loading; typed `h` (Tree) or `t2` (List to Tree) must collapse the view and retire the scan; reopening must
  load every child. Cold expansion and warm refresh are separate phases.
- **Startup.** Process creation, the UI handshake, configuration readiness and the first default Explorer, with
  isolated workspace state and the checkout's own plugin lockfile. Plugin caches are warm: fresh processes, not empty
  caches.
- **Git.** A new repository with staged files and no commit; each repeat modifies and restores a tracked file.
  `query_ms` waits for the real refresh, `ready_ms` for the changed annotation in the Explorer model (not a UI flush).
  Each refresh first outlasts the previous one's throttle window.
- **Copy.** The actual `c` action with an accepted path prompt; every file is hashed after timing. `job_ms` ends at
  the native terminal notification (baseline: the copy return), and throughput divides verified bytes or files by
  it. `ready_ms` adds publication, result draining, unlock and the completion cursor. `visible_ms` is when the
  destination name appears, which measures publication policy, not input latency. The expanded-source and
  outside-destination cases make no destination-flush claim. Final probe options `{"destination_browse":"tree"}`
  (or `"list"`) and `{"memory_stages":true}` add native-only phases: browsing the copied output, and memory samples
  across the Job's lifetime that must not be pooled with throughput.
- **Observation.** Drivers notify operation start and finish, and `observer_rpcs` must be zero inside every timed
  operation. Widget readiness is checked on frame and cursor events plus a 2 ms timer; copy and Git readiness checks
  start after the terminal or query notification.
- **CPU, gaps and memory.** `cpu_ms` and `main_cpu_ms` cover an operation through ready; `job_cpu_ms` and
  `job_main_cpu_ms` stop at the terminal notification. Process CPU includes native threads; main-thread CPU is
  macOS-only. A nominal 2 ms timer records the largest tick gap. Natural GC stays on while timing, and a full GC
  precedes memory snapshots. `process_memory_bytes` is libuv's reading: physical footprint on macOS (libuv 1.53+),
  RSS elsewhere, not `ps` RSS. Process memory, Lua heap and native retained accounting overlap; never add them.
- **Statistics.** Repeated operations reduce to one median per process, then to the median, minimum and maximum
  across processes. p95 needs at least 20 processes; `maximum_observation` keeps the slowest single operation. Watch
  events and soak cycles are observations within a process, not independent trials. One-process runs validate
  wiring only.

## Focused drivers

The runner invokes these drivers; run one directly to diagnose a scenario. They use the installed release library
unless given another.

### Navigation

```sh
node script/benchmark/explorer.mjs --case navigation --processes 20 --native /absolute/yoz.so
```

Each fresh process runs ten cycles: typed j/mx selects a file for cut, nested reveal keeps it, an external removal of
the display root (also the process cwd) is followed by refresh and reveal of an existing file, and the hidden view
must release its watches and queued work. Cursor and target are checked in UI flushes. Native acceptance, no latency
claim; ordinary specs cover stale observations, superseded navigation and recovery errors.

### Git and filesystem integration

```sh
nvim -l __test__/run.lua era/m/explorer/
```

A disposable repository with real status/ignore jobs, external writes and renames, ignore invalidation on focus, and
release on hide. Pending-selection cases (loading, cancellation, retry, revision conflicts, a closed pane) never hand a
partial collection to an action.

### Installed LSP server

```sh
nvim -l __test__/bench/explorer/lsp.lua ~/.local/share/nvim/mason/bin/vtsls
```

Renames through the actual action in a temporary TypeScript project and checks the server's import edits, preserved
unsaved buffers and client reattachment, without saving. vtsls 0.3.0 answers with `didRenameFiles` and
`workspace/applyEdit`, not `willRenameFiles`; specs cover the latter.

### Full configuration and Job UI

```sh
nvim -l __test__/bench/explorer/full_config.lua 5 200   # processes, cursor moves
nvim -l __test__/bench/explorer/jobs_ui.lua 3           # processes
```

`full_config.lua` loads the actual `init.lua` and plugins over 200 files. It drives the real create, rename and
delete prompts, keeps an unsaved buffer across rename and delete, and types cursor motion while refreshing every
40 ms. `prompt_ms` ends at the prompt text in the UI; `confirmed_ms` at the filesystem and buffer effects plus the
published Explorer content, not a flush.

`jobs_ui.lua` answers overwrite prompts, copies and moves through missing parents, cancels preparation, pastes 260
files while hidden, cancels a running 10,000-file copy from the Space menu, and exits during a copy by typed and
direct quit; at `VimLeavePre` the cancellation must be acknowledged and the Job registry empty. It checks contents,
terminal states, selection release, result delivery and zero pending work after disposal. Native Jobs and prompts
are not mocked.

### Idle CPU

```sh
nvim -l __test__/bench/explorer/idle.lua [baseline-checkout] [processes]
```

200 files; visible, hidden and disposed phases each settle 500 ms after GC, then run 3 s without polling, with Git
and LSP off. CPU is process-wide `getrusage`, including native threads, as a percentage of one core.

### Recursive root watch (macOS)

```sh
nvim -l __test__/bench/explorer/root_watch.lua 3 [/absolute/yoz.so]
```

96 expanded directories must hold one OS root (`roots=1`, `directories=97`, `limited=false`). The probe covers
external changes beyond the old 50-directory cap, renamed directories, collapsed caches, an external symlink root,
release on hide and a 3 s idle window. Linux and Windows keep a nonrecursive 50-directory budget.

### Job and watch activity

```sh
nvim -l __test__/bench/explorer/activity.lua jobs 3        # a 256 MiB sparse file through the actual Job
nvim -l __test__/bench/explorer/activity.lua jobs-many 3   # 1,000 four-byte files, several progress intervals
nvim -l __test__/bench/explorer/activity.lua watch 3       # isolated renames, a continuous stream, a 500-file burst
```

A native library and a Lua overlay may follow the process count. The watch fixture holds 1,000 files, a cursor anchor
and a visible rename marker. Each isolated rename follows 200 ms without changes, since a change within 150 ms of the
previous re-read continues that activity. The continuous phase creates 80 files and renames the marker every 20 ms;
the burst creates 500 files before the last marker change. `visible_ms` counts displayed marker versions only, and
`final_change_ms` measures the final catch-up. CPU includes a 5 ms latency timer and parent observation.

### Long session

```sh
nvim -l __test__/bench/explorer/soak.lua 200 1000   # cycles (a multiple of 20), files
```

Each cycle folds and expands, switches Tree and List, refreshes, renames a watched file externally through a UI
flush, hides and reopens; a second tab joins every 10 cycles and the whole Widget is recreated every 20. Hidden panes
must hold zero watches and queued work. The final ownership check flushes JIT traces before asserting that disposed
objects are collectible; the memory and weak-reference counts before the flush are kept too.

### Bulk Move preparation

```sh
nvim -l __test__/bench/explorer/move.lua 200 200 none   # files, modified buffers, none|notify|async [profile]
```

Real per-item Move with editor preparation; it verifies every file and every buffer's name, modified flag and text.
`notify` accepts only `didRenameFiles`; `async` adds an empty asynchronous `willRenameFiles` reply. Both measure
protocol overhead, not server latency. `wall_ms` runs to unlock and native idle; `prepare_ms`, `sync_ms` and
`callbacks_ms` overlap, so never add them. `NVIM_EXPLORER_BENCH_CHECKOUT` and `NVIM_EXPLORER_BENCH_NATIVE` select
another Lua checkout or library.

### Filetree probes

```sh
nvim -l __test__/bench/filetree.lua 20 tree annotations   # 50k files, 80×48 UI; tree or list
nvim -l __test__/bench/filetree_watch.lua 20              # isolated external renames through UI flush, 80×24 UI
```

`filetree.lua` reports the first page and the complete load through UI flush; `annotations` adds a 48-row annotation
query, diagnostic navigation across 50k rows and diagnostic updates through UI flush. `filetree_watch.lua` reports
rename-to-flush latency, which includes the watch merge wait, and the tail from Lua's first observation to flush;
each rename follows 200 ms without changes.

Opt-in Rust probes run in release mode, one at a time:

```sh
cargo test --manifest-path rust/Cargo.toml -p yoz --release --lib <test> -- --ignored --nocapture
```

- `ux::filetree::reader::tests::t_scan_stages`: cold and fully loaded warm scans of 1k, 10k and 100k direct files,
  with per-stage times and page-boundary staging (not RSS).
- `t_annotations_wide_directory_with_loaded_aliases`: annotation aggregation and sparse Git navigation with 128
  loaded aliases.
- `t_native_watch_notification_latency`: OS notification latency with 1 ms polling.
- `t_native_link_watch_budget_stress`: 55 external symlink targets against the 50-root budget; needs a file
  descriptor limit of at least 4096.
- `ux::filetree::jobs::staged::tests::` with `--test-threads=1`: staged copy capacity and integrity through a real
  selection task, sampling retained memory every 5 ms; capacity, not throughput.

Cross-filesystem Jobs need a disposable second filesystem:

```sh
FILETREE_TEST_VOLUME=/absolute/mount cargo test --manifest-path rust/Cargo.toml -p yoz --lib \
  cross_filesystem -- --ignored --test-threads=1
```

## Platforms

The tools pick the native library per platform and record what the memory reading means; that makes them portable,
not evidence. Linux, Windows and WSL results come only from runs on those systems, including OS watch and trash
behavior.

## Latest baselines

Values are medians of per-process medians in milliseconds unless noted. Fewer than 20 processes support no p95
claim; rerun the unified runner before comparing against another build.

### macOS (2026-10-23)

`node script/benchmark/explorer.mjs --processes 3`, native only: Apple M5 Pro (6P + 12E) on AC power, Darwin 27.0.0,
Neovim 0.12.6, libuv 1.53.0, Rust 1.99.0, a verified release receipt and macOS physical footprint. All 25 cases
passed, including every acceptance driver.

Widget cases (first flush 10.8–12.6 ms throughout):

| Case       | Mode |   Ready | Cursor | Scroll | Selection | Visual selection | Refresh ready | Reopen | Open MiB |
| ---------- | ---- | ------: | -----: | -----: | --------: | ---------------: | ------------: | -----: | -------: |
| mixed 200  | Tree |  10.762 |  0.264 |  0.701 |     0.406 |            5.590 |         8.834 |  5.345 |     10.5 |
| mixed 200  | List |  10.999 |  0.232 |  0.648 |     0.418 |            5.223 |         9.630 |  4.282 |     11.5 |
| flat 1k    | Tree |  32.539 |  0.236 |  0.818 |     0.551 |            4.548 |         9.347 |  4.587 |     15.4 |
| flat 1k    | List |  22.218 |  0.222 |  0.734 |     0.570 |            3.835 |         9.239 |  5.123 |     14.3 |
| flat 10k   | Tree | 102.428 |  0.293 |  0.746 |     1.007 |            5.440 |        26.453 |  7.374 |     43.4 |
| flat 10k   | List | 102.000 |  0.267 |  0.674 |     0.839 |            4.332 |        21.701 |  6.228 |     43.3 |
| branch 10k | Tree |  97.462 |  0.224 |  0.746 |     0.759 |            4.371 |        28.764 |  7.406 |     41.9 |
| branch 10k | List | 107.623 |  0.249 |  0.731 |     0.862 |            4.704 |        29.115 |  6.115 |     41.9 |
| flat 50k   | Tree | 681.468 |  0.223 |  0.723 |     3.598 |            7.721 |       117.663 | 14.532 |    129.7 |
| flat 50k   | List | 684.514 |  0.197 |  0.696 |     3.320 |            7.385 |       119.026 | 15.057 |    135.6 |

- Ready is one cold open per process, so a single slow open moves it; mixed 200 ranged from 9.2 to 11.7 ms. In branch
  10k, cold expansion flushes in 11.4 ms, warm expansion in 4.1 ms and collapse in 3.2 ms.
- Real-configuration startup is ready at 80.6 ms and visible at 108.0 ms; the first default Explorer is ready at
  29.5 ms.
- `git_1000` refresh is ready at 80.6 ms, of which the status query takes 76.6 ms, with 8.0 ms main-thread CPU and a
  2.9 ms maximum tick gap. The CPU includes the watch re-read of the file the case modifies, which lands inside the
  refresh.

| Copy case           |   Job ms |   CPU ms | Ready ms |
| ------------------- | -------: | -------: | -------: |
| One dense 64 MiB    |   14.084 |   14.855 |   18.359 |
| 100 × 4 B           |   22.276 |   19.819 |   24.818 |
| 1k × 4 B            |  168.262 |  148.677 |  171.273 |
| 10k × 4 B           | 1543.817 | 1367.170 | 1546.050 |
| 1k × 4 KiB          |  186.354 |  158.078 |  190.517 |
| 1k × 64 KiB         |  182.206 |  162.075 |  185.443 |
| 1k, source expanded |  188.776 |  161.165 |  194.567 |
| 1k, target outside  |  174.477 |  147.340 |  176.724 |

Copies keep the main thread to 3.8–26.1 ms of CPU and the maximum tick gap to 2.8–4.0 ms.

Active loading (50k directory):

| Mode | Phase | Input visible ms | Cancel visible ms | Resume ms | Max tick gap ms |
| ---- | ----- | ---------------: | ----------------: | --------: | --------------: |
| Tree | Cold  |            0.276 |             6.888 |   733.446 |           4.466 |
| Tree | Warm  |            0.256 |            11.027 |   191.135 |           2.474 |
| List | Cold  |            0.275 |             1.503 |   739.304 |           4.747 |
| List | Warm  |            0.254 |             5.643 |   192.593 |           6.228 |

- Idle visible, hidden and disposed phases use 0.09–0.20 ms of CPU per three seconds with no redraw notifications
  at 10.7 MiB; the macOS recursive root watch over 97 idle directories uses 0.06 ms.
- Watch activity: an isolated rename is visible after 59.0 ms; a continuous stream shows its changes after 34.5 ms
  (10–42 ms by their place in the merge window) and catches up 126.8 ms after the last; a 500-file burst is visible
  after 121.3 ms. Main-thread CPU is 3.1%, 5.4% and 4.4% of one core. The 256 MiB sparse-file Job takes 44.6 ms wall
  time, 2.4 ms main-thread CPU and a 5.7 ms maximum tick gap.
- Soak (200 cycles): each cycle's rename follows reopening the hidden view within 150 ms, which the restarted watch
  counts as activity, so it is visible after 175.7 ms (56 ms when it comes 600 ms later). Hidden-view footprint grows
  from 16.9 to 21.2 MiB and settles at 20.7 MiB after the trace flush.
- Full configuration: create, rename and delete are confirmed after 25.2, 9.6 and 9.2 ms; the worst cursor during a
  refresh is 9.6 ms. The vtsls rename edits arrive after 71.9 ms with 7.2 ms of rename I/O.
- Navigation acceptance: three processes of ten cycles each complete typed selection, nested reveal, removed-root
  recovery and view release.

### Focused probes (2026-10-22/23)

Same host. The Filetree probes and scan stages were re-measured on 2026-10-23 with the macOS bulk listing; the other
probes are from 2026-10-22. Filetree probes over 50k files in an 80×48 UI, 20 samples each, median / p95 ms:

| Measurement                            |            Tree |            List |
| -------------------------------------- | --------------: | --------------: |
| First 512 rows through UI flush        |     4.88 / 6.67 |     4.69 / 6.29 |
| Complete initial load through UI flush | 673.16 / 693.50 | 679.78 / 695.57 |
| 48-row annotation query                |     0.53 / 1.51 |     0.71 / 1.48 |
| Diagnostic navigation across 50k rows  |     4.80 / 5.90 |     4.79 / 5.95 |
| Diagnostic update through UI flush     |     0.68 / 2.07 |     0.60 / 1.36 |

- Rust retains 80.1 MiB for 50,009 nodes; final Lua heaps are 1.34 / 1.25 MiB and process footprint about 250 MiB.
  These owners overlap; do not add them.
- `filetree_watch.lua`, three processes of 20 isolated renames: rename to UI flush 47.4 ms (per-process p95
  53.8–56.4 ms); Lua's first observation to flush 0.9 ms (p95 8.5–9.3 ms).
- With 128 loaded aliases, annotation aggregation takes p95 6.30 ms and sparse Git navigation p95 3.79 ms. OS watch
  notifications arrive after p50 11.6 / p95 13.7 ms with 1 ms polling.

`t_scan_stages`, medians of three processes; total is initialization, IO, owner application, projection and
retirement:

| Direct files | Phase | Total ms |  IO ms | Apply ms | Project ms | Pages | Staging MiB |
| -----------: | ----- | -------: | -----: | -------: | ---------: | ----: | ----------: |
|        1,000 | Cold  |     4.97 |   1.78 |     1.70 |       1.17 |     2 |        0.96 |
|        1,000 | Warm  |     1.71 |   1.34 |     0.25 |       0.01 |     2 |        0.76 |
|       10,000 | Cold  |    55.26 |  16.72 |    20.36 |      17.38 |     6 |        5.08 |
|       10,000 | Warm  |    23.81 |  19.13 |     3.83 |       0.05 |     6 |        3.18 |
|      100,000 | Cold  |  1319.52 | 218.28 |   481.65 |     615.38 |    70 |       28.90 |
|      100,000 | Warm  |   415.77 | 310.55 |    97.04 |       0.43 |    50 |        8.17 |

Bulk Move preparation, 200 four-byte files, three processes per case:

| Buffers | LSP adapter | Total ms | Prepare ms |
| ------: | ----------- | -------: | ---------: |
|       0 | none        |     88.1 |        7.2 |
|      40 | none        |    671.2 |      297.1 |
|     200 | none        |   2832.8 |     1324.4 |
|     200 | notify      |   2821.9 |     1325.1 |
|     200 | async       |   4142.7 |     2658.1 |

Per-item buffer synchronization dominates with many modified buffers; the asynchronous `willRenameFiles` reply
doubles preparation.

Staged copy capacity, one execution per scenario with a 32 MiB task limit. Job time includes selection cleanup and
excludes fixture construction and content verification:

| Scenario               | Source files | Copied | Job seconds | Sampled task peak MiB | Final Source nodes |
| ---------------------- | -----------: | -----: | ----------: | --------------------: | -----------------: |
| Unloaded source        |       100000 | 100000 |       15.52 |                 25.26 |                 10 |
| Already loaded source  |       100000 | 100000 |       17.10 |                 25.28 |             100010 |
| Decline last conflict  |       100000 |  99999 |       33.42 |                 19.04 |             100009 |
| Merge directory        |        10000 |  10000 |        2.60 |                  1.88 |                 10 |
| Cancel after 40k bytes |        50000 |  10033 |        1.90 |                  2.68 |              10043 |
| Nested long paths      |        10000 |  10000 |        2.21 |                  1.22 |                 34 |

Loaded cases build Source entries from real metadata without a browse Scan, so they validate loaded Job inputs, not
100k browse capacity. The shared data ledger, which includes task charges, samples 207.6 MiB in the decline case;
task accounting is not process memory.

### Linux (2026-10-08)

WSL2 on warm local ext4, five fresh processes per case and mode, three repeats:

| Tree metric                   |       ms |
| ----------------------------- | -------: |
| 10k complete open             |  141.397 |
| 50k first content flush       |   12.909 |
| 50k complete open             | 1581.009 |
| 50k refresh                   |  283.966 |
| 64 MiB copy Job               |   14.459 |
| 10k four-byte files, copy Job |  335.973 |

The eleven-case matrix passed Tree/List browsing, loading input and cancellation, idle, watch churn, five 100-cycle
soaks, full-configuration operations and Job/exit UI. Parent entry watches share the 50-root budget and ignore
unrelated siblings.

### Pre-native comparison (2026-10-07)

Apple M1 Pro, Neovim 0.12.5, three to five alternating processes against `00ccccfd3`, the Lua Explorer that native
replaced:

- 50k Tree opened in 2.07 s instead of 4.39 s (first flush 17.7 ms instead of 4.39 s), refreshed in 0.32 s instead
  of 15.0 s, selected one or 100 rows in 5.8 / 13.0 ms instead of 13.9 s, and ended at 172 instead of 640 MiB.
- Copying 10k four-byte files took 3.3 s instead of 9.3 s with a 7 ms instead of 9.4 s maximum timer gap, but used
  more total CPU: 665 instead of 366 ms for 1k files, of which 109 instead of 363 ms on the main thread.
- Small views cost slightly more: at 200 files, cursor flush 0.34 instead of 0.21 ms, scrolling 1.47 instead of
  0.63 ms and footprint 10.5 instead of 9.0 MiB. Startup and idle CPU were equal.

## Known limits

- A change within 150 ms of the previous watch re-read, or of reopening a hidden view, waits for the whole 150 ms
  window like sustained activity; a change after a quiet period shows in about 50 ms.
- In the pre-native comparison, small-file copies used more total CPU than the Lua Explorer, though less main-thread
  CPU, and copy throughput varies across processes; judge responsiveness and throughput separately.
- A fixed 32 MiB task budget and the shared scan staging cap bound copy and browse capacity; large change sets and
  long names share those caps.
- Expanded-source copy preparation can still reject with `selection revision changed` while acquiring the selection
  lock; reruns pass, so the race is unresolved rather than absent.
- Cross-volume IO and Windows have no recorded runs.
