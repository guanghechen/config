#! /usr/bin/env bash


## copy ~/.inputrc
if [ -f "$HOME/.inputrc" ]; then
  printf "\e[93m  [setup config] ~/.inputrc already exists. (skipped).\e[0m\n"
else
  printf "\e[96m  [setup config] setting up ~/.inputrc...\e[0m\n"
  cp "$HOME/.config/guanghechen/asset/conf/.inputrc" "$HOME/.inputrc"
fi

## sync configs
printf "\e[96m  [setup config] syncing configs...\e[0m\n"
node "$HOME/.config/guanghechen/cli/sync-xdg-config.mjs"
