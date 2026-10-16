fzf-history() {
    if [[ -n "${HISTFILE:-}" ]]; then
        history -a
        history -n
    fi

    local time_fmt="%m-%d %H:%M:%S | "

    local selected
    selected=$(HISTTIMEFORMAT="$time_fmt" history |
        sed -E 's/^ *[0-9]+ *//' |
        fzf --tac --no-sort --prompt="History> " \
            --with-shell='bash --noprofile --norc -c' --bind=ctrl-o:ignore \
            --query="$READLINE_LINE" \
            --preview='line={}; printf "%s\n" "${line#* | }"' \
            --preview-window="bottom:3:wrap")

    if [[ -n "$selected" ]]; then
        local cmd="${selected#* | }"
        READLINE_LINE="$cmd"
        READLINE_POINT=${#READLINE_LINE}
    fi
}
