fzf-git-status() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo 'fzf-git-status: Not in a git repository.' >&2
        return 1
    fi

    _ghc_readline_context
    local token="$GHC_READLINE_TOKEN"

    local preview_cmd
    preview_cmd="bash -c 'line=\"{}\"; idx_st=\"\${line:0:1}\"; p=\"\${line:3}\"; if [[ \"\$idx_st\" == \"?\" ]]; then bat --line-range=:500 --style=snip --number --color=always \"\$p\" 2>/dev/null || cat -n \"\$p\"; else git diff --color=always -- \"\$p\" 2>/dev/null; git diff --color=always --staged -- \"\$p\" 2>/dev/null; fi'"

    local open_cmd
    open_cmd="bash -c 'line=\"{}\"; p=\"\${line:3}\"; if [[ \"\${line:0:1}\" == \"R\" ]]; then p=\"\${p##* -> }\"; fi; nvim \"\$p\" < /dev/tty'"

    local selected
    selected=$(git status --short |
        fzf --ansi --multi --prompt="Git Status> " \
            --query="$token" \
            --nth=2.. \
            --preview="$preview_cmd" \
            --preview-window="right:60%:wrap" \
            --bind="ctrl-o:execute($open_cmd)")

    if [[ -n "$selected" ]]; then
        local paths=()
        local line path
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            if [[ "${line:0:1}" == "R" ]]; then
                path="${line:3}"
                path="${path##* -> }"
            else
                path="${line:3}"
            fi
            paths+=("$path")
        done <<< "$selected"

        if [[ ${#paths[@]} -gt 0 ]]; then
            local replacement
            replacement=$(_ghc_shell_escape_join "${paths[@]}")
            READLINE_LINE="${GHC_READLINE_BEFORE:0:GHC_READLINE_TOKEN_START}${replacement}${GHC_READLINE_AFTER}"
            READLINE_POINT=$(( GHC_READLINE_TOKEN_START + ${#replacement} ))
        fi
    fi
}
