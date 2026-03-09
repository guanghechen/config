# shellcheck shell=bash
# ghc-proxy - Toggle or set proxy settings

: "${ghc_vpn_host_ip:=127.0.0.1}"
: "${ghc_vpn_host_port:=7890}"

ghc-proxy() {
    local proxy="http://$ghc_vpn_host_ip:$ghc_vpn_host_port"

    if [[ "$1" == "on" ]]; then
        export http_proxy="$proxy"
        export https_proxy="$proxy"
        git config --global http.proxy "$proxy"
        git config --global https.proxy "$proxy"
        npm config set proxy "$proxy"
        npm config set https-proxy "$proxy"
    elif [[ "$1" == "off" ]]; then
        unset http_proxy
        unset https_proxy
        git config --global --unset http.proxy
        git config --global --unset https.proxy
        npm config delete proxy
        npm config delete https-proxy
    else
        if [[ -n "$http_proxy" ]]; then
            ghc-proxy off
        else
            ghc-proxy on
        fi
    fi
}
