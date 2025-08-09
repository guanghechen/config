#! /usr/bin/env bash

source $HOME/.config/guanghechen/nix/setup/path.sh

printf "\n\e[94m  [setup app] set vscode...\e[0m\n"
fish -c "node ~/.config/guanghechen/config/app/vscode/keybinding/index.mjs"

printf "\n\e[94m  [setup app] set windows terminal...\e[0m\n"
fish -c "node ~/.config/guanghechen/config/app/windows-terminal/index.mjs"
