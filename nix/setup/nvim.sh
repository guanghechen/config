#! /usr/bin/env bash

source $HOME/.config/guanghechen/nix/setup/path.sh

fish -c "\
  cd $HOME/.config/nvim\
  && bash rust/nvim_tools/build.sh\
  && nvim --headless -c 'source ~/.config/nvim/init.lua' +q\
  && nvim --headless -c 'source ~/.config/nvim/init.lua | Lazy update' +q\
"
if [ -d "$HOME/.config/nvim-nvchad/" ]; then
  fish -c "\
    cd $HOME/.config/nvim-nvchad\
    && bash rust/nvim_tools/build.sh\
    && nvchad --headless -c 'source ~/.config/nvim-nvchad/init.lua' +q\
    && nvchad --headless -c 'source ~/.config/nvim-nvchad/init.lua | Lazy update' +q\
  "
fi
