_ghc_expand_path_token() {
    # Preserve interactive path expansion without evaluating command, process, or arithmetic substitutions.
    local token="$1"
    local result=""
    local quote=""
    local char next remaining var_name matched
    local i=0

    while (( i < ${#token} )); do
        char=${token:i:1}

        if [[ "$quote" == "'" ]]; then
            if [[ "$char" == "'" ]]; then
                quote=""
            else
                result+="$char"
            fi
            ((i++))
            continue
        fi

        if [[ "$char" == "'" && -z "$quote" ]]; then
            quote="'"
            ((i++))
            continue
        fi

        if [[ "$char" == '"' ]]; then
            if [[ "$quote" == '"' ]]; then
                quote=""
            else
                quote='"'
            fi
            ((i++))
            continue
        fi

        if [[ "$char" == "\\" ]]; then
            if (( i + 1 >= ${#token} )); then
                result+="\\"
                ((i++))
                continue
            fi

            next=${token:i+1:1}
            if [[ "$quote" != '"' || "$next" == '$' || "$next" == '`' || "$next" == '"' || "$next" == "\\" ]]; then
                result+="$next"
                ((i += 2))
                continue
            fi

            result+="\\"
            ((i++))
            continue
        fi

        if (( i == 0 )) && [[ -z "$quote" && "$char" == "~" ]]; then
            next=${token:i+1:1}
            if [[ -z "$next" || "$next" == "/" ]]; then
                result+="$HOME"
                ((i++))
                continue
            fi
        fi

        if [[ -z "$result" && "$quote" != "'" && "$char" == '$' ]]; then
            remaining=${token:i}
            if [[ "$remaining" =~ ^\$\{([a-zA-Z_][a-zA-Z0-9_]*)\} ]]; then
                var_name=${BASH_REMATCH[1]}
                matched=${BASH_REMATCH[0]}
                result+="${!var_name-}"
                ((i += ${#matched}))
                continue
            fi
            if [[ "$remaining" =~ ^\$([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
                var_name=${BASH_REMATCH[1]}
                matched=${BASH_REMATCH[0]}
                result+="${!var_name-}"
                ((i += ${#matched}))
                continue
            fi
        fi

        result+="$char"
        ((i++))
    done

    printf '%s' "$result"
}
