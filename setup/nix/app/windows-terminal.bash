#! /usr/bin/env bash

source "$HOME/.config/guanghechen/setup/nix/bot/env.bash"

## Setup windows terminal
printf "\e[96msyncing Windows Terminal settings...\e[0m\n"
node "$HOME/.config/guanghechen/cli/sync-config-windows-terminal.mjs"
