function ghc-patch-claude --description "Patch Claude Code with custom modifications"
    set -l script_dir ~/.config/claude/script

    # Check if claude is installed
    if not command -q claude
        printf "\e[91m  Claude Code not installed\e[0m\n"
        return 1
    end

    printf "\e[96m  cd ~/.config/claude/script/ && bun src/patch/index.ts\e[0m\n"
    fish -c "cd ~/.config/claude/script/ && bun src/patch/index.ts"
end
