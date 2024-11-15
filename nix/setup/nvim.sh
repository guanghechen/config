#! /usr/bin/env bash

source $HOME/.config/guanghechen/nix/setup/path.sh

fish -c "cd $HOME/.config/nvim/rust/nvim_tools/ && bash build.sh && nvim --headless -c 'source ~/.config/nvim/init.lua' +q"
if [ -d "$HOME/.config/nvim-nvchad/" ]; then
  fish -c "cd $HOME/.config/nvim-nvchad/rust/nvim_tools/ && bash build.sh && nvchad --headless -c 'source ~/.config/nvim-nvchad/init.lua' +q"
fi
