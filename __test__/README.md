# Tests

Lua and Node tests, shared fixtures and test support live here; Rust unit tests live beside their source modules in
`../rust/<crate>/src/`. The layout, harness, resource lifecycle, timing and Rust/Node placement rules are defined in
the [test architecture](../spec/design/test-harness.md). This guide covers commands and how to write a spec.

## Layout

```text
__test__/
  run.lua     # CLI and isolated suite entry
  support/    # harness, shared primitives and domain support
  specs/      # Lua specs; paths mirror the production modules they test
  fixtures/   # shared data, Lua oracles and child-process entry scripts
  node/       # Node tests of script/ and the benchmark CLIs
  manual/     # manual checks against real servers or a full configuration
  bench/      # optional benchmarks; see bench/README.md
```

Support modules:

- Core: `harness` (cases, assertions, waits, cleanup, temporary directories, buffers and windows), `bootstrap` (declared
  globals, the native library, reporter, schedule and autocommand doubles), `runner`, `ui` and `ui_grid` (a child
  Neovim over msgpack-RPC and its screen), `process` (headless scripts, PTY processes and scenarios), `fs`, `git`.
- Domain: `treeview`, `filetree`, `explorer`, `diffview`, `git_files`, `git_buffer`, `picker`, `directory_picker`,
  `lsp`, `nvimbar`, `dressing`, `image`, `ai`, `clipboard`, `theme`, `ark_autocmd`, `textobject`, `undo`, `cmp/`.

Feature guides live beside their specs: [completion](specs/era/keystroke/cmp/README.md) and
[Git](specs/era/m/git/README.md). Explorer integration specs run the real Filetree/Treeview runtime; trash specs use a
temporary PATH tool and never touch the user's recycle bin. `fixtures/yoz/` keeps its LF and CRLF line endings through
local Git attributes, since both are part of the tested input.

## Run

Run commands from the repository root:

```sh
# All Lua specs
nvim -l __test__/run.lua

# One feature or one file (literal path filters)
nvim -l __test__/run.lua era/dressing/indentline/
nvim -l __test__/run.lua __test__/specs/era/dressing/indentline/provider_spec.lua

# Inspect selection, adjust the per-suite timeout (default: 30 seconds), or the
# number of suites run at once (default: half the hardware threads, at most 8)
nvim -l __test__/run.lua --list era/dressing/
nvim -l __test__/run.lua --timeout 60000 stl/c/
nvim -l __test__/run.lua --jobs 1

# Node and Rust tests, and Rust lints
node --test __test__/node/*.test.mjs
cargo test --manifest-path rust/Cargo.toml --workspace --all-targets --quiet
cargo clippy --manifest-path rust/Cargo.toml --workspace --all-targets -- -D warnings

# Another platform's cfg branches, after `rustup target add x86_64-pc-windows-msvc`
cargo clippy --manifest-path rust/Cargo.toml --target x86_64-pc-windows-msvc --workspace --all-targets -- -D warnings

# Formatting (pinned StyLua and rustfmt), the LuaLS baseline, and the repository-wide health check
node script/format-check.mjs
node script/luals-check.mjs
node script/healcheck.mjs
```

The entry can also be invoked by absolute path from another working directory. Requirements are the latest Neovim and
the existing repository toolchain; native `yoz` specs need the library `node script/build.mjs` installs in `lua/`.
The runner never installs dependencies or builds production artifacts.

## Write a spec

```lua
local parser = require("era.dressing.indentline.parser")
local t = require("__test__.support.harness").new()

t:test("uses tabstop when shiftwidth is zero", function()
  local bufnr = t:buffer({ "\tvalue" }, { filetype = "lua" })
  vim.api.nvim_set_option_value("shiftwidth", 0, { buf = bufnr })
  vim.api.nvim_set_option_value("tabstop", 8, { buf = bufnr })
  t.assert_eq(8, parser.get_options(bufnr).shiftwidth, "effective shiftwidth")
end)

t:run()
```

- Put the spec at the path of the module it tests; name cases after observable behavior, with a concrete trigger for
  regressions. Prefer real small inputs and native buffer/window APIs when their behavior is the contract.
- Acquire resources through the harness (`t:tempdir()`, `t:buffer()`, `t:window()`) or support (`UI.open`,
  `git.repo`), or register `t:defer` right after acquiring them; substitute with `t:patch_global`/`t:patch_table` and
  `bootstrap.with_*`.
- Wait for what should happen with `t.wait_until`, `t.await` or `t.settle`, and for a child with `ui:wait_until` or
  `ui:wait_lua`; observe what must not happen over a fixed window. Keep wall-clock budgets out of specs.
- Compare tables with `t.assert_same`, errors with `t.assert_error`; call `t.skip(reason)` only when the environment
  cannot exercise the behavior.
- Keep a helper in its spec until a second spec needs it, then move it to the support module of its domain.

## Fixtures and manual checks

Fixtures under `fixtures/` follow the spec paths. The `*_lua_reference.lua` files keep the algorithms differential
tests compare against; they are not production implementations.

Each script under `manual/` starts with its exact command and prerequisites and runs its checks as harness cases. The
full-configuration Git checks run in a disposable process on a changed tracked file; `-u init.lua` alone still
resolves modules from the default config path, so the prelude puts this checkout first:

```sh
nvim --headless \
  --cmd 'lua local root = vim.uv.cwd(); vim.opt.runtimepath:prepend(root); package.path = root .. "/?.lua;" .. package.path; package.cpath = root .. "/lua/?.so;" .. package.cpath' \
  -u init.lua -i NONE -n lua/era/m/git/ignore.lua \
  -c 'luafile __test__/manual/era/m/git/status_runtime.lua'
```

## Benchmarks

Benchmarks are optional tooling under `bench/`. [bench/README.md](bench/README.md) gives their shared rules, the
result format and an index of every benchmark with its command or its suite's README.
