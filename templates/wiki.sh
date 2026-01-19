#!/bin/bash
# wiki session layout

SESSION="G1-wiki"

# If session exists, attach to it
if tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux attach-session -t "$SESSION"
  exit 0
fi

# Window 1: translator
tmux new-session -d -s "$SESSION" -n "translator" -c "$HOME/wiki/translator"

# Window 2: wiki-note
tmux new-window -t "$SESSION" -n "wiki-note" -c "$HOME/wiki/wiki-note"

# Window 3: wiki
tmux new-window -t "$SESSION" -n "wiki" -c "$HOME/wiki/wiki"

# Window 4: term
tmux new-window -t "$SESSION" -n "term" -c "$HOME/wiki/wiki"

# Enter claude in each window
tmux send-keys -t "$SESSION:translator" "claude --permission-mode=plan" Enter
tmux send-keys -t "$SESSION:wiki-note" "claude --permission-mode=plan" Enter
tmux send-keys -t "$SESSION:wiki" "claude --permission-mode=plan" Enter
tmux send-keys -t "$SESSION:term" "claude --permission-mode=plan" Enter

# Select first window and attach or switch
tmux select-window -t "$SESSION:translator"
if [[ -n "$TMUX" ]]; then
  tmux switch-client -t "$SESSION"
else
  tmux attach-session -t "$SESSION"
fi
