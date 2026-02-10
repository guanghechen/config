# shellcheck shell=bash
# ghc-neovim-nightly - Build and install Neovim nightly

ghc-neovim-nightly() {
    local ps_cmd="ps aux"
    if [[ "$GHC_ENV_PLATFORM" == "nix" || "$GHC_ENV_PLATFORM" == "wsl" ]]; then
        ps_cmd="ps -aux"
    fi

    local nvim_processes
    nvim_processes=$(eval "$ps_cmd" | grep nvim | grep -v grep)

    if [[ -n "$nvim_processes" ]]; then
        printf "\e[93m  Neovim processes are currently running:\e[0m\n\n"
        echo "$nvim_processes"
        printf "\n\e[91m  Please close all Neovim instances or kill the processes before continuing.\e[0m\n"
        local pids
        pids=$(echo "$nvim_processes" | awk '{print $2}' | tr '\n' ' ')
        printf "\e[96m  You can kill them with: kill %s\e[0m\n" "$pids"
        return 1
    fi

    if [[ -z "$NEOVIM_HOME" ]]; then
        printf "\e[91m  Error: NEOVIM_HOME environment variable is not set\e[0m\n"
        return 1
    fi

    printf "\e[94m  Building Neovim nightly...\e[0m\n\n"

    printf "\e[96m  Fetching tags and checking out nightly branch...\e[0m\n"
    git fetch origin --tags --force && git checkout nightly || return 1

    printf "\n\e[96m  Building with CMake (RelWithDebInfo)...\e[0m\n"
    make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX="$NEOVIM_HOME" || return 1

    printf "\n\e[96m  Removing old installation...\e[0m\n"
    rm -rf "$NEOVIM_HOME" || return 1

    printf "\n\e[96m  Installing to %s...\e[0m\n" "$NEOVIM_HOME"
    make install || return 1

    printf "\n\e[92m  Neovim nightly installed successfully!\e[0m\n"
}
