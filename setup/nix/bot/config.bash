#! /usr/bin/env bash

## copy ~/.gitconfig
if [ -f "$HOME/.gitconfig" ]; then
  printf "\e[93m~/.gitconfig already exists (skipped)\e[0m\n"
else
  printf "\e[96msetting up ~/.gitconfig...\e[0m\n"
  cp "$HOME/.config/guanghechen/asset/conf/.gitconfig" "$HOME/.gitconfig"
fi

## copy ~/.inputrc
if [ -f "$HOME/.inputrc" ]; then
  printf "\e[93m~/.inputrc already exists (skipped)\e[0m\n"
else
  printf "\e[96msetting up ~/.inputrc...\e[0m\n"
  cp "$HOME/.config/guanghechen/asset/conf/.inputrc" "$HOME/.inputrc"
fi
