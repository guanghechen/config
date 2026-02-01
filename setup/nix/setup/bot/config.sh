#! /usr/bin/env bash

GHC_CONFIG_ROOT="${GHC_CONFIG_ROOT:-$HOME/.config/guanghechen}"
export GHC_CONFIG_ROOT

clone_or_update_config_repo() {
  local reporoot="$HOME/.config"
  local repomain="$GHC_CONFIG_ROOT"
  local repo_required_branches=(
    "bat"
    "btop"
    "conda"
    "cspell"
    "fish"
    "fzf"
    "gh"
    "git-delta"
    "kit-pm"
    "lazygit"
    "lsd"
    "nvim"
    "ora"
    "pm2"
    "ripgrep"
    "tmux"
    "yazi"
    "yoz"
  )
  local repo_optional_branches=(
    "alacritty"
    "alacritty-windows"
    "claude"
    "codex"
    "ghostty"
    "helix"
    "kitty"
    "komorebi"
    "neovide"
    "newsboat"
    "nvim-lazy"
    "nvim-nvchad"
    "opencode"
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

## copy ~/.inputrc
if [ -f "$HOME/.inputrc" ]; then
  printf "\e[93m  [setup config] ~/.inputrc already exists. (skipped).\e[0m\n"
else
  printf "\e[96m  [setup config] setting up ~/.inputrc...\e[0m\n"
  cp "$GHC_CONFIG_ROOT/asset/conf/.inputrc" "$HOME/.inputrc"
fi

## sync configs
printf "\e[96m  [setup config] cloning configs...\e[0m\n"
clone_or_update_config_repo
