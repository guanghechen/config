function ghc-update-agents --description "Update AI coding agents globally"
    set -l log_icon (printf '\uf1da ')
    printf "\e[96m%sUpdating AI coding agents...\e[0m\n" $log_icon
    npm install -g @anthropic-ai/claude-code @google/gemini-cli @openai/codex @github/copilot

    printf "\e[96m%sPatching Claude Code...\e[0m\n" $log_icon
    ghc-patch-claude
end
