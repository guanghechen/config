function yarn3-proxy
    yarn config set httpProxy "http://$ghc_vpn_host_ip:$ghc_vpn_host_port"
    yarn config set httpsProxy "http://$ghc_vpn_host_ip:$ghc_vpn_host_port"
end
