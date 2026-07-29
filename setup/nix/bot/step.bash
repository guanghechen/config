#! /usr/bin/env bash

## Shared step helpers for setup entrypoints.
##
## Each leaf script runs in its own `bash -e -o pipefail` process, so any
## unhandled command failure becomes the step status without leaking shell
## state into the entrypoint.

GHC_STEP_FAILURES=()

ghc_run_script() {
  /usr/bin/env bash -e -o pipefail "$@"
}

## Usage: ghc_step <label> <command> [args...]   — abort the bootstrap on failure
ghc_step() {
  local _ghc_label="$1"
  shift

  printf "\n\e[96m  [setup %s] preparing...\e[0m\n" "$_ghc_label"
  if "$@"; then
    printf "\e[92m  [setup %s] done.\e[0m\n" "$_ghc_label"
  else
    local _ghc_rc=$?
    printf "\e[91m  [setup %s] FAILED (exit %d). aborting.\e[0m\n" "$_ghc_label" "$_ghc_rc"
    exit "$_ghc_rc"
  fi
}

## Usage: ghc_step_optional <label> <command> [args...]   — warn, carry on, remember
ghc_step_optional() {
  local _ghc_label="$1"
  shift

  printf "\n\e[96m  [setup %s] preparing...\e[0m\n" "$_ghc_label"
  if "$@"; then
    printf "\e[92m  [setup %s] done.\e[0m\n" "$_ghc_label"
  else
    local _ghc_rc=$?
    printf "\e[91m  [setup %s] FAILED (exit %d). (continuing).\e[0m\n" "$_ghc_label" "$_ghc_rc"
    GHC_STEP_FAILURES+=("$_ghc_label")
  fi
}

## Usage: ghc_require <command>...   — abort naming the first missing one
ghc_require() {
  ## A step just changed PATH; drop anything bash cached from an earlier lookup.
  hash -r 2>/dev/null || :

  local _ghc_cmd
  for _ghc_cmd in "$@"; do
    command -v "$_ghc_cmd" >/dev/null 2>&1 && continue
    printf "\e[91m  [setup] required command not found: %s. aborting.\e[0m\n" "$_ghc_cmd"
    exit 1
  done
}

## Final verdict; its status is meant to be the bootstrap's exit code.
ghc_step_summary() {
  if [ "${#GHC_STEP_FAILURES[@]}" -eq 0 ]; then
    printf "\n\e[95m ===== [setup] all steps completed. =====\e[0m\n"
    return 0
  fi

  local _ghc_item
  printf "\n\e[91m ===== [setup] completed with %d failed step(s) =====\e[0m\n" "${#GHC_STEP_FAILURES[@]}"
  for _ghc_item in "${GHC_STEP_FAILURES[@]}"; do
    printf "\e[91m    - %s\e[0m\n" "$_ghc_item"
  done
  return 1
}
