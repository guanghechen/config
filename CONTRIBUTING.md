# Contributing to VSGit

## Module boundaries

- `extension.ts` is the composition root.
- `app` owns VS Code command workflows and depends on lower layers through narrow capability
  interfaces.
- `comparison` and `history` own their state transitions; `git` owns read-only Git execution; `view`
  owns TreeView and diff presentation; `platform` owns stable extension IDs.
- Dependencies are one-way. `pnpm test` checks allowed layer edges and rejects import cycles.

State has one writer: `CommitHistorySession` owns history, `CommitMarkSession` owns marks,
`ComparisonSession` owns the active comparison, and `CommitChangeCache` owns derived immutable
commit changes. A failed current operation preserves the last successful snapshot; a superseded
operation aborts its Git process and returns no snapshot.

## Naming and style

- Use `kebab-case.ts` filenames and descriptive domain names such as `historySession`,
  `comparisonSession`, and `repositoryResolver`; avoid context-free names such as `value`,
  `manager`, or `data` for long-lived state.
- Prefix TypeScript interfaces with `I`. Use `PascalCase` for types/classes, `camelCase` for
  functions/parameters, and `UPPER_CASE` for module constants.
- Name lifecycle and role types consistently: `*Session`, `*Controller`, `*Provider`, `*Source`, and
  `*Cache`.
- Keep exposed interfaces narrow. Add an abstraction only when a real second implementation, test
  fake, or peer module exists.

Prettier and ESLint enforce formatting, type-only imports, interface naming, identifier casing, and
shadowing rules.

## Verification

Run the complete local gate before committing:

```bash
pnpm check
```

Performance changes should include deterministic regression coverage for Git call counts,
cancellation, cache reuse/eviction, or concurrency instead of relying only on timing benchmarks.
