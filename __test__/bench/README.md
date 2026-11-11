# Benchmarks

Benchmarks are optional measurements kept apart from the test suites: specs neither load their drivers nor need their
results. Run every command from the repository root. Each suite's README keeps its scenarios' methods and latest
baselines; this file holds what all benchmarks share.

## Layout

- A topic with several files is a directory holding its `README.md` and entry scripts, such as `treeview/`.
- A single-file benchmark stays at this level; its header comment gives its command and what it measures.
- Modules the drivers share live in `lib/`: `record.lua` writes a run, `stats.lua` summarizes distributions, and
  `metrics.lua` reads process and main-thread CPU, process memory and the Lua heap.
- Runners and reporters written in Node live in [`script/benchmark/`](../../script/benchmark/); their tests are
  `__test__/node/benchmark-*.test.mjs`.
- `results/` holds local output.

## Rules

- Run benchmarks sequentially, without concurrent builds, tests or other benchmarks.
- Benchmarks use existing binaries and never install or download dependencies.
- Samples, traces and local analysis under `results/` are ignored by Git. A suite's README records each scenario's
  method and latest baseline; earlier numbers remain in its Git history.

## Result format

Most Lua benchmarks write each run through `lib/record.lua` to `results/<bench>/<UTC>-<pid>.json` (schema
`bench-run/1`) and print the results with that path. `<bench>` is the record name the driver passes; it does not change
when a driver moves, so local results stay comparable by name. A run records its environment (Neovim, LuaJIT, host,
checkout commit and dirty state, the native library's build receipt and the process-memory definition), its conditions
and its results. Durations are milliseconds and memory is bytes.

Two kinds of benchmark keep their own output:

- The drivers that the Node runners start, those in `fuzzy/` and the `explorer/` probes other than `move.lua` and the
  Filetree probes, print JSON records on stdout. `script/benchmark/explorer.mjs` and `script/benchmark/fuzzy.mjs`
  collect them into a result directory with `metadata.json`, `results.jsonl`, `summary.json` and `report.md`.
- The completion benchmark writes `metadata.json` and one `<phase>.json` per phase into the directory it is given; see
  [Completion](cmp/README.md).

A distribution is `{ n, median, p95, min, max }` from `lib/stats.lua`, or `script/benchmark/stats.mjs` in Node: the
median of an even count is the midpoint, and p95 is nearest-rank and absent below 20 values. Both implementations are
checked against `__test__/fixtures/bench/stats_cases.json` (`specs/support/bench_stats_spec.lua` and
`node/benchmark-stats.test.mjs`). `iterations` counts repetitions within one process and `processes` counts fresh
processes.

## Index

Suites:

- [Explorer and Filetree](explorer/README.md): the unified Explorer runner in `script/benchmark/`, focused Lua probes,
  Filetree probes and opt-in Rust scan, watch and copy-capacity tests.
- [Treeview](treeview/README.md): synthetic projection, `ux::treeview::perf_tests`, real data consumers, cursor-path
  guides, result consumers, viewport decorations, Diffview and List measurements.
- [Yoz Fuzzy](fuzzy/README.md): the L1 Rust core, L2 FFI and L3 real UI levels of `script/benchmark/fuzzy.mjs`, fzf
  parity and ranking quality.
- [Completion](cmp/README.md): the completion benchmark and its reporter.

Single-file benchmarks:

- `nvim --headless -u NONE -i NONE -n -l __test__/bench/im.lua [native-library]`: macOS IM capture and restoration to
  the same current source, excluding cold initialization. The library defaults to `lua/yoz.so`; pass
  `rust/target/release/libyoz.dylib` to compare a new build. The run aborts if the source changes externally, and it
  does not measure switching between input methods.
- `nvim -l __test__/bench/lsp_event.lua`: the keymap reconciliation of `era.m.lsp.event` when a client registers and
  unregisters a capability at run time.
- `nvim -l __test__/bench/nvimbar.lua`: Nvimbar refreshes of 8, 32 and 64 components, from the refresh to the
  publication of their latest data.
- `nvim -l __test__/bench/searcher.lua [iterations=20]`: the Searcher's publication of a completed native search of 500
  matches, normal and as a replace preview, and of 5,000 matches, split into poll, normalize, apply and render.
- `nvim -l __test__/bench/signal_hub.lua [iterations=50000]`: the CPU cost of SignalHub delivery and cleanup.
