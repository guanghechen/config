#! /usr/bin/env bash
# shellcheck disable=SC1091


# shellcheck source=setup/nix/setup/path.sh
source "$HOME/.config/guanghechen/setup/nix/setup/path.sh"

FONT_DIR="/usr/share/fonts/RobotoMono"
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
  printf "\e[96m  [setup font (RobotoMono)] force removing existing RobotoMono fonts...\e[0m\n"
  sudo rm -rf "$FONT_DIR"
fi

if [ -d "$FONT_DIR" ]; then
  printf "\e[93m  [setup font (RobotoMono)] RobotoMono is already installed. (skipped)\e[0m\n"
else
  mkdir -p  ~/download/fonts/RobotoMono
  rm    -rf ~/download/fonts/RobotoMono
  mkdir -p  ~/download/fonts/RobotoMono
  cd "$HOME/download/fonts/RobotoMono" || return 1

  printf "\e[96m  [setup font (RobotoMono)] downloading RobotoMono fonts...\e[0m\n"
  wget https://github.com/guanghechen/mirror/releases/download/font/RobotoMono.zip

  printf "\e[96m  [setup font (RobotoMono)] installing RobotoMono fonts...\e[0m\n"
  unzip RobotoMono.zip
  rm -f RobotoMono.zip
  sudo cp -r ~/download/fonts/RobotoMono "$FONT_DIR/"
  sudo fc-cache -f -v
fi
