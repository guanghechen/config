function zi --description "Zoxide interactive selection with fzf"
    set -l result (
        zoxide query --list |
        fzf --no-sort --prompt="Zoxide> " \
            --preview="ll {}" \
            --preview-window="right:60%:wrap"
    )
    test -n "$result" && cd "$result"
end
