# shellcheck shell=bash
# y - Yazi file manager with cwd sync

y() {
    local tmp
    tmp=$(mktemp -t "yazi-cwd.XXXXXX")
    yazi "$@" --cwd-file="$tmp"
    local cwd
    cwd=$(<"$tmp")
    if [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
        builtin cd -- "$cwd" || return 1
    fi
    rm -f -- "$tmp"
}
