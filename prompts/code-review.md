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

## Output

For each issue found, provide:
1. **Location**: File path and line number(s)
2. **Category**: Which review focus area it belongs to
3. **Severity**: Critical / Warning / Suggestion
4. **Description**: Clear explanation of the issue
5. **Recommendation**: How to fix or improve

Style:
- Respond in Chinese, but keep technical terms and code in English
- Only explain rare or domain-specific concepts
