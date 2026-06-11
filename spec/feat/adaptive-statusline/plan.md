# Statusline Consolidation Implementation Plan

## 1. Scope Mapping

| Design Ref      | Design Source | Code Target                                      | Test Target              |
|-----------------|---------------|--------------------------------------------------|--------------------------|
| Adaptive modes  | arch.md       | `script/load-theme.sh`                           | tmux parse validation    |
| Layout selector | flow.md       | `script/status-layout.sh`                        | bash syntax validation   |
| Status formats  | arch.md       | `conf/theme/status02.tmux.conf`                  | tmux parse validation    |
| Theme variables | arch.md       | `/Users/wanchenfang/.config/guanghechen/asset/theme/app/tmux.hbs` | `ghc-theme gen/apply` |

## 2. Work Breakdown

| Step | Design Ref      | Change Area                 | Inputs        | Outputs            | Verification                 | Code Target                 |
|------|-----------------|-----------------------------|---------------|--------------------|------------------------------|-----------------------------|
| 1    | Theme variables | theme template              | color names   | generated variables | `ghc-theme gen && apply`     | `tmux.hbs`                  |
| 2    | Status formats  | adaptive status theme       | existing vars | status02 formats   | tmux source-file validation  | `status02.tmux.conf`        |
| 3    | Layout selector | shell script                | client width  | status row count   | `bash -n`                    | `status-layout.sh`          |
| 4    | Mode loading    | theme loader                | mode `02/12`  | adaptive load path | tmux source-file validation  | `load-theme.sh`             |

## 3. Acceptance Criteria

- `@GHC_SL_MODE=02` supports top adaptive statusline.
- `@GHC_SL_MODE=12` supports bottom adaptive statusline.
- Width `>=200` uses one status row.
- Width `<200` uses two status rows.
- Existing modes continue to parse.

## 4. Rollback Plan

- Set `@GHC_SL_MODE` to `01` or `11`.
- Revert `status02.tmux.conf`, `status-layout.sh`, `load-theme.sh`, and `tmux.hbs` changes.

## 5. Progress

| Step | Status  | Notes                    |
|------|---------|--------------------------|
| 1    | done    | Added status02 theme variables |
| 2    | done    | Added adaptive status02 formats |
| 3    | done    | Added width-based layout script |
| 4    | done    | Added 02/12 load and toggle paths |
