# ADO Skill Reference

## WIQL Query Syntax

```sql
SELECT [fields] FROM WorkItems WHERE [conditions] ORDER BY [field]
```

### Common Fields

| Field                              | Description  |
| ---------------------------------- | ------------ |
| `[System.Id]`                      | ID           |
| `[System.Title]`                   | Title        |
| `[System.State]`                   | State        |
| `[System.WorkItemType]`            | Type         |
| `[System.AssignedTo]`              | Assigned To  |
| `[System.CreatedBy]`               | Created By   |
| `[System.CreatedDate]`             | Created Date |
| `[System.ChangedDate]`             | Changed Date |
| `[System.AreaPath]`                | Area Path    |
| `[System.IterationPath]`           | Iteration    |
| `[System.Tags]`                    | Tags         |
| `[Microsoft.VSTS.Common.Priority]` | Priority     |

### Date Macros

| Macro           | Description    |
| --------------- | -------------- |
| `@today`        | Today          |
| `@today - N`    | N days ago     |
| `@startOfWeek`  | Start of week  |
| `@startOfMonth` | Start of month |
| `@me`           | Current user   |

### Examples

```bash
# My active items
az boards query --wiql "SELECT [System.Id], [System.Title] FROM WorkItems WHERE [System.AssignedTo] = @me AND [System.State] <> 'Closed'" --org <ORG>

# Recent bugs
az boards query --wiql "SELECT [System.Id], [System.Title] FROM WorkItems WHERE [System.WorkItemType] = 'Bug' AND [System.CreatedDate] >= @today - 7" --org <ORG>

# Items with tag
az boards query --wiql "SELECT [System.Id], [System.Title] FROM WorkItems WHERE [System.Tags] CONTAINS 'TagName'" --org <ORG>
```

---

## REST API

All `az rest` calls require: `--resource "499b84ac-1321-427f-aa17-267ca6975798"`

### Build Operations

```bash
# Timeline
az rest --method get \
  --url "https://dev.azure.com/<ORG>/<PROJECT>/_apis/build/builds/<BUILD_ID>/timeline?api-version=7.1" \
  --resource "499b84ac-1321-427f-aa17-267ca6975798"

# Specific log
az rest --method get \
  --url "https://dev.azure.com/<ORG>/<PROJECT>/_apis/build/builds/<BUILD_ID>/logs/<LOG_ID>?api-version=7.1" \
  --resource "499b84ac-1321-427f-aa17-267ca6975798"
```

### PR Operations

```bash
# Comment threads
az rest --method get \
  --url "https://dev.azure.com/<ORG>/<PROJECT>/_apis/git/repositories/<REPO>/pullrequests/<PR_ID>/threads?api-version=7.1" \
  --resource "499b84ac-1321-427f-aa17-267ca6975798"
```

### Work Item Operations

```bash
# Add comment
az rest --method post \
  --url "https://dev.azure.com/<ORG>/<PROJECT>/_apis/wit/workitems/<ID>/comments?api-version=7.0-preview" \
  --headers "Content-Type=application/json" \
  --body '{"text": "Comment"}' \
  --resource "499b84ac-1321-427f-aa17-267ca6975798"
```

### Test Results

```bash
# Test runs for build
az rest --method get \
  --url "https://dev.azure.com/<ORG>/<PROJECT>/_apis/test/runs?buildId=<BUILD_ID>&api-version=7.1-preview" \
  --resource "499b84ac-1321-427f-aa17-267ca6975798"

# Failed tests
az rest --method get \
  --url "https://dev.azure.com/<ORG>/<PROJECT>/_apis/testresults/runs/<RUN_ID>/results?outcomes=Failed&api-version=7.2-preview.1" \
  --resource "499b84ac-1321-427f-aa17-267ca6975798"
```

---

## Configuration

Set defaults to avoid repetition:

```bash
az devops configure --defaults organization=https://dev.azure.com/<ORG> project=<PROJECT>
az devops configure --list
```

---

## Troubleshooting

| Error                                         | Solution                    |
| --------------------------------------------- | --------------------------- |
| `TF401019: Git repository does not exist`     | Check repo name and project |
| `TF400813: User is not authorized`            | Check permissions, re-login |
| `AADSTS70002: Error validating credentials`   | Token expired, `az login`   |

```bash
# Re-authenticate
az login

# Verify account
az account show

# Check extension
az extension list | grep devops
```
