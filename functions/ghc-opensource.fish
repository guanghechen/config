function ghc-opensource --description 'Clone or pull an opensource repository'
    set script_path "$XDG_CONFIG_HOME/guanghechen/cli/opensource.mjs"
    if test -f "$script_path"
        set -l args $argv
        if test (count $args) -gt 0
            set -l github_url_pattern '^https?://github\.com/([^/?#]+)/([^/?#]+)'
            if string match -qr -- $github_url_pattern $args[1]
                set -l github_url_parts (string match -r --groups-only -- $github_url_pattern $args[1])
                set -l owner_name $github_url_parts[1]
                set -l repo_name (string replace -r -- '\.git$' '' $github_url_parts[2])

                # Avoid treating GitHub site sections as repository owners.
                set -l reserved_github_paths about account apps blog business codespaces collections contact customer-stories dashboard enterprise events explore features github-copilot join login marketplace new notifications orgs organizations pricing pulls repositories search security settings showcases sponsors topics trending users
                set -l owner_name_lower (string lower -- $owner_name)
                set -l owner_name_pattern '^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$'
                set -l repo_name_pattern '^[A-Za-z0-9._-]+$'

                if not contains -- $owner_name_lower $reserved_github_paths
                    and string match -qr -- $owner_name_pattern $owner_name
                    and string match -qr -- $repo_name_pattern $repo_name
                    set args[1] "$owner_name/$repo_name"
                end
            end
        end

        set -l output (node "$script_path" $args)
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
