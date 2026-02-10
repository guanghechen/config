fzf-history() {
    if [[ -n "${HISTFILE:-}" ]]; then
        history -a
        history -n
    fi

    local time_fmt="%m-%d %H:%M:%S | "
    local preview_cmd
    preview_cmd="bash -c 'line=\"{}\"; printf \"%s\\n\" \"\${line#* | }\"'"

    local selected
    selected=$(HISTTIMEFORMAT="$time_fmt" history |
        sed -E 's/^ *[0-9]+ *//' |
        fzf --tac --no-sort --prompt="History> " \
            --query="$READLINE_LINE" \
            --preview="$preview_cmd" \
            --preview-window="bottom:3:wrap")

    if [[ -n "$selected" ]]; then
        local cmd="${selected#* | }"
        READLINE_LINE="$cmd"
        READLINE_POINT=${#READLINE_LINE}
    fi
}
