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
      git -C "$repopath" merge origin/$branch --ff-only
    else
      printf "\e[96m  [setup config] add new worktree of %s into %s\e[0m\n" "$branch" "$repopath"
      git -C "$repomain" worktree add "$repopath" $branch
    fi
  done

  for branch in "${repo_optional_branches[@]}"; do
    local repopath="$reporoot/$branch"
    if [ -e "$repopath/.git" ]; then
      printf "\e[96m  [setup config] merging origin/%s into %s\e[0m\n" "$branch" "$repopath"
      git -C "$repopath" merge origin/$branch --ff-only
    fi
  done
}

printf "\e[96m  [setup config] cloning configs...\e[0m\n"
clone_or_update_config_repo

## copy ~/.gitconfig
if [ -f "$HOME/.gitconfig" ]; then
  printf "\e[93m  [setup config] ~/.gitconfig already exists. (skipped).\e[0m\n"
else
  printf "\e[96m  [setup config] setting up ~/.gitconfig...\e[0m\n"
  cp -f ~/.config/guanghechen/config/.gitconfig "$HOME/.gitconfig"
fi

## copy ~/.inputrc
if [ -f "$HOME/.inputrc" ]; then
  backup_file="$HOME/.inputrc.$(date +%Y%m%d).bak"
  mv "$HOME/.inputrc" "$backup_file"
  printf "\e[93m  [backup] ~/.inputrc -> %s\e[0m\n" "$backup_file"
fi
cp ~/.config/guanghechen/nix/config/.inputrc $HOME/.inputrc

## setup newsboat platform symlink
if [ -d "$HOME/.config/newsboat" ]; then
  newsboat_config_dir="$HOME/.config/newsboat"
  newsboat_platform_link="$newsboat_config_dir/local/platform"
  newsboat_platform_dir="$newsboat_config_dir/conf/platform"

  # Detect platform
  if [ "$(uname)" = "Darwin" ]; then
    platform="mac"
  elif [ -r /proc/version ] && grep -qEi "(Microsoft|WSL)" /proc/version; then
    platform="wsl"
  else
    platform="nix"
  fi

  # Create local dir if not exists
  mkdir -p "$newsboat_config_dir/local"

  # Create/update symlink
  if [ -e "$newsboat_platform_dir/$platform" ]; then
    printf "\e[96m  [setup config] setting up newsboat platform symlink (%s)...\e[0m\n" "$platform"
    ln -sf "$newsboat_platform_dir/$platform" "$newsboat_platform_link"
  fi
fi
