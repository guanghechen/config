zi() {
    if ! command -v zoxide >/dev/null 2>&1; then
        echo 'zi: zoxide not found.' >&2
        return 1
    fi

    local result
    result=$(zoxide query --list |
        fzf --no-sort --prompt="Zoxide> " \
            --preview="ll {}" \
            --preview-window="right:60%:wrap")

    if [[ -n "$result" ]]; then
        cd "$result" || return
        READLINE_LINE=""
        READLINE_POINT=0
    fi
}
