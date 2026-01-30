#! /usr/bin/env bash
# shellcheck disable=SC1091

# shellcheck source=nix/setup/path.sh
source "$HOME/.config/guanghechen/nix/setup/path.sh"

if fnm list | grep -q "v$PREFER_NODE_VERSION"; then
  printf "\e[93m  [setup node] node@%s is already installed. (skipped)\e[0m\n" "$PREFER_NODE_VERSION"
else
  printf "\e[96m  [setup node] installing node@%s...\e[0m\n" "$PREFER_NODE_VERSION"
  fnm install "$PREFER_NODE_VERSION"
fi

fnm use "$PREFER_NODE_VERSION"
fnm default "$PREFER_NODE_VERSION"

printf "\e[96m  [setup node] installing npm pm2 yarn prettier\e[0m\n"
npm install -g npm pm2 yarn prettier

## Setup agents
for pkg in @anthropic-ai/claude-code @google/gemini-cli @openai/codex @github/copilot; do
  if npm list -g "$pkg" &>/dev/null; then
    printf "\e[93m  [setup node] %s is already installed. (skipped)\e[0m\n" "$pkg"
  else
    printf "\e[96m  [setup node] installing %s...\e[0m\n" "$pkg"
    npm install -g "$pkg"
  fi
done
