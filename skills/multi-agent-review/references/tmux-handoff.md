# Tmux Handoff Notes

把 tmux 当作 review 的 message transport 和 visibility layer。Review record 必须保持结构化，不要依赖 raw scrollback。

tmux transport conventions —— pane ref（`%N`/`#N`/`@M#N`）、`send-keys`、tmux buffer、`sleep 2 && C-m C-m` 触发、以及 pane 安全与「不猜测 / 不扫描 / 不自动选择 pane」等发送规则 —— 见 `tmux-pane-collab` skill，本文件不再重复。

Review-specific notes：
- 不要把 unbounded pane scrollback 当成 Review Packet。
- 长 Review Packet 用完整 structured block 发送，pane history 只作为 observation layer，不作为 review record。
- 如果 pane 中出现疑似 secret output，不要复制或复述到 review record；改为要求 safer review artifact。
- 如果 target pane 缺失、stale 或不是预期 agent，先报告 blocker 并询问正确 pane ref，再继续 review handoff。
