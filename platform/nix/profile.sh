# Linux login env

export ghc_vpn_host_ip="127.0.0.1"
if [[ -r /etc/resolv.conf ]]; then
    detected_ip="$(awk '/^nameserver/ && $2 !~ /::/ {print $2; exit}' /etc/resolv.conf)"
    if [[ -n "$detected_ip" ]]; then
        export ghc_vpn_host_ip="$detected_ip"
    fi
fi
