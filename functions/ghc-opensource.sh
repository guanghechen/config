# shellcheck shell=bash
# ghc-opensource - Clone or pull an opensource repository

ghc-opensource() {
    local script_path="$XDG_CONFIG_HOME/guanghechen/cli/opensource.mjs"
    if [[ -f "$script_path" ]]; then
        local output exit_code
        output=$(node "$script_path" "$@")
        exit_code=$?

        if [[ -n "$output" ]]; then
            local line
            while IFS= read -r line; do
                if [[ "$line" == CD:* ]]; then
                    local target_dir="${line#CD:}"
                    if [[ -d "$target_dir" ]]; then
                        cd "$target_dir" || return 1
                    fi
                else
                    echo "$line"
                fi
            done <<< "$output"
        fi

        return $exit_code
    else
        printf "\e[91m  Cannot find %s.\e[0m\n" "$script_path"
        return 1
    fi
}
