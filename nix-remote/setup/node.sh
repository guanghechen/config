#! /usr/bin/env bash

source $HOME/.config/guanghechen/nix/setup/path.sh

if fnm list | grep -q "v$PREFER_NODE_VERSION"; then
  printf "\n\e[93m  [setup node] node@$PREFER_NODE_VERSION is already installed. (skipped)\e[0m\n"
else
  printf "\n\e[94m   [setup node] installing node@$REFER_NODE_VERSION...\e[0m\n"
  fnm install $PREFER_NODE_VERSION
fi

fnm use $PREFER_NODE_VERSION

printf "\n\e[94m   [setup node] installing npm bun pm2 yarn prettier\e[0m\n"
npm install -g npm bun pm2 yarn prettier

## Setup ora
if [ -d "$HOME/.config/ora" ]; then
  printf "\n\e[94m   [setup node] setup ora...\e[0m\n"
  fish -c "cd $HOME/.config/ora && yarn"
fi
