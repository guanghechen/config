# Login shell entry for ~/.config/bash

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
BASH_CONFIG_DIR="$XDG_CONFIG_HOME/bash"

export LANG="${LANG:-en_US.UTF-8}"
export LC_CTYPE="${LC_CTYPE:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
export LESSCHARSET="${LESSCHARSET:-utf-8}"
export TZ="${TZ:-Asia/Shanghai}"
export no_proxy="${no_proxy:-localhost,127.0.0.1,::1}"
export NO_PROXY="${NO_PROXY:-$no_proxy}"

set -o vi

# Platform detection (login shell)
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

# PATH helper to avoid duplicates
_add_path() {
  [[ ":$PATH:" != *":$1:"* ]] && export PATH="$1:$PATH"
}

export CONDARC="$XDG_CONFIG_HOME/conda/condarc"
export LS_COLORS="${LS_COLORS:-di=1;94:ln=1;96:ex=1;92:or=1;91:mi=1;91:pi=93:so=1;95:bd=1;93:cd=1;93}"

export HOMEBREW_NO_ANALYTICS=1
if [[ -x /opt/homebrew/bin/brew ]]; then
  export HOMEBREW_PREFIX="/opt/homebrew"
  export HOMEBREW_CELLAR="/opt/homebrew/Cellar"
  export HOMEBREW_REPOSITORY="/opt/homebrew"
  export HOMEBREW_SHELLENV_PREFIX="/opt/homebrew"
  export NEOVIM_HOME="/opt/homebrew"
elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  export HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
  export HOMEBREW_CELLAR="/home/linuxbrew/.linuxbrew/Cellar"
  export HOMEBREW_REPOSITORY="/home/linuxbrew/.linuxbrew"
  export HOMEBREW_SHELLENV_PREFIX="/home/linuxbrew/.linuxbrew"
  export NEOVIM_HOME="/home/linuxbrew/.linuxbrew"
fi

if [[ -z "${PREFER_NEOVIM_VERSION:-}" || "$PREFER_NEOVIM_VERSION" != "stable" ]]; then
  if [[ -x "$HOME/.app/neovim/bin/nvim" ]]; then
    export NEOVIM_HOME="$HOME/.app/neovim"
  elif [[ -x /opt/me/app/neovim/bin/nvim ]]; then
    export NEOVIM_HOME="/opt/me/app/neovim"
  fi
fi

if [[ -n "${NEOVIM_HOME:-}" ]]; then
  _add_path "$NEOVIM_HOME/bin"
fi

_add_path "/usr/local/bin"
if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
  _add_path "$HOMEBREW_PREFIX/bin"
fi

_add_path "$HOME/.local/bin"
_add_path "$HOME/.cargo/bin"

# App env
export FZF_DEFAULT_COMMAND="fd --hidden --follow --no-ignore-vcs --color=never --exclude=.git --exclude=node_modules --exclude=.DS_Store --type=f"
export FZF_DEFAULT_OPTS_FILE="$HOME/.config/fzf/fzf.fzfrc"

if [[ -n "${NEOVIM_HOME:-}" ]]; then
  export EDITOR="$NEOVIM_HOME/bin/nvim"
  export VISUAL="$NEOVIM_HOME/bin/nvim"
  export MYVIMRC="$XDG_CONFIG_HOME/nvim/init.lua"
  export VIM="$NEOVIM_HOME/share/nvim"
  export VIMRUNTIME="$NEOVIM_HOME/share/nvim/runtime"
fi

export LG_CONFIG_FILE="$XDG_CONFIG_HOME/lazygit/config.yml,$XDG_CONFIG_HOME/lazygit/local/theme.yml"
export NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=8192}"
export PYTHONIOENCODING="${PYTHONIOENCODING:-utf8}"
export PYTHONPYCACHEPREFIX="${PYTHONPYCACHEPREFIX:-$HOME/.cache/pycache}"
export PYTHONUTF8="${PYTHONUTF8:-1}"

# Preferences
export PREFER_NEOVIM_VERSION="${PREFER_NEOVIM_VERSION:-nightly}"
export PREFER_TMUX_VERSION="${PREFER_TMUX_VERSION:-stable}"
export ROOT_SOURCECODES="${ROOT_SOURCECODES:-$HOME/sourcecodes}"
export ROOT_WORKSPACE="${ROOT_WORKSPACE:-$HOME/ws}"
export YOZ_SERVER_PORT="${YOZ_SERVER_PORT:-7777}"

# Agent env
export ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL:-${GHC_ANTHROPIC_BASE_URL:-http://127.0.0.1:4747/api/claude}}"
export ANTHROPIC_AUTH_TOKEN="${ANTHROPIC_AUTH_TOKEN:-${GHC_ANTHROPIC_AUTH_TOKEN:-}}"
export ANTHROPIC_MODEL="${ANTHROPIC_MODEL:-claude-opus-4.6-fast}"
export ANTHROPIC_SMALL_FAST_MODEL="${ANTHROPIC_SMALL_FAST_MODEL:-claude-sonnet-4.6}"
export CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$XDG_CONFIG_HOME/claude}"

export CODEX_HOME="${CODEX_HOME:-$XDG_CONFIG_HOME/codex}"

export GOOGLE_GEMINI_BASE_URL="${GOOGLE_GEMINI_BASE_URL:-${GHC_GEMINI_BASE_URL:-http://127.0.0.1:4747/api/gemini}}"
export GEMINI_API_KEY="${GEMINI_API_KEY:-${GHC_GEMINI_AUTH_TOKEN:-}}"
export GEMINI_MODEL="${GEMINI_MODEL:-gemini-3-pro-preview}"
export GEMINI_CONFIG_DIR="${GEMINI_CONFIG_DIR:-$HOME/.gemini}"

# Local sensitive env
if [[ -f "$BASH_CONFIG_DIR/local/env.bash" ]]; then
  source "$BASH_CONFIG_DIR/local/env.bash"
fi

# Platform-specific env
if [[ -f "$BASH_CONFIG_DIR/platform/$GHC_ENV_PLATFORM/profile.bash" ]]; then
  source "$BASH_CONFIG_DIR/platform/$GHC_ENV_PLATFORM/profile.bash"
fi
