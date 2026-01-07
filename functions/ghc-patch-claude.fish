function ghc-patch-claude --description "Patch Claude Code with custom modifications"
    set -l script_dir ~/.config/claude/script

    # Check if claude is installed
    if not command -q claude
        echo "❌ Claude Code not installed"
        return 1
    end

    # All platforms: limit-128k
    set -l scripts limit-128k.mjs

    # WSL only: image-paste
    if test -r /proc/version; and grep -qEi "(Microsoft|WSL)" /proc/version
        set -a scripts image-paste.mjs
    end

    # Run each patch script
    for script in $scripts
        set -l script_path $script_dir/$script
        if not test -f $script_path
            echo "⚠ Script not found: $script"
            continue
        end
        echo "→ Running $script"
        node $script_path
        echo
    end
end
