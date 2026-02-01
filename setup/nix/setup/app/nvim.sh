#! /usr/bin/env bash
# shellcheck disable=SC1091

GHC_CONFIG_ROOT="${GHC_CONFIG_ROOT:-$HOME/.config/guanghechen}"
export GHC_CONFIG_ROOT

# shellcheck source=setup/nix/setup/path.sh
source "$GHC_CONFIG_ROOT/setup/nix/setup/path.sh"

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
