#! /usr/bin/env bash

clone_or_update_config_repo() {
  local CONFIG_ROOT_DIR="$HOME/.config"
  local CONFIG_MAIN_DIR="$CONFIG_ROOT_DIR/guanghechen"
  local CONFIG_REPO="https://github.com/guanghechen/config.git"
  local CONFIG_BRANCHES=(
    "btop"
    "conda"
    "fish"
    "fzf"
    "lazygit"
    "lsd"
    "nvim"
    "ripgrep"
    "tmux"
    "yazi"
  )
  local OPTIONAL_CONFIG_BRANCHES=(
    "alacritty"
    "alacritty-windows"
    "claude"
    "ghostty"
    "helix"
    "kitty"
    "komorebi"
    "neovide"
    "nvim-lazy"
    "nvim-nvchad"
    "plan"
    "pm2"
    "pwsh"
    "skhd"
    "tsuki"
    "wezterm"
    "yabai"
    "yasb"
    "yozora"
  )

  for branch in "${CONFIG_BRANCHES[@]}"; do
    local repo_path="$CONFIG_ROOT_DIR/$branch"
    if [ -e "$repo_path/.git" ]; then
      printf "\e[34m  [setup config] merging origin/$branch into $repo_path\e[0m\n"
      git -C "$repo_path" merge origin/$branch --ff-only
    else
      printf "\e[34m  [setup config] add new worktree of $branch into $repo_path\e[0m\n"
      git -C "$CONFIG_MAIN_DIR" worktree add "$repo_path" $branch
    fi
    printf "\n"
  done

  for branch in "${OPTIONAL_CONFIG_BRANCHES[@]}"; do
    local repo_path="$CONFIG_ROOT_DIR/$branch"
    if [ -e "$repo_path/.git" ]; then
      printf "\e[34m  [setup config] merging origin/$branch into $repo_path\e[0m\n"
      git -C "$repo_path" merge origin/$branch --ff-only
      printf "\n"
    fi
  done
}

printf "\n\e[34m  [setup config] cloning configs...\e[0m\n"
clone_or_update_config_repo

if [ -f "$HOME/.gitconfig" ]; then
  printf "\n\e[33;5;214m  [setup config] ~/.gitconfig is already exist. (skipped).\e[0m\n"
else
  printf "\n\e[34m  [setup config] setting up ~/.gitconfig...\e[0m\n"
  cp -f ~/.config/guanghechen/config/.gitconfig "$HOME/.gitconfig"
fi
