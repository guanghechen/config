# macOS interactive config

alias ghc-reset-git-credential='echo -e "host=github.com\nprotocol=https\n" | git credential-osxkeychain erase'

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
        alias code="env -u TMUX -u TERM $code_cmd_escaped"
    else
        alias code="$code_cmd_escaped"
    fi
fi

alias ghc-gen-secret="node -e \"console.log(crypto.randomBytes(32).toString('base64'))\" | pbcopy"
alias ghc-invisible-space="node -e \"process.stdout.write('\u00A0')\" | pbcopy"
