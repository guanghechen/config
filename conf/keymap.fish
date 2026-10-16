bind -M insert ctrl-y accept-autosuggestion
bind -M default ctrl-y accept-autosuggestion
bind -M insert ctrl-w forward-bigword
bind -M default ctrl-w forward-bigword

for mode in default insert
    bind --mode $mode ctrl-shift-f fzf-file
    bind --mode $mode ctrl-shift-l fzf-git-log
    bind --mode $mode ctrl-shift-g fzf-git-status
    bind --mode $mode ctrl-shift-h fzf-history
    bind --mode $mode ctrl-shift-p fzf-processes
    bind --mode $mode ctrl-shift-e fzf-variables
    bind --mode $mode ctrl-shift-z zi
end
