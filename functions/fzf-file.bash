fzf-file() {
    _ghc_readline_context
    local token="$GHC_READLINE_TOKEN"
    local query
    query=$(_ghc_unquote_token "$token")

    local search_path="$query"
    if [[ "$search_path" == '~/'* ]]; then
        search_path="$HOME/${search_path:2}"
    fi

    local result status
    if [[ "$search_path" == */ && -d "$search_path" ]]; then
        result=$(fd --hidden --follow --no-ignore-vcs --color=always --exclude=.git --exclude='*.local' --exclude=local/ --exclude='*.exe' --exclude='*.zip' --type=f --base-directory="$search_path" |
            GHC_FZF_FILE_BASE="$search_path" fzf --ansi --multi --prompt="$search_path> " \
                --preview='bash -c '\''path=$GHC_FZF_FILE_BASE$1; bat --line-range=:500 --style=snip --theme=vsc-light-modern --number --color=always "$path" || cat -n "$path"'\'' _ {}')
        status=$?
        if [[ $status -eq 0 && -n "$result" ]]; then
            mapfile -t items <<< "$result"
            local prefixed=()
            local item
            for item in "${items[@]}"; do
                [[ -z "$item" ]] && continue
                prefixed+=("${search_path}${item}")
            done
            local replacement
            replacement=$(_ghc_shell_escape_join "${prefixed[@]}")
            READLINE_LINE="${GHC_READLINE_BEFORE:0:GHC_READLINE_TOKEN_START}${replacement}${GHC_READLINE_AFTER}"
            READLINE_POINT=$(( GHC_READLINE_TOKEN_START + ${#replacement} ))
        fi
    else
        result=$(fd --hidden --follow --no-ignore-vcs --color=always --exclude=.git --exclude='*.local' --exclude=local/ --exclude='*.exe' --exclude='*.zip' --type=f |
            fzf --ansi --multi --prompt="File> " --query="$query" --preview="bat --line-range=:500 --style=snip --theme=vsc-light-modern --number --color=always {} || cat -n {}")
        status=$?
        if [[ $status -eq 0 && -n "$result" ]]; then
            mapfile -t items <<< "$result"
            local replacement
            replacement=$(_ghc_shell_escape_join "${items[@]}")
            READLINE_LINE="${GHC_READLINE_BEFORE:0:GHC_READLINE_TOKEN_START}${replacement}${GHC_READLINE_AFTER}"
            READLINE_POINT=$(( GHC_READLINE_TOKEN_START + ${#replacement} ))
        fi
    fi
}
