#! /usr/bin/env bash
# shellcheck disable=SC1091


# shellcheck source=setup/nix/bot/env.sh
source "$HOME/.config/guanghechen/setup/nix/bot/env.sh"

## Setup vscode
printf "\e[96m  [setup vscode] set vscode...\e[0m\n"
fish -c "node \"$HOME/.config/guanghechen/cli/sync-config-vscode.mjs\""
