#! /usr/bin/env bash
# shellcheck disable=SC1091

GHC_CONFIG_ROOT="${GHC_CONFIG_ROOT:-$HOME/.config/guanghechen}"
export GHC_CONFIG_ROOT

# shellcheck source=setup/nix/setup/path.sh
source "$GHC_CONFIG_ROOT/setup/nix/setup/path.sh"

FONT_DIR="/usr/share/fonts/Maple"
FORCE=false

for arg in "$@"; do
  case $arg in
    --force)
      FORCE=true
      shift
      ;;
  esac
done

if [ "$FORCE" = true ] && [ -d "$FONT_DIR" ]; then
  printf "\e[96m  [setup font (Maple)] force removing existing Maple fonts...\e[0m\n"
  sudo rm -rf "$FONT_DIR"
fi

if [ -d "$FONT_DIR" ]; then
  printf "\e[93m  [setup font (Maple)] Maple is already installed. (skipped)\e[0m\n"
else
  mkdir -p ~/download/fonts/Maple
  rm -rf ~/download/fonts/Maple
  mkdir -p ~/download/fonts/Maple

  cd "$HOME/download/fonts/Maple" || return 1

  printf "\e[96m  [setup font (Maple)] downloading MapleMono-NF-CN fonts...\e[0m\n"
  wget https://github.com/guanghechen/mirror/releases/download/font/MapleMono-NF-CN-unhinted.zip

  printf "\e[96m  [setup font (Maple)] installing MapleMono fonts...\e[0m\n"
  unzip MapleMono-NF-CN-unhinted.zip
  rm -f MapleMono-NF-CN-unhinted.zip
  sudo cp -r ~/download/fonts/Maple "$FONT_DIR/"
  sudo fc-cache -f -v
fi
