# Test Harness Flow Spec

## 1. Scope

This spec defines the dataflow for Lua test execution under `lua/__test__/`.
It covers single-suite execution, run-all execution, runtime preparation, case
cleanup, reporting, and process exit status.

It does not define production module behavior or external CI wiring.

## 2. Boundary

- Input Boundary: suite files under `lua/__test__/`, optional runner filters,
  explicit bootstrap requests from each suite, and test case callbacks.
- Output Boundary: stdout test report, suite result records, failed suite count,
  process exit status, and restored runtime patches after each case.

## 3. Dataflow State Machine

### States

| State           | Owner                | Read Set                    | Write Set                        | Side Effects                   |
| --------------- | -------------------- | --------------------------- | -------------------------------- | ------------------------------ |
| Discovered      | `__test__.runner`    | `lua/__test__` file paths   | suite path list                  | none                           |
| RuntimePrepared | `__test__.bootstrap` | suite bootstrap declaration | runtime globals, package path    | optional global assignment     |
| SuiteLoaded     | `__test__.harness`   | suite file, harness API     | suite registry, case registry    | suite module execution         |
| CaseRunning     | `__test__.harness`   | case callback, patch stack  | case result, patch stack         | test callback execution        |
| CaseCleaned     | `__test__.harness`   | patch stack, case result    | restored runtime, cleanup result | global and vim API restoration |
| SuiteReported   | `__test__.harness`   | case results                | suite result                     | stdout suite report            |
| RunReported     | `__test__.runner`    | subprocess exit codes       | failed suite count               | stdout run report, `os.exit`   |

### Transitions

| From            | To              | Trigger                     | Guard                        | On Failure                                  |
| --------------- | --------------- | --------------------------- | ---------------------------- | ------------------------------------------- |
| Discovered      | RuntimePrepared | runner starts suite process | suite path exists            | record non-zero suite exit and continue     |
| RuntimePrepared | SuiteLoaded     | bootstrap returns           | required globals available   | record bootstrap failure and continue       |
| SuiteLoaded     | CaseRunning     | harness dequeues case       | case callback is callable    | record invalid case failure and continue    |
| CaseRunning     | CaseCleaned     | case returns or errors      | patch stack is owned by case | run cleanup; attach cleanup error to case   |
| CaseCleaned     | CaseRunning     | next case exists            | suite has pending cases      | record failure and continue                 |
| CaseCleaned     | SuiteReported   | no pending case remains     | suite result can be computed | abort current suite report                  |
| SuiteReported   | RuntimePrepared | next suite exists           | runner has pending suites    | continue with next suite                    |
| SuiteReported   | RunReported     | no pending suite remains    | suite results complete       | emit fatal runner failure and exit non-zero |

## 4. Failure Path

- retry: no automatic retry; tests must be deterministic.
- rollback: case-owned patches are restored in reverse registration order.
- degrade: a suite load, bootstrap failure, or failed case returns non-zero from
  the suite process; the run-all runner records one failed suite and continues.
- abort: harness internal invariant failures abort the current process with a
  non-zero exit code after printing the failing invariant.

## 5. Invariants

- Each suite owns its case registry; cases do not write into another suite.
- Each case owns its patch stack; cleanup runs after every case even when the
  case fails.
- A suite file can be executed directly with `nvim -l <suite-file>`.
- Run-all output is the sum of suite results and uses non-zero exit status when
  any suite or case fails.
- Bootstrap is explicit; a test must not depend on full config side effects
  unless the suite declares that mode.

## 6. Test Matrix

| Scenario             | Input                             | Expected Output                       |
| -------------------- | --------------------------------- | ------------------------------------- |
| Direct passing suite | one suite with passing cases      | zero failures, exit code 0            |
| Direct failing suite | one suite with failing case       | failure details, exit code 1          |
| Run-all mixed suites | one pass, one fail                | both reported, exit code 1            |
| Patch cleanup        | case patches `_G` or `vim`        | original value restored after case    |
| Suite load failure   | syntax or require error           | failed suite record, runner continues |
| Minimal bootstrap    | suite requests `stl.c.Future`     | `_G.stl.c.Future` available in case   |
| Async case           | callback completes before timeout | pass result without leaking timers    |

## 7. Open Decisions

| Topic | Options | Owner | Deadline | Blocking | Decision Rule |
| ----- | ------- | ----- | -------- | -------- | ------------- |
| None  | none    | none  | none     | false    | none          |
