fzf-git-status() {
    local repo_root
    if ! repo_root=$(git rev-parse --show-toplevel 2>/dev/null); then
        echo 'fzf-git-status: Not in a git repository.' >&2
        return 1
    fi

    _ghc_readline_context
    local token="$GHC_READLINE_TOKEN"
    local query
    query=$(_ghc_unquote_token "$token")

    local entry status_code path old_path
    local -a selected=()
    mapfile -d '' -t selected < <(
        git status --porcelain=v1 --null |
        while IFS= read -r -d '' entry; do
            status_code=${entry:0:2}
            path=${entry:3}
            printf '%s %s/%s\0' "$status_code" "$repo_root" "$path"

            if [[ "$status_code" == *[RC]* ]]; then
                IFS= read -r -d '' old_path || break
            fi
        done |
        fzf --read0 --print0 --multi --prompt="Git Status> " \
            --with-shell='bash --noprofile --norc -c' \
            --query="$query" \
            --nth=2.. \
            --preview='
                line={}
                status_code=${line:0:2}
                p=${line:3}
                if [[ "$status_code" == "??" ]]; then
                    bat --line-range=:500 --style=snip --number --color=always -- "$p" 2>/dev/null || cat -n -- "$p"
                else
                    git diff --color=always -- "$p" 2>/dev/null
                    git diff --color=always --staged -- "$p" 2>/dev/null
                fi
            ' \
            --preview-window="right:60%:wrap" \
            --bind='ctrl-o:execute(
                paths=()
                for line in {+}; do
                    paths+=("${line:3}")
                done
                nvim -- "${paths[@]}" < /dev/tty
            )'
    )

    if [[ ${#selected[@]} -gt 0 ]]; then
        local paths=()
        local line
        for line in "${selected[@]}"; do
            [[ -z "$line" ]] && continue
            paths+=("${line:3}")
        done

        if [[ ${#paths[@]} -gt 0 ]]; then
            local replacement
            replacement=$(_ghc_shell_escape_join "${paths[@]}")
            READLINE_LINE="${GHC_READLINE_BEFORE:0:GHC_READLINE_TOKEN_START}${replacement}${GHC_READLINE_AFTER}"
            READLINE_POINT=$(( GHC_READLINE_TOKEN_START + ${#replacement} ))
        fi
    fi
}
