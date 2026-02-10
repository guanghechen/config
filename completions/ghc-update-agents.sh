# shellcheck shell=bash
# Completion for ghc-update-agents

_ghc_update_agents() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local opts="--skip-installation"

    COMPREPLY=($(compgen -W "$opts" -- "$cur"))
}

complete -F _ghc_update_agents ghc-update-agents
