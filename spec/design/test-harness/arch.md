# Test Harness Architecture Spec

## 1. Module Boundary (SRP)

| Module               | Responsibility                             | Public Ports                                                                    | Private Runtime                        |
| -------------------- | ------------------------------------------ | ------------------------------------------------------------------------------- | -------------------------------------- |
| `__test__.harness`   | Register cases, assert, patch, run, report | `new`, `test`, `assert_*`, `patch_*`, `wait_until`, `run`                       | suite state, case list, patch stack    |
| `__test__.bootstrap` | Prepare declared runtime globals           | `with_global`, `with_runtime`, `with_stl_c`, `with_stl`, `with_dot`, `with_era` | saved globals, require mapping helpers |
| `__test__.runner`    | Discover and run suites                    | `discover`, `run_all`, `main`                                                   | suite paths, subprocess exit codes     |
| `__test__.run`       | Script entry for run-all mode              | top-level `runner.main()` call                                                  | none                                   |
| suite files          | Express behavior examples and regressions  | top-level `t.test(...)` registrations                                           | fixture data, local mocks              |

## 2. Dependency Graph

- one-way dependencies:

```text
suite files -> __test__.harness
suite files -> __test__.bootstrap
__test__.run -> __test__.runner
__test__.runner -> suite files by subprocess path
__test__.bootstrap -> production modules by explicit request
```

- forbidden reverse dependencies:

```text
production modules -/> __test__
__test__.harness -/> suite files
__test__.harness -/> production modules
__test__.bootstrap -/> __test__.runner
__test__.runner -/> __test__.harness
```

## 3. Interaction Lifecycle Model

### Lifecycle

- init: load `__test__.harness`; create one suite context for the current file.
- start: suite registers cases and optional bootstrap declarations.
- stop: harness runs registered cases, computes suite result, and prints summary.
- dispose: restore all case patches and suite patches, then release suite state.

### Interaction Transitions

| From       | To         | Event                  | Guard                    | Timeout | Error Handling                           |
| ---------- | ---------- | ---------------------- | ------------------------ | ------- | ---------------------------------------- |
| init       | start      | suite file loads       | harness module available | none    | fail suite load                          |
| start      | case_run   | `t.run()` or auto main | cases registered         | none    | invalid case becomes failed case         |
| case_run   | case_clean | case returns or errors | cleanup stack exists     | none    | failure captured, cleanup still runs     |
| case_clean | case_run   | next case selected     | next case exists         | none    | continue after recording cleanup failure |
| case_clean | stop       | no case remains        | result computed          | none    | fail suite if result cannot be computed  |
| stop       | dispose    | summary emitted        | patch stacks drained     | none    | exit non-zero if any failure exists      |

## 4. Interface Contracts

| Port                    | Input                        | Output             | Idempotency                            | Timeout    | Error Contract                                   |
| ----------------------- | ---------------------------- | ------------------ | -------------------------------------- | ---------- | ------------------------------------------------ |
| `harness.test`          | name, callback               | registered case    | not idempotent by name                 | none       | invalid input raises suite load error            |
| `harness.assert_eq`     | expected, actual, message    | nil                | idempotent                             | none       | raises assertion error                           |
| `harness.patch_global`  | global name, replacement     | cleanup handle     | idempotent cleanup                     | none       | cleanup error is attached to case result         |
| `harness.patch_table`   | table, key, replacement      | cleanup handle     | idempotent cleanup                     | none       | cleanup error is attached to case result         |
| `harness.wait_until`    | predicate, timeout ms        | nil                | idempotent by predicate                | caller set | timeout raises assertion error                   |
| `harness.run`           | `exit`, `quiet` opts         | suite result       | not idempotent after side-effect cases | suite set  | failures are captured in the suite result        |
| `bootstrap.with_global` | global name, table spec      | patched global     | idempotent cleanup                     | none       | invalid or missing module raises bootstrap error |
| `bootstrap.with_stl_c`  | harness                      | patched `_G.stl.c` | idempotent cleanup                     | none       | missing module raises bootstrap error            |
| `bootstrap.with_stl`    | module map or default subset | patched `_G.stl`   | idempotent cleanup                     | none       | missing module raises bootstrap error            |
| `runner.discover`       | root path, filter            | suite path list    | idempotent                             | none       | unreadable root returns empty list plus warning  |
| `runner.run_all`        | root path, filter            | failed suite count | idempotent if tests are deterministic  | suite set  | non-zero subprocess exits increment failed count |

## 5. Minimal Core + Plugin Contract

### Minimal Core

- baseline capabilities: case registration, assertions, patch cleanup, direct
  suite execution, run-all execution, and aggregate reporting.
- works without optional plugins: true
- external framework dependency: none

### Plugin Contract

No runtime plugin contract is defined for the initial harness. The minimal core
is intentionally self-contained. If future work adds optional adapters, that
adapter lifecycle must be designed in a separate spec before implementation.

## 6. Observability and Degrade Strategy

- Print case names and failures in deterministic order.
- Print one suite summary and one aggregate summary in run-all mode.
- Include file path and case name for each failure.
- Do not print secret-like environment values or credential files.
- Degrade by failing only the current suite when bootstrap or suite load fails.
- Abort only when harness state is internally inconsistent and cleanup cannot be
  trusted.

## 7. Open Decisions

| Topic | Options | Owner | Deadline | Blocking | Decision Rule |
| ----- | ------- | ----- | -------- | -------- | ------------- |
| None  | none    | none  | none     | false    | none          |
