#! /usr/bin/env bash

if [ -e "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
  export HOME_HOMEBREW=/home/linuxbrew/.linuxbrew
elif [ -e "/opt/homebrew/bin/brew" ]; then
  export HOME_HOMEBREW=/opt/homebrew
fi

if [[ ":$PATH:" != *":$HOME_HOMEBREW:"* ]]; then
  export PATH=$PATH:"$HOME_HOMEBREW/bin"
fi
