#! /usr/bin/env bash

### Homebrew
if [ -e "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
  export HOME_HOMEBREW=/home/linuxbrew/.linuxbrew
elif [ -e "/opt/homebrew/bin/brew" ]; then
  export HOME_HOMEBREW=/opt/homebrew
fi
if [[ ":$PATH:" != *":$HOME_HOMEBREW:"* ]]; then
  export PATH=$PATH:"$HOME_HOMEBREW/bin"
fi

### Cargo
if [ -f "$HOME/.cargo/bin/cargo" ] && [[ ":$PATH:" != *":$HOME/.cargo/bin:"* ]]; then
  export PATH="$HOME/.cargo/bin:$PATH"
fi

### fnm
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd)"
fi

### Miniforge3
if [ -f "$HOME/.app/miniforge3/bin/conda" ] && [[ ":$PATH:" != *":$HOME/.app/miniforge3/bin:"* ]]; then
  export HOME_MINIFORGE="$HOME/.app/miniforge3"
  export PATH="$HOME/.app/miniforge3/bin:$PATH"
  eval "$("$HOME/.app/miniforge3/bin/conda" shell.bash hook)"
fi
