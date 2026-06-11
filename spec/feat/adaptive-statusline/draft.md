# Statusline Consolidation Draft

## 1. Problem Statement

Consolidate tmux statusline modes and keep the adaptive mode that uses two status rows on narrow clients and one status row on wide clients.

## 2. Context and Constraints

- tmux 3.6b supports `status` values `on`, `2`, `3`, `4`, and `5`.
- Only status modes `01/02/11/12` remain loadable; legacy `03/04/13/14` normalize to retained modes.
- Retained mode names are `01`/`02` for top position and `11`/`12` for bottom position.
- Width threshold is 200 columns.
- Theme colors and symbols must be defined in `/Users/wanchenfang/.config/guanghechen/asset/theme/app/tmux.hbs`, then generated with `fish -c "ghc-theme gen && ghc-theme apply"`.

## 3. Open Questions

| Question          | Options                  | Decision               | Rationale                         |
|-------------------|--------------------------|------------------------|-----------------------------------|
| Width threshold   | 160 / 200 / 240          | 200                    | User confirmed                    |
| Layout split      | session-first / window-first | session-first      | User prefers session info first   |
| Mode names        | keep 01/02/11/12         | 01/02/11/12            | Retain top/bottom and compact/adaptive pairs |

## 4. Risk Notes

| Risk                     | Trigger                         | Evidence                       | Impact                         | Mitigation                               |
|--------------------------|---------------------------------|--------------------------------|--------------------------------|------------------------------------------|
| Multi-client width drift | Different clients attach widths | tmux status options are global | Last layout update wins        | Accept for initial implementation        |
| Resize hook churn        | Frequent client resize          | Hook may run repeatedly        | Flicker or extra tmux commands | Cache layout in `@GHC_SL_LAYOUT`         |
| Stale second line        | Switch from status 2 to on      | `status-format[1]` can remain  | Unexpected row if status set 2 | Explicitly set status and format entries |

## 5. Draft Decisions

- Implement `script/status-layout.sh` as the layout owner.
- Use `client_width >= 200` as wide layout.
- Narrow layout line 0: host, current session, current-group session list, and global info.
- Narrow layout line 1: current window, pane, and app info.
- Wide layout line 0: merged info using existing status-left/right plus window list.
