# Readline key bindings
bind 'set bind-tty-special-chars off'

# Align with fish keymap semantics as much as readline allows.
bind -m vi-command '"\C-w": forward-word'
bind -m vi-insert '"\C-w": forward-word'

# CSI u sequences distinguish Ctrl+Shift shortcuts sent by the terminal.
bind -x '"\e[70;6u": "fzf-file"' # Ctrl+Shift+F
bind -x '"\e[76;6u": "fzf-git-log"' # Ctrl+Shift+L
bind -x '"\e[71;6u": "fzf-git-status"' # Ctrl+Shift+G
bind -x '"\e[82;6u": "fzf-history"' # Ctrl+Shift+R
bind -x '"\e[80;6u": "fzf-processes"' # Ctrl+Shift+P
bind -x '"\e[69;6u": "fzf-variables"' # Ctrl+Shift+E
bind -x '"\e[90;6u": "zi"' # Ctrl+Shift+Z
