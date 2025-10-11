#! /usr/bin/env bash

source $HOME/.config/guanghechen/nix/setup/path.sh

if fnm list | grep -q "v$PREFER_NODE_VERSION"; then
  printf "\n\e[93m  [setup node] node@$PREFER_NODE_VERSION is already installed. (skipped)\e[0m\n"
else
  fnm install $PREFER_NODE_VERSION
  fnm use $PREFER_NODE_VERSION
  fish -c "npm install -g npm bun pm2 yarn prettier"
  fish -c "npm install -g @anthropic-ai/claude-code @google/gemini-cli"
fi

if [ -d "$HOME/.config/yoz" ]; then
  printf "\n\e[94m  [setup node] setup yoz...\e[0m\n"
  fish -c "cd $HOME/.config/yoz && yarn install"
fi
