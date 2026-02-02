# ADO Skill Examples

## View Work Item

```
/ado https://dev.azure.com/myorg/myproject/_workitems/edit/12345
/ado 12345
```

```bash
az boards work-item show --id 12345 --org https://dev.azure.com/myorg
```

---

## Query Work Items

```
/ado my tasks
/ado query bugs
```

```bash
az boards query --wiql "SELECT [System.Id], [System.Title], [System.State] FROM WorkItems WHERE [System.AssignedTo] = @me AND [System.State] <> 'Closed'" --org <ORG>
```

---

## View PR

```
/ado pr 456
/ado https://dev.azure.com/myorg/myproject/_git/repo/pullrequest/456
```

```bash
az repos pr show --id 456 --org <ORG>
```

---

## View Build

```
/ado https://dev.azure.com/myorg/myproject/_build/results?buildId=789
```

```bash
az pipelines build show --id 789 --org https://dev.azure.com/myorg --project myproject
```

---

## Get Build Logs

```
/ado logs 789
```

```bash
az rest --method get \
  --url "https://dev.azure.com/<ORG>/<PROJECT>/_apis/build/builds/789/logs?api-version=7.1" \
  --resource "499b84ac-1321-427f-aa17-267ca6975798"
```

---

## Update Work Item

```
/ado update 12345 state=Resolved
```

```bash
az boards work-item update --id 12345 --state Resolved --org <ORG>
```

---

## Queue Build

```
/ado trigger build MyPipeline on main
```

```bash
az pipelines build queue --definition-name MyPipeline --branch refs/heads/main --org <ORG> --project <PROJECT>
```

---

## URL Parsing

| URL Pattern                                                   | Parsed As |
| ------------------------------------------------------------- | --------- |
| `https://dev.azure.com/org/project/_workitems/edit/123`       | Work Item |
| `https://dev.azure.com/org/project/_git/repo/pullrequest/456` | PR        |
| `https://dev.azure.com/org/project/_build/results?buildId=789`| Build     |
| `https://org.visualstudio.com/project/_workitems/edit/123`    | Work Item |
