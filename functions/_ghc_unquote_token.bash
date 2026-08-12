_ghc_unquote_token() {
    local token="$1"
    local quote="${token:0:1}"

    if [[ "$quote" == "'" || "$quote" == '"' ]]; then
        token=${token:1}
        [[ "${token: -1}" == "$quote" ]] && token=${token::-1}
    fi

    printf '%s' "$token"
}
