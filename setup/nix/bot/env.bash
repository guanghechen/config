#! /usr/bin/env bash

source "$HOME/.config/guanghechen/env/setting.bash" || return 1

### Homebrew
export HOMEBREW_NO_ANALYTICS=1
if [ -e "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
  export HOME_HOMEBREW=/home/linuxbrew/.linuxbrew
elif [ -e "/opt/homebrew/bin/brew" ]; then
  export HOME_HOMEBREW=/opt/homebrew
elif [ -e "/usr/local/bin/brew" ]; then
  export HOME_HOMEBREW=/usr/local
fi
if [ -n "${HOME_HOMEBREW:-}" ] && [[ ":$PATH:" != *":$HOME_HOMEBREW/bin:"* ]]; then
  export PATH=$PATH:"$HOME_HOMEBREW/bin"
fi

### Cargo
if [ -f "$HOME/.cargo/bin/cargo" ] && [[ ":$PATH:" != *":$HOME/.cargo/bin:"* ]]; then
  export PATH="$HOME/.cargo/bin:$PATH"
fi

### fnm
if command -v fnm >/dev/null 2>&1; then
  _ghc_fnm_env="$(fnm env --use-on-cd)" || return 1
  eval "$_ghc_fnm_env" || return 1
  unset _ghc_fnm_env
fi

### Miniforge3
if [ -f "$HOME/.app/miniforge3/bin/conda" ] && [[ ":$PATH:" != *":$HOME/.app/miniforge3/bin:"* ]]; then
  export HOME_MINIFORGE="$HOME/.app/miniforge3"
  export PATH="$HOME/.app/miniforge3/bin:$PATH"
  _ghc_conda_env="$("$HOME/.app/miniforge3/bin/conda" shell.bash hook)" || return 1
  eval "$_ghc_conda_env" || return 1
  unset _ghc_conda_env
fi
