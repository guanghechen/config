function ghc-theme --description 'Theme management CLI'
    set script_path "$HOME/.config/guanghechen/cli/theme.mjs"
    if test -f "$script_path"
        node "$script_path" $argv
    else
        printf "\e[91m  Cannot find %s.\e[0m\n" "$script_path"
        return 1
    end
end
