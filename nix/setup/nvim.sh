#! /usr/bin/env bash

source $HOME/.config/guanghechen/nix/setup/path.sh

fish -c "\
  cd $HOME/.config/nvim\
  && bash rust/nvim_tools/build.sh\
  && nvim --headless -u ./init-update.lua\
"
if [ -d "$HOME/.config/nvim-nvchad/" ]; then
  fish -c "\
    cd $HOME/.config/nvim-nvchad\
    && bash rust/nvim_tools/build.sh\
    && nvchad --headless -u ./init-update.lua\
  "
fi

cargo install tree-sitter-cli # [treesitter-cli]
