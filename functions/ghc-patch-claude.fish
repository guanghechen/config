function ghc-patch-claude --description "Patch Claude Code with custom modifications"
    set -l script_dir ~/.config/claude/script

    # Check if claude is installed
    if not command -q claude
        echo "❌ Claude Code not installed"
        return 1
    end

    echo "cd ~/.config/claude/script/ && bun src/patch/index.ts"
    fish -c "cd ~/.config/claude/script/ && bun src/patch/index.ts"
end
