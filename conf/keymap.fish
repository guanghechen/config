function __smart_tab
    if commandline --showing-suggestion
        set -l max_steps 200
        set -l step 0
        set -l last_buffer (commandline)

        while commandline --showing-suggestion
            if test $step -ge $max_steps
                break
            end
            set step (math $step + 1)

            commandline -f forward-single-char

            set -l current_buffer (commandline)
            if test "$current_buffer" = "$last_buffer"
                # Prevent infinite loop when forward-single-char makes no progress.
                break
            end
            set last_buffer "$current_buffer"

            set -l last_char (commandline --cut-at-cursor | string sub -s -1)
            if test "$last_char" = " "
                commandline -f backward-delete-char
                break
            end
        end
        return
    end
    commandline -f complete
end

bind -M insert \cy accept-autosuggestion
bind -M default \cy accept-autosuggestion
bind -M insert tab __smart_tab
bind -M insert ctrl-i __smart_tab

for mode in default insert
    bind --mode $mode \e\[70\;6u fzf-file # Ctrl+Shift+F
    bind --mode $mode \e\[76\;6u fzf-git-log # Ctrl+Shift+L
    bind --mode $mode \e\[71\;6u fzf-git-status # Ctrl+Shift+G
    bind --mode $mode \e\[82\;6u fzf-history # Ctrl+Shift+R
    bind --mode $mode \e\[80\;6u fzf-processes # Ctrl+Shift+P
    bind --mode $mode \e\[69\;6u fzf-variables # Ctrl+Shift+E
    bind --mode $mode \e\[90\;6u zi # Ctrl+Shift+Z
end
