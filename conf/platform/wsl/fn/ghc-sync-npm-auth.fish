# Sync .npmrc from Windows to WSL
function ghc-sync-npm-auth -d "Sync .npmrc authentication from Windows to WSL"
    if not set -q ghc_windows_username; or test -z "$ghc_windows_username"
        echo "Error: ghc_windows_username is not set"
        echo "Please set it in your fish config: set -gx ghc_windows_username 'your_windows_username'"
        return 1
    end

    set -l win_home "/mnt/c/Users/$ghc_windows_username"

    if not test -d "$win_home"
        echo "Error: Windows home directory not found at $win_home"
        echo "Please check if ghc_windows_username ('$ghc_windows_username') is correct"
        return 1
    end

    set -l win_npmrc "$win_home/.npmrc"
    set -l wsl_npmrc "$HOME/.npmrc"

    if not test -f "$win_npmrc"
        echo "Error: Windows .npmrc not found at $win_npmrc"
        echo "Please run 'artifacts-npm-credprovider -c ~/.npmrc' in Windows first"
        return 1
    end

    # Backup existing .npmrc if exists
    if test -f "$wsl_npmrc"
        cp "$wsl_npmrc" "$wsl_npmrc.bak"
        echo "Backed up existing .npmrc to .npmrc.bak"
    end

    cp "$win_npmrc" "$wsl_npmrc"
    echo "Synced .npmrc from Windows ($win_npmrc) to WSL ($wsl_npmrc)"
end
