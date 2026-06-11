# Statusline Consolidation Flow Spec

## 1. Scope

Adaptive rendering for tmux status modes `02` and `12`.

## 2. Boundary

- Input Boundary: `@GHC_SL_MODE`, `#{client_width}`, current session/window/pane formats.
- Output Boundary: tmux `status`, `status-format[0]`, `status-format[1]`, `status-left`, `status-right`, and `@GHC_SL_LAYOUT` options.

## 3. Dataflow State Machine

### States

| State              | Owner              | Read Set                         | Write Set                                      | Side Effects                |
|--------------------|--------------------|----------------------------------|------------------------------------------------|-----------------------------|
| ModeLoaded         | `load-theme.sh`    | `@GHC_SL_MODE`                   | `status-position`, `status-justify`            | Source adaptive status file |
| WidthDetected      | `status-layout.sh` | `#{client_width}`                | local `layout_mode`                            | None                        |
| LayoutSelected     | `status-layout.sh` | local `layout_mode`, cached mode | `status`, `@GHC_SL_LAYOUT`, `status-format[]`  | tmux option updates         |
| StatusRendered     | tmux renderer      | `status-format[]`, theme options | terminal status area                           | Statusline redraw           |

### Transitions

| From           | To             | Trigger                   | Guard                         | On Failure                  |
|----------------|----------------|---------------------------|-------------------------------|-----------------------------|
| ModeLoaded     | WidthDetected  | theme load / resize hook  | mode is `02` or `12`          | Keep existing status mode   |
| WidthDetected  | LayoutSelected | width read succeeds       | width is numeric              | Degrade to wide layout      |
| LayoutSelected | StatusRendered | options changed           | tmux accepts status settings  | Keep previous status format |

## 4. Failure Path

- retry: Resize hook can run again on the next client resize.
- rollback: Set `@GHC_SL_MODE` back to `01` or `11` and reload theme.
- degrade: If width is unavailable, use one-line wide layout.
- abort: If tmux rejects config during validation, do not source changed files.

## 5. Invariants

- Modes `01` and `11` use compact one-line layout; modes `02` and `12` use adaptive layout.
- `status` is `on` for wide layout and `2` for narrow layout.
- `status-format[1]` is explicitly set for adaptive mode.
- Layout changes are no-op when the cached `@GHC_SL_LAYOUT` value already matches.

## 6. Test Matrix

| Case              | Input                         | Expected                         |
|-------------------|-------------------------------|----------------------------------|
| Wide top          | mode `02`, width `>=200`      | `status on`, top position        |
| Narrow top        | mode `02`, width `<200`       | `status 2`, top position         |
| Wide bottom       | mode `12`, width `>=200`      | `status on`, bottom position     |
| Narrow bottom     | mode `12`, width `<200`       | `status 2`, bottom position      |
| Existing mode     | mode `01`                     | Existing status01 behavior       |

## 7. Open Decisions

| Topic | Options | Owner | Deadline | Blocking | Decision Rule |
|-------|---------|-------|----------|----------|---------------|
