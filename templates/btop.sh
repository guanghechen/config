#!/bin/bash
# btop monitoring session layout

SESSION="btop"
BTOP_DIR="$HOME/.config/btop"

# If session exists, attach to it
if tmux has-session -t $SESSION 2>/dev/null; then
    tmux attach-session -t $SESSION
    exit 0
fi

# Window 1: dashboard - full panes preset (preset 0)
tmux new-session -d -s $SESSION -n "dashboard" -c "$BTOP_DIR"
tmux send-keys -t $SESSION:dashboard "btop -p 0" Enter

# Window 2: tmux - proc only, filter 'tmux' (preset 2)
tmux new-window -t $SESSION -n "tmux" -c "$BTOP_DIR"
tmux send-keys -t $SESSION:tmux "btop -p 2 -f tmux" Enter

# Window 3: nvim - proc only, filter 'nvim' (preset 2)
tmux new-window -t $SESSION -n "nvim" -c "$BTOP_DIR"
tmux send-keys -t $SESSION:nvim "btop -p 2 -f nvim" Enter

# Select first window and attach
tmux select-window -t $SESSION:dashboard
tmux attach-session -t $SESSION

