# shellcheck shell=bash
# Completion for ghc-ghostty-shader

_ghc_ghostty_shader() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local shaders
    shaders="$(ghc-ghostty-shader --list 2>/dev/null)"
    local opts="--silent --prev --next -s"

    if [[ "$cur" == -* ]]; then
        COMPREPLY=($(compgen -W "$opts" -- "$cur"))
    else
        COMPREPLY=($(compgen -W "$shaders" -- "$cur"))
    fi
}

complete -F _ghc_ghostty_shader ghc-ghostty-shader
