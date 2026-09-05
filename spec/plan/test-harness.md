# Test Infrastructure Migration Plan

Design references:

- [Architecture](../design/test-harness/arch.md)
- [Execution flow](../design/test-harness/flow.md)

## Scope

Consolidate all test code and shared fixtures under `__test__/`, remove testing
dependencies from the Lua runtime, standardize Lua spec naming and selection,
and make execution and resource cleanup explicit. Preserve existing behavior
assertions and the native Rust/Node runners.

## Execution

1. Inventory the original Lua suites and record the complete baseline result.
2. Move specs to `__test__/specs/` with `_spec.lua` names and group feature behaviors.
3. Move harness/bootstrap/runner to `__test__/support/`; add the shared process entry.
4. Expose `defer` for resource ownership and validate runner failure paths.
5. Split indentline rendering, frame state, and native provider coverage.
6. Move Node specs, Rust test bodies, and shared fixtures under `__test__/`;
   preserve Rust module scope and platform gates through compile-time includes.
7. Replace Lua test-only hooks with ordinary domain modules where needed.
8. Update healthcheck, editor settings, commands, and documentation references.
9. Check migration coverage, run focused infrastructure specs and the full suite,
   then review the complete changeset.

## Acceptance

- Existing behavior assertions survive the migration.
- All test code and shared fixtures live under `__test__/`; `lua/` has no
  `__test__` references or test-only exports.
- Cargo discovers the same Rust tests; Node specs still run with `node --test`.
- The same entry handles the full suite, a directory, and one file from any CWD.
- Test discovery includes only specs and cannot silently pass an empty selection.
- Suite processes have explicit startup and bounded execution.
- Case/suite cleanup runs after failures without discarding original diagnostics.
- Validation distinguishes pre-existing failures from migration regressions.

Current commands and the test authoring guide live in [__test__/README.md](../../__test__/README.md).
