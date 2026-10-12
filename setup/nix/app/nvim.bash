#! /usr/bin/env bash

source "$HOME/.config/guanghechen/setup/nix/bot/env.bash"

ghc_activate_python() {
  if command -v conda >/dev/null 2>&1 && conda activate "$GHC_APP_PYTHON_ENV"; then
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    return 0
  fi

  printf "\e[91mneither conda nor python3 is available\e[0m\n" >&2
  return 1
}

for nvim_appname in nvim nvim-nvchad nvim-stable; do
  if [ "$nvim_appname" != nvim ] && [ ! -d "$HOME/.config/$nvim_appname" ]; then
    printf '\e[93mSkipping %s: configuration directory not found\e[0m\n' "$nvim_appname"
    continue
  fi

  printf '\e[96mSetting up %s\e[0m\n' "$nvim_appname"
  (
    export NVIM_APPNAME="$nvim_appname"
    cd "$HOME/.config/$nvim_appname" &&
      ghc_activate_python &&
      fnm use "$GHC_APP_EDITION_NODE" &&
      node script/build.mjs &&
      nvim --headless -u ./init-update.lua
  ) || exit "$?"
done
