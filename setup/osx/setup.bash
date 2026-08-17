#! /usr/bin/env bash

repomain="$HOME/.config/guanghechen"
repoworktree="$HOME/.config/kit"
setup_nix="$repomain/setup/nix"
setup_osx="$repomain/setup/osx"

if ! git --version >/dev/null 2>&1; then
  printf "\e[91m  [setup preparation] Git is unavailable. Install Xcode Command Line Tools with: xcode-select --install\e[0m\n" >&2
  exit 1
fi

## Download core configurations
##
## This runs before step.bash is available, since step.bash lives in the repo
## this step is fetching.
ghc_bootstrap_repo() {
  if [ -e "$repomain/.git" ]; then
    git -C "$repomain" fetch origin || return 1
    git -C "$repomain" merge origin/guanghechen --ff-only || return 1
    return 0
  fi

  mkdir -p "$repomain" || return 1
  git clone https://github.com/guanghechen/config.git --branch=guanghechen "$repomain"
}

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

## Bootstrap
printf "\n\e[95m ===== [bootstrap] =====\e[0m\n"
source "$setup_nix/bot/env.bash" || exit 1

### Setup homebrew
if [ -z "$HOME_HOMEBREW" ] || [ -w "$HOME_HOMEBREW/var/homebrew/locks" ]; then
  ghc_step_optional homebrew ghc_run_script "$setup_nix/bot/homebrew.bash"
  ghc_step_optional "homebrew (osx)" ghc_run_script "$setup_osx/bot/homebrew-patch.bash"
fi

## Setup envs
printf "\n\e[95m ===== [setup env] =====\e[0m\n"
ghc_step_optional rust ghc_run_script "$setup_nix/env/rust.bash"
ghc_step_optional miniforge ghc_run_script "$setup_nix/env/miniforge.bash"
ghc_step_optional bun ghc_run_script "$setup_nix/env/bun.bash"
ghc_step_optional fish ghc_run_script "$setup_nix/bot/fish.bash"
ghc_step_optional node ghc_run_script "$setup_nix/env/node.bash"

## Refresh PATH after installers ran in isolated shells.
source "$setup_nix/bot/env.bash" || exit 1

## The published `kit-repo` provisions every app config below.
ghc_require cargo
ghc_step kit-repo ghc_run_script "$setup_nix/env/kit-repo.bash"
kit_repo_bin="${CARGO_HOME:-$HOME/.cargo}/bin/kit-repo"

## Setup configs
### ensure kit worktree
ghc_ensure_kit_worktree() {
  if [ -e "$repoworktree/.git" ]; then
    printf "\e[93m  [setup config] %s already exists. (skipped worktree).\e[0m\n" "$repoworktree"
    ## Having the worktree is what the later steps need; it is also what
    ## `kit-repo sync` writes into, so a dirty tree here is normal and a
    ## non-fast-forward pull must not take the bootstrap down.
    git -C "$repoworktree" pull --ff-only origin kit ||
      printf "\e[93m  [setup config] pull failed for %s. (continuing).\e[0m\n" "$repoworktree"
  elif git -C "$repomain" show-ref --verify --quiet refs/heads/kit; then
    printf "\e[96m  [setup config] attaching existing branch kit to %s...\e[0m\n" "$repoworktree"
    git -C "$repomain" worktree add "$repoworktree" kit
  else
    printf "\e[96m  [setup config] creating worktree %s from origin/kit...\e[0m\n" "$repoworktree"
    git -C "$repomain" fetch origin &&
      git -C "$repomain" worktree add --track -b kit "$repoworktree" origin/kit
  fi
}

ghc_sync_kit_repo() {
  "$kit_repo_bin" set config.edition "osx" || return 1
  "$kit_repo_bin" sync
}

## Without the worktree and synced local settings there is no app config for
## any step below, so these two failures abort instead of joining the summary.
ghc_step worktree ghc_ensure_kit_worktree
ghc_step "local settings" ghc_sync_kit_repo
ghc_step_optional config ghc_run_script "$setup_nix/bot/config.bash"

## Setup apps
printf "\n\e[95m ===== [setup app] =====\e[0m\n"
ghc_step_optional newsboat ghc_run_script "$setup_nix/app/newsboat.bash"
ghc_step_optional nvim ghc_run_script "$setup_nix/app/nvim.bash"
ghc_step_optional tmux ghc_run_script "$setup_nix/app/tmux.bash"

## Setup font
ghc_step_optional font ghc_run_script "$setup_osx/bot/font-maple.bash"

## Setup themes
ghc_require node
ghc_step_optional theme node "$repomain/cli/theme.mjs" apply

ghc_step_summary
