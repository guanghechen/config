# WSL interactive config

alias chmod='chmod --preserve-root'
alias pbpaste='powershell.exe Get-Clipboard >'

code_cmd=""
if command -v code >/dev/null 2>&1; then
    code_cmd="code"
elif [[ -x /mnt/c/app/vscode/bin/code ]]; then
    code_cmd="/mnt/c/app/vscode/bin/code"
elif [[ -x /mnt/d/app/vscode/bin/code ]]; then
    code_cmd="/mnt/d/app/vscode/bin/code"
elif [[ -x "/mnt/c/Program Files/Microsoft VS Code/bin/code" ]]; then
    code_cmd="/mnt/c/Program Files/Microsoft VS Code/bin/code"
elif [[ -n "${GHC_WINDOWS_USERNAME:-}" && -x "/mnt/c/Users/${GHC_WINDOWS_USERNAME}/AppData/Local/Programs/Microsoft VS Code/bin/code" ]]; then
    code_cmd="/mnt/c/Users/${GHC_WINDOWS_USERNAME}/AppData/Local/Programs/Microsoft VS Code/bin/code"
fi

if [[ -n "$code_cmd" ]]; then
    printf -v code_cmd_escaped '%q' "$code_cmd"
    if [[ -n "${TMUX:-}" ]]; then
        alias code="env -u TMUX -u TERM $code_cmd_escaped"
    else
        alias code="$code_cmd_escaped"
    fi
fi

alias ghc-gen-secret="node -e \"console.log(crypto.randomBytes(32).toString('base64'))\" | clip.exe"
alias ghc-invisible-space="node -e \"process.stdout.write('\u00A0')\" | clip.exe"

wsl_fn_dir="$BASH_CONFIG_DIR/platform/wsl/fn"
if [[ -d "$wsl_fn_dir" ]]; then
    for f in "$wsl_fn_dir"/*.sh; do
        [[ -r "$f" ]] && source "$f"
    done
fi
