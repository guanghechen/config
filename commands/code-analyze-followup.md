Perform a follow-up analysis after completing fixes for previously identified issues.

## Analysis Topic

``````text
$ARGUMENTS
``````

## Purpose

This command is used when you have already addressed most issues from a previous code analysis and want to:
1. Re-analyze the same topic with fresh perspective
2. Leverage existing resolution records to reduce false positives
3. Update stale file paths and line ranges due to code changes
4. Discover any new issues introduced during fixes

## Workflow

### Step 1: Locate Previous Analysis

Search for existing `.code-analyze/*-cc.md` files related to the given topic:
- Match by topic keywords in filename or content
- If multiple matches found, list them and ask user to select
- If no match found, inform user and suggest using `/code-analyze` instead

### Step 2: Parse Existing Records

From the previous analysis file, extract:

1. **Original review target** - The files/directories/scope that was analyzed
2. **Preserved resolution statuses** - Issues marked with:
   - `󰛨 [By Designed]` / `~by design~`
   - `󰜺 [Won't Fix]` / `~won't fix~`
   - `󱙝 [False Alarm]` / `~false alarm~`

3. **Fixed/Done issues** - For reference only (will be re-verified):
   - `󰄬 [fixed]` / `✅` prefix
   - `󰄬 [done]`

### Step 3: Validate and Update Records

For each preserved issue (By Design / Won't Fix / False Alarm):

1. **Check if code still exists**:
   - If the file is deleted → Remove the record entirely
   - If the specific code block is deleted → Remove the record entirely

2. **Update stale locations**:
   - Use semantic matching (function names, variable names, code patterns) to relocate issues
   - Update `**Location**` field with new `filepath:line` or `filepath:line-range`
   - If code has moved to a different file, update the file path

3. **Keep the issue content intact** - Do not modify description or recommendation

### Step 4: Perform Fresh Analysis

Re-analyze the original target with:
- Full scope as defined in Step 1
- Same review focus areas as `/code-analyze`
- **Suppress** issues that match preserved records (By Design / Won't Fix / False Alarm)

### Step 5: Generate Output

Produce a comprehensive report that includes:

1. **Preserved Issues** (collapsed section):
   - List all By Design / Won't Fix / False Alarm issues with updated locations
   - These are retained for future follow-ups but not flagged as actionable

2. **New Issues Found**:
   - Any newly discovered issues from the fresh analysis
   - Grouped by category with standard formatting

3. **Summary**:
   - Count of preserved issues (by type)
   - Count of new issues (by severity)
   - Count of records removed (due to deleted code)

## Output Format

```markdown
# Code Analysis Follow-up: {topic}

> Re-analyzed: {original-target}
> Previous analysis: {previous-file-path}
> Date: {current-date}

## Summary

### New Issues

| Category           | Critical | Warning | Suggestion | Total |
| ------------------ | -------- | ------- | ---------- | ----- |
| 1. Logic Errors    | 0        | 1       | 0          | 1     |
| 2. Performance     | 0        | 0       | 1          | 1     |
| **Total**          | **0**    | **1**   | **1**      | **2** |

### Preserved & Removed

| Status          | Count |
| --------------- | ----- |
| By Design       | X     |
| Won't Fix       | X     |
| False Alarm     | X     |
| Records Removed | X     |

---

## New Issues

### 1. Logic Errors

#### 1.1 [Critical] New issue title
- **Location**: `src/file.ts:42`
- **Description**: ...
- **Recommendation**: ...

### 2. Performance Issues
...

---

<details>
<summary>📋 Preserved Issues (X items) - Click to expand</summary>

### By Design (X)

#### 󰛨 [By Designed] Original issue title
- **Location**: `src/file.ts:58` ← Updated from line 45
- **Description**: ...
- **Reason**: (if provided)

### Won't Fix (X)

#### 󰜺 [Won't Fix] Original issue title
- **Location**: `src/file.ts:72`
- **Description**: ...
- **Reason**: (if provided)

### False Alarm (X)

#### 󱙝 [False Alarm] Original issue title
- **Location**: `src/file.ts:90` ← Updated from line 85
- **Description**: ...
- **Reason**: (if provided)

</details>
```

## Output Requirement

1. **Display** the full report in the conversation (stdout)
2. **Overwrite** the original `.code-analyze/*-cc.md` file with the updated analysis

## Style

- Respond in Chinese, keep code and technical terms in English
- Only explain rare or domain-specific concepts
- Skip categories with no issues
