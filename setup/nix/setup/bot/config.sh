#! /usr/bin/env bash

GHC_CONFIG_ROOT="${GHC_CONFIG_ROOT:-$HOME/.config/guanghechen}"
export GHC_CONFIG_ROOT

## copy ~/.inputrc
if [ -f "$HOME/.inputrc" ]; then
  printf "\e[93m  [setup config] ~/.inputrc already exists. (skipped).\e[0m\n"
else
  printf "\e[96m  [setup config] setting up ~/.inputrc...\e[0m\n"
  cp "$GHC_CONFIG_ROOT/asset/conf/.inputrc" "$HOME/.inputrc"
fi

## sync configs
printf "\e[96m  [setup config] syncing configs...\e[0m\n"
node "$GHC_CONFIG_ROOT/cli/sync-xdg-config.mjs"
