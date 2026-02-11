_ghc_shell_escape_join() {
    local out=""
    local item escaped
    for item in "$@"; do
        [[ -z "$item" ]] && continue
        printf -v escaped '%q' "$item"
        if [[ -n "$out" ]]; then
            out+=" "
        fi
        out+="$escaped"
    done
    printf '%s' "$out"
}
