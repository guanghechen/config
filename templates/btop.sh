#!/bin/bash
# btop monitoring session layout

SESSION="btop"
BTOP_DIR="$HOME/.config/btop"

# If session exists, attach to it
if tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux attach-session -t "$SESSION"
  exit 0
fi

# Window 1: dashboard - full panes preset (preset 0)
tmux new-session -d -s "$SESSION" -n "dashboard" -c "$BTOP_DIR"

# Window 2: tmux - proc only, filter 'tmux' (preset 2)
tmux new-window -t "$SESSION" -n "tmux" -c "$BTOP_DIR"

# Window 3: nvim - proc only, filter 'nvim' (preset 2)
tmux new-window -t "$SESSION" -n "nvim" -c "$BTOP_DIR"

# Window 4: nvim headless - proc only, filter 'nvim' (preset 2)
tmux new-window -t "$SESSION" -n "nvim-headless" -c "$BTOP_DIR"

sleep 1

tmux rename-window -t "$SESSION:1" "dashboard" # override hook rename
tmux send-keys -t "$SESSION:dashboard" "btop -p 0" Enter
tmux send-keys -t "$SESSION:tmux" "btop -p 2 --filter 'tmux'" Enter
tmux send-keys -t "$SESSION:nvim" "btop -p 2 --filter 'nvim'" Enter
tmux send-keys -t "$SESSION:nvim-headless" "btop -p 2 --filter 'nvim --headless'" Enter

# Select first window and attach or switch
tmux select-window -t "$SESSION:dashboard"
if [[ -n "$TMUX" ]]; then
  tmux switch-client -t "$SESSION"
else
  tmux attach-session -t "$SESSION"
fi
