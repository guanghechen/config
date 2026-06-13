# Status Right Dynamic Length Draft

## 1. Problem Statement

`status-right-length` is still the static theme seed (`84`). When fullscreen adds the zoom pill, tmux can clip the right edge and hide seconds in `%H:%M:%S`.

## 2. Context and Constraints

- `status-left-length` is already dynamically planned from faithful `status_left.literal_text`.
- `status_right.literal_text` currently undercounts round/icon glyphs and conditional pills.
- `status-right-length` is a maximum, not padding; overestimation is safe, underestimation clips.

## 3. Decisions

| Question | Options | Decision | Rationale |
|----------|---------|----------|-----------|
| Length source | static bump / dynamic literal | dynamic literal | avoids future right-side clipping as widgets grow |
| Conditional widgets | exact snapshot / pessimistic literal | pessimistic literal | tmux format state like `window_zoomed_flag` is not in snapshot; overestimate is safe |
| Literal helper | duplicate constants / shared helper | shared `widget::pill` helper | keeps rich/literal width shape consistent across right-side pills |

## 4. Risk Notes

| Risk | Trigger | Evidence | Impact | Mitigation |
|------|---------|----------|--------|------------|
| Over-reserved right length | conditional pills hidden | pessimistic literal includes fullscreen/prefix | harmless because length is max | cap at client width and keep static floor |
| Literal drift | future pill shape changes | hand-maintained rich/literal shadows | clipping regression | centralize pill literal helper and tests |

## 5. Draft Decisions

Implement faithful/pessimistic right literal width and dynamic `status-right-length` in the runtime planner.
