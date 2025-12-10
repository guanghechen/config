bind -M insert \cy accept-autosuggestion
bind -M default \cy accept-autosuggestion

for mode in default insert
    bind --mode $mode \e\[70\;6u fzf-file # Ctrl+Shift+F
    bind --mode $mode \e\[76\;6u fzf-git-log # Ctrl+Shift+L
    bind --mode $mode \e\[71\;6u fzf-git-status # Ctrl+Shift+G
    bind --mode $mode \e\[82\;6u fzf-history # Ctrl+Shift+R
    bind --mode $mode \e\[80\;6u fzf-processes # Ctrl+Shift+P
    bind --mode $mode \e\[69\;6u fzf-variables # Ctrl+Shift+E
    bind --mode $mode \e\[90\;6u zi # Ctrl+Shift+Z
end
