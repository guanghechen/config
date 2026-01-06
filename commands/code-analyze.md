---
description: Comprehensive code review on specified target
---

Perform a comprehensive code review on the specified target.

## Review Target

``````text
$ARGUMENTS
``````

**Mode Detection**:
- If the argument is a `.code-analyzer/{topic}/*.md` file path → **Re-analyze Mode**
- Otherwise → **New Analysis Mode**

### Re-analyze Mode

When given an existing `.code-analyzer/{topic}/*.md` file:
1. Read the file to extract the original review target and issues
2. Read `baseline.md` in the same directory to get shared consensus
3. Re-analyze the same target to check:
   - Which previously identified issues are now **fixed** (mark with ✅)
   - Which issues **remain unfixed**
   - Any **new issues** introduced since the last review
4. **Suppress** issues documented in `baseline.md` (By Design decisions)
5. **Rewrite** the analysis file with updated results

## Baseline File

The `baseline.md` file (`.code-analyzer/{topic}/baseline.md`) stores shared consensus:

```markdown
# Baseline: {topic}

> Review target: {original-target}

## By Design

These are intentional design decisions. Do NOT report as issues in any analysis.

### {pattern-or-location}
- **Reason**: Why this is intentional
- **Date**: When this decision was made
```

**Rules**:
- **Only `By Design`** decisions are stored in baseline (permanent design decisions)
- Other statuses (`fixed`, `done`, `won't fix`, `false alarm`) stay in the analysis file only
- All commands must read baseline before analysis and suppress matching issues

## Review Focus Areas

Analyze the code systematically with emphasis on:

### 1. Logic Errors
- Incorrect conditional logic, off-by-one errors, boundary conditions
- Unhandled edge cases
- Incorrect control flow, unreachable branches
- Race conditions or concurrency issues

### 2. Performance Issues
- Unnecessary computations or redundant operations
- N+1 queries or inefficient database access patterns
- Expensive operations inside loops
- Suboptimal algorithm complexity

### 3. Memory Leaks
- Missing cleanup of resources (event listeners, subscriptions, timers)
- Memory accumulation (growing arrays, caches without eviction)
- Improper disposal patterns in component/object lifecycle
- Circular references preventing garbage collection

### 4. Deprecated APIs
- Deprecated language features or library APIs
- Outdated patterns with better modern alternatives
- Incompatibility with current runtime/framework versions

### 5. Code Organization
- Illogical ordering of code elements (imports, constants, types, functions)
- Poor separation of concerns
- Unrelated code grouped together
- Private implementation before public API

### 6. Code Style & Conventions
- Deviation from project coding standards
- Inconsistent naming conventions (including `I`-prefixed interfaces/types)
- Inconsistent formatting and structure
- Code duplication that should be refactored

## Issue Format

Group issues by category using hierarchical numbering (e.g., `1.1`, `1.2`, `2.1`), where the first digit represents the category number from Review Focus Areas.

For each issue, provide:
- **Location**: File path and line number(s)
- **Severity**: Critical / Warning / Suggestion
- **Description**: Clear explanation of the issue
- **Recommendation**: How to fix or improve

Example:
```markdown
### 1. Logic Errors

#### 1.1 [Critical] Off-by-one error in loop
- **Location**: `src/utils.ts:42`
- **Description**: ...
- **Recommendation**: ...

#### 󰄬 ~~[fixed] 1.2 [Warning] Unhandled edge case~~
- **Location**: `src/utils.ts:58`
- **Description**: ...
- **Recommendation**: ...

#### 󰜺 ~~[Won't Fix] 1.3 [Warning] Missing null check~~
- **Location**: `src/utils.ts:75`
- **Description**: ...
- **Recommendation**: ...
```

## Issue Resolution Statuses

Issues can be marked with the following statuses (applied via `/code-apply`). All resolved statuses use ~~strikethrough~~ to indicate completion:

| Status      | Heading Format             | Stored In      | Meaning                                           |
| ----------- | -------------------------- | -------------- | ------------------------------------------------- |
| Fixed       | `󰄬 ~~[fixed] ... ~~`       | analysis file  | Issue resolved by code fix                        |
| Done        | `󰄬 ~~[done] ... ~~`        | analysis file  | TODO item completed                               |
| By Design   | `󰛨 ~~[By Design] ... ~~`   | **baseline**   | Intentional behavior; suppress in future analysis |
| Won't Fix   | `󰜺 ~~[Won't Fix] ... ~~`   | analysis file  | Known issue, accepted risk or deferred            |
| False Alarm | `󱙝 ~~[False Alarm] ... ~~` | analysis file  | Not a real issue; exclude from future analysis    |

**Re-analyze Behavior**:
- `󰄬 [fixed]` / `󰄬 [done]`: Re-verify; remove strikethrough if issue reappears
- `󰜺 [Won't Fix]` / `󱙝 [False Alarm]`: Preserve in analysis file; do NOT re-report
- `󰛨 [By Design]`: Stored in `baseline.md`; permanently suppressed across all analyses

## Summary Table

Provide a summary table at the beginning of the output:

```markdown
## Summary

| Category           | Critical | Warning | Suggestion | Total |
| ------------------ | -------- | ------- | ---------- | ----- |
| 1. Logic Errors    | 1        | 2       | 0          | 3     |
| 2. Performance     | 0        | 1       | 1          | 2     |
| 4. Deprecated APIs | 0        | 1       | 0          | 1     |
| **Total**          | **1**    | **4**   | **1**      | **6** |
```

- Skip rows for categories with 0 total issues
- The **Total** row is always present

## Output Requirement

### New Analysis Mode
1. Read `baseline.md` if exists; suppress documented By Design issues
2. **Display** the full review output in the conversation
3. **Save** analysis to `{cwd}/.code-analyzer/{topic}/cc.md`
   - `{topic}`: concise kebab-case title (e.g., `git-module`, `user-auth-service`)

### Re-analyze Mode
1. Read `baseline.md`; suppress documented By Design issues
2. **Display** the full updated review output in the conversation
3. **Rewrite** the specified `.code-analyzer/{topic}/*.md` file with updated analysis

## Style

- Respond in Chinese (简体中文); keep code and technical terms in English
- Only explain rare or domain-specific concepts
- Skip categories with no issues found
