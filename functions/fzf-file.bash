fzf-file() {
    _ghc_readline_context
    local token="$GHC_READLINE_TOKEN"
    local unescaped
    unescaped=$(_ghc_expand_path_token "$token")

    local result status
    if [[ "$unescaped" == */ && -d "$unescaped" ]]; then
        result=$(fd --hidden --follow --no-ignore-vcs --color=always --exclude=.git --exclude='*.local' --exclude=local/ --exclude='*.exe' --exclude='*.zip' --type=f --base-directory="$unescaped" |
            GHC_FZF_FILE_BASE="$unescaped" fzf --ansi --multi --prompt="$unescaped> " \
                --preview='bash -c '\''path=$GHC_FZF_FILE_BASE$1; bat --line-range=:500 --style=snip --theme=vsc-light-modern --number --color=always "$path" || cat -n "$path"'\'' _ {}')
        status=$?
        if [[ $status -eq 0 && -n "$result" ]]; then
            mapfile -t items <<< "$result"
            local prefixed=()
            local item
            for item in "${items[@]}"; do
                [[ -z "$item" ]] && continue
                prefixed+=("${unescaped}${item}")
            done
            local replacement
            replacement=$(_ghc_shell_escape_join "${prefixed[@]}")
            READLINE_LINE="${GHC_READLINE_BEFORE:0:GHC_READLINE_TOKEN_START}${replacement}${GHC_READLINE_AFTER}"
            READLINE_POINT=$(( GHC_READLINE_TOKEN_START + ${#replacement} ))
        fi
    else
        result=$(fd --hidden --follow --no-ignore-vcs --color=always --exclude=.git --exclude='*.local' --exclude=local/ --exclude='*.exe' --exclude='*.zip' --type=f |
            fzf --ansi --multi --prompt="File> " --query="$unescaped" --preview="bat --line-range=:500 --style=snip --theme=vsc-light-modern --number --color=always {} || cat -n {}")
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
