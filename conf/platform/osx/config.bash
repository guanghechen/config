# osx platform configuration

## Filter other users' PATH entries inherited through sudo su
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

## Variables
export ghc_vpn_host_ip="127.0.0.1"
export f_vscode_keybindings="$HOME/Library/Application Support/Code/User/keybindings.json"
export f_cline_settings="$HOME/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json"

## llvm
export LDFLAGS="-L/opt/homebrew/opt/llvm/lib"
export CPPFLAGS="-I/opt/homebrew/opt/llvm/include"

# Aliases and shell functions are interactive-only.
[[ $- == *i* ]] || return 0

## Aliases
alias ghc-reset-git-credential='echo -e "host=github.com\nprotocol=https\n" | git credential-osxkeychain erase'

### VS Code
code_cmd=""
if command -v code >/dev/null 2>&1; then
    code_cmd="code"
elif [[ -x /usr/local/bin/code ]]; then
    code_cmd="/usr/local/bin/code"
elif [[ -x /opt/homebrew/bin/code ]]; then
    code_cmd="/opt/homebrew/bin/code"
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
alias ghc-gen-secret="node -e \"console.log(crypto.randomBytes(32).toString('base64'))\" | pbcopy"
alias ghc-invisible-space="node -e \"process.stdout.write('\u00A0')\" | pbcopy"
