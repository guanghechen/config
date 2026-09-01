#! /usr/bin/env bash

repomain="$HOME/.config/guanghechen"
repoworktree="$HOME/.config/kit"
setup_nix="$repomain/setup/nix"
setup_nix_remote="$repomain/setup/nix-remote"

for prerequisite in sudo apt; do
  if ! command -v "$prerequisite" >/dev/null 2>&1; then
    printf "\e[91m  [setup preparation] unsupported platform: required command not found: %s (Debian/Ubuntu only).\e[0m\n" "$prerequisite" >&2
    exit 1
  fi
done

ghc_prepare_system() {
  sudo apt update &&
    sudo apt dist-upgrade -y &&
    sudo apt remove -y tmux &&
    sudo apt install -y curl git locales traceroute wget &&
    sudo apt install -y bash-completion build-essential libvips-dev unixodbc &&
    sudo apt install -y clangd colordiff file fontconfig libunwind8 net-tools vim &&
    sudo apt install -y wl-clipboard &&
    sudo apt autoremove -y &&
    sudo apt autoclean &&
    sudo locale-gen en_US.UTF-8 &&
    sudo update-locale LANG=en_US.UTF-8
}

ghc_bootstrap_repo() {
  if [ -e "$repomain/.git" ]; then
    git -C "$repomain" fetch origin || return 1
    git -C "$repomain" merge origin/guanghechen --ff-only || return 1
    return 0
  fi

  mkdir -p "$repomain" || return 1
  git clone https://github.com/guanghechen/config.git --branch=guanghechen "$repomain"
}

printf "\n\e[1;95m󰒓 setup\e[0m\n"
printf "\n\e[96m  [setup preparation] preparing...\e[0m\n"
if ! ghc_prepare_system; then
  printf "\e[91m  [setup preparation] FAILED. aborting.\e[0m\n"
  exit 1
fi
printf "\e[92m  [setup preparation] done.\e[0m\n"

printf "\n\e[96m  [setup repo] preparing...\e[0m\n"
if ! ghc_bootstrap_repo; then
  printf "\e[91m  [setup repo] FAILED to sync %s. aborting.\e[0m\n" "$repomain"
  exit 1
fi
printf "\e[92m  [setup repo] done.\e[0m\n"

source "$setup_nix/bot/step.bash" || {
  printf "\e[91m  [setup repo] step.bash is missing from %s. aborting.\e[0m\n" "$setup_nix/bot"
  exit 1
}

## Configuration helpers
ghc_ensure_kit_worktree() {
  if [ -e "$repoworktree/.git" ]; then
    printf "\e[93m%s already exists (skipped worktree creation)\e[0m\n" "$repoworktree"
    ## `kit-repo sync` writes into this worktree, so a dirty tree is normal and
    ## a non-fast-forward pull must not take the bootstrap down.
    git -C "$repoworktree" pull --ff-only origin kit ||
      printf "\e[93mpull failed for %s (continuing)\e[0m\n" "$repoworktree"
  elif git -C "$repomain" show-ref --verify --quiet refs/heads/kit; then
    printf "\e[96mattaching existing branch kit to %s...\e[0m\n" "$repoworktree"
    git -C "$repomain" worktree add "$repoworktree" kit
  else
    printf "\e[96mcreating worktree %s from origin/kit...\e[0m\n" "$repoworktree"
    git -C "$repomain" fetch origin &&
      git -C "$repomain" worktree add --track -b kit "$repoworktree" origin/kit
  fi
}

ghc_sync_kit_repo() {
  "$kit_repo_bin" set config.edition "nix-remote" || return 1
  "$kit_repo_bin" sync
}

## Bootstrap
ghc_section "" bootstrap
ghc_step_in_place "" "runtime environment" source "$setup_nix/bot/env.bash"
if [ -z "${HOME_HOMEBREW:-}" ] || [ -w "$HOME_HOMEBREW/var/homebrew/locks" ]; then
  ghc_step_optional "" homebrew ghc_run_script "$setup_nix_remote/bot/homebrew.bash"
else
  ghc_step_skip "" homebrew "lock directory is not writable"
fi

## Environment
ghc_section "" environment
ghc_step_optional "" rust ghc_run_script "$setup_nix/env/rust.bash"
ghc_step_optional "" node ghc_run_script "$setup_nix_remote/env/node.bash"
ghc_step_in_place "" "runtime environment" source "$setup_nix/bot/env.bash"

## Configuration
ghc_section "" configuration
ghc_step "" "cargo available" ghc_require cargo
ghc_step "󰏗" kit-repo ghc_run_script "$setup_nix/env/kit-repo.bash"
kit_repo_bin="${CARGO_HOME:-$HOME/.cargo}/bin/kit-repo"
ghc_step "󰙅" worktree ghc_ensure_kit_worktree
printf "\n"
ghc_sync_kit_repo || exit $?
ghc_step_optional "" config ghc_run_script "$setup_nix/bot/config.bash"
ghc_step_optional "" bash ghc_run_script "$HOME/.config/bash/setup.bash"

## Applications
ghc_section "󱧺" applications
ghc_step_optional "" nvim ghc_run_script "$setup_nix/app/nvim.bash"
ghc_step_optional "" tmux ghc_run_script "$setup_nix/app/tmux.bash"
ghc_step "" "node available" ghc_require node
ghc_step_optional "" theme node "$repomain/cli/theme.mjs" apply

ghc_step_summary
