function ghc-ghostty-shader --description 'Manage Ghostty shaders per appearance'
    set script_path "$HOME/.config/guanghechen/cli/ghostty-shader.mjs"
    if test -f "$script_path"
        node "$script_path" $argv
    else
        printf "\e[91m  Cannot find %s.\e[0m\n" "$script_path" >&2
        return 1
    end
end
