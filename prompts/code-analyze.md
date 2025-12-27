Perform a comprehensive code review on the specified target.

## Review Target

``````text
$ARGUMENTS
``````

**Mode Detection**:
- If the argument is a `.code-analyze/*.md` file path → **Re-analyze Mode**
- Otherwise → **New Analysis Mode**

### Re-analyze Mode

When given an existing `.code-analyze/*.md` file:
1. Read the file to extract the original review target and issues
2. Re-analyze the same target to check:
   - Which previously identified issues are now **fixed** (mark with ✅)
   - Which issues **remain unfixed**
   - Any **new issues** introduced since the last review
3. **Preserve** all issue resolution statuses (see Issue Resolution Statuses)
4. **Rewrite** the file with updated analysis results

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

| Status      | Heading Format                   | Meaning                                              |
| ----------- | -------------------------------- | ---------------------------------------------------- |
| Fixed       | `󰄬 ~~[fixed] ... ~~`             | Issue resolved by code fix                           |
| Done        | `󰄬 ~~[done] ... ~~`              | TODO item completed                                  |
| By Design   | `󰛨 ~~[By Design] ... ~~`         | Intentional behavior; suppress in future analysis    |
| Won't Fix   | `󰜺 ~~[Won't Fix] ... ~~`         | Known issue, accepted risk or deferred               |
| False Alarm | `󱙝 ~~[False Alarm] ... ~~`       | Not a real issue; exclude from future analysis       |

**Re-analyze Behavior**:
- `󰄬 [fixed]` / `󰄬 [done]`: Re-verify; remove strikethrough if issue reappears
- `󰛨 [By Design]` / `󰜺 [Won't Fix]` / `󱙝 [False Alarm]`: Preserve; do NOT re-report

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
1. **Display** the full review output in the conversation
2. **Save** a copy to `{cwd}/.code-analyze/{simple-title}-codex.md`
   - `{simple-title}`: concise kebab-case title (e.g., `user-auth-service`)

### Re-analyze Mode
1. **Display** the full updated review output in the conversation
2. **Rewrite** the specified `.code-analyze/*.md` file with updated analysis

## Style

- Respond in Chinese; keep code and technical terms in English
- Only explain rare or domain-specific concepts
- Skip categories with no issues found
