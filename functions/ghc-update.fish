function ghc-update
    set script_path "$XDG_CONFIG_HOME/guanghechen/cli/sync-xdg-config.mjs"
    if test -f "$script_path"
        node "$script_path"
    else
        printf "\e[91m  Cannot find %s.\e[0m\n" "$script_path"
    end
end
