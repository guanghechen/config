#! /bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd $SCRIPT_DIR

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Function to build a Rust package and deploy it
# Args:
#   $1 - source_name: original package name (e.g., yoz)
#   $2 - target_name: target package name for output (e.g., yoz)
ghc-rust-build() {
  cd $SCRIPT_DIR

  local source_name="$1"
  local target_name="$2"
  local force="$3"

  if [ -z "$source_name" ] || [ -z "$target_name" ]; then
    echo -e "${RED}[neovim ${source_name:-unknown}] error: missing required parameters${RESET}"
    return 1
  fi

  local cargo_target_dir="$SCRIPT_DIR/target"
  local package_dir="$SCRIPT_DIR/$source_name"

  if [ ! -d "$package_dir" ]; then
    echo -e "${RED}[neovim $source_name] error: package not found${RESET}"
    return 1
  fi

  cd "$package_dir"

  local lua_dir="$SCRIPT_DIR/../lua"
  local bin_dir="$SCRIPT_DIR/../bin"

  mkdir -p "$lua_dir"
  mkdir -p "$bin_dir"

  if [ "$(uname)" == "Darwin" ]; then
    local lua_output="$lua_dir/${target_name}.so"
    local bin_output="$bin_dir/osx.${target_name}.so"
    local lib_name="lib${source_name}.dylib"

    if [ "$force" == "true" ] || [ ! -f "$lua_output" ]; then
      echo -e "${CYAN}[neovim $source_name] compiling...${RESET}"
      cargo build --release --quiet
      rm -f "$lua_output" "$bin_output"
      cp "${cargo_target_dir}/release/${lib_name}" "$lua_output"
      cp "${cargo_target_dir}/release/${lib_name}" "$bin_output"
      rm -rf "$cargo_target_dir"
      echo -e "${GREEN}[neovim $source_name] ✓ built${RESET}"
    else
      echo -e "${GREEN}[neovim $source_name] ✓ cached${RESET}"
    fi

  elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    local lua_output="$lua_dir/${target_name}.so"
    local bin_output="$bin_dir/nix.${target_name}.so"
    local lib_name="lib${source_name}.so"

    if [ "$force" == "true" ] || [ ! -f "$lua_output" ]; then
      echo -e "${CYAN}[neovim $source_name] compiling...${RESET}"
      cargo build --release --quiet
      rm -f "$lua_output" "$bin_output"
      cp "${cargo_target_dir}/release/${lib_name}" "$lua_output"
      cp "${cargo_target_dir}/release/${lib_name}" "$bin_output"
      rm -rf "$cargo_target_dir"
      echo -e "${GREEN}[neovim $source_name] ✓ built${RESET}"
    else
      echo -e "${GREEN}[neovim $source_name] ✓ cached${RESET}"
    fi

  elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
    local lua_output="$lua_dir/${target_name}.dll"
    local bin_output="$bin_dir/win.${target_name}.dll"
    local lib_name="lib${source_name}.dll"

    if [ "$force" == "true" ] || [ ! -f "$lua_output" ]; then
      echo -e "${CYAN}[neovim $source_name] compiling...${RESET}"
      cargo build --release --quiet
      rm -f "$lua_output" "$bin_output"
      cp "${cargo_target_dir}/release/${lib_name}" "$lua_output"
      cp "${cargo_target_dir}/release/${lib_name}" "$bin_output"
      rm -rf "$cargo_target_dir"
      echo -e "${GREEN}[neovim $source_name] ✓ built${RESET}"
    else
      echo -e "${GREEN}[neovim $source_name] ✓ cached${RESET}"
    fi
  fi
}

# Parse command line arguments
FORCE=false
while [[ $# -gt 0 ]]; do
  case $1 in
  --force | -f)
    FORCE=true
    shift
    ;;
  *)
    echo -e "${RED}[neovim build] error: unknown option: $1${RESET}"
    echo -e "${YELLOW}[neovim build] usage: $0 [--force|-f]${RESET}"
    exit 1
    ;;
  esac
done

ghc-rust-build "yoz" "yoz" "$FORCE"

echo -e "${BLUE}[neovim build] done${RESET}"
