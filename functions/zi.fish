function zi --description "Zoxide interactive selection with fzf"
    set -l result (
        zoxide query --list --score |
        fzf --no-sort --prompt="Zoxide> " \
            --preview="ll {2}" \
            --preview-window="right:60%:wrap" |
        awk '{print $2}'
    )
    test -n "$result" && cd "$result"
end
