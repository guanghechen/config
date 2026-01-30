#! /usr/bin/env bash
# shellcheck disable=SC1091

# shellcheck source=nix/setup/path.sh
source "$HOME/.config/guanghechen/nix/setup/path.sh"

FONT_COMMON_DIR="/Library/Fonts"
FONT_LOCAL_DIR="$HOME/Library/Fonts"
FORCE=false

for arg in "$@"; do
  case $arg in
    --force)
      FORCE=true
      shift
      ;;
  esac
done

if [ "$FORCE" = true ] && [ -f "$FONT_COMMON_DIR/RobotoMonoNerdFont-Bold.ttf" ]; then
  printf "\e[96m  [setup font (RobotoMono)] force removing existing RobotoMono fonts...\e[0m\n"
  rm -rf "$FONT_LOCAL_DIR"/RobotoMonoNerdFont*
  sudo rm -rf "$FONT_COMMON_DIR"/RobotoMonoNerdFont*
fi

if [ -f "$FONT_COMMON_DIR/RobotoMonoNerdFont-Bold.ttf" ]; then
  printf "\e[93m  [setup font (RobotoMono)] RobotoMono is already installed. (skipped)\e[0m\n"
else
  mkdir -p ~/download/fonts/RobotoMono
  rm -rf ~/download/fonts/RobotoMono
  mkdir -p ~/download/fonts/RobotoMono
  cd "$HOME/download/fonts/RobotoMono" || return 1

  rm -rf "$FONT_LOCAL_DIR/RobotoMonoNerdFont*"
  sudo rm -rf "$FONT_COMMON_DIR/RobotoMonoNerdFont*"

  printf "\e[96m  [setup font (RobotoMono)] downloading RobotoMono fonts...\e[0m\n"
  wget https://github.com/guanghechen/mirror/releases/download/font/RobotoMono.zip

  printf "\e[96m  [setup font (RobotoMono)] installing RobotoMono fonts...\e[0m\n"
  unzip RobotoMono.zip
  rm -f RobotoMono.zip
  sudo cp ~/download/fonts/RobotoMono/* "$FONT_COMMON_DIR/"
  sudo atsutil databases -remove
fi
