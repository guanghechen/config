#! /usr/bin/env bash

clone_or_update_config_repo() {
  local reporoot="$HOME/.config"
  local repomain="$reporoot/guanghechen"
  local repo_required_branches=(
    "bat"
    "btop"
    "conda"
    "git-delta"
    "fish"
    "fzf"
    "lazygit"
    "lsd"
    "nvim"
    "pm2"
    "ripgrep"
    "tmux"
    "yazi"
    "yozora"
  )
  local repo_optional_branches=(
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
    "pwsh"
    "skhd"
    "tsuki"
    "wezterm"
    "yabai"
    "yasb"
  )

  for branch in "${repo_required_branches[@]}"; do
    local repopath="$reporoot/$branch"
    if [ -e "$repopath/.git" ]; then
      printf "\e[94m  [setup config] merging origin/$branch into $repopath\e[0m\n"
      git -C "$repopath" merge origin/$branch --ff-only
    else
      printf "\e[94m  [setup config] add new worktree of $branch into $repopath\e[0m\n"
      git -C "$repomain" worktree add "$repopath" $branch
    fi
    printf "\n"
  done

  for branch in "${repo_optional_branches[@]}"; do
    local repopath="$reporoot/$branch"
    if [ -e "$repopath/.git" ]; then
      printf "\e[94m  [setup config] merging origin/$branch into $repopath\e[0m\n"
      git -C "$repopath" merge origin/$branch --ff-only
      printf "\n"
    fi
  done
}

printf "\n\e[94m  [setup config] cloning configs...\e[0m\n"
clone_or_update_config_repo

if [ -f "$HOME/.gitconfig" ]; then
  printf "\n\e[93m  [setup config] ~/.gitconfig is already exist. (skipped).\e[0m\n"
else
  printf "\n\e[94m  [setup config] setting up ~/.gitconfig...\e[0m\n"
  cp -f ~/.config/guanghechen/config/.gitconfig "$HOME/.gitconfig"
fi
