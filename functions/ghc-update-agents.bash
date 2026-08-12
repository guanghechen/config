# shellcheck shell=bash
# ghc-update-agents - Update AI coding agents globally

ghc-update-agents() {
    local skip_installation=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skip-installation)
                skip_installation=true
                ;;
            --)
                shift
                break
                ;;
            -*)
                echo "Unknown option $1" >&2
                return 1
                ;;
            *)
                echo "Unexpected argument: $1" >&2
                return 1
                ;;
        esac
        shift
    done

    local agents=(
        "@anthropic-ai/claude-code"
        "@google/gemini-cli"
        "@openai/codex"
        "@github/copilot"
        "opencode-ai"
    )

    if ! $skip_installation; then
        local install_status=0
        for agent in "${agents[@]}"; do
            printf "\e[96m  Installing %s...\e[0m\n" "$agent"
            install_status=0
            npm install -g "$agent" >/dev/null || install_status=$?
            if [[ $install_status -ne 0 ]]; then
                printf "\e[91m  Failed to install %s\e[0m\n" "$agent" >&2
                return "$install_status"
            fi
            local pkg_ver
            pkg_ver=$(npm list -g "$agent" --depth=0 2>/dev/null | grep "$agent" | sed 's/.*@//')
            printf "\e[92m  %s installed: v%s\e[0m\n\n" "$agent" "$pkg_ver"
        done
    else
        printf "\e[93m  Skipping agent installation as requested\e[0m\n\n"
    fi

    # Check if claude is installed
    if command -v claude &>/dev/null; then
        printf "\e[96m  Patching Claude Code...\e[0m\n"
        node ~/.config/guanghechen/cli/patch-agents.mjs --agent claude

        # Sync Claude Code plugins from settings.json
        local claude_settings_file="$HOME/.config/claude/settings.json"
        if [[ -f "$claude_settings_file" ]]; then
            local -a plugins=()
            while IFS= read -r plugin; do
                [[ -n "$plugin" ]] && plugins+=("$plugin")
            done < <(jq -r '.enabledPlugins // {} | to_entries | map(select(.value == true)) | .[].key' "$claude_settings_file" 2>/dev/null)
            if [[ ${#plugins[@]} -gt 0 ]]; then
                printf "\e[96m  Syncing Claude Code plugins...\e[0m\n"
                claude plugin marketplace update
                for plugin in "${plugins[@]}"; do
                    printf "\e[90m  Installing %s...\e[0m\n" "$plugin"
                    claude plugin install "$plugin" --scope user 2>/dev/null
                done
                printf "\e[92m  Synced %d plugin(s)\e[0m\n\n" "${#plugins[@]}"
            fi
        fi
    fi
}
