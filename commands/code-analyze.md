Please perform a comprehensive code review on the following target.

## Review Target

``````text
$ARGUMENTS
``````

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

Example:
```
### 1. Logic Errors

#### 1.1 [Critical] Off-by-one error in loop
- **Location**: `src/utils.ts:42`
- **Description**: ...
- **Recommendation**: ...

#### 1.2 [Warning] Unhandled edge case
- **Location**: `src/utils.ts:58`
- **Description**: ...
- **Recommendation**: ...

### 2. Performance Issues

#### 2.1 [Warning] N+1 query pattern
- **Location**: `src/api/users.ts:23-30`
- **Description**: ...
- **Recommendation**: ...
```

Style:
- Respond in Chinese, but keep technical terms and code in English
- Only explain rare or domain-specific concepts
- Skip categories with no issues found

## Output Requirement

1. **Display the full review output in the conversation** (stdout)
2. **Simultaneously save** a copy to `{cwd}/.code-analyze/{simple-title}-cc.md`, where `{simple-title}` is a concise kebab-case title derived from the review target (e.g., `user-auth-service`, `payment-controller`)
