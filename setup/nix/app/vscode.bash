#! /usr/bin/env bash

source "$HOME/.config/guanghechen/setup/nix/bot/env.bash"

## Setup vscode
printf "\e[96m  [setup vscode] set vscode...\e[0m\n"
fish -c "node \"$HOME/.config/guanghechen/cli/sync-config-vscode.mjs\""
