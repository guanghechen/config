# App initialization

_prepend_path_once() {
    local path_item="$1"
    [[ -n "$path_item" && ":$PATH:" != *":$path_item:"* ]] && export PATH="$path_item:$PATH"
}

if command -v starship >/dev/null 2>&1; then
    export STARSHIP_CONFIG="$HOME/.config/starship/bash.toml"
    eval "$(starship init bash)"
fi

if [[ -d "$HOME/.bun" ]]; then
    export BUN_INSTALL="$HOME/.bun"
    if [[ -x "$BUN_INSTALL/bin/bun" ]]; then
        _prepend_path_once "$BUN_INSTALL/bin"
    fi
fi

if [[ -x "$HOME/.cargo/bin/cargo" ]]; then
    _prepend_path_once "$HOME/.cargo/bin"
fi

if command -v fnm >/dev/null 2>&1; then
    eval "$(fnm env --use-on-cd --shell bash)"
fi

if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
fi

if [[ -z "${PREFER_TMUX_VERSION:-}" || "$PREFER_TMUX_VERSION" != "stable" ]]; then
    if [[ -x "$ROOT_SOURCECODES/github/tmux/tmux/tmux" ]]; then
        _prepend_path_once "$ROOT_SOURCECODES/github/tmux/tmux"
    fi
fi

if [[ -n "${TMUX:-}" ]]; then
    export TERM="tmux-256color"
else
    export TERM="xterm-256color"
fi

if [[ -x "$HOME/.app/miniforge3/bin/conda" ]]; then
    export CONDA_CHANGEPS1=false
    export CONDA_PROMPT_MODIFIER=""
    __conda_setup="$($HOME/.app/miniforge3/bin/conda "shell.bash" "hook" 2>/dev/null)"
    if [[ $? -eq 0 ]]; then
        eval "$__conda_setup"
    elif [[ -f "$HOME/.app/miniforge3/etc/profile.d/conda.sh" ]]; then
        source "$HOME/.app/miniforge3/etc/profile.d/conda.sh"
    fi
    unset __conda_setup
fi
