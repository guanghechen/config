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
    runner.lua             # discovery, process timeout, aggregate result
    harness.lua            # cases, assertions, cleanup
    bootstrap.lua          # explicitly declared runtime globals
    filetree.lua           # native Filetree runtime and filesystem fixtures
    explorer.lua           # composed Explorer panes, native state and input helpers
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
platform gates. Shared Rust test support also stays inside its crate under `#[cfg(test)]`.
Filetree reader, runtime, annotations and watch tests use child `tests` modules;
their production files retain the same private module boundaries and platform gates.
The archived `myers_linear_space` tests remain disabled alongside their experimental implementation.
Production Lua modules have no test-directory references or test-only exports.
Shared search fixtures preserve their original line endings through local Git
attributes; LF and CRLF are part of the tested input.

Manual macOS IM measurements live in `bench/im.lua`. Run
`nvim --headless -u NONE -i NONE -n -l __test__/bench/im.lua [native-library]`
to measure capture and restoration to the same current source, excluding cold initialization.
The default library is `lua/yoz.so`; pass `rust/target/release/libyoz.dylib` to compare a new build.
The benchmark aborts if the source changes externally and does not measure switching between input methods.

Full Explorer Widget measurements and acceptance probes live in
[`bench/explorer/`](bench/explorer/README.md). The runner supports isolated native/legacy
Tree comparison, separate native List runs, raw samples, version/module hashes and
independent-process summaries. That guide also contains real Git/watch, installed
vtsls rename and repeated-session commands; empty Git notification timing is kept
separate from actual Git collection.

Filetree measurements use the installed release module (`lua/yoz.so`) and an attached 80×48 UI:
`nvim -l __test__/bench/filetree.lua 20 tree annotations` (or `list`). Each run creates 50k files,
keeps natural GC during samples, and reports publication/flush latency and separate memory metrics.
The optional `annotations` argument also measures a 48-row viewport, worst-case 50k-row diagnostic
navigation, and diagnostic updates through UI flush. Native stage and loaded-alias measurements
are opt-in Rust tests `t_native_directory_stages` and `t_annotations_wide_directory_with_loaded_aliases`;
run them with `cargo test --release ... -- --ignored --nocapture` and without concurrent test/build load.

2026-09-22 acceptance: Apple M2 Max / 32 GiB, Darwin 27.0.0, Neovim 0.12.5, release module,
80×48 attached UI, 50k files, 20 samples per mode with natural GC. Values below are p95 milliseconds:

| Measurement | Tree | List |
| --- | ---: | ---: |
| First 512 rows through UI flush | 17.590 | 20.747 |
| Complete initial load through UI flush | 1986.568 | 1969.299 |
| 48-row annotation query | 1.930 | 1.660 |
| Diagnostic navigation across 50k visible rows | 14.196 | 14.066 |
| Diagnostic update through UI flush | 2.888 | 2.506 |

Both complete-load p95 values meet the 2 s target, and these local annotation operations meet 16 ms.
The initial unchanged implementation measured 2021.666/2075.876 ms. The final change caches source-order
sibling ranks during projection and reads display options only on demand, avoiding an unused Lua table
on every polling tick. The maximum Tree complete flush was 2050.850 ms; the acceptance bound is p95.
Rust retained memory after collection was about 109.2 MiB per final tree, with zero queued work.
Final Lua heaps were 1055.8/1021.0 KiB; process RSS was 992768/1017920 KiB after natural-GC samples.
These metrics describe different owners and must not be added together.

The release alias benchmark passed: 50k synthetic files plus 128 real loaded aliases, 20 samples,
annotation aggregate p95 10.086 ms and sparse Git navigation p95 6.054 ms. A separate 98-page native
scan measured IO 237.980 ms, apply 472.549 ms, projection 682.003 ms; these are single-run stage totals.
Seven existing release performance tests passed. Three-state 50k leaf updates measured p95 0.052 ms;
preparing 50k explicit operation roots took p95 64.646 ms on the native owner, separately from local UI
interaction. Deep ancestry tests covered 1k/2k/4k/8k nodes; ordinary tests cover 10k-depth construction,
text storage and iterative release. The filtered 8k ancestor batch measured p95 16.168 ms.
On the real macOS filesystem, 471 nested directories reached a 1022-byte absolute path; creating the
next level returned `ENAMETOOLONG`. Native Filetree open, resource lookup and details succeeded at that
deepest path, and the temporary tree was removed.

The explicit 200k stress case uses a 2 GiB budget: 200005 source nodes, three states with different roots
and Tree/List modes, three retained old frames, leaf/directory rename, reparent, insert/remove and metadata
changes. It passed with about 321.1 MiB retained; dropping all handles returned accounted memory to zero.
This synthetic pressure case is separate from the real 50k filesystem baseline.

Watch latency uses `nvim -l __test__/bench/filetree_watch.lua 20` with an attached 80×24 UI.
A real single-file rename measured p95 185.722 ms from mutation to UI flush,
including the 150 ms coalescing window. Lua's first observation of the new source to flush measured
p95 0.325 ms. A separate native OS notification probe measured
p95 14.424 ms with 1 ms polling. These are separate observations, not an additive per-event trace.
The backend coalescing window is fixed; IO and owner scheduling remain included in the total latency.
After detach the watch count and queue depth were zero. The ordinary native suite also opens/releases
100 data/state/view instances and checks final budget reclamation after retained frames are dropped.

Explorer integration tests use the actual Filetree/Treeview runtime and default entry. They cover shared
and independent state, symlink reveal, root loss/recreation, flags and titles, Visual selection, queued
copy/cut changes, paste cleanup, cancelled preparation, late callbacks, LSP rename preparation/edits,
dirty-buffer preservation, byte-name isolation, trash failure, complete target paths, Git/diagnostic
subscriptions and real typed exit commands. Trash tests use a temporary PATH tool and do not alter the
user's recycle bin. `status_runtime.lua` now checks the default Explorer's native ignore decoration.

Final regression run: Rust workspace 474 passed, with the 15 opt-in cases exercised separately;
Explorer 32 cases / 7 suites, UX 28 cases / 7 suites, source-window opening 11 cases, LSP rename 7 cases,
and all 11 adjacent nvimbar suites passed. StyLua, Lua annotation alignment, cargo fmt and diff checks
passed. The full-config Git smoke passed status parity, stable native handles, signs, Explorer ignore
and blame using the installed release module. Restart an existing Neovim process to load the new native API.

Cross-filesystem acceptance ran all three opt-in Job cases on a separate temporary 512 MiB APFS volume,
including watched 128 MiB copy/move coordination. The volume was detached and its image removed.
Reproduce on a disposable second filesystem with `FILETREE_TEST_VOLUME=/absolute/mount` and
`cargo test --manifest-path rust/Cargo.toml -p yoz --lib cross_filesystem -- --ignored --test-threads=1`.

Run stress probes sequentially without concurrent builds:

```sh
cargo test --manifest-path rust/Cargo.toml -p yoz --release --lib performance -- --ignored --nocapture --test-threads=1
cargo test --manifest-path rust/Cargo.toml -p yoz --release --lib t_large_multi_root_mutations_keep_retained_frames -- --ignored --nocapture
cargo test --manifest-path rust/Cargo.toml -p yoz --release --lib t_annotations_wide_directory_with_loaded_aliases -- --ignored --nocapture
cargo test --manifest-path rust/Cargo.toml -p yoz --release --lib t_native_watch_notification_latency -- --ignored --nocapture
cargo test --manifest-path rust/Cargo.toml -p yoz --release --lib t_native_link_watch_budget_stress -- --ignored --nocapture
```

The watch-budget stress needs a file descriptor limit of at least 4096. Windows has a native
`ReadDirectoryChangesW` backend and is checked with the installed `x86_64-pc-windows-msvc` target.
Linux/Windows/WSL runtime and their trash backends were not executed on this macOS host; cross-compilation
does not establish runtime/watch acceptance on those platforms.

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
  -c 'luafile __test__/fixtures/era/m/git/status_runtime.lua'
```

For full-config word-highlight E2E, open a tracked file with an unstaged change hunk:
use the same runtime/native prelude, a changed tracked file, and
`-c 'luafile __test__/fixtures/era/m/git/word_diff_runtime.lua'`.
These fixtures compare actual UI data with the Lua oracle, disable context saving and exit without
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

# Inspect selection, or adjust the per-suite timeout (default: 30 seconds)
nvim -l __test__/run.lua --list era/dressing/
nvim -l __test__/run.lua --timeout 60000 stl/c/

# Node and Rust tests
node --test __test__/node/*.test.mjs
cargo test --manifest-path rust/Cargo.toml --workspace --all-targets --quiet

# Formatting and the existing repository-wide health check
~/.local/share/nvim/mason/bin/stylua --check __test__
cargo fmt --manifest-path rust/Cargo.toml --all -- --check
node script/healcheck.mjs
```

The entry can also be invoked by absolute path from another working directory.
It resolves the checkout's real path from its own location and gives every spec a fresh
`--headless -u NONE -i NONE -n` Neovim process. Tests use this checkout's runtime
alongside Neovim's built-in runtime and library directories, including its bundled
parsers. The canonical checkout is also the CWD. No user configuration or plugin
startup is loaded automatically.

Requirements are the latest Neovim and the existing repository toolchain.
Native `yoz` specs need the compiled module in `lua/`; build it through the
existing `node script/build.mjs` workflow. Git integration specs use temporary
local repositories. The runner does not install dependencies or build production artifacts.
The native blame exit spec uses the installed `rustc` to build a tiny controlled Git-process fixture
in its temporary directory; it is removed during cleanup. Real Git query/parsing parity is tested separately.

Zero matches, an empty spec, a missing `t:run()`, load errors, case or cleanup
failures, process failures, and timeouts all produce a nonzero exit status. A
failed suite does not prevent later suites from running. There are no automatic
retries or silent skips.
An unreadable spec directory, including a nested directory, fails selection
before any suite starts.

## Write a spec

```lua
local harness = require("__test__.support.harness")
local parser = require("era.dressing.indentline.parser")
local t = harness.new("era.dressing.indentline.options")

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

- Name cases after observable behavior and include a concrete trigger for regressions.
- Prefer real small inputs and native buffer/window APIs when their behavior is the contract.
- Use `patch_global` and `patch_table` for controlled substitutions; each returns an idempotent restore handle.
- Register resources with `defer` immediately after acquisition. Cleanup runs in reverse order, including after failures. Top-level registrations last for the suite; registrations inside a case last for that case.
- Declare application globals through `__test__.support.bootstrap`. Load `ark.bootstrap` explicitly only when the composed runtime is part of the test.
- Wait for observable async completion with `t.wait_until(predicate, timeout_ms, message)`; settle or cancel owned work before cleanup.
- Keep temporary repositories, files, buffers, and windows owned by the creating test. Test failures must retain their original diagnostics.
