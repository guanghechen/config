# nix platform configuration

## VPN host
export ghc_vpn_host_ip="127.0.0.1"
if [[ -r /etc/resolv.conf ]]; then
    detected_ip="$(awk '/^nameserver/ && $2 !~ /::/ {print $2; exit}' /etc/resolv.conf)"
    if [[ -n "$detected_ip" ]]; then
        export ghc_vpn_host_ip="$detected_ip"
    fi
fi

# Aliases and shell functions are interactive-only.
[[ $- == *i* ]] || return 0

## Aliases
# --preserve-root is a GNU chmod option, unavailable in the macOS system chmod.
alias chmod='chmod --preserve-root'

## Clipboard helpers
alias ghc-gen-secret="node -e \"console.log(crypto.randomBytes(32).toString('base64'))\" | xsel --clipboard --input"
