# shellcheck shell=bash
# ghc-ghostty-shader - Manage Ghostty shaders per appearance

ghc-ghostty-shader() {
    local script_path="$HOME/.config/guanghechen/cli/ghostty-shader.mjs"
    if [[ -f "$script_path" ]]; then
        node "$script_path" "$@"
    else
        printf '\e[91m  Cannot find %s.\e[0m\n' "$script_path" >&2
        return 1
    fi
}
