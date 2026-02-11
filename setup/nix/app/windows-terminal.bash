#! /usr/bin/env bash

source "$HOME/.config/guanghechen/setup/nix/bot/env.bash"

## Setup windows terminal
printf "\e[96m  [setup windows-terminal] set windows terminal...\e[0m\n"
fish -c "node \"$HOME/.config/guanghechen/cli/sync-config-windows-terminal.mjs\""
