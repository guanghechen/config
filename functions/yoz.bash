# shellcheck shell=bash
# yoz - Preview file with yoz

yoz() {
    local script_path="$XDG_CONFIG_HOME/guanghechen/cli/yoz.mjs"
    if [[ -f "$script_path" ]]; then
        node "$script_path" "$@"
    else
        printf "\e[91m  Cannot find %s.\e[0m\n" "$script_path"
        return 1
    fi
}
