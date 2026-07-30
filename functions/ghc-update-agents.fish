function ghc-update-agents --description "Update AI coding agents globally"
    argparse skip-installation -- $argv
    or return 1

    set -l agents \
        @anthropic-ai/claude-code \
        @google/gemini-cli \
        opencode-ai

    if test -z "$_flag_skip_installation"
        for agent in $agents
            printf "\e[96m  Installing %s...\e[0m\n" $agent
            npm install -g $agent >/dev/null
            set -l pkg_ver (npm list -g $agent --depth=0 2>/dev/null | grep $agent | sed 's/.*@//')
            printf "\e[92m  %s installed: v%s\e[0m\n\n" $agent $pkg_ver
        end
    else
        printf "\e[93m  Skipping agent installation as requested\e[0m\n\n"
    end

    # Check if claude is installed
    if command -q claude
        printf "\e[96m  Patching Claude Code...\e[0m\n"
        node ~/.config/guanghechen/cli/patch-agents.mjs --agent claude

        # Sync only enabled Claude Code plugins from settings.json
        set -l claude_settings_file "$HOME/.config/claude/settings.json"
        if test -f $claude_settings_file
            set -l plugin_entries (jq -r '.enabledPlugins // {} | to_entries[] | "\(.key)\t\(.value == true)"' $claude_settings_file 2>/dev/null)
            set -l synced_plugins 0
            for plugin_entry in $plugin_entries
                set -l plugin_parts (string split \t -- $plugin_entry)
                set -l plugin $plugin_parts[1]
                set -l plugin_enabled $plugin_parts[2]

                if test "$plugin_enabled" != true
                    continue
                end

                if test $synced_plugins -eq 0
                    printf "\e[96m  Syncing Claude Code plugins...\e[0m\n"
                    claude plugin marketplace update
                end

                printf "\e[90m  Installing %s...\e[0m\n" $plugin
                claude plugin install $plugin --scope user 2>/dev/null
                set synced_plugins (math $synced_plugins + 1)
            end

            if test $synced_plugins -gt 0
                printf "\e[92m  Synced %d plugin(s)\e[0m\n\n" $synced_plugins
            end
        end
    end
end
