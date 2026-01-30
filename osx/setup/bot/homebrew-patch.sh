#! /usr/bin/env bash
# shellcheck disable=SC1091

GHC_CONFIG_ROOT="${GHC_CONFIG_ROOT:-$HOME/.config/guanghechen}"
export GHC_CONFIG_ROOT

# shellcheck source=nix/setup/path.sh
source "$GHC_CONFIG_ROOT/nix/setup/path.sh"

### Install git
brew tap microsoft/git
brew install --cask git-credential-manager

### Install odbc
brew install unixodbc

### Install pngpaste
brew install pngpaste

### Install kitty
brew install --cask kitty

### Install wezterm
brew install --cask wezterm

### Install yabai
brew install koekeishiya/formulae/skhd
brew install koekeishiya/formulae/yabai
brew install FelixKratz/formulae/borders

### Install OSX System Utilities
brew install mole
