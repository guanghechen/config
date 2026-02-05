function yoz --description "Preview file with yoz"
    set script_path "$XDG_CONFIG_HOME/guanghechen/cli/yoz.mjs"
    if test -f "$script_path"
        node "$script_path" $argv
    else
        printf "\e[91m  Cannot find %s.\e[0m\n" "$script_path"
    end
end
