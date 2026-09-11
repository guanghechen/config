#! /usr/bin/env bash

## copy ~/.gitconfig
if [ -f "$HOME/.gitconfig" ]; then
  printf "\e[93m~/.gitconfig already exists (skipped)\e[0m\n"
else
  printf "\e[96msetting up ~/.gitconfig...\e[0m\n"
  cp "$HOME/.config/guanghechen/asset/conf/.gitconfig" "$HOME/.gitconfig"
fi

## link XDG .npmrc
npmrc_source="$HOME/.npmrc"
npmrc_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
npmrc_path="$npmrc_config_home/.npmrc"
if [ -e "$npmrc_path" ] || [ -L "$npmrc_path" ]; then
  printf "\e[93m%s already exists (skipped)\e[0m\n" "$npmrc_path"
elif [ ! -f "$npmrc_source" ]; then
  printf "\e[93m%s is missing or not a file (skipped link)\e[0m\n" "$npmrc_source"
else
  printf "\e[96mlinking %s to %s...\e[0m\n" "$npmrc_path" "$npmrc_source"
  mkdir -p "$npmrc_config_home" || exit 1
  ln -s "$npmrc_source" "$npmrc_path" || exit 1
fi

## copy ~/.inputrc
if [ -f "$HOME/.inputrc" ]; then
  printf "\e[93m~/.inputrc already exists (skipped)\e[0m\n"
else
  printf "\e[96msetting up ~/.inputrc...\e[0m\n"
  cp "$HOME/.config/guanghechen/asset/conf/.inputrc" "$HOME/.inputrc"
fi
