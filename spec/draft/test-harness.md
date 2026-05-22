# Test Harness Draft

## 1. Problem Statement

Lua tests currently use independent `nvim -l` scripts under `lua/__test__/`.
That keeps each file easy to run, but test registration, assertions, reporting,
global patching, and cleanup are duplicated across suites.

The immediate trigger is `lua/__test__/era/m/explorer/action.lua`: it is a useful
regression test, but its local mock lifecycle shows that the current pattern does
not scale for action-level tests that patch `_G` and `vim` APIs.

## 2. Context and Constraints

- Keep the existing `nvim -l <test-file>` workflow.
- Avoid adding external test framework dependencies unless local needs exceed the
  minimal harness design.
- Keep tests inside `lua/__test__/` so `require("__test__.*")` works with the
  existing runtime path.
- Do not rely on full Neovim config bootstrap by default; tests should declare
  the runtime globals they need.
- Preserve focused module tests for `stl` and `era` without crossing production
  dependency boundaries.
- Current staged explorer action test remains uncommitted until migrated into the
  final harness shape.

## 3. Open Questions

| Question                        | Options                                     | Decision                   | Rationale                                                              |
| ------------------------------- | ------------------------------------------- | -------------------------- | ---------------------------------------------------------------------- |
| Test runner dependency          | local harness / plenary / busted            | local harness              | Existing tests only need a small script runner.                        |
| Per-file execution              | keep / replace with run-all only            | keep                       | Fast local debugging depends on `nvim -l file`.                        |
| Run-all entry                   | none / Lua script entry / shell script      | Lua script entry           | Keeps execution in Neovim and avoids shell glue.                       |
| Bootstrap default               | full config / minimal declared globals      | minimal declared globals   | Prevents hidden state from masking test issues.                        |
| Explorer action regression test | drop / keep current / migrate to harness    | migrate to harness         | The regression is valuable but mock cleanup belongs in shared helpers. |
| External formatter in tests     | system `stylua` / Mason `stylua` / optional | Mason `stylua` when needed | Repo documents Mason tooling and avoids install prompts.               |

## 4. Risk Notes

| Risk                     | Trigger                                     | Evidence                                      | Impact                                | Mitigation                                      |
| ------------------------ | ------------------------------------------- | --------------------------------------------- | ------------------------------------- | ----------------------------------------------- |
| Hidden global dependency | Suite passes only after full config loading | `era.m.git.diff.run_diff_future` reads `stl`. | Tests fail differently by entry path. | Require explicit bootstrap or minimal globals.  |
| Leaked runtime patch     | Test mutates `_G` or `vim` without cleanup  | Explorer action test patches both.            | Later tests become order-dependent.   | Harness owns patch stack and case cleanup.      |
| Runner duplication       | Each suite defines local `test/assert`      | All existing suites duplicate runner code.    | Higher maintenance and drift.         | Centralize registration, assertions, reporting. |
| Large migration churn    | Rewriting all suites at once                | `future.lua` has 79 cases.                    | Review becomes noisy.                 | Migrate harness first, then suites by module.   |
| Async flakiness          | `vim.wait` timeouts or worker callback lag  | `diff.lua` async tests wait 3000 ms.          | False negatives in run-all.           | Provide async helpers and explicit timeouts.    |

## 5. Draft Decisions

- Add a minimal `lua/__test__/harness.lua` module.
- Add `lua/__test__/runner.lua` as the run-all module and `lua/__test__/run.lua` as the script entry.
- Add optional `lua/__test__/bootstrap.lua` helpers for declared runtime globals.
- Keep suite files executable with `nvim -l lua/__test__/path/to/suite.lua`.
- Use harness-owned patch cleanup for `_G`, `vim`, environment variables, and
  package-loaded overrides.
- Migrate the staged explorer action test after the harness exists.
