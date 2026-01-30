#! /usr/bin/env bash

clone_or_update_config_repo() {
  local reporoot="$HOME/.config"
  local repomain="$reporoot/guanghechen"
  local repo_required_branches=(
    "bat"
    "btop"
    "conda"
    "cspell"
    "fish"
    "fzf"
    "git-delta"
    "lazygit"
    "lsd"
    "nvim"
    "ripgrep"
    "tmux"
    "yazi"
  )
  local repo_optional_branches=(
    "alacritty"
    "alacritty-windows"
    "claude"
    "codex"
    "gh"
    "ghostty"
    "helix"
    "kitty"
    "kit-pm"
    "komorebi"
    "neovide"
    "newsboat"
    "nvim-lazy"
    "nvim-nvchad"
    "opencode"
    "ora"
    "pm2"
    "pwsh"
    "skhd"
    "tsuki"
    "wezterm"
    "yabai"
    "yasb"
    "yoz"
  )

  for branch in "${repo_required_branches[@]}"; do
    local repopath="$reporoot/$branch"
    if [ -e "$repopath/.git" ]; then
      printf "\e[96m  [setup config] merging origin/%s into %s\e[0m\n" "$branch" "$repopath"
      git -C "$repopath" merge "origin/$branch" --ff-only
    else
      printf "\e[96m  [setup config] add new worktree of %s into %s\e[0m\n" "$branch" "$repopath"
      git -C "$repomain" worktree add "$repopath" "$branch"
    fi
  done

  for branch in "${repo_optional_branches[@]}"; do
    local repopath="$reporoot/$branch"
    if [ -e "$repopath/.git" ]; then
      printf "\e[96m  [setup config] merging origin/%s into %s\e[0m\n" "$branch" "$repopath"
      git -C "$repopath" merge "origin/$branch" --ff-only
    fi
  done
}

## copy ~/.gitconfig
if [ -f "$HOME/.gitconfig" ]; then
  printf "\e[93m  [setup config] ~/.gitconfig already exists. (skipped).\e[0m\n"
else
  printf "\e[96m  [setup config] setting up ~/.gitconfig...\e[0m\n"
  cp -f "$HOME/.config/guanghechen/config/.gitconfig" "$HOME/.gitconfig"
fi

## copy ~/.inputrc
if [ -f "$HOME/.inputrc" ]; then
  printf "\e[93m  [setup config] ~/.inputrc already exists. (skipped).\e[0m\n"
else
  printf "\e[96m  [setup config] setting up ~/.inputrc...\e[0m\n"
  cp "$HOME/.config/guanghechen/nix/conf/.inputrc" "$HOME/.inputrc"
fi

## sync configs
printf "\e[96m  [setup config] cloning configs...\e[0m\n"
clone_or_update_config_repo
