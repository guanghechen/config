# shellcheck shell=bash
# ghc-theme - Theme management CLI

ghc-theme() {
    local script_path="$HOME/.config/guanghechen/cli/theme.mjs"
    if [[ -f "$script_path" ]]; then
        node "$script_path" "$@"
    else
        printf "\e[91m  Cannot find %s.\e[0m\n" "$script_path"
        return 1
    fi
}
