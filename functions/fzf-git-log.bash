fzf-git-log() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo 'fzf-git-log: Not in a git repository.' >&2
        return 1
    fi

    _ghc_readline_context
    local token="$GHC_READLINE_TOKEN"
    local format='%C(bold blue)%h%C(reset) - %C(cyan)%ad%C(reset)%C(auto)%d%C(reset) %C(normal)%s%C(reset)  %C(dim normal)[%an]%C(reset)'

    # The preview moves below the list when a side panel would be narrower than 120 columns,
    # leaving room for delta's side-by-side layout.
    local selected
    selected=$(git log --graph --no-show-signature --color=always --format=format:"$format" --date=short |
        fzf --ansi --multi --no-sort --scheme=history --prompt="Git Log> " \
            --with-shell='bash --noprofile --norc -c' --bind=ctrl-o:ignore \
            --preview='
                # Graph-only lines carry no commit hash.
                [[ {} =~ ^[^0-9a-f]*([0-9a-f]{4,}) ]] || exit
                show=(git show --color=always --unified=5 --stat --stat-count=5 --patch
                    "--date=format:%Y-%m-%d %H:%M:%S"
                    "--format=%C(bold blue)%h%C(reset)%C(auto)%d%C(reset)%n%C(dim)%an <%ae>%C(reset)  %C(cyan)%ad%C(reset) %C(dim)(%ar)%C(reset)%n%n%C(bold)%s%C(reset)%n%n%-b")
                # alt-w sets the preview label, which doubles as the ignore-whitespace state.
                [[ -n $FZF_PREVIEW_LABEL ]] && show+=(--ignore-all-space)
                if command -v delta >/dev/null; then
                    # delta renders at a fixed width; narrow previews use the unified layout.
                    ((FZF_PREVIEW_COLUMNS < 100)) && export DELTA_FEATURES=+unified
                    "${show[@]}" "${BASH_REMATCH[1]}" | delta --width="$FZF_PREVIEW_COLUMNS"
                else
                    "${show[@]}" "${BASH_REMATCH[1]}"
                fi
            ' \
            --preview-window='right,60%,<120(down,60%)' \
            --bind='ctrl-/:change-preview-window(90%,<120(down,90%)|)+refresh-preview' \
            --bind='alt-w:transform-preview-label([[ -n $FZF_PREVIEW_LABEL ]] || echo " ignore whitespace ")+refresh-preview' \
            --bind=resize:refresh-preview \
            --query="$token")

    if [[ -n "$selected" ]]; then
        local hashes=()
        local line full
        while IFS= read -r line; do
            [[ $line =~ ^[^0-9a-f]*([0-9a-f]{4,}) ]] || continue
            full=$(git rev-parse "${BASH_REMATCH[1]}" 2>/dev/null) || continue
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
