# macOS login env

if [[ -n "${PATH:-}" ]]; then
    current_user="$(whoami)"
    new_path=""
    IFS=':' read -r -a path_parts <<< "$PATH"
    for p in "${path_parts[@]}"; do
        if [[ "$p" != /Users/* || "$p" == "/Users/$current_user/"* ]]; then
            if [[ -z "$new_path" ]]; then
                new_path="$p"
            else
                new_path="$new_path:$p"
            fi
        fi
    done
    export PATH="$new_path"
fi

export ghc_vpn_host_ip="127.0.0.1"
export f_vscode_keybindings="$HOME/Library/Application Support/Code/User/keybindings.json"
export f_cline_settings="$HOME/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json"

export LDFLAGS="-L/opt/homebrew/opt/llvm/lib"
export CPPFLAGS="-I/opt/homebrew/opt/llvm/include"
