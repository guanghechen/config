#! /usr/bin/env bash

source $HOME/.config/guanghechen/nix/setup/path.sh

if fnm list | grep -q "v$PREFER_NODE_VERSION"; then
  printf "\e[93m  [setup node] node@%s is already installed. (skipped)\e[0m\n" "$PREFER_NODE_VERSION"
else
  printf "\e[96m  [setup node] installing node@%s...\e[0m\n" "$PREFER_NODE_VERSION"
  fnm install "$PREFER_NODE_VERSION"
fi

fnm use "$PREFER_NODE_VERSION"
fnm default "$PREFER_NODE_VERSION"

printf "\e[96m  [setup node] installing npm bun pm2 yarn prettier\e[0m\n"
npm install -g npm bun pm2 yarn prettier

## Setup ora
if [ -d "$HOME/.config/ora" ]; then
  printf "\e[96m  [setup node] setup ora...\e[0m\n"
  fish -c "cd $HOME/.config/ora && yarn"
fi
