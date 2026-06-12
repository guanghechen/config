# Statusline Runtime Refactor Flow Spec

## 1. Scope

主数据流：`RenderEvent` 进入 Rust renderer，产出 bounded tmux status update。

## 2. Boundary

- Input Boundary: CLI args, tmux snapshot, tmux option cache, platform metrics commands。
- Output Boundary: tmux global/session options, `refresh-client -S`。

## 3. Dataflow State Machine

### States

| State              | Owner               | Read Set                         | Write Set                       | Side Effects              |
|--------------------|---------------------|----------------------------------|---------------------------------|---------------------------|
| EventReceived      | CLI                 | argv                             | RenderEvent                     | none                      |
| SnapshotRead       | TmuxAdapter         | tmux formats/options/sessions    | TmuxSnapshot                    | one tmux read transaction |
| ContextResolved    | StatusRuntime       | TmuxSnapshot                     | RenderContext                   | none                      |
| ComponentsRendered | ComponentRegistry   | RenderContext, ComponentCache    | ComponentOutput list            | optional metrics commands |
| StatusComposed     | StatusComposer      | ComponentOutput list             | RenderedStatus                  | none                      |
| DeltaPrepared      | CommitPlanner       | TmuxSnapshot, RenderedStatus     | TmuxCommandPlan                 | none                      |
| Committed          | TmuxAdapter         | TmuxCommandPlan                  | tmux options/status             | tmux write transaction    |

### Transitions

| From               | To                 | Trigger          | Guard                           | On Failure                 |
|--------------------|--------------------|------------------|----------------------------------|----------------------------|
| EventReceived      | SnapshotRead       | valid event      | event parsed                     | abort with usage error     |
| SnapshotRead       | ContextResolved    | snapshot ok      | status02 active or fallback path | abort current apply        |
| ContextResolved    | ComponentsRendered | layout resolved  | local status not off             | degrade to no-op           |
| ComponentsRendered | StatusComposed     | outputs ready    | required components ok           | keep old statusline        |
| StatusComposed     | DeltaPrepared      | compose ok       | status strings valid             | keep old statusline        |
| DeltaPrepared      | Committed          | plan non-empty   | command within limit             | split commit then retry    |
| DeltaPrepared      | Committed          | plan empty       | no changes                       | no-op                      |

## 4. Failure Path

- retry: tmux write fails with command-length risk -> split command by option and retry once。
- rollback: commit is all-or-previous; no partial semantic rollback required。
- degrade: optional component failure -> stale cache -> hidden -> continue。
- abort: snapshot parse failure, required layout failure, invalid event。

## 5. Invariants

- cache option is bounded by component-defined single-slot payload。
- component never calls tmux directly。
- composer never reads or writes cache。
- commit planner never samples metrics。
- no status refresh path uses shell scripts except the renderer tick trigger。
- `status01` remains fallback when renderer is unavailable or apply fails。

## 6. Test Matrix

| Case                  | Input                         | Expected                         |
|-----------------------|-------------------------------|----------------------------------|
| wide single session   | mode 02, session_count 1      | one row, no session list         |
| narrow multi session  | mode 02, width < 200          | two rows                         |
| local status off      | session-local status off      | no-op                            |
| metrics unsupported   | platform != macOS             | metrics hidden                   |
| metrics command fail  | provider error                | stale value or hidden            |
| cache repeat tick     | unchanged component values    | no cache growth                  |
| delta no-op           | rendered status unchanged     | no tmux write                    |
| command split         | large session list            | write succeeds or clear error    |

## 7. Open Decisions（唯一待定区）

| Topic             | Options                    | Owner   | Deadline | Blocking | Decision Rule              |
|-------------------|----------------------------|---------|----------|----------|----------------------------|
| memory/network native API | command-based / native FFI | primary | later    | false    | only if command cost hurts |
