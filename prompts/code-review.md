Review code changes or verify fixes from previous analysis.

## Review Target

``````text
$ARGUMENTS
``````

## Mode Detection

- If argument references a `.code-analyze/*.md` file or previous analysis → **Verification Mode**
- Otherwise → **Review Mode**

## Review Mode

Perform a focused code review on the specified target:
- Check for bugs, logic errors, edge cases
- Identify potential regressions
- Assess code quality and conventions

## Verification Mode

Verify fixes from a previous `/code-analyze`:
1. Locate the previous analysis (file path, topic keyword, or recent conversation)
2. Check each issue: properly fixed / partially fixed / not fixed / regressed
3. Identify any new issues introduced

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
2. **Update** `.code-analyze/*-codex.md` if in Verification Mode

## Style

- Respond in Chinese; keep code and technical terms in English
- Use `file:line` format for locations
- Skip sections with no items
