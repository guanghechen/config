#! /usr/bin/env bash

printf "\n\e[34m  [setup config] gen themes...\e[0m\n"
fish -c "node ~/.config/guanghechen/config/theme/gen_themes.mjs"

printf "\n\e[34m  [setup config] set default theme...\e[0m\n"
fish -c "node ~/.config/guanghechen/config/theme/toggle_theme.mjs one_half_dark"
