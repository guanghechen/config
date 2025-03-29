function ghc-proxy
    set proxy "http://$ghc_vpn_host_ip:$ghc_vpn_host_port"

    if test "$argv[1]" = on
        set -gx http_proxy $proxy
        set -gx https_proxy $proxy
        git config --global http.proxy $proxy
        git config --global https.proxy $proxy
        npm config set proxy $proxy
        npm config set https-proxy $proxy
    else if test "$argv[1]" = off
        set -e http_proxy
        set -e https_proxy
        git config --global --unset http.proxy
        git config --global --unset https.proxy
        npm config delete proxy
        npm config delete https-proxy
    else
        if set -q http_proxy
            ghc-proxy off
        else
            ghc-proxy on
        end
    end
end
