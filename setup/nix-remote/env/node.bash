#! /usr/bin/env bash

source "$HOME/.config/guanghechen/setup/nix/bot/env.bash"

if fnm list | grep -q "v$GHC_APP_EDITION_NODE"; then
  printf "\e[93m  [setup node] node@%s is already installed. (skipped)\e[0m\n" "$GHC_APP_EDITION_NODE"
else
  printf "\e[96m  [setup node] installing node@%s...\e[0m\n" "$GHC_APP_EDITION_NODE"
  fnm install "$GHC_APP_EDITION_NODE"
fi

fnm use "$GHC_APP_EDITION_NODE"
fnm default "$GHC_APP_EDITION_NODE"

printf "\e[96m  [setup node] installing npm prettier\e[0m\n"
npm install -g npm prettier

printf "\e[96m  [setup node] installing @guanghechen/kit\e[0m\n"
npm install -g @guanghechen/kit
