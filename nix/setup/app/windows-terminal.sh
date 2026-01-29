#! /usr/bin/env bash

source $HOME/.config/guanghechen/nix/setup/path.sh

## Setup windows terminal
printf "\e[96m  [setup windows-terminal] set windows terminal...\e[0m\n"
fish -c "node ~/.config/guanghechen/config/app/windows-terminal/index.mjs"
