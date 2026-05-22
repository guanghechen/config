# Test Harness Implementation Plan

## 1. Scope Mapping

| Design Ref        | Design Source                      | Code Target                                       | Test Target                              |
| ----------------- | ---------------------------------- | ------------------------------------------------- | ---------------------------------------- |
| Harness core      | `spec/design/test-harness/arch.md` | `lua/__test__/harness.lua`                        | `lua/__test__/stl/prompt.lua`            |
| Runtime bootstrap | `spec/design/test-harness/arch.md` | `lua/__test__/bootstrap.lua`                      | `lua/__test__/era/m/git/diff.lua`        |
| Run-all dataflow  | `spec/design/test-harness/flow.md` | `lua/__test__/runner.lua`, `lua/__test__/run.lua` | all suites under `lua/__test__/`         |
| Patch cleanup     | `spec/design/test-harness/flow.md` | `lua/__test__/harness.lua`                        | `lua/__test__/era/m/explorer/action.lua` |
| Suite migration   | `spec/design/test-harness/arch.md` | existing test suite files                         | migrated suite files                     |

## 2. Work Breakdown

| Step | Design Ref        | Change Area       | Inputs                 | Outputs                        | Verification                     | Code Target                                       |
| ---- | ----------------- | ----------------- | ---------------------- | ------------------------------ | -------------------------------- | ------------------------------------------------- |
| 1    | Harness core      | shared helpers    | repeated local runners | reusable harness API           | direct `prompt.lua` run passes   | `lua/__test__/harness.lua`                        |
| 2    | Runtime bootstrap | globals setup     | explicit module maps   | minimal `_G` bootstrap helpers | `diff.lua` async cases pass      | `lua/__test__/bootstrap.lua`                      |
| 3    | Patch cleanup     | mock lifecycle    | explorer action mocks  | patch stack cleanup helpers    | globals restored after each case | `lua/__test__/harness.lua`                        |
| 4    | Suite migration   | existing suites   | current suite files    | suites using harness API       | each suite passes with `nvim -l` | `lua/__test__/**/*.lua`                           |
| 5    | Run-all runner    | aggregate command | migrated suite files   | module plus script entry       | all suites run in one command    | `lua/__test__/runner.lua`, `lua/__test__/run.lua` |
| 6    | Documentation     | usage guidance    | final command set      | documented test commands       | docs match actual commands       | `AGENTS.md` or `spec/CODESTYLE.md`                |

## 3. Acceptance Criteria

- Every suite can still run directly with `nvim -l <suite-file>`.
- A run-all entry can execute all suite files and returns non-zero on failure.
- No suite defines its own `passed`, `failed`, `test`, or common assertion
  helpers after migration.
- Runtime global requirements are explicit through `__test__.bootstrap` or local
  fixture setup.
- Tests that patch `_G`, `vim`, or module tables restore those patches after each
  case.
- Current `era.m.git.diff` async tests pass without loading the full user config.
- The staged explorer action regression test is migrated before it is committed.

## 4. Rollback Plan

- Keep production code untouched during harness migration.
- If the harness blocks progress, restore individual suite files to their current
  self-contained runner form.
- If run-all introduces flakiness, keep direct suite execution as the supported
  command and defer aggregate execution.
- If bootstrap hides production dependency issues, replace broad bootstrap calls
  with smaller per-suite global patches.

## 5. Progress

| Step | Status    | Notes                                          |
| ---- | --------- | ---------------------------------------------- |
| 1    | completed | Added `lua/__test__/harness.lua`.              |
| 2    | completed | Added `lua/__test__/bootstrap.lua`.            |
| 3    | completed | Explorer action test uses patch helpers.       |
| 4    | completed | Existing suites use shared harness API.        |
| 5    | completed | Added `runner.lua` module and `run.lua` entry. |
| 6    | completed | Test commands documented in `CODESTYLE.md`.    |
