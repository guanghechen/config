## Filter other users path (which could be inherit by `sudo su`)
set -l current_user (whoami)
set -l new_path
for p in $PATH
    if not string match -q "/Users/*" -- $p || string match -q "/Users/$current_user/*" -- $p
        set new_path $new_path $p
    end
end
set -gx PATH $new_path

## Variables
set -gx ghc_vpn_host_ip '127.0.0.1'
set -gx f_vscode_settings "$HOME/Library/Application Support/Code/User/keybindings.json"
set -gx f_cline_settings "$HOME/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json"

## Aliases
alias code='env -u TMUX -u TERM /usr/local/bin/code'
alias ghc-reset-git-credential='echo -e "host=github.com\nprotocol=https\n" | git credential-osxkeychain erase'

## Abbr
abbr -a ghc-gen-secret "node -e \"console.log(crypto.randomBytes(32).toString('base64'))\" | pbcopy"
