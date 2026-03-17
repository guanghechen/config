# shellcheck shell=bash

ghc-sync-npm-auth() {
    if [[ -z "${GHC_WINDOWS_USERNAME:-}" ]]; then
        echo "Error: GHC_WINDOWS_USERNAME is not set"
        echo "Please set it in your shell config: export GHC_WINDOWS_USERNAME='your_windows_username'"
        return 1
    fi

    local win_home="/mnt/c/Users/$GHC_WINDOWS_USERNAME"
    if [[ ! -d "$win_home" ]]; then
        echo "Error: Windows home directory not found at $win_home"
        echo "Please check if GHC_WINDOWS_USERNAME ('$GHC_WINDOWS_USERNAME') is correct"
        return 1
    fi

    local win_npmrc="$win_home/.npmrc"
    local wsl_npmrc="$HOME/.npmrc"

    if [[ ! -f "$win_npmrc" ]]; then
        echo "Error: Windows .npmrc not found at $win_npmrc"
        echo "Please run 'artifacts-npm-credprovider -c ~/.npmrc' in Windows first"
        return 1
    fi

    if [[ -f "$wsl_npmrc" ]]; then
        cp -- "$wsl_npmrc" "$wsl_npmrc.bak"
        echo "Backed up existing .npmrc to .npmrc.bak"
    fi

    cp -- "$win_npmrc" "$wsl_npmrc"
    echo "Synced .npmrc from Windows ($win_npmrc) to WSL ($wsl_npmrc)"
}
