Please perform a comprehensive code review on the following target.

## Review Target

``````text
$ARGUMENTS
``````

**Mode Detection**:
- If the argument is a `.code-analyze/*.md` file path, enter **Re-analyze Mode**
- Otherwise, enter **New Analysis Mode**

### Re-analyze Mode

When given an existing `.code-analyze/*.md` file:
1. Read the file to extract the original review target and issues
2. Re-analyze the same target to check:
   - Which previously identified issues are now **fixed** (mark with ✅)
   - Which issues **remain unfixed**
   - Any **new issues** introduced since the last review
3. **Preserve** all issue resolution statuses (see below)
4. **Rewrite** the file with updated analysis results

## Review Focus Areas

Analyze the code systematically with emphasis on the following aspects:

### 1. Logic Errors
- Check for incorrect conditional logic, off-by-one errors, boundary conditions
- Verify edge cases are handled properly
- Ensure control flow is correct and all branches are reachable
- Look for race conditions or concurrency issues

### 2. Performance Issues
- Identify unnecessary computations or redundant operations
- Check for N+1 queries or inefficient database access patterns
- Look for expensive operations inside loops
- Evaluate algorithm complexity and suggest optimizations where needed

### 3. Memory Leaks
- Check for proper cleanup of resources (event listeners, subscriptions, timers)
- Identify potential memory accumulation (growing arrays, caches without eviction)
- Verify proper disposal patterns in components/objects lifecycle
- Look for circular references that may prevent garbage collection

### 4. Deprecated APIs
- Identify usage of deprecated language features or library APIs
- Check for outdated patterns that have better modern alternatives
- Verify compatibility with current runtime/framework versions

### 5. Code Organization
- Evaluate logical ordering of code elements (imports, constants, types, functions)
- Check for proper separation of concerns
- Verify related code is grouped together meaningfully
- Ensure public API comes before private implementation details

### 6. Code Style & Conventions
- Verify adherence to project coding standards
- Check naming conventions (including `I`-prefixed interfaces/types)
- Ensure consistent formatting and structure
- Look for code duplication that should be refactored

## Output Format

Group issues by category using hierarchical numbering (e.g., `1.1`, `1.2`, `2.1`), where the first digit represents the category number from Review Focus Areas above.

For each issue, provide:
- **Location**: File path and line number(s)
- **Severity**: Critical / Warning / Suggestion
- **Description**: Clear explanation of the issue
- **Recommendation**: How to fix or improve
- **Status Tag** (for resolved issues): Prepend a semantic Nerd Font icon before the status label: `󰄬 [fixed]` (bug fix), `󰄬 [done]` (TODO completed), `󰜺 [Won't Fix]` (deferred), `󰛨 [By Design]` (intentional), `󱙝 [False Alarm]` (not a real issue)

Example:
```
### 1. Logic Errors

####  [fixed] 1.1 [Critical] Off-by-one error in loop
- **Location**: `src/utils.ts:42`
- **Description**: ...
- **Recommendation**: ...

####  [Won't Fix] 1.2 [Warning] Unhandled edge case
- **Location**: `src/utils.ts:58`
- **Description**: ...
- **Recommendation**: ...

####  [By Designed] 1.3 [Warning] ~by design~ Missing null check
- **Location**: `src/utils.ts:75`
- **Description**: ...
- **Recommendation**: ...

####  [fixed] 1.4 [Critical] Bug fix applied for null pointer
- **Location**: `src/service.ts:12`
- **Description**: ...
- **Recommendation**: ...

####  [done] 1.5 [Suggestion] Completed TODO: add retry guard
- **Location**: `src/client.ts:30`
- **Description**: ...
- **Recommendation**: ...

### 2. Performance Issues

#### 2.1 [Warning] ~won't fix~ N+1 query pattern
- **Location**: `src/api/users.ts:23-30`
- **Description**: ...
- **Recommendation**: ...
```

## Issue Resolution Statuses

Issues can be marked with the following statuses (applied via `/code-apply`):

| Status      | Heading Tag        | Marker Format              | Meaning                                                    |
| ----------- | ------------------ | -------------------------- | ---------------------------------------------------------- |
| Fixed       | `󰄬 [fixed]`        | `✅` prefix                | Issue closed by explicit bug fix                           |
| Done (TODO) | `󰄬 [done]`         | Headline tag only          | Issue closed by completing prior TODO                      |
| By Design   | `󰛨 [By Designed]`  | `~by design~` after number | Intentional behavior; suppress in future re-analysis       |
| Won't Fix   | `󰜺 [Won't Fix]`    | `~won't fix~` after number | Known issue, accepted risk or deferred                     |
| False Alarm | `󱙝 [False Alarm]`  | `~false alarm~` after num  | Not a real issue; exclude from future re-analysis          |

**Re-analyze Behavior**:
- `󰄬 [fixed]`: Re-verify the fix is effective; remove marker if issue reappears
- `󰄬 [done]`: Confirm TODO is completed; remove marker if not done
- `󰛨 [By Design]`: Preserve marker; do NOT re-report
- `󰜺 [Won't Fix]`: Preserve marker; do NOT re-report
- `󱙝 [False Alarm]`: Preserve marker; do NOT re-report

Style:
- Respond in Chinese, but keep technical terms and code in English
- Only explain rare or domain-specific concepts
- Skip categories with no issues found

## Output Requirement

### New Analysis Mode
1. **Display the full review output in the conversation** (stdout)
2. **Simultaneously save** a copy to `{cwd}/.code-analyze/{simple-title}-cc.md`, where `{simple-title}` is a concise kebab-case title derived from the review target (e.g., `user-auth-service`, `payment-controller`)

### Re-analyze Mode
1. **Display the full updated review output in the conversation** (stdout)
2. **Rewrite** the specified `.code-analyze/*.md` file with the updated analysis
