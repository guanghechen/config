# Shared configuration for login and interactive shells.
# Source this file directly to reload; entry-point wrappers load it once per shell.

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
BASH_CONFIG_DIR="$XDG_CONFIG_HOME/bash"

## Bootstrap environment
export LANG="en_US.UTF-8"
export LC_CTYPE="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export LESSCHARSET="utf-8"
export TZ="Asia/Shanghai"
export no_proxy="localhost,127.0.0.1,::1"
export NO_PROXY="$no_proxy"

## Platform detection
case "$(uname -s)" in
    Darwin) GHC_ENV_PLATFORM="osx" ;;
    *)
        case "$(uname -r)" in
            *[Mm]icrosoft*|*[Ww][Ss][Ll]*) GHC_ENV_PLATFORM="wsl" ;;
            *) GHC_ENV_PLATFORM="nix" ;;
        esac
        ;;
esac
export GHC_ENV_PLATFORM

## Preferences (resolved before platform and application configuration)
export PREFER_NEOVIM_VERSION="${PREFER_NEOVIM_VERSION:-nightly}"
export PREFER_TMUX_VERSION="${PREFER_TMUX_VERSION:-stable}"
export ROOT_SOURCECODES="$HOME/sourcecodes"
export ROOT_WORKSPACE="$HOME/ws"
export YOZ_SERVER_PORT="7777"

## Bootstrap paths
export CONDARC="$XDG_CONFIG_HOME/conda/condarc"
export LS_COLORS="di=1;94:ln=1;96:ex=1;92:or=1;91:mi=1;91:pi=93:so=1;95:bd=1;93:cd=1;93"

### Homebrew
export HOMEBREW_NO_ANALYTICS=1
if [[ -f /opt/homebrew/bin/brew ]]; then
    export HOMEBREW_PREFIX="/opt/homebrew"
    export HOMEBREW_CELLAR="/opt/homebrew/Cellar"
    export HOMEBREW_REPOSITORY="/opt/homebrew"
    export HOMEBREW_SHELLENV_PREFIX="/opt/homebrew"
    export NEOVIM_HOME="/opt/homebrew"
elif [[ -f /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    export HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
    export HOMEBREW_CELLAR="/home/linuxbrew/.linuxbrew/Cellar"
    export HOMEBREW_REPOSITORY="/home/linuxbrew/.linuxbrew"
    export HOMEBREW_SHELLENV_PREFIX="/home/linuxbrew/.linuxbrew"
    export NEOVIM_HOME="/home/linuxbrew/.linuxbrew"
fi
[[ ":$PATH:" == *":/usr/local/bin:"* ]] || export PATH="$PATH:/usr/local/bin"
if [[ -n "${HOMEBREW_PREFIX:-}" && ":$PATH:" != *":$HOMEBREW_PREFIX/bin:"* ]]; then
    export PATH="$PATH:$HOMEBREW_PREFIX/bin"
fi
# Make user-installed app hooks discoverable before conf/app.bash is loaded.
[[ ":$PATH:" == *":$HOME/.local/bin:"* ]] || export PATH="$PATH:$HOME/.local/bin"

## Shared environment
export LG_CONFIG_FILE="$XDG_CONFIG_HOME/lazygit/config.yml,$XDG_CONFIG_HOME/lazygit/local/theme.yml"
export NODE_OPTIONS="--max-old-space-size=8192"
export PYTHONIOENCODING="utf8"
export PYTHONPYCACHEPREFIX="$HOME/.cache/pycache"
export PYTHONUTF8="1"

## Agents
export KIT_COPILOT_URL="http://127.0.0.1:4747"
export ANTHROPIC_BASE_URL="$KIT_COPILOT_URL/api/claude"
export GOOGLE_GEMINI_BASE_URL="$KIT_COPILOT_URL/api/gemini"
export OPENAI_BASE_URL="$KIT_COPILOT_URL/api/codex"

export CLAUDE_CONFIG_DIR="$XDG_CONFIG_HOME/claude"
export CODEX_HOME="$XDG_CONFIG_HOME/codex"
export PI_CODING_AGENT_DIR="$XDG_CONFIG_HOME/pi"
export PI_CODING_AGENT_SESSION_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/pi/sessions"
export PI_TELEMETRY="0"
export GEMINI_CONFIG_DIR="$HOME/.gemini"

export ANTHROPIC_MODEL="claude-opus-4.6-1m"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="claude-sonnet-5"
export CLAUDE_CODE_MAX_OUTPUT_TOKENS="64000"
export GEMINI_MODEL="gemini-3-pro-preview"

## Local overrides
# Resolve local preferences before platform and application initialization.
if [[ -f "$BASH_CONFIG_DIR/local/env.bash" ]]; then
    source "$BASH_CONFIG_DIR/local/env.bash"
fi

## Platform-specific configuration
source "$BASH_CONFIG_DIR/conf/platform/$GHC_ENV_PLATFORM/config.bash"

## Application initialization
source "$BASH_CONFIG_DIR/conf/app.bash"

__BASH_CONFIG_LOADED=1
# Non-interactive login shells stop after environment and application paths are ready.
[[ $- == *i* ]] || return 0

## Interactive configuration
set -o vi
source "$BASH_CONFIG_DIR/conf/alias.bash"
source "$BASH_CONFIG_DIR/conf/keymap.bash"

## Functions
# Bash needs explicit sourcing; Fish autoloads functions from this directory.
for f in "$BASH_CONFIG_DIR"/functions/*.bash; do
    [[ -r "$f" ]] && source "$f"
done

## Completions
# Load system completion once, before custom completion definitions.
if [[ -z "${__BASH_COMPLETION_LOADED:-}" ]]; then
    if [[ -f /usr/share/bash-completion/bash_completion ]]; then
        source /usr/share/bash-completion/bash_completion
    elif [[ -f /etc/bash_completion ]]; then
        source /etc/bash_completion
    fi
    __BASH_COMPLETION_LOADED=1
fi
for f in "$BASH_CONFIG_DIR"/completions/*.bash; do
    [[ -r "$f" ]] && source "$f"
done
