# shellcheck shell=bash
# ghc-theme-apply - Apply a theme

ghc-theme-apply() {
    local script_path="$HOME/.config/guanghechen/cli/theme.mjs"
    if [[ -f "$script_path" ]]; then
        local first_arg
        first_arg=$(echo "$1" | tr '[:upper:]' '[:lower:]' | xargs)  # lowercase and trim
        node "$script_path" apply "$first_arg"
    else
        printf "\e[91m  Cannot find %s.\e[0m\n" "$script_path"
    fi
}
