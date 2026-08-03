#! /usr/bin/env bash

source "$HOME/.config/guanghechen/env/setting.bash" || return 1

### Runtime platform (wsl | osx | nix | unknown), independent of GHC_EDITION.
case "$(uname -s)" in
  Darwin)
    GHC_ENV_PLATFORM=osx
    ;;
  Linux)
    if uname -r | grep -qi microsoft; then
      GHC_ENV_PLATFORM=wsl
    else
      GHC_ENV_PLATFORM=nix
    fi
    ;;
  *)
    GHC_ENV_PLATFORM=unknown
    ;;
esac
export GHC_ENV_PLATFORM

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
if [ -f "$HOME/.app/miniforge3/bin/conda" ] && [ -x "$HOME/.app/miniforge3/bin/conda" ]; then
  export HOME_MINIFORGE="$HOME/.app/miniforge3"
  if [[ ":$PATH:" != *":$HOME_MINIFORGE/bin:"* ]]; then
    export PATH="$HOME_MINIFORGE/bin:$PATH"
  fi
  _ghc_conda_env="$("$HOME/.app/miniforge3/bin/conda" shell.bash hook)" || return 1
  eval "$_ghc_conda_env" || return 1
  unset _ghc_conda_env
fi
