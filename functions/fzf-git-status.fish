# Upstream reference: https://github.com/PatrickF1/fzf.fish/blob/main/functions/_fzf_search_git_status.fish
# Locally adapted; see README.md for sync policy.

function fzf-git-status --description "Search git status and insert file paths"
    set -l repo_root (git rev-parse --show-toplevel 2>/dev/null | string collect --no-trim-newlines)
    if test $status -ne 0
        echo 'fzf-git-status: Not in a git repository.' >&2
        commandline --function repaint
        return 1
    end
    # Strip only git's output terminator, preserving newlines in the directory name.
    set repo_root (string split --right --max=1 --fields=1 -- \n "$repo_root")

    set -l selected (
        git status --porcelain=v1 --null |
        while read --null --local entry
            set -l status_code (string sub --length 2 -- "$entry")
            set -l path (string split --max=1 --fields=2 -- "$status_code " "$entry")
            printf '%s %s/%s\0' "$status_code" "$repo_root" "$path"

            if string match --quiet --regex '[RC]' -- "$status_code"
                read --null --local old_path
            end
        end |
        fzf --read0 --print0 --multi --prompt="Git Status> " \
            --with-shell='fish --no-config -c' \
            --query=(commandline --current-token) \
            --nth=2.. \
            --preview='
                set -l line {}
                set -l status_code (string sub --length 2 -- "$line")
                set -l p (string split --max=1 --fields=2 -- "$status_code " "$line")
                if test "$status_code" = "??"
                    bat --line-range=:500 --style=snip --number --color=always -- "$p" 2>/dev/null || cat -n -- "$p"
                else
                    git diff --color=always -- "$p" 2>/dev/null
                    git diff --color=always --staged -- "$p" 2>/dev/null
                end
            ' \
            --preview-window="right:60%:wrap" \
            --bind='ctrl-o:execute(
                set -l paths
                for line in {+}
                    set -l prefix (string sub --length 3 -- "$line")
                    set -a paths (string split --max=1 --fields=2 -- "$prefix" "$line")
                end
                nvim -- $paths < /dev/tty
            )' |
        string split0
    )

    if test $status -eq 0
        set -l paths
        for line in $selected
            set -l prefix (string sub --length 3 -- "$line")
            set -a paths (string split --max=1 --fields=2 -- "$prefix" "$line")
        end
        commandline --current-token --replace -- (string escape -- $paths | string join ' ')
    end

    commandline --function repaint
end
