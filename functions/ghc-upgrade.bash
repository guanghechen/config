# shellcheck shell=bash
# ghc-upgrade - Upgrade system configuration

ghc-upgrade() {
  local config_root="$HOME/.config/guanghechen"
  [[ -n "$XDG_CONFIG_HOME" ]] && config_root="$XDG_CONFIG_HOME/guanghechen"
  [[ -n "$GHC_CONFIG_ROOT" ]] && config_root="$GHC_CONFIG_ROOT"

  local edition=""
  if command -v kit-repo &>/dev/null; then
    edition=$(kit-repo get config.edition 2>/dev/null | tr -d '[:space:]')
  fi

  if [[ -z "$edition" ]]; then
    if [[ -n "$SSH_CONNECTION" || -n "$SSH_CLIENT" || -n "$SSH_TTY" ]]; then
      edition="nix-remote"
    elif [[ "$(uname)" == "Darwin" ]]; then
      edition="osx"
    else
      edition="nix"
    fi
  fi

  case "$edition" in
  nix-remote)
    bash "$config_root/setup/nix-remote/setup.bash"
    ;;
  osx)
    bash "$config_root/setup/osx/setup.bash"
    ;;
  win)
    pwsh -File "$config_root/setup/win/setup.ps1"
    ;;
  *)
    bash "$config_root/setup/nix/setup.bash"
    ;;
  esac
}
