fzf-processes() {
    _ghc_readline_context
    local token="$GHC_READLINE_TOKEN"

    local preview_fmt
    preview_fmt="pid,ppid=PARENT,user,%cpu,rss=RSS_IN_KB,start=START_TIME,command"

    local selected
    selected=$(ps -A -o pid,command |
        fzf --multi --ansi --prompt="Processes> " \
            --header-lines=1 \
            --exact \
            --query="$token" \
            --preview="ps -o '$preview_fmt' -p {1} || echo 'Process {1} exited.'" \
            --preview-window="bottom:4:wrap")

    if [[ -n "$selected" ]]; then
        local pids=()
        local line pid
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            pid=${line%% *}
            pids+=("$pid")
        done <<< "$selected"

        if [[ ${#pids[@]} -gt 0 ]]; then
            local replacement
            replacement=$(_ghc_shell_escape_join "${pids[@]}")
            READLINE_LINE="${GHC_READLINE_BEFORE:0:GHC_READLINE_TOKEN_START}${replacement}${GHC_READLINE_AFTER}"
            READLINE_POINT=$(( GHC_READLINE_TOKEN_START + ${#replacement} ))
        fi
    fi
}
