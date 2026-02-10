# shellcheck shell=bash
# ghc-update - Sync XDG config

ghc-update() {
    local script_path="$XDG_CONFIG_HOME/guanghechen/cli/sync-xdg-config.mjs"
    if [[ -f "$script_path" ]]; then
        node "$script_path"
    else
        printf "\e[91m  Cannot find %s.\e[0m\n" "$script_path"
    fi
}
