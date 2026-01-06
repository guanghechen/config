---
description: Create a PR for current branch
---

Please create a PR for the current branch. Generate a reasonable PR title based on the changes rather than using a default one.

## Arguments (Optional)

``````text
$ARGUMENTS
``````

## Workflow

1. **Analyze changes**: Review all commits on the current branch compared to the base branch
2. **Generate PR title**: Create a concise, descriptive title that summarizes the changes
3. **Generate PR body**: Include:
   - Summary of changes
   - Any breaking changes
   - Testing notes if applicable
4. **Create PR**: Use `gh pr create` with the generated title and body
