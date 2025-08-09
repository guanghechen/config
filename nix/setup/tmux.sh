#! /usr/bin/env bash

source $HOME/.config/guanghechen/nix/setup/path.sh

TPM_DIR="$HOME/.config/tmux/plugins/tpm"
if [ -d "$TPM_DIR" ]; then
  printf "\n\e[94m  [setup tmux] updating tmux plugin manager...\e[0m\n"
  git -C "$TPM_DIR" pull
else
  printf "\n\e[94m  [setup tmux] installing tmux plugin manager...\e[0m\n"
  mkdir -p "$HOME/.config/tmux/plugins/"
  git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
fi

# Install plugins need start a tmux server first.
# printf "\n\e[94m  [setup tmux] installing tmux plugins...\e[0m\n"
# tmux run-shell ~/.config/tmux/plugins/tpm/bin/install_plugins
