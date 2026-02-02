#! /usr/bin/env bash
# shellcheck disable=SC1091


# shellcheck source=setup/nix/path.sh
source "$HOME/.config/guanghechen/setup/nix/path.sh"

fish -c "\
  cd \"$HOME/.config/nvim\"\
  && conda activate \"$PREFER_PYTHON_ENV\"\
  && fnm use \"$PREFER_NODE_VERSION\"\
  && bash rust/build.sh\
  && nvim --headless -u ./init-update.lua\
"
if [ -d "$HOME/.config/nvim-nvchad/" ]; then
  fish -c "\
    cd \"$HOME/.config/nvim-nvchad\"\
    && conda activate \"$PREFER_PYTHON_ENV\"\
    && fnm use \"$PREFER_NODE_VERSION\"\
    && bash rust/build.sh\
    && nvchad --headless -u ./init-update.lua\
  "
fi
