# wsl platform configuration

## Windows paths
# Keep existing entries in place to preserve the user's PowerShell selection.
for _ghc_path in \
    "/mnt/c/Program Files/PowerShell/7/" \
    "/mnt/c/WINDOWS/System32/WindowsPowerShell/v1.0/" \
    "/mnt/c/WINDOWS/System32/" \
    "/mnt/c/WINDOWS/"; do
    [[ ":$PATH:" == *":$_ghc_path:"* ]] || export PATH="$_ghc_path:$PATH"
done
unset _ghc_path

## Variables
export BROWSER="/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"

if [[ -n "${GHC_WINDOWS_USERNAME:-}" ]]; then
    export f_windows_terminal_settings="/mnt/c/Users/$GHC_WINDOWS_USERNAME/AppData/Local/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json"
    export f_windows_download="/mnt/c/Users/$GHC_WINDOWS_USERNAME/Downloads"
    export f_vscode_keybindings="/mnt/c/Users/$GHC_WINDOWS_USERNAME/AppData/Roaming/Code/User/keybindings.json"
fi

## VPN host
export ghc_vpn_host_ip="127.0.0.1"
if command -v ipconfig.exe >/dev/null 2>&1; then
    detected_ip="$(ipconfig.exe | awk -F: '/IPv4 Address/ {gsub(/[^0-9.]/, "", $2); if ($2 ~ /^192\./) {print $2; exit}}')"
else
    detected_ip="$(awk '/^nameserver/ && $2 !~ /::/ {print $2; exit}' /etc/resolv.conf 2>/dev/null)"
fi
if [[ -n "$detected_ip" ]]; then
    export ghc_vpn_host_ip="$detected_ip"
fi

# Aliases and shell functions are interactive-only.
[[ $- == *i* ]] || return 0

## Aliases
# --preserve-root is a GNU chmod option, unavailable in the macOS system chmod.
alias chmod='chmod --preserve-root'
alias pbpaste='powershell.exe Get-Clipboard >'

### VS Code
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
        # Do not pass tmux's terminal environment to VS Code.
        alias code="env -u TMUX -u TERM $code_cmd_escaped"
    else
        alias code="$code_cmd_escaped"
    fi
fi

## Clipboard helpers
alias ghc-gen-secret="node -e \"console.log(crypto.randomBytes(32).toString('base64'))\" | clip.exe"
alias ghc-invisible-space="node -e \"process.stdout.write('\u00A0')\" | clip.exe"

## WSL-specific functions
# Bash sources these definitions explicitly; Fish autoloads them from fish_function_path.
wsl_fn_dir="$BASH_CONFIG_DIR/conf/platform/wsl/fn"
if [[ -d "$wsl_fn_dir" ]]; then
    for f in "$wsl_fn_dir"/*.bash; do
        [[ -r "$f" ]] && source "$f"
    done
fi
