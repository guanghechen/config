#!/bin/bash
# AI agent coding session layout

SESSION="agent"

# If session exists, attach to it
if tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux attach-session -t "$SESSION"
  exit 0
fi

# Window 1: claude
tmux new-session -d -s "$SESSION" -n "claude" -c "$HOME/.config/claude/"

# Window 2: codex
tmux new-window -t "$SESSION" -n "codex" -c "$HOME/.config/codex/"

# Window 3: gemini
tmux new-window -t "$SESSION" -n "gemini" -c "$HOME/.gemini/"

# Window 4: opencode
tmux new-window -t "$SESSION" -n "opencode" -c "$HOME/.config/opencode/"

sleep 1
tmux rename-window -t "$SESSION:1" "claude" # override hook rename

# Select first window and attach
tmux select-window -t "$SESSION:claude"
tmux attach-session -t "$SESSION"
