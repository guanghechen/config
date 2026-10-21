# Tests

Lua/Node test code and shared fixtures live under this directory. Rust unit tests
live alongside their source modules in `../rust/<crate>/src/`. Lua tests run in
Neovim using the repository's local harness; Node and Rust use their native runners.
The execution and ownership contracts are defined in [architecture](../spec/design/test-harness/arch.md)
and [flow](../spec/design/test-harness/flow.md).

## Layout

```text
__test__/
  run.lua                  # CLI and isolated suite entry
  support/
    runner.lua             # discovery, parallel suite processes, timeouts, ordered aggregate output
    harness.lua            # cases, assertions, await, temporary directories, cleanup
    bootstrap.lua          # explicitly declared globals, the native library, reporter capture
    ui.lua                 # msgpack-RPC client for child Neovim processes, with redraws
    ui_grid.lua            # screen grid built from ext_linegrid redraws
    process.lua            # headless scripts and PTY Neovim processes
    git.lua                # isolated Git commands and temporary repositories
    treeview.lua           # native Treeview requests, ResultTree publishing, typed-ahead checks
    filetree.lua           # native Filetree runtime and filesystem fixtures
    explorer.lua           # composed Explorer panes, child UI start, native state and input helpers
    cmp/                   # completion runtime, embedded editor, behavior editor and behavior traces
    textobject.lua, git_files.lua, diffview_pane.lua, directory_picker.lua  # feature helpers
  specs/
    support/               # tests of the test infrastructure
    ux/filetree/
      runtime_spec.lua     # browsing, paging, immutable resources and watch
      jobs_spec.lua        # file operations, confirmation and task lifetime
      annotations_spec.lua # diagnostic input and stable-frame decoration
      git_spec.lua         # native Git snapshots; creates a temporary Git repository
      ui_spec.lua          # attached annotation rendering
    ark/
    yoz/
    stl/
    dot/
      win/
        open_spec.lua        # opening events, saved cursor and navigation ownership
        open_screen_spec.lua # native TUI opening with real ShaDa and UI services
    era/
      m/explorer/          # default entry, actions, shared state, inputs, UI and exit
      dressing/indentline/
        parser_spec.lua    # indentation parsing and option resolution
        render_spec.lua    # virtual text and highlight output
        frame_spec.lua     # buffer context, window cache, invalidation
        provider_spec.lua  # real redraws, extmarks, screen contents
        screen_spec.lua    # batched refreshes and idle command-line TUI updates
        setup_spec.lua     # registration, eligibility, enable/disable
      dressing/statusline/
        setup_spec.lua     # dirty events, subscriptions and exit lifecycle
        loading_spec.lua   # composed runtime and lazy backend loading
        screen_spec.lua    # native command-line screen updates
        exit_spec.lua      # pending process cleanup on Neovim exit
      m/nvimbar/
        queue_spec.lua     # dispatch order and deadline budget
        component_spec.lua # component request, snapshot and cancellation state
        nvimbar_spec.lua   # layout, publication and window ownership
        init_spec.lua      # lazy constructor declarations
        component/        # individual data providers and formatters
  node/
    build.test.mjs         # Node tests for script/build.mjs
  manual/                  # manually run checks against real servers or a full configuration
  fixtures/
    dot/win/
      seed_marks.lua       # isolated ShaDa file-position fixtures
      open_screen.lua      # native opening and cursor-restoration scenarios
    yoz/                   # shared Lua/Rust search fixtures
    era/dressing/statusline/
      runtime.lua          # shared runtime assembly for native scenarios
      cmdline.lua          # command-line screen scenario
      exit.lua             # pending Python probe scenario
```

Directory names follow the module or feature under test. A large feature can
group related behavior specs, such as `era/m/diffview/workspace/`. Test files use
`*_spec.lua`; support and fixture files are outside the discovery root. Keep
small fixtures local to their spec and move shared helpers into `support/` only
when they have multiple consumers.

Node tests use `node/*.test.mjs`. Rust unit tests live in the corresponding crate's
source modules under `#[cfg(test)]`, preserving private access, module names, and
platform gates. Shared Rust test support stays inside its crate in `#[cfg(test)]`
`test_support.rs` modules: `rust/yoz/src/test_support.rs` (`TempDir`, `eventually`, `percentile`,
`isolated`), `ux/treeview/`, `ux/filetree/` and `git/`. Test functions are named `t_*`.
Filetree and Treeview tests use a child `tests` module per production module, such as
`ux/filetree/jobs/tests.rs` or `ux/treeview/reads/tests.rs`; their production files retain the
same private module boundaries and platform gates. A large suite becomes a `tests.rs` that declares one
child per contract, such as `ux/filetree/jobs/tests/{moves,links,copy,admission,create}.rs`. File
operations share a process-wide limit on active jobs, so a test that starts operations or creates files
holds `ux::filetree::test_support::operations()` from its first line. Opt-in release measurements live in
`perf_tests.rs` modules and in `#[ignore]` cases named by the measurement records below.
Production Lua modules have no test-directory references or test-only exports.
Shared search fixtures preserve their original line endings through local Git
attributes; LF and CRLF are part of the tested input.

Explorer integration tests use the actual Filetree/Treeview runtime and default entry. They cover shared
and independent state, symlink reveal, root loss/recreation, flags and titles, Visual selection, queued
copy/cut changes, paste cleanup, cancelled preparation, late callbacks, LSP rename preparation/edits,
dirty-buffer preservation, byte-name isolation, trash failure, complete target paths, Git/diagnostic
subscriptions and real typed exit commands. Trash tests use a temporary PATH tool and do not alter the
user's recycle bin. `status_runtime.lua` now checks the default Explorer's native ignore decoration.

Completion regression specs live under `specs/era/keystroke/cmp/`; their runtime and behavior
editor are in `support/cmp/`, and behavior cases with per-step expectations are in
`fixtures/era/keystroke/cmp/behavior/`. Ordinary suites need no benchmark runners or generated results:

```sh
nvim -l __test__/run.lua era/keystroke/cmp/
cargo test --offline --manifest-path rust/Cargo.toml -p yoz completion:: --lib

# Real servers, using an existing Mason executable or an explicit executable argument
nvim -l __test__/manual/era/keystroke/cmp/lua_ls.lua
nvim -l __test__/manual/era/keystroke/cmp/emmet.lua
```

The [completion behavior guide](../spec/debug/cmp-behavior.md) maps failures to focused
suites. Full-sort, tokenization and scalar/SIMD oracles remain separate from production algorithms.
The [performance guide](../spec/debug/cmp-benchmark.md) documents the benchmark CLI, baseline
contract, sampling/GC boundaries and reporter; `node --test __test__/node/cmp-*.test.mjs` tests them.

Git regression coverage lives in `specs/era/m/git/` and `../rust/yoz/src/git/`:

- Status, ignore and blame compare real Git query results with independent Lua references, including
  raw object identity, UI projections, symlinks, invalidation, cancellation and process cleanup.
- Staging covers byte/EOL normalization, histogram selection, 40k-line / 10k-hunk reference-stack limits,
  real index writes, clean filters, stale snapshots and FIFO release.
- Unicode codecs use Neovim's actual file writer as the byte oracle, covering aliases, BOM, leading
  U+FEFF, LF/CRLF, NUL, BMP/astral text and EOF. Invalid or unrepresentable input must preserve the index.
- Word diff covers 2,000 seeded byte edits, the 500-byte cap, failure/empty-result contracts, and actual
  popup text, highlight extmarks, keymap cleanup and source-buffer preservation.
- The shared `blame_history.lua` fixture builds real history with 10k distinct commits for the former
  mlua auxiliary-reference-stack failure. Sparse labels, error recovery and arbitrary bytes are tested too.

The Lua reference files retain the algorithms used by differential tests; they are not production
implementations and should not be used as a source of new features.

For full-config status/signs/ignore/blame smoke coverage, open a changed tracked file in a disposable
process. On macOS/Linux, prepend this checkout's runtime and native module explicitly; `-u init.lua`
alone still resolves modules from the default config path:

```sh
nvim --headless \
  --cmd 'lua vim.opt.runtimepath:prepend(vim.uv.cwd()); package.cpath = vim.uv.cwd() .. "/lua/?.so;" .. package.cpath' \
  -u init.lua -i NONE -n lua/era/m/git/ignore.lua \
  -c 'luafile __test__/manual/era/m/git/status_runtime.lua'
```

For full-config word-highlight E2E, open a tracked file with an unstaged change hunk:
use the same runtime/native prelude, a changed tracked file, and
`-c 'luafile __test__/manual/era/m/git/word_diff_runtime.lua'`.
These checks compare actual UI data with the Lua oracle, disable context saving and exit without
writing source buffers.

## Run

Run commands from the repository root:

```sh
# All Lua specs
nvim -l __test__/run.lua

# One feature or one file (literal path filters)
nvim -l __test__/run.lua era/dressing/indentline/
nvim -l __test__/run.lua __test__/specs/era/dressing/indentline/provider_spec.lua

# nvimbar core/providers and statusline integration/native scenarios
nvim -l __test__/run.lua era/m/nvimbar/
nvim -l __test__/run.lua era/dressing/statusline/

# Inspect selection, adjust the per-suite timeout (default: 30 seconds), or the
# number of suites run at once (default: half the hardware threads, at most 8)
nvim -l __test__/run.lua --list era/dressing/
nvim -l __test__/run.lua --timeout 60000 stl/c/
nvim -l __test__/run.lua --jobs 1

# Node and Rust tests, and Rust lints
node --test __test__/node/*.test.mjs
cargo test --manifest-path rust/Cargo.toml --workspace --all-targets --quiet
cargo clippy --manifest-path rust/Cargo.toml --workspace --all-targets -- -D warnings

# Formatting (pinned StyLua and rustfmt), the LuaLS baseline, and the repository-wide health check
node script/format-check.mjs
node script/luals-check.mjs
node script/healcheck.mjs
```

The entry can also be invoked by absolute path from another working directory.
It resolves the checkout's real path from its own location and gives every spec a fresh
`--headless -u NONE -i NONE -n` Neovim process. Suites run concurrently; each suite's output is
written as one block in discovery order, and suite processes do not inherit `TMUX`. The slowest suites
of earlier runs start first, from durations the runner records in Neovim's cache directory
(`test-suite-durations.json`); without a record, suites start in discovery order. Tests use this checkout's runtime
alongside Neovim's built-in runtime and library directories, including its bundled
parsers. The canonical checkout is also the CWD. No user configuration or plugin
startup is loaded automatically.

Requirements are the latest Neovim and the existing repository toolchain.
Native `yoz` specs load the library this platform installs in `lua/` (`yoz.so`, or `yoz.dll` on
Windows) through `require("yoz")`; build it with `node script/build.mjs`, which compiles only the
current platform's target. Git integration specs use temporary local repositories. The runner does not install dependencies or build production artifacts.
The native blame exit spec uses the installed `rustc` to build a tiny controlled Git-process fixture
in its temporary directory; it is removed during cleanup. Real Git query/parsing parity is tested separately.

Zero matches, an empty spec, a missing `t:run()`, load errors, case or cleanup
failures, process failures, and timeouts all produce a nonzero exit status. A
failed suite does not prevent other suites from running. There are no automatic
retries. A case that the environment cannot exercise calls `t.skip(reason)`; it
prints `SKIP <case>: <reason>`, counts in the summary, and does not fail the suite.
A suite slower than the shared limit declares `--- Timeout: <ms>` among its leading
comment lines; the runner applies the larger of that and the shared limit.
An unreadable spec directory, including a nested directory, fails selection
before any suite starts.

## Write a spec

```lua
local harness = require("__test__.support.harness")
local parser = require("era.dressing.indentline.parser")
local t = harness.new()

t:test("uses tabstop when shiftwidth is zero", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  vim.api.nvim_set_option_value("shiftwidth", 0, { buf = bufnr })
  vim.api.nvim_set_option_value("tabstop", 8, { buf = bufnr })
  t.assert_eq(8, parser.get_options(bufnr).shiftwidth, "effective shiftwidth")
end)

t:run()
```

- Specs have no header: the suite takes its name from the file path, and specs declare no `__module_name__`.
- Name cases after observable behavior and include a concrete trigger for regressions.
- Prefer real small inputs and native buffer/window APIs when their behavior is the contract.
- Use `patch_global` and `patch_table` for controlled substitutions; each returns an idempotent restore handle.
- Register resources with `defer` immediately after acquisition. Cleanup runs in reverse order, including after failures. Top-level registrations last for the suite; registrations inside a case last for that case.
- Declare application globals through `__test__.support.bootstrap`. Load `ark.bootstrap` explicitly only when the composed runtime is part of the test.
- Compare tables with `t.assert_same(expected, actual, message)`, which shows both sides on failure.
- Suites run concurrently, so wait by what the assertion claims: wait for something that should happen
  until it holds, with a generous timeout; observe something that must not happen over a fixed window;
  for a step that expects both, wait the window and then keep polling the expected state. Keep wall-clock
  budgets out of specs; measure latency in benchmarks.
- Wait for observable async completion with `t.wait_until(predicate, timeout_ms, message)` or a Future with
  `t.await(future, timeout_ms)`; settle or cancel owned work before cleanup. When the predicate makes RPC requests
  to a child, use `ui:wait_until`: a request inside a `vim.wait` callback keeps the wait from timing out.
- Create temporary directories with `t:tempdir()` under the system temporary directory, never inside the checkout;
  temporary Git repositories come from `support.git`, child processes from `support.process` or `support.ui`.
- Load the native library with `bootstrap.with_native(t)` and record reports with `bootstrap.with_reporter(t)`.
- Skip only after detecting at runtime that the environment cannot exercise the behavior, such as a filesystem that refuses a name; never skip to hide a failure.
- Keep temporary repositories, files, buffers, and windows owned by the creating test. Test failures must retain their original diagnostics.

## Benchmarks

Benchmarks are optional tooling. Run them sequentially, without concurrent builds,
tests or other benchmarks; they use existing binaries and never install or download
dependencies. Samples, traces and local analysis under `bench/results/` are ignored by Git. Measurement records keep each scenario's method
and latest baseline:

- [Explorer and Filetree](bench/explorer/README.md): the unified Explorer runner in
  [`script/benchmark/`](../script/benchmark/), focused Lua probes, Filetree probes and
  opt-in Rust scan, watch and copy-capacity tests.
- [Treeview](bench/treeview.md): synthetic projection, `ux::treeview::perf_tests`,
  real data consumers, guides, result consumers, Diffview and List measurements.
- [Yoz Fuzzy](../spec/design/feat/yoz/fuzzy.md#评测): L1 Rust core, L2 FFI and L3 real UI.
- [Completion](../spec/debug/cmp-benchmark.md): the completion benchmark and reporter.

Fuzzy matcher measurements run through `node script/benchmark/fuzzy.mjs`;
for example `node script/benchmark/fuzzy.mjs --level e2e --case files_10k_tree --build --baseline-rev 117a4fc88 --runs 3`.
`--current DIR` times a snapshot so the working tree stays editable during long runs. Corpora, levels, statistics, the
fzf parity check (`fuzzy::perf_tests::t_fzf_parity`) and the ranking-quality probe (`fuzzy::perf_tests::t_fuzzy_quality`)
are described in the fuzzy design.

Manual macOS IM measurements live in `bench/im.lua`. Run
`nvim --headless -u NONE -i NONE -n -l __test__/bench/im.lua [native-library]`
to measure capture and restoration to the same current source, excluding cold initialization.
The default library is `lua/yoz.so`; pass `rust/target/release/libyoz.dylib` to compare a new build.
The benchmark aborts if the source changes externally and does not measure switching between input methods.

Cursor-path guide measurements use `nvim -l __test__/bench/treeview_guides.lua [native-library] [baseline-dir] [rows] [samples] [ui-height]`.
Defaults are `lua/yoz.so`, no baseline override, 50,000 rows and 300 samples per operation after 30 warmups.
Pass `''` for the baseline directory when specifying a larger row count. The fixture imports 512-record chunks,
expands an eight-way tree, and attaches an 80×50 UI by default. It measures API/Normal adjacent movement, visible
branch changes, eight API cursor requests in one callback, redraw before CursorMoved, cold jumps, scrolling and
Visual movement through native publication and UI flush, with natural GC and an assertion of zero body writes.
The burst alternates between two visible rows: its first request repeats the existing position and seven move it.
The optional baseline directory contains the previous `decorations.lua`, `surface.lua` and `view.lua`; both variants
use the same release native module. Output includes p50/p95/max, sample counts, surface work, path updates,
prepare/redraw/guide-extmark counts and retained Lua heap. `flush` measures visible output; `publication` measures
native frame acknowledgement; `settled` waits for both and for deferred path invalidation to clear.
Viewport preparation calls are separate from native row-query counts and exported-row totals, including bounded
overscan. Process CPU per operation uses getrusage after warmup and includes native threads and measurement RPCs.
Cursor-only publications can acknowledge pixels that
already flushed and need no further redraw. Path-update time includes any immediate redraw it requests;
it is not an isolated ancestry-query measurement. External terminal/compositor presentation is excluded.

`nvim -l __test__/bench/treeview_results.lua 50000` drives the production ResultPaths/ResultFiles adapter
in an attached 100×40 UI with virtual file records (no filesystem scan). It reports producer time,
first complete UI flush, cursor feedback and native confirmation separately, buffer writes during
cursor movement, retained Lua heap, and collection of the first directory's selected identities.

`nvim -l __test__/bench/treeview_diffview.lua 10000 10` drives actual Diffview expansion actions in an
attached 100×40 UI. It separates the header-only first screen and first file materialization from
subsequent expansion/collapse, and counts record-plan rebuilds, imports and icon lookups in the hot loop.

`nvim -l __test__/bench/diffview_navigation.lua 5000` measures cold/hot adjacency and navigation after
metadata publication. Add a preserved baseline directory as the second argument; pass `"" directories`
to sample skipping collapsed directories. Preview I/O and UI flush are excluded.
