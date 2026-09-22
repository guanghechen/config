# shellcheck shell=bash

open() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: open <url|path>"
        return 1
    fi

    local target="$1"
    local filepath winpath
    if [[ "$target" =~ ^https?:// ]]; then
        explorer.exe "$target"
    elif [[ "$target" =~ ^file:// ]]; then
        filepath="${target#file://}"
        winpath="$(wslpath -w "$filepath")" || return 1
        explorer.exe "file://$winpath"
    else
        winpath="$(wslpath -w "$target")" || return 1
        explorer.exe "$winpath"
    fi
}
