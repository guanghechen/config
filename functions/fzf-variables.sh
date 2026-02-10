fzf-variables() {
    _ghc_readline_context
    local token="$GHC_READLINE_TOKEN"
    local query="${token//\$/}"

    local preview_cmd
    preview_cmd="bash -c 'v=\"{}\"; if declare -p \"\$v\" >/dev/null 2>&1; then declare -p \"\$v\"; else printf \"%s=%q\\n\" \"\$v\" \"\${!v}\"; fi'"

    local selected
    selected=$(compgen -v |
        fzf --multi --prompt="Variables> " \
            --query="$query" \
            --preview-window="wrap" \
            --preview="$preview_cmd")

    if [[ -n "$selected" ]]; then
        mapfile -t vars <<< "$selected"
        local replacement=""
        local var
        if [[ "$token" == *'$'* ]]; then
            for var in "${vars[@]}"; do
                [[ -z "$var" ]] && continue
                if [[ -n "$replacement" ]]; then
                    replacement+=" "
                fi
                replacement+="\${$var}"
            done
        else
            for var in "${vars[@]}"; do
                [[ -z "$var" ]] && continue
                if [[ -n "$replacement" ]]; then
                    replacement+=" "
                fi
                replacement+="$var"
            done
        fi

        if [[ -n "$replacement" ]]; then
            READLINE_LINE="${GHC_READLINE_BEFORE:0:GHC_READLINE_TOKEN_START}${replacement}${GHC_READLINE_AFTER}"
            READLINE_POINT=$(( GHC_READLINE_TOKEN_START + ${#replacement} ))
        fi
    fi
}
