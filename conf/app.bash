# App initialization

## path helpers
# Preserve the position of existing entries while keeping PATH duplicate-free.
_prepend_path_once() {
    local path_item="$1"
    [[ -n "$path_item" && ":$PATH:" != *":$path_item:"* ]] && export PATH="$path_item:$PATH"
}

_append_path_once() {
    local path_item="$1"
    [[ -z "$path_item" ]] && return

    local current_path="${PATH:-}"
    [[ ":$current_path:" == *":$path_item:"* ]] && return
    export PATH="${current_path:+$current_path:}$path_item"
}

## starship (prompt)
# Respect an icon supplied by the environment; otherwise select a platform default.
if [[ -z "${STARSHIP_OS_ICON+x}" ]]; then
    if [[ "${GHC_ENV_PLATFORM:-nix}" == "osx" ]]; then
        export STARSHIP_OS_ICON=""
    else
        export STARSHIP_OS_ICON=""
    fi
fi

if command -v starship >/dev/null 2>&1; then
    export STARSHIP_CONFIG="$HOME/.config/starship/bash.toml"
    eval "$(starship init bash)"
fi

## fnm
if command -v fnm >/dev/null 2>&1; then
    eval "$(fnm env --use-on-cd --shell bash)"
fi

## bun
if [[ -d "$HOME/.bun" ]]; then
    export BUN_INSTALL="$HOME/.bun"
    if [[ -x "$BUN_INSTALL/bin/bun" ]]; then
        _append_path_once "$BUN_INSTALL/bin"
    fi
fi

## cargo
# The call order leaves local/bin ahead of bin after both entries are prepended.
_ghc_cargo_home="${CARGO_HOME:-$HOME/.cargo}"
_prepend_path_once "$_ghc_cargo_home/bin"
_prepend_path_once "$_ghc_cargo_home/local/bin"
unset _ghc_cargo_home

## zoxide
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
fi

## tmux
# Prefer the source-built binary unless the stable version is explicitly requested.
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

## miniforge3
if [[ -x "$HOME/.app/miniforge3/bin/conda" ]]; then
    export CONDA_CHANGEPS1=false
    export CONDA_PROMPT_MODIFIER=""

    # Prefer conda's generated hook; retain the profile script as a compatibility fallback.
    if __conda_setup="$("$HOME/.app/miniforge3/bin/conda" "shell.bash" "hook" 2>/dev/null)"; then
        eval "$__conda_setup"
    elif [[ -f "$HOME/.app/miniforge3/etc/profile.d/conda.sh" ]]; then
        source "$HOME/.app/miniforge3/etc/profile.d/conda.sh"
    fi
    unset __conda_setup
fi
