#! /usr/bin/env bash

source $HOME/.config/guanghechen/nix/setup/path.sh

if fnm list | grep -q "v20"; then
  printf "\n\e[33;5;214m  [setup node] node@20 is already installed. (skipped)\e[0m\n"
else
  fnm install 20
  fish -c "npm install -g npm pm2 yarn"
fi
