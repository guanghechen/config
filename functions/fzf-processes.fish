# Upstream reference: https://github.com/PatrickF1/fzf.fish/blob/main/functions/_fzf_search_processes.fish
# Locally adapted; see README.md for sync policy.

function fzf-processes --description "Search running processes and insert PID"
    set -l preview_fmt (string join ',' 'pid' 'ppid=PARENT' 'user' '%cpu' 'rss=RSS_IN_KB' 'start=START_TIME' 'command')
    set -l selected (
        ps -A -opid,command |
        fzf --multi --ansi --prompt="Processes> " \
            --with-shell='fish --no-config -c' --bind=ctrl-o:ignore \
            --header-lines=1 \
            --exact \
            --query=(commandline --current-token) \
            --preview="ps -o '$preview_fmt' -p {1} || echo 'Process {1} exited.'" \
            --preview-window="bottom:4:wrap"
    )

    if test $status -eq 0
        set -l pids
        for proc in $selected
            set -a pids (string split --no-empty --field=1 -- " " $proc)
        end
        commandline --current-token --replace -- (string join ' ' $pids)
    end

    commandline --function repaint
end
