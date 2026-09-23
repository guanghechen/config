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

## Optional coding agents (disabled by default)
# Uncomment individual commands to install or update to the latest version globally.

## Claude Code
# npm install -g @anthropic-ai/claude-code@latest

## Gemini CLI
# npm install -g @google/gemini-cli@latest

## OpenCode
# npm install -g opencode-ai@latest
