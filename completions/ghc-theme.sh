# shellcheck shell=bash
# Completion for ghc-theme

_ghc_theme() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    local subcmds="apply gen generate toggle"
    local themes="
        catppuccin-frappe
        catppuccin-latte
        catppuccin-macchiato
        catppuccin-mocha
        gruvbox-dark
        gruvbox-light
        nord
        onehalf-dark
        onehalf-light
        rosepine-dawn
        rosepine-main
        rosepine-moon
        tokyonight-day
        tokyonight-moon
        tokyonight-night
        tokyonight-storm
        vsc-dark-modern
        vsc-light-modern
    "
    local opts="--silent -s --help -h"

    case "$prev" in
        ghc-theme)
            COMPREPLY=($(compgen -W "$subcmds $opts" -- "$cur"))
            ;;
        apply|toggle)
            COMPREPLY=($(compgen -W "$themes" -- "$cur"))
            ;;
        gen|generate)
            COMPREPLY=()
            ;;
        *)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "$opts" -- "$cur"))
            fi
            ;;
    esac
}

complete -F _ghc_theme ghc-theme
