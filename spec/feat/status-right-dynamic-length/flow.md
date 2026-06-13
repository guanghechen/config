# Status Right Dynamic Length Flow Spec

## 1. Scope

Prevent status02 right-side clipping by computing and committing `status-right-length` from rendered right width.

## 2. Boundary

- Input Boundary: rendered `status_right.literal_text`, tmux `status-right-length`, client width.
- Output Boundary: tmux global `status-right-length` option.

## 3. Dataflow State Machine

### States

| State | Owner | Read Set | Write Set | Side Effects |
|-------|-------|----------|-----------|--------------|
| RenderedRight | widgets/composer | widget state + tmux format assumptions | `status_right.literal_text` | none |
| LengthComputed | `status_length` | `status_right.literal_text`, client width | desired `status-right-length` | none |
| LengthCommitted | `commit` | computed length + snapshot option | tmux option plan | `tmux set -g status-right-length` |

### Transitions

| From | To | Trigger | Guard | On Failure |
|------|----|---------|-------|------------|
| RenderedRight | LengthComputed | render/apply | literal available | abort via render error |
| LengthComputed | LengthCommitted | commit planning | option stale | skip if unchanged |

## 4. Failure Path

- retry: next status tick recomputes and commits again.
- rollback: previous tmux option remains if commit fails.
- degrade: static theme seed `84` applies before runtime converges.
- abort: tmux command errors propagate as `AppError`.

## 5. Invariants

- `status-right-length` must never be below the static default `84`.
- Dynamic length must include right-side round/icon glyph placeholders.
- Conditional fullscreen/prefix/bell literals may overestimate but must not underestimate.

## 6. Test Matrix

- Right length grows with rendered right literal width plus padding.
- CommitPlanner writes stale `status-right-length` and skips matching values.
- cache no-op misses when `status-right-length` is stale.
- Pill widgets include glyph placeholders in literal text.

## 7. Open Decisions

| Topic | Options | Owner | Deadline | Blocking | Decision Rule |
|-------|---------|-------|----------|----------|---------------|
