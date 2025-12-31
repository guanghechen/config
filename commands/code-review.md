Review code changes or verify fixes from previous analysis.

## Review Target

``````text
$ARGUMENTS
``````

## Mode Detection

- If argument references a `.code-analyzer/{topic}/` directory or previous analysis → **Verification Mode**
- Otherwise → **Review Mode**

## Review Mode

Perform a focused code review on the specified target:
- Check for bugs, logic errors, edge cases
- Identify potential regressions
- Assess code quality and conventions
- Read `baseline.md` if exists; suppress documented By Design issues

## Verification Mode

Verify fixes from a previous `/code-analyze`:
1. Read `baseline.md` to get By Design decisions (permanently suppressed)
2. Read analysis file to get previous issues
3. Check each issue: properly fixed / partially fixed / not fixed / regressed
4. Identify any new issues introduced (excluding By Design in baseline)

## Summary Table

```markdown
## Summary

| Status         | Count |
| -------------- | ----- |
| Verified       | 3     |
| Remaining      | 1     |
| New Issues     | 0     |
```

## Output Requirement

1. **Display** the report in the conversation
2. **Update** `.code-analyzer/{topic}/cc.md` if in Verification Mode

## Style

- Respond in Chinese (简体中文); keep code and technical terms in English
- Use `file:line` format for locations
- Skip sections with no items
