fzf-file() {
    _ghc_readline_context
    local token
    token=$(_ghc_unquote_token "$GHC_READLINE_TOKEN")
    if [[ "$token" == '~/'* ]]; then
        token="$HOME/${token:2}"
    fi

    local search_dir=.
    local prompt='File> '
    local query="$token"
    if [[ "$token" == */ && -d "$token" ]]; then
        search_dir="$token"
        prompt="$token> "
        query=''
    fi

    # fd includes the search directory in each result; fzf quotes complete paths.
    local -a items=()
    mapfile -d '' -t items < <(
        command fd --hidden --follow --no-ignore-vcs --color=always --print0 \
            --exclude=.git --exclude=node_modules --exclude=.DS_Store \
            --exclude='*.local' --exclude=local/ --exclude='*.exe' --exclude='*.zip' \
            --type=f --search-path="$search_dir" |
        fzf --ansi --read0 --print0 --multi --scheme=path --prompt="$prompt" --query="$query" \
            --with-shell='bash --noprofile --norc -c' \
            --preview='bat --line-range=:500 --style=snip --number --color=always -- {} || cat -n -- {}' \
            --bind='ctrl-o:execute(nvim -- {+} < /dev/tty)'
    )

    if [[ ${#items[@]} -gt 0 ]]; then
        local replacement
        replacement=$(_ghc_shell_escape_join "${items[@]}")
        READLINE_LINE="${GHC_READLINE_BEFORE:0:GHC_READLINE_TOKEN_START}${replacement}${GHC_READLINE_AFTER}"
        READLINE_POINT=$(( GHC_READLINE_TOKEN_START + ${#replacement} ))
    fi
}
