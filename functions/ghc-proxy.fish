function ghc-proxy
    set -gx http_proxy "http://$ghc_vpn_host_ip:$ghc_vpn_host_port"
    set -gx https_proxy "http://$ghc_vpn_host_ip:$ghc_vpn_host_port"
end
