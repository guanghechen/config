#! /usr/bin/env bash
# shellcheck disable=SC1091


# shellcheck source=setup/nix/setup/path.sh
source "$HOME/.config/guanghechen/setup/nix/setup/path.sh"

## Setup windows terminal
printf "\e[96m  [setup windows-terminal] set windows terminal...\e[0m\n"
fish -c "node \"$HOME/.config/guanghechen/cli/sync-config-windows-terminal.mjs\""
