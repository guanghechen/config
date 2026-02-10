# shellcheck shell=bash
# ghc-theme-gen - Generate themes

ghc-theme-gen() {
    local script_path="$HOME/.config/guanghechen/cli/theme.mjs"
    if [[ -f "$script_path" ]]; then
        node "$script_path" gen
    else
        printf "\e[91m  Cannot find %s.\e[0m\n" "$script_path"
    fi
}
