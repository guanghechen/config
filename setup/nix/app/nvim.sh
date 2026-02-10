#! /usr/bin/env bash
# shellcheck disable=SC1091


# shellcheck source=setup/nix/bot/env.sh
source "$HOME/.config/guanghechen/setup/nix/bot/env.sh"

fish -c "\
  cd \"$HOME/.config/nvim\"\
  && conda activate \"$GHC_APP_PYTHON_ENV\"\
  && fnm use \"$GHC_APP_EDITION_NODE\"\
  && bash rust/build.sh\
  && nvim --headless -u ./init-update.lua\
"
if [ -d "$HOME/.config/nvim-nvchad/" ]; then
  fish -c "\
    cd \"$HOME/.config/nvim-nvchad\"\
    && conda activate \"$GHC_APP_PYTHON_ENV\"\
    && fnm use \"$GHC_APP_EDITION_NODE\"\
    && bash rust/build.sh\
    && nvchad --headless -u ./init-update.lua\
  "
fi
