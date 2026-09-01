#! /usr/bin/env bash

## Shared forest and step helpers for setup entrypoints.
##
## Entrypoints declare flat sections. Each step is an independent, rounded
## tree whose combined output is streamed one level below its root. Optional
## failures are collected; required failures abort with the original exit code.

GHC_STEP_FAILURES=()
GHC_SECTION=""
GHC_SECTION_HAS_STEP=false
GHC_COLOR_RESET=$'\e[0m'
GHC_COLOR_RAIL=$'\e[90m'
GHC_COLOR_HEADING=$'\e[1;95m'
GHC_COLOR_STEP=$'\e[96m'
GHC_COLOR_SUCCESS=$'\e[92m'
GHC_COLOR_ERROR=$'\e[91m'
GHC_COLOR_WARNING=$'\e[93m'
GHC_COLOR_SUMMARY=$'\e[95m'

ghc_run_script() {
  /usr/bin/env bash -e -o pipefail "$@"
}

ghc_section() {
  local icon="$1"
  local label="$2"

  printf "\n%s%s %s%s\n" "$GHC_COLOR_HEADING" "$icon" "$label" "$GHC_COLOR_RESET"
  GHC_SECTION="$label"
  GHC_SECTION_HAS_STEP=false
}

_ghc_step_gap() {
  if [ "$GHC_SECTION_HAS_STEP" = true ]; then
    printf "\n"
  fi
  GHC_SECTION_HAS_STEP=true
}

_ghc_forest_output() {
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    line="${line##*$'\r'}"
    [ -n "$line" ] || continue
    printf "%s│%s  %s%s\n" "$GHC_COLOR_RAIL" "$GHC_COLOR_RESET" "$line" "$GHC_COLOR_RESET"
  done
}

_ghc_run_nested() {
  local enable_color=false
  if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ -z "${NODE_DISABLE_COLORS:-}" ]; then
    enable_color=true
  fi

  (
    if [ "$enable_color" = true ]; then
      export FORCE_COLOR="${FORCE_COLOR:-1}"
      export CARGO_TERM_COLOR="${CARGO_TERM_COLOR:-always}"
      if [ -z "${HOMEBREW_NO_COLOR:-}" ]; then
        export HOMEBREW_COLOR="${HOMEBREW_COLOR:-1}"
      fi
    fi
    "$@"
  ) 2>&1 | _ghc_forest_output
  local rc=${PIPESTATUS[0]}
  return "$rc"
}

_ghc_run_in_place() {
  "$@"
}

_ghc_step_status() {
  local mode="$1"
  local icon="$2"
  local label="$3"
  local runner="$4"
  shift 4

  _ghc_step_gap
  printf "%s╭─%s %s%s %s%s\n" \
    "$GHC_COLOR_RAIL" "$GHC_COLOR_RESET" "$GHC_COLOR_STEP" "$icon" "$label" "$GHC_COLOR_RESET"
  local rc
  if "$runner" "$@"; then
    printf "%s╰─%s %s✓ done%s\n" \
      "$GHC_COLOR_RAIL" "$GHC_COLOR_RESET" "$GHC_COLOR_SUCCESS" "$GHC_COLOR_RESET"
    return 0
  else
    rc=$?
  fi

  if [ "$mode" = "required" ]; then
    printf "%s╰─%s %s✗ failed (exit %d); aborting%s\n" \
      "$GHC_COLOR_RAIL" "$GHC_COLOR_RESET" "$GHC_COLOR_ERROR" "$rc" "$GHC_COLOR_RESET"
    exit "$rc"
  fi

  printf "%s╰─%s %s✗ failed (exit %d); continuing%s\n" \
    "$GHC_COLOR_RAIL" "$GHC_COLOR_RESET" "$GHC_COLOR_ERROR" "$rc" "$GHC_COLOR_RESET"
  if [ -n "$GHC_SECTION" ]; then
    GHC_STEP_FAILURES+=("$GHC_SECTION / $label")
  else
    GHC_STEP_FAILURES+=("$label")
  fi
  return 0
}

ghc_step() {
  local icon="$1"
  local label="$2"
  shift 2
  _ghc_step_status required "$icon" "$label" _ghc_run_nested "$@"
}

## Run in the entrypoint shell when the command must mutate its environment.
## In-place steps are expected to be quiet; ordinary step output is streamed.
ghc_step_in_place() {
  local icon="$1"
  local label="$2"
  shift 2
  _ghc_step_status required "$icon" "$label" _ghc_run_in_place "$@"
  ## PATH may have changed; discard executable paths cached by the parent shell.
  hash -r 2>/dev/null || :
}

ghc_step_optional() {
  local icon="$1"
  local label="$2"
  shift 2
  _ghc_step_status optional "$icon" "$label" _ghc_run_nested "$@"
}

ghc_step_skip() {
  local icon="$1"
  local label="$2"
  local reason="$3"
  _ghc_step_gap
  printf "%s╭─%s %s%s %s%s\n" \
    "$GHC_COLOR_RAIL" "$GHC_COLOR_RESET" "$GHC_COLOR_STEP" "$icon" "$label" "$GHC_COLOR_RESET"
  printf "%s╰─%s %s○ skipped — %s%s\n" \
    "$GHC_COLOR_RAIL" "$GHC_COLOR_RESET" "$GHC_COLOR_WARNING" "$reason" "$GHC_COLOR_RESET"
}

## Return non-zero naming the first missing command.
ghc_require() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 && continue
    printf "%srequired command not found: %s%s\n" "$GHC_COLOR_ERROR" "$cmd" "$GHC_COLOR_RESET"
    return 1
  done
}

## Final verdict; its status is meant to be the bootstrap's exit code.
ghc_step_summary() {
  printf "\n%s summary%s\n" "$GHC_COLOR_HEADING" "$GHC_COLOR_RESET"
  printf "%s╭─%s %s󰒓 setup%s\n" \
    "$GHC_COLOR_RAIL" "$GHC_COLOR_RESET" "$GHC_COLOR_SUMMARY" "$GHC_COLOR_RESET"

  if [ "${#GHC_STEP_FAILURES[@]}" -eq 0 ]; then
    printf "%s╰─%s %s✓ all sections completed%s\n" \
      "$GHC_COLOR_RAIL" "$GHC_COLOR_RESET" "$GHC_COLOR_SUCCESS" "$GHC_COLOR_RESET"
    return 0
  fi

  local count=${#GHC_STEP_FAILURES[@]}
  local item
  local noun="step"
  [ "$count" -eq 1 ] || noun="steps"
  for item in "${GHC_STEP_FAILURES[@]}"; do
    printf "%s│%s  %s%s%s\n" \
      "$GHC_COLOR_RAIL" "$GHC_COLOR_RESET" "$GHC_COLOR_ERROR" "$item" "$GHC_COLOR_RESET"
  done
  printf "%s╰─%s %s✗ completed with %d failed %s%s\n" \
    "$GHC_COLOR_RAIL" "$GHC_COLOR_RESET" "$GHC_COLOR_ERROR" "$count" "$noun" "$GHC_COLOR_RESET"
  return 1
}
