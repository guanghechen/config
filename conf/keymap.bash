# Readline key bindings
bind 'set bind-tty-special-chars off'

# Align with fish keymap semantics as much as readline allows.
bind -m vi-command '"\C-w": forward-word'
bind -m vi-insert '"\C-w": forward-word'

# CSI u sequences distinguish Ctrl+Shift shortcuts sent by the terminal.
# Terminals send unshifted letter codepoints; modifier 6 encodes Ctrl+Shift.
bind -x '"\e[102;6u": "fzf-file"' # Ctrl+Shift+F
bind -x '"\e[108;6u": "fzf-git-log"' # Ctrl+Shift+L
bind -x '"\e[103;6u": "fzf-git-status"' # Ctrl+Shift+G
bind -x '"\e[104;6u": "fzf-history"' # Ctrl+Shift+H
bind -x '"\e[112;6u": "fzf-processes"' # Ctrl+Shift+P
bind -x '"\e[101;6u": "fzf-variables"' # Ctrl+Shift+E
bind -x '"\e[122;6u": "zi"' # Ctrl+Shift+Z
