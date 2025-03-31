#! /usr/bin/env bash

source $HOME/.config/guanghechen/nix/setup/path.sh

# printf "\n\e[34m  [setup config] gen themes...\e[0m\n"
# fish -c "node ~/.config/guanghechen/config/theme/gen_themes.mjs"

THEME=${GUANGHECHEN_PREFER_THEME:-catppuccin-mocha}
printf "\n\e[34m  [setup config] set default theme ($THEME)...\e[0m\n"
fish -c "node ~/.config/guanghechen/config/theme/apply_theme.mjs $THEME"
