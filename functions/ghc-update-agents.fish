function ghc-update-agents --description "Update AI coding agents globally"
    argparse skip-installation -- $argv
    or return 1

    set -l agents \
        @anthropic-ai/claude-code \
        @google/gemini-cli \
        @openai/codex \
        @github/copilot \
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
        set -l script_dir ~/.config/claude/script
        printf "\e[96m  cd ~/.config/claude/script/ && bun src/patch/index.ts\e[0m\n"
        fish -c "cd ~/.config/claude/script/ && bun src/patch/index.ts"

        # Sync Claude Code plugins from settings.json
        set -l claude_settings_file "$HOME/.config/claude/settings.json"
        if test -f $claude_settings_file
            set -l plugins (jq -r '.enabledPlugins // {} | to_entries | map(select(.value == true)) | .[].key' $claude_settings_file 2>/dev/null)
            if test (count $plugins) -gt 0
                printf "\e[96m  Syncing Claude Code plugins...\e[0m\n"
                claude plugin marketplace update
                for plugin in $plugins
                    if test "$plugin" = "ralph-loop@claude-plugins-official"; and test "$GHC_ENV_PLATFORM" = win
                        printf "\e[93m  Skipping %s on Windows\e[0m\n" $plugin
                        continue
                    end
                    printf "\e[90m  Installing %s...\e[0m\n" $plugin
                    claude plugin install $plugin --scope user 2>/dev/null
                end
                printf "\e[92m  Synced %d plugin(s)\e[0m\n\n" (count $plugins)
            end
        end
    end
end
