function fzf-git-status --description "Search git status and insert file paths"
    set -l repo_root (git rev-parse --show-toplevel 2>/dev/null)
    if test $status -ne 0
        echo 'fzf-git-status: Not in a git repository.' >&2
        commandline --function repaint
        return 1
    end

    set -l selected (
        git status --porcelain=v1 --null |
        while read --null --local entry
            set -l status_code (string sub --length 2 -- "$entry")
            set -l path (string sub --start=4 -- "$entry")
            printf '%s %s/%s\0' "$status_code" "$repo_root" "$path"

            if string match --quiet --regex '[RC]' -- "$status_code"
                read --null --local old_path
            end
        end |
        fzf --read0 --print0 --multi --prompt="Git Status> " \
            --query=(commandline --current-token) \
            --nth=2.. \
            --preview='fish --no-config -c "
                set -l line \$argv[1]
                set -l status_code (string sub --length 2 -- \$line)
                set -l p (string sub --start=4 -- \$line)
                if test \"\$status_code\" = \"??\"
                    bat --line-range=:500 --style=snip --number --color=always \$p 2>/dev/null || cat -n \$p
                else
                    git diff --color=always -- \$p 2>/dev/null
                    git diff --color=always --staged -- \$p 2>/dev/null
                end
            " -- {}' \
            --preview-window="right:60%:wrap" \
            --bind="ctrl-o:execute(nvim -- (string sub --start=4 -- {}) < /dev/tty)" |
        string split0
    )

    if test $status -eq 0
        set -l paths
        for line in $selected
            set -a paths (string sub --start=4 -- $line)
        end
        commandline --current-token --replace -- (string escape -- $paths | string join ' ')
    end

    commandline --function repaint
end
