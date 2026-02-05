function ghc-opensource --description 'Clone or pull an opensource repository'
    set script_path "$XDG_CONFIG_HOME/guanghechen/cli/opensource.mjs"
    if test -f "$script_path"
        set -l output (node "$script_path" $argv)
        set -l exit_code $status

        # Parse output for CD command
        for line in $output
            if string match -q "CD:*" $line
                set -l target_dir (string replace "CD:" "" $line)
                if test -d "$target_dir"
                    cd "$target_dir"
                end
            else
                echo $line
            end
        end

        return $exit_code
    else
        printf "\e[91m  Cannot find %s.\e[0m\n" "$script_path"
        return 1
    end
end
