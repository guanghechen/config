# Test Architecture

## Scope and layout

All Lua, Node, and Rust test code and shared fixtures live under top-level
`__test__/`, outside the production `lua/` runtime. Lua specs are grouped by the
module or feature under test and use the `*_spec.lua` suffix. Related behaviors may share a feature directory,
such as `__test__/specs/era/m/diffview/workspace/`.

- `__test__/run.lua` is the public CLI and the entry used by suite subprocesses.
- `__test__/support/` contains reusable execution and fixture support.
- `__test__/specs/` is the only Lua discovery root.
- `__test__/specs/support/` tests the infrastructure itself.
- `__test__/node/*.test.mjs` contains Node tests, run with `node --test`.
- `__test__/rust/<crate>/**/*_test.rs` contains Rust unit tests, run with `cargo test`.
- `__test__/fixtures/` contains fixtures shared across specs or languages.
- Small fixtures stay local to their spec. Shared helpers need multiple real consumers.

The local harness remains dependency-free. Test infrastructure does not introduce
production abstractions or a runtime plugin system.

## Ownership and dependencies

| Component                    | Responsibility                                        | Owned state                         |
| ---------------------------- | ----------------------------------------------------- | ----------------------------------- |
| `__test__/run.lua`           | Resolve checkout, prepare runtime, dispatch execution | Process CWD, runtime and Lua paths  |
| `__test__.support.runner`    | Discover, select, launch, time out, report suites     | Suite list, child process results   |
| `__test__.support.harness`   | Register cases, assert, run, clean up, report         | Case registry, case/suite cleanups  |
| `__test__.support.bootstrap` | Prepare explicitly requested application globals      | Harness-owned global substitutions  |
| `*_spec.lua`                 | Specify observable behavior and regressions           | Local fixtures and resource handles |

Within a process, dependencies remain one-way:

```text
CLI entry -> runner
suite entry -> spec -> harness
                   -> bootstrap -> explicitly requested production modules
                   -> production modules under test
```

The runner starts a new entry process with `--suite`; that branch loads the spec
without importing the runner. Production Lua modules never import test support,
reference `__test__`, or expose test-only hooks. Pure logic needed by production
and tests belongs to normal domain modules, such as `era.m.ai.capture`.
Neither harness nor runner imports production modules. Bootstrap does not import
runner or suites.

Rust source modules retain only `#[cfg(test)] mod ... { include!(...); }` wiring
for their extracted unit tests. Include paths start from `CARGO_MANIFEST_DIR` and
point into `__test__/rust/`; module names, private access, and platform gates stay
unchanged. No test code is included in a normal build. Node specs import the
production scripts directly. Shared fixture paths resolve from the checkout root.

## Execution contract

The public command is `nvim -l __test__/run.lua [--list] [--timeout ms] [path-filter]`.
The selector is a literal substring of the spec path. A complete file path selects
one suite; a directory selects its specs. Discovery is recursive and sorted, and
only includes regular files ending in `_spec.lua`. Helpers are not excluded by a
filename blacklist.
Directory reads and entry inspection are checked; a failure at any depth aborts
discovery before launching suites.

The entry resolves the repository's canonical path from its own file location,
sets CWD to that checkout, and installs its runtime and Lua paths alongside
Neovim's built-in runtime and library directories. Bundled parsers remain available
when Neovim installs them separately from `$VIMRUNTIME`. Each suite starts in a separate
Neovim process with `--headless -u NONE -i NONE -n`. Application configuration and
plugin startup are not automatic; a composed runtime spec may explicitly request
`ark.bootstrap` when that runtime is part of the tested contract.

Suites run sequentially through argv-based `vim.system` calls, with a 30-second
per-suite timeout that the CLI can override. A failed or timed-out suite is
reported and later suites still run. There are no automatic retries, dependency
installation, or implicit native builds.

Zero selected suites, missing directories, invalid CLI arguments, empty specs,
forgotten `t:run()` calls, load errors, case/cleanup failures, failed launches,
nonzero child exits, and timeouts must produce a nonzero exit status.

## Harness and resource lifecycle

- One harness owns each suite's case registry. A spec ends with `t:run()`.
- `t:defer(fn)` registers cleanup and returns an idempotent early-disposal handle.
- `patch_global` and `patch_table` use the same cleanup ownership.
- Registrations made during a case belong to that case. Top-level registrations
  belong to the suite and remain available to every case.
- Cleanup runs in reverse order after both success and failure. A cleanup error
  is retained alongside the original failure and does not skip other cleanups.
- A suite with no registered cases fails but still disposes suite resources.
- Specs own their temporary files, repositories, buffers, windows, and async work.
  Async work must settle or be cancelled before its resources are disposed.

`harness:run({ exit = false, quiet = true })` remains available for harness
self-tests. Ordinary specs use the default process-exiting mode. Bootstrap
helpers remain explicit declarations and register restoration through the harness.

## Test boundaries and naming

Prefer focused specs for distinct contracts. The indentline feature illustrates
this with `parser_spec.lua`, `render_spec.lua`, `frame_spec.lua`,
`provider_spec.lua`, and `setup_spec.lua`. Pure calculations, buffer/cache state,
native rendering, and lifecycle registration have separate fixtures and failure
signals while remaining together under the feature directory.

Case names describe observable behavior. Regression tests include the triggering
input and assert the affected result. New shared support is extracted only for
actual repeated needs. All Lua specs use the same harness and resource lifecycle.

## Validation

Infrastructure specs cover discovery boundaries, deterministic ordering, literal
selection, empty selection, child state isolation, paths containing spaces and
Unicode, execution from another CWD, load/case/cleanup failures, empty specs,
missing run calls, process failures, timeouts, and CLI diagnostics.

See [flow](flow.md) for state transitions and
[the test guide](../../../__test__/README.md) for executable commands and examples.
