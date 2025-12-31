Apply fixes based on the previous code analysis.

## Issues to Apply

``````text
$ARGUMENTS
``````

If no specific issues are provided, apply all actionable issues (Critical and Warning severity) from the previous review.

## Examples

1. Apply all sub-issues under #1 (i.e., #1.1, #1.2, #1.x, etc.):
   ```
   /code-apply #1
   ```

2. Apply only issue #1.2:
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

   - **by design**: Intentional behavior → stored in `baseline.md`
   - **won't fix**: Acknowledged issue, deferred → stays in analysis file
   - **false alarm**: Not a real issue → stays in analysis file
   - **custom context**: Additional instructions override the original recommendation

## Guidelines

- Fix each issue completely before moving to the next
- Keep changes minimal and focused
- Follow existing codebase conventions
- Skip suggestions unless explicitly requested
- If unclear, ask for clarification

Use the `coder` sub-agent for implementation.

## Post-Apply Verification

After applying all fixes:

1. **Re-review** each fixed issue to verify proper resolution
2. **Update files** based on resolution status:

| Status      | Marker                       | Stored In                             |
| ----------- | ---------------------------- | ------------------------------------- |
| Fixed       | `󰄬 ~~[fixed] ...~~`          | analysis file (`codex.md`)            |
| Done        | `󰄬 ~~[done] ...~~`           | analysis file (`codex.md`)            |
| By Design   | `󰛨 ~~[By Design] ...~~`      | **`baseline.md`** (permanent)         |
| Won't Fix   | `󰜺 ~~[Won't Fix] ...~~`      | analysis file (`codex.md`)            |
| False Alarm | `󱙝 ~~[False Alarm] ...~~`    | analysis file (`codex.md`)            |

3. **Report** summary using the table format below

## Summary Table

Provide summary tables after applying changes:

```markdown
## Summary

### Issues Processed

| Category           | Critical | Warning | Suggestion | Total |
| ------------------ | -------- | ------- | ---------- | ----- |
| 1. Logic Errors    | 1        | 1       | 0          | 2     |
| 2. Performance     | 0        | 1       | 0          | 1     |
| **Total**          | **1**    | **2**   | **0**      | **3** |

### Resolution Status

| Status      | Count |
| ----------- | ----- |
| Fixed       | 2     |
| By Design   | 1     |
| Won't Fix   | 0     |
| False Alarm | 0     |
```

- Skip rows for categories/statuses with 0 count (except **Total** row)

## Output Requirement

1. **Display** the summary in the conversation
2. **Update** the analysis file (`.code-analyzer/{topic}/codex.md`) with resolution markers
3. **Append to `baseline.md`** if any issues marked as By Design (create file if not exists)

## Style

- Respond in Chinese (简体中文); keep code and technical terms in English
- Only explain rare or domain-specific concepts
