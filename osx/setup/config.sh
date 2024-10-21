#! /usr/bin/env bash

clone_or_update_config_repo() {
  local CONFIG_ROOT_DIR="$HOME/.config"
  local CONFIG_REPO="https://github.com/guanghechen/config.git"
  local CONFIG_BRANCHES=(
    "alacritty"
    "btop"
    "fish"
    "fzf"
    "guanghechen"
    "helix"
    "lazygit"
    "lsd"
    "nvim"
    "ripgrep"
    "tmux"
    "yazi"
  )

  for branch in "${CONFIG_BRANCHES[@]}"; do
    local repo_path="$CONFIG_ROOT_DIR/$branch"
    if [ -d "$repo_path/.git" ]; then
      git -C "$repo_path" pull origin $branch
    else
      mkdir -p "$repo_path"
      git clone $CONFIG_REPO "$repo_path" --single-branch --branch=$branch
    fi
  done
}

printf "\n\e[34m  [setup config] cloning configs...\e[0m\n"
clone_or_update_config_repo

if [ -f "$HOME/.gitconfig" ]; then
  printf "\n\e[38;5;214m  [setup config] ~/.gitconfig is already exist. (skipped).\e[0m\n"
else
  printf "\n\e[34m  [setup config] setting up ~/.gitconfig...\e[0m\n"
  cp -f ~/.config/guanghechen/osx/config/.gitconfig "$HOME/.gitconfig"
fi
