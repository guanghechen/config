function fzf-git-log --description "Search git log and insert commit hash"
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo 'fzf-git-log: Not in a git repository.' >&2
        commandline --function repaint
        return 1
    end

    set -l format '%C(bold blue)%h%C(reset) - %C(cyan)%ad%C(reset) %C(yellow)%d%C(reset) %C(normal)%s%C(reset)  %C(dim normal)[%an]%C(reset)'
    set -l selected (
        git log --no-show-signature --color=always --format=format:$format --date=short |
        fzf --ansi --multi --scheme=history --prompt="Git Log> " \
            --preview="git show --color=always --stat --patch {1}" \
            --query=(commandline --current-token)
    )

    if test $status -eq 0
        set -l hashes
        for line in $selected
            set -l abbrev (string split --field=1 " " $line)
            set -a hashes (git rev-parse $abbrev)
        end
        commandline --current-token --replace (string join ' ' $hashes)
    end

    commandline --function repaint
end
