# Tests

All test code and shared fixtures live under this directory. Lua tests run in
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
  specs/
    support/               # tests of the test infrastructure
    ark/
    yoz/
    stl/
    dot/
    era/
      dressing/indentline/
        parser_spec.lua    # indentation parsing and option resolution
        render_spec.lua    # virtual text and highlight output
        frame_spec.lua     # buffer context, window cache, invalidation
        provider_spec.lua  # real redraws, extmarks, screen contents
        setup_spec.lua     # registration, eligibility, enable/disable
  node/
    build.test.mjs         # Node tests for script/build.mjs
  rust/
    yoz/                   # unit tests mirroring rust/yoz/src/
    im/                    # unit tests mirroring rust/im/src/
  fixtures/
    yoz/                   # shared Lua/Rust search fixtures
```

Directory names follow the module or feature under test. A large feature can
group related behavior specs, such as `era/m/diffview/workspace/`. Test files use
`*_spec.lua`; support and fixture files are outside the discovery root. Keep
small fixtures local to their spec and move shared helpers into `support/` only
when they have multiple consumers.

Node tests use `node/*.test.mjs`. Rust tests use `rust/<crate>/**/*_test.rs`;
the original source modules contain only `#[cfg(test)]` include wiring, preserving
private access, module names, and platform gates. The archived
`myers_linear_space_test.rs` remains disabled with its experimental implementation.
Production Lua modules have no test-directory references or test-only exports.
Shared search fixtures preserve their original line endings through local Git
attributes; LF and CRLF are part of the tested input.

## Run

Run commands from the repository root:

```sh
# All Lua specs
nvim -l __test__/run.lua

# One feature or one file (literal path filters)
nvim -l __test__/run.lua era/dressing/indentline/
nvim -l __test__/run.lua __test__/specs/era/dressing/indentline/provider_spec.lua

# Inspect selection, or adjust the per-suite timeout (default: 30 seconds)
nvim -l __test__/run.lua --list era/dressing/
nvim -l __test__/run.lua --timeout 60000 stl/c/

# Node and Rust tests
node --test __test__/node/*.test.mjs
cargo test --manifest-path rust/Cargo.toml --workspace --all-targets --quiet

# Formatting and the existing repository-wide health check
~/.local/share/nvim/mason/bin/stylua --check __test__
fd -e rs . __test__/rust -X rustfmt --edition 2024 --check
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
local repositories. The runner does not install dependencies or build artifacts.

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
