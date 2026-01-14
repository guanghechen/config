function ghc-update-agents --description "Update AI coding agents globally"
    set -l agents \
        @anthropic-ai/claude-code \
        @google/gemini-cli \
        @openai/codex \
        @github/copilot \
        opencode-ai

    for agent in $agents
        printf "\e[96m  Installing %s...\e[0m\n" $agent
        npm install -g $agent >/dev/null
        set -l pkg_ver (npm list -g $agent --depth=0 2>/dev/null | grep $agent | sed 's/.*@//')
        printf "\e[92m  %s installed: v%s\e[0m\n\n" $agent $pkg_ver
    end

    printf "\e[96m  Patching Claude Code...\e[0m\n"
    ghc-patch-claude
end
