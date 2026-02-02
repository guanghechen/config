---
name: ado
description: Azure DevOps integration for work items, PRs, builds, and releases. Triggered by ADO URLs or ADO-related queries.
argument-hint: '[url | id | action]'
---

# Azure DevOps (ADO) Skill

Interact with Azure DevOps via `az boards`, `az repos`, `az pipelines`, and `az rest`.

## Requirements

- Logged in via `az login`
- Extension installed: `az extension add --name azure-devops`
- **Use English for all outputs and modifications**
- **Write operations require explicit user approval before execution**

## Arguments

- `<url>` — ADO URL (auto-detects resource type)
- `<id>` — Work item ID (numeric)
- `<action>` — Commands like `query bugs`, `my tasks`, `pr 123`

---

## Work Items

```bash
# View
az boards work-item show --id <ID> --org <ORG>

# Query (WIQL)
az boards query --wiql "SELECT [System.Id], [System.Title] FROM WorkItems WHERE [System.AssignedTo] = @me AND [System.State] <> 'Closed'" --org <ORG>

# Update
az boards work-item update --id <ID> --state "Resolved" --org <ORG>
az boards work-item update --id <ID> --discussion "Comment" --org <ORG>

# Create
az boards work-item create --type Bug --title "Title" --project <PROJECT> --org <ORG>
```

---

## Pull Requests

```bash
# View
az repos pr show --id <PR_ID> --org <ORG>

# List
az repos pr list --status active --top 10 --org <ORG> --project <PROJECT>

# Get comments (REST API)
az rest --method get \
  --url "https://dev.azure.com/<ORG>/<PROJECT>/_apis/git/repositories/<REPO>/pullrequests/<PR_ID>/threads?api-version=7.1" \
  --resource "499b84ac-1321-427f-aa17-267ca6975798"
```

Note: `az repos pr list` does not support `@me`. Use actual email.

---

## Builds

```bash
# View
az pipelines build show --id <BUILD_ID> --org <ORG> --project <PROJECT>

# List
az pipelines build list --top 10 --org <ORG> --project <PROJECT>

# Queue
az pipelines build queue --definition-id <DEF_ID> --branch <BRANCH> --org <ORG> --project <PROJECT>

# Get logs (REST API)
az rest --method get \
  --url "https://dev.azure.com/<ORG>/<PROJECT>/_apis/build/builds/<BUILD_ID>/logs?api-version=7.1" \
  --resource "499b84ac-1321-427f-aa17-267ca6975798"
```

---

## Releases

```bash
# View
az pipelines release show --id <RELEASE_ID> --org <ORG> --project <PROJECT>

# List
az pipelines release list --org <ORG> --project <PROJECT>
```

---

## URL Patterns

| Pattern                           | Type      |
| --------------------------------- | --------- |
| `/_workitems/edit/<id>`           | Work Item |
| `/_git/<repo>/pullrequest/<id>`   | PR        |
| `/_build/results?buildId=<id>`    | Build     |
| `/_releaseProgress?releaseId=<id>`| Release   |

Supported formats:
- `https://dev.azure.com/<org>` (new)
- `https://<org>.visualstudio.com` (legacy)

---

## Output Format

Display results as markdown tables:

| Field       | Value           |
| ----------- | --------------- |
| ID          | {id}            |
| Type        | {workItemType}  |
| Title       | {title}         |
| State       | {state}         |
| Assigned To | {assignedTo}    |

---

## Error Handling

If commands fail, verify:
1. Logged in (`az login`)
2. Has project access
3. Correct organization URL

---

## Write Operations (Require Approval)

**Always ask for user confirmation before executing these commands:**

| Command | Action |
|---------|--------|
| `az boards work-item update` | Modify work item state/fields |
| `az boards work-item create` | Create new work item |
| `az pipelines build queue` | Trigger pipeline build |
| `az rest --method post/patch` | Add comments, modify resources |

See [reference.md](reference.md) for advanced usage.
