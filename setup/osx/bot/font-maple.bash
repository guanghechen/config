#! /usr/bin/env bash

source "$HOME/.config/guanghechen/setup/nix/bot/env.bash"
source "$HOME/.config/guanghechen/setup/nix/bot/font.bash"

ghc_setup_font_maple() {
  local label="MapleMono"
  local url="https://github.com/guanghechen/mirror/releases/download/font/MapleMono-NF-CN-unhinted.zip"
  local sha256="ab88522932cf4015dffeaef6dedc59a22a5fefecdcc6e583d9fcd997da5b7cac"
  local font_dir="/Library/Fonts"
  local local_dir="$HOME/Library/Fonts"
  local workdir="$HOME/download/fonts/Maple"

  ## Fonts are reproducible artifacts: verify before replacing them, and rerun
  ## setup after any install or cache failure.
  ghc_font_fetch "$label" "$url" "$sha256" "$workdir" || return 1

  printf "\e[96m  [setup font (%s)] installing into %s...\e[0m\n" "$label" "$font_dir"
  rm -f "$local_dir"/MapleMono*.ttf || return 1
  sudo rm -f "$font_dir"/MapleMono*.ttf || return 1
  sudo install -m 0644 "$workdir"/*.ttf "$font_dir/" || return 1
  sudo atsutil databases -remove || return 1
}

ghc_setup_font_maple
