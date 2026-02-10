# shellcheck shell=bash
# Completion for ghc-ghostty-shader

_ghc_ghostty_shader() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local shaders="off cubes fireworks-rockets gears-and-belts inside-the-matrix just-snow matrix-hallway mnoise sparks-from-fire starfield"
    local opts="--silent --prev --next -s -p -n"

    if [[ "$cur" == -* ]]; then
        COMPREPLY=($(compgen -W "$opts" -- "$cur"))
    else
        COMPREPLY=($(compgen -W "$shaders" -- "$cur"))
    fi
}

complete -F _ghc_ghostty_shader ghc-ghostty-shader
