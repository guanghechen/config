#! /usr/bin/env bash

source "$HOME/.config/guanghechen/setup/nix/bot/env.bash"

if fnm list | grep -q "v$GHC_APP_EDITION_NODE"; then
  printf "\e[93mnode@%s is already installed (skipped)\e[0m\n" "$GHC_APP_EDITION_NODE"
else
  printf "\e[96minstalling node@%s...\e[0m\n" "$GHC_APP_EDITION_NODE"
  fnm install "$GHC_APP_EDITION_NODE"
fi

fnm use "$GHC_APP_EDITION_NODE"
fnm default "$GHC_APP_EDITION_NODE"

## Setup agents
for pkg in @anthropic-ai/claude-code @google/gemini-cli; do
  if npm list -g "$pkg" &>/dev/null; then
    printf "\e[93m%s is already installed (skipped)\e[0m\n" "$pkg"
  else
    printf "\e[96minstalling %s...\e[0m\n" "$pkg"
    npm install -g "$pkg"
  fi
done
