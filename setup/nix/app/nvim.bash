#! /usr/bin/env bash

source "$HOME/.config/guanghechen/setup/nix/bot/env.bash"

ghc_activate_python() {
  if command -v conda >/dev/null 2>&1 && conda activate "$GHC_APP_PYTHON_ENV"; then
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    return 0
  fi

  printf "\e[91m [setup nvim] neither conda nor python3 is available.\e[0m\n" >&2
  return 1
}

(
  cd "$HOME/.config/nvim" &&
    ghc_activate_python &&
    fnm use "$GHC_APP_EDITION_NODE" &&
    node rust/script/build.mjs &&
    nvim --headless -u ./init-update.lua
)

if [ -d "$HOME/.config/nvim-nvchad/" ]; then
  (
    cd "$HOME/.config/nvim-nvchad" &&
      ghc_activate_python &&
      fnm use "$GHC_APP_EDITION_NODE" &&
      node rust/script/build.mjs &&
      NVIM_APPNAME=nvim-nvchad nvim --headless -u ./init-update.lua
  )
fi
