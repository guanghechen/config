# shellcheck shell=bash

start() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: start <url|path>"
        return 1
    fi

    local target="$1"
    local filepath winpath
    if [[ "$target" =~ ^https?:// ]]; then
        cmd.exe /c start "" "$target"
    elif [[ "$target" =~ ^file:// ]]; then
        filepath="${target#file://}"
        winpath="$(wslpath -w "$filepath")" || return 1
        cmd.exe /c start "" "file://$winpath"
    else
        winpath="$(wslpath -w "$target")" || return 1
        cmd.exe /c start "" "$winpath"
    fi
}
