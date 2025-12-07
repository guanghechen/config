function fzf-git-status --description "Search git status and insert file paths"
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo 'fzf-git-status: Not in a git repository.' >&2
        commandline --function repaint
        return 1
    end

    set -l selected (
        git status --short |
        fzf --ansi --multi --prompt="Git Status> " \
            --query=(commandline --current-token) \
            --nth=2.. \
            --preview='fish -c "
                set -l line {}
                set -l idx_st (string sub --length 1 \$line)
                set -l p (string sub --start=4 \$line)
                if test \$idx_st = \"?\"
                    bat --line-range=:500 --style=snip --number --color=always \$p 2>/dev/null || cat -n \$p
                else
                    git diff --color=always -- \$p 2>/dev/null
                    git diff --color=always --staged -- \$p 2>/dev/null
                end
            "' \
            --preview-window="right:60%:wrap" \
a           --bind="ctrl-o:execute(nvim (string sub --start=4 {}) < /dev/tty)"
    )

    if test $status -eq 0
        set -l paths
        for line in $selected
            if test (string sub --length 1 $line) = R
                # renamed: "R old -> new", extract new path
                set -a paths (string split -- " -> " $line)[-1]
            else
                set -a paths (string sub --start=4 $line)
            end
        end
        commandline --current-token --replace -- (string join ' ' $paths)
    end

    commandline --function repaint
end
