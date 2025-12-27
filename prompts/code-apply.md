Based on the previous code analysis and review, apply the specified fixes.

## Issues to Apply

``````text
$ARGUMENTS
``````

If no specific issues are provided, apply all actionable issues (Critical and Warning severity) from the previous review.

## Examples

1. Apply fixes for all sub-issues under #1 (i.e., #1.1, #1.2, #1.x, etc.)

    ```
    /code-apply #1
    ```

2. Apply fix only for issue #1.2, ignoring other issues

    ```
    /code-apply #1.2
    ```

3. Mark issues with resolution status or provide additional context:

    ```
    /code-apply
    1. #1.1 by design
    2. #1.2 won't fix
    3. #1.3 false alarm
    4. #3.2 use memoization instead of caching the entire result
    ```

    - **by design**: The behavior is intentional; suppress future reports
    - **won't fix**: Acknowledged issue, but deferring or accepting the risk
    - **false alarm**: Not a real issue; mark to prevent future detection
    - **custom context**: Additional instructions take priority over the original recommendation

## Guidelines

- Fix each issue completely before moving to the next
- Keep changes minimal and focused
- Follow existing codebase conventions
- Skip suggestions unless explicitly requested
- If unclear, ask for clarification

If sub-agents are supported, use the `coder` agent. Otherwise, follow `$XDG_CONFIG_HOME/claude/agents/coder.md`.

## Post-Apply Verification

After applying all fixes:

1. **Re-review** each fixed issue to verify it's properly resolved
2. **Update** the corresponding `.code-analyze/*-codex.md` file:
   - Mark resolved issues as ✅ (prepend to the issue title)
   - Add verification notes if needed
3. **Report** summary of applied fixes and their verification status
