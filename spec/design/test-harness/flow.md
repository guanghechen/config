# Test Execution Flow

This document defines the execution and failure flow for the test structure
specified in [architecture](arch.md). All test sources live under `__test__/`.

The repository health check runs Node specs from `__test__/node/` with
`node --test`, Lua specs through `__test__/run.lua`, and Rust unit tests through
`cargo test --workspace --all-targets`. Cargo compiles the files in
`__test__/rust/` through their original source modules' `cfg(test)` includes.
Each check retains its runner's exit status; a failed check does not skip later checks.

## Lua CLI and suite processes

1. `__test__/run.lua` resolves its canonical checkout and prepares CWD, runtimepath,
   packpath, and the Lua module path, preserving Neovim's built-in runtime and library directories.
2. The parent process parses a literal path filter, `--list`, and `--timeout`.
   Invalid arguments or an unreadable/empty selection fail before spawning.
3. Discovery collects and sorts `__test__/specs/**/*_spec.lua`. List mode prints the
   selected paths and exits without running them.
4. For each selected path, the runner starts a clean Neovim process executing
   `__test__/run.lua --suite <path>`. The child's entry prepares the same checkout.
5. The child loads its spec, which declares globals, creates one harness,
   registers cases, and calls `t:run()`.
6. Each case runs, then its cleanup stack drains. Failures retain diagnostics.
   After the last case, suite cleanup drains and the child reports and exits.
7. The parent records the child's output and exit status. A failed launch,
   nonzero exit, or timeout increments the failed-suite count. Later suites run.
8. The parent reports the aggregate result and exits nonzero if any suite failed.

## Case lifecycle

| State          | Owner     | Output / invariant                                    |
| -------------- | --------- | ----------------------------------------------------- |
| Registered     | Spec      | Named callable cases and declared suite resources     |
| Running        | Harness   | One active case cleanup stack                         |
| Case cleanup   | Harness   | All case cleanups attempted in reverse order          |
| Suite cleanup  | Harness   | All suite cleanups attempted after the final case      |
| Reported       | Harness   | Counts and original/cleanup failure diagnostics        |
| Process ended  | Runner    | Exit status recorded; subsequent suite may start      |

Suite resources outlive case resources. Cleanup handles run at most once even
when invoked early. Empty suites still release their suite resources and fail.

## Failure contract

| Trigger                         | Required behavior                                    |
| ------------------------------- | ---------------------------------------------------- |
| Missing root / zero matches      | Nonzero CLI exit; no successful zero-test result      |
| Invalid option / timeout         | Actionable diagnostic before spawning                |
| Empty file / missing `t:run()`   | Child exits nonzero                                  |
| Zero registered cases            | Harness reports failure and runs suite cleanup        |
| Spec load or assertion error     | Child reports failure; later suites run               |
| Case cleanup error               | Keep both errors; run remaining cleanups              |
| Process launch error             | Record failed suite; later suites run                 |
| Suite exceeds deadline           | Terminate child, report timeout, continue             |

There is no retry or silent skip. Missing dependencies are failures with their
original diagnostics; the test runner never installs or replaces dependencies.
Application bootstrap is explicit and state does not cross suite processes.
