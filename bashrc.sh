# Interactive shell entry for ~/.config/bash

BASH_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/bash"

set -o vi

# Fallback platform detection for non-login shells
if [[ -z "${GHC_ENV_PLATFORM:-}" ]]; then
    GHC_ENV_PLATFORM="nix"
    if [[ "$(uname)" == "Darwin" ]]; then
        GHC_ENV_PLATFORM="osx"
    elif [[ -r /proc/version ]] && grep -qEi "(Microsoft|WSL)" /proc/version; then
        GHC_ENV_PLATFORM="wsl"
    fi
    export GHC_ENV_PLATFORM
fi

# Config modules
source "$BASH_CONFIG_DIR/conf/app.sh"
source "$BASH_CONFIG_DIR/conf/alias.sh"
source "$BASH_CONFIG_DIR/conf/keymap.sh"

# Platform-specific interactive config
if [[ -f "$BASH_CONFIG_DIR/platform/$GHC_ENV_PLATFORM/bashrc.sh" ]]; then
    source "$BASH_CONFIG_DIR/platform/$GHC_ENV_PLATFORM/bashrc.sh"
fi

# Functions
for f in "$BASH_CONFIG_DIR"/functions/*.sh; do
    [[ -r "$f" ]] && source "$f"
done

# Completions
for f in "$BASH_CONFIG_DIR"/completions/*.sh; do
    [[ -r "$f" ]] && source "$f"
done
