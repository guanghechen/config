fzf-git-log() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo 'fzf-git-log: Not in a git repository.' >&2
        return 1
    fi

    _ghc_readline_context
    local token="$GHC_READLINE_TOKEN"
    local format='%C(bold blue)%h%C(reset) - %C(cyan)%ad%C(reset) %C(yellow)%d%C(reset) %C(normal)%s%C(reset)  %C(dim normal)[%an]%C(reset)'

    local selected
    selected=$(git log --no-show-signature --color=always --format=format:"$format" --date=short |
        fzf --ansi --multi --scheme=history --prompt="Git Log> " \
            --preview="git show --color=always --stat --patch {1}" \
            --query="$token")

    if [[ -n "$selected" ]]; then
        local hashes=()
        local line abbrev full
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            abbrev=${line%% *}
            full=$(git rev-parse "$abbrev" 2>/dev/null) || continue
            hashes+=("$full")
        done <<< "$selected"

        if [[ ${#hashes[@]} -gt 0 ]]; then
            local replacement
            replacement=$(_ghc_shell_escape_join "${hashes[@]}")
            READLINE_LINE="${GHC_READLINE_BEFORE:0:GHC_READLINE_TOKEN_START}${replacement}${GHC_READLINE_AFTER}"
            READLINE_POINT=$(( GHC_READLINE_TOKEN_START + ${#replacement} ))
        fi
    fi
}
