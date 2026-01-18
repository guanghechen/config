# Tmux Pane Debugging Guide

本指南介绍如何使用 tmux pane 进行调试，适用于需要在后台运行长时间任务并实时观察输出的场景。

## Why tmux pane?

| 优势             | 说明                                                     |
| ---------------- | -------------------------------------------------------- |
| 非阻塞           | Agent 可以在等待任务完成的同时执行其他操作               |
| 可观察           | 通过 `tmux capture-pane` 随时查看输出，了解当前进度      |
| 可复用           | 同一个 pane 可以多次运行不同任务                         |
| 错误排查         | 出现问题时可以看到完整的输出日志                         |

## Basic Commands

### 查看当前 tmux panes

```bash
tmux list-panes -a -F "#{pane_id} #{session_name}:#{window_index}.#{pane_index}"
```

### 在指定 pane 中运行命令

```bash
# %x 是 pane id（如 %10, %11 等）
tmux send-keys -t %x 'your-command-here' Enter
```

### 查看 pane 输出

```bash
# 捕获 pane 当前可见内容（带 ANSI 颜色）
tmux capture-pane -ep -t %x

# 捕获完整历史（包括滚动缓冲区）
tmux capture-pane -ep -t %x -S -
```

### 等待并检查

```bash
# 等待一段时间后检查输出
sleep 60 && tmux capture-pane -ep -t %x
```

## Example: Long-running Task

```bash
# 1. 在 pane 中启动任务
tmux send-keys -t %x 'long-running-command' Enter

# 2. 定期检查状态
tmux capture-pane -ep -t %x | tail -20

# 3. 等待完成后读取结果
cat /path/to/output/file
```

## Tips

- **选择空闲的 pane**: 确保目标 pane 没有正在运行的任务
- **使用绝对路径**: 在 `send-keys` 中使用绝对路径避免路径问题
- **检查退出状态**: 任务完成后可以通过 `echo $?` 检查上一条命令的退出状态
- **清理 pane**: 使用 `tmux send-keys -t %x 'clear' Enter` 清理输出
