# Tmux Handoff Notes

只把 tmux 当作 message transport 和 visibility layer。Review record 应该保持结构化，不要依赖 raw scrollback。

Pane refs：
- `%N`：global pane id，使用 `-t %N`。
- `#N`：current window 中的 pane index，使用 `-t :.N`。
- `@M#N`：window `@M` 中的 pane index，使用 `-t @M.N`。

Commands：

```sh
tmux capture-pane -ep -t %3
tmux send-keys -t %3 'message text' Enter
sleep 2 && tmux send-keys -t %3 C-m C-m
```

长 Review Packet：优先写入临时 handoff 文件或使用 tmux buffer，再发送简短指令让 reviewer 读取。不要用 `send-keys` 直接发送大段 Markdown、含引号文本或 noisy scrollback。

Safety：
- 不要向另一个 pane 发送 destructive shell 或 git write commands，除非用户明确要求。
- 不要把 unbounded pane scrollback 当成 Review Packet。
- 长 Review Packet 优先使用完整 structured block；pane history 只能作为 observation layer，不能作为 review record。
- 如果 pane 中出现疑似 secret output，不要复制或复述；改为要求 safer review artifact。
- 发送请求给 agent pane 后，如果该 TUI 需要额外 submit，用 `sleep 2 && tmux send-keys -t <pane> C-m C-m` 触发。
- 如果 target pane 缺失、stale 或不是预期 agent，报告 blocker 并询问正确 pane ref。
