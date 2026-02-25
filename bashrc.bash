# Interactive shell entry for ~/.config/bash

BASH_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/bash"

set -o vi

# Fallback platform detection for non-login shells
if [[ -z "${GHC_ENV_PLATFORM:-}" ]]; then
    GHC_ENV_PLATFORM="nix"
    if [[ "$(uname)" == "Darwin" ]]; then
        GHC_ENV_PLATFORM="osx"
    elif [[ -r /proc/version ]]; then
        if command -v rg >/dev/null 2>&1; then
            if rg -qi "(Microsoft|WSL)" /proc/version; then
                GHC_ENV_PLATFORM="wsl"
            fi
        elif grep -qEi "(Microsoft|WSL)" /proc/version; then
            GHC_ENV_PLATFORM="wsl"
        fi
    fi
    export GHC_ENV_PLATFORM
fi

# Config modules
# Keep app init idempotent when users re-source bashrc.bash manually.
if [[ -z "${__BASH_CONF_APP_LOADED:-}" ]]; then
    __BASH_CONF_APP_LOADED=1
    source "$BASH_CONFIG_DIR/conf/app.bash"
fi
source "$BASH_CONFIG_DIR/conf/alias.bash"
source "$BASH_CONFIG_DIR/conf/keymap.bash"

# Platform-specific interactive config
if [[ -f "$BASH_CONFIG_DIR/platform/$GHC_ENV_PLATFORM/bashrc.bash" ]]; then
  source "$BASH_CONFIG_DIR/platform/$GHC_ENV_PLATFORM/bashrc.bash"
fi

# Functions
for f in "$BASH_CONFIG_DIR"/functions/*.bash; do
  [[ -r "$f" ]] && source "$f"
done

# System bash-completion (before custom completions)
if [[ -f /usr/share/bash-completion/bash_completion ]]; then
  source /usr/share/bash-completion/bash_completion
elif [[ -f /etc/bash_completion ]]; then
  source /etc/bash_completion
fi

# Completions
for f in "$BASH_CONFIG_DIR"/completions/*.bash; do
  [[ -r "$f" ]] && source "$f"
done
