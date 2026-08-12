_ghc_readline_context() {
    GHC_READLINE_BEFORE=${READLINE_LINE:0:READLINE_POINT}
    # shellcheck disable=SC2034 # Used by fzf-* widgets in other sourced files.
    GHC_READLINE_AFTER=${READLINE_LINE:READLINE_POINT}

    local token_start=0
    local quote=""
    local escaped=false
    local char
    local i
    for ((i = 0; i < ${#GHC_READLINE_BEFORE}; i++)); do
        char=${GHC_READLINE_BEFORE:i:1}

        if [[ "$escaped" == true ]]; then
            escaped=false
            continue
        fi

        if [[ "$char" == "\\" && "$quote" != "'" ]]; then
            escaped=true
            continue
        fi

        if [[ -n "$quote" ]]; then
            [[ "$char" == "$quote" ]] && quote=""
            continue
        fi

        if [[ "$char" == "'" || "$char" == '"' ]]; then
            quote="$char"
        elif [[ "$char" == [[:space:]] ]]; then
            token_start=$((i + 1))
        fi
    done

    GHC_READLINE_TOKEN=${GHC_READLINE_BEFORE:token_start}
    # shellcheck disable=SC2034 # Used by fzf-* widgets in other sourced files.
    GHC_READLINE_TOKEN_START=$token_start
}
