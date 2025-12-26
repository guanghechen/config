Based on the previous code analysis and review, apply the specified fixes.

## Issues to Apply

``````text
$ARGUMENTS
``````

If no specific issues are provided, apply all actionable issues (Critical and Warning severity) from the previous review.

## Guidelines

- Fix each issue completely before moving to the next
- Keep changes minimal and focused
- Follow existing codebase conventions
- Skip suggestions unless explicitly requested
- If unclear, ask for clarification

Use the `coder` sub-agent for implementation.

## Post-Apply Verification

After applying all fixes:

1. **Re-review** each fixed issue to verify it's properly resolved
2. **Update** the corresponding `.code-analyze/*-cc.md` file:
   - Mark resolved issues as ✅ (prepend to the issue title)
   - Add verification notes if needed
3. **Report** summary of applied fixes and their verification status
